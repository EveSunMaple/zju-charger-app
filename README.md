# 浙大充电桩

浙江大学充电桩找桩与插口状态展示应用。当前仓库先交付 Flutter demo，数据使用离线快照，重点验证 3D 点云、2D 精确俯视和移动端视觉。

## 当前状态

- 客户端：Flutter 3.47.x，iOS 模拟器与 Android 模拟器均已验证
- 数据：内置 `app/assets/data/snapshot.json`
- 范围：35 个站点 / 137 台设备 / 1644 个插口
- 暂不包含：实时后端、账号、推送、HarmonyOS、内嵌地图
- Android：debug / release APK 均已在 Android 16 / API 36 模拟器运行通过

## Demo 截图

| 3D 点云 | 2D 俯视 |
| --- | --- |
| ![3D](screenshots/demo_3d.png) | ![2D](screenshots/demo_2d.png) |

| 精密导航与功率 | 演示控制 |
| --- | --- |
| ![精密导航](screenshots/demo_precise.png) | ![演示控制](screenshots/demo_debug.png) |

Android 模拟器验证：

| 3D 点云 | 2D 俯视 |
| --- | --- |
| ![Android 3D](screenshots/android_3d.png) | ![Android 2D](screenshots/android_2d.png) |

| 精密导航与功率 | 演示控制 |
| --- | --- |
| ![Android 精密导航](screenshots/android_precise.png) | ![Android 演示控制](screenshots/android_debug.png) |

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

验证：

```bash
cd app
flutter analyze
flutter test
```

## Android 验证

```bash
cd app
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT=$ANDROID_HOME
flutter build apk --debug
flutter run -d emulator-5554
```

详细环境与 AVD 配置见 [Android 验证](docs/ANDROID.md)。

## 文档

- [Demo 说明](docs/DEMO.md)
- [Android 验证](docs/ANDROID.md)
- [技术决策](docs/DECISIONS.md)
- [后续清单](docs/BACKLOG.md)
