from __future__ import annotations

import asyncio
import copy
import csv
import json
import logging
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable

import httpx

from .config import Settings

log = logging.getLogger(__name__)

CST = timezone(timedelta(hours=8))
CAMPUS_NAME = {
    1: "玉泉校区",
    2: "紫金港校区",
    3: "华家池校区",
    4: "西溪校区",
    5: "之江校区",
}
STATUS_LABEL = {
    "0": "空闲",
    "1": "充电中",
    "3": "浮充",
    "4": "储物",
    "6": "空闲",
    "7": "计量故障",
    "8": "保险丝故障",
    "9": "继电器故障",
}
FAULT_LABEL = {"7", "8", "9"}
FAULT_HEAD = {9: 3, 12: 6, 13: 4}


def now_str() -> str:
    return datetime.now(CST).strftime("%Y-%m-%d %H:%M:%S")


def load_stations(path: Path) -> list[dict]:
    stations: list[dict] = []
    with path.open(encoding="utf-8") as fp:
        for row in csv.DictReader(fp):
            row["device_ids"] = [str(item) for item in json.loads(row["device_ids"])]
            row["campus_id"] = int(row.get("campus") or 0)
            row["campus_name"] = CAMPUS_NAME.get(row["campus_id"], "其他")
            stations.append(row)
    return stations


def port_kind(code: str, idx0: int, devtypeid) -> str:
    if code in ("0", "6"):
        return "free"
    if code == "1":
        return "busy"
    if code == "3":
        return "float"
    if code == "4":
        return "storage"
    if code in FAULT_LABEL:
        try:
            head = FAULT_HEAD.get(int(devtypeid), 0)
        except (TypeError, ValueError):
            head = 0
        return "fault" if idx0 < head else "free"
    return "fault"


def parse_device(obj: dict) -> dict:
    raw = str(obj.get("portstatur") or "")
    port_size = int(obj.get("portSize") or len(raw) or 0)
    devtypeid = obj.get("devtypeid")
    ports: list[dict] = []
    counts = {"free": 0, "busy": 0, "float": 0, "storage": 0, "fault": 0}
    for idx, code in enumerate(raw, start=1):
        kind = port_kind(code, idx - 1, devtypeid)
        counts[kind] += 1
        label = (
            "空闲"
            if code in FAULT_LABEL and kind == "free"
            else STATUS_LABEL.get(code, "故障")
        )
        ports.append(
            {
                "no": idx,
                "code": code,
                "kind": kind,
                "status": label,
                "free": kind == "free",
            }
        )
    return {
        "devaddress": str(obj.get("devaddress")),
        "devtypeid": devtypeid,
        "devdescript": obj.get("devdescript"),
        "area_name": obj.get("areaName"),
        "work_time": obj.get("workTime"),
        "port_size": port_size,
        "raw": raw,
        "ports": ports,
        **counts,
    }


def parse_offline(devaddress: str, message: str) -> dict:
    return {
        "devaddress": devaddress,
        "devtypeid": None,
        "devdescript": None,
        "area_name": None,
        "work_time": None,
        "port_size": 0,
        "raw": "",
        "ports": [],
        "free": 0,
        "busy": 0,
        "float": 0,
        "storage": 0,
        "fault": 0,
        "offline": True,
        "offline_msg": message,
    }


def _parse_series(raw) -> dict[int, float]:
    out: dict[int, float] = {}
    if not raw or not isinstance(raw, str):
        return out
    body = raw.strip()
    if body.startswith("{"):
        body = body[1:]
    if body.endswith("}"):
        body = body[:-1]
    for pair in body.split(","):
        if ":" not in pair:
            continue
        key, _, value = pair.partition(":")
        try:
            out[int(key.strip())] = float(value.strip())
        except ValueError:
            continue
    return out


def _downsample(series: dict[int, float], max_points: int = 20) -> list[float]:
    keys = sorted(series)
    if not keys:
        return []
    if len(keys) <= max_points:
        return [round(series[key], 1) for key in keys]
    step = (len(keys) - 1) / (max_points - 1)
    picked = [keys[round(i * step)] for i in range(max_points)]
    return [round(series[key], 1) for key in picked]


