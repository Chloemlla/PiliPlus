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
      subtitle: '本构建只列近期变化：修复主页返回与 Android 系统界面，完善评论收藏、界面交互、数据可靠性和 Seal 去广告成品。',
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
      title: '主页与 Android 系统界面',
      subtitle: '主页布局、系统栏与媒体通知会按当前窗口和播放状态正确同步。',
      platformHint: 'Android',
      bullets: [
        '从横屏、视频或沉浸式页面返回竖屏主页后，不再残留挤压正文的左侧空白栏。',
        '状态栏保持透明，图标明暗会随当前页面与主题重新更新。',
        '非直播内容在真实时长可用时，系统媒体通知可显示并拖动进度；直播或未知时长不会显示误导性 seek。',
        '窗口尺寸或方向变化时会重新判断导航布局，避免沿用旧页面状态。',
      ],
      tip: '宽屏横屏与手动启用的侧边栏仍保持原有布局；少数 OEM 隐藏进度条时仍可用快进/快退。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.bookmarks_outlined,
      title: '本地评论收藏与选区修复',
      subtitle: '主动收藏不再与“自动记录评论”混用，评论选区菜单也恢复了安全、准确的行为。',
      bullets: [
        '关闭“记录评论”后仍可收藏、查看、导入和导出；旧本地数据会无损迁移到独立收藏夹。',
        '导入按评论 ID 去重，坏条目会跳过并显示摘要；清空与取消收藏会立即刷新列表。',
        '“加入过滤”遇到空选区不再崩溃；Windows 右键仅在命中当前选区时保留选择。',
      ],
      tip: '入口：评论更多菜单 → 收藏评论；我的 → 收藏的评论。',
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
      icon: Icons.storage_outlined,
      title: '设置与账号数据更稳',
      subtitle: '高风险设置写入改走类型明确的存储接口，账号别名与后台写入失败也有统一处理。',
      bullets: [
        '窗口位置、音量与播放模式会在写入前校验，后台保存失败会进入可诊断的崩溃记录。',
        '导入或刷新账号时按 canonical key 合并别名，先安全写入再删除过期键。',
        'CI 恢复导入与页面裸存储写入边界检查，防止同类依赖环和静默写入回归。',
      ],
      tip: '这些调整不改变现有设置项位置和账号切换入口。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.content_cut_rounded,
      title: 'Seal 去广告输出连续成品',
      subtitle: '多个正片保留区间不再各自产生片段文件，而会经专用流程合并为一个可打开、分享的成品。',
      bullets: [
        '仍由 PiliPlus 读取空降助手标记、计算保留区间并展示逐段去除报告。',
        'Seal 区分普通多片段导出与去广告合并任务，不影响多 P、Cookie 和常规下载。',
        '若分段合并失败，会清理临时片段后下载完整源并应用同一组保留区间；再次失败只给出可重试错误，不把含广告原片当作成功。',
      ],
      tip: '路径：视频菜单 → 下载并去除空降助手标记；设置 → 其它设置。',
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
