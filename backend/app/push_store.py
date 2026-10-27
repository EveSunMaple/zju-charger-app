from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path


class PushStore:
    def __init__(self, db_path: Path):
        self.db_path = db_path

    def init(self) -> None:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS devices (
                    device_id TEXT PRIMARY KEY,
                    platform TEXT NOT NULL,
                    push_token TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS subscriptions (
                    device_id TEXT NOT NULL,
                    station_name TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    last_notified_at TEXT,
                    PRIMARY KEY(device_id, station_name),
                    FOREIGN KEY(device_id) REFERENCES devices(device_id)
                        ON DELETE CASCADE
                )
                """
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_subscriptions_station "
                "ON subscriptions(station_name)"
            )
            conn.commit()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=15)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA foreign_keys=ON")
        return conn

    def upsert_device(
        self,
        device_id: str,
        platform: str,
        push_token: str,
        station_names: list[str],
    ) -> int:
        now = datetime.now(timezone.utc).isoformat()
        unique_names = list(dict.fromkeys(station_names))
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO devices(device_id, platform, push_token, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(device_id) DO UPDATE SET
                    platform = excluded.platform,
                    push_token = excluded.push_token,
                    updated_at = excluded.updated_at
                """,
                (device_id, platform, push_token, now, now),
            )
            existing = {
                row["station_name"]: row["last_notified_at"]
                for row in conn.execute(
                    "SELECT station_name, last_notified_at FROM subscriptions "
                    "WHERE device_id = ?",
                    (device_id,),
                )
            }
            if unique_names:
                placeholders = ",".join("?" for _ in unique_names)
                conn.execute(
                    f"DELETE FROM subscriptions WHERE device_id = ? "
                    f"AND station_name NOT IN ({placeholders})",
                    (device_id, *unique_names),
                )
            else:
                conn.execute(
                    "DELETE FROM subscriptions WHERE device_id = ?",
                    (device_id,),
                )
            for name in unique_names:
                conn.execute(
                    """
                    INSERT INTO subscriptions(device_id, station_name, created_at, last_notified_at)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(device_id, station_name) DO NOTHING
                    """,
                    (device_id, name, now, existing.get(name)),
                )
            conn.commit()
        return len(unique_names)

    def delete_device(self, device_id: str) -> None:
        with self._connect() as conn:
            conn.execute("DELETE FROM subscriptions WHERE device_id = ?", (device_id,))
            conn.execute("DELETE FROM devices WHERE device_id = ?", (device_id,))
            conn.commit()

    def subscribers(self, station_name: str) -> list[dict]:
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT d.device_id, d.platform, d.push_token, s.last_notified_at
                FROM subscriptions s
                JOIN devices d ON d.device_id = s.device_id
                WHERE s.station_name = ? AND d.push_token <> ''
                """,
                (station_name,),
            ).fetchall()
        return [dict(row) for row in rows]

    def mark_notified(self, device_id: str, station_name: str) -> None:
        now = datetime.now(timezone.utc).isoformat()
        with self._connect() as conn:
            conn.execute(
                "UPDATE subscriptions SET last_notified_at = ? "
                "WHERE device_id = ? AND station_name = ?",
                (now, device_id, station_name),
            )
            conn.commit()

    def subscription_count(self) -> int:
        with self._connect() as conn:
            row = conn.execute("SELECT COUNT(*) AS count FROM subscriptions").fetchone()
        return int(row["count"]) if row else 0

    def device_count(self) -> int:
        with self._connect() as conn:
            row = conn.execute("SELECT COUNT(*) AS count FROM devices").fetchone()
        return int(row["count"]) if row else 0

    def clear(self) -> None:
        with self._connect() as conn:
            conn.execute("DELETE FROM subscriptions")
            conn.execute("DELETE FROM devices")
            conn.commit()
