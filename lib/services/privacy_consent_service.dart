import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

/// Tracks whether the user has acknowledged the privacy policy.
///
/// The flag is set when the privacy policy is opened from the legal info page
/// and cleared when the user withdraws consent. All reads/writes stay in this
/// service (never in page code) so new `lib/pages/*` files keep within the
/// check_import_boundaries.py raw-write baseline.
abstract final class PrivacyConsentService {
  static bool get hasAgreed {
    return GStorage.setting.get(
      SettingBoxKey.privacyPolicyAgreed,
      defaultValue: false,
    );
  }

  static Future<void> markAgreed() {
    return GStorage.setting.put(SettingBoxKey.privacyPolicyAgreed, true);
  }

  static Future<void> withdrawAgreed() {
    return GStorage.setting.delete(SettingBoxKey.privacyPolicyAgreed);
  }
}
