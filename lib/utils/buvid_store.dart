import 'package:crypto/crypto.dart' show Digest;
import 'package:pili_plus/utils/bilibili_device_identity.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:pili_plus/utils/utils.dart';

/// Persisted process-wide buvid.
///
/// Kept outside `storage_pref.dart` so that `utils/accounts/` never depends on
/// preferences: storage initialization must stay free of `storage_pref.dart`
/// (enforced by `tool/check_import_boundaries.py`).
abstract final class BuvidStore {
  static String get buvid {
    final dynamic stored = GStorage.setting.get(SettingBoxKey.buvid);
    if (stored is String) return stored;

    final dynamic legacy = GStorage.localCache.get(SettingBoxKey.buvid);
    if (legacy is String) {
      GStorage.setting.put(SettingBoxKey.buvid, legacy);
      GStorage.localCache.delete(SettingBoxKey.buvid);
      BilibiliDeviceIdentity.buvid = legacy;
      return legacy;
    }
    return generate();
  }

  static String generate() {
    final md5Str = Digest(
      List.generate(16, (_) => Utils.random.nextInt(256)),
    ).toString().toUpperCase();
    final buvid = 'XY${md5Str[2]}${md5Str[12]}${md5Str[22]}$md5Str';
    GStorage.setting.put(SettingBoxKey.buvid, buvid);
    BilibiliDeviceIdentity.buvid = buvid;
    return buvid;
  }
}
