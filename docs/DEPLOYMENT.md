# 后端部署指南

## 目标结构

```text
手机 App
  │ HTTPS
  ▼
Caddy / Nginx（80/443）
  │ 127.0.0.1:8000
  ▼
FastAPI 容器
  ├─ 定时全量抓取
  ├─ 单站刷新
  ├─ data/snapshot.json
  └─ data/push.db
        │ HTTP
        ▼
量子新能上游
```

API 不直接暴露公网，只让反向代理访问。手机只访问 HTTPS 域名。

## 服务器要求

- Linux（Ubuntu 22.04/24.04 均可）
- 1 核 1G 起步，建议 1 核 2G
- 已安装 Docker + Docker Compose
- 公网域名解析到服务器
- 服务器可访问 `http://www.szlzxn.cn`
- 开放 80/443，不开放 8000

先验证上游：

```bash
curl -sS -m 15 -X POST http://www.szlzxn.cn/wxn/getDeviceInfo \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data 'areaId=6&devaddress=40759094' | head -c 200
```

有 JSON 返回即可。若服务器访问不了上游，先解决网络问题或换部署位置。

## 一、Docker 部署

### 1. 拉代码

```bash
git clone git@github.com-eve:EveSunMaple/zju-charger-app.git
cd zju-charger-app
```

HTTPS：

```bash
git clone https://github.com/EveSunMaple/zju-charger-app.git
```

### 2. 配置环境变量

```bash
cp backend/.env.example backend/.env
```

编辑 `backend/.env`：

```bash
# 必填/常用
APP_HOST=0.0.0.0
APP_PORT=8000
LOG_LEVEL=INFO
REFRESH_INTERVAL_SECONDS=60
POWER_PORT_LIMIT=200

# 推送；没有 JPush 账号时保持 false
PUSH_ENABLED=false
JPUSH_APP_KEY=
JPUSH_MASTER_SECRET=
```

其他参数见 `docs/BACKEND.md`。

### 3. 启动

```bash
cd infra
docker compose up -d --build
docker compose ps
docker compose logs -f api
```

API 只监听宿主机 `127.0.0.1:8000`：

```bash
curl http://127.0.0.1:8000/healthz
curl http://127.0.0.1:8000/v1/meta
curl -o /tmp/snapshot.json http://127.0.0.1:8000/v1/snapshot
wc -c /tmp/snapshot.json
```

首次启动会先加载种子快照，然后后台全量扫描约 3-4 分钟。等：

```bash
watch -n 15 'curl -s http://127.0.0.1:8000/v1/meta'
```

看到 `refresh.full.running=false`、`fetched_at` 变成当前时间即可。

### 4. 配置 HTTPS

安装 Caddy：

```bash
sudo apt update
sudo apt install -y caddy
```

复制并修改域名：

```bash
sudo cp infra/Caddyfile.example /etc/caddy/Caddyfile
sudo nano /etc/caddy/Caddyfile
```

内容：

```caddyfile
charger.example.com {
    encode gzip
    reverse_proxy 127.0.0.1:8000
}
```

把 `charger.example.com` 换成你的域名，然后：

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
sudo systemctl status caddy
```

验证：

```bash
curl https://charger.example.com/healthz
curl https://charger.example.com/v1/meta
```

### 5. 防火墙

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 8000/tcp
sudo ufw status
```

不要把 8000 直接暴露到公网。

## 二、不用 Docker（systemd）

```bash
sudo mkdir -p /opt/zju-charger
sudo chown -R $USER:$USER /opt/zju-charger
git clone git@github.com-eve:EveSunMaple/zju-charger-app.git /opt/zju-charger

cd /opt/zju-charger/backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env
nano .env
```

启动一次确认：

```bash
.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
```

另开终端：

```bash
curl http://127.0.0.1:8000/healthz
```

安装 systemd：

```bash
sudo cp /opt/zju-charger/infra/zju-charger.service.example /etc/systemd/system/zju-charger.service
sudo nano /etc/systemd/system/zju-charger.service
```

把 `User=zju`、路径和域名按实际修改，然后：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now zju-charger
sudo systemctl status zju-charger
sudo journalctl -u zju-charger -f
```

## 三、App 指向后端

```bash
cd app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://charger.example.com
```

或者用 CI 的仓库 Variables：

```text
API_BASE_URL=https://charger.example.com
```

然后重新跑 CI，下载新的 APK。

iOS/Android 正式包必须使用 HTTPS；本地调试才用：

```text
Android 模拟器：http://10.0.2.2:8000
iOS 模拟器：http://127.0.0.1:8000
```

## 四、推送（可选）

没有 JPush 账号时保持：

```text
PUSH_ENABLED=false
```

空位事件只写日志：

```bash
docker compose logs -f api | grep "push dry-run"
```

有账号后：

```text
PUSH_ENABLED=true
JPUSH_APP_KEY=...
JPUSH_MASTER_SECRET=...
JPUSH_APNS_PRODUCTION=false
```

App 构建时同时传 `JPUSH_APP_KEY`，详见 `docs/PUSH.md`。

## 五、备份与更新

备份：

```bash
cd zju-charger-app
tar czf backup-$(date +%F).tgz \
  backend/data/snapshot.json \
  backend/data/push.db
```

更新：

```bash
cd zju-charger-app
git pull
cd infra
docker compose up -d --build
docker compose logs -f api
```

`backend/data/` 已挂载到宿主机，重建容器不会丢快照和订阅。

## 六、上线验收

```bash
# 健康检查
curl -fsS https://charger.example.com/healthz

# 数据年龄、站点数、推送统计
curl -fsS https://charger.example.com/v1/meta

# 完整快照
curl -fsS https://charger.example.com/v1/snapshot | head -c 300
```

App 端：

1. 打开 App，顶栏显示「数据」而不是「快照」
2. 数据年龄小于约 5 分钟
3. 收藏、收藏夹、空位提醒可操作
4. 点「刷新数据」等待 15-20 秒，当前站时间更新
5. 推送配置后，后台杀掉 App，插口从占用变空闲能收到通知

## 七、常见问题

### `/healthz` 显示 `ready=false`

首次启动/首次全量刷新还没完成。看日志：

```bash
docker compose logs -f api
```

### 上游返回 429 / 参数错误

保持 `UPSTREAM_DEVICE_INTERVAL=1.2`，不要并发打上游。当前后端已经串行限流和退避。

### 手机访问不到 API

- 域名是否解析到服务器
- Caddy 是否正常：`systemctl status caddy`
- 防火墙 80/443 是否开放
- 是否误用了 HTTP；release 包需要 HTTPS
- `API_BASE_URL` 是否在构建时传入

### 推送没有通知

- `PUSH_ENABLED=true` 了吗
- JPush AppKey/MasterSecret 是否配置
- Android 13+ 是否授予通知权限
- iOS 是否开启 Push Notifications capability 并配置 APNs
- 先看后端日志是否有 `push dry-run` 或 `jpush failed`

### 风险

- 上游是未公开接口，可能变更或限流
- 匿名设备接口无登录鉴权，公网部署建议在反向代理层加限流
- 全量刷新约 3-4 分钟，不是秒级实时
- 单实例 SQLite 足够；多实例需要 PostgreSQL/Redis
