import 'package:flutter/material.dart';

final class ImprovementsGuidePageData {
  const ImprovementsGuidePageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
    this.tip,
    this.platformHint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final String? tip;
  final String? platformHint;
}

/// User-facing explanation of Chloemlla/main deltas vs upstream.
abstract final class ImprovementsGuideData {
  static const branchLabel = 'Chloemlla/main';
  static const upstreamLabel = 'bggRGjQaUbCoE/PiliPlus';

  static const List<ImprovementsGuidePageData> pages = [
    ImprovementsGuidePageData(
      icon: Icons.auto_awesome_outlined,
      title: '欢迎使用本分支 PiliPlus',
      subtitle:
          '你安装的是 $branchLabel。它在上游 $upstreamLabel 之上保留了额外能力与工程加固，下面按模块说明「改了什么、怎么用」。',
      bullets: [
        '本引导仅在首次安装打开时出现，可随时在「设置 → 关于」再次查看。',
        '上游通用功能（推荐、弹幕、动态、私信等）仍然保留。',
        '若与上游行为不一致，以本仓库 main 与对应说明为准。',
      ],
      tip: '可左右滑动浏览，或点「跳过」直接进入应用。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.download_for_offline_outlined,
      title: '下载视频交给 Seal',
      subtitle: '视频详情菜单里的「下载视频 / 下载音频」在 Android 上优先委托 Seal（yt-dlp）处理队列与落盘。',
      platformHint: 'Android',
      bullets: [
        '离线缓存仍走应用内下载服务，与 Seal 委托互不替代。',
        '未安装 Seal 时会提示并打开 Seal Releases。',
        'PiliPlus 自有状态面板：等待确认 → 进行中 → 完成 / 失败 / 取消（跳过「正在启动」闪屏）。',
        '可透传已登录账号 Cookie 给 Seal（任务级）；多账号可选并记住。',
        '可按空降助手已标记片段去除广告并合成成品，并展示逐段报告。',
        '设置项「委托 Seal 时自动开始下载」默认关闭，需 Seal 同步开启 Allow external auto-start。',
      ],
      tip: '路径：视频页三点菜单或播放页顶部「更多设置」→ 下载视频 / 下载并去除空降助手标记 / 下载音频。包名 com.chloemlla.seal。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.playlist_add_check_outlined,
      title: '播放列表导入与导出',
      subtitle: '可将收藏夹、稍后再看、追番和追剧整理为可迁移的播放列表。',
      bullets: [
        '支持 JSON 与 M3U8 导出，保留视频、合集和来源信息。',
        '导入前会校验版本、条目类型和必要字段，并展示预览。',
        '导入过程中逐条处理失效链接，单条失败不会阻断整个列表。',
      ],
      tip: '入口：播放列表页面的导入 / 导出操作。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.download_done_outlined,
      title: '批量下载与任务管理',
      subtitle: '下载任务支持集中查看、批量操作和更清晰的状态反馈。',
      bullets: [
        '支持批量开始、暂停、重试和删除任务。',
        '列表展示等待、进行中、完成、失败和取消状态。',
        '下载队列与播放器页面解耦，切换页面不会丢失任务进度。',
      ],
      tip: '入口：下载管理页面。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.bookmark_added_outlined,
      title: '视频书签与时间戳',
      subtitle: '在视频播放位置创建个人书签，之后可以快速回到关键片段。',
      bullets: [
        '书签保存视频、时间位置、标题和备注。',
        '支持从播放器菜单创建、编辑、删除和跳转书签。',
        '书签列表按视频聚合，适合整理课程、资料和长视频。',
      ],
      tip: '入口：播放页顶部「更多设置」→ 视频标记，或「我的 → 我的视频标记」。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.bar_chart_outlined,
      title: '观看统计',
      subtitle: '聚合观看时长、视频数量和活跃趋势，帮助了解自己的观看习惯。',
      bullets: [
        '按天、周和月查看观看时长及视频数量。',
        '统计来自本地观看记录，不上传视频标题或播放内容。',
        '异常或重复记录会在聚合阶段去重，减少数据抖动。',
      ],
      tip: '入口：设置或个人页面中的观看统计。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.notifications_active_outlined,
      title: '直播关键词提醒',
      subtitle: '关注的直播间出现指定关键词时，可通过系统通知提醒。',
      platformHint: 'Android / 移动端',
      bullets: [
        '支持配置关键词、关注范围和提醒开关。',
        '轮询使用节流与去重，避免同一场直播重复通知。',
        '通知点击后可直接进入对应直播间。',
      ],
      tip: '入口：直播提醒设置。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.picture_in_picture_alt_outlined,
      title: '持久化画中画',
      subtitle: '画中画播放状态跨页面导航保留，回到应用后可继续当前视频。',
      platformHint: 'Android',
      bullets: [
        '保存视频、分 P、播放位置、标题和封面等恢复信息。',
        '播放器关闭、播放完成或退出画中画后会清理过期状态。',
        '系统画中画控制与应用内播放状态保持同步。',
      ],
      tip: '开启路径：设置 → 播放设置 → 后台画中画。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.sync_alt_outlined,
      title: 'Synapse 设置与搜索记录同步',
      subtitle: '通过 Synapse-Client 授权后，将通用设置、播放设置和搜索历史在账号设备间同步。\n下载: https://github.com/Chloemlla/Synapse-Client/releases/latest',
      bullets: [
        '同步前明确区分本地设置、账号设置和敏感字段；WebDAV 密码、Cookie 与 Token 保留本地。',
        '网络失败时保留本地状态，下一次同步可继续处理。',
        '冲突时展示新增、修改、移除预览，可选择保留本地、使用远端或安全合并。',
      ],
      tip: '入口：设置 → 额外设置 → Synapse 云同步。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.qr_code_scanner_outlined,
      title: 'B 站网页二维码授权',
      subtitle: '可用本机已登录账号扫描 / 识别 B 站官方网页登录二维码，完成网页端授权。',
      platformHint: 'Android',
      bullets: [
        '支持相机扫码、相册识别与粘贴链接。',
        '解析后展示场景信息（环境、临时登录、短信验证等），失败可重试。',
        '授权请求会附着账号 Cookie，并与现有多账号体系打通。',
        'Android 扫码使用 CameraX + Google ML Kit；日志对敏感字段脱敏。',
      ],
      tip: '入口：登录 / Web QR 授权相关页面（扫描网页登录）。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.bug_report_outlined,
      title: '崩溃捕获、过滤与历史',
      subtitle: '跨 Flutter 与 Android 保留可复盘的故障，并过滤播放器噪声诊断。',
      platformHint: '全平台（native 桥 Android）',
      bullets: [
        '本地崩溃历史：列表、系统信息、堆栈、近期事件，可分享。',
        '启动时可提示上一会话的严重崩溃。',
        '过滤常见 media-kit / 网络诊断，避免误报淹没真实问题。',
        'Android 接入 lumen-crash 作为 native 捕获桥（安装失败不阻断冷启动）。',
      ],
      tip: '路径：设置相关崩溃 / 错误日志入口，或启动提示中的异常报告页。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.storage_outlined,
      title: 'Android MMKV 热存储',
      subtitle: '设置、缓存、观看进度等热数据在 Android 上走 MMKV，大箱支持懒加载与容量控制。',
      platformHint: 'Android',
      bullets: [
        '覆盖 userInfo、setting、localCache、观看进度、reply 等热路径。',
        '观看进度 / reply 等大箱懒加载，减轻冷启动解码压力。',
        '迁移与解码失败时避免用过期 Hive 快照覆盖新数据。',
        '设置导入、账号导入与 WebDAV 备份安全性同步增强。',
      ],
      tip: '对用户透明；升级后设置与进度应更快、更稳。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.shield_outlined,
      title: '密钥旁路与隐私保护',
      subtitle: '账号密钥与 WebDAV 密码迁出普通明文存储；复制 Cookie 需系统身份验证。',
      platformHint: '全平台（Cookie 验证 Android）',
      bullets: [
        'AccountSecretStore / SettingSecretStore：敏感字段独立加密旁路文件。',
        '设置导出 / 备份路径校验或排除敏感字段。',
        'Android「复制登录 Cookie」需通过锁屏 / PIN 验证。',
        '日志与崩溃上下文经 LogRedactor 脱敏。',
      ],
      tip: '路径：设置 → 隐私 → 复制登录 Cookie。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.play_circle_outline,
      title: '媒体导出、播放与系统控件',
      subtitle: '内置媒体导出、播放稳定性和系统媒体控件持续增强。',
      platformHint: '多平台 / Android',
      bullets: [
        '内置导出：视频 MP4 直链、音频 DASH 导出为 m4a（非 Android 菜单主路径仍可用）。',
        '播放器网络流错误分类与中断重试，减少无效异常。',
        '音频心跳 / seek / 切轨时重置时长，降低误报。',
        'Android NativeMediaService：MediaSession + 前台媒体通知，支持系统媒体控件。',
        '后台无画中画时原地关闭视频轨道、不重开播放器，快速前后台切换近零等待，音频不中断。',
      ],
      tip: '后台播放时留意系统通知栏媒体控件是否可用。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.content_paste_go_outlined,
      title: '剪贴板视频链接',
      subtitle: '识别剪贴板中的 B 站视频链接（含 b23 短链），可按需自动提示打开。',
      platformHint: '移动端',
      bullets: [
        '进入应用或回到前台时可检测剪贴板链接。',
        '设置项「自动打开剪贴板视频」默认关闭。',
        '搜索提交、活动页打开前会识别链接，避免重复弹窗。',
        '正在看视频时再次打开剪贴板链接会二次确认。',
      ],
      tip: '路径：设置 → 隐私 → 自动打开剪贴板视频。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.security_update_good_outlined,
      title: '首启权限、包名与更新源',
      subtitle: 'Android 首次启动会按系统版本引导权限；本分支包名与更新检查指向 Chloemlla 仓库。',
      platformHint: 'Android',
      bullets: [
        '首启权限：通知、相册/媒体、存储、系统亮度等（按 API 级别适配）。',
        '权限对话框等待 Navigator 就绪，避免无 context 崩溃。',
        '应用包名：com.chloemlla.piliplus。',
        '检查更新与源码地址：github.com/Chloemlla/PiliPlus。',
      ],
      tip: '稍后若弹出权限说明，可按需授权；拒绝不会强制退出。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.notification_important_outlined,
      title: '直播更新进度通知',
      subtitle: '后台播放直播且未开启画中画时，用系统前台服务展示可交互的进度通知。',
      platformHint: 'Android',
      bullets: [
        '退出应用且无 PiP 时，创建带进度条、标题与播放/暂停按钮的常驻通知。',
        'Android 16 上以 Live Update（promoted ongoing）样式呈现；OEM 缺接口时自动降级，避免崩溃。',
        '与媒体播放通知互补，覆盖直播后台场景。',
      ],
      tip: '后台直播时留意通知栏的进度通知。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.fact_check_outlined,
      title: '应用声明与法律信息',
      subtitle: '关于页新增「应用声明」，集中提供法律信息、开源许可声明与应用权限说明。',
      bullets: [
        '法律信息：用户协议、隐私政策、会员服务协议、个人信息收集清单等以内置网页查看。',
        '撤回同意与撤回隐私政策同意：查看当前授权状态并一键清除同意标记。',
        '开源许可声明并入应用声明；应用权限列出系统权限及用途。',
      ],
      tip: '路径：设置 → 关于 → 应用声明。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.rocket_launch_outlined,
      title: '准备就绪',
      subtitle: '以上是本分支相对上游的主要增量。进入应用后即可正常使用；完整说明见仓库 README。',
      bullets: [
        'Seal 下载、播放列表、批量下载、书签、统计、直播提醒、画中画和设置同步等详见上文各页。',
        '网页二维码授权、崩溃历史、MMKV、隐私保护和剪贴板能力也已纳入本分支。',
        '工程侧另有 Baseline Profile、CI 与测试加固，提升发布与冷启稳定性。',
        '可在「设置 → 关于 → 本分支改进说明」再次打开本引导。',
      ],
      tip: '点「开始使用」进入应用。',
    ),
  ];
}
