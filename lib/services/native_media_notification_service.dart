import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

typedef NativeMediaActionHandler =
    FutureOr<void> Function(String action, Map<String, dynamic> args);

final nativeMediaNotificationService = NativeMediaNotificationService._();

class NativeMediaNotificationService {
  NativeMediaNotificationService._();

  static const MethodChannel _channel = MethodChannel(
    'pili_plus/native_media_notification',
  );

  bool _initialized = false;
  NativeMediaActionHandler? onAction;

  bool get isAvailable => Platform.isAndroid;

  void ensureInitialized() {
    if (!isAvailable || _initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> start(Map<String, Object?> state) => _invoke('start', state);

  Future<void> updateMetadata(Map<String, Object?> state) =>
      _invoke('updateMetadata', state);

  Future<void> updatePlayback(Map<String, Object?> state) =>
      _invoke('updatePlayback', state);

  Future<void> stop() => _invoke('stop');

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    if (!isAvailable) return;
    ensureInitialized();
    await _channel.invokeMethod<void>(method, arguments);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onAction') return;
    final payload = Map<String, dynamic>.from(call.arguments as Map);
    final action = payload['action'] as String?;
    if (action == null) return;
    final args = payload['args'] == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(payload['args'] as Map);
    await onAction?.call(action, args);
  }
}
