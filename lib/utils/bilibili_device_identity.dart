import 'package:pili_plus/utils/utils.dart';

/// Keeps the process-wide buvid available without importing storage or login layers.
abstract final class BilibiliDeviceIdentity {
  static String _buvid = Utils.generateRandomString(32);

  static String get buvid => _buvid;

  static set buvid(String value) {
    if (value.isNotEmpty) _buvid = value;
  }
}
