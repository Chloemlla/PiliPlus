import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:pili_plus/utils/clash_compat.dart';

/// Monitors connection failures when Clash VPN is supposed to be routing.
///
/// When consecutive connection errors exceed the threshold, the Clash VPN
/// is likely dead (process killed before the network-level watch detects it).
/// Triggers a fallback so the app switches back to the default network path
/// immediately instead of waiting for the partner status poll.
///
/// After a fallback, re-checks with exponential backoff (5s, 10s, 20s, 30s)
/// to detect when Clash comes back.
class ConnectionFailoverInterceptor extends Interceptor {
  /// Max consecutive failures before triggering a fallback.
  /// Lowered from 3 to 2 so a single brief burst of errors (e.g. both
  /// retries of one request fail) triggers faster.
  static const _maxFailures = 2;

  /// Time window within which failures must accumulate.
  static const _window = Duration(seconds: 15);

  /// Exponential backoff sequence for re-checks after a fallback.
  static const _recheckDelays = [5, 10, 20, 30];

  /// Grace period after startup: do not trigger fallback during this window.
  static const _gracePeriod = Duration(seconds: 8);

  final DateTime _startedAt = DateTime.now();

  int _failCount = 0;
  Timer? _windowTimer;
  bool _fallbackTriggered = false;
  int _recheckIndex = 0;
  Timer? _recheckTimer;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _reset();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isNetworkError(err) && ClashCompat.isClashVpnRouting) {
      _recordFailure();
    }
    handler.next(err);
  }

  bool _isNetworkError(DioException err) {
    if (err.response != null) return false;
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.unknown:
        return true;
      default:
        return false;
    }
  }

  void _recordFailure() {
    // Don't trigger during the startup grace period.
    if (DateTime.now().difference(_startedAt) < _gracePeriod) {
      _failCount = 0;
      return;
    }
    _failCount++;
    if (kDebugMode) {
      debugPrint(
        'ConnectionFailoverInterceptor: fail $_failCount/$_maxFailures',
      );
    }
    _windowTimer?.cancel();
    _windowTimer = Timer(_window, _reset);
    if (_failCount >= _maxFailures && !_fallbackTriggered) {
      _fallbackTriggered = true;
      _recheckIndex = 0;
      _triggerFallback();
    }
  }

  void _reset() {
    _failCount = 0;
    _windowTimer?.cancel();
    _windowTimer = null;
    if (_fallbackTriggered) {
      // A success after fallback means Clash might be back - clear the
      // forced fallback and let the next native event re-evaluate.
      _fallbackTriggered = false;
      _recheckTimer?.cancel();
      _recheckTimer = null;
      ClashCompat.clearFallback();
    }
  }

  void _triggerFallback() {
    if (kDebugMode) {
      debugPrint(
        'ConnectionFailoverInterceptor: '
        'Clash VPN routing appears dead — falling back to default network',
      );
    }
    ClashCompat.forceFallback();
    _scheduleRecheck();
  }

  /// Re-check with exponential backoff to detect when Clash comes back.
  void _scheduleRecheck() {
    _recheckTimer?.cancel();
    if (_recheckIndex >= _recheckDelays.length) return;
    final delay = _recheckDelays[_recheckIndex++];
    if (kDebugMode) {
      debugPrint(
        'ConnectionFailoverInterceptor: '
        're-check in ${delay}s (attempt $_recheckIndex/${_recheckDelays.length})',
      );
    }
    _recheckTimer = Timer(Duration(seconds: delay), () {
      if (!_fallbackTriggered) return;
      // Partner is back and reachable via ContentProvider — Clash is
      // actually running again. Clear the forced fallback so the
      // adapter pool re-evaluates on the next native status event.
      if (ClashCompat.clashVpnRunning && ClashCompat.partnerStatusAvailable) {
        if (kDebugMode) {
          debugPrint(
            'ConnectionFailoverInterceptor: '
            'Clash partner is back — clearing fallback',
          );
        }
        _fallbackTriggered = false;
        ClashCompat.clearFallback();
        return;
      }
      // Native side hasn't confirmed the death yet (partner watch may
      // not have caught up). Keep the fallback active.
      if (ClashCompat.clashVpnRunning) {
        _scheduleRecheck();
        return;
      }
      // Native side has caught up (partner watch detected the death).
      if (kDebugMode) {
        debugPrint(
          'ConnectionFailoverInterceptor: '
          'native confirmed Clash death — clearing fallback',
        );
      }
      _fallbackTriggered = false;
      ClashCompat.clearFallback();
    });
  }
}