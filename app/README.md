# 浙大充电桩 App

Flutter demo 客户端。当前使用离线快照，重点验证 3D 点云、2D 俯视和移动端交互。

## 运行

```bash
flutter pub get
open -a Simulator
flutter run
```

如果 Flutter 未加入 PATH：

```bash
/Users/sunmaple/development/flutter/bin/flutter run
```

默认设备为 iPhone 18 Pro 模拟器。也可以使用：

```bash
flutter devices
flutter run -d "iPhone 18 Pro"
```

## 测试

```bash
flutter analyze
flutter test
```

## 数据

`assets/data/snapshot.json`，来源为网页原型的离线快照：

- 35 个站点
- 137 台设备
- 1644 个插口

## 目录

```text
lib/
├── core/          主题、地理计算、格式化、导航
├── data/          快照加载
├── features/
│   ├── debug/     演示控制面板
│   └── home/      首页、HERO、点云、雷达、附近列表、精密面板
├── models/        站点/设备/插口/功率模型
└── state/         Riverpod 演示状态
```
