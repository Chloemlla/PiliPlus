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
          '你第一次打开这个构建。本版本加入 Clash Meta VPN 自动适配，并保留上游文本/表情选择改进。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
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
      icon: Icons.content_copy_outlined,
      title: '文本选择更顺手',
      subtitle: '多段选中文本按换行拼接，复制阅读更清晰；双击/三击与跨平台选区表现更稳定。',
      bullets: [
        '选中后展示菜单前会统一收起工具栏并清理选区。',
        '评论「加入过滤」在选区为空时会安全跳过，避免崩溃。',
        '直播超聊选中文本可直接走「视频」「搜索」入口。',
      ],
    ),
    const ImprovementsGuidePageData(
      icon: Icons.emoji_emotions_outlined,
      title: '表情选择与还原',
      subtitle: '复制/回复流程对「表情与文本」处理更顺畅，表情占位会还原为原始文本。',
      bullets: [
        '动态、私信、评论等富文本表情改用 EmoteSpan 携带原文。',
        '编辑器表情插入使用统一占位符，序列化更一致。',
        '继续支持把选中内容加入评论过滤。',
      ],
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