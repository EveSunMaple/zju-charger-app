from __future__ import annotations

import json
from pathlib import Path


class SnapshotStore:
    def __init__(self, snapshot_path: Path):
        self.snapshot_path = snapshot_path

    def init(self) -> None:
        self.snapshot_path.parent.mkdir(parents=True, exist_ok=True)

    def save(self, snapshot: dict) -> None:
        payload = json.dumps(snapshot, ensure_ascii=False, separators=(",", ":"))
        temp = self.snapshot_path.with_suffix(".json.tmp")
        temp.write_text(payload, encoding="utf-8")
        temp.replace(self.snapshot_path)

    def latest(self) -> dict | None:
        if not self.snapshot_path.exists():
            return None
        try:
            return json.loads(self.snapshot_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None

    def seed(self, path: Path) -> dict | None:
        if not path.exists():
            return None
        snapshot = json.loads(path.read_text(encoding="utf-8"))
        self.save(snapshot)
        return snapshot
