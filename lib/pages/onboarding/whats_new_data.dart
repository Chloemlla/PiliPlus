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
      subtitle: '本构建同步了上游 PiliPlus main 的最新修正，同时保留本分支的定时关闭倒计时、画质推荐与音频解码自恢复等能力。',
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
      title: '同步上游最新修正',
      subtitle: '合入上游 bggRGjQaUbCoE/PiliPlus main 在 2.1.1 之后的修复与细节调整。',
      bullets: [
        '自定义定时关闭改为小时 / 分钟滚轮选择器，确认后按分钟启动或更新定时。',
        '修正播放信息里 VideoTrack 的显示与复制内容（之前误用了音频轨道）。',
        '多分段视频拼接不再强制 no_clip，提升播放兼容性。',
        '为等级 / 播放图标与视频时间补齐 LTR 文本方向，改善无障碍朗读。',
      ],
      tip: '本分支特有能力（画质推荐、Seal 委托下载、Synapse 同步等）均未改动。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.timer_outlined,
      title: '定时关闭改动保留说明',
      subtitle: '上游重写了自定义定时面板，本次合并按「吸收上游选择器 + 保留本分支倒计时」处理。',
      bullets: [
        '吸收：小时/分钟滚轮选择器代替原来的时间输入弹窗。',
        '保留：定时关闭剩余时间倒计时与「当前播放结束后关闭」提示。',
        '保留：音频页与直播全屏控件上的剩余时间展示，到时暂停后自动清理定时器。',
      ],
      tip: '在播放器更多设置 → 定时关闭里可看到剩余时间。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.speed_outlined,
      title: '播放器改动保留说明',
      subtitle: '上游与本分支在播放器上都有改动，本次合并按「保留本分支行为 + 吸收上游修正」处理。',
      bullets: [
        '保留：音频解码器出错时自动 seek 回当前位置恢复声音。',
        '保留：X / C 长按连续步进 0.1x 倍速。',
        '保留：下拉刷新指示器的本分支 Stack 实现（上游的 RefreshLayout 空指示器修正已同步到布局层）。',
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
