import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/pages/onboarding/oss_notice_page.dart';
import 'package:pili_plus/services/first_launch_improvements_guide_service.dart';
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
  static bool _isRetryScheduled = false;

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

  static Future<void> _markSeenAndContinueStartup() async {
    await markSeen();
    // Next first-launch step: branch improvements guide (then permissions).
    await FirstLaunchImprovementsGuideService.maybeShow();
  }

  static Future<void> maybeShow() async {
    if (_isRunning || hasSeen) {
      // Already acknowledged; still allow later first-launch steps.
      if (hasSeen) {
        await FirstLaunchImprovementsGuideService.maybeShow();
      }
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
          builder: (_) => OssNoticePage(
            markSeenOnClose: true,
            onFinished: _markSeenAndContinueStartup,
          ),
        ),
      );
      if (!hasSeen) {
        await _markSeenAndContinueStartup();
      }
    } finally {
      _isRunning = false;
    }
  }

  static Future<void> openManual({bool markAsSeen = true}) async {
    final navigator = _currentNavigator();
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
