# 浙大充电桩

浙江大学充电桩找桩与插口状态展示应用。当前仓库先交付 Flutter demo，数据使用离线快照，重点验证 3D 点云、2D 精确俯视和移动端视觉。

## 当前状态

- 客户端：Flutter 3.47.x，iOS 模拟器优先
- 数据：内置 `app/assets/data/snapshot.json`
- 范围：35 个站点 / 137 台设备 / 1644 个插口
- 暂不包含：实时后端、账号、推送、HarmonyOS、内嵌地图

## 快速开始

```bash
cd app
flutter pub get
open -a Simulator
flutter run
```

本机 Flutter SDK 位于 `/Users/sunmaple/development/flutter`。未加入全局 PATH 时使用：

```bash
/Users/sunmaple/development/flutter/bin/flutter run
```

## 文档

- [Demo 说明](docs/DEMO.md)
- [技术决策](docs/DECISIONS.md)
- [后续清单](docs/BACKLOG.md)
