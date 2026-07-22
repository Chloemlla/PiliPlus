import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Serializes cold-start fullscreen overlays that share [Get.key] navigator.
///
/// Priority is enforced by callers: crash report > OSS notice > improvements
/// guide > build-scoped what's-new > Android first-launch permissions.
abstract final class StartupOverlayCoordinator {
  static const int maxNavigatorRetries = 30;

  static bool _crashActive = false;
  static Completer<void>? _crashIdle;

  static bool get isCrashActive => _crashActive;

  static void beginCrashOverlay() {
    if (_crashActive) {
      return;
    }
    _crashActive = true;
    _crashIdle = Completer<void>();
  }

  static void endCrashOverlay() {
    if (!_crashActive) {
      return;
    }
    _crashActive = false;
    final idle = _crashIdle;
    _crashIdle = null;
    if (idle != null && !idle.isCompleted) {
      idle.complete();
    }
  }

  /// Wait until any startup crash overlay is closed.
  static Future<void> waitUntilCrashIdle() {
    if (!_crashActive) {
      return Future<void>.value();
    }
    return (_crashIdle ??= Completer<void>()).future;
  }

  static NavigatorState? currentNavigator() {
    final navigator = Get.key.currentState;
    if (navigator == null || !navigator.mounted) {
      return null;
    }
    return navigator;
  }

  /// Resolve navigator with limited post-frame retries.
  static Future<NavigatorState?> waitForNavigator({
    int maxFrames = maxNavigatorRetries,
    String? debugLabel,
  }) async {
    final existing = currentNavigator();
    if (existing != null) {
      return existing;
    }

    for (var attempt = 0; attempt < maxFrames; attempt++) {
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      await completer.future;
      final navigator = currentNavigator();
      if (navigator != null) {
        return navigator;
      }
    }

    if (kDebugMode) {
      debugPrint(
        'StartupOverlayCoordinator: navigator unavailable'
        '${debugLabel == null ? '' : ' ($debugLabel)'}'
        ' after $maxFrames frames',
      );
    }
    return null;
  }

  /// Run [action] after a navigator is available, with bounded outer rounds.
  ///
  /// Each round uses [waitForNavigator]. Used by first-launch steps so a single
  /// late navigator readiness window does not permanently skip onboarding.
  static Future<void> runWhenNavigatorReady(
    Future<void> Function(NavigatorState navigator) action, {
    int rounds = 3,
    int maxFrames = maxNavigatorRetries,
    String? debugLabel,
  }) async {
    for (var round = 0; round < rounds; round++) {
      final navigator = await waitForNavigator(
        maxFrames: maxFrames,
        debugLabel: debugLabel == null ? null : '$debugLabel#$round',
      );
      if (navigator != null) {
        await action(navigator);
        return;
      }
    }
    if (kDebugMode) {
      debugPrint(
        'StartupOverlayCoordinator: giving up'
        '${debugLabel == null ? '' : ' ($debugLabel)'}'
        ' after $rounds navigator rounds',
      );
    }
  }
}
