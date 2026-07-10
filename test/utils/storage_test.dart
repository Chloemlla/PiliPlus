import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:pili_plus/utils/settings_backup_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settings backup validation', () {
    test('accepts map sections', () {
      final section = SettingsBackupValidator.validateSection(
        {
          'setting': {'theme': 'dark'},
        },
        'setting',
        const {},
      );

      expect(section, {'theme': 'dark'});
    });

    test('rejects missing sections', () {
      expect(
        () => SettingsBackupValidator.validateSection(
          {},
          'setting',
          const {},
        ),
        throwsFormatException,
      );
    });

    test('rejects non-map sections', () {
      expect(
        () => SettingsBackupValidator.validateSection(
          {'setting': true},
          'setting',
          const {},
        ),
        throwsFormatException,
      );
    });

    test('removes WebDAV password from exported settings', () {
      final sanitized = GStorage.sanitizeSettingsForExport({
        SettingBoxKey.webdavUri: 'https://example.com',
        SettingBoxKey.webdavPassword: 'secret',
      });

      expect(
        sanitized,
        containsPair(SettingBoxKey.webdavUri, 'https://example.com'),
      );
      expect(sanitized, isNot(contains(SettingBoxKey.webdavPassword)));
    });
  });
}
