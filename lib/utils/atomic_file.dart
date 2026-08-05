import 'dart:io';

abstract final class AtomicFile {
  static File backupOf(File target) => File('${target.path}.bak');

  /// Replaces [target] only after [contents] has been written and validated.
  ///
  /// A valid previous target is copied to the backup generation before the
  /// replacement is promoted. The previous backup is retained when the
  /// current target is invalid or when any promotion step fails.
  static void replaceText(
    File target,
    String contents, {
    void Function(String contents)? validate,
  }) {
    final temp = File('${target.path}.tmp');
    final targetStage = File('${target.path}.replace');
    final backup = backupOf(target);
    final backupTemp = File('${backup.path}.tmp');
    final backupStage = File('${backup.path}.replace');

    _deleteIfExists(temp);
    _deleteIfExists(targetStage);
    _deleteIfExists(backupTemp);
    _deleteIfExists(backupStage);

    try {
      temp.writeAsStringSync(contents, flush: true);
      final written = temp.readAsStringSync();
      validate?.call(written);

      final targetWasValid = _isValid(target, validate);
      if (targetWasValid) {
        target.copySync(backupTemp.path);
      }

      if (target.existsSync()) {
        target.renameSync(targetStage.path);
      }
      try {
        temp.renameSync(target.path);
      } catch (_) {
        if (target.existsSync()) target.deleteSync();
        if (targetStage.existsSync()) targetStage.renameSync(target.path);
        rethrow;
      }

      if (targetWasValid) {
        _promoteBackup(backupTemp, backup, backupStage);
      }
    } finally {
      _deleteIfExists(temp);
      _deleteIfExists(targetStage);
      _deleteIfExists(backupTemp);
      _deleteIfExists(backupStage);
    }
  }

  static String? readPrimaryOrBackup(
    File target,
    void Function(String contents) validate,
  ) {
    Object? primaryError;
    if (target.existsSync()) {
      try {
        final contents = target.readAsStringSync();
        validate(contents);
        return contents;
      } catch (error) {
        primaryError = error;
      }
    }

    final backup = backupOf(target);
    if (backup.existsSync()) {
      final contents = backup.readAsStringSync();
      validate(contents);
      _restoreFromBackup(target, contents, validate);
      return contents;
    }

    if (primaryError != null) {
      final corrupt = File(
        '${target.path}.corrupt.${DateTime.now().millisecondsSinceEpoch}',
      );
      try {
        target.renameSync(corrupt.path);
      } catch (error) {
        throw StateError(
          'Invalid file could not be quarantined at ${corrupt.path}: '
          '${error.runtimeType}',
        );
      }
      throw StateError(
        'Invalid file quarantined at ${corrupt.path}: '
        '${primaryError.runtimeType}',
      );
    }
    return null;
  }

  static bool _isValid(File file, void Function(String contents)? validate) {
    if (!file.existsSync()) return false;
    if (validate == null) return true;
    try {
      validate(file.readAsStringSync());
      return true;
    } catch (_) {
      return false;
    }
  }

  static void _promoteBackup(
    File backupTemp,
    File backup,
    File backupStage,
  ) {
    if (backup.existsSync()) {
      backup.renameSync(backupStage.path);
    }
    try {
      backupTemp.renameSync(backup.path);
    } catch (_) {
      if (backup.existsSync()) backup.deleteSync();
      if (backupStage.existsSync()) backupStage.renameSync(backup.path);
      rethrow;
    }
    _deleteIfExists(backupStage);
  }

  static void _restoreFromBackup(
    File target,
    String contents,
    void Function(String contents) validate,
  ) {
    replaceText(target, contents, validate: validate);
  }

  static void _deleteIfExists(File file) {
    if (file.existsSync()) file.deleteSync();
  }
}
