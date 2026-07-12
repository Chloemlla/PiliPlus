import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:pili_plus/http/constants.dart';
import 'package:pili_plus/pages/video/controller.dart';
import 'package:pili_plus/utils/page_utils.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// Delegates video/audio downloads to Seal via the L3 external download protocol.
///
/// The entire lifecycle is presented by a self-owned animated status panel
/// (launch → waiting → accepted → completed/failed/canceled), instead of bare
/// toasts.
abstract final class SealDownloadUtils {
  static const _channel = MethodChannel('pili_plus/seal_download');
  static const releasesUrl = 'https://github.com/Chloemlla/Seal/releases';
  static const _panelTag = 'seal_download_panel';

  static bool _listening = false;
  static final Set<String> _handledEvents = <String>{};
  static final Map<String, _SealSession> _sessions = <String, _SealSession>{};
  static String? _activeRequestId;

  static bool get isSupported => Platform.isAndroid;

  /// Wire MethodChannel callbacks as early as possible on Android.
  static void ensureListening() {
    if (!isSupported) return;
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler(_onMethodCall);
      if (kDebugMode) {
        debugPrint('SealDownloadUtils: listening for DOWNLOAD_STATUS');
      }
    }
    unawaited(
      _channel.invokeMethod<void>('readyForStatus').catchError((Object _) {}),
    );
  }

  static Future<void> downloadVideo(VideoDetailController ctr) {
    return _download(ctr, extractAudio: false);
  }

  static Future<void> downloadAudio(VideoDetailController ctr) {
    return _download(ctr, extractAudio: true);
  }

  static Future<void> _download(
    VideoDetailController ctr, {
    required bool extractAudio,
  }) async {
    ensureListening();
    final url = pageUrlOf(ctr);
    if (url == null || url.isEmpty) {
      await _showErrorPanel(
        title: '无法委托下载',
        message: '无法构造视频链接',
      );
      return;
    }

    final requestId =
        'piliplus-${extractAudio ? 'audio' : 'video'}-${DateTime.now().microsecondsSinceEpoch}';
    final title = _titleOf(ctr);
    final session = _SealSession(
      requestId: requestId,
      extractAudio: extractAudio,
      pageUrl: url,
      mediaTitle: title,
      autoStart: Pref.sealAutoStart,
    );
    _sessions[requestId] = session;
    _activeRequestId = requestId;
    session.phase.value = SealPanelPhase.launching;
    await _showOrUpdatePanel(session);

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'delegateDownload',
        <String, dynamic>{
          'url': url,
          'extractAudio': extractAudio,
          'autoStart': Pref.sealAutoStart,
          'openUi': true,
          'requestId': requestId,
        },
      );
      if (result == null) {
        _finishSession(
          session,
          SealPanelPhase.failed,
          message: '未收到 Seal 启动结果',
        );
        return;
      }
      final status = SealDownloadStatus.fromMap(result);
      if (status.status == 'launched') {
        session.phase.value = Pref.sealAutoStart
            ? SealPanelPhase.waitingAuto
            : SealPanelPhase.waitingUi;
        session.message.value = Pref.sealAutoStart
            ? '已委托 Seal，正在自动入队…'
            : '已打开 Seal，请在 Seal 中确认下载';
        await _showOrUpdatePanel(session);
      } else {
        await _applyStatusToSession(session, status);
      }
    } on PlatformException catch (error) {
      if (error.code == 'not_installed') {
        session.phase.value = SealPanelPhase.notInstalled;
        session.message.value = '请先安装 Seal 后再下载';
        await _showOrUpdatePanel(session);
        return;
      }
      _finishSession(
        session,
        SealPanelPhase.failed,
        message: error.message ?? '委托 Seal 失败',
      );
    } catch (error) {
      _finishSession(
        session,
        SealPanelPhase.failed,
        message: '委托 Seal 失败：$error',
      );
    }
  }

  static String? pageUrlOf(VideoDetailController ctr) {
    if (ctr.isFileSource) return null;
    final epId = ctr.epId;
    if (epId != null) {
      return '${HttpString.baseUrl}/bangumi/play/ep$epId';
    }
    final bvid = ctr.bvid;
    if (bvid.isEmpty) return null;
    return '${HttpString.baseUrl}/video/$bvid';
  }

  static String _titleOf(VideoDetailController ctr) {
    try {
      final args = Get.arguments;
      if (args is Map) {
        final t = args['title']?.toString().trim();
        if (t != null && t.isNotEmpty) return t;
        final fav = args['favTitle']?.toString().trim();
        if (fav != null && fav.isNotEmpty) return fav;
      }
    } catch (_) {}
    if (ctr.watchLaterTitle.trim().isNotEmpty) {
      return ctr.watchLaterTitle.trim();
    }
    return ctr.bvid;
  }


  static Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method != 'onDownloadStatus') return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final status = SealDownloadStatus.fromMap(args);
    await _handleStatusEvent(status);
    return null;
  }

  static Future<void> _handleStatusEvent(SealDownloadStatus status) async {
    final key = _eventKey(status);
    if (!_handledEvents.add(key)) return;
    if (_handledEvents.length > 120) {
      _handledEvents.remove(_handledEvents.first);
    }

    if (kDebugMode) {
      debugPrint(
        'SealDownload status=${status.status} '
        'code=${status.errorCode} '
        'task=${status.taskId} '
        'req=${status.callerRequestId} '
        'source=${status.source}',
      );
    }

    final session = _resolveSession(status);
    if (session != null) {
      // Keep active pointer so late events still map after 后台等待.
      _activeRequestId ??= session.requestId;
      await _applyStatusToSession(session, status);
      return;
    }

    // Orphan terminal event (e.g. after app restart): still show panel.
    if (status.isTerminal ||
        status.status == 'accepted' ||
        status.status == 'rejected') {
      final orphan = _SealSession(
        requestId:
            status.callerRequestId ??
            'orphan-${DateTime.now().microsecondsSinceEpoch}',
        extractAudio: status.isAudioHint,
        pageUrl: '',
        mediaTitle: status.displayName ?? 'Seal 下载',
        autoStart: false,
      );
      _sessions[orphan.requestId] = orphan;
      _activeRequestId = orphan.requestId;
      await _applyStatusToSession(orphan, status);
    }
  }

  static _SealSession? _resolveSession(SealDownloadStatus status) {
    final requestId = status.callerRequestId;
    if (requestId != null && _sessions.containsKey(requestId)) {
      return _sessions[requestId];
    }
    if (_activeRequestId != null && _sessions.containsKey(_activeRequestId)) {
      return _sessions[_activeRequestId!];
    }
    if (_sessions.length == 1) return _sessions.values.first;
    return null;
  }

    static Future<void> _applyStatusToSession(
    _SealSession session,
    SealDownloadStatus status,
  ) async {
    final current = session.phase.value;
    switch (status.status) {
      case 'accepted':
        // Never regress from a successful terminal phase.
        if (current == SealPanelPhase.completed) break;
        session.taskId = status.taskId ?? session.taskId;
        session.phase.value = SealPanelPhase.accepted;
        session.message.value = '已交给 Seal 下载，完成后将在此更新';
      case 'needs_ui':
        // Activity Result often arrives after the user already confirmed in Seal
        // (QuickDownloadActivity finishes later). Do not overwrite accepted/terminal.
        if (current == SealPanelPhase.accepted ||
            current.isTerminal ||
            current == SealPanelPhase.waitingAuto) {
          break;
        }
        session.phase.value = SealPanelPhase.waitingUi;
        session.message.value = '已打开 Seal，请确认下载配置';
      case 'rejected':
        if (current == SealPanelPhase.completed ||
            current == SealPanelPhase.accepted) {
          break;
        }
        _finishSession(
          session,
          SealPanelPhase.rejected,
          message: status.userFacingErrorMessage ?? 'Seal 拒绝了下载请求',
        );
      case 'completed':
        session.taskId = status.taskId ?? session.taskId;
        session.contentUri = status.contentUri ?? session.contentUri;
        session.displayName = status.displayName ?? session.displayName;
        session.mimeType = status.mimeType ?? session.mimeType;
        session.phase.value = SealPanelPhase.completed;
        session.message.value = (session.contentUri?.isNotEmpty == true)
            ? '下载完成，可打开或分享文件'
            : '下载完成（文件在 Seal 中查看）';
      case 'failed':
        if (current == SealPanelPhase.completed) break;
        _finishSession(
          session,
          SealPanelPhase.failed,
          message: status.userFacingErrorMessage ?? 'Seal 下载失败',
        );
      case 'canceled':
        // Empty-session cancel (UI closed without enqueue) must not clobber
        // a real accepted/completed task that already reported.
        if (current == SealPanelPhase.accepted ||
            current == SealPanelPhase.completed ||
            current == SealPanelPhase.failed) {
          break;
        }
        // If we already have a task id, prefer keeping in-progress over empty cancel.
        if (session.taskId != null &&
            session.taskId!.isNotEmpty &&
            (status.taskId == null || status.taskId!.isEmpty)) {
          break;
        }
        _finishSession(
          session,
          SealPanelPhase.canceled,
          message: '已取消 Seal 下载',
        );
      case 'launched':
        if (current == SealPanelPhase.accepted ||
            current.isTerminal ||
            current == SealPanelPhase.waitingUi ||
            current == SealPanelPhase.waitingAuto) {
          break;
        }
        session.phase.value = session.autoStart
            ? SealPanelPhase.waitingAuto
            : SealPanelPhase.waitingUi;
      default:
        if (status.status.isNotEmpty) {
          session.message.value = 'Seal 状态：${status.status}';
        }
    }
    await _showOrUpdatePanel(session);
  }


  static void _finishSession(
    _SealSession session,
    SealPanelPhase phase, {
    required String message,
  }) {
    session.phase.value = phase;
    session.message.value = message;
    unawaited(_showOrUpdatePanel(session));
  }

  static String _eventKey(SealDownloadStatus status) {
    final request = status.callerRequestId ?? '';
    final task = status.taskId ?? '';
    final uri = status.contentUri ?? '';
    final source = status.source ?? '';
    return '$request|$task|${status.status}|${status.errorCode ?? ''}|$uri|$source';
  }

  static Future<void> _showErrorPanel({
    required String title,
    required String message,
  }) async {
    final session = _SealSession(
      requestId: 'error-${DateTime.now().microsecondsSinceEpoch}',
      extractAudio: false,
      pageUrl: '',
      mediaTitle: title,
      autoStart: false,
    );
    session.phase.value = SealPanelPhase.failed;
    session.message.value = message;
    _sessions[session.requestId] = session;
    _activeRequestId = session.requestId;
    await _showOrUpdatePanel(session);
  }

  static Future<void> _showOrUpdatePanel(_SealSession session) async {
    final isOpen = SmartDialog.checkExist(tag: _panelTag);
    if (isOpen) {
      // ValueNotifiers drive the already-open panel.
      return;
    }
    await SmartDialog.show(
      tag: _panelTag,
      keepSingle: true,
      clickMaskDismiss: false,
      backType: SmartBackType.normal,
      animationType: SmartAnimationType.scale,
      animationTime: const Duration(milliseconds: 320),
      builder: (context) {
        return _SealStatusPanel(
          session: session,
          onClose: () => _closePanel(session),
          onInstall: () async {
            await PageUtils.launchURL(releasesUrl);
          },
          onOpen: () async {
            final uri = session.contentUri;
            if (uri == null || uri.isEmpty) return;
            await openContentUri(uri: uri, mimeType: session.mimeType);
          },
          onShare: () async {
            final uri = session.contentUri;
            if (uri == null || uri.isEmpty) return;
            await shareContentUri(
              uri: uri,
              mimeType: session.mimeType,
              displayName: session.displayName,
            );
          },
          onRetry: () async {
            await _closePanel(session);
            // Re-delegate with same mode; caller should re-tap menu if needed.
          },
        );
      },
    );
  }

  static Future<void> _closePanel(_SealSession session) async {
    await SmartDialog.dismiss(tag: _panelTag);
    // Keep mapping for late accepted/completed after user taps 后台等待.
    _activeRequestId ??= session.requestId;
    // Only drop terminal sessions after the user dismisses the final UI.
    if (session.phase.value.isTerminal) {
      _sessions.remove(session.requestId);
      if (_activeRequestId == session.requestId) {
        _activeRequestId = null;
      }
    }
  }


  static Future<void> openContentUri({
    required String uri,
    String? mimeType,
  }) async {
    try {
      await _channel.invokeMethod<bool>('openContentUri', <String, dynamic>{
        'uri': uri,
        'mimeType': mimeType,
      });
    } on PlatformException catch (error) {
      SmartDialog.showToast(error.message ?? '无法打开文件');
    } catch (error) {
      SmartDialog.showToast('无法打开文件：$error');
    }
  }

  static Future<void> shareContentUri({
    required String uri,
    String? mimeType,
    String? displayName,
  }) async {
    try {
      await _channel.invokeMethod<bool>('shareContentUri', <String, dynamic>{
        'uri': uri,
        'mimeType': mimeType,
        'displayName': displayName,
      });
    } on PlatformException catch (error) {
      SmartDialog.showToast(error.message ?? '无法分享文件');
    } catch (error) {
      SmartDialog.showToast('无法分享文件：$error');
    }
  }
}

