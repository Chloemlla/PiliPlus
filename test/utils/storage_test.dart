import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settings backup validation', () {
    test('accepts map sections', () {
      final section = GStorage.validateSettingsSection({
        'setting': {'theme': 'dark'},
      }, 'setting');

      expect(section, {'theme': 'dark'});
    });

    test('rejects missing sections', () {
      expect(
        () => GStorage.validateSettingsSection({}, 'setting'),
        throwsFormatException,
      );
    });

    test('rejects non-map sections', () {
      expect(
        () => GStorage.validateSettingsSection({'setting': true}, 'setting'),
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
