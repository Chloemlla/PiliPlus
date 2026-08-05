import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Dart-side interface to [LiveUpdateService] (Android foreground service with
/// ProgressStyle notification promoted as a Live Update).
///
/// This notification is shown when the app is in the background and PiP is NOT
/// active, complementing the existing [NativeMediaNotificationService] (MediaStyle).
/// It displays a progress bar, video title, and play/pause toggle.
final liveUpdateService = _LiveUpdateService._();

class _LiveUpdateService {
  _LiveUpdateService._();

  static const MethodChannel _channel = MethodChannel('pili_plus/live_update');

  bool _initialized = false;
  bool _active = false;
  bool get isActive => _active;

  /// Callback invoked when the user taps play/pause on the Live Update notification.
  FutureOr<void> Function(String action, Map<String, dynamic> args)? onAction;

  bool get isAvailable => Platform.isAndroid;

  void ensureInitialized() {
    if (!isAvailable || _initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Start or update the Live Update notification with the current playback state.
  Future<void> start({
    required String title,
    String? artist,
    String? subText,
    String? artUri,
    required int max,
    required int progress,
    required bool playing,
    bool indeterminate = false,
  }) async {
    if (!isAvailable) return;
    ensureInitialized();
    _active = true;
    await _invoke('start', {
      'title': title,
      if (artist != null) 'artist': artist,
      if (subText != null) 'subText': subText,
      if (artUri != null) 'artUri': artUri,
      'max': max,
      'progress': progress,
      'playing': playing,
      'indeterminate': indeterminate,
    });
  }

  /// Update progress and playback state without restarting the service.
  Future<void> update({
    required int progress,
    int? max,
    bool? playing,
    String? subText,
  }) async {
    if (!isAvailable || !_active) return;
    await _invoke('update', {
      'progress': progress,
      if (max != null) 'max': max,
      if (playing != null) 'playing': playing,
      if (subText != null) 'subText': subText,
    });
  }

  /// Stop and dismiss the Live Update notification.
  Future<void> stop() async {
    if (!isAvailable || !_active) return;
    _active = false;
    await _invoke('stop');
  }

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
    final handler = onAction;
    if (handler != null) {
      await handler(action, args);
    }
  }
}