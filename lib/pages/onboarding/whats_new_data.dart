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
      subtitle: '本构建集中补齐播放辅助、个人数据、直播提醒、弹幕高亮和 Seal 下载管理。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.play_circle_outline,
      title: '播放更聪明，也更容易续看',
      subtitle: '清晰度建议、视频标记和画中画状态都接入了真实播放流程。',
      bullets: [
        '智能清晰度会结合可用档位、网络测速、连接类型与电量给出建议，并在播放器显示当前自动选择。',
        '播放时可保存带名称和备注的时间点；“我的视频标记”支持搜索、筛选、排序、导入导出和一键跳转。',
        'Android 与桌面端画中画会保存当前视频和位置；返回同一视频时恢复，退出、播完或过期后自动清理。',
      ],
      tip: '入口：播放器控制区；我的 → 我的视频标记。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.insights_outlined,
      title: '本地收藏与观看统计',
      subtitle: '显式收藏和真实观看时长均只保存在本机，并提供可控的查看与清理入口。',
      bullets: [
        '关闭“记录评论”后仍可收藏、查看、导入和导出；旧本地数据会无损迁移到独立收藏夹。',
        '导入按评论 ID 去重，坏条目会跳过并显示摘要；清空与取消收藏会立即刷新列表。',
        '观看统计按真实播放增量记录，暂停、缓冲、跳转和长时间无活动不会虚增时长。',
        '可查看周/月/全部趋势与常看 UP 主，导出 JSON/CSV、分享周报图片或确认后清空。',
      ],
      tip: '入口：我的 → 收藏的评论 / 我的观看统计。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.download_outlined,
      title: '播放列表备份与 Seal 下载管理',
      subtitle: '本地备份、跨设备转移和委托下载都拥有更完整的状态与恢复路径。',
      bullets: [
        '收藏夹、稍后再看、追番与追剧可导出 JSON/M3U8；JSON 导入会先预览、逐项校验并跳过重复 BVID。',
        '下载管理按 Seal 的真实任务拆分显示标题、格式、清晰度、进度和文件大小，支持单项或批量暂停、恢复、重试与删除。',
        '空降助手去广告仍由 PiliPlus 展示逐段报告；Seal 只有生成并验证连续成品后才会回报成功。',
      ],
      tip: '入口：我的 → 导入/导出播放列表；设置 → 其它设置 → 下载管理。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.notifications_active_outlined,
      title: '直播提醒与弹幕高亮',
      subtitle: '关注直播更及时，重点弹幕也能醒目但不破坏原有颜色。',
      bullets: [
        '直播规则按账号隔离，可从关注列表选择 UP 主或手动输入 UID，并匹配标题、分区或两者。',
        '应用在前台启动时立即检查、之后每 15 分钟轮询；同一 UP 主 4 小时内最多提醒一次，点击通知直达真实直播间。',
        '弹幕高亮支持普通文本、正则、优先级、快捷规则和 50 条上限；原本彩色的弹幕会保留填充色，仅增加规则色描边。',
      ],
      tip: '入口：设置 → 其它设置 → 直播提醒设置 / 弹幕高亮。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.shield_outlined,
      title: '存储、账号与界面可靠性',
      subtitle: '近期审计修复继续作为这些新功能的安全底座。',
      bullets: [
        '设置导入会先校验并在失败时完整回滚；MMKV 批量写入、账号别名合并和密钥文件替换均保留可恢复状态。',
        'WebDAV 备份替换不会在上传失败时破坏上一份有效备份，启动 Cookie 写入也会等待并给出可诊断错误。',
        '“重置所有数据”会同步清理评论收藏、视频标记、观看统计、直播规则和下载历史，避免功能独立存储被遗漏。',
      ],
      tip: '所有真实分析、测试与平台构建均以 GitHub Actions 结果为准。',
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
