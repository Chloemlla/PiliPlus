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
> 下列条目汇总本 `main` 分支相对上游的持续改动，按主题分组，便于对照提交历史。

### 1. 视频下载委托 Seal（Android）

将详情页三点菜单中的 **「下载视频 / 下载音频」** 从应用内直链导出，改为委托给 [Seal](https://github.com/Chloemlla/Seal)（yt-dlp 下载器）处理队列与落盘。

| 项目 | 说明 |
|------|------|
| 入口 | 视频详情三点菜单：下载视频 / 下载音频 |
| 不变 | **离线缓存** 仍走应用内下载服务 |
| 协议 | Seal L2/L3：`com.chloemlla.seal.action.DOWNLOAD` + `DOWNLOAD_STATUS` |
| 链接 | UGC：`https://www.bilibili.com/video/{bvid}`；PGC：`.../bangumi/play/ep{epId}` |
| 音频 | 传 `extract_audio=true`（需 Seal 侧识别为音频类型） |
| 未安装 | Toast「请先安装 Seal」并打开 [Seal Releases](https://github.com/Chloemlla/Seal/releases) |
| 设置 | **委托 Seal 时自动开始下载**（默认关；需 Seal 开启 Allow external auto-start） |

实现要点：

- `SealDownloadChannel`：安装检测、`startActivityForResult` 启动、打开/分享 `content_uri`
- `SealDownloadStatusBridge`（Application 级）：接收定向状态广播，Dart 未就绪时排队，避免退后台丢终态
- `SealDownloadUtils`：构造 bilibili 页 URL、订阅状态、完成居中成功卡片（打开 / 分享 / 关闭）
- 启动时 `ensureListening` + `readyForStatus` 握手，引擎重连后可冲刷缓存事件
- 非 Android 平台仍走原 `MediaExportUtils` 内置导出

相关提交示例：`edb5ec38a`、`6512bd796`。  
Seal 侧联调文档：[third-party-call-guide.md](https://github.com/Chloemlla/Seal/blob/main/docs/third-party-call-guide.md)。

### 2. B 站网页二维码授权（Android）

支持扫描 / 识别 B 站官方网页登录二维码并完成授权，替代不稳定链路、补齐重试与会话完整性。

- Android 侧扫码通道（相机 / 相册），启动与解码流程加固，降低 native 崩溃
- Web QR 授权会话：URL 解析、场景模型、显式端口校验、Cookie 附着
- 失败可重试；敏感信息脱敏，避免日志泄露账号凭据
- 与账号体系打通，授权后可正常使用登录态接口

相关方向提交：`web_qr_auth` / `fix(qr): ...` 系列。

### 3. 崩溃捕获、过滤与历史

跨 Flutter / Android 的故障可观测性，避免噪声诊断冲刷真实问题。

- 统一捕获 Flutter 未处理异常与部分 native / 启动失败
- **过滤** 非可操作的播放器诊断，减少误报
- **本地崩溃历史**：有界存储、列表查看、分享详情（系统信息、堆栈、近期事件）
- 启动阶段可提示最近严重崩溃；归档语义有测试覆盖

相关方向：`feat(crash)` / `fix(crash)` / crash report UI。

### 4. Android 存储：MMKV 热路径

- 完成 Android 端 **MMKV** 作为热存储后端的迁移（相对纯 Hive 的读写路径）
- 修复 MMKV 解码失败时误覆盖 legacy Hive 数据的问题
- Box 可用性检查、迁移逻辑、批量操作错误处理
- 设置导入校验、账号导入一致性、WebDAV 备份安全性增强

相关方向：`feat(android): complete MMKV storage migration`、`perf(android): add MMKV-backed hot storage` 及后续 fix。

### 5. 媒体导出与播放体验

- 内置 **下载视频 / 下载音频** 媒体导出能力（MP4 直链 / DASH 音频；现 Android 菜单优先委托 Seal）
- 播放器网络流错误分类与中断重试
- 升级后保留默认编解码偏好（避免升级重置）
- 音频心跳 / seek / 切轨时重置时长，减少异常上报
- 导出字幕等体验优化

### 6. 剪贴板视频链接

- 识别剪贴板中的 B 站视频链接（含 **b23 短链**）
- 搜索提交、活动页打开前可提示，避免重复弹窗
- 正在看视频时再打开剪贴板链接前二次确认

### 7. 首启与权限 / CI

- Android **首次启动权限** 引导；对话框等待 Navigator 就绪，避免无 context 崩溃
- CI：Release APK 构建磁盘清理、模拟器架构与 profile 调整
- Baseline Profile 产物归档与校验拆分
- Android 构建补丁：strip pub-cache manifest packages 等工程向修复

### 8. 工程与协作

- 持续 **merge upstream**，在保留本分支特性的前提下吸收上游修复
- Trellis 任务流 / 规格文档用于 AI 协作开发（仓库内 `.trellis/`，默认本地）
- 分析器警告清理、测试补充、导入边界检查等质量维护

### 使用提示（Seal 下载）

1. 安装 [Chloemlla/Seal](https://github.com/Chloemlla/Seal/releases)（包名 `com.chloemlla.seal`）
2. Seal：**设置 → Interface & interaction → External downloads** 开启外部委托
3. 可选：Seal 开启 *Allow external auto-start*，并在 PiliPlus 开启「委托 Seal 时自动开始下载」
4. 视频页三点菜单 → 下载视频 / 下载音频
5. 完成态依赖 Seal L3 状态广播；UI 确认路径需 Seal 侧 watch 任务（详见 Seal 文档）

### 说明

- 本列表**不是**完整 changelog，而是本分支相对上游的主要增量说明。
- 上游已有的通用功能（推荐流、弹幕、动态、私信等）见上文 `feat` / `功能` 清单。
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
