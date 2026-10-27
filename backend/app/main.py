from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import Literal

from .collector import Collector
from .config import settings
from .provider import UpstreamClient
from .push import PushNotifier, build_sender
from .push_store import PushStore
from .store import SnapshotStore

logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
log = logging.getLogger(__name__)
logging.getLogger("httpx").setLevel(logging.WARNING)


@asynccontextmanager
async def lifespan(app: FastAPI):
    store = SnapshotStore(settings.snapshot_path)
    store.init()
    push_store = PushStore(settings.push_db_path)
    push_store.init()
    client = UpstreamClient(settings)
    collector = Collector(settings, client, store)
    notifier = PushNotifier(settings, push_store, build_sender(settings))
    collector.add_snapshot_listener(notifier.on_snapshot)
    await collector.start()
    app.state.collector = collector
    app.state.push_store = push_store
    app.state.push_notifier = notifier
    app.state.settings = settings
    try:
        yield
    finally:
        await collector.stop()
        await app.state.push_notifier.close()


app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"]
    if settings.cors_origins == "*"
    else settings.cors_origins.split(","),
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def collector_of(request: Request) -> Collector:
    return request.app.state.collector


def require_snapshot(collector: Collector) -> dict:
    if not collector.current:
        raise HTTPException(status_code=503, detail="快照尚未生成")
    return collector.current


@app.get("/")
async def root():
    return {
        "name": settings.app_name,
        "version": settings.version,
        "docs": "/docs",
        "snapshot": "/v1/snapshot",
    }


@app.get("/healthz")
async def healthz(request: Request):
    collector = collector_of(request)
    return {
        "ok": True,
        "ready": collector.current is not None,
        "snapshot_age": collector.snapshot_age_seconds(),
        "refresh": collector.refresh_status()["full"],
    }


@app.get("/v1/meta")
async def meta(request: Request):
    collector = collector_of(request)
    payload = collector.meta()
    payload["refresh"] = collector.refresh_status()
    push_store: PushStore = request.app.state.push_store
    payload["push"] = {
        "enabled": settings.push_enabled,
        "devices": push_store.device_count(),
        "subscriptions": push_store.subscription_count(),
    }
    return payload


@app.get("/v1/snapshot")
async def snapshot(request: Request):
    collector = collector_of(request)
    current = require_snapshot(collector)
    return JSONResponse(
        content=current,
        headers={"Cache-Control": "no-store"},
    )


@app.post("/v1/stations/{name}/refresh", status_code=202)
async def refresh_station(name: str, request: Request):
    collector = collector_of(request)
    require_snapshot(collector)
    ok, message = collector.start_station_refresh(name)
    if not ok:
        status = 404 if message == "站点不存在" else 429
        raise HTTPException(status_code=status, detail=message)
    return {
        "ok": True,
        "msg": message,
        "station": name,
        "status": collector.refresh_status()["stations"].get(name),
    }


class DeviceRegistration(BaseModel):
    platform: Literal["android", "ios", "ohos", "unknown"] = "unknown"
    push_token: str = Field(min_length=1, max_length=512)
    station_names: list[str] = Field(default_factory=list, max_length=100)


@app.put("/v1/devices/{device_id}")
async def register_device(
    device_id: str,
    payload: DeviceRegistration,
    request: Request,
):
    collector = collector_of(request)
    current = require_snapshot(collector)
    valid_names = {station["name"] for station in current["stations"]}
    names = list(dict.fromkeys(name for name in payload.station_names if name))
    invalid = [name for name in names if name not in valid_names]
    if invalid:
        raise HTTPException(
            status_code=400,
            detail={"error": "站点不存在", "stations": invalid},
        )
    if not 8 <= len(device_id) <= 64:
        raise HTTPException(status_code=400, detail="device_id 长度不合法")
    push_store: PushStore = request.app.state.push_store
    count = push_store.upsert_device(
        device_id=device_id,
        platform=payload.platform,
        push_token=payload.push_token,
        station_names=names,
    )
    return {
        "ok": True,
        "device_id": device_id,
        "subscriptions": count,
        "push_enabled": settings.push_enabled,
    }


@app.delete("/v1/devices/{device_id}")
async def unregister_device(device_id: str, request: Request):
    push_store: PushStore = request.app.state.push_store
    push_store.delete_device(device_id)
    return {"ok": True, "device_id": device_id}
