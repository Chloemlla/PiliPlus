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
      subtitle: '本构建同步了上游 PiliPlus 在 2.1.2 之后的新提交：多处单选设置改为点按弹出菜单、新增「允许三方APP访问私有存储」，并修正了评论排序文案与若干细节问题。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.menu_open_outlined,
      title: '单选设置改为弹出菜单',
      subtitle: '原先需要打开对话框再选择的单选项，现在点一下就地弹出菜单，选完即生效。',
      bullets: [
        '外观风格：主题模式、导航栏样式、动态页UP主显示位置、动态/消息未读标记、顶底栏收起类型。',
        '播放设置：SuperChat 显示类型、底部进度条展示、循环播放方式。',
        '其它设置：评论展示、楼中楼评论展示、动态展示、番剧片头片尾跳过类型。',
        '「二级评论展示」更名为「楼中楼评论展示」，选项文案统一为更短的标签。',
      ],
      tip: '设置各分类页内，右侧带说明文字的条目即为弹出菜单项。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.folder_shared_outlined,
      title: '允许三方APP访问私有存储（Android）',
      subtitle: '新增开关，可让 MT 管理器等文件管理器通过系统文件框访问本应用私有目录。',
      bullets: [
        '路径：设置 → 其它设置 → 允许三方APP访问私有存储。',
        '默认关闭；开关会即时启用或停用对应的系统 DocumentsProvider 组件。',
        '本分支已把该组件的包名与授权标识改成本应用自身的 com.chloemlla.piliplus，不再沿用上游包名。',
      ],
      tip: '不需要时建议保持关闭，减少其他应用读取私有数据的入口。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.bug_report_outlined,
      title: '日志页与若干修复',
      subtitle: '同步上游的日志页改进和几个明确的问题修复。',
      bullets: [
        '日志页「相关信息」卡片新增复制按钮，可一次复制设备、应用与编译信息。',
        '本分支保留脱敏处理：复制出的内容仍会经过 LogRedactor。',
        '内置浏览器打开 http 链接时会自动改用 https。',
        '评论区投票卡片在切换内容后不再残留上一条的投票。',
        '修正 CDN 测速的速度累加错误，以及搜索相关接口的账号归类。',
        '桌面端弹出发布面板的动画时长略微缩短。',
      ],
      tip: '日志与异常报告入口在「设置 → 关于 → 日志」。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.build_circle_outlined,
      title: '构建脚本修复（不影响使用）',
      subtitle: 'Android 打包步骤此前会因为缓存中的 media_kit 依赖已带有 MD5 去除补丁而判定为「脏工作区」并中止。',
      bullets: [
        '现在该校验会忽略这个已知补丁文件，只对播放器隔离补丁保持严格校验。',
        '仅影响 CI 打包流程，应用行为没有变化。',
      ],
      tip: '若之前的构建产物缺失，重新触发一次构建即可。',
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
