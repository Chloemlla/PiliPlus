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
> 对比基线：`upstream/main`（当前对齐 `c1aeaca09` · Release 2.1.0） → 本仓库 `main`  
> 下列条目按主题汇总本分支相对上游的持续增量，覆盖用户可见能力与工程侧改动；不是完整 commit 列表。

### 1. 视频下载委托 Seal（Android）

将详情页三点菜单中的 **「下载视频 / 下载音频」** 从应用内直链导出，改为委托给 [Seal](https://github.com/Chloemlla/Seal)（yt-dlp 下载器）处理队列与落盘。

| 项目 | 说明 |
|------|------|
| 入口 | 视频详情三点菜单：下载视频 / 下载音频 |
| 不变 | **离线缓存** 仍走应用内下载服务 |
| 协议 | Seal L2/L3：`com.chloemlla.seal.action.DOWNLOAD` + `DOWNLOAD_STATUS` |
| 链接 | UGC：`https://www.bilibili.com/video/{bvid}`；PGC：`.../bangumi/play/ep{epId}` |
| 音频 | 走 Seal QuickDownload，并传 `extract_audio=true` |
| 未安装 | Toast「请先安装 Seal」并打开 [Seal Releases](https://github.com/Chloemlla/Seal/releases) |
| 设置 | **委托 Seal 时自动开始下载**（默认关；需 Seal 开启 Allow external auto-start） |
| 面板 | 自有动画状态机：等待确认 → 进行中 → 完成 / 失败 / 取消（跳过「正在启动 Seal」） |

实现要点：

- `SealDownloadChannel`：安装检测、`startActivityForResult` 启动、打开/分享 `content_uri`
- `SealDownloadStatusBridge`（Application 级）：接收定向状态广播，Dart 未就绪时排队，避免退后台丢终态
- `SealDownloadUtils`：自有动画状态面板覆盖 等待确认 → 进行中 → 完成/失败（跳过「正在启动 Seal」阶段）
- 状态机防护：晚到的 Activity Result `needs_ui` / 空会话 `canceled` **不会回退**已进入 accepted 或完成态的面板
- 「后台等待」关闭后仍保留 session 映射，终态广播可再次弹出完成面板
- 启动时 `ensureListening` + `readyForStatus` 握手，引擎重连后可冲刷缓存事件
- 非 Android 平台仍走原 `MediaExportUtils` 内置导出

相关提交示例：`edb5ec38a`、`6512bd796`、`938ddbebe`、`7c350f2c4`、`6f8dfff08`、`a253eb378`。  
Seal 侧联调文档：[third-party-call-guide.md](https://github.com/Chloemlla/Seal/blob/main/docs/third-party-call-guide.md)、[UI 路径终态](https://github.com/Chloemlla/Seal/blob/main/docs/third-party-ui-path-status-callback.md)。

### 2. B 站网页二维码授权（Android）

支持扫描 / 识别 B 站官方网页登录二维码并完成授权，替代不稳定链路、补齐重试与会话完整性。

能力概览：

- 入口：Web QR 授权页（相机实时扫码 / 相册识别）
- URL 解析与场景模型：`WebQrAuthHttp` + `models_new/web_qr_auth`（host / 显式端口 / 场景参数）
- 扫码链路：Android `QrScannerActivity` + `qr_scanner.dart`；延后初始化 ML Kit，替换不稳定解码路径
- 会话：失败可重试，授权时附着账号 Cookie；启动扫码时加固权限与 native 崩溃防护
- 安全：日志脱敏（`LogRedactor`），降低 Cookie / 凭据泄露风险
- 结果：授权后与现有账号体系打通，可正常访问登录态接口

相关方向：`web_qr_auth` / `fix(qr): ...` 系列。

### 3. 崩溃捕获、过滤与历史

跨 Flutter / Android 的故障可观测性，避免噪声诊断冲刷真实问题。

| 模块 | 作用 |
|------|------|
| `CrashReporter` / `CrashReportHandler` | 统一接入 Flutter 未处理异常与部分启动失败 |
| `CrashReportFilter` | 过滤非可操作的播放器诊断，减少误报 |
| `CrashReportStore` / `CrashReportArchive` | 有界本地历史、合并归档语义 |
| Crash report UI | 列表查看、分享详情（系统信息、堆栈、近期事件） |
| `lumen-crash` | Android native 捕获桥：`PiliPlusApplication` 安装 SDK，`NativeCrashChannel` 导入 pending report |

实现要点：

- Flutter 与 Android 双侧捕获；启动阶段可提示最近严重崩溃
- **lumen-crash**（`com.chloemlla.lumen:lumen-crash`）作为 Android 进程内捕获桥，失败安装不阻断冷启动（对 Baseline Profile / CI 冷启友好）
- 进程退出采集（`ProcessExitCollector`）与 breadcrumb / module 解析，便于定位业务面
- 相关单测：`crash_report_*`、归档合并语义

相关方向：`feat(crash)` / `fix(crash)` / `6c179a79b` lumen-crash 接入。

### 4. Android 存储：MMKV 热路径

Android 热数据从纯 Hive 读写迁移为 **MMKV 后端**，非 Android 或 MMKV 不可用时仍回落 Hive。

- 覆盖 box：`userInfo`、`localCache`、`setting`、`historyWord`、`video`、`watchProgress`、`reply` 等
- `AndroidMmkvBackedBox` + Java bridge（`AndroidMmkv`）：迁移 marker、codec 编解码、批量写
- **lazy open / staged open / lighter close**，观看进度与 reply 等大箱可懒加载
- 批量写与 LRU 上限优化，降低启动与热路径开销
- 解码失败时避免误用过期 Hive 快照覆盖新 MMKV 数据
- 设置导入校验、账号导入一致性、WebDAV 备份安全性增强
- 单测：`test/utils/android_mmkv_box_test.dart` 等

相关方向：`a70f5d90e`、`298b811a7`、`7d7c1bd96`、`655aa5c24` 及后续 fix。

### 5. 密钥、隐私与日志安全

- `AccountSecretStore` / `SettingSecretStore`：账号 access key、WebDAV 密码等敏感字段迁出普通 Hive 明文，改为独立加密 sidecar
- 设置导出 / 备份路径排除或校验敏感字段，降低明文外泄面
- Android **复制登录 Cookie** 需通过系统锁屏 / PIN 验证（`AndroidCredentialAuth`）
- `LogRedactor`：日志与崩溃上下文中的敏感字段脱敏
- 相关单测：`account_secret_store_test`、`setting_secret_store_test`、`log_redactor_test`、`settings_backup_validator_test`

### 6. 媒体导出与播放体验

- 内置 `MediaExportUtils`：视频 MP4 直链导出 / 音频 DASH → `.m4a`（多分段等场景有明确失败提示）
- **Android 视频菜单优先委托 Seal**；非 Android 或未走菜单委托时仍可用内置导出
- 播放器网络流错误分类与中断重试（`stream_error` 相关契约与单测）
- 音频心跳 / seek / 切轨时重置时长，减少异常上报
- Android **NativeMediaService**：`MediaSession` + 前台媒体通知通道，补齐系统媒体控件
- 下载服务：分段下载并发管理等稳定性调整

### 7. 剪贴板视频链接

- `ClipboardVideoLinkHandler`：识别剪贴板 B 站视频链接（含 **b23 短链**）
- 设置项 **自动打开剪贴板视频**（默认关）：回前台时检测并提示
- 搜索提交、活动页打开前可识别链接，避免重复弹窗
- 正在看视频时再打开剪贴板链接前二次确认

### 8. 首启权限与 Android 包标识

- `AndroidFirstLaunchPermissionGate`：首次启动权限引导（通知、相册/媒体、存储、亮度等，按系统版本适配）
- 权限对话框等待 Navigator 就绪，避免无 context 崩溃
- 应用包名 / namespace：`com.chloemlla.piliplus`（debug / dev 使用 applicationIdSuffix）
- 更新检查与源码地址指向本仓库 `Chloemlla/PiliPlus`（`Constants.sourceCodeRepository` / GitHub Releases）
- `minSdk` 抬升以适配 lumen-crash（≥ 26），target SDK 与 CI 依赖同步调整

### 9. CI / Baseline Profile / 发布工程

- 增加 Android **Baseline Profile** 生成模块与 workflow 任务
- 模拟器冷启 / ATD / AOSP 镜像选择、磁盘清理、产物归档与校验拆分
- Baseline Profile 启动路径持续硬化（Flutter 模拟器与 ATD 上的启动崩溃规避）
- Release APK 构建：磁盘空间清理、APK 重命名稳健化、workflow 英文命名、签名 / 私钥检测正则增强
- 构建补丁：strip pub-cache manifest packages 等
- 检查更新动作 pin、workflow dispatch 密钥写入条件修正

### 10. 测试、质量与协作

- 持续 **merge upstream**，在保留本分支特性的前提下吸收上游修复
- 新增 / 扩展单测：MMKV、密钥 store、崩溃归档过滤、Web QR 场景、网络策略、播放器 stream error、settings backup 等
- `tool/check_import_boundaries.py`：导入边界检查
- Trellis 任务流 / 规格文档（仓库内 `.trellis/`，默认本地）支撑 AI 协作开发
- 分析器警告清理、局部 UI 一致性与数据安全修缮

### 使用提示（Seal 下载）

1. 安装 [Chloemlla/Seal](https://github.com/Chloemlla/Seal/releases)（包名 `com.chloemlla.seal`）
2. Seal：**设置 → Interface & interaction → External downloads** 开启外部委托
3. 可选：Seal 开启 *Allow external auto-start*，并在 PiliPlus 开启「委托 Seal 时自动开始下载」
4. 视频页三点菜单 → 下载视频 / 下载音频
5. 完成态依赖 Seal L3 状态广播；UI 确认后应看到「进行中 → 完成」动画面板自动切换（详见 Seal UI 路径文档）

### 说明

- 本列表**不是**完整 changelog，而是本分支相对上游的主要增量说明（约覆盖 `upstream/main..main` 的主题面）。
- 上游已有的通用功能（推荐流、弹幕、动态、私信等）见下文 `feat` / `功能` 清单。
- 若与上游行为冲突，以本仓库 `main` 与对应 commit 为准。

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
