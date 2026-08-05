import 'dart:io';

import 'package:flutter/services.dart';

abstract final class NativeCrashBridge {
  static const _channel = MethodChannel('pili_plus/native_crash');

  static Future<List<Map<String, dynamic>>> getPendingReports() async {
    if (!Platform.isAndroid) return const [];
    final reports = await _channel.invokeListMethod<Object?>(
      'getPendingReports',
    );
    return [
      for (final report in reports ?? const [])
        if (report is Map)
          report.map((key, value) => MapEntry(key.toString(), value)),
    ];
  }

  static Future<void> acknowledgeReports(List<String> recordIds) async {
    if (!Platform.isAndroid || recordIds.isEmpty) return;
    await _channel.invokeMethod<void>('acknowledgeReports', {
      'recordIds': recordIds,
    });
  }

  static Future<Map<String, dynamic>?> getLumenPendingReport() async {
    if (!Platform.isAndroid) return null;
    final report = await _channel.invokeMethod<Object?>('getLumenPendingReport');
    if (report is! Map) return null;
    return report.map((key, value) => MapEntry(key.toString(), value));
  }

  static Future<void> clearLumenPendingReport() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('clearLumenPendingReport');
  }

  /// Wait briefly for Android exit-history staging to finish writing.
  static Future<bool> awaitExitHistoryReady({int timeoutMs = 2500}) async {
    if (!Platform.isAndroid) return true;
    try {
      final ready = await _channel.invokeMethod<bool>('awaitExitHistoryReady', {
        'timeoutMs': timeoutMs,
      });
      return ready ?? true;
    } catch (_) {
      // If the method is unavailable, continue import immediately.
      return true;
    }
  }

  /// Best-effort forward of Flutter breadcrumbs into lumen-crash native buffer.
  static Future<void> recordBreadcrumb(String event) async {
    if (!Platform.isAndroid) return;
    final value = event.trim();
    if (value.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('recordBreadcrumb', {'event': value});
    } catch (_) {
      // Native breadcrumb bridge must never break product flows.
    }
  }
}
