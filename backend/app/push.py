from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Protocol

import httpx

from .config import Settings
from .push_store import PushStore

log = logging.getLogger(__name__)

CST = timezone(timedelta(hours=8))


class PushSender(Protocol):
    async def send(self, subscriber: dict, title: str, body: str, extras: dict) -> bool:
        ...


class LoggingPushSender:
    async def send(self, subscriber: dict, title: str, body: str, extras: dict) -> bool:
        token = subscriber.get("push_token", "")
        log.info(
            "push dry-run device=%s platform=%s token=%s title=%s body=%s extras=%s",
            subscriber.get("device_id"),
            subscriber.get("platform"),
            f"***{token[-6:]}" if token else "",
            title,
            body,
            extras,
        )
        return True


class JPushSender:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._client = httpx.AsyncClient(
            timeout=10,
            auth=(settings.jpush_app_key, settings.jpush_master_secret),
        )

    async def close(self) -> None:
        await self._client.aclose()

    async def send(self, subscriber: dict, title: str, body: str, extras: dict) -> bool:
        token = subscriber.get("push_token") or ""
        if not token:
            return False
        payload = {
            "platform": "all",
            "audience": {"registration_id": [token]},
            "notification": {
                "alert": body,
                "android": {
                    "alert": body,
                    "title": title,
                    "extras": extras,
                },
                "ios": {
                    "alert": {"title": title, "body": body},
                    "sound": "default",
                    "badge": "+1",
                    "extras": extras,
                },
            },
            "options": {
                "apns_production": self.settings.jpush_apns_production,
                "time_to_live": 600,
            },
        }
        try:
            response = await self._client.post(
                self.settings.jpush_api_url,
                json=payload,
            )
            if response.status_code >= 300:
                log.warning(
                    "jpush failed device=%s status=%s body=%s",
                    subscriber.get("device_id"),
                    response.status_code,
                    response.text[:300],
                )
                return False
            log.info(
                "jpush sent device=%s station=%s",
                subscriber.get("device_id"),
                extras.get("station"),
            )
            return True
        except Exception as exc:
            log.warning(
                "jpush error device=%s: %s",
                subscriber.get("device_id"),
                exc,
            )
            return False


class PushNotifier:
    def __init__(
        self,
        settings: Settings,
        store: PushStore,
        sender: PushSender,
    ):
        self.settings = settings
        self.store = store
        self.sender = sender

    async def close(self) -> None:
        close = getattr(self.sender, "close", None)
        if close is not None:
            await close()

    async def on_snapshot(
        self,
        previous: dict | None,
        current: dict,
        changed_station: str | None = None,
    ) -> None:
        if previous is None:
            return
        events = self._events(previous, current, changed_station)
        if not events:
            return
        total = sum(len(items) for items in events.values())
        log.info("free port events: %s stations, %s ports", len(events), total)
        now = datetime.now(timezone.utc)
        for station_name, ports in events.items():
            if self._is_stale(previous, station_name, changed_station):
                log.info("skip push for %s: previous snapshot stale", station_name)
                continue
            subscribers = self.store.subscribers(station_name)
            if not subscribers:
                continue
            title = "有空闲插口"
            body = f"{station_name} 有 {len(ports)} 个空闲插口"
            extras = {
                "type": "free_port",
                "station": station_name,
                "free_count": len(ports),
            }
            for subscriber in subscribers:
                if self._on_cooldown(subscriber, now):
                    continue
                try:
                    sent = await self.sender.send(subscriber, title, body, extras)
                except Exception:
                    log.exception("push send failed for %s", station_name)
                    sent = False
                if sent:
                    self.store.mark_notified(
                        subscriber["device_id"],
                        station_name,
                    )

    def _events(
        self,
        previous: dict,
        current: dict,
        changed_station: str | None,
    ) -> dict[str, list[tuple[str, int]]]:
        old_stations = {
            station["name"]: station for station in previous.get("stations", [])
        }
        new_stations = {
            station["name"]: station for station in current.get("stations", [])
        }
        names = [changed_station] if changed_station else list(new_stations)
        result: dict[str, list[tuple[str, int]]] = {}
        for name in names:
            if name is None:
                continue
            old_station = old_stations.get(name)
            new_station = new_stations.get(name)
            if old_station is None or new_station is None:
                continue
            old_ports = self._ports(old_station)
            new_ports = self._ports(new_station)
            changed: list[tuple[str, int]] = []
            for key, new_kind in new_ports.items():
                old_kind = old_ports.get(key)
                if new_kind == "free" and old_kind in ("busy", "float"):
                    changed.append(key)
            if changed:
                result[name] = changed
        return result

    @staticmethod
    def _ports(station: dict) -> dict[tuple[str, int], str]:
        ports: dict[tuple[str, int], str] = {}
        for device in station.get("devices", []):
            devaddress = device.get("devaddress") or ""
            for port in device.get("ports", []):
                ports[(devaddress, int(port.get("no") or 0))] = port.get("kind", "")
        return ports

    def _is_stale(
        self,
        previous: dict,
        station_name: str,
        changed_station: str | None,
    ) -> bool:
        if changed_station:
            station = next(
                (
                    item
                    for item in previous.get("stations", [])
                    if item.get("name") == station_name
                ),
                None,
            )
            if station is not None:
                age = self._age_seconds(
                    station.get("observed_at") or previous.get("fetched_at")
                )
                return age is not None and age > self.settings.push_stale_seconds
        age = self._age_seconds(previous.get("fetched_at"))
        return age is not None and age > self.settings.push_stale_seconds

    def _on_cooldown(self, subscriber: dict, now: datetime) -> bool:
        last = subscriber.get("last_notified_at")
        if not last:
            return False
        try:
            parsed = datetime.fromisoformat(last)
        except ValueError:
            return False
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return (now - parsed).total_seconds() < self.settings.push_cooldown_seconds

    @staticmethod
    def _age_seconds(value: str | None) -> int | None:
        if not value:
            return None
        try:
            parsed = datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            try:
                parsed = datetime.fromisoformat(value)
            except ValueError:
                return None
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=CST)
        return max(0, int((datetime.now(CST) - parsed).total_seconds()))


def build_sender(settings: Settings) -> PushSender:
    if (
        settings.push_enabled
        and settings.jpush_app_key
        and settings.jpush_master_secret
    ):
        log.info("push sender: JPush")
        return JPushSender(settings)
    log.info("push sender: logging dry-run")
    return LoggingPushSender()
