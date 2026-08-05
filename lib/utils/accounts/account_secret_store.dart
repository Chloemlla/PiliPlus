import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as crypt;
import 'package:path/path.dart' as path;
import 'package:pili_plus/utils/atomic_file.dart';

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
    final existing = AtomicFile.readPrimaryOrBackup(
      keyFile,
      _decodeKey,
    );
    if (existing != null) {
      return _decodeKey(existing);
    }
    final key = crypt.Key.fromSecureRandom(32);
    AtomicFile.replaceText(keyFile, key.base64, validate: _decodeKey);
    return key;
  }

  static crypt.Key _decodeKey(String contents) {
    final key = crypt.Key.fromBase64(contents.trim());
    if (key.bytes.length != 32) throw const FormatException('Invalid key size');
    return key;
  }

  static void _load() {
    _secrets.clear();
    final dataFile = _dataFile!;
    final contents = AtomicFile.readPrimaryOrBackup(dataFile, _decodeSecrets);
    if (contents == null) {
      return;
    }
    _secrets.addAll(_decodeSecrets(contents));
  }

  static Map<String, AccountSecret> _decodeSecrets(String contents) {
    final encryptedJson = jsonDecode(contents);
    if (encryptedJson is! Map) {
      throw const FormatException('Invalid account secret file');
    }
    final payload = encryptedJson['payload'];
    final iv = encryptedJson['iv'];
    if (payload is! String || iv is! String) {
      throw const FormatException('Invalid account secret payload');
    }
    final plainText = crypt.Encrypter(crypt.AES(_key!, mode: crypt.AESMode.gcm))
        .decrypt(
          crypt.Encrypted.fromBase64(payload),
          iv: crypt.IV.fromBase64(iv),
        );
    final decoded = jsonDecode(plainText);
    if (decoded is! Map) {
      throw const FormatException('Invalid account secret map');
    }
    return {
      for (final entry in decoded.entries)
        entry.key.toString(): AccountSecret.fromJson(entry.value),
    };
  }

  static void _save() {
    final iv = crypt.IV.fromSecureRandom(16);
    final payload = crypt.Encrypter(
      crypt.AES(_key!, mode: crypt.AESMode.gcm),
    ).encrypt(jsonEncode(_secrets), iv: iv);
    AtomicFile.replaceText(
      _dataFile!,
      jsonEncode({'version': 1, 'iv': iv.base64, 'payload': payload.base64}),
      validate: _decodeSecrets,
    );
  }

  static void _ensureInitialized() {
    if (!isInitialized) {
      throw StateError('AccountSecretStore is not initialized');
    }
  }
}