enum SealPanelPhase {
  launching,
  waitingUi,
  waitingAuto,
  accepted,
  completed,
  failed,
  rejected,
  canceled,
  notInstalled;

  bool get isBusy =>
      this == launching ||
      this == waitingUi ||
      this == waitingAuto ||
      this == accepted;

  bool get isTerminal =>
      this == completed ||
      this == failed ||
      this == rejected ||
      this == canceled ||
      this == notInstalled;

  bool get isSuccess => this == completed;

  bool get isError =>
      this == failed || this == rejected || this == notInstalled;
}

final class _SealSession {
  _SealSession({
    required this.requestId,
    required this.extractAudio,
    required this.pageUrl,
    required this.mediaTitle,
    required this.autoStart,
  });

  final String requestId;
  final bool extractAudio;
  final String pageUrl;
  final String mediaTitle;
  final bool autoStart;

  final ValueNotifier<SealPanelPhase> phase = ValueNotifier(
    SealPanelPhase.launching,
  );
  final ValueNotifier<String> message = ValueNotifier('正在连接 Seal…');

  String? taskId;
  String? contentUri;
  String? displayName;
  String? mimeType;

  String get kindLabel => extractAudio ? '音频' : '视频';
}

final class SealDownloadStatus {
  const SealDownloadStatus({
    required this.status,
    this.errorCode,
    this.errorMessage,
    this.taskId,
    this.callerRequestId,
    this.contentUri,
    this.displayName,
    this.mimeType,
    this.source,
  });

