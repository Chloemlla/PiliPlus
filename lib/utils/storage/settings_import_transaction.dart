import 'package:collection/collection.dart';

typedef SettingsSnapshot = Map<dynamic, dynamic>;
typedef SettingsSnapshotReader = SettingsSnapshot Function();
typedef SettingsClear = Future<void> Function();
typedef SettingsWriteAll = Future<void> Function(SettingsSnapshot values);
typedef SettingsRollbackVerifier = void Function();

final class SettingsImportTarget {
  const SettingsImportTarget({
    required this.read,
    required this.clear,
    required this.writeAll,
  });

  final SettingsSnapshotReader read;
  final SettingsClear clear;
  final SettingsWriteAll writeAll;
}

final class SettingsImportRollbackException implements Exception {
  const SettingsImportRollbackException({
    required this.importError,
    required this.rollbackError,
  });

  final Object importError;
  final Object rollbackError;

  @override
  String toString() =>
      'Settings import failed ($importError) and rollback could not be '
      'verified ($rollbackError)';
}

Future<void> replaceSettingsSections({
  required SettingsImportTarget setting,
  required SettingsSnapshot settingValues,
  required SettingsImportTarget video,
  required SettingsSnapshot videoValues,
  Future<void> Function()? applySupplemental,
  Future<void> Function()? restoreSupplemental,
  SettingsRollbackVerifier? verifySupplemental,
}) async {
  final settingSnapshot = Map<dynamic, dynamic>.of(setting.read());
  final videoSnapshot = Map<dynamic, dynamic>.of(video.read());
  try {
    await setting.clear();
    await setting.writeAll(settingValues);
    await video.clear();
    await video.writeAll(videoValues);
    if (applySupplemental != null) await applySupplemental();
  } catch (error, stackTrace) {
    final rollbackFailures = <({String operation, Object error})>[];
    StackTrace? firstRollbackStackTrace;

    Future<void> attempt(
      String operation,
      Future<void> Function() rollback,
    ) async {
      try {
        await rollback();
      } catch (rollbackError, rollbackStackTrace) {
        rollbackFailures.add((operation: operation, error: rollbackError));
        firstRollbackStackTrace ??= rollbackStackTrace;
      }
    }

    await attempt('setting.clear', setting.clear);
    await attempt(
      'setting.writeAll',
      () => setting.writeAll(settingSnapshot),
    );
    await attempt('video.clear', video.clear);
    await attempt('video.writeAll', () => video.writeAll(videoSnapshot));
    if (restoreSupplemental != null) {
      await attempt('supplemental.restore', restoreSupplemental);
    }
    await attempt(
      'setting.verify',
      () => Future<void>.sync(() {
        const equality = DeepCollectionEquality();
        if (!equality.equals(setting.read(), settingSnapshot)) {
          throw StateError('Setting rollback snapshot verification failed');
        }
      }),
    );
    await attempt(
      'video.verify',
      () => Future<void>.sync(() {
        const equality = DeepCollectionEquality();
        if (!equality.equals(video.read(), videoSnapshot)) {
          throw StateError('Video rollback snapshot verification failed');
        }
      }),
    );
    if (verifySupplemental != null) {
      await attempt(
        'supplemental.verify',
        () => Future<void>.sync(verifySupplemental),
      );
    }

    if (rollbackFailures.isNotEmpty) {
      final rollbackError = StateError(
        rollbackFailures
            .map((failure) => '${failure.operation}: ${failure.error}')
            .join('; '),
      );
      Error.throwWithStackTrace(
        SettingsImportRollbackException(
          importError: error,
          rollbackError: rollbackError,
        ),
        firstRollbackStackTrace ?? stackTrace,
      );
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}
