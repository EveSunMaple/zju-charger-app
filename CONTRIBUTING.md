# 协作指南

## 开始前

1. 阅读 [README](README.md) 的快速开始和目录结构。
2. 确认 Flutter 3.47.8、Xcode 27 或 Android SDK 环境可用。
3. 从最新 `main` 创建分支：

```bash
git switch main
git pull
git switch -c feat/your-feature
```

## 分支命名

- `feat/<name>`
- `fix/<name>`
- `docs/<name>`
- `refactor/<name>`
- `test/<name>`

## 提交

提交信息使用前缀：

```text
feat: add favorite station
fix: handle empty port list
docs: update Android AVD setup
test: cover radar hit testing
chore: update dependencies
```

一次提交只做一件事；不要提交构建产物、截图以外的临时文件、密钥或 `.env`。

## 开发与测试

客户端：

```bash
cd app
dart format lib test
flutter analyze
flutter test
```

后端：

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/pytest -q
```

iOS：

```bash
flutter run -d "iPhone 18 Pro"
```

Android：

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT=$ANDROID_HOME
flutter run -d emulator-5554
```

完整 Android 环境见 [docs/ANDROID.md](docs/ANDROID.md)。

## Pull Request

PR 描述请包含：

- 做了什么
- 为什么这样做
- 如何验证（命令、设备、截图）
- 已知限制

UI 改动附 iOS/Android 截图。数据模型或接口改动同步更新 `docs/` 和测试。后端改动至少运行 `pytest`。

## 代码约定

- 不添加无意义注释；用清晰的命名表达意图
- 状态统一走 Riverpod
- 点云相关逻辑放在 `features/home/scene_*`
- 新平台能力先做薄封装，避免直接散落平台判断
- 不把上游抓取逻辑放进客户端
- 3D 桩体继续标注为示意，不能包装成真实物理布局

## 提交前检查

```bash
cd app
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

全部通过后再提交 PR。
