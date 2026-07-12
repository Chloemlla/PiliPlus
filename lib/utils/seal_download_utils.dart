import 'dart:async';
import 'dart:io' show Platform;

import 'package:pili_plus/http/constants.dart';
import 'package:pili_plus/pages/video/controller.dart';
import 'package:pili_plus/utils/page_utils.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// Delegates video/audio downloads to Seal via the L3 external download protocol.
abstract final class SealDownloadUtils {
  static const _channel = MethodChannel('pili_plus/seal_download');
  static const releasesUrl = 'https://github.com/Chloemlla/Seal/releases';
  static const _dialogTag = 'seal_download_complete';

  static bool _listening = false;
  static final Set<String> _handledEvents = <String>{};

  static bool get isSupported => Platform.isAndroid;

  static void ensureListening() {
    if (!isSupported || _listening) return;
    _listening = true;
    _channel.setMethodCallHandler(_onMethodCall);
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
      SmartDialog.showToast('无法构造视频链接');
      return;
    }

    final requestId =
        'piliplus-${extractAudio ? 'audio' : 'video'}-${DateTime.now().microsecondsSinceEpoch}';
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
      if (result == null) return;
      final status = SealDownloadStatus.fromMap(result);
      if (status.status == 'launched') {
        SmartDialog.showToast(
          Pref.sealAutoStart ? '正在委托 Seal 下载…' : '已打开 Seal，请确认下载',
        );
      }
    } on PlatformException catch (error) {
      if (error.code == 'not_installed') {
        await _promptInstallSeal();
        return;
      }
      SmartDialog.showToast(error.message ?? '委托 Seal 失败');
    } catch (error) {
      SmartDialog.showToast('委托 Seal 失败：$error');
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

  static Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method != 'onDownloadStatus') return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final status = SealDownloadStatus.fromMap(args);
    await _handleStatusEvent(status);
    return null;
  }

  static Future<void> _handleStatusEvent(SealDownloadStatus status) async {
    final key =
        '${status.callerRequestId ?? ''}|${status.taskId ?? ''}|${status.status}|${status.errorCode ?? ''}';
    if (!_handledEvents.add(key)) return;
    if (_handledEvents.length > 100) {
      _handledEvents.remove(_handledEvents.first);
    }

    switch (status.status) {
      case 'accepted':
        SmartDialog.showToast('已交给 Seal 下载');
      case 'needs_ui':
        // Launch toast already covers the open-UI path.
        break;
      case 'rejected':
        SmartDialog.showToast(
          status.userFacingErrorMessage ?? 'Seal 拒绝了下载请求',
        );
      case 'completed':
        await _showCompletedDialog(status);
      case 'failed':
        SmartDialog.showToast(
          status.userFacingErrorMessage ?? 'Seal 下载失败',
        );
      case 'canceled':
        SmartDialog.showToast('已取消 Seal 下载');
      default:
        if (kDebugMode) {
          debugPrint('seal status: ${status.status}');
        }
    }
  }

  static Future<void> _promptInstallSeal() async {
    SmartDialog.showToast('请先安装 Seal');
    await PageUtils.launchURL(releasesUrl);
  }

  static Future<void> _showCompletedDialog(SealDownloadStatus status) async {
    final hasUri = status.contentUri?.isNotEmpty == true;
    final fileName = (status.displayName?.isNotEmpty == true)
        ? status.displayName!
        : '下载完成';

    await SmartDialog.show(
      tag: _dialogTag,
      animationType: SmartAnimationType.scale,
      builder: (context) {
        final theme = Theme.of(context);
        return _SealSuccessCard(
          fileName: fileName,
          showActions: hasUri,
          onOpen: hasUri
              ? () async {
                  SmartDialog.dismiss(tag: _dialogTag);
                  await openContentUri(
                    uri: status.contentUri!,
                    mimeType: status.mimeType,
                  );
                }
              : null,
          onShare: hasUri
              ? () async {
                  SmartDialog.dismiss(tag: _dialogTag);
                  await shareContentUri(
                    uri: status.contentUri!,
                    mimeType: status.mimeType,
                    displayName: status.displayName,
                  );
                }
              : null,
          onClose: () => SmartDialog.dismiss(tag: _dialogTag),
          theme: theme,
        );
      },
    );
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

class _SealSuccessCard extends StatefulWidget {
  const _SealSuccessCard({
    required this.fileName,
    required this.showActions,
    required this.onOpen,
    required this.onShare,
    required this.onClose,
    required this.theme,
  });

  final String fileName;
  final bool showActions;
  final FutureOr<void> Function()? onOpen;
  final FutureOr<void> Function()? onShare;
  final VoidCallback onClose;
  final ThemeData theme;

  @override
  State<_SealSuccessCard> createState() => _SealSuccessCardState();
}

class _SealSuccessCardState extends State<_SealSuccessCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.theme.colorScheme;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.tertiary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 40,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Seal 下载完成',
                        style: widget.theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.fileName,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: widget.theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (widget.showActions)
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: widget.onOpen == null
                                    ? null
                                    : () => widget.onOpen!(),
                                child: const Text('打开'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: widget.onShare == null
                                    ? null
                                    : () => widget.onShare!(),
                                child: const Text('分享'),
                              ),
                            ),
                          ],
                        ),
                      TextButton(
                        onPressed: widget.onClose,
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
