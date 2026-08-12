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
      subtitle: '本构建将 Android 网页登录扫码从华为 Scan Kit 迁移到 CameraX + Google ML Kit，不再依赖华为扫描引擎。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.qr_code_scanner_outlined,
      title: '扫码改用 CameraX + Google ML Kit',
      subtitle: 'Android 网页登录扫码从华为 HMS Scan Kit 迁移到 CameraX 相机预览 + Google ML Kit 识别。',
      bullets: [
        '移除华为扫描引擎（scanplus / libscannative.so）依赖，相机扫码与相册识别统一走 Google ML Kit。',
        '扫码仅识别 QR 码格式以提升速度；手电筒开关与失败处理行为保持不变。',
      ],
      tip: '入口：登录 / Web QR 授权相关页面（扫描网页登录）。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.error_outline,
      title: 'Synapse 同步报错提示',
      subtitle: '同步、预览或绑定失败时，直接显示服务端返回的原因文案，不再展示底层的 "Bad state" 或 DioException 原始信息。',
      bullets: [
        '预览变更 / 保存并启用失败时，Toast 直接显示服务端提示（如「Bilibili 凭据不可用」）。',
        '网络或服务异常时给出可读的失败提示，并附 HTTP 状态码。',
      ],
      tip: '在「设置 → Synapse 同步」中触发一次失败即可看到。',
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
