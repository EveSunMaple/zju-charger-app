# 后续清单

以下内容明确不在当前 demo 范围内，后续按优先级推进。

## 数据与后端

- 状态变更历史与功率历史曲线
- PostgreSQL / Redis 多实例部署
- 其他充电服务商适配（安中大楼等）
- 数据源健康监控、指标与告警
- 推送失败重试与孤儿订阅清理

## 客户端

- 真实 GPS 持续定位与精度圈
- 设备指南针 / 朝向传感器
- GCJ-02 / WGS-84 坐标纠偏
- 离线缓存优化
- Android 真机测试（模拟器 debug 构建已完成）
- Android release 签名与 APK 体积优化
- 空位提醒：匿名设备 ID + 推送 token（已实现，真实 JPush 联调待账号）
- JPush iOS APNs / Android 厂商离线推送配置
- 客户端 API 刷新策略与离线缓存优化
- 内嵌高德/百度地图与真实路径规划
- 每台设备真实照片、插口编号绑定、实际桩体布局
- 管理后台、历史统计、故障趋势、用户上报
- AR 找桩

## 平台与发布

- HarmonyOS NEXT：Flutter-OH 版本验证、定位/传感器/推送插件、HAP 签名
- HarmonyOS 4.x：Android APK 兼容性验证
- iOS TestFlight / App Store
- 华为应用市场 / 国内安卓商店
- APP 备案、隐私政策、软件著作权
- 应用图标、启动页、商店素材

## 当前不做

- 账号、登录、跨设备收藏同步
- 后端 WebSocket
- 内嵌地图
- HarmonyOS（最后处理）
- 真实桩体照片/布局

## 后续增强：JPush 真实推送

### JPush 是什么

JPush（极光推送）是服务器向手机 App 主动发送通知的服务。它把 APNs、华为 Push、小米/OPPO/vivo 等厂商通道聚合起来，服务端只需要按设备的 registration ID 发送。

### 为什么需要

「空位提醒」要求用户没打开 App 时也能收到通知：

- App 在前台：WebSocket / 轮询可以工作
- App 在后台或被系统杀掉：连接会断，必须走系统级推送
- Android、iOS、鸿蒙推送通道不同，逐个接入成本高
- JPush 可以作为统一通道，服务端直接调 REST API

### 当前状态

- 客户端已接入 JPush SDK，并预留匿名设备注册、订阅同步、通知点击选站
- 后端已实现 `busy/float -> free` 事件检测、订阅存储、JPush REST 发送器
- 默认 `PUSH_ENABLED=false`，使用 `LoggingPushSender` 空跑
- 真实 JPush AppKey / MasterSecret、APNs、华为推送尚未联调
- 当前版本不阻塞找桩、收藏、单站刷新等核心功能

### 后续要做

1. 创建 JPush 应用，配置 Android 包名和 AppKey
2. 后端配置 `PUSH_ENABLED=true`、`JPUSH_APP_KEY`、`JPUSH_MASTER_SECRET`
3. Android 真机验证通知权限、在线/离线推送、厂商通道
4. iOS 开启 Push Notifications capability，配置 APNs 证书/密钥
5. 鸿蒙接入 JPush HarmonyOS SDK，配置华为 Push
6. 通知点击后打开对应站点并刷新数据
7. 推送到达率、失败重试、无效 token 清理、孤儿订阅清理
8. 隐私政策中补充通知权限和推送 token 说明

### 验收标准

- App 在后台/被杀后仍能收到空位通知
- 点击通知能打开 App 并定位到对应站点
- 同一设备同一站点 10 分钟冷却生效
- 首次全量刷新和旧快照不会误推
- 用户可以关闭某站提醒，服务端订阅同步删除

### 替代方案

- 不用第三方：分别接入 APNs、FCM/HMS、小米/OPPO/vivo 推送，工作量和维护成本更高
- 只做前台提醒：使用 WebSocket / 轮询，不满足 App 关闭后的提醒场景
