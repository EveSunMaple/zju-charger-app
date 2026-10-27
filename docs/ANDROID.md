# Android 验证

## 环境

本机验证环境：

| 项 | 值 |
| --- | --- |
| 机器 | Apple Silicon / macOS 27 |
| Flutter | 3.47.8 stable |
| JDK | OpenJDK 17.0.20.1 |
| Android SDK | `/opt/homebrew/share/android-commandlinetools` |
| 编译 SDK | Android 36 / 37 |
| Build Tools | 36.0.0 / 37.0.0 |
| NDK | 28.2.13676358 |
| Emulator | 37.2.12 |
| AVD | `zju_android`，Pixel 7，Android 16 / API 36，arm64-v8a |

## 一次性配置

```bash
brew install --cask android-commandlinetools
brew install openjdk@17

export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"

yes | sdkmanager --install \
  "platform-tools" \
  "emulator" \
  "platforms;android-36" \
  "build-tools;37.0.0" \
  "system-images;android-36;google_apis;arm64-v8a"

echo no | avdmanager create avd \
  -n zju_android \
  -k "system-images;android-36;google_apis;arm64-v8a" \
  -d pixel_7 --force
```

## 启动模拟器

桌面窗口模式，适合人工点击测试：

```bash
emulator -avd zju_android \
  -no-audio -no-boot-anim \
  -gpu host -no-snapshot \
  -memory 3072 -cores 4
```

无窗口模式，适合脚本/截图：

```bash
emulator -avd zju_android \
  -no-window -no-audio -no-boot-anim \
  -gpu swiftshader_indirect -no-snapshot
```

AVD 配置中已建议启用：

```ini
hw.gpu.enabled=yes
hw.gpu.mode=host
hw.ramSize=3G
```

如果首次启动出现 “System UI isn't responding”，点 Wait 并等待系统稳定；或关闭其他占用内存的模拟器/IDE 后重启。

等待启动：

```bash
adb wait-for-device
adb shell getprop sys.boot_completed
```

## 构建与运行

```bash
cd app
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT=$ANDROID_HOME
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

flutter config --android-sdk "$ANDROID_HOME"
flutter build apk --debug
flutter build apk --release
flutter run -d emulator-5554
```

联调实时后端：

```bash
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

产物：

```text
app/build/app/outputs/flutter-apk/app-debug.apk    # 约 146 MB
app/build/app/outputs/flutter-apk/app-release.apk  # 约 46 MB
```

当前 release 仍使用 debug 签名，仅用于验证；正式发布前需要配置正式 keystore、混淆和体积优化。

## Gradle 镜像

构建时 Google Maven 出现过 `429 Too Many Requests`，已在以下文件加入阿里云镜像并保留官方仓库兜底：

- `app/android/settings.gradle.kts`
- `app/android/build.gradle.kts`

海外网络环境可以移除镜像，直接使用 `google()` / `mavenCentral()`。

## 已验证

- Android 16 / API 36 模拟器安装并启动成功
- 3D 点云、2D 俯视、精密面板、功率 chips、雷达、附近列表、演示控制面板均正常
- 通过 `adb shell input` 实际点击了演示按钮、10m 预设、完成按钮，并滚动到雷达/列表
- Flutter 日志无异常，`flutter analyze` 和 `flutter test` 均通过
- release APK 构建成功并在模拟器安装运行通过
- 截图：`screenshots/android_3d.png`、`android_2d.png`、`android_precise.png`、`android_debug.png`

## 尚未验证

- Android 真机
- 真实 GPS、指南针、权限弹窗
- release APK 签名与上架
- 后台数据与推送

## 已知提示

构建过程会出现：

```text
Warning: SDK processing. This version only understands SDK XML versions up to 3
but an SDK XML file of version 4 was encountered.
```

这是 command-line tools 与 platform XML 版本差异，不影响本次构建和运行；后续更新 command-line tools 可消除。
