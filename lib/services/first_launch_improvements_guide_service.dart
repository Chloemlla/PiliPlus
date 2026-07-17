import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:pili_plus/pages/onboarding/improvements_guide_page.dart';
import 'package:pili_plus/services/android_first_launch_permission_service.dart';
import 'package:pili_plus/services/first_launch_migration.dart';
import 'package:pili_plus/services/startup_overlay_coordinator.dart';
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

  /// Show only when the first-launch flag is unset.
  static Future<void> maybeShow() async {
    if (_isRunning) {
      return;
    }
    _isRunning = true;
    try {
      await FirstLaunchMigration.ensureSeenFlagsForReturningUsers();
      await StartupOverlayCoordinator.waitUntilCrashIdle();

      if (hasSeen) {
        if (Platform.isAndroid) {
          await AndroidFirstLaunchPermissionService.requestMissingPermissions();
        }
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

      await StartupOverlayCoordinator.runWhenNavigatorReady(
        (navigator) async {
          await StartupOverlayCoordinator.waitUntilCrashIdle();
          if (hasSeen) {
            return;
          }

          await navigator.push<void>(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => const ImprovementsGuidePage(
                markSeenOnClose: true,
                onFinished: markSeen,
              ),
            ),
          );
          // Continue only after the guide route has been popped.
          if (!hasSeen) {
            await markSeen();
          }
        },
        debugLabel: 'improvements-guide',
      );

      if (Platform.isAndroid) {
        await AndroidFirstLaunchPermissionService.requestMissingPermissions();
      }
    } finally {
      _isRunning = false;
    }
  }

  /// Always open the guide (from About), without changing first-launch semantics
  /// unless [markAsSeen] is true.
  static Future<void> openManual({bool markAsSeen = false}) async {
    final navigator = await StartupOverlayCoordinator.waitForNavigator(
      debugLabel: 'improvements-guide-manual',
    );
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
}
