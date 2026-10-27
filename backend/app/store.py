from __future__ import annotations

import json
import sqlite3
from pathlib import Path


class SnapshotStore:
    def __init__(self, db_path: Path, snapshot_path: Path):
        self.db_path = db_path
        self.snapshot_path = snapshot_path

    def init(self) -> None:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS snapshots (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    fetched_at TEXT NOT NULL,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    payload TEXT NOT NULL
                )
                """
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_snapshots_fetched "
                "ON snapshots(fetched_at)"
            )
            conn.commit()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=15)
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA synchronous=NORMAL")
        return conn

    def save(self, snapshot: dict) -> None:
        payload = json.dumps(snapshot, ensure_ascii=False, separators=(",", ":"))
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO snapshots(fetched_at, payload) VALUES (?, ?)",
                (snapshot.get("fetched_at", ""), payload),
            )
            conn.execute(
                "DELETE FROM snapshots WHERE id NOT IN "
                "(SELECT id FROM snapshots ORDER BY id DESC LIMIT 200)"
            )
            conn.commit()
        self._write_file(payload)

    def latest(self) -> dict | None:
        if not self.db_path.exists():
            return None
        with self._connect() as conn:
            row = conn.execute(
                "SELECT payload FROM snapshots ORDER BY id DESC LIMIT 1"
            ).fetchone()
        if row is None:
            return None
        return json.loads(row[0])

    def seed(self, path: Path) -> dict | None:
        if not path.exists():
            return None
        snapshot = json.loads(path.read_text(encoding="utf-8"))
        self.save(snapshot)
        return snapshot

    def _write_file(self, payload: str) -> None:
        self.snapshot_path.parent.mkdir(parents=True, exist_ok=True)
        temp = self.snapshot_path.with_suffix(".json.tmp")
        temp.write_text(payload, encoding="utf-8")
        temp.replace(self.snapshot_path)
