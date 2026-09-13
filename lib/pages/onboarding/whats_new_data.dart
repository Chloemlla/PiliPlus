import 'package:flutter/material.dart';
import 'package:pili_plus/build_config.dart';
import 'package:pili_plus/pages/onboarding/improvements_guide_data.dart';
import 'package:pili_plus/utils/date_utils.dart';

/// User-facing explanation of intentional changes in the current build.
///
/// Contract: every user-facing commit must refresh [pages] in the same change
/// set. See docs/flutter-build-whats-new.md.
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
      subtitle: '本构建合并了上游一批改动（与上一构建的差异共 134 个文件），并带来几处新能力：搜索「综合」页换用专门的综合接口，动态详情的赞与转发拆成两个标签，拖动进度条立即跟手，另有一批行为修复与内部整理。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '搜索「综合」页：结果按 B站活动、用户、番剧影视与视频分区展示。',
        '收藏夹：可切换页码顺序，复制或移动内容时保持原有顺序。',
        '修复：分享链接冲突（#2909）与空降助手「最短片段时长」不生效（#2892）。',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.search,
      title: '搜索「综合」页改版',
      subtitle: '「综合」搜索改用专门的综合接口，一页里依次给出 B站活动、用户、番剧影视与视频结果。',
      bullets: [
        'B站活动：活动与直播入口排在最前，封面在左、标题与说明在右，直播中的带「直播」标记；点一下进入活动页，长按（桌面右键）可保存封面。',
        '用户：显示头像、昵称、等级、粉丝数与视频数、认证说明与个性签名，点一下进入其个人空间；下方还有一排该用户的视频可直接点开。',
        '番剧影视：以横向滑动的卡片展示，结果多时可左右翻阅。',
        '视频结果：与「视频」搜索页共用同一套网格与卡片。',
      ],
      tip: '入口不变：搜索页顶部选择「综合」。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.emoji_emotions_outlined,
      title: '表情提示与预览',
      subtitle: '表情名称提示改由统一组件绘制，并新增「点击表情显示 Tooltip」开关，默认关闭。',
      bullets: [
        '新增设置：设置 → 其它设置 →「点击表情显示 Tooltip」，打开后点按表情即可弹出预览。',
        '统一组件：评论区、动态、私信、文章与直播表情的提示样式由同一个小部件绘制，不再各页面各写一套。',
        '默认关闭：保持上一构建的点按行为，需要预览时再打开。',
      ],
      tip: '入口：设置 → 其它设置 → 点击表情显示 Tooltip。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.bookmark_border,
      title: '收藏夹：页码顺序与保序复制',
      subtitle: '收藏夹详情页新增「页码顺序」切换；批量复制或移动内容时保持原有顺序，条目数量同步刷新。',
      bullets: [
        '页码顺序：收藏夹页右上角的「页码顺序」可选正序/倒序，收藏很多时能直接从最后一页开始翻。',
        '保序复制：复制或移动到其它收藏夹后，顺序与源收藏夹一致（相关 #2850）。',
        '数量同步：复制或移动结束后，收藏夹的条目数量立即更新。',
      ],
      tip: '入口：收藏夹详情页右上角的「页码顺序」按钮。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.play_circle_outline,
      title: '播放器：拖动进度立即跟手',
      subtitle: '拖动进度条时进度立刻更新，不必等松手；播放页控件间距与播放内核参数也跟随上游更新。',
      bullets: [
        '拖动进度：拖动进度条的过程中进度立即跟手，松手后再由播放器对齐到实际位置。',
        '控件间距：播放页与直播页顶部、底部按钮的上下间距改为固定值，不再随工具栏高度浮动。',
        '播放内核：mpv 播放参数与原生事件循环跟随上游更新（#2873）。',
      ],
      tip: '拖动逻辑在共用的播放器插件里，全屏播放同样生效。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.format_list_bulleted,
      title: '动态详情：赞与转发拆分',
      subtitle: '动态详情页原来的「赞与转发」合并列表拆成「转发」和「赞」两个标签；屏蔽片段的起止时间在手机上改为就地输入。',
      bullets: [
        '标签拆分：原来只有「评论」与「赞与转发」两个标签，现为「转发」「评论」「赞」三个，各自独立翻页；「赞」列表续页时会带上翻页位置，不再错位。',
        '转发列表：点转发者的昵称直接进入其个人空间，不再误开动态详情。',
        '屏蔽片段：手机上的开始/结束时间改为在面板内就地输入、回车确认；平板与桌面仍是弹窗，并补上「开始/结束」标题。',
      ],
      tip: '入口：动态详情页顶部标签栏；屏蔽片段在播放页顶部「提交片段」。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.cleaning_services_outlined,
      title: '修复与内部整理',
      subtitle: '本构建修复了两处行为问题，另有一处 Linux 桌面端修复；其余是与上游同步带来的内部整理。',
      bullets: [
        '修复分享链接冲突（#2909）：开启「设置 → 关于 → 打开受支持的链接」后，分享里的「其他 app 打开」会与之冲突，现改走 Android 原生方式打开。',
        '修复空降助手「最短片段时长」不生效（#2892）：设置的秒数此前未换算成毫秒，短于设定值的片段仍会被跳过；现按设置值生效。',
        '修复 Linux 单实例（#2884）：桌面端重复启动会激活已打开的窗口，不再开出第二个实例。',
        '同步上游：本构建与上一构建的差异共 134 个文件，主要是上游重构与依赖升级，界面基本无感知。',
        '已修回：动态详情的标签栏维持本分支原来的可滚动样式——上游新版标签栏依赖本分支 Flutter 没有的接口。',
      ],
      tip: '以上不影响日常使用。',
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
