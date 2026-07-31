import 'package:pili_plus/utils/storage/settings_import_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'write failure restores both settings sections before rethrowing',
    () async {
      final setting = _MemorySettingsTarget({
        'theme': 1,
        'windowSize': <double>[1180, 720],
      });
      final video = _MemorySettingsTarget({
        'playRepeat': 2,
        'speeds': <double>[1, 1.5, 2],
      })..failOnWrite = 1;

      await expectLater(
        replaceSettingsSections(
          setting: setting.target,
          settingValues: const {'theme': 2},
          video: video.target,
          videoValues: const {'playRepeat': 3},
        ),
        throwsStateError,
      );

      expect(setting.data, {
        'theme': 1,
        'windowSize': <double>[1180, 720],
      });
      expect(video.data, {
        'playRepeat': 2,
        'speeds': <double>[1, 1.5, 2],
      });
    },
  );

  test(
    'reports rollback corruption instead of hiding snapshot drift',
    () async {
      final setting = _MemorySettingsTarget({'theme': 1})..corruptOnWrite = 2;
      final video = _MemorySettingsTarget({'playRepeat': 2})..failOnWrite = 1;

      await expectLater(
        replaceSettingsSections(
          setting: setting.target,
          settingValues: const {'theme': 2},
          video: video.target,
          videoValues: const {'playRepeat': 3},
        ),
        throwsA(isA<SettingsImportRollbackException>()),
      );
    },
  );

  test(
    'supplemental restore still runs when a box rollback step fails',
    () async {
      final setting = _MemorySettingsTarget({'theme': 1})..failOnWrite = 2;
      final video = _MemorySettingsTarget({'playRepeat': 2})..failOnWrite = 1;
      var supplementalRestoreCalls = 0;
      var supplementalVerifyCalls = 0;

      await expectLater(
        replaceSettingsSections(
          setting: setting.target,
          settingValues: const {'theme': 2},
          video: video.target,
          videoValues: const {'playRepeat': 3},
          restoreSupplemental: () => Future<void>.sync(() {
            supplementalRestoreCalls++;
          }),
          verifySupplemental: () {
            supplementalVerifyCalls++;
          },
        ),
        throwsA(isA<SettingsImportRollbackException>()),
      );

      expect(supplementalRestoreCalls, 1);
      expect(supplementalVerifyCalls, 1);
      expect(video.data, {'playRepeat': 2});
    },
  );

  test(
    'supplemental failure restores both sections and the old secret',
    () async {
      final setting = _MemorySettingsTarget({'theme': 1});
      final video = _MemorySettingsTarget({'playRepeat': 2});
      var supplemental = 'old-secret';

      await expectLater(
        replaceSettingsSections(
          setting: setting.target,
          settingValues: const {'theme': 2},
          video: video.target,
          videoValues: const {'playRepeat': 3},
          applySupplemental: () => Future<void>.sync(() {
            supplemental = 'new-secret';
            throw StateError('injected supplemental write failure');
          }),
          restoreSupplemental: () => Future<void>.sync(() {
            supplemental = 'old-secret';
          }),
          verifySupplemental: () {
            if (supplemental != 'old-secret') {
              throw StateError('supplemental rollback verification failed');
            }
          },
        ),
        throwsStateError,
      );

      expect(setting.data, {'theme': 1});
      expect(video.data, {'playRepeat': 2});
      expect(supplemental, 'old-secret');
    },
  );
}

final class _MemorySettingsTarget {
  _MemorySettingsTarget(Map<dynamic, dynamic> initial)
    : data = Map<dynamic, dynamic>.of(initial);

  Map<dynamic, dynamic> data;
  int writeCount = 0;
  int? failOnWrite;
  int? corruptOnWrite;

  SettingsImportTarget get target => SettingsImportTarget(
    read: () => Map<dynamic, dynamic>.of(data),
    clear: () async {
      data.clear();
    },
    writeAll: (values) async {
      writeCount++;
      if (writeCount == failOnWrite) {
        throw StateError('injected settings write failure');
      }
      data = Map<dynamic, dynamic>.of(values);
      if (writeCount == corruptOnWrite && data.isNotEmpty) {
        data.remove(data.keys.first);
      }
    },
  );
}
