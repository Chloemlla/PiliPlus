import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as crypt;
import 'package:path/path.dart' as path;

final class AccountSecret {
  const AccountSecret({
    required this.cookies,
    required this.accessKey,
    required this.refresh,
  });

  final Map<String, String> cookies;
  final String? accessKey;
  final String? refresh;

  Map<String, dynamic> toJson() => {
    'cookies': cookies,
    if (accessKey != null) 'accessKey': accessKey,
    if (refresh != null) 'refresh': refresh,
  };

  factory AccountSecret.fromJson(Object? json) {
    if (json is! Map) {
      return const AccountSecret(cookies: {}, accessKey: null, refresh: null);
    }
    final cookies = json['cookies'];
    return AccountSecret(
      cookies: cookies is Map
          ? {
              for (final entry in cookies.entries)
                if (entry.value != null)
                  entry.key.toString(): entry.value.toString(),
            }
          : {},
      accessKey: json['accessKey']?.toString(),
      refresh: json['refresh']?.toString(),
    );
  }
}

abstract final class AccountSecretStore {
  static const String keyFileName = 'account_secrets.key';
  static const String dataFileName = 'account_secrets.json.enc';

  static final Map<String, AccountSecret> _secrets = {};

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

  static AccountSecret? read(String key) {
    _ensureInitialized();
    return _secrets[key];
  }

  static void write(String key, AccountSecret secret) {
    _ensureInitialized();
    _secrets[key] = secret;
    _save();
  }

  static void delete(String key) {
    _ensureInitialized();
    if (_secrets.remove(key) != null) {
      _save();
    }
  }

  static void deleteAll(Iterable<dynamic> keys) {
    _ensureInitialized();
    var changed = false;
    for (final key in keys) {
      if (key is String && _secrets.remove(key) != null) {
        changed = true;
      }
    }
    if (changed) {
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
        throw const FormatException('Invalid account secret file');
      }
      final payload = encryptedJson['payload'];
      final iv = encryptedJson['iv'];
      if (payload is! String || iv is! String) {
        throw const FormatException('Invalid account secret payload');
      }
      final plainText =
          crypt.Encrypter(crypt.AES(_key!, mode: crypt.AESMode.gcm)).decrypt(
            crypt.Encrypted.fromBase64(payload),
            iv: crypt.IV.fromBase64(iv),
          );
      final decoded = jsonDecode(plainText);
      if (decoded is! Map) {
        throw const FormatException('Invalid account secret map');
      }
      _secrets.addAll({
        for (final entry in decoded.entries)
          entry.key.toString(): AccountSecret.fromJson(entry.value),
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
      throw StateError('AccountSecretStore is not initialized');
    }
  }
}