def parse_tewlog(obj: dict) -> dict | None:
    power = _parse_series(obj.get("powerlog"))
    if not power:
        return None
    current = _parse_series(obj.get("electricurrentlog"))
    voltage = _parse_series(obj.get("elevlog"))
    energy = _parse_series(obj.get("eleconsumlog"))
    keys = sorted(power)
    t0, t1 = keys[0], keys[-1]

    def last(series: dict[int, float], divisor: float = 1.0):
        if not series:
            return None
        return round(series[sorted(series)[-1]] / divisor, 2)

    return {
        "w": round(power[t1]),
        "wmax": round(max(power.values())),
        "a": last(current, 10),
        "v": last(voltage, 100),
        "wh": last(energy) or 0,
        "mins": max(0, round((t1 - t0) / 60000)),
        "at": datetime.fromtimestamp(t1 / 1000, CST).strftime("%H:%M:%S"),
        "curve": _downsample(power),
    }


def build_station(
    station: dict,
    cache: dict[str, dict],
    power_map: dict[tuple[str, str], dict] | None = None,
) -> dict | None:
    power_map = power_map or {}
    devices: list[dict] = []
    for devaddress in station["device_ids"]:
        record = cache.get(devaddress)
        if record is None or not (record["ports"] or record.get("offline")):
            continue
        record = copy.deepcopy(record)
        for port in record["ports"]:
            telemetry = power_map.get((devaddress, f"{port['no']:02d}"))
            if telemetry:
                port["power"] = telemetry
        devices.append(record)
    if not devices:
        return None

    free = sum(device["free"] for device in devices)
    busy = sum(device["busy"] for device in devices)
    float_count = sum(device.get("float", 0) for device in devices)
    storage = sum(device.get("storage", 0) for device in devices)
    fault = sum(device.get("fault", 0) for device in devices)
    total = sum(device["port_size"] for device in devices)
    offline = sum(1 for device in devices if device.get("offline"))
    return {
        "name": station["name"],
        "provider": station["provider"],
        "campus_id": station["campus_id"],
        "campus_name": station["campus_name"],
        "lat": float(station["lat"]),
        "lon": float(station["lon"]),
        "free": free,
        "busy": busy,
        "float": float_count,
        "storage": storage,
        "fault": fault,
        "total": total,
        "offline": offline,
        "observed_at": now_str(),
        "devices": devices,
    }


def build_snapshot(
    stations: list[dict],
    cache: dict[str, dict],
    power_map: dict[tuple[str, str], dict] | None = None,
    area_id: int = 6,
) -> dict:
    records = [
        record
        for station in stations
        if (record := build_station(station, cache, power_map)) is not None
    ]
    return recalculate_snapshot(
        {
            "stations": records,
            "fetched_at": now_str(),
        },
        area_id=area_id,
    )


def recalculate_snapshot(snapshot: dict, area_id: int = 6) -> dict:
    stations = snapshot.get("stations") or []
    stations.sort(key=lambda item: (-item["free"], item["name"]))
    totals = {
        "free": 0,
        "busy": 0,
        "float": 0,
        "storage": 0,
        "fault": 0,
        "total": 0,
        "offline": 0,
    }
    power_ports = 0
    for station in stations:
        for key in totals:
            if key == "total":
                totals[key] += station["total"]
            elif key == "offline":
                totals[key] += station["offline"]
            else:
                totals[key] += station[key]
        for device in station["devices"]:
            power_ports += sum(1 for port in device["ports"] if "power" in port)

    campuses = sorted({station["campus_id"] for station in stations})
    scope = (
        f"全校（areaId={area_id}）"
        if len(campuses) > 1
        else (CAMPUS_NAME.get(campuses[0], "其他") if campuses else "")
    )
    return {
        "scope": scope,
        "campuses": [CAMPUS_NAME.get(campus, "其他") for campus in campuses],
        "fetched_at": snapshot.get("fetched_at") or now_str(),
        "station_count": len(stations),
        "device_count": sum(len(station["devices"]) for station in stations),
        "port_total": totals["total"],
        "port_free": totals["free"],
        "port_busy": totals["busy"],
        "port_float": totals["float"],
        "port_storage": totals["storage"],
        "port_fault": totals["fault"],
        "port_offline": totals["offline"],
        "power_ports": power_ports,
        "stations": stations,
    }


