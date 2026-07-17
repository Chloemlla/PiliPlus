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
        '设置项「委托 Seal 时自动开始下载」默认关闭，需 Seal 同步开启 Allow external auto-start。',
      ],
      tip: '路径：视频页三点菜单 → 下载视频 / 下载音频。包名 com.chloemlla.seal。',
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
        '扫码链路加固，降低 native 崩溃；日志对敏感字段脱敏。',
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
      subtitle: '内置媒体导出与播放稳定性增强，并补齐 Android 系统媒体通知。',
      platformHint: '多平台 / Android',
      bullets: [
        '内置导出：视频 MP4 直链、音频 DASH 导出为 m4a（非 Android 菜单主路径仍可用）。',
        '播放器网络流错误分类与中断重试，减少无效异常。',
        '音频心跳 / seek / 切轨时重置时长，降低误报。',
        'Android NativeMediaService：MediaSession + 前台媒体通知，支持系统媒体控件。',
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
      icon: Icons.rocket_launch_outlined,
      title: '准备就绪',
      subtitle: '以上是本分支相对上游的主要增量。进入应用后即可正常使用；完整说明见仓库 README。',
      bullets: [
        'Seal 下载、网页二维码授权、崩溃历史、MMKV、隐私保护等详见上文各页。',
        '工程侧另有 Baseline Profile、CI 与测试加固，提升发布与冷启稳定性。',
        '可在「设置 → 关于 → 本分支改进说明」再次打开本引导。',
      ],
      tip: '点「开始使用」进入应用。',
    ),
  ];
}
