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
      subtitle: '本构建同步了上游 PiliPlus 2.1.2，新增 App 字体设置、蜂窝网络解码偏好与二级评论排序，同时保留本分支的 WebDAV 事务备份、定时关闭倒计时等能力。',
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
      title: '同步上游 2.1.2',
      subtitle: '合入上游 bggRGjQaUbCoE/PiliPlus 在 2.1.1 之后的新功能与修复。',
      bullets: [
        '新增「App 字体设置」页：可选系统字体、调字重与字号，并带实时预览与一键重置。',
        '新增「蜂窝网络首选解码格式」，按当前网络类型自动应用对应偏好。',
        '新增二级评论独立排序设置（默认按时间）。',
        '退出登录支持多账号并发，失败账号会单独提示；macOS 可用 Command+R 刷新推荐。',
        '修复找不到默认页时可能产生无效首页索引的问题。',
      ],
      tip: '本分支特有能力（画质推荐、Seal 委托下载、Synapse 同步等）均未改动。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.cloud_upload_outlined,
      title: 'WebDAV 备份改动保留说明',
      subtitle: '上游重构了 WebDAV 连接缓存，本次合并按「吸收上游连接层 + 保留本分支事务写入」处理。',
      bullets: [
        '吸收：备份/恢复前根据当前设置快照重建客户端，避免用旧配置写入。',
        '保留：先写临时文件并校验内容，成功后才替换正式备份，失败自动回退。',
        '保留：旧备份会先复制为 .bak，恢复失败不会丢掉上一份配置。',
      ],
      tip: '在「设置 → WebDAV」里可手动触发备份与恢复。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.text_fields_outlined,
      title: '字体设置入口变更',
      subtitle: '原来的「字体大小」与「App 字体字重」两个入口已合并为一个字体设置页。',
      bullets: [
        '路径：设置 → 外观风格 → App 字体设置。',
        '字体列表读取系统字体（Android / Windows / Linux），部分字体可能无法应用。',
        '旧的字号与字重设置值仍然沿用，无需重新调整。',
      ],
      tip: '点「重置」可一次恢复默认字体、字重与字号。',
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