  factory SealDownloadStatus.fromMap(Map<dynamic, dynamic> map) {
    return SealDownloadStatus(
      status: map['status']?.toString() ?? '',
      errorCode: map['error_code']?.toString(),
      errorMessage: map['error_message']?.toString(),
      taskId: map['task_id']?.toString(),
      callerRequestId: map['caller_request_id']?.toString(),
      contentUri: map['content_uri']?.toString(),
      displayName: map['display_name']?.toString(),
      mimeType: map['mime_type']?.toString(),
      source: map['source']?.toString(),
    );
  }

  final String status;
  final String? errorCode;
  final String? errorMessage;
  final String? taskId;
  final String? callerRequestId;
  final String? contentUri;
  final String? displayName;
  final String? mimeType;
  final String? source;

  bool get isTerminal =>
      status == 'completed' || status == 'failed' || status == 'canceled';

  bool get isAudioHint {
    final mime = mimeType?.toLowerCase() ?? '';
    final name = displayName?.toLowerCase() ?? '';
    return mime.startsWith('audio/') ||
        name.endsWith('.m4a') ||
        name.endsWith('.mp3') ||
        name.endsWith('.opus') ||
        name.endsWith('.flac');
  }

  bool get isVideoHint {
    final mime = mimeType?.toLowerCase() ?? '';
    final name = displayName?.toLowerCase() ?? '';
    return mime.startsWith('video/') ||
        name.endsWith('.mp4') ||
        name.endsWith('.mkv') ||
        name.endsWith('.webm');
  }

