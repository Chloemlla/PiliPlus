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
      subtitle:
          '本构建只列近期变化：同步上游界面优化，完善本地评论收藏，并修复返回主页后的布局与 Android 状态栏显示。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.brightness_6_outlined,
      title: '主页返回与 Android 状态栏',
      subtitle: '窗口、方向或主题变化后，主页布局与系统栏会按当前状态重新同步。',
      platformHint: 'Android',
      bullets: [
        '从横屏、视频或沉浸式页面返回竖屏主页后，不再残留挤压正文的左侧空白栏。',
        '状态栏保持透明，图标明暗会随当前页面与主题重新更新。',
        '窗口尺寸或方向变化时会重新判断导航布局，避免沿用旧页面状态。',
      ],
      tip: '宽屏横屏与手动启用的侧边栏仍保持原有布局。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.star_outline,
      title: '评论收藏与查看入口',
      subtitle: '评论更多菜单现在支持本地收藏，并可在我的页集中查看。',
      bullets: [
        '收藏数据仅保存在本机，不会调用 Bilibili 收藏夹接口。',
        '收藏列表保留表情、图片与来源跳转，支持取消收藏。',
        '支持导入、导出，并可在其它设置中控制本地评论记录。',
      ],
      tip: '打开评论更多菜单，选择「收藏评论」即可保存。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.dashboard_outlined,
      title: '上游界面与交互优化',
      subtitle: '主页、视频与内容卡片完成一轮布局和交互细节更新。',
      bullets: [
        '主页宽窄屏导航与视频页顶部区域统一布局，窗口切换更稳定。',
        '视频、直播、空间等卡片的圆角与加载骨架更加一致。',
        '动态投票状态更直观，长按文本时的选区绘制更精确。',
      ],
      tip: '这些变化来自近期上游同步，不再重复罗列更早的分支功能。',
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
