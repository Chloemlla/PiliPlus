import 'package:pili_plus/utils/settings_backup_validator.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects unknown schema versions', () {
    expect(
      () => SettingsBackupValidator.validateSchemaVersion({
        'schemaVersion': SettingsBackupValidator.currentSchemaVersion + 1,
      }),
      throwsFormatException,
    );
  });

  test('rejects invalid startup-critical values before import', () {
    expect(
      () => SettingsBackupValidator.validateSection(
        {
          'setting': {
            SettingBoxKey.schemeVariant: 999,
            SettingBoxKey.windowSize: [1180],
          },
        },
        'setting',
        const {},
      ),
      throwsFormatException,
    );
  });

  test('accepts legacy version zero with valid settings', () {
    final result = SettingsBackupValidator.validateSection(
      {
        'setting': {
          SettingBoxKey.windowSize: [1180.0, 720.0],
          SettingBoxKey.customColor: 0xFF00FF00,
        },
      },
      'setting',
      const {},
    );

    expect(result[SettingBoxKey.windowSize], [1180.0, 720.0]);
  });
}
