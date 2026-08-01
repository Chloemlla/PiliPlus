import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pili_plus/services/account_service.dart';
import 'package:pili_plus/services/live_alert_service.dart';

/// Keeps live-alert polling foreground-only and refreshes it after account
/// changes so an in-flight request can never carry rules into another account.
class LiveAlertLifecycleObserver extends WidgetsBindingObserver {
  LiveAlertLifecycleObserver._();

  static final LiveAlertLifecycleObserver instance =
      LiveAlertLifecycleObserver._();

  StreamSubscription<bool>? _accountSubscription;
  bool _isInitialized = false;
  bool _isForeground = false;
  int _accountGeneration = 0;

  Future<void> init() async {
    if (_isInitialized) return;

    await LiveAlertService.instance.init();
    WidgetsBinding.instance.addObserver(this);
    if (Get.isRegistered<AccountService>()) {
      _accountSubscription = Get.find<AccountService>().isLogin.listen((_) {
        unawaited(_handleAccountChanged());
      });
    }
    _isInitialized = true;

    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    await LiveAlertService.instance.activateCurrentAccount();
    if (_isForeground) LiveAlertService.instance.startPolling();
  }

  Future<void> _handleAccountChanged() async {
    final generation = ++_accountGeneration;
    LiveAlertService.instance.stopPolling();
    try {
      await LiveAlertService.instance.activateCurrentAccount();
    } on Exception {
      return;
    }
    if (generation == _accountGeneration && _isForeground) {
      LiveAlertService.instance.startPolling();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      LiveAlertService.instance.startPolling();
    } else {
      LiveAlertService.instance.stopPolling();
    }
  }

  void dispose() {
    _isForeground = false;
    _accountGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    final accountSubscription = _accountSubscription;
    _accountSubscription = null;
    if (accountSubscription != null) unawaited(accountSubscription.cancel());
    LiveAlertService.instance.stopPolling();
    _isInitialized = false;
  }
}
