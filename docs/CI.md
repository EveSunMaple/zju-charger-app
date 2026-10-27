# CI 流水线

工作流：`.github/workflows/flutter-ci.yml`

## 触发

- 任意分支 push
- Pull Request
- 手动 `workflow_dispatch`

同一分支的新提交会取消上一轮未完成的 CI，只保留最新一轮。

## 阶段

| Job | 内容 |
| --- | --- |
| `flutter` | `dart format` 检查、`flutter analyze`、`flutter test` |
| `backend` | `pytest` |
| `android` | 安装 JDK 17 / Android SDK 36 / NDK 28.2，构建 debug + release APK |

`android` 依赖前两个 job 成功，避免把测试失败的包发出去。

## 下载安装包

打开对应 commit 的 Actions run，页面底部 **Artifacts**：

```text
zju-charger-android-<commit-sha>/
├── app-debug.apk
├── app-release.apk
└── SHA256SUMS
```

- `app-release.apk`：约 54 MB，当前使用 debug 签名，仅用于内部测试
- `app-debug.apk`：约 146 MB，保留调试能力
- `SHA256SUMS`：APK 校验和

## Variables

在仓库 Variables 中可选设置：

```text
API_BASE_URL=https://charger.example.com
JPUSH_APP_KEY=极光 AppKey
DEBUG_PUSH_TOKEN=demo-push-token-1234
```

CI 会通过 `--dart-define=...` 打进 APK：

- 未设置 `API_BASE_URL` 时使用 `assets/data/snapshot.json` 离线快照
- 未设置 `JPUSH_APP_KEY` 时推送关闭
- `DEBUG_PUSH_TOKEN` 仅用于没有 JPush 凭据时验证订阅流程

正式环境必须使用 HTTPS；Android release 包不允许 cleartext HTTP。

## 缓存与超时

- Flutter SDK / pub 缓存由 `subosito/flutter-action` 处理
- Gradle 缓存 `~/.gradle/caches` 与 `~/.gradle/wrapper`
- Android job 超时 30 分钟

## 未包含

- iOS 签名 / TestFlight
- HarmonyOS HAP
- 应用商店发布
- 自动化 UI 测试（当前只有 Flutter 单测/Widget 测试和后端单测）
