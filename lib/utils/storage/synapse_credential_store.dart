import 'package:pili_plus/utils/setting_secret_store.dart';

/// Stores only the Synapse JWT in the encrypted setting sidecar.
///
/// The Bilibili cookie is deliberately not part of this store or its API.
abstract final class SynapseCredentialStore {
  static String _key(int mid) => 'Synapse.jwt.$mid';

  static String? read(int mid) {
    if (mid <= 0) return null;
    return SettingSecretStore.read(_key(mid));
  }

  static void write(int mid, String jwt) {
    if (mid <= 0 || jwt.trim().isEmpty) {
      throw ArgumentError('A valid account and JWT are required');
    }
    SettingSecretStore.write(_key(mid), jwt.trim());
  }

  static void delete(int mid) {
    if (mid > 0) SettingSecretStore.delete(_key(mid));
  }
}