  String? get userFacingErrorMessage {
    final message = errorMessage?.trim();
    if (message != null && message.isNotEmpty) return message;
    return switch (errorCode) {
      'disabled' => 'Seal 已关闭外部下载委托',
      'auto_start_denied' => 'Seal 未允许自动开始下载',
      'invalid_url' => '无效的下载链接',
      'unsupported_version' => 'Seal 协议版本不兼容',
      'caller_denied' => 'Seal 白名单拒绝了当前应用',
      'queue_rejected' => 'Seal 请求过于频繁，请稍后再试',
      'internal_error' => 'Seal 内部错误',
      'download_failed' => 'Seal 下载失败',
      'canceled' => '已取消 Seal 下载',
      _ => null,
    };
  }
}

class _SealStatusPanel extends StatefulWidget {
  const _SealStatusPanel({
    required this.session,
    required this.onClose,
    required this.onInstall,
    required this.onOpen,
    required this.onShare,
    required this.onRetry,
  });

  final _SealSession session;
  final FutureOr<void> Function() onClose;
  final FutureOr<void> Function() onInstall;
  final FutureOr<void> Function() onOpen;
  final FutureOr<void> Function() onShare;
  final FutureOr<void> Function() onRetry;

  @override
  State<_SealStatusPanel> createState() => _SealStatusPanelState();
}

