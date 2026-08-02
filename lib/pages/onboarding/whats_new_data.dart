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
      subtitle: '本构建优化连续播放和后台播放，减少不必要的视频流量与加载。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.playlist_play_outlined,
      title: '连续播放更符合播放列表预期',
      subtitle: '顺序播放、列表循环和自动连播会自动略过未购买的充电专属视频。',
      bullets: [
        '已购买的充电内容仍会正常播放，不会被自动跳过。',
        '手动切换上一集或下一集时保留原有行为。',
        '当播放列表没有可继续播放的内容时，播放器会正常结束或进入相关视频。',
      ],
      tip: '充电专属标记来自播放列表和视频详情数据。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.headphones_outlined,
      title: '后台播放减少视频流量',
      subtitle: '没有进入画中画时，后台优先使用最高可用音频；返回应用后再恢复视频轨道。',
      bullets: [
        '画中画播放仍保留视频画面和原有控制方式。',
        '返回应用时恢复到后台前的播放位置和画质选择。',
        '直播、本地文件和桌面端播放不受这项切换影响。',
      ],
      tip: '后台播放开关关闭时仍按原设置暂停或恢复播放。',
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
