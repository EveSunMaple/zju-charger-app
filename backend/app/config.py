from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        return default


def _env_float(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, str(default)))
    except ValueError:
        return default


@dataclass(frozen=True)
class Settings:
    app_name: str = "ZJU Charger API"
    version: str = "0.1.0"
    host: str = os.getenv("APP_HOST", "0.0.0.0")
    port: int = _env_int("APP_PORT", 8000)
    log_level: str = os.getenv("LOG_LEVEL", "INFO")

    area_id: int = _env_int("AREA_ID", 6)
    upstream_device_url: str = os.getenv(
        "UPSTREAM_DEVICE_URL",
        "http://www.szlzxn.cn/wxn/getDeviceInfo",
    )
    upstream_power_url: str = os.getenv(
        "UPSTREAM_POWER_URL",
        "http://www.szlzxn.cn/wxn/selectTewlog",
    )
    user_agent: str = os.getenv(
        "UPSTREAM_USER_AGENT",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) "
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 "
        "MicroMessenger/8.0.60(0x18003c2f) NetType/WIFI Language/zh_CN",
    )
    request_timeout: float = _env_float("UPSTREAM_TIMEOUT", 15.0)
    max_retries: int = _env_int("UPSTREAM_MAX_RETRIES", 6)
    device_interval: float = _env_float("UPSTREAM_DEVICE_INTERVAL", 1.2)
    power_interval: float = _env_float("UPSTREAM_POWER_INTERVAL", 0.25)

    refresh_interval: int = _env_int("REFRESH_INTERVAL_SECONDS", 60)
    power_limit: int = _env_int("POWER_PORT_LIMIT", 200)
    station_power_limit: int = _env_int("STATION_POWER_PORT_LIMIT", 24)
    station_cooldown: int = _env_int("STATION_REFRESH_COOLDOWN_SECONDS", 30)
    full_cooldown: int = _env_int("FULL_REFRESH_COOLDOWN_SECONDS", 90)

    data_dir: Path = Path(os.getenv("DATA_DIR", str(BASE_DIR / "data")))
    db_path: Path = Path(os.getenv("DB_PATH", str(BASE_DIR / "data" / "state.db")))
    snapshot_path: Path = Path(
        os.getenv("SNAPSHOT_PATH", str(BASE_DIR / "data" / "snapshot.json"))
    )
    stations_csv: Path = Path(
        os.getenv("STATIONS_CSV", str(BASE_DIR / "data" / "stations_all.csv"))
    )
    seed_snapshot: Path = Path(
        os.getenv("SEED_SNAPSHOT", str(BASE_DIR / "data" / "seed_snapshot.json"))
    )
    cors_origins: str = os.getenv("CORS_ORIGINS", "*")


settings = Settings()
