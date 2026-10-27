# 技术决策

## ADR-001 客户端使用 Flutter

- 状态：已确定
- 日期：2026-10-26
- 决策：客户端使用 Flutter / Dart，一套代码覆盖 Android、iOS，HarmonyOS 后续单独评估。
- 原因：点云 morph 是本项目核心视觉，Flutter CustomPainter 控制力强；三端一致的 UI 与动效更容易保证；后续 Flutter-OH 可复用 Dart 业务代码。
- 代价：需要维护 Flutter 工具链；HarmonyOS 插件需要逐项验证。

## ADR-002 Demo 使用离线快照

- 状态：已确定
- 日期：2026-10-26
- 决策：demo 阶段直接读取 `app/assets/data/snapshot.json`，不接后端。
- 原因：先验证交互与视觉；避免把上游限流、服务端和网络问题混进 UI 迭代。
- 后续：接入 FastAPI 数据网关后，用同一套模型替换数据源。

## ADR-003 永久不做账号与跨设备同步

- 状态：已确定
- 日期：2026-10-27
- 决策：产品不做登录、注册、用户表、会话和跨设备收藏同步；收藏与提醒只存在当前设备。
- 空位提醒使用匿名设备 ID + 推送 token，不需要账号。
- 原因：取消账号后隐私、合规和开发成本最低；本产品没有跨设备同步的硬需求。
- 影响：重装 App 会生成新设备 ID，旧订阅不会自动迁移。

## ADR-004 v1 地图使用外部跳转

- 状态：已确定
- 日期：2026-10-26
- 决策：App 内保留自绘雷达/俯视示意，真实导航通过高德 URI 外部跳转。
- 原因：避免在 demo 阶段引入地图 SDK；Flutter 鸿蒙地图插件兼容性风险较高。
- 后续：内嵌地图进入 `BACKLOG.md`，届时再评估高德三端 SDK。

## ADR-005 3D 点云是示意模型

- 状态：已确定
- 日期：2026-10-26
- 决策：沿用 demo 的合成桩体模型，由设备数量和插口数量生成；界面上标注为示意，不宣称是实景结构。
- 原因：上游数据不包含桩体几何布局，直接呈现合成结构会误导用户。
- 后续：真实桩体照片、插口编号绑定和实际布局进入 `BACKLOG.md`。

## ADR-006 鸿蒙延后

- 状态：已确定
- 日期：2026-10-26
- 决策：demo 与 v1 先交付 iOS/Android；HarmonyOS NEXT 在 Flutter-OH 插件验证通过后接入。
- 原因：当前无鸿蒙真机与开发者账号；鸿蒙模拟器需要免费华为账号 + 实名。
- 后续：接入时必须先验证定位、指南针、推送、HAP 签名和 Flutter-OH 版本。

## ADR-007 Demo 使用 Flutter 3.47.8

- 状态：已确定
- 日期：2026-10-26
- 决策：demo 固定使用 Flutter 3.47.8 / Dart 3.13.7。
- 原因：本机 Xcode 27.1 与 iOS 27 模拟器需要 Flutter 3.47+；该版本已处理 UIScene 生命周期要求。
- 后续：接入 HarmonyOS 时以当时的 Flutter-OH 版本为准，必要时用第二个 SDK 构建 HAP，Dart 业务代码保持兼容。

## ADR-008 Android 先于 HarmonyOS 验证

- 状态：已确定
- 日期：2026-10-26
- 决策：Android 使用官方 Flutter + Android SDK/模拟器先完成验证，HarmonyOS 最后处理。
- 环境：Flutter 3.47.8、OpenJDK 17、Android SDK API 36、Pixel 7 AVD。
- 结果：debug APK 在 Android 16 / API 36 模拟器运行通过，3D、2D、雷达、列表、调试面板均验证。
- 后续：Android 真机、release 签名、HarmonyOS-Flutter 插件验证。

## ADR-009 Gradle 使用阿里云镜像

- 状态：已确定
- 日期：2026-10-26
- 决策：Android Gradle 仓库在官方仓库前加入阿里云 Google / Central / Gradle Plugin 镜像。
- 原因：直接访问 Google Maven 出现 429，且 Flutter 引擎下载速度不稳定。
- 影响：国内构建更稳定；海外环境可移除镜像，仅保留 `google()` / `mavenCentral()`。

## ADR-010 后端只做快照、单站刷新与推送

- 状态：已确定
- 日期：2026-10-27
- 决策：服务端职责收敛为定时全量抓取、单站刷新、最新 JSON 快照、匿名订阅与推送。
- 存储：`data/snapshot.json` 保存最新快照；SQLite 仅保存 `devices/subscriptions`（`push.db`）。
- 删除：账号、跨设备同步、WebSocket、站点列表/详情接口、功率接口、状态接口、快照历史表。
- 原因：客户端已持有完整快照，站点列表/详情/功率都可本地计算；减少接口和部署复杂度。
- 约束：单站刷新约 10-15 秒，全量刷新约 3-4 分钟；单站 `observed_at` 独立于全量 `fetched_at`。
- 后续：多实例时再迁移 PostgreSQL/Redis。

## ADR-012 空位推送只推真实释放

- 状态：已确定
- 日期：2026-10-27
- 决策：仅在插口 `busy/float -> free` 时推送；不推“将满”。
- 规则：首次全量刷新不推、旧快照超过 15 分钟不推、同设备同站点 10 分钟冷却。
- 通道：极光 JPush；没有账号时 `PUSH_ENABLED=false` 空跑。
- 原因：只推确定可用的口，降低误报和打扰。

## ADR-011 客户端 API 优先、离线兜底

- 状态：已确定
- 日期：2026-10-27
- 决策：设置 `API_BASE_URL` 时优先请求 `/v1/snapshot`；失败或未设置时回退 `assets/data/snapshot.json`。
- 显示：API 模式顶栏显示「数据」，离线模式显示「快照」。
- 原因：保证没有后端时 demo 仍可运行，同时支持本地/服务器联调。
