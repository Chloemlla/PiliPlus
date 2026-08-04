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
      subtitle: '本构建优化 Android 冷启动与后台播放，减少黑屏和无焦点窗口导致的 ANR。',
      bullets: [
        '版本：$versionLabel',
        'Build Time：$buildTimeLabel',
        'Commit Hash：$commitLabel',
        '与「本分支改进说明」不同：这里讲的是这次新构建相对上一构建的变化。',
      ],
      tip: '可左右滑动浏览；完成后同一构建不会再次自动弹出。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.speed_outlined,
      title: 'Android 冷启动更快',
      subtitle: '应用会先显示首帧，再恢复音频服务、账号会话和历史状态。',
      bullets: [
        '慢网络、慢设备和服务启动不会长时间阻塞首屏。',
        'Android 16 上启动或恢复窗口时减少无焦点窗口 ANR。',
        '会话恢复或历史同步失败时仍可进入应用并继续使用。',
        '首帧超时和主线程冻结会保留线程快照与无响应时长，便于定位问题。',
      ],
      tip: '后台初始化失败会记录为可处理错误，不影响首屏。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.headphones_outlined,
      title: '后台播放保持稳定',
      subtitle: 'Android 使用原生媒体服务承载通知和系统媒体控制，避免重复启动音频服务。',
      bullets: [
        '通知栏仍支持播放、暂停、快进、后退和切换播放项。',
        '画中画播放仍保留视频画面和原有控制方式。',
        '没有进入画中画时，切后台原地关闭视频轨道、返回时原地恢复，不重开播放器、音频不中断。',
        '3 秒内快速返回不做任何切换，频繁前后台切换近零等待。',
      ],
      tip: '后台播放开关关闭时仍按原设置暂停或恢复播放。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.cloud_sync_outlined,
      title: 'Synapse 授权改用客户端 handoff',
      subtitle: '云同步授权现在通过 Synapse-Client 的 PKCE 流程完成，PiliPlus 不再打开浏览器或接收 JWT 回调。',
      bullets: [
        '授权回调只接受 code、error 和 state，并校验一次性 state。',
        '访问令牌写入加密凭据；B 站 UID bind 和后续同步流程保持不变。',
        '客户端身份与设备标识会随授权和同步请求上报，设置中可查看设备追踪状态。',
        '失效授权不会在启动时生成错误报告；自动同步会暂停，重新授权后恢复。',
      ],
      tip: '入口：设置 → Synapse 云同步。',
    ),
    const ImprovementsGuidePageData(
      icon: Icons.sync_outlined,
      title: 'Synapse 设置全量同步与变更预览',
      subtitle: '通用设置、播放设置和搜索记录会按固定周期同步到远端，启动或冲突时可先查看变更再选择处理方式。',
      bullets: [
        '同步范围覆盖通用设置和独立的播放设置，不再遗漏倍速、长按倍速和视频适配等选项。',
        '搜索记录支持完整批量同步，定时任务每五分钟检查并合并远端变化。',
        '应用远端数据前会显示设置键的新增、修改、移除数量，以及搜索记录变更概览。',
        'WebDAV 密码、Cookie、Token、设备标识和 Synapse 连接状态仍保留在本地。',
      ],
      tip: '入口：设置 → Synapse 云同步；同步冲突时可选择保留本地、使用远端或安全合并。',
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
