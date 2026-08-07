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
      subtitle: '本构建新增应用声明与直播更新进度通知，恢复播放器「更多设置」的下载/书签/画质推荐/应用内小窗入口，并合并上游 PR #23 的文本省略与选择增强。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.fact_check_outlined,
      title: '新增「应用声明」入口',
      subtitle: '关于页新增应用声明，集中提供法律信息、开源许可声明与应用权限说明。',
      bullets: [
        '法律信息：用户协议、隐私政策、会员服务协议、个人信息收集清单，均在内置网页中查看。',
        '撤回同意与撤回隐私政策同意：可查看当前授权状态并一键撤回，撤回后相关同意标记被清除。',
        '开源许可声明：与原有开源声明与第三方鸣谢合并，入口统一收敛到应用声明。',
        '应用权限：列出应用声明使用的系统权限及用途说明。',
      ],
      tip: '入口：设置 → 关于 → 应用声明。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.notification_important_outlined,
      title: '直播更新进度通知',
      subtitle: '后台播放直播且未开启画中画时，通知栏显示可交互的进度通知（Android 16 起为 Live Update 样式）。',
      platformHint: 'Android',
      bullets: [
        '切到后台且无画中画时，创建带进度条、标题与播放/暂停按钮的常驻通知。',
        '部分厂商系统（如 vivo）缺少 promoted-ongoing 接口时自动降级，避免崩溃。',
        '回到前台或恢复画中画后通知自动收敛。',
      ],
      tip: '在直播播放页切到后台即可看到。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.format_line_spacing_outlined,
      title: '回复文本省略与选择增强',
      subtitle: '合并上游 PR #23，回复正文的换行省略、富文本选择与图片保存更准确。',
      bullets: [
        '长文本在换行处正确省略并显示省略号，不再截断半个字。',
        '「全文 / 收起」的文本选择在富文本场景正确生效。',
        '修复图片保存对省略计算的依赖与字段不一致。',
      ],
      tip: '在动态、评论等富文本场景体验文本展开与选择。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.menu_open_outlined,
      title: '恢复播放器「更多设置」入口',
      subtitle: '视频播放页顶部「更多设置」重新提供应用内小窗、下载视频、下载音频、去除空降助手标记、视频标记与画质推荐模式入口。',
      platformHint: 'Android（下载相关）',
      bullets: [
        '应用内小窗：播放中可转入悬浮小窗继续播放，点击「打开」回到原视频页；与系统画中画互补。',
        '下载视频 / 下载音频 / 下载并去除空降助手标记：Android 上优先委托 Seal（yt-dlp）处理队列与落盘。',
        '视频标记：可在播放位置新建标记，标记列表仍从「我的 → 我的视频标记」查看。',
        '画质推荐模式：与播放器「画质」菜单入口等价，此处更易直达。',
      ],
      tip: '路径：视频播放页顶部 → 更多设置。',
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
