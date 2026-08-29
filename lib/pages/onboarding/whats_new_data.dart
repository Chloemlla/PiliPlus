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
      subtitle: '本构建同步了上游 PiliPlus 的举报流程改版：举报弹窗新增网页举报入口、补充说明按举报理由决定是否必填，并整理了私信举报与私有存储开关的实现。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.report_outlined,
      title: '举报弹窗改版',
      subtitle: '举报理由与补充说明的关系更贴近官方网页端，理由后带 * 的表示必须填写补充说明。',
      bullets: [
        '评论举报：选择任意理由都会出现补充说明输入框，「其他」与「虚假不实信息」必填，其余选填。',
        '弹幕举报：「其它」的理由编号改为官方的 11，直播弹幕举报不再要求填写补充说明。',
        '未选择需要补充说明的理由时，不会再残留上一次的校验错误提示。',
      ],
      tip: '入口不变：长按评论/弹幕或在对应菜单中选择「举报」。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.vpn_key_outlined,
      title: 'Clash 读不到状态时说清原因',
      subtitle: '设置页「Clash VPN 自动适配」不再只写一句读不到状态，而是给出这次缺的是什么、该在 Clash 里做什么。',
      bullets: [
        '按 Clash 回传的授权层级分四种情况：旧版没有伙伴接口、等待在 Clash 中确认配对、已被拒绝可撤销、证书未登记只开放基础状态。',
        '被拒绝时不再把一份全空的状态当成读到了，改回按「VPN 是否活跃」判断，不会误报 Clash 已停止。',
        '只开放基础状态时仍能正常跟随 Clash，只是读不到配置名与节点，文案会顺带说明怎么补。',
      ],
      tip: '入口：设置 → 其他设置 → Clash VPN 自动适配。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.open_in_browser_outlined,
      title: '网页举报入口',
      subtitle: '评论举报与用户举报弹窗右上角新增地球图标，可跳到 B 站官方网页举报页处理复杂情况。',
      bullets: [
        '评论举报会带上 oid / rpid 等定位参数，直接落到对应评论的举报页。',
        '用户举报会带上目标 uid，网页端主题跟随应用当前的深浅色。',
        '网页在应用内置浏览器打开，仍会沿用 http 自动升级 https 的处理。',
      ],
      tip: '若客户端举报接口返回异常，可改用网页举报作为兜底。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.cleaning_services_outlined,
      title: '内部整理（无界面变化）',
      subtitle: '同步上游对私有存储开关和私信举报代码的整理，行为与上一构建一致。',
      bullets: [
        '「允许三方APP访问私有存储」开关改为直接使用应用级 Context，不再依赖当前 Activity。',
        '本分支继续把该组件包名固定为 com.chloemlla.piliplus，不随上游示例包名变化。',
        '私信举报的两处入口合并为同一个方法，避免两边逻辑走偏。',
      ],
      tip: '开关位置不变：设置 → 其它设置 → 允许三方APP访问私有存储。',
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
