import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/pages/onboarding/improvements_guide_page.dart';
import 'package:pili_plus/services/android_first_launch_permission_service.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

/// First-install fullscreen guide that explains Chloemlla/main branch deltas.
class FirstLaunchImprovementsGuideGate extends StatefulWidget {
  const FirstLaunchImprovementsGuideGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<FirstLaunchImprovementsGuideGate> createState() =>
      _FirstLaunchImprovementsGuideGateState();
}

class _FirstLaunchImprovementsGuideGateState
    extends State<FirstLaunchImprovementsGuideGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FirstLaunchImprovementsGuideService.maybeShow();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

abstract final class FirstLaunchImprovementsGuideService {
  static bool _isRunning = false;
  static bool _isRetryScheduled = false;

  static bool get hasSeen {
    return GStorage.setting.get(
      SettingBoxKey.firstLaunchImprovementsGuideSeen,
      defaultValue: false,
    );
  }

  static Future<void> markSeen() {
    return GStorage.setting.put(
      SettingBoxKey.firstLaunchImprovementsGuideSeen,
      true,
    );
  }

  static Future<void> _markSeenAndContinueStartup() async {
    await markSeen();
    if (Platform.isAndroid) {
      // Kick the permission flow after the guide is dismissed.
      await AndroidFirstLaunchPermissionService.requestMissingPermissions();
    }
  }

  /// Show only when the first-launch flag is unset.
  static Future<void> maybeShow() async {
    if (_isRunning || hasSeen) {
      return;
    }

    // Wait for the open-source notice to finish first.
    final ossSeen = GStorage.setting.get(
      SettingBoxKey.firstLaunchOssNoticeSeen,
      defaultValue: false,
    );
    if (ossSeen != true) {
      return;
    }

    final navigator = _currentNavigator();
    if (navigator == null) {
      _scheduleRetry();
      return;
    }

    _isRunning = true;
    try {
      await navigator.push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const ImprovementsGuidePage(
            markSeenOnClose: true,
            onFinished: _markSeenAndContinueStartup,
          ),
        ),
      );
      // If the route was dismissed without onFinished, still mark once shown.
      if (!hasSeen) {
        await _markSeenAndContinueStartup();
      }
    } finally {
      _isRunning = false;
    }
  }

  /// Always open the guide (from About), without changing first-launch semantics
  /// unless [markAsSeen] is true.
  static Future<void> openManual({bool markAsSeen = true}) async {
    final navigator = _currentNavigator();
    if (navigator == null) {
      return;
    }
    await navigator.push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ImprovementsGuidePage(
          markSeenOnClose: markAsSeen,
          onFinished: markAsSeen ? markSeen : null,
        ),
      ),
    );
  }

  static NavigatorState? _currentNavigator() {
    final navigator = Get.key.currentState;
    if (navigator == null || !navigator.mounted) {
      return null;
    }
    return navigator;
  }

  static void _scheduleRetry() {
    if (_isRetryScheduled) {
      return;
    }
    _isRetryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isRetryScheduled = false;
      maybeShow();
    });
  }
}
