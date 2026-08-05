import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pili_plus/models/download/seal_download_status.dart';

typedef SealDownloadStatusListener =
    FutureOr<void> Function(
      SealDownloadStatus status,
    );

/// The sole Dart owner of the shared PiliPlus/Seal MethodChannel handler.
///
/// Feature consumers register typed listeners here instead of replacing each
/// other's [MethodChannel.setMethodCallHandler].
final class SealDownloadChannelDispatcher {
  SealDownloadChannelDispatcher._({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'pili_plus/seal_download';
  static final instance = SealDownloadChannelDispatcher._();

  final MethodChannel _channel;
  final Set<SealDownloadStatusListener> _listeners =
      <SealDownloadStatusListener>{};
  bool _installed = false;

  bool get isSupported => Platform.isAndroid;

  void addStatusListener(SealDownloadStatusListener listener) {
    _listeners.add(listener);
    ensureListening();
  }

  void removeStatusListener(SealDownloadStatusListener listener) {
    _listeners.remove(listener);
  }

  void ensureListening() {
    if (!isSupported) return;
    if (!_installed) {
      _installed = true;
      _channel.setMethodCallHandler(_onMethodCall);
    }
    unawaited(
      _channel.invokeMethod<void>('readyForStatus').catchError((Object error) {
        if (kDebugMode) {
          debugPrint('Seal status readiness failed: $error');
        }
      }),
    );
  }

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    ensureListening();
    return _channel.invokeMethod<T>(method, arguments);
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method != 'onDownloadStatus') return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final status = SealDownloadStatus.fromMap(args);
    final listeners = List<SealDownloadStatusListener>.of(_listeners);
    await Future.wait<void>([
      for (final listener in listeners)
        Future<void>.sync(() => listener(status)).catchError((Object error) {
          if (kDebugMode) {
            debugPrint('Seal status listener failed: $error');
          }
        }),
    ]);
    return null;
  }
}
