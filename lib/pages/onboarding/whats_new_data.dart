import 'package:flutter/material.dart';
import 'package:pili_plus/build_config.dart';
import 'package:pili_plus/pages/onboarding/improvements_guide_data.dart';
import 'package:pili_plus/utils/date_utils.dart';

/// User-facing explanation of intentional changes in the current build.
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
      subtitle:
          '你第一次打开这个构建。下面说明本版本同步上游时保留的有意 UI 重构与功能增强，并附上构建标识便于核对。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.touch_app_outlined,
      title: '界面交互重构',
      subtitle: '上游 opt ui 用更轻的命中与滚动包装替换旧组件，评论区、动态作者区、多列表 FAB 行为更统一。',
      bullets: [
        'ExtraHitTestWidget 替换为 TranslucentRow，头像/昵称区域命中更稳定。',
        '评论与多个列表的 FAB 显隐抽到共用 fabAnimWrapper。',
        '动态详情等页面仍保留发布日期；仅评论区曾误删日期，本构建已修复。',
      ],
      tip: '这是体验重构，不是功能被砍掉。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.live_tv_outlined,
      title: '直播反馈',
      subtitle: '直播推荐卡片支持按官方反馈理由提交不喜欢/反馈，减少无效推荐。',
      platformHint: '直播推荐',
      bullets: [
        '卡片更多入口可打开反馈理由。',
        '提交成功后会有轻提示，失败可重试。',
      ],
    ),
    ImprovementsGuidePageData(
      icon: Icons.public_outlined,
      title: '应用内网页更稳',
      subtitle: 'in-app WebView 会拦截非 http(s) scheme，避免 ERR_UNKNOWN_URL_SCHEME 直接崩链路。',
      bullets: [
        '可识别的应用内路由仍优先交给 PiliScheme。',
        '外部链接会提示是否打开，而不是静默失败。',
      ],
      tip: '从动态 / 评论打开站外链接时体验更可预期。',
    ),
    ImprovementsGuidePageData(
      icon: Icons.play_circle_outline,
      title: '播放兜底增强',
      subtitle: '多段旧格式资源走 EDL 拼接播放；音视频源组装与指针滚动也有同步优化。',
      bullets: [
        'dash 缺失但存在多段 durl 时，用 edl:// 串联播放。',
        '播放器音频附件改用 EDL 新流，减少部分平台打开失败。',
        '指针滚动与 seek 初始化边界更清晰。',
      ],
    ),
    ImprovementsGuidePageData(
      icon: Icons.subtitles_outlined,
      title: '弹幕调节更细',
      subtitle: '弹幕透明度与字号滑条精度提升，方便微调观感。',
      bullets: [
        '透明度 divisions：10 → 100。',
        '字号 / 全屏字号 divisions：20 → 200。',
        'macOS 标题栏恢复不透明背景，避免首帧透明。',
      ],
    ),
    ImprovementsGuidePageData(
      icon: Icons.bug_report_outlined,
      title: '本构建修复补充',
      subtitle: '同步上游时有一处非有意回退，已在本分支单独修回。',
      bullets: [
        '评论日期显示：恢复主评完整时间、子评相对/短日期。',
        'IP 归属仅在有 location 时拼接，避免孤立的「 • 」。',
      ],
      tip: '若仍看到无日期，请确认已安装包含该修复的构建。',
    ),
    ImprovementsGuidePageData(
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