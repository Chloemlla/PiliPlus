import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:pili_plus/build_config.dart';
import 'package:pili_plus/pages/onboarding/improvements_guide_page.dart';
import 'package:pili_plus/pages/onboarding/whats_new_data.dart';
import 'package:pili_plus/services/android_first_launch_permission_service.dart';
import 'package:pili_plus/services/startup_overlay_coordinator.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

/// Immersive "what's new" guide for the first open of each new build.
///
/// Shown when [BuildConfig.commitHash] / [BuildConfig.buildTime] differs from
/// the last acknowledged pair stored in settings.
class WhatsNewGuideGate extends StatefulWidget {
  const WhatsNewGuideGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<WhatsNewGuideGate> createState() => _WhatsNewGuideGateState();
}

class _WhatsNewGuideGateState extends State<WhatsNewGuideGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WhatsNewGuideService.maybeShow();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

abstract final class WhatsNewGuideService {
  static bool _isRunning = false;

  static String get currentCommitHash => BuildConfig.commitHash.trim();

  static int get currentBuildTime => BuildConfig.buildTime;

  static String get acknowledgedCommitHash {
    return (GStorage.setting.get(SettingBoxKey.whatsNewAckCommitHash)
                as String?)
            ?.trim() ??
        '';
  }

  static int get acknowledgedBuildTime {
    final value = GStorage.setting.get(SettingBoxKey.whatsNewAckBuildTime);
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  /// True when this install already confirmed the current build identity.
  static bool get isCurrentBuildAcknowledged {
    final hash = currentCommitHash;
    if (hash.isEmpty || hash == 'N/A') {
      // Local/dev builds without injected hash: fall back to buildTime only.
      if (currentBuildTime <= 0) {
        return true;
      }
      return acknowledgedBuildTime == currentBuildTime;
    }
    return acknowledgedCommitHash == hash &&
        acknowledgedBuildTime == currentBuildTime;
  }

  static Future<void> markCurrentBuildAcknowledged() {
    return Future.wait([
      GStorage.setting.put(
        SettingBoxKey.whatsNewAckCommitHash,
        currentCommitHash,
      ),
      GStorage.setting.put(
        SettingBoxKey.whatsNewAckBuildTime,
        currentBuildTime,
      ),
    ]);
  }

  /// Auto-show after first-launch chain; skip if already acknowledged.
  static Future<void> maybeShow() async {
    if (_isRunning) {
      return;
    }
    _isRunning = true;
    try {
      await StartupOverlayCoordinator.waitUntilCrashIdle();

      // Wait for first-install onboarding to finish first.
      final ossSeen = GStorage.setting.get(
        SettingBoxKey.firstLaunchOssNoticeSeen,
        defaultValue: false,
      );
      final improvementsSeen = GStorage.setting.get(
        SettingBoxKey.firstLaunchImprovementsGuideSeen,
        defaultValue: false,
      );
      if (ossSeen != true || improvementsSeen != true) {
        return;
      }

      if (!isCurrentBuildAcknowledged) {
        await StartupOverlayCoordinator.runWhenNavigatorReady(
          (navigator) async {
            await StartupOverlayCoordinator.waitUntilCrashIdle();
            if (isCurrentBuildAcknowledged) {
              return;
            }

            await navigator.push<void>(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => ImprovementsGuidePage(
                  markSeenOnClose: true,
                  finishLabel: '知道了',
                  pages: WhatsNewData.pages,
                  onFinished: markCurrentBuildAcknowledged,
                ),
              ),
            );
            if (!isCurrentBuildAcknowledged) {
              await markCurrentBuildAcknowledged();
            }
          },
          debugLabel: 'whats-new-guide',
        );
      }

      // Keep the first-launch permission chain after onboarding / what's-new.
      if (Platform.isAndroid) {
        await AndroidFirstLaunchPermissionService.requestMissingPermissions();
      }
    } finally {
      _isRunning = false;
    }
  }

  /// Always open from About. When [markAsSeen] is true, write current build.
  static Future<void> openManual({bool markAsSeen = false}) async {
    final navigator = await StartupOverlayCoordinator.waitForNavigator(
      debugLabel: 'whats-new-guide-manual',
    );
    if (navigator == null) {
      return;
    }
    await navigator.push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ImprovementsGuidePage(
          markSeenOnClose: markAsSeen,
          finishLabel: '知道了',
          pages: WhatsNewData.pages,
          onFinished: markAsSeen ? markCurrentBuildAcknowledged : null,
        ),
      ),
    );
  }
}