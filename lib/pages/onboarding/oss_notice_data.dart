import 'package:pili_plus/common/constants.dart';

final class OssCredit {
  const OssCredit({
    required this.name,
    required this.author,
    required this.description,
    required this.license,
    this.url,
  });

  final String name;
  final String author;
  final String description;
  final String license;
  final String? url;
}

/// First-launch open-source notice + curated third-party credits.
abstract final class OssNoticeData {
  static const projectName = Constants.appName;
  static const sourceUrl = Constants.sourceCodeUrl;
  static const projectLicense = 'GNU General Public License v3.0 (GPL-3.0)';
  static const projectLicenseUrl =
      '${Constants.sourceCodeUrl}/blob/main/LICENSE';

  static const freeNoticeTitle = '永久免费 · 谨防上当受骗';
  static const freeNoticeBody =
      '本项目为兴趣驱动的开源第三方客户端，永久免费。'
      '不会以“正版激活、会员代充、付费解锁、私下转账”等名义收费。'
      '请仅通过官方源码仓库与可信发行渠道获取；'
      '任何声称“收费版 / 内部版 / 破解授权”的都可能是骗局，请勿上当。';

  static const disclaimer =
      '所用接口均来自公开资料收集，仅供学习与测试。'
      '请在下载后 24 小时内删除；请支持正版，遵守当地法律法规。';

