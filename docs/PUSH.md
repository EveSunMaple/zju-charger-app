# 空位提醒与推送

> 当前状态：代码路径已预留，默认 `PUSH_ENABLED=false` 空跑。真实 JPush/APNs/华为推送联调列为后续增强，不阻塞当前版本。原因与任务清单见 [BACKLOG.md](BACKLOG.md#后续增强jpush-真实推送)。

## 产品范围

- 按具体站点订阅“占用 → 空闲”提醒
- 匿名设备，不需要账号
- 收藏、提醒只保存在当前设备
- 不做跨设备同步
- 不推“将满”，只推真实出现空闲插口

## 客户端

- 首次启动生成匿名 UUID：`LocalStore`
- 本地收藏和提醒站点：`SharedPreferences`
- 推送 SDK：极光 JPush
- 订阅同步：`PUT /v1/devices/{device_id}`

### 调试模式

没有 JPush AppKey 时，可以用假 token 跑通订阅和推送空跑：

```bash
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=DEBUG_PUSH_TOKEN=demo-push-token-1234
```

后端 `PUSH_ENABLED=false` 时，事件会写入日志，不真正发送。

### JPush Android

1. 在极光控制台创建应用，包名与 `com.zjucharger.zju_charger` 一致。
2. 构建时同时提供 Gradle 占位符和 Dart 参数：

```bash
export JPUSH_APP_KEY=你的AppKey
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=JPUSH_APP_KEY=$JPUSH_APP_KEY
```

3. `app/android/app/build.gradle.kts` 已配置：

```kotlin
manifestPlaceholders["JPUSH_PKGNAME"] = "com.zjucharger.zju_charger"
manifestPlaceholders["JPUSH_APPKEY"] = jpushAppKey
manifestPlaceholders["JPUSH_CHANNEL"] = "developer-default"
```

4. Android 13+ 通知权限已在启动时请求：`requestRequiredPermission()`。
5. 已关闭 Flutter 自动 deep link，避免厂商通道点击白屏。

### JPush iOS

1. 在 Xcode 打开 `Runner`，开启 `Push Notifications` capability。
2. 配置 APNs 证书/密钥到极光控制台。
3. 构建时传入：

```bash
flutter run -d "iPhone 18 Pro" \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=JPUSH_APP_KEY=$JPUSH_APP_KEY
```

4. 当前代码会调用 `applyPushAuthority` 请求通知权限，并读取冷启动通知。
5. iOS 端到端验证需要 Apple Developer 账号；没有账号只能验证编译和 UI。

### HarmonyOS

- 当前未接入 `jpush_harmony_sdk`
- 需要华为开发者账号、HAP 签名和 `GETUI_APPID/client_id` 配置
- 按既定计划放到最后

## 后端

```bash
PUSH_ENABLED=true
JPUSH_APP_KEY=...
JPUSH_MASTER_SECRET=...
JPUSH_APNS_PRODUCTION=false
```

`PUSH_ENABLED=false` 使用 `LoggingPushSender`，日志示例：

```text
push dry-run device=... platform=android token=***n-1234 title=有空闲插口
body=紫金港玉湖 有 1 个空闲插口 extras={'station': '紫金港玉湖', 'free_count': 1}
```

## 事件规则

- 全量刷新或单站刷新后比较旧/新插口状态
- 仅 `busy/float -> free` 触发
- 首次全量刷新不推
- 旧快照超过 15 分钟不推
- 同一设备 + 同一站点 10 分钟冷却
- 发送失败不阻塞刷新，不更新冷却时间，下次事件可重试

## 测试

后端：

```bash
cd backend
.venv/bin/pytest -q
```

覆盖：订阅替换、订阅删除、冷却、旧快照跳过、单站事件过滤。

客户端：

```bash
cd app
flutter test
```

覆盖：本地收藏/提醒持久化、通知点击选站、Widget 渲染。

## 已知限制

- 无账号时设备 ID 就是身份；重装 App 会生成新 ID，旧订阅成为孤儿记录
- 设备接口没有鉴权，公网部署需要限流/访问控制
- 厂商离线推送依赖厂商账号和应用商店状态
- JPush 真实发送不在 CI 中执行
