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
      subtitle: '本构建集中修复 Android 播放器底栏、网络切换和退出播放时的稳定性问题。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.video_settings_outlined,
      title: '播放器控件已恢复',
      subtitle: '视频详情页和全屏播放恢复上游默认控件布局与交互。',
      bullets: [
        '播放、暂停、时间、画质、倍速和全屏等默认控件保持原有尺寸与顺序。',
        '底部控制栏不再额外添加分支专属的“更多”按钮，避免改变上游播放习惯。',
        '视频标记和画质推荐模式仍可从顶部“更多设置”访问，书签与推荐能力不会丢失。',
      ],
      tip: '手机竖屏、窄窗口和横屏全屏均使用统一的上游控件几何与渐变。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.health_and_safety_outlined,
      title: '播放与网络生命周期更稳定',
      subtitle: '针对三份 Android 崩溃报告分别修正请求、连接关闭和播放器释放路径。',
      bullets: [
        '账号 Cookie 与请求重试现在只会结束一次请求，避免启动阶段出现“handler 已调用”的异常。',
        '网络或 VPN 路由切换时会先启用新连接，再平滑释放旧连接，减少 HTTP/2 关闭竞态。',
        'Android 退出或切换播放器时不再由界面主线程同步等待媒体事件线程结束，降低无响应风险。',
        '系统媒体通知刷新会去除重复调度，减少播放结束附近不必要的主线程工作。',
      ],
      tip: '这些修复不会改变按钮功能、顺序、账号内容或网络设置。',
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