def unique_devices(stations: Iterable[dict]) -> list[str]:
    seen: dict[str, None] = {}
    for station in stations:
        for device in station["device_ids"]:
            seen.setdefault(device, None)
    return list(seen)


def power_jobs(cache: dict[str, dict]) -> list[tuple[str, str]]:
    float_jobs: list[tuple[str, str]] = []
    busy_jobs: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for devaddress, record in cache.items():
        if not record.get("ports"):
            continue
        for port in record["ports"]:
            kind = port.get("kind") or port_kind(
                port.get("code", ""),
                (port.get("no") or 1) - 1,
                record.get("devtypeid"),
            )
            if kind not in ("busy", "float"):
                continue
            key = (devaddress, f"{port['no']:02d}")
            if key in seen:
                continue
            seen.add(key)
            (float_jobs if kind == "float" else busy_jobs).append(key)
    return float_jobs + busy_jobs


class IntervalLimiter:
    def __init__(self, interval: float):
        self.interval = max(0.0, interval)
        self._queue: asyncio.PriorityQueue = asyncio.PriorityQueue()
        self._counter = 0
        self._worker: asyncio.Task | None = None
        self._worker_lock = asyncio.Lock()

    async def wait(self, priority: int = 10) -> None:
        if self.interval <= 0:
            return
        loop = asyncio.get_running_loop()
        future = loop.create_future()
        self._counter += 1
        await self._queue.put((priority, self._counter, future))
        await self._ensure_worker()
        await future

    async def _ensure_worker(self) -> None:
        async with self._worker_lock:
            if self._worker is None or self._worker.done():
                self._worker = asyncio.create_task(self._run())

    async def _run(self) -> None:
        while True:
            _, _, future = await self._queue.get()
            if not future.done():
                future.set_result(True)
            await asyncio.sleep(self.interval)

    async def close(self) -> None:
        if self._worker is not None:
            self._worker.cancel()
            await asyncio.gather(self._worker, return_exceptions=True)
            self._worker = None


