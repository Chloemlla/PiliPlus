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
      subtitle: '本构建合并了上游 PiliPlus 2.1.1，同时保留本分支的画质推荐、音频解码自恢复与倍速步进等能力。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.merge_outlined,
      title: '同步上游 2.1.1',
      subtitle: '合入上游 bggRGjQaUbCoE/PiliPlus 的 Release 2.1.1，包含其间的修复与细节调整。',
      bullets: [
        '桌面端托盘隐藏/显示改为先切换窗口透明度，规避 Windows 上隐藏后残留的问题。',
        '视频弹幕趋势请求补齐 aid 与浏览器 UA、Referer，接口更稳定。',
        '字幕加载失败时不再写入空结果，重进可重新拉取。',
      ],
      tip: '本分支特有能力（画质推荐、Seal 委托下载、Synapse 同步等）均未改动。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.speed_outlined,
      title: '播放器改动保留说明',
      subtitle: '上游与本分支在播放器上都有改动，本次合并按「保留本分支行为 + 吸收上游修正」处理。',
      bullets: [
        '保留：音频解码器出错时自动 seek 回当前位置恢复声音。',
        '保留：X / C 长按连续步进 0.1x 倍速。',
        '吸收：播放器错误上报附带播放列表上下文，便于定位问题。',
      ],
      tip: '如遇播放异常，可在「设置 → 关于 → 日志」查看上报内容。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.rocket_launch_outlined,
      title: '可以继续使用了',
      subtitle: '以上是本构建值得知道的有意变更。之后同一 Commit / Build Time 不会再自动弹出。',
      bullets: [
        '可在「设置 → 关于 → 本次更新说明」再次打开。',
        '分支级长期能力仍见「本分支改进说明」。',
        '开源协议与第三方鸣谢见「应用声明 → 开源许可声明」。',
      ],
      tip: '点「知道了」进入应用。',
    ),
  ];
}
