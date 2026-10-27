from __future__ import annotations

from datetime import datetime, timedelta

from app.collector import Collector
from app.config import settings
from app.provider import CST


def station(observed_at: str, free: int) -> dict:
    return {
        "name": "测试站",
        "provider": "test",
        "campus_id": 2,
        "campus_name": "紫金港校区",
        "lat": 30.3,
        "lon": 120.09,
        "free": free,
        "busy": 0,
        "float": 0,
        "storage": 0,
        "fault": 0,
        "total": 1,
        "offline": 0,
        "observed_at": observed_at,
        "devices": [],
    }


def test_full_refresh_preserves_newer_station():
    collector = Collector(settings, None, None)
    now = datetime.now(CST)
    newer = (now - timedelta(seconds=10)).strftime("%Y-%m-%d %H:%M:%S")
    older = (now - timedelta(minutes=2)).strftime("%Y-%m-%d %H:%M:%S")
    collector.current = {
        "fetched_at": older,
        "stations": [station(newer, 1)],
    }
    full = {
        "fetched_at": now.strftime("%Y-%m-%d %H:%M:%S"),
        "stations": [station(older, 0)],
    }
    merged = collector._preserve_newer_stations(full, now - timedelta(minutes=1))
    assert merged["stations"][0]["observed_at"] == newer
    assert merged["port_free"] == 1
