<div align="center">
    <img width="200" height="200" src="assets/images/logo/logo.png">
</div>



<div align="center">
    <h1>PiliPlus</h1>
<div align="center">
    
![GitHub repo size](https://img.shields.io/github/repo-size/Chloemlla/PiliPlus) 
![GitHub Repo stars](https://img.shields.io/github/stars/Chloemlla/PiliPlus) 
![GitHub all releases](https://img.shields.io/github/downloads/Chloemlla/PiliPlus/total) 
</div>
    <p>使用Flutter开发的BiliBili第三方客户端</p>
    
<img src="assets/screenshots/510shots_so.png" width="32%" alt="home" />
<img src="assets/screenshots/174shots_so.png" width="32%" alt="home" />
<img src="assets/screenshots/850shots_so.png" width="32%" alt="home" />
<br/>
<img src="assets/screenshots/main_screen.png" width="96%" alt="home" />
<br/>
</div>


<br/>

## 适配平台

- [x] Android
- [x] iOS
- [x] Pad
- [x] Windows
- [x] Linux

[![Packaging status](https://repology.org/badge/vertical-allrepos/piliplus.svg)](https://repology.org/project/piliplus/versions)



## 本分支（Chloemlla/main）相对上游的改进

> 仓库：[Chloemlla/PiliPlus](https://github.com/Chloemlla/PiliPlus)  
> 上游参考：[bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) · 更早：[orz12/PiliPalaX](https://github.com/orz12/PiliPalaX) / [guozhigq/pilipala](https://github.com/guozhigq/pilipala)  
> 对比基线：`upstream/main`（当前对齐 `c1aeaca09` · Release 2.1.0） → 本仓库 `main`（约 98 个本分支增量提交）  
> 本文按**功能模块**汇总本分支相对上游的主要改进：用户可见行为、关键实现入口、平台范围与工程保障。  
> **不是**完整 changelog / 提交列表；上游已有的通用能力见下文 `feat` / `功能` 清单。

### 0. 总览

| 模块 | 平台 | 用户侧收益 | 关键入口 |
|------|------|------------|----------|
| Seal 外部下载委托 | Android | 详情页下载走 Seal 队列，可回传完成/失败状态 | `SealDownloadUtils` / `SealDownloadChannel` |
| B 站网页二维码授权 | Android | 扫网页登录码授权本机账号 | `WebQrAuthPage` / `WebQrAuthHttp` / `QrScannerActivity` |
| 崩溃捕获与历史 | Android + Flutter | 可过滤噪声、本地查看/分享崩溃 | `CrashReporter` / `lumen-crash` |
| MMKV 热存储 | Android | 设置/进度/缓存更快，大箱懒加载 | `AndroidMmkvBackedBox` |
| 密钥旁路与隐私 | 全平台（部分 Android） | Cookie/密钥不再明文落库；复制 Cookie 需系统验证 | `AccountSecretStore` / `AndroidCredentialAuth` |
| 媒体导出 / 系统媒体控件 | 多平台 / Android | 内置导出 + 系统通知/MediaSession | `MediaExportUtils` / `NativeMediaService` |
| 剪贴板视频链接 | 移动端 | 识别 bilibili / b23 链接并可选自动打开 | `ClipboardVideoLinkHandler` |
| 首启权限 / 包标识 / 更新源 | Android | 首启权限引导；包名与更新源指向本仓库 | `AndroidFirstLaunchPermissionGate` / `Constants` |
| CI / Baseline Profile | 工程 | 冷启 profile 生成、校验与发布流硬化 | `:baselineprofile` / `.github/workflows/build.yml` |

---

### 1. 视频下载委托 Seal（Android）

#### 问题与目标
上游详情页「下载视频 / 下载音频」更偏应用内直链导出；复杂清晰度、音视频分离与队列管理成本高。本分支将 **菜单下载** 委托给 [Seal](https://github.com/Chloemlla/Seal)（yt-dlp 前端），由 Seal 负责解析、队列与落盘，PiliPlus 负责发起与状态呈现。

#### 用户可见行为
- 视频详情三点菜单：**下载视频 / 下载音频**
- **离线缓存** 仍走应用内 `DownloadService`，与 Seal 委托互不替代
- 未安装 Seal：Toast「请先安装 Seal」并打开 [Seal Releases](https://github.com/Chloemlla/Seal/releases)
- 已安装：拉起 Seal，并显示 PiliPlus 自有动画状态面板  
  `等待确认 / 自动入队 → 进行中 → 完成 / 失败 / 取消`  
  （**跳过**「正在启动 Seal」中间态，减少闪屏感）
- 设置项：**委托 Seal 时自动开始下载**（默认关；需 Seal 开启 Allow external auto-start）
- 完成态可打开 / 分享 `content_uri`；关闭「后台等待」后仍可在终态广播到达时再弹出完成面板

#### 协议与链接
| 项 | 说明 |
|----|------|
| 动作 | L2/L3：`com.chloemlla.seal.action.DOWNLOAD` + 状态广播 `DOWNLOAD_STATUS` |
| UGC | `https://www.bilibili.com/video/{bvid}` |
| PGC | `https://www.bilibili.com/bangumi/play/ep{epId}` |
| 音频 | Seal QuickDownload + `extract_audio=true` |
| 会话 | 每次委托生成 `requestId`，Dart session map 跟踪生命周期 |

#### 实现结构
- `SealDownloadUtils`：Dart 侧门面；`ensureListening` / `readyForStatus` 握手；面板状态机；防回退逻辑
- `SealDownloadChannel`：安装检测、`startActivityForResult`、打开/分享结果文件
- `SealDownloadStatusBridge`（`PiliPlusApplication` 安装）：Application 级接收定向状态广播；Dart 引擎未就绪时排队，避免退后台丢终态
- 状态机防护：晚到的 Activity Result `needs_ui` / 空会话 `canceled` **不会回退**已进入 `accepted` 或终态的面板
- 非 Android：仍走 `MediaExportUtils` 内置导出

#### 相关提交方向
`edb5ec38a` 委托入口 · `6512bd796` L3 状态接收加固 · `938ddbebe` 自有动画面板 · `7c350f2c4` 跳过 launching 阶段 · `6f8dfff08` 音频 QuickDownload · `a253eb378` 面板 UX 收紧。

Seal 联调文档：[third-party-call-guide.md](https://github.com/Chloemlla/Seal/blob/main/docs/third-party-call-guide.md)、[UI 路径终态](https://github.com/Chloemlla/Seal/blob/main/docs/third-party-ui-path-status-callback.md)。

---

### 2. B 站网页二维码授权（Android）

#### 问题与目标
支持扫描 / 识别 **B 站官方网页登录二维码**，用本机已登录账号完成网页端授权；补齐 URL 校验、会话完整性、重试与扫码链路稳定性。

#### 用户可见行为
- 入口页：`扫描网页登录`（`WebQrAuthPage`）
- 输入方式：相机实时扫码 / 相册识别 / 手动粘贴二维码链接
- 解析成功后展示场景信息（环境、是否临时登录、短信二次验证等）
- 可确认授权；失败可重试；权限被永久拒绝时引导打开系统设置
- 授权成功后与现有账号体系打通，登录态接口可继续使用

#### 实现结构
| 层 | 组件 | 职责 |
|----|------|------|
| UI | `lib/pages/web_qr_auth/*` | 阶段机 `idle/loading/ready/confirming/success/error`、场景面板、扫码源面板 |
| HTTP | `WebQrAuthHttp` | passport 场景查询 / 确认 / 短信与极验相关接口；请求附着账号 Cookie |
| 模型 | `models_new/web_qr_auth` | 二维码 key、场景、环境参数；host / 显式默认端口校验 |
| Native 扫码 | `QrScannerActivity` + CameraX / ZXing 等 | 延后初始化、替换不稳定 ML Kit 解码路径，降低启动扫码 native 崩溃 |
| Dart 通道 | `AndroidQrScanner` | 相机权限、错误码映射、相册解码 |

#### 安全与可观测
- 授权链路 cookie / verify code 经 `LogRedactor` 脱敏
- `CrashBreadcrumbs` 记录扫码阶段（start / decoded / cancelled / error），便于对照崩溃历史

#### 相关提交方向
`8bc531050` 场景模型 · `437f741fd` 解码路径替换 · `ec8ac7588` 延后初始化 · `3ce6a1278` 附着 Cookie · 以及多轮 `fix(qr)` 重试 / 端口 / 权限加固。

---

### 3. 崩溃捕获、过滤与历史

#### 问题与目标
播放器与网络层会产生大量**不可操作**诊断噪声；同时需要跨 Flutter / Android 保留可复盘的真实故障，并在启动时提示最近严重崩溃。

#### 用户可见行为
- 本地崩溃历史：列表、详情（系统信息、堆栈、近期事件）、分享
- 启动阶段若存在上一会话严重崩溃，可提示查看
- 常见 media-kit / TCP / SSL seek 等诊断默认过滤，避免误报淹没真实问题

#### 模块分工
| 模块 | 作用 |
|------|------|
| `CrashReporter` / `CrashReportHandler` | 安装 FlutterError / PlatformDispatcher 钩子；同步/异步记录 |
| `CrashReportFilter` | 过滤 SSL seek、TCP 断流、AMediaCodec 等非可操作诊断 |
| `CrashReportStore` / `CrashReportArchive` | 有界本地历史、合并归档语义 |
| `CrashBreadcrumbs` / `CrashModuleResolver` | 导航与业务面包屑、模块定位 |
| `lumen-crash` | Android native 捕获桥 |
| `NativeCrashBridge` / `NativeCrashChannel` | 导入 pending report / lumen report 并 acknowledge |
| `ProcessExitCollector` | 后台线程采集进程退出历史 |

#### lumen-crash 接入要点
- 依赖：`com.chloemlla.lumen:lumen-crash`（Compose BOM 对齐 api 依赖）
- 安装点：`PiliPlusApplication.attachBaseContext` / `onCreate`（幂等；失败安装 **不阻断** 冷启动，适配 Baseline Profile / CI）
- Dart 侧：`CrashReporter.ensureInitialized()` 导入 native / lumen pending report
- `minSdk` 抬升至 ≥ 26（与 lumen-crash 对齐）

#### 相关提交方向
`a85ea371b` 双侧捕获 · `fb82add62` 过滤历史 · `cff4affcb` 崩溃 UI · `6c179a79b` lumen-crash · `15b490691` Compose BOM · 相关单测 `test/services/crash/*`。

---

### 4. Android 存储：MMKV 热路径

#### 问题与目标
将 Android 热读写从纯 Hive 迁移为 **MMKV 后端**，降低设置、缓存、观看进度等路径延迟；大箱支持懒加载与 LRU 上限，避免启动期全量解码。

#### 覆盖范围
- 典型 box：`userInfo`、`localCache`、`setting`、`historyWord`、`video`
- 大箱懒加载：`watchProgress`、`reply`（`AndroidMmkvLoadMode.lazy`）
- 非 Android / MMKV 不可用：透明回落 Hive

#### 实现要点
- `openAndroidMmkvBackedBox` + `AndroidMmkvBackedBox`：迁移 marker、codec 编解码、批量写、lazy key 集合
- 迁移失败 / 解码失败时 **不** 用过期 Hive 快照覆盖已迁移 MMKV 数据
- `BoundedStringKeyLru` + `WatchProgressStore` / `ReplyCacheStore`：写序近似 LRU，控制大箱膨胀
- staged open / lighter close，减少启动与退出开销
- 设置导入校验、账号导入一致性、WebDAV 备份安全性同步增强

#### 相关提交方向
`a70f5d90e` 热存储 · `298b811a7` 完整迁移 · `7d7c1bd96` 批量写/LRU · `655aa5c24` lazy/staged open · 单测 `test/utils/android_mmkv_box_test.dart`、`bounded_string_key_lru_test.dart`。

---

### 5. 密钥、隐私与日志安全

#### 敏感字段旁路存储
- `AccountSecretStore`：账号 cookies / accessKey / refresh 独立 AES-GCM 加密文件（`account_secrets.json.enc` + key 文件）
- `SettingSecretStore`：设置侧敏感串（如 WebDAV 密码）同样旁路加密
- 账号 adapter 读写时组合公开字段 + secret sidecar；导出 / 备份路径排除或校验敏感字段

#### 用户操作保护
- Android **复制登录 Cookie**（隐私设置）：必须先过 `AndroidCredentialAuth`（系统锁屏 / PIN / 生物识别）
- 未登录、验证失败、系统验证不可用均有明确 Toast

#### 日志与崩溃脱敏
- `LogRedactor`：Cookie / SESSDATA / access_key / refresh_token / 验证码 / 本地路径 / content URI 等统一替换为 `[REDACTED]` 或占位符
- 崩溃报告与日志页面共享脱敏规则，降低分享报告时的凭据泄露面

#### 相关单测
`account_secret_store_test`、`setting_secret_store_test`、`log_redactor_test`、`settings_backup_validator_test`。

---

### 6. 媒体导出与播放体验

#### 内置媒体导出（多平台）
`MediaExportUtils`：
- 视频：MP4 直链（durl，音视频合一；多分段明确失败提示）
- 音频：当前 DASH 音频流导出为 `.m4a`
- Android 详情菜单 **优先委托 Seal**；非 Android 或未走委托路径时仍可用内置导出

#### 播放器稳定性
- `PlPlayerStreamError`：区分网络打开失败 vs 中断断流，支撑中断重试
- 音频心跳 / seek / 切轨时重置时长，减少异常时长上报
- 下载服务分段并发管理等稳定性调整

#### Android 系统媒体控件
- `NativeMediaService`：`MediaSession` + 前台通知通道
- `NativeMediaNotificationService`：Flutter ↔ native 动作桥（播放/暂停/上下首/快进退/倍速/弹幕/循环/睡眠定时等）
- 系统媒体中心 / 通知栏可控制正在播放内容

---

### 7. 剪贴板视频链接

#### 用户可见行为
- 设置：**自动打开剪贴板视频**（默认关）
- 回前台时检测剪贴板中的 B 站视频链接（含 **b23.tv 短链**，会解析跳转）
- 搜索提交 / 活动页打开前可识别链接，避免重复弹窗
- 当前已在视频页（`/videoV`）时再次打开剪贴板链接会二次确认
- 同链 3 秒节流 + 会话内 link/videoKey 去重，防止连弹

#### 实现
- `ClipboardVideoLinkHandler` + 生命周期 observer
- `IdUtils` 归一化 aid/bvid；`UrlUtils.parseRedirectUrl` 解析 b23

---

### 8. 首启权限与 Android 包标识

#### 首启权限引导
- `AndroidFirstLaunchPermissionGate` / `AndroidFirstLaunchPermissionService`
- 首次启动按系统版本请求通知、相册/媒体、存储、亮度等相关权限
- 每项先说明原因；永久拒绝可引导应用设置
- **必须等 Navigator 就绪**再弹窗，避免冷启无 context 崩溃；未完成则下次重试

#### 包名、更新源与 SDK
| 项 | 本分支 |
|----|--------|
| `applicationId` / `namespace` | `com.chloemlla.piliplus` |
| debug / dev | `.debug` / `.dev` suffix |
| 源码与更新 | `Constants.sourceCodeRepository = Chloemlla/PiliPlus`；检查更新走本仓库 Releases |
| `minSdk` | `max(flutter.minSdk, 26)`（lumen-crash） |
| 依赖 | MMKV、CameraX、ZXing、lumen-crash、ProfileInstaller 等 |

---

### 9. CI / Baseline Profile / 发布工程

#### Baseline Profile
- 模块：`android/baselineprofile`（`BaselineProfileGenerator`）
- workflow：Generate → Validate（`baseline-prof.txt` / `startup-prof.txt` 非空）→ Upload artifact
- 合并策略：`mergeIntoMain = true`，构建期不自动生成，CI 显式任务生成

#### 冷启与模拟器硬化（近期重点）
- Flutter 模拟器 / ATD / AOSP 默认镜像选择修正
- 启动路径规避 lumen-crash 安装失败拖垮冷启
- 磁盘清理、emulator boot 可靠化、产物归档拆分

#### 发布与安全流水线
- Release APK 重命名稳健化、workflow 英文命名
- 签名 / 私钥检测正则增强；workflow dispatch 写密钥条件修正
- strip pub-cache manifest packages 等 Android 补丁
- 检查更新 action pin，降低供应链漂移

---

### 10. 测试、质量与协作工程

- 持续 **merge upstream**，在保留本分支特性的前提下吸收上游修复
- 单测扩展：MMKV、密钥 store、崩溃归档/过滤、Web QR 场景、网络策略、播放器 stream error、settings backup、bounded task queue 等
- `tool/check_import_boundaries.py`：导入边界检查
- 仓库内 Trellis 任务流 / 规格（`.trellis/`，默认本地）支撑 AI 协作开发
- 分析器警告清理、局部 UI 与数据安全修缮

---

### 使用提示（Seal 下载）

1. 安装 [Chloemlla/Seal](https://github.com/Chloemlla/Seal/releases)（包名 `com.chloemlla.seal`）
2. Seal：**设置 → Interface & interaction → External downloads** 开启外部委托
3. 可选：Seal 开启 *Allow external auto-start*，并在 PiliPlus 开启「委托 Seal 时自动开始下载」
4. 视频页三点菜单 → 下载视频 / 下载音频
5. 完成态依赖 Seal L3 状态广播；UI 确认后应看到「进行中 → 完成」动画面板自动切换（详见 Seal UI 路径文档）

### 说明

- 本列表**不是**完整 changelog，而是本分支相对上游的**功能模块级**增量说明（覆盖 `upstream/main..main` 主要主题面）。
- 上游已有的通用功能（推荐流、弹幕、动态、私信等）见下文 `feat` / `功能` 清单。
- 若与上游行为冲突，以本仓库 `main` 与对应实现/commit 为准。

---

## refactor

- [ ] gRPC [wip]
- [x] 用户界面
- [x] 其他

## feat

- [x] 编辑动态
- [x] DLNA 投屏
- [x] 离线缓存/播放
- [x] Android 视频菜单委托 Seal 下载（视频/音频）
- [x] 移动端支持点击弹幕悬停，点赞、复制、举报 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] 播放音频
- [x] 跳过番剧片头/片尾
- [x] 安卓端 `loudnorm` 适配 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] Win/Mac 支持极验、短信登录 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] 视频截取动图 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] AI 原声翻译
- [x] SuperChat
- [x] 播放课堂视频
- [x] 发起投票
- [x] 发布动态/评论支持`富文本编辑`/`表情显示`/`@用户`
- [x] 修改消息设置
- [x] 修改聊天设置
- [x] 展示折叠消息
- [x] 查看用户图文
- [x] 动态话题
- [x] 直播分区
- [x] 分享`视频`/`番剧`/`动态`/`专栏`/`直播`至消息
- [x] 创建/修改/删除关注分组
- [x] 移除粉丝
- [x] 直播弹幕发送表情
- [x] 收藏夹排序
- [x] 稍后再看 ~~`未看`~~ / `未看完` / ~~`已看完`~~ 分类
- [x] WebDAV 备份/恢复设置
- [x] 保存评论/动态
- [x] 高级弹幕 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] 取消/置顶评论
- [x] 记笔记
- [x] 多账号支持 by [@My-Responsitories](https://github.com/My-Responsitories)
- [x] 屏蔽带货动态/评论
- [x] 互动视频
- [x] 发评/动态反诈
- [x] 崩溃捕获过滤与历史
- [x] 高能进度条
- [x] 滑动跳转预览视频缩略图
- [x] Live Photo
- [x] 复制/移动/排序收藏夹/稍后再看视频
- [x] 超分辨率
- [x] 合并弹幕
- [x] 会员彩色弹幕
- [x] 播放全部/继续播放/倒序播放
- [x] Cookie登录
- [x] B 站网页二维码授权（Android）
- [x] Android MMKV 热存储与懒加载
- [x] 账号/设置密钥旁路存储与 Cookie 凭据保护
- [x] 剪贴板视频链接识别（含 b23）与自动打开
- [x] Android 首次启动权限引导
- [x] Android 系统媒体通知 / MediaSession
- [x] 显示视频分段信息
- [x] 调节字幕大小
- [x] 调节全屏弹幕大小
- [x] 收藏夹/稍后再看多选删除
- [x] 搜索用户动态
- [x] 直播弹幕
- [x] 修改头像/用户名/签名/性别/生日
- [x] 创建/编辑/删除收藏夹
- [x] 评论楼中楼查看对话
- [x] 评论楼中楼定位点击查看的评论
- [x] 评论楼中楼按热度/时间排序
- [x] 评论点踩
- [x] 私信发图
- [x] 投币动画
- [x] 取消/追番，更新追番状态
- [x] 取消/订阅合集
- [x] SponsorBlock
- [x] 显示视频完整合集
- [x] 三连动画
- [x] 番剧三连
- [x] 带图评论
- [x] 视频TAG
- [x] 筛选搜索
- [x] 转发动态
- [x] 合集图片
- [x] 删除/置顶/撤回私信
- [x] 举报用户/评论/视频/动态
- [x] 删除/发布/置顶文本/图片动态
- [x] 其他

## opt

- [x] 专栏界面
- [x] 私信界面
- [x] 收藏面板
- [x] PIP
- [x] 视频封面
- [x] 回复界面
- [x] 系统通知
- [x] 评论显示
- [x] 亮度调节
- [x] 视频播放
- [x] 视频staff
- [x] 防止bottomsheet遮挡全屏视频
- [x] 其他

## fix

- [x] 番剧分集点赞/投币/收藏
- [x] bugs

<br/>

## 功能

- [x] 推荐视频列表(app端)
- [x] 最热视频列表
- [x] 热门直播
- [x] 番剧列表
- [x] 屏蔽黑名单内用户视频
- [x] 无痕模式（播放视为未登录）
- [x] 游客模式（推荐视为未登录）

- [x] 用户相关
  - [x] 粉丝、关注用户、拉黑用户查看
  - [x] 用户主页查看
  - [x] 关注/取关用户
  - [x] 离线缓存
  - [x] 稍后再看
  - [x] 观看记录
  - [x] 我的收藏
  - [x] 站内私信
  
- [x] 动态相关
  - [x] 全部、投稿、番剧分类查看
  - [x] 动态评论查看
  - [x] 动态评论回复功能

- [x] 视频播放相关
  - [x] 双击快进/快退
  - [x] 双击播放/暂停
  - [x] 垂直方向调节亮度/音量
  - [x] 垂直方向上滑全屏、下滑退出全屏
  - [x] 水平方向手势快进/快退
  - [x] 全屏方向设置
  - [x] 倍速选择/长按2倍速
  - [x] 硬件加速（视机型而定）
  - [x] 画质选择（高清画质未解锁）
  - [x] 音质选择（视视频而定）
  - [x] 解码格式选择（视视频而定）
  - [x] 弹幕
  - [x] 字幕
  - [x] 记忆播放
  - [x] 视频比例：高度/宽度适应、填充、包含等
     
- [x] 搜索相关
  - [x] 热搜
  - [x] 搜索历史
  - [x] 默认搜索词
  - [x] 投稿、番剧、直播间、用户搜索
  - [x] 视频搜索排序、按时长筛选
    
- [x] 视频详情页相关
  - [x] 视频选集(分p)切换
  - [x] 点赞、投币、收藏/取消收藏
  - [x] 相关视频查看
  - [x] 评论用户身份标识
  - [x] 评论(排序)查看、二楼评论查看
  - [x] 主楼、二楼评论回复功能
  - [x] 评论点赞
  - [x] 评论笔记图片查看、保存

- [x] 设置相关
  - [x] 画质、音质、解码方式预设      
  - [x] 图片质量设定
  - [x] 主题模式：亮色/暗色/跟随系统
  - [x] 震动反馈(可选)
  - [x] 高帧率
  - [x] 自动全屏
  - [x] 横屏适配
- [ ] 等等

<br/>

## 下载

可以通过右侧release进行下载或拉取代码到本地进行编译

<br/>

## 声明

此项目（PiliPlus）是个人为了兴趣而开发，仅用于学习和测试，请于下载后24小时内删除。
所用API皆从官方网站收集，不提供任何破解内容。
在此致敬原作者：[guozhigq/pilipala](https://github.com/guozhigq/pilipala)
在此致敬上游作者：[orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)
本仓库做了更激进的修改，感谢原作者的开源精神。

感谢使用


<br/>

## 致谢

- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
- 等等

<br/>
<br/>
<br/>

## Star History

<a href="https://www.star-history.com/#Chloemlla/PiliPlus&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Chloemlla/PiliPlus&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Chloemlla/PiliPlus&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=Chloemlla/PiliPlus&type=Date" />
 </picture>
</a>
