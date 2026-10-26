# Demo 说明

## 目标

在 iOS 模拟器上还原网页原型的主要体验：

- 自动锁定最近可用站点
- 3D 点云桩体
- 距离小于 25m 时逐点飞掠为 2D 俯视
- 精密导航面板、雷达与附近列表
- 功率/将满信息
- 调试面板模拟定位

## 运行

```bash
cd app
flutter pub get
open -a Simulator
flutter run
```

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

## 已知限制

- 没有真实 GPS，使用调试面板的模拟定位
- 没有指南针传感器，指北针使用模拟方位
- 没有后端，刷新按钮只做模拟刷新
- 3D 桩体为合成示意，不是实景结构
- 只验证 iOS 模拟器；Android 与 HarmonyOS 后续
- 地图按钮使用外部高德 URI，模拟器中会打开 Safari

## 验收

- 首页可滚动，无 overflow
- 200m → 10m 触发 3D→2D
- 10m → 200m 触发 2D→3D
- 站点切换、端口颜色、空闲数、功率 chips 与快照一致
- `flutter analyze` 通过
- `flutter test` 通过
