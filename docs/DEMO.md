# Demo 说明

## 目标

在 iOS 与 Android 模拟器上还原网页原型的主要体验：

- 自动锁定最近可用站点
- 3D 点云桩体
- 距离小于 25m 时逐点飞掠为 2D 俯视
- 精密导航面板、雷达与附近列表
- 功率/将满信息
- 本地收藏、收藏夹、空位提醒
- 单站刷新与站点数据年龄
- 调试面板模拟定位

## 截图

| 3D 点云 | 2D 俯视 |
| --- | --- |
| ![3D](../screenshots/demo_3d.png) | ![2D](../screenshots/demo_2d.png) |

| 精密导航与功率 | 演示控制 |
| --- | --- |
| ![精密导航](../screenshots/demo_precise.png) | ![演示控制](../screenshots/demo_debug.png) |

Android 16 / API 36 模拟器：

| 3D 点云 | 2D 俯视 |
| --- | --- |
| ![Android 3D](../screenshots/android_3d.png) | ![Android 2D](../screenshots/android_2d.png) |

| 精密导航与功率 | 演示控制 |
| --- | --- |
| ![Android 精密导航](../screenshots/android_precise.png) | ![Android 演示控制](../screenshots/android_debug.png) |

## 运行

纯离线：

```bash
cd app
flutter pub get
open -a Simulator
flutter run
```

接实时后端：

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
cp .env.example .env
.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000

cd ../app
flutter run -d "iPhone 18 Pro" \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Android 模拟器把地址换成 `http://10.0.2.2:8000`。接口说明见 [BACKEND.md](BACKEND.md)。

指定设备：

```bash
flutter devices
flutter run -d "iPhone 18 Pro"
```

## 数据

- 文件：`app/assets/data/snapshot.json`
- 来源：网页原型 `data/snapshot.json`
- 内容：35 站点 / 137 设备 / 1644 插口
- 时间显示为快照的真实抓取时间，不伪造实时

## 实现要点

- 点云投影：`rotY → rotX → 透视`，FOV 950，舞台高度 330
- 初始 3D 角度：`rotX=-50°`、`rotY=-15°`
- morph：1.4s，`easeInOutCubic`，逐点错峰
- 距离回差：进入 2D 阈值 25m，退出阈值 40m
- 2D 态模型缩放 88%
- 端口颜色：空闲绿、占用/浮充红、储物/故障灰；浮充标「满」
- 雷达使用对数刻度，可点按切换站点
- 空位提醒所需的匿名订阅尚未接入，当前只展示快照数据

## 已知限制

- 没有真实 GPS，使用调试面板的模拟定位
- 没有指南针传感器，指北针使用模拟方位
- 未启动后端时自动回退离线快照；刷新按钮只同步服务端最新快照，不直接触发上游抓取
- 3D 桩体为合成示意，不是实景结构
- 全量刷新约 3-4 分钟，不是秒级实时
- 单站刷新合并进全量快照，全量 `fetched_at` 不变，单站有 `observed_at`
- 账号与跨设备同步永久不做；收藏和提醒只存在当前设备
- iOS 模拟器与 Android 16 / API 36 模拟器已验证；真实 JPush 端到端与 HarmonyOS 后续
- 地图按钮使用外部高德 URI，模拟器中会打开 Safari

## 验收

- 首页可滚动，无 overflow
- 200m → 10m 触发 3D→2D
- 10m → 200m 触发 2D→3D
- 站点切换、端口颜色、空闲数、功率 chips 与快照一致
- `flutter analyze` 通过
- `flutter test` 通过（8 个测试）
- 已在 375px 宽度下检查无 overflow
- Android 通过 adb 实际点击和滚动验证
- Android 构建说明见 [ANDROID.md](ANDROID.md)
