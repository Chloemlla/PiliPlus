import 'package:pili_plus/utils/setting_secret_store.dart';

/// Stores OAuth credentials in the encrypted setting sidecar.
///
/// The Bilibili cookie is deliberately not part of this store or its API.
abstract final class SynapseCredentialStore {
  static const accessTokenKey = 'accessToken';
  static const refreshTokenKey = 'refreshToken';

  static String? readAccessToken() =>
      SettingSecretStore.readSynapse(accessTokenKey);

  static void writeAccessToken(String token) {
    if (token.trim().isEmpty) {
      throw ArgumentError('A non-empty OAuth access token is required');
    }
    SettingSecretStore.writeSynapse(accessTokenKey, token.trim());
  }

  static String? readRefreshToken() =>
      SettingSecretStore.readSynapse(refreshTokenKey);

  static void writeRefreshToken(String token) {
    if (token.trim().isNotEmpty) {
      SettingSecretStore.writeSynapse(refreshTokenKey, token.trim());
    }
  }

  static void deleteRefreshToken() =>
      SettingSecretStore.deleteSynapse(refreshTokenKey);

  static void delete() {
    SettingSecretStore.deleteSynapse(accessTokenKey);
    SettingSecretStore.deleteSynapse(refreshTokenKey);
  }
}