  /// Direct / critical third-party packages and upstream lineage.
  /// Not a complete transitive dependency dump.
  static const List<OssCredit> credits = [
    OssCredit(
      name: 'Flutter',
      author: 'Flutter authors / Google',
      description: '跨平台 UI 框架与引擎。',
      license: 'BSD-3-Clause',
      url: 'https://github.com/flutter/flutter',
    ),
    OssCredit(
      name: 'Dart',
      author: 'Dart authors / Google',
      description: '应用使用的编程语言与运行时。',
      license: 'BSD-3-Clause',
      url: 'https://github.com/dart-lang/sdk',
    ),
    OssCredit(
      name: 'pilipala',
      author: 'guozhigq',
      description: '早期开源 B 站第三方客户端，本项目谱系源头之一。',
      license: 'GPL-3.0',
      url: 'https://github.com/guozhigq/pilipala',
    ),
    OssCredit(
      name: 'PiliPalaX',
      author: 'orz12',
      description: '上游分支之一，提供大量功能演进基础。',
      license: 'GPL-3.0',
      url: 'https://github.com/orz12/PiliPalaX',
    ),
    OssCredit(
      name: 'PiliPlus (upstream)',
      author: 'bggRGjQaUbCoE',
      description: '本分支主要上游仓库，持续合入通用功能与修复。',
      license: 'GPL-3.0',
      url: 'https://github.com/bggRGjQaUbCoE/PiliPlus',
    ),
    OssCredit(
      name: 'bilibili-API-collect',
      author: 'SocialSisterYi 等贡献者',
      description: 'B 站公开接口文档汇总，接口实现参考来源。',
      license: 'CC-BY-NC-4.0 / 文档约定',
      url: 'https://github.com/SocialSisterYi/bilibili-API-collect',
    ),
    OssCredit(
      name: 'media_kit / media_kit_video',
      author: 'media-kit authors · fork: My-Responsitories',
      description: '跨平台视频/音频播放核心。',
      license: 'MIT',
      url: 'https://github.com/media-kit/media-kit',
    ),
    OssCredit(
      name: 'dio',
      author: 'cfug / FlutterChina',
      description: 'HTTP 网络请求客户端。',
      license: 'MIT',
      url: 'https://pub.dev/packages/dio',
    ),
    OssCredit(
      name: 'get (GetX)',
      author: 'Jonny Borges · fork: bggRGjQaUbCoE',
      description: '路由、状态与依赖注入。',
      license: 'MIT',
      url: 'https://pub.dev/packages/get',
    ),
    OssCredit(
      name: 'hive_ce',
      author: 'IO-Design-Team / Hive CE',
      description: '本地键值存储（非 Android 或回落路径）。',
      license: 'Apache-2.0',
      url: 'https://pub.dev/packages/hive_ce',
    ),
    OssCredit(
      name: 'MMKV',
      author: 'Tencent',
      description: 'Android 热路径本地存储后端。',
      license: 'BSD-3-Clause',
      url: 'https://github.com/Tencent/MMKV',
    ),
    OssCredit(
      name: 'flutter_inappwebview',
      author: 'Lorenzo Pichilli · fork: bggRGjQaUbCoE',
      description: '内置浏览器 / WebView。',
      license: 'Apache-2.0',
      url: 'https://pub.dev/packages/flutter_inappwebview',
    ),
    OssCredit(
      name: 'canvas_danmaku',
      author: 'bggRGjQaUbCoE 等',
      description: '弹幕绘制与交互。',
      license: 'MIT / 仓库声明',
      url: 'https://github.com/bggRGjQaUbCoE/canvas_danmaku',
    ),
    OssCredit(
      name: 'audio_service',
      author: 'Ryan Heise · fork: bggRGjQaUbCoE',
      description: '后台音频与系统媒体控件桥接。',
      license: 'MIT',
      url: 'https://pub.dev/packages/audio_service',
    ),
    OssCredit(
      name: 'audio_session',
      author: 'Ryan Heise',
      description: '音频会话与中断处理。',
      license: 'MIT',
      url: 'https://pub.dev/packages/audio_session',
    ),
    OssCredit(
      name: 'catcher_2',
      author: 'Catcher 2 authors · fork: My-Responsitories',
      description: '异常捕获与报告处理。',
      license: 'Apache-2.0',
      url: 'https://pub.dev/packages/catcher_2',
    ),
    OssCredit(
      name: 'lumen-crash',
      author: 'Chloemlla / Project Lumen',
      description: 'Android native 崩溃捕获桥（Project Lumen / lumen-crash）。',
      license: '见 Project-Lumen 仓库声明',
      url: 'https://github.com/Chloemlla/Project-Lumen',
    ),
    OssCredit(
      name: 'protobuf',
      author: 'Google / Dart team',
      description: 'gRPC / protobuf 消息编解码。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/protobuf',
    ),
    OssCredit(
      name: 'cookie_jar',
      author: 'flutterchina',
      description: 'Cookie 持久化与管理。',
      license: 'MIT',
      url: 'https://pub.dev/packages/cookie_jar',
    ),
    OssCredit(
      name: 'cached_network_image_ce',
      author: 'Baseflow / CE fork: My-Responsitories',
      description: '网络图片缓存显示。',
      license: 'MIT',
      url: 'https://pub.dev/packages/cached_network_image',
    ),
    OssCredit(
      name: 'flutter_smart_dialog',
      author: 'fluttercandies · fork: bggRGjQaUbCoE',
      description: 'Toast / Loading / 自定义弹层。',
      license: 'MIT',
      url: 'https://pub.dev/packages/flutter_smart_dialog',
    ),
    OssCredit(
      name: 'dynamic_color',
      author: 'Material Foundation',
      description: 'Material You 动态取色。',
      license: 'Apache-2.0',
      url: 'https://pub.dev/packages/dynamic_color',
    ),
    OssCredit(
      name: 'unDraw',
      author: 'Katerina Limpitsouni',
      description:
          '空状态动态色插画灵感来源（主题 ColorScheme 填充的 undraw 风格矢量，本地 CustomPaint 实现，无 CDN 依赖）。',
      license: 'unDraw License（可免费用于开源/商业，需署名）',
      url: 'https://undraw.co/',
    ),
    OssCredit(
      name: 'flex_seed_scheme',
      author: 'Mike Rydstrom (rydmike)',
      description: '基于 seed 的配色方案生成。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/flex_seed_scheme',
    ),
    OssCredit(
      name: 'flutter_svg',
      author: 'DNField / Flutter Community',
      description: 'SVG 资源渲染。',
      license: 'MIT',
      url: 'https://pub.dev/packages/flutter_svg',
    ),
    OssCredit(
      name: 'font_awesome_flutter',
      author: 'Brian Egan 等 · fork: bggRGjQaUbCoE',
      description: 'Font Awesome 图标集。',
      license: 'MIT / SIL OFL（字体）',
      url: 'https://pub.dev/packages/font_awesome_flutter',
    ),
    OssCredit(
      name: 'material_design_icons_flutter',
      author: 'mdi authors · fork: bggRGjQaUbCoE',
      description: 'Material Design Icons。',
      license: 'Apache-2.0 / SIL OFL（字体）',
      url: 'https://pub.dev/packages/material_design_icons_flutter',
    ),
    OssCredit(
      name: 'permission_handler',
      author: 'Baseflow',
      description: '运行时权限请求。',
      license: 'MIT',
      url: 'https://pub.dev/packages/permission_handler',
    ),
    OssCredit(
      name: 'path_provider',
      author: 'Flutter team',
      description: '应用目录路径访问。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/path_provider',
    ),
    OssCredit(
      name: 'share_plus',
      author: 'Flutter Community',
      description: '系统分享。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/share_plus',
    ),
    OssCredit(
      name: 'url_launcher',
      author: 'Flutter team',
      description: '打开外链与系统浏览器。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/url_launcher',
    ),
    OssCredit(
      name: 'image_picker',
      author: 'Flutter team',
      description: '相册/相机选图。',
      license: 'Apache-2.0 / BSD-3-Clause',
      url: 'https://pub.dev/packages/image_picker',
    ),
    OssCredit(
      name: 'image_cropper',
      author: 'HungHD 等',
      description: '图片裁剪。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/image_cropper',
    ),
    OssCredit(
      name: 'file_picker',
      author: 'Miguel Ruivo · fork: bggRGjQaUbCoE',
      description: '系统文件选择。',
      license: 'MIT',
      url: 'https://pub.dev/packages/file_picker',
    ),
    OssCredit(
      name: 'saver_gallery',
      author: 'FlutterCandies / community',
      description: '保存图片/视频到系统相册。',
      license: 'Apache-2.0',
      url: 'https://pub.dev/packages/saver_gallery',
    ),
    OssCredit(
      name: 'pretty_qr_code',
      author: 'pretty_qr_code authors',
      description: '二维码绘制（登录等）。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/pretty_qr_code',
    ),
    OssCredit(
      name: 'fl_chart',
      author: 'Iman Khoshabi',
      description: '图表绘制（如弹幕统计等）。',
      license: 'MIT',
      url: 'https://pub.dev/packages/fl_chart',
    ),
    OssCredit(
      name: 'connectivity_plus',
      author: 'Flutter Community',
      description: '网络连通状态。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/connectivity_plus',
    ),
    OssCredit(
      name: 'device_info_plus',
      author: 'Flutter Community',
      description: '设备信息。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/device_info_plus',
    ),
    OssCredit(
      name: 'package_info_plus',
      author: 'Flutter Community',
      description: '应用版本信息。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/package_info_plus',
    ),
    OssCredit(
      name: 'battery_plus',
      author: 'Flutter Community',
      description: '电池状态。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/battery_plus',
    ),
    OssCredit(
      name: 'wakelock_plus',
      author: 'Flutter Community',
      description: '播放时保持屏幕常亮。',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/wakelock_plus',
    ),
    OssCredit(
      name: 'window_manager',
      author: 'LeanFlutter · fork: bggRGjQaUbCoE',
      description: '桌面窗口管理。',
      license: 'MIT',
      url: 'https://pub.dev/packages/window_manager',
    ),
    OssCredit(
      name: 'tray_manager',
      author: 'LeanFlutter',
      description: '桌面托盘。',
      license: 'MIT',
      url: 'https://pub.dev/packages/tray_manager',
    ),
    OssCredit(
      name: 'screen_retriever',
      author: 'LeanFlutter',
      description: '桌面显示器几何信息。',
      license: 'MIT',
      url: 'https://pub.dev/packages/screen_retriever',
    ),
    OssCredit(
      name: 'desktop_webview_window',
      author: 'MixinNetwork / Predidit fork',
      description: 'Linux 桌面 WebView 窗口。',
      license: 'Apache-2.0',
      url: 'https://github.com/Predidit/linux_webview_window',
    ),
    OssCredit(
      name: 'webdav_client',
      author: 'wgh136 等',
      description: 'WebDAV 备份/恢复客户端。',
      license: 'BSD-3-Clause / 仓库声明',
      url: 'https://github.com/wgh136/webdav_client',
    ),
    OssCredit(
      name: 'dlna_dart',
      author: 'dlna_dart authors',
      description: 'DLNA 投屏。',
      license: 'MIT / 仓库声明',
      url: 'https://pub.dev/packages/dlna_dart',
    ),
    OssCredit(
      name: 'encrypt / crypto / archive / uuid / path / intl / logger / html',
      author: '各包原作者 / Dart 社区',
      description: '加解密、压缩、路径、国际化、日志与 HTML 解析等基础库。',
      license: 'BSD-3-Clause / MIT 等（见各包）',
      url: 'https://pub.dev',
    ),
    OssCredit(
      name: 'HMS Scan Kit (scanplus)',
      author: 'Huawei',
      description: 'Android 网页二维码扫码（相机 RemoteView + 图库 decodeWithBitmap）。',
      license: '华为 Scan Kit 许可 / SDK 条款',
      url: 'https://developer.huawei.com/consumer/cn/doc/HMSCore-Guides/android-0000001051075346',
    ),
    OssCredit(
      name: 'Seal（联调下载器，可选）',
      author: 'JunkFood02 原作 · Chloemlla 分支',
      description: 'Android 菜单下载委托的外部 yt-dlp 前端；非内嵌依赖。',
      license: 'GPL-3.0',
      url: 'https://github.com/Chloemlla/Seal',
    ),
  ];
}
