import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pili_plus/services/live_alert_service.dart';

/// Observer that starts/stops live alert polling based on app lifecycle.
/// Polling is only active when the app is in the foreground.
class LiveAlertLifecycleObserver extends WidgetsBindingObserver {
  static final LiveAlertLifecycleObserver instance = LiveAlertLifecycleObserver._();

  LiveAlertLifecycleObserver._();

  bool _isInitialized = false;

  /// Initialize the lifecycle observer
  Future<void> init() async {
    if (_isInitialized) return;

    await LiveAlertService.instance.init();
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground - start polling
        LiveAlertService.instance.startPolling();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is in background - stop polling
        LiveAlertService.instance.stopPolling();
        break;
    }
  }

  /// Dispose the observer
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LiveAlertService.instance.stopPolling();
  }
}