class UpstreamClient:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._client = httpx.AsyncClient(
            timeout=settings.request_timeout,
            follow_redirects=True,
            headers={
                "User-Agent": settings.user_agent,
                "Host": "www.szlzxn.cn",
                "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            },
        )
        self._device_limiter = IntervalLimiter(settings.device_interval)
        self._power_limiter = IntervalLimiter(settings.power_interval)
        self.throttled = 0

    async def close(self) -> None:
        await self._device_limiter.close()
        await self._power_limiter.close()
        await self._client.aclose()

    async def _request(self, url: str, data: dict) -> dict:
        response = await self._client.post(url, data=data)
        response.raise_for_status()
        return response.json()

    async def fetch_device(
        self,
        devaddress: str,
        priority: int = 10,
    ) -> tuple[dict | None, str | None]:
        data = {"areaId": self.settings.area_id, "devaddress": devaddress}
        wait = 5.0
        last_message = None
        for attempt in range(self.settings.max_retries):
            await self._device_limiter.wait(priority)
            try:
                payload = await self._request(self.settings.upstream_device_url, data)
            except Exception as exc:
                log.warning("%s network error: %s", devaddress, exc)
                await asyncio.sleep(wait)
                wait = min(wait * 2, 60)
                continue

            if payload.get("success") in (True, "true", 1) and isinstance(
                payload.get("obj"), dict
            ):
                return payload["obj"], None
            message = payload.get("msg") or ""
            last_message = message
            if "参数错误" in message:
                self.throttled += 1
                log.warning(
                    "%s throttled (%s), retry %s/%s",
                    devaddress,
                    message,
                    attempt + 1,
                    self.settings.max_retries,
                )
            elif "离线" in message:
                return None, "offline"
            else:
                log.warning("%s rejected: %s", devaddress, message)
                return None, "error"
            await asyncio.sleep(wait)
            wait = min(wait * 2, 60)
        return None, "error" if last_message else None

    async def fetch_power(
        self,
        devaddress: str,
        port: str,
        priority: int = 10,
    ) -> tuple[dict | None, str | None]:
        data = {"devaddress": devaddress, "devport": port}
        wait = 5.0
        last_message = None
        for attempt in range(self.settings.max_retries):
            await self._power_limiter.wait(priority)
            try:
                payload = await self._request(self.settings.upstream_power_url, data)
            except Exception as exc:
                log.warning("%s/%s telemetry network error: %s", devaddress, port, exc)
                await asyncio.sleep(wait)
                wait = min(wait * 2, 60)
                continue
            if payload.get("success") in (True, "true", 1) and isinstance(
                payload.get("obj"), dict
            ):
                return payload["obj"], None
            message = payload.get("msg") or ""
            last_message = message
            if "参数错误" in message:
                self.throttled += 1
                log.warning(
                    "%s/%s telemetry throttled (%s), retry %s/%s",
                    devaddress,
                    port,
                    message,
                    attempt + 1,
                    self.settings.max_retries,
                )
            else:
                log.warning("%s/%s telemetry rejected: %s", devaddress, port, message)
                return None, "error"
            await asyncio.sleep(wait)
            wait = min(wait * 2, 60)
        return None, "error" if last_message else None

    async def refresh_all(self, stations: list[dict]) -> tuple[dict, dict]:
        devices = unique_devices(stations)
        cache: dict[str, dict] = {}
        log.info("full refresh start: %s stations, %s devices", len(stations), len(devices))
        for index, devaddress in enumerate(devices, start=1):
            obj, error = await self.fetch_device(devaddress)
            if obj:
                cache[devaddress] = parse_device(obj)
            elif error == "offline":
                cache[devaddress] = parse_offline(devaddress, "设备离线")
            if index % 10 == 0 or index == len(devices):
                log.info("status %s/%s", index, len(devices))

        jobs = power_jobs(cache)[: self.settings.power_limit]
        power_map: dict[tuple[str, str], dict] = {}
        for index, (devaddress, port) in enumerate(jobs, start=1):
            obj, _ = await self.fetch_power(devaddress, port)
            if obj:
                parsed = parse_tewlog(obj)
                if parsed:
                    power_map[(devaddress, port)] = parsed
            if index % 25 == 0 or index == len(jobs):
                log.info("power %s/%s", index, len(jobs))

        snapshot = build_snapshot(
            stations,
            cache,
            power_map,
            area_id=self.settings.area_id,
        )
        stats = {
            "devices_ok": len(cache),
            "power_ports": len(power_map),
            "throttled": self.throttled,
        }
        log.info(
            "full refresh done: %s devices, %s power ports, %s throttled",
            len(cache),
            len(power_map),
            self.throttled,
        )
        return snapshot, stats

    async def refresh_station(self, station: dict) -> tuple[dict | None, int]:
        cache: dict[str, dict] = {}
        for devaddress in station["device_ids"]:
            obj, error = await self.fetch_device(devaddress, priority=0)
            if obj:
                cache[devaddress] = parse_device(obj)
            elif error == "offline":
                cache[devaddress] = parse_offline(devaddress, "设备离线")
        jobs = power_jobs(cache)[: self.settings.station_power_limit]
        power_map: dict[tuple[str, str], dict] = {}
        for devaddress, port in jobs:
            obj, _ = await self.fetch_power(devaddress, port, priority=0)
            if obj:
                parsed = parse_tewlog(obj)
                if parsed:
                    power_map[(devaddress, port)] = parsed
        return build_station(station, cache, power_map), len(power_map)
