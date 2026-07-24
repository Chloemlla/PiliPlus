import 'package:flutter/material.dart';
import 'package:pili_plus/build_config.dart';
import 'package:pili_plus/pages/onboarding/improvements_guide_data.dart';
import 'package:pili_plus/utils/date_utils.dart';

/// User-facing explanation of intentional changes in the current build.
///
/// Contract: every user-facing commit must refresh [pages] in the same change
/// set. See docs/flutter-build-whats-new.md and Trellis
/// .trellis/spec/frontend/flutter-build-whats-new.md.
abstract final class WhatsNewData {
  static String get buildTimeLabel {
    if (BuildConfig.buildTime <= 0) {
      return 'N/A';
    }
    return DateFormatUtils.format(
      BuildConfig.buildTime,
      format: DateFormatUtils.longFormatDs,
    );
  }

  static String get commitLabel {
    final hash = BuildConfig.commitHash.trim();
    if (hash.isEmpty || hash == 'N/A') {
      return 'N/A';
    }
    if (hash.length <= 12) {
      return hash;
    }
    return hash.substring(0, 12);
  }

  static String get versionLabel {
    return '${BuildConfig.versionName}+${BuildConfig.versionCode}';
  }

  static List<ImprovementsGuidePageData> get pages => [
    ImprovementsGuidePageData(
      icon: Icons.new_releases_outlined,
      title: '本次构建更新说明',
      subtitle: '你第一次打开这个构建。设置搜索可一键定位到分区项并荧光闪烁，同时保留 Scan Kit / Clash / Seal 等能力。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.search,
      title: '设置搜索：一键定位',
      subtitle: '在设置搜索中点选结果，会跳转到对应分区页并滚动到该项。',
      bullets: [
        '目标设置项会荧光高亮闪烁一次，方便在长列表中辨认。',
        '定位后开关与点击项仍可正常操作。',
        '结果行展示所属分区，便于确认跳转目标。',
      ],
      tip: '路径：设置 → 搜索。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.qr_code_scanner_outlined,
      title: 'Android 扫码改用华为 Scan Kit',
      subtitle: '网页二维码授权的相机与相册识别改为 HMS Scan Kit，不依赖 Google ML Kit / GMS。',
      platformHint: 'Android',
      bullets: [
        '相机扫码使用 Scan Kit RemoteView；相册识别使用 decodeWithBitmap。',
        'Flutter 通道契约不变：scanCamera / scanImage，网页登录授权流程不变。',
        '无需 agconnect-services.json 即可走 Scan Kit 独立 SDK；依赖声明华为 Maven。',
      ],
      tip: '入口：登录 / Web QR 授权（扫描网页登录）。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.vpn_lock_outlined,
      title: 'Clash VPN 自动适配',
      subtitle: '同时安装 Clash Meta 并开启 VPN 时，PiliPlus 流量自动经 Clash 处理，无需手填代理。',
      bullets: [
        '默认开启；可在「设置 → 其它设置」关闭「Clash VPN 自动适配」。',
        'Clash 访问控制在仅代理名单模式下也会自动放行本应用。',
        'VPN 开/关时会刷新网络连接池，避免旧连接绕路。',
        '手动系统代理在 Clash VPN 活跃时自动忽略，防止双重代理。',
      ],
      tip: '仅 Android；需使用配套 ClashMetaForAndroid 构建以获得伙伴状态查询。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.content_cut_rounded,
      title: 'Seal 下载：Cookie 与空降助手去广告',
      subtitle: '委托 Seal 时可透传登录 Cookie，并按空降助手已标记片段合成无广告成品。',
      bullets: [
        '多账号可选下载鉴权账号，支持记住选择，无需在 Seal 再管 Cookie。',
        '「下载并去除空降助手标记」：读取空降助手片段，经 Seal 分段合成正片。',
        '完成后展示逐段去除报告（类型、时间范围、时长）；支持多 P 逐个处理。',
        '设置中可配置默认类别、最小时长、是否每次询问类别与 Cookie 透传。',
      ],
      tip: '路径：视频菜单 → 下载并去除空降助手标记；设置 → 其它设置。',
    ),


    const ImprovementsGuidePageData(
      icon: Icons.bug_report_outlined,
      title: '本构建保留与修复',
      subtitle: '合并上游时保留本分支已有能力，并收敛滚动与主题相关稳定性。',
      bullets: [
        '评论日期显示：继续保留主评完整时间、子评相对/短日期。',
        '滚动偏移补丁改为始终写入像素，边界判断使用 minScrollExtent。',
        '动态取色等内容展开状态与上游修复对齐。',
      ],
      tip: '若仍看到无日期，请确认已安装包含该修复的构建。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.rocket_launch_outlined,
      title: '可以继续使用了',
      subtitle: '以上是本构建值得知道的有意变更。之后同一 Commit / Build Time 不会再自动弹出。',
      bullets: [
        '可在「设置 → 关于 → 本次更新说明」再次打开。',
        '分支级长期能力仍见「本分支改进说明」。',
        '开源协议与第三方鸣谢见「开源声明与第三方鸣谢」。',
      ],
      tip: '点「知道了」进入应用。',
    ),
  ];
}