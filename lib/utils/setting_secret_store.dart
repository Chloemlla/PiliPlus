import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as crypt;
import 'package:path/path.dart' as path;

abstract final class SettingSecretStore {
  static const String keyFileName = 'setting_secrets.key';
  static const String dataFileName = 'setting_secrets.json.enc';

  static final Map<String, String> _secrets = {};

  static File? _keyFile;
  static File? _dataFile;
  static crypt.Key? _key;

  static bool get isInitialized => _key != null;

  static void init(String directoryPath) {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _keyFile = File(path.join(dir.path, keyFileName));
    _dataFile = File(path.join(dir.path, dataFileName));
    _key = _readOrCreateKey();
    _load();
  }

  static String? read(String key) {
    if (!isInitialized) {
      return null;
    }
    return _secrets[key];
  }

  static void write(String key, String value) {
    _ensureInitialized();
    _secrets[key] = value;
    _save();
  }

  static void delete(String key) {
    _ensureInitialized();
    if (_secrets.remove(key) != null) {
      _save();
    }
  }

  static void clear() {
    _ensureInitialized();
    if (_secrets.isEmpty) {
      return;
    }
    _secrets.clear();
    _save();
  }

  static crypt.Key _readOrCreateKey() {
    final keyFile = _keyFile!;
    if (keyFile.existsSync()) {
      return crypt.Key.fromBase64(keyFile.readAsStringSync());
    }
    final key = crypt.Key.fromSecureRandom(32);
    keyFile.writeAsStringSync(key.base64, flush: true);
    return key;
  }

  static void _load() {
    _secrets.clear();
    final dataFile = _dataFile!;
    if (!dataFile.existsSync()) {
      return;
    }
    try {
      final encryptedJson = jsonDecode(dataFile.readAsStringSync());
      if (encryptedJson is! Map) {
        throw const FormatException('Invalid setting secret file');
      }
      final payload = encryptedJson['payload'];
      final iv = encryptedJson['iv'];
      if (payload is! String || iv is! String) {
        throw const FormatException('Invalid setting secret payload');
      }
      final plainText =
          crypt.Encrypter(crypt.AES(_key!, mode: crypt.AESMode.gcm)).decrypt(
            crypt.Encrypted.fromBase64(payload),
            iv: crypt.IV.fromBase64(iv),
          );
      final decoded = jsonDecode(plainText);
      if (decoded is! Map) {
        throw const FormatException('Invalid setting secret map');
      }
      _secrets.addAll({
        for (final entry in decoded.entries)
          if (entry.value != null) entry.key.toString(): entry.value.toString(),
      });
    } catch (_) {
      final corruptPath =
          '${dataFile.path}.corrupt.${DateTime.now().millisecondsSinceEpoch}';
      dataFile.renameSync(corruptPath);
      _secrets.clear();
    }
  }

  static void _save() {
    final iv = crypt.IV.fromSecureRandom(16);
    final payload = crypt.Encrypter(
      crypt.AES(_key!, mode: crypt.AESMode.gcm),
    ).encrypt(jsonEncode(_secrets), iv: iv);
    _dataFile!.writeAsStringSync(
      jsonEncode({'version': 1, 'iv': iv.base64, 'payload': payload.base64}),
      flush: true,
    );
  }

  static void _ensureInitialized() {
    if (!isInitialized) {
      throw StateError('SettingSecretStore is not initialized');
    }
  }
}
