import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

/// One-shot migration so returning users are not treated as first installs
/// after onboarding flags are introduced.
abstract final class FirstLaunchMigration {
  static bool _done = false;

  static const _firstLaunchKeys = <String>{
    SettingBoxKey.firstLaunchOssNoticeSeen,
    SettingBoxKey.firstLaunchImprovementsGuideSeen,
    SettingBoxKey.androidFirstLaunchPermissionsRequested,
  };

  /// Written during anonymous cold start (e.g. buvid). Not upgrade evidence.
  static const _bootstrapLocalCacheKeys = <String>{
    LocalCacheKey.buvid,
    LocalCacheKey.timeStamp,
    LocalCacheKey.mixinKey,
  };

  /// Idempotent. Safe to call from multiple first-launch entrypoints.
  static Future<void> ensureSeenFlagsForReturningUsers() async {
    if (_done) {
      return;
    }
    _done = true;

    // Only upgrades / returning installs. Mid-chain first installs must continue.
    if (!_isReturningUser()) {
      return;
    }

    final writes = <Future<void>>[];
    if (!_boolFlag(SettingBoxKey.firstLaunchOssNoticeSeen)) {
      writes.add(
        GStorage.setting.put(SettingBoxKey.firstLaunchOssNoticeSeen, true),
      );
    }
    if (!_boolFlag(SettingBoxKey.firstLaunchImprovementsGuideSeen)) {
      writes.add(
        GStorage.setting.put(
          SettingBoxKey.firstLaunchImprovementsGuideSeen,
          true,
        ),
      );
    }
    if (!_boolFlag(SettingBoxKey.androidFirstLaunchPermissionsRequested)) {
      writes.add(
        GStorage.setting.put(
          SettingBoxKey.androidFirstLaunchPermissionsRequested,
          true,
        ),
      );
    }
    if (writes.isNotEmpty) {
      await Future.wait(writes);
    }
  }

  static bool _boolFlag(String key) {
    return GStorage.setting.get(key, defaultValue: false) == true;
  }

  /// Durable usage signals only. First-launch flags themselves are not evidence,
  /// otherwise a mid-chain first install would be silenced incorrectly.
  static bool _isReturningUser() {
    if (Accounts.main.isLogin) {
      return true;
    }
    try {
      if (Accounts.account.isNotEmpty) {
        return true;
      }
    } catch (_) {
      // Accounts box may be unavailable in rare early paths.
    }
    if (GStorage.userInfo.isNotEmpty) {
      return true;
    }
    if (GStorage.historyWord.isNotEmpty) {
      return true;
    }
    try {
      if (GStorage.watchProgress.isNotEmpty) {
        return true;
      }
    } catch (_) {
      // watchProgress is opened after critical prefs; ignore if still closed.
    }

    // localCache often only has cold-start buvid/wbi keys on a true first install.
    for (final key in GStorage.localCache.keys) {
      if (key is! String || _bootstrapLocalCacheKeys.contains(key)) {
        continue;
      }
      return true;
    }

    for (final key in GStorage.setting.keys) {
      if (key is String && !_firstLaunchKeys.contains(key)) {
        return true;
      }
    }
    return false;
  }
}
