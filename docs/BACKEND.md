# 后端与实时数据

## 职责

后端只做四件事：

1. 定时全量抓取上游
2. 单站按需刷新
3. 提供最新快照
4. 匿名设备订阅与空位推送

不做账号、登录、跨设备收藏同步、历史库、WebSocket 或管理后台。

```text
Flutter App
   │ GET /v1/snapshot
   ▼
FastAPI
   ├─ 全量刷新任务
   ├─ 单站刷新任务
   ├─ data/snapshot.json
   ├─ data/push.db（设备/订阅）
   └─ JPush REST
        │ 1.2s 串行限流
        ▼
量子新能上游
```

## 接口

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/healthz` | 存活、数据年龄、全量刷新状态 |
| GET | `/v1/meta` | 站点/设备/插口汇总、刷新状态、推送统计 |
| GET | `/v1/snapshot` | 完整插口级快照，客户端唯一数据源 |
| POST | `/v1/stations/{name}/refresh` | 单站刷新，202 |
| PUT | `/v1/devices/{device_id}` | 注册/更新匿名设备、推送 token、订阅站点 |
| DELETE | `/v1/devices/{device_id}` | 删除设备和全部订阅 |
| GET | `/docs` | Swagger 文档 |

客户端不调用站点列表、站点详情、功率或 WebSocket 接口，这些数据全部从 `/v1/snapshot` 本地计算。

### 设备注册

```http
PUT /v1/devices/6f1c2d3e-...
Content-Type: application/json

{
  "platform": "android",
  "push_token": "JPush registration id",
  "station_names": ["紫金港玉湖", "紫金港医学院南侧"]
}
```

`station_names` 是覆盖式更新：传空数组即取消该设备全部站点提醒。

## 数据流

1. 启动时读取 `data/snapshot.json`；不存在则读取 `data/seed_snapshot.json`。
2. 后台全量扫描 135 台去重设备，1.2s 间隔，约 3 分钟。
3. 扫描完成后抓取最多 200 个在充/浮充端口功率，间隔 0.25s。
4. 快照原子写入 `data/snapshot.json`，并更新内存快照。
5. 全量完成后等待 60 秒开始下一轮，数据年龄通常不超过约 4 分钟。
6. 单站刷新约 10-15 秒，保留 30 秒冷却；结果合并回当前快照。
7. 全量快照的 `fetched_at` 不变；单站有独立的 `observed_at`。

## 空位推送

刷新后比较旧/新快照：

```text
旧状态 = busy / float
新状态 = free
```

命中后向订阅该站点的设备推送：

```text
标题：有空闲插口
内容：紫金港玉湖 有 2 个空闲插口
附加：station=紫金港玉湖, free_count=2
```

规则：

- 同一设备 + 同一站点 10 分钟内只推一次
- 首次全量刷新不推
- 旧快照超过 15 分钟不推
- 推送失败只记录日志，不阻塞刷新
- `PUSH_ENABLED=false` 使用 logging sender 空跑
- 只推“占用 → 空闲”，不推“将满”，避免误报

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
curl http://127.0.0.1:8000/v1/snapshot
cd backend && .venv/bin/pytest -q
```

## 客户端接入

```bash
# Android 模拟器
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000

# iOS 模拟器
flutter run -d "iPhone 18 Pro" \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

未设置 `API_BASE_URL` 或请求失败时自动回退 `assets/data/snapshot.json`。API 模式顶栏显示「数据」，离线模式显示「快照」。

## 配置

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
| `SNAPSHOT_PATH` | ./data/snapshot.json | 最新快照 |
| `PUSH_DB_PATH` | ./data/push.db | 设备/订阅库 |
| `PUSH_ENABLED` | false | 是否真实发送推送 |
| `PUSH_COOLDOWN_SECONDS` | 600 | 单设备单站推送冷却 |
| `PUSH_STALE_SECONDS` | 900 | 旧快照禁止推送阈值 |
| `JPUSH_APP_KEY` | - | 极光 AppKey |
| `JPUSH_MASTER_SECRET` | - | 极光 MasterSecret |
| `JPUSH_APNS_PRODUCTION` | false | iOS APNs 环境 |

## 部署

```bash
cd infra
cp ../backend/.env.example ../backend/.env
docker compose up -d --build
docker compose logs -f api
```

建议只暴露 80/443，API 8000 仅本机或容器网络，使用 Caddy/Nginx 终止 HTTPS。

生产检查：

```bash
curl https://charger.example.com/healthz
curl https://charger.example.com/v1/meta
```

备份 `backend/data/snapshot.json` 和 `backend/data/push.db`。

## 已知限制

- 上游是未公开接口，可能变更或限流；当前按 1.2s 串行、指数退避处理。
- 全量刷新约 3-4 分钟；单站刷新可做到 10-15 秒。
- 单站刷新合并后全量 `fetched_at` 不变，客户端应显示 `observed_at`。
- 匿名设备接口无登录鉴权；公网部署建议加网关限流或访问控制。
- SQLite 适合单实例；多实例需要 PostgreSQL/Redis。
- iOS APNs 需要 Apple Developer；鸿蒙离线推送需要华为开发者账号。
- 账号、跨设备收藏同步、历史统计、管理后台均不在当前范围。
