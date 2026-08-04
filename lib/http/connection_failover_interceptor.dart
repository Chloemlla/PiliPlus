import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:pili_plus/utils/clash_compat.dart';

/// Monitors connection failures when Clash VPN is supposed to be routing.
///
/// When consecutive connection errors exceed the threshold, the Clash VPN
/// is likely dead (process killed before the network-level watch detects it).
/// Triggers a fallback so the app switches back to the default network path
/// immediately instead of waiting for the 5-second partner status poll.
class ConnectionFailoverInterceptor extends Interceptor {
  static const _maxFailures = 3;
  static const _window = Duration(seconds: 30);

  int _failCount = 0;
  Timer? _windowTimer;
  bool _fallbackTriggered = false;

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
      _triggerFallback();
    }
  }

  void _reset() {
    _failCount = 0;
    _windowTimer?.cancel();
    _windowTimer = null;
  }

  void _triggerFallback() {
    if (kDebugMode) {
      debugPrint(
        'ConnectionFailoverInterceptor: '
        'Clash VPN routing appears dead — falling back to default network',
      );
    }
    // Force the Clash routing flag off so _createPool() skips the
    // skipManualProxy optimization and rebuilds the adapter pool.
    ClashCompat.forceFallback();
    // Schedule a re-check after the partner watch might have caught up.
    Timer(const Duration(seconds: 6), () {
      _fallbackTriggered = false;
      ClashCompat.clearFallback();
    });
  }
}