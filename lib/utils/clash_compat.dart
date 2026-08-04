import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';

/// Android ClashMeta VPN full partner adapt bridge for PiliPlus.
///
/// Native side binds the process to the VPN Network while auto-adapt is on
/// and Clash is routing. Dart side skips stacking manual HTTP proxy and
/// rebuilds Dio pools when routing changes.
abstract final class ClashCompat {
  static const MethodChannel _method = MethodChannel('pili_plus/clash_compat');
  static const EventChannel _events = EventChannel('pili_plus/clash_compat_events');

  // ignore: cancel_subscriptions
  static StreamSubscription<dynamic>? _sub;
  static bool clashInstalled = false;
  static bool vpnActive = false;
  static bool clashVpnRunning = false;
  static bool partnerStatusAvailable = false;
  static bool partnerAppAutoAdapt = true;
  static bool processBound = false;
  static bool autoAdaptEnabled = true;
  static String? profileName;
  static String? clashPackage;
  static bool _fallbackForced = false;

  /// True when VPN path should own traffic (skip manual HTTP proxy).
  /// Prefer Clash StatusProvider truth when available so a non-Clash VPN is
  /// not treated as Clash routing. The native side handles the fallback
  /// heuristic and partner-process-death detection.
  static bool get isClashVpnRouting {
    if (!Platform.isAndroid) return false;
    if (_fallbackForced) return false;
    return clashVpnRunning;
  }

  /// Force the routing flag off when the HTTP layer detects repeated
  /// connection failures while Clash was supposed to be routing. This
  /// provides an immediate fallback without waiting for the native
  /// partner status poll (up to 5s).
  static void forceFallback() {
    _fallbackForced = true;
    if (!_statusChanged.isClosed) {
      _statusChanged.add(null);
    }
  }

  /// Clear the forced fallback so the next native status event can
  /// re-enable Clash routing when Clash comes back.
  static void clearFallback() {
    _fallbackForced = false;
    // Notify listeners so the adapter pool is re-evaluated. If Clash
    // came back during the fallback window, isClashVpnRouting now
    // returns the native clashVpnRunning value again.
    if (!_statusChanged.isClosed) {
      _statusChanged.add(null);
    }
  }

  static final StreamController<void> _statusChanged =
      StreamController<void>.broadcast();

  static Stream<void> get onStatusChanged => _statusChanged.stream;

  static Future<void> ensureStarted() async {
    if (!Platform.isAndroid) return;
    await refresh();
    if (_sub != null) return;
    _sub = _events.receiveBroadcastStream().listen(
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

  /// Push Dart-side auto-adapt preference to native so process binding follows.
  static Future<void> setAutoAdaptEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      final raw = await _method.invokeMethod<dynamic>(
        'setAutoAdaptEnabled',
        <String, dynamic>{'enabled': enabled},
      );
      if (raw is Map) {
        _applyMap(Map<Object?, Object?>.from(raw));
      } else {
        autoAdaptEnabled = enabled;
      }
      if (!_statusChanged.isClosed) {
        _statusChanged.add(null);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ClashCompat.setAutoAdaptEnabled: $e');
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
    partnerStatusAvailable = map['partnerStatusAvailable'] == true;
    partnerAppAutoAdapt = map['partnerAppAutoAdapt'] != false;
    processBound = map['processBound'] == true;
    if (map.containsKey('autoAdaptEnabled')) {
      autoAdaptEnabled = map['autoAdaptEnabled'] != false;
    }
    profileName = map['profileName'] as String?;
    clashPackage = map['clashPackage'] as String?;
  }

  static String statusLabel({required bool autoAdaptEnabled}) {
    if (!Platform.isAndroid) return '仅 Android 支持';
    if (!autoAdaptEnabled) return '已关闭自动适配';
    if (!clashInstalled) return '未检测到 Clash Meta';
    if (isClashVpnRouting) {
      final profile = profileName;
      final bound = processBound ? ' · 进程已绑定' : '';
      if (profile != null && profile.isNotEmpty) {
        return 'VPN 已连接 · $profile$bound';
      }
      return 'VPN 已连接 · 流量自动经 Clash$bound';
    }
    return '已安装 Clash · 等待开启 VPN';
  }
}
