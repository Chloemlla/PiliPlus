import 'dart:io';

import 'package:pili_plus/utils/setting_secret_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('SettingSecretStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('setting_secret_store_');
      SettingSecretStore.init(tempDir.path);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('does not persist setting secrets as plaintext', () {
      SettingSecretStore.write('webdavPassword', 'webdav-secret');

      final raw = File(
        path.join(tempDir.path, SettingSecretStore.dataFileName),
      ).readAsStringSync();

      expect(raw, isNot(contains('webdav-secret')));
    });

    test('loads persisted setting secrets after reinitialization', () {
      SettingSecretStore.write('webdavPassword', 'webdav-secret');

      SettingSecretStore.init(tempDir.path);

      expect(SettingSecretStore.read('webdavPassword'), 'webdav-secret');
    });
  });
}
