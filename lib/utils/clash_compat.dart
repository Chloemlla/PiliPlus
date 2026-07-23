import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';

/// Android ClashMeta VPN auto-adapt bridge.
abstract final class ClashCompat {
  static const MethodChannel _method = MethodChannel('pili_plus/clash_compat');
  static const EventChannel _events = EventChannel('pili_plus/clash_compat_events');

  static StreamSubscription<dynamic>? _sub;
  static bool clashInstalled = false;
  static bool vpnActive = false;
  static bool clashVpnRunning = false;
  static String? profileName;
  static String? clashPackage;

  /// True when VPN path should own traffic (skip manual HTTP proxy).
  static bool get isClashVpnRouting =>
      Platform.isAndroid && (clashVpnRunning || (clashInstalled && vpnActive));

  static final StreamController<void> _statusChanged =
      StreamController<void>.broadcast();

  static Stream<void> get onStatusChanged => _statusChanged.stream;

  static Future<void> ensureStarted() async {
    if (!Platform.isAndroid) return;
    await refresh();
    _sub ??= _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) {
        if (kDebugMode) debugPrint('ClashCompat event error: $e');
      },
    );
  }

  static Future<void> refresh() async {
    if (!Platform.isAndroid) return;
    try {
      final raw = await _method.invokeMethod<dynamic>('getStatus');
      if (raw is Map) {
        _applyMap(Map<Object?, Object?>.from(raw));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ClashCompat.refresh: $e');
    }
  }

  static void _onEvent(dynamic event) {
    if (event is Map) {
      _applyMap(Map<Object?, Object?>.from(event));
      if (!_statusChanged.isClosed) {
        _statusChanged.add(null);
      }
    }
  }

  static void _applyMap(Map<Object?, Object?> map) {
    clashInstalled = map['clashInstalled'] == true;
    vpnActive = map['vpnActive'] == true;
    clashVpnRunning = map['clashVpnRunning'] == true;
    profileName = map['profileName'] as String?;
    clashPackage = map['clashPackage'] as String?;
  }

  static String statusLabel({required bool autoAdaptEnabled}) {
    if (!Platform.isAndroid) return '仅 Android 支持';
    if (!autoAdaptEnabled) return '已关闭自动适配';
    if (!clashInstalled) return '未检测到 Clash Meta';
    if (clashVpnRunning || vpnActive) {
      final profile = profileName;
      if (profile != null && profile.isNotEmpty) {
        return 'VPN 已连接 · $profile';
      }
      return 'VPN 已连接 · 流量自动经 Clash';
    }
    return '已安装 Clash · 等待开启 VPN';
  }
}
