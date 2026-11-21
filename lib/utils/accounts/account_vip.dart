import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/storage_pref.dart';

/// VIP status derived from the cached user info.
///
/// Kept out of `Accounts` so `utils/accounts.dart` stays free of
/// `utils/storage_pref.dart`: storage initialization must not depend on
/// preferences (enforced by `tool/check_import_boundaries.py`).
abstract final class AccountVip {
  static bool get isMainVip => Pref.userInfoCache?.vipStatus == 1;

  static bool get isVideoVip =>
      Accounts.main == Accounts.video ? isMainVip : true;
}
