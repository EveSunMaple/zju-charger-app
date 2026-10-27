from __future__ import annotations

import json

from app.config import settings
from app.provider import (
    build_snapshot,
    load_stations,
    parse_device,
    parse_tewlog,
    port_kind,
    unique_devices,
)


def test_port_kind_fault_head_logic():
    assert port_kind("0", 0, 9) == "free"
    assert port_kind("6", 7, 40) == "free"
    assert port_kind("1", 0, 9) == "busy"
    assert port_kind("3", 0, 9) == "float"
    assert port_kind("4", 0, 9) == "storage"
    assert port_kind("7", 0, 9) == "fault"
    assert port_kind("7", 3, 9) == "free"
    assert port_kind("8", 5, 13) == "free"


def test_parse_device_counts_and_port_numbers():
    obj = {
        "devaddress": "demo",
        "devtypeid": 9,
        "portstatur": "0163",
        "portSize": 4,
        "devdescript": "测试设备",
    }
    parsed = parse_device(obj)
    assert parsed["port_size"] == 4
    assert [port["no"] for port in parsed["ports"]] == [1, 2, 3, 4]
    assert [port["kind"] for port in parsed["ports"]] == [
        "free",
        "busy",
        "free",
        "float",
    ]
    assert parsed["free"] == 2
    assert parsed["busy"] == 1
    assert parsed["float"] == 1


def test_parse_tewlog_units_and_curve():
    obj = {
        "powerlog": "{1000:10,2000:20,3000:30}",
        "electricurrentlog": "{1000:10,2000:20,3000:15}",
        "elevlog": "{1000:22000,2000:22100,3000:22200}",
        "eleconsumlog": "{1000:100,2000:200,3000:300}",
    }
    parsed = parse_tewlog(obj)
    assert parsed is not None
    assert parsed["w"] == 30
    assert parsed["wmax"] == 30
    assert parsed["a"] == 1.5
    assert parsed["v"] == 222
    assert parsed["wh"] == 300
    assert parsed["mins"] == 0
    assert parsed["curve"] == [10, 20, 30]


def test_seed_snapshot_counts_match_registry():
    stations = load_stations(settings.stations_csv)
    seed = json.loads(settings.seed_snapshot.read_text(encoding="utf-8"))
    cache = {
        device["devaddress"]: device
        for station in seed["stations"]
        for device in station["devices"]
    }
    built = build_snapshot(stations, cache, area_id=settings.area_id)
    assert built["station_count"] == 35
    assert built["port_total"] == 1644
    assert built["port_free"] == 481
    assert built["port_busy"] == 1121
    assert built["port_float"] == 42
    assert len(unique_devices(stations)) == 135
