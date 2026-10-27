from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .collector import Collector
from .config import settings
from .provider import UpstreamClient
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
    client = UpstreamClient(settings)
    collector = Collector(settings, client, store)
    await collector.start()
    app.state.collector = collector
    app.state.settings = settings
    try:
        yield
    finally:
        await collector.stop()


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
