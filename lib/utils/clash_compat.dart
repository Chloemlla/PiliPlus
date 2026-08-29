import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';

/// CMFA 授予 PiliPlus 的 `partnerStatus` 读取层级，对应 provider 的 `accessTier` 字段。
///
/// [basic] 只带内核/隧道状态与自动适配开关——足够决定要不要绕过手动代理，但读不到配置名、
/// 节点、流量与运行错误。
enum ClashAccess { unavailable, denied, basic, full }

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
  static ClashAccess partnerAccess = ClashAccess.unavailable;
  static String? partnerDeniedReason;
  static bool partnerAppAutoAdapt = true;
  static bool processBound = false;
  static bool autoAdaptEnabled = true;
  static String? profileName;
  static String? clashPackage;
  static bool _fallbackForced = false;
  static int partnerApiVersion = 0;
  static String? clashMode;
  static String? selectedNode;
  static int upTotalBytes = 0;
  static int downTotalBytes = 0;
  static int vpnState = 0; // 0=disconnected, 1=connecting, 2=connected
  static int proxyDelayMs = 0;
  static int aliveProxies = 0;
  static int memoryUsageBytes = 0;
  static String? lastError;

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
    partnerAccess = _parseAccess(map['partnerAccess'] as String?);
    partnerDeniedReason = map['partnerDeniedReason'] as String?;
    partnerAppAutoAdapt = map['partnerAppAutoAdapt'] != false;
    processBound = map['processBound'] == true;
    if (map.containsKey('autoAdaptEnabled')) {
      autoAdaptEnabled = map['autoAdaptEnabled'] != false;
    }
    profileName = map['profileName'] as String?;
    clashPackage = map['clashPackage'] as String?;
    partnerApiVersion = (map['apiVersion'] as num?)?.toInt() ?? 0;
    clashMode = map['mode'] as String?;
    selectedNode = map['selectedNode'] as String?;
    upTotalBytes = (map['upTotal'] as num?)?.toInt() ?? 0;
    downTotalBytes = (map['downTotal'] as num?)?.toInt() ?? 0;
    vpnState = (map['vpnState'] as num?)?.toInt() ?? (clashVpnRunning ? 2 : 0);
    proxyDelayMs = (map['proxyDelay'] as num?)?.toInt() ?? 0;
    aliveProxies = (map['aliveProxies'] as num?)?.toInt() ?? 0;
    memoryUsageBytes = (map['memoryUsage'] as num?)?.toInt() ?? 0;
    lastError = map['lastError'] as String?;
  }

  static ClashAccess _parseAccess(String? wire) => switch (wire) {
    'denied' => ClashAccess.denied,
    'basic' => ClashAccess.basic,
    'full' => ClashAccess.full,
    _ => ClashAccess.unavailable,
  };

  /// 把 Clash 的机器可读 `deniedReason` 翻成用户能照着做的一句中文。
  ///
  /// 取值来自 CMFA 的 `PartnerAccessResolver`；未知取值原样带出，便于反馈时对照 logcat。
  static String describeDeniedReason(String? reason) => switch (reason) {
    'pending_user_approval' => '等待在 Clash 中确认配对：打开 Clash 主页或点击配对通知即可授权',
    'denied_by_user' => '已在 Clash 中拒绝授权，可在 Clash 主页「伙伴应用」里撤销',
    'signer_unverified' => 'Clash 未登记 PiliPlus 的签名证书，只开放基础状态；在「伙伴应用」里允许即可读取完整状态',
    'not_partner' => 'Clash 没把 PiliPlus 认成伙伴应用，请更新 Clash 到支持伙伴配对的版本',
    'no_signature' => 'Clash 读不到 PiliPlus 的签名信息，无法完成配对',
    null => 'Clash 未说明原因',
    _ => 'Clash 返回原因：$reason',
  };

  static String statusLabel({required bool autoAdaptEnabled}) {
    if (!Platform.isAndroid) return '仅 Android 支持';
    if (!autoAdaptEnabled) return '已关闭自动适配';
    if (!clashInstalled) return '未检测到 Clash Meta';
    if (partnerAccess == ClashAccess.denied) {
      return '读不到 Clash 状态 · ${describeDeniedReason(partnerDeniedReason)}';
    }
    // 基础层足够决定出口，但配置名/节点/流量都读不到，所以顺带说明缺什么、怎么补。
    final tierNote = partnerAccess == ClashAccess.basic
        ? ' · ${describeDeniedReason(partnerDeniedReason)}'
        : '';
    if (isClashVpnRouting) {
      final profile = profileName;
      final mode = clashMode;
      final node = selectedNode;
      final delay = proxyDelayMs > 0 ? ' · ${proxyDelayMs}ms' : '';
      final alive = aliveProxies > 0 ? ' · $aliveProxies 在线' : '';
      final bound = processBound ? ' · 进程已绑定' : '';
      final modeInfo = mode != null ? ' · $mode' : '';
      final nodeInfo = node != null && node.isNotEmpty ? ' · $node' : '';
      if (profile != null && profile.isNotEmpty) {
        return 'VPN 已连接 · $profile$modeInfo$nodeInfo$delay$alive$bound$tierNote';
      }
      return 'VPN 已连接 · 流量自动经 Clash$modeInfo$nodeInfo$delay$alive$bound$tierNote';
    }
    if (partnerStatusAvailable) {
      final error = lastError;
      if (error != null && error.isNotEmpty) {
        return 'Clash 已停止 · $error';
      }
      return 'Clash 已停止 · 等待重新开启$tierNote';
    }
    // 走到这里只剩 unavailable：Clash 装着但没回伙伴接口，路由退回「VPN 是否活跃」的启发式。
    return '已安装 Clash · 等待开启 VPN（该 Clash 版本没有伙伴状态接口，更新后可显示详情）';
  }
}
