from __future__ import annotations

import json

from app.store import SnapshotStore


def test_store_round_trip(tmp_path):
    store = SnapshotStore(tmp_path / "snapshot.json")
    store.init()
    snapshot = {"fetched_at": "2026-10-27 10:00:00", "stations": [], "port_total": 1}
    store.save(snapshot)
    latest = store.latest()
    assert latest == snapshot
    assert json.loads((tmp_path / "snapshot.json").read_text()) == snapshot
    assert not (tmp_path / "snapshot.json.tmp").exists()


def test_store_seed(tmp_path):
    seed = tmp_path / "seed.json"
    seed.write_text(json.dumps({"fetched_at": "seed", "stations": []}), encoding="utf-8")
    store = SnapshotStore(tmp_path / "snapshot.json")
    store.init()
    loaded = store.seed(seed)
    assert loaded is not None
    assert store.latest()["fetched_at"] == "seed"
