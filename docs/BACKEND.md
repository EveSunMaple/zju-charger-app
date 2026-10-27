# 后端与实时数据

## 架构

```text
Flutter App
   │  GET /v1/snapshot
   ▼
FastAPI 数据网关
   ├─ 全量刷新任务
   ├─ 单站刷新任务
   ├─ SQLite 快照存储
   └─ WebSocket 广播
        │ 服务端口 HTTP，1.2s 串行限流
        ▼
量子新能上游
   getDeviceInfo / selectTewlog
```

客户端不直接访问上游，所有抓取、限流、状态解析都在服务端完成。

## 数据流

1. 服务启动时优先读取 SQLite 最新快照；没有则读取 `data/seed_snapshot.json`。
2. 后台任务立即做一次全量扫描：135 台去重设备，设备间隔 1.2s，约 3 分钟。
3. 状态扫描完成后抓取在充/浮充端口功率，最多 200 口，间隔 0.25s。
4. 快照写入 SQLite，并同步写入 `data/snapshot.json` 方便排查。
5. 全量任务完成后等待 60 秒再开始下一轮；数据年龄通常不超过约 4 分钟。
6. 单站刷新约 10-15 秒，冷却 30 秒；刷新结果合并回当前全量快照。

## 接口

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/healthz` | 健康检查、快照年龄、刷新状态 |
| GET | `/v1/meta` | 站点/设备/插口汇总、数据年龄 |
| GET | `/v1/snapshot` | 完整快照，字段与客户端离线快照一致 |
| GET | `/v1/stations` | 站点摘要列表 |
| GET | `/v1/stations/{name}` | 单站完整设备/插口数据 |
| POST | `/v1/stations/{name}/refresh` | 异步刷新单站，202 |
| POST | `/v1/refresh` | 异步全量刷新，202 |
| GET | `/v1/status` | 全量与单站刷新状态 |
| GET | `/v1/power?devaddress=...&port=...` | 实时功率遥测 |
| WS | `/v1/stream` | 刷新完成广播 |
| GET | `/docs` | Swagger 文档 |

站点名包含中文时，客户端需要 URL 编码。示例：

```bash
curl http://127.0.0.1:8000/v1/snapshot
curl "http://127.0.0.1:8000/v1/stations/%E7%B4%AB%E9%87%91%E6%B8%AF%E7%8E%89%E6%B9%96"
curl -X POST "http://127.0.0.1:8000/v1/stations/%E7%B4%AB%E9%87%91%E6%B8%AF%E7%8E%89%E6%B9%96/refresh"
```

## 本地运行

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
cp .env.example .env
.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

验证：

```bash
curl http://127.0.0.1:8000/healthz
curl http://127.0.0.1:8000/v1/meta
cd backend && .venv/bin/pytest -q
```

首次启动若数据库为空，会先使用种子快照；后台全量刷新完成后数据年龄会归零。

## 客户端接入

客户端通过编译参数指定 API：

```bash
# Android 模拟器访问宿主机
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000

# iOS 模拟器
flutter run -d "iPhone 18 Pro" \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

未设置 `API_BASE_URL` 或请求失败时，客户端自动回退到 `assets/data/snapshot.json`，顶栏显示「快照」；API 成功时显示「数据」。客户端每 30 秒静默同步一次，刷新按钮会重新拉取 `/v1/snapshot`。

Android debug 包允许 cleartext HTTP；正式环境必须使用 HTTPS。

## 配置

复制 `backend/.env.example` 为 `backend/.env`：

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `APP_PORT` | 8000 | API 端口 |
| `AREA_ID` | 6 | 浙大区域号 |
| `UPSTREAM_DEVICE_INTERVAL` | 1.2 | 设备请求间隔秒 |
| `UPSTREAM_POWER_INTERVAL` | 0.25 | 功率请求间隔秒 |
| `REFRESH_INTERVAL_SECONDS` | 60 | 全量轮次间隔 |
| `POWER_PORT_LIMIT` | 200 | 全量功率巡检上限 |
| `STATION_POWER_PORT_LIMIT` | 24 | 单站功率巡检上限 |
| `STATION_REFRESH_COOLDOWN_SECONDS` | 30 | 单站刷新冷却 |
| `FULL_REFRESH_COOLDOWN_SECONDS` | 90 | 全量刷新冷却 |
| `DATA_DIR` | ./data | 数据目录 |
| `DB_PATH` | ./data/state.db | SQLite 路径 |
| `SEED_SNAPSHOT` | ./data/seed_snapshot.json | 种子快照 |

## 部署

本机未安装 Docker，容器构建未在本机执行；本地 venv + uvicorn 已验证。服务器上首次部署时先构建并查看日志。

```bash
cd infra
cp ../backend/.env.example ../backend/.env
docker compose up -d --build
docker compose logs -f api
```

建议只暴露 80/443，API 8000 仅监听本机或容器网络。用 Caddy/Nginx 终止 HTTPS：

```text
charger.example.com {
    encode gzip
    reverse_proxy 127.0.0.1:8000
}
```

生产检查：

```bash
curl https://charger.example.com/healthz
curl https://charger.example.com/v1/meta
docker compose logs -f api
```

数据备份：备份 `backend/data/state.db` 即可；`snapshot.json` 是可读镜像。

## 已知限制

- 上游是未公开接口，可能变更或限流；当前按 1.2s 串行、指数退避处理。
- 全量刷新约 3-4 分钟，不是秒级实时；客户端会显示数据年龄。
- 单站刷新会合并进全量快照，但全量快照的 `fetched_at` 不变；单站有独立 `observed_at`。
- SQLite 适合单实例；多实例部署前需要换 PostgreSQL/Redis 并拆分广播。
- 刷新接口目前无鉴权，公网部署应加访问控制或只允许 App 网关调用。
- 账号、推送、真实 GPS 尚未接入。
- WebSocket 目前只广播刷新事件，客户端仍以 HTTP 拉取快照。
