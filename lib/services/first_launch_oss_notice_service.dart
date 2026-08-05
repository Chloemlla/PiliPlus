import 'package:flutter/material.dart';
import 'package:pili_plus/pages/onboarding/oss_notice_page.dart';
import 'package:pili_plus/services/first_launch_improvements_guide_service.dart';
import 'package:pili_plus/services/first_launch_migration.dart';
import 'package:pili_plus/services/startup_overlay_coordinator.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

/// First-install open-source notice (source URL, free notice, licenses).
class FirstLaunchOssNoticeGate extends StatefulWidget {
  const FirstLaunchOssNoticeGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<FirstLaunchOssNoticeGate> createState() =>
      _FirstLaunchOssNoticeGateState();
}

class _FirstLaunchOssNoticeGateState extends State<FirstLaunchOssNoticeGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FirstLaunchOssNoticeService.maybeShow();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

abstract final class FirstLaunchOssNoticeService {
  static bool _isRunning = false;

  static bool get hasSeen {
    return GStorage.setting.get(
      SettingBoxKey.firstLaunchOssNoticeSeen,
      defaultValue: false,
    );
  }

  static Future<void> markSeen() {
    return GStorage.setting.put(
      SettingBoxKey.firstLaunchOssNoticeSeen,
      true,
    );
  }

  static Future<void> maybeShow() async {
    if (_isRunning) {
      return;
    }
    _isRunning = true;
    try {
      await FirstLaunchMigration.ensureSeenFlagsForReturningUsers();
      await StartupOverlayCoordinator.waitUntilCrashIdle();

      if (hasSeen) {
        // Already acknowledged; still allow later first-launch steps.
        await FirstLaunchImprovementsGuideService.maybeShow();
        return;
      }

      await StartupOverlayCoordinator.runWhenNavigatorReady(
        (navigator) async {
          // Crash overlay may have started while waiting for navigator.
          await StartupOverlayCoordinator.waitUntilCrashIdle();
          if (hasSeen) {
            return;
          }

          await navigator.push<void>(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => const OssNoticePage(
                markSeenOnClose: true,
                onFinished: markSeen,
              ),
            ),
          );
          // Continue only after the notice route has been popped.
          if (!hasSeen) {
            await markSeen();
          }
        },
        debugLabel: 'oss-notice',
      );

      await FirstLaunchImprovementsGuideService.maybeShow();
    } finally {
      _isRunning = false;
    }
  }

  static Future<void> openManual({bool markAsSeen = false}) async {
    final navigator = await StartupOverlayCoordinator.waitForNavigator(
      debugLabel: 'oss-notice-manual',
    );
    if (navigator == null) {
      return;
    }
    await navigator.push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => OssNoticePage(
          markSeenOnClose: markAsSeen,
          onFinished: markAsSeen ? markSeen : null,
        ),
      ),
    );
  }
}