class _SealStatusPanelState extends State<_SealStatusPanel>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  late final AnimationController _success = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  late final Animation<double> _scale = CurvedAnimation(
    parent: _enter,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0, 0.55, curve: Curves.easeOut),
  );

  SealPanelPhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    widget.session.phase.addListener(_onPhase);
    widget.session.message.addListener(_onMessage);
    _enter.forward();
    _onPhase();
  }

  @override
  void dispose() {
    widget.session.phase.removeListener(_onPhase);
    widget.session.message.removeListener(_onMessage);
    _enter.dispose();
    _pulse.dispose();
    _success.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onMessage() {
    if (mounted) setState(() {});
  }

  void _onPhase() {
    final phase = widget.session.phase.value;
    if (_lastPhase == phase) {
      if (mounted) setState(() {});
      return;
    }
    _lastPhase = phase;
    if (phase.isBusy) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
    if (phase.isSuccess) {
      _success
        ..reset()
        ..forward();
    }
    if (phase.isError || phase == SealPanelPhase.canceled) {
      _shake
        ..reset()
        ..forward();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = widget.session;
    final phase = session.phase.value;
    final hasUri = session.contentUri?.isNotEmpty == true;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = math.sin(t * math.pi * 6) * (1 - t) * 10;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.surfaceContainerHigh,
                        Color.alphaBlend(
                          cs.primary.withValues(alpha: 0.06),
                          cs.surfaceContainerHigh,
                        ),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.22),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHero(cs, phase),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: Text(
                            _headline(phase, session),
                            key: ValueKey('h-$phase'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          child: Text(
                            session.message.value,
                            key: ValueKey(session.message.value),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _metaChip(theme, cs, session),
                        if (phase == SealPanelPhase.completed &&
                            (session.displayName?.isNotEmpty == true ||
                                hasUri)) ...[
                          const SizedBox(height: 12),
                          Text(
                            session.displayName ?? '已完成文件',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _buildActions(theme, cs, phase, hasUri),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(ColorScheme cs, SealPanelPhase phase) {
    final icon = _iconFor(phase);
    final colors = _gradientFor(cs, phase);

    Widget core = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: 40, color: cs.onPrimary),
    );

    if (phase.isBusy) {
      core = AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final s = 0.94 + (_pulse.value * 0.08);
          final glow = 0.18 + (_pulse.value * 0.22);
          return Transform.scale(
            scale: s,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withValues(alpha: glow),
                    blurRadius: 24 + _pulse.value * 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: core,
      );
    }

    if (phase.isSuccess) {
      core = ScaleTransition(
        scale: CurvedAnimation(parent: _success, curve: Curves.elasticOut),
        child: core,
      );
    }

    return core;
  }

  Widget _metaChip(ThemeData theme, ColorScheme cs, _SealSession session) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            session.extractAudio
                ? Icons.music_note_rounded
                : Icons.movie_outlined,
            size: 16,
            color: cs.onPrimaryContainer,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              '${session.kindLabel} · ${session.mediaTitle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    ThemeData theme,
    ColorScheme cs,
    SealPanelPhase phase,
    bool hasUri,
  ) {
    if (phase == SealPanelPhase.notInstalled) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => widget.onInstall(),
              icon: const Icon(Icons.download_rounded),
              label: const Text('前往安装 Seal'),
            ),
          ),
          TextButton(onPressed: () => widget.onClose(), child: const Text('关闭')),
        ],
      );
    }

    if (phase == SealPanelPhase.completed) {
      return Column(
        children: [
          if (hasUri)
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => widget.onOpen(),
                    child: const Text('打开'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => widget.onShare(),
                    child: const Text('分享'),
                  ),
                ),
              ],
            )
          else
            Text(
              '可在 Seal 下载列表中查看文件',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          TextButton(onPressed: () => widget.onClose(), child: const Text('关闭')),
        ],
      );
    }

    if (phase.isBusy) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            phase == SealPanelPhase.waitingUi
                ? '确认后可返回本页，完成后将自动更新'
                : '请稍候，状态会自动刷新',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.outline,
            ),
          ),
          TextButton(
            onPressed: () => widget.onClose(),
            child: const Text('后台等待'),
          ),
        ],
      );
    }

    // failed / rejected / canceled
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () => widget.onClose(),
            child: const Text('知道了'),
          ),
        ),
      ],
    );
  }

  String _headline(SealPanelPhase phase, _SealSession session) {
    return switch (phase) {
      SealPanelPhase.launching => '正在启动 Seal',
      SealPanelPhase.waitingUi => '等待在 Seal 中确认',
      SealPanelPhase.waitingAuto => '正在自动入队',
      SealPanelPhase.accepted => 'Seal 下载进行中',
      SealPanelPhase.completed => 'Seal 下载完成',
      SealPanelPhase.failed => '下载失败',
      SealPanelPhase.rejected => '请求被拒绝',
      SealPanelPhase.canceled => '已取消下载',
      SealPanelPhase.notInstalled => '未安装 Seal',
    };
  }

  IconData _iconFor(SealPanelPhase phase) {
    return switch (phase) {
      SealPanelPhase.launching => Icons.rocket_launch_rounded,
      SealPanelPhase.waitingUi => Icons.touch_app_rounded,
      SealPanelPhase.waitingAuto => Icons.hourglass_top_rounded,
      SealPanelPhase.accepted => Icons.cloud_download_rounded,
      SealPanelPhase.completed => Icons.check_rounded,
      SealPanelPhase.failed => Icons.error_outline_rounded,
      SealPanelPhase.rejected => Icons.block_rounded,
      SealPanelPhase.canceled => Icons.cancel_outlined,
      SealPanelPhase.notInstalled => Icons.install_mobile_rounded,
    };
  }

  List<Color> _gradientFor(ColorScheme cs, SealPanelPhase phase) {
    if (phase.isSuccess) {
      return [cs.primary, cs.tertiary];
    }
    if (phase.isError) {
      return [cs.error, cs.errorContainer];
    }
    if (phase == SealPanelPhase.canceled) {
      return [cs.outline, cs.secondary];
    }
    return [cs.primary, cs.secondary];
  }
}
