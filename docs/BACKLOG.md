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
