from __future__ import annotations

from dataclasses import replace
from datetime import datetime, timedelta

import pytest

from app.config import settings
from app.provider import CST
from app.push import PushNotifier
from app.push_store import PushStore


class FakeSender:
    def __init__(self, ok: bool = True):
        self.ok = ok
        self.sent = []

    async def send(self, subscriber, title, body, extras) -> bool:
        self.sent.append((subscriber, title, body, extras))
        return self.ok


def station_snapshot(fetched_at: str, kinds: dict[int, str]) -> dict:
    return {
        "fetched_at": fetched_at,
        "stations": [
            {
                "name": "紫金港玉湖",
                "observed_at": fetched_at,
                "devices": [
                    {
                        "devaddress": "dev-1",
                        "ports": [
                            {"no": number, "kind": kind}
                            for number, kind in kinds.items()
                        ],
                    }
                ],
            }
        ],
    }


def current_time() -> str:
    return datetime.now(CST).strftime("%Y-%m-%d %H:%M:%S")


@pytest.fixture
def store(tmp_path):
    store = PushStore(tmp_path / "push.db")
    store.init()
    return store


@pytest.mark.asyncio
async def test_free_transition_sends_once(store):
    store.upsert_device("device-123", "android", "token-1", ["紫金港玉湖"])
    sender = FakeSender()
    notifier = PushNotifier(
        replace(settings, push_cooldown_seconds=600, push_stale_seconds=900),
        store,
        sender,
    )
    old = station_snapshot(current_time(), {1: "busy", 2: "free"})
    new = station_snapshot(current_time(), {1: "free", 2: "free"})
    await notifier.on_snapshot(old, new)
    assert len(sender.sent) == 1
    assert "紫金港玉湖" in sender.sent[0][2]
    await notifier.on_snapshot(old, new)
    assert len(sender.sent) == 1


@pytest.mark.asyncio
async def test_stale_previous_snapshot_is_ignored(store):
    store.upsert_device("device-123", "android", "token-1", ["紫金港玉湖"])
    sender = FakeSender()
    notifier = PushNotifier(
        replace(settings, push_cooldown_seconds=600, push_stale_seconds=900),
        store,
        sender,
    )
    old_time = (datetime.now(CST) - timedelta(minutes=20)).strftime(
        "%Y-%m-%d %H:%M:%S"
    )
    old = station_snapshot(old_time, {1: "busy"})
    new = station_snapshot(current_time(), {1: "free"})
    await notifier.on_snapshot(old, new)
    assert sender.sent == []


@pytest.mark.asyncio
async def test_station_refresh_only_checks_requested_station(store):
    store.upsert_device("device-123", "android", "token-1", ["紫金港玉湖"])
    sender = FakeSender()
    notifier = PushNotifier(
        replace(settings, push_cooldown_seconds=600, push_stale_seconds=900),
        store,
        sender,
    )
    old = station_snapshot(current_time(), {1: "busy"})
    new = station_snapshot(current_time(), {1: "free"})
    await notifier.on_snapshot(old, new, "不存在的站点")
    assert sender.sent == []
    await notifier.on_snapshot(old, new, "紫金港玉湖")
    assert len(sender.sent) == 1


def test_push_store_replace_and_delete(store):
    assert store.upsert_device("device-123", "ios", "token-1", ["A", "B"]) == 2
    subscribers = store.subscribers("A")
    assert len(subscribers) == 1
    assert subscribers[0]["push_token"] == "token-1"
    store.mark_notified("device-123", "A")
    assert store.subscribers("A")[0]["last_notified_at"] is not None

    assert store.upsert_device("device-123", "ios", "token-2", ["B", "C"]) == 2
    assert store.subscribers("A") == []
    assert len(store.subscribers("B")) == 1
    assert len(store.subscribers("C")) == 1
    assert store.device_count() == 1
    assert store.subscription_count() == 2

    store.delete_device("device-123")
    assert store.device_count() == 0
    assert store.subscription_count() == 0
