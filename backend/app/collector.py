from __future__ import annotations

import asyncio
import copy
import logging
import time
from datetime import datetime

from .config import Settings
from .hub import WebSocketHub
from .provider import (
    CST,
    UpstreamClient,
    load_stations,
    recalculate_snapshot,
)
from .store import SnapshotStore

log = logging.getLogger(__name__)


class Collector:
    def __init__(
        self,
        settings: Settings,
        client: UpstreamClient,
        store: SnapshotStore,
        hub: WebSocketHub,
    ):
        self.settings = settings
        self.client = client
        self.store = store
        self.hub = hub
        self.stations = load_stations(settings.stations_csv)
        self.current: dict | None = None
        self._stop = asyncio.Event()
        self._loop_task: asyncio.Task | None = None
        self._full_lock = asyncio.Lock()
        self._full_last_start = 0.0
        self._full_task: asyncio.Task | None = None
        self._full_status = {
            "running": False,
            "last_start": None,
            "last_done": None,
            "last_error": None,
            "last_stats": None,
        }
        self._station_tasks: dict[str, asyncio.Task] = {}
        self._station_started: dict[str, float] = {}
        self._station_status: dict[str, dict] = {}

    async def start(self) -> None:
        snapshot = self.store.latest()
        if snapshot is None:
            snapshot = self.store.seed(self.settings.seed_snapshot)
            if snapshot:
                log.info("seeded snapshot: %s", snapshot.get("fetched_at"))
        self.current = self._ensure_observed_at(snapshot)
        if self.current:
            self.store.save(self.current)
        self._loop_task = asyncio.create_task(self._loop())
        log.info("collector started with %s stations", len(self.stations))

    async def stop(self) -> None:
        self._stop.set()
        if self._loop_task:
            self._loop_task.cancel()
            await asyncio.gather(self._loop_task, return_exceptions=True)
        for task in list(self._station_tasks.values()):
            task.cancel()
        if self._station_tasks:
            await asyncio.gather(*self._station_tasks.values(), return_exceptions=True)
        await self.client.close()

    async def _loop(self) -> None:
        try:
            await asyncio.sleep(1)
            while not self._stop.is_set():
                age = self.snapshot_age_seconds()
                if self.current is None or age is None or age >= self.settings.refresh_interval:
                    await self.full_refresh()
                try:
                    await asyncio.wait_for(
                        self._stop.wait(),
                        timeout=self.settings.refresh_interval,
                    )
                except asyncio.TimeoutError:
                    continue
        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception("collector loop failed")

    async def full_refresh(self) -> bool:
        if self._full_lock.locked():
            return False
        async with self._full_lock:
            self._full_status.update(
                {
                    "running": True,
                    "last_start": time.time(),
                    "last_error": None,
                }
            )
            self._full_last_start = time.time()
            try:
                snapshot, stats = await self.client.refresh_all(self.stations)
                self.current = self._ensure_observed_at(snapshot)
                self.store.save(self.current)
                self._full_status["last_stats"] = stats
                await self.hub.broadcast(
                    {
                        "type": "snapshot",
                        "fetched_at": self.current["fetched_at"],
                        "station_count": self.current["station_count"],
                        "port_free": self.current["port_free"],
                        "port_busy": self.current["port_busy"],
                        "port_float": self.current["port_float"],
                    }
                )
                return True
            except Exception as exc:
                log.exception("full refresh failed")
                self._full_status["last_error"] = f"{type(exc).__name__}: {exc}"
                return False
            finally:
                self._full_status["running"] = False
                self._full_status["last_done"] = time.time()

    def start_full_refresh(self) -> tuple[bool, str]:
        now = time.time()
        if self._full_lock.locked() or self._full_status["running"]:
            return False, "全量刷新已在进行中"
        if (
            self._full_last_start
            and now - self._full_last_start < self.settings.full_cooldown
        ):
            wait = int(self.settings.full_cooldown - (now - self._full_last_start))
            return False, f"冷却中，请 {wait}s 后再试"
        self._full_task = asyncio.create_task(self.full_refresh())
        return True, "已开始全量刷新"

    def start_station_refresh(self, name: str) -> tuple[bool, str]:
        station = self._find_station(name)
        if station is None:
            return False, "站点不存在"
        task = self._station_tasks.get(name)
        if task is not None and not task.done():
            return False, "该站点正在刷新"
        now = time.time()
        started = self._station_started.get(name, 0)
        if started and now - started < self.settings.station_cooldown:
            wait = int(self.settings.station_cooldown - (now - started))
            return False, f"冷却中，请 {wait}s 后再试"
        self._station_started[name] = now
        self._station_status[name] = {
            "running": True,
            "last_start": now,
            "last_done": None,
            "last_error": None,
        }
        task = asyncio.create_task(self._station_refresh(station))
        self._station_tasks[name] = task
        return True, "已开始刷新该站点"

    async def _station_refresh(self, station: dict) -> None:
        name = station["name"]
        try:
            record, power_ports = await self.client.refresh_station(station)
            if record is None:
                raise RuntimeError("站点没有可用设备数据")
            if self.current is None:
                raise RuntimeError("尚无全量快照")
            snapshot = copy.deepcopy(self.current)
            stations = [
                record if item["name"] == name else item
                for item in snapshot["stations"]
            ]
            snapshot["stations"] = stations
            self.current = recalculate_snapshot(
                snapshot,
                area_id=self.settings.area_id,
            )
            self.store.save(self.current)
            self._station_status[name].update(
                {
                    "power_ports": power_ports,
                    "last_error": None,
                }
            )
            await self.hub.broadcast(
                {
                    "type": "station",
                    "station": name,
                    "observed_at": record.get("observed_at"),
                    "fetched_at": self.current["fetched_at"],
                }
            )
        except Exception as exc:
            log.exception("station refresh failed: %s", name)
            self._station_status[name]["last_error"] = f"{type(exc).__name__}: {exc}"
        finally:
            self._station_status[name]["running"] = False
            self._station_status[name]["last_done"] = time.time()

    def snapshot_age_seconds(self) -> int | None:
        if not self.current:
            return None
        fetched_at = self.current.get("fetched_at")
        if not fetched_at:
            return None
        try:
            parsed = datetime.strptime(fetched_at, "%Y-%m-%d %H:%M:%S").replace(
                tzinfo=CST
            )
        except ValueError:
            return None
        return max(0, int((datetime.now(CST) - parsed).total_seconds()))

    def meta(self) -> dict:
        snapshot = self.current or {}
        return {
            "ok": snapshot != {},
            "fetched_at": snapshot.get("fetched_at"),
            "age_seconds": self.snapshot_age_seconds(),
            "station_count": snapshot.get("station_count", 0),
            "device_count": snapshot.get("device_count", 0),
            "port_total": snapshot.get("port_total", 0),
            "port_free": snapshot.get("port_free", 0),
            "port_busy": snapshot.get("port_busy", 0),
            "port_float": snapshot.get("port_float", 0),
            "port_storage": snapshot.get("port_storage", 0),
            "port_fault": snapshot.get("port_fault", 0),
            "port_offline": snapshot.get("port_offline", 0),
            "power_ports": snapshot.get("power_ports", 0),
            "refresh_interval": self.settings.refresh_interval,
        }

    def status_payload(self) -> dict:
        return {
            "full": {
                **self._full_status,
                "last_start": self._as_iso(self._full_status["last_start"]),
                "last_done": self._as_iso(self._full_status["last_done"]),
            },
            "stations": {
                name: {
                    **status,
                    "last_start": self._as_iso(status["last_start"]),
                    "last_done": self._as_iso(status["last_done"]),
                }
                for name, status in self._station_status.items()
            },
            "snapshot_age": self.snapshot_age_seconds(),
        }

    def station_summaries(self) -> list[dict]:
        if not self.current:
            return []
        return [
            {key: value for key, value in station.items() if key != "devices"}
            for station in self.current["stations"]
        ]

    def get_station(self, name: str) -> dict | None:
        if not self.current:
            return None
        for station in self.current["stations"]:
            if station["name"] == name:
                return station
        return None

    def _find_station(self, name: str) -> dict | None:
        for station in self.stations:
            if station["name"] == name:
                return station
        return None

    def _ensure_observed_at(self, snapshot: dict | None) -> dict | None:
        if snapshot is None:
            return None
        for station in snapshot.get("stations", []):
            station.setdefault("observed_at", snapshot.get("fetched_at"))
        return snapshot

    @staticmethod
    def _as_iso(value: float | None) -> str | None:
        if value is None:
            return None
        return datetime.fromtimestamp(value, CST).isoformat()
