from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query, Request, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .collector import Collector
from .config import settings
from .hub import WebSocketHub
from .provider import UpstreamClient, parse_tewlog
from .store import SnapshotStore

logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
log = logging.getLogger(__name__)
logging.getLogger("httpx").setLevel(logging.WARNING)


@asynccontextmanager
async def lifespan(app: FastAPI):
    store = SnapshotStore(settings.db_path, settings.snapshot_path)
    store.init()
    client = UpstreamClient(settings)
    hub = WebSocketHub()
    collector = Collector(settings, client, store, hub)
    await collector.start()
    app.state.collector = collector
    app.state.hub = hub
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
    allow_origins=["*"] if settings.cors_origins == "*" else settings.cors_origins.split(","),
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
        "stations": "/v1/stations",
    }


@app.get("/healthz")
async def healthz(request: Request):
    collector = collector_of(request)
    return {
        "ok": True,
        "ready": collector.current is not None,
        "snapshot_age": collector.snapshot_age_seconds(),
        "refresh": collector.status_payload()["full"],
    }


@app.get("/v1/meta")
async def meta(request: Request):
    collector = collector_of(request)
    payload = collector.meta()
    payload["full_refresh"] = collector.status_payload()["full"]
    return payload


@app.get("/v1/snapshot")
async def snapshot(request: Request):
    collector = collector_of(request)
    current = require_snapshot(collector)
    return JSONResponse(
        content=current,
        headers={"Cache-Control": "no-store"},
    )


@app.get("/v1/stations")
async def stations(request: Request):
    collector = collector_of(request)
    require_snapshot(collector)
    return {
        "ok": True,
        **collector.meta(),
        "stations": collector.station_summaries(),
    }


@app.get("/v1/stations/{name}")
async def station_detail(name: str, request: Request):
    collector = collector_of(request)
    require_snapshot(collector)
    station = collector.get_station(name)
    if station is None:
        raise HTTPException(status_code=404, detail="站点不存在")
    return {
        "ok": True,
        "fetched_at": collector.current["fetched_at"],
        "age_seconds": collector.snapshot_age_seconds(),
        "station": station,
        "refresh": collector.status_payload()["stations"].get(name),
    }


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
        "status": collector.status_payload()["stations"].get(name),
    }


@app.post("/v1/refresh", status_code=202)
async def refresh_all(request: Request):
    collector = collector_of(request)
    ok, message = collector.start_full_refresh()
    if not ok:
        raise HTTPException(status_code=429, detail=message)
    return {"ok": True, "msg": message, "status": collector.status_payload()["full"]}


@app.get("/v1/status")
async def status(request: Request):
    collector = collector_of(request)
    return {"ok": True, "status": collector.status_payload(), "meta": collector.meta()}


@app.get("/v1/power")
async def power(
    request: Request,
    devaddress: str = Query(..., min_length=1),
    port: str = Query(""),
):
    collector = collector_of(request)
    current = require_snapshot(collector)
    device = None
    for station in current["stations"]:
        for item in station["devices"]:
            if item["devaddress"] == devaddress:
                device = item
                break
        if device:
            break
    if device is None:
        raise HTTPException(status_code=404, detail="设备不在当前快照中")
    ports = [
        f"{item['no']:02d}"
        for item in device["ports"]
        if item["kind"] in ("busy", "float")
    ]
    if port:
        ports = [port]
    ports = ports[:16]
    power_map = {}
    for port_no in ports:
        obj, error = await collector.client.fetch_power(devaddress, port_no)
        if obj:
            parsed = parse_tewlog(obj)
            if parsed:
                power_map[port_no] = parsed
        elif error:
            log.warning("power failed %s/%s: %s", devaddress, port_no, error)
    return {
        "ok": True,
        "devaddress": devaddress,
        "at": collector.current.get("fetched_at"),
        "power": power_map,
    }


@app.websocket("/v1/stream")
async def stream(websocket: WebSocket):
    hub: WebSocketHub = websocket.app.state.hub
    collector: Collector = websocket.app.state.collector
    await hub.connect(websocket)
    try:
        await websocket.send_json(
            {
                "type": "hello",
                "meta": collector.meta(),
            }
        )
        while True:
            await websocket.receive_text()
    except Exception:
        pass
    finally:
        await hub.disconnect(websocket)
