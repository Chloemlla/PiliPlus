import 'dart:io';

abstract final class AtomicFile {
  static File backupOf(File target) => File('${target.path}.bak');

  static void replaceText(
    File target,
    String contents, {
    void Function(String contents)? validate,
  }) {
    final temp = File('${target.path}.tmp');
    final backup = backupOf(target);
    if (temp.existsSync()) temp.deleteSync();
    temp.writeAsStringSync(contents, flush: true);
    final written = temp.readAsStringSync();
    validate?.call(written);

    if (backup.existsSync()) backup.deleteSync();
    if (target.existsSync()) target.renameSync(backup.path);
    try {
      temp.renameSync(target.path);
    } catch (_) {
      if (target.existsSync()) target.deleteSync();
      if (backup.existsSync()) backup.renameSync(target.path);
      rethrow;
    } finally {
      if (temp.existsSync()) temp.deleteSync();
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
      replaceText(target, contents, validate: validate);
      return contents;
    }
    if (primaryError != null) {
      final corrupt =
          '${target.path}.corrupt.${DateTime.now().millisecondsSinceEpoch}';
      target.renameSync(corrupt);
      throw StateError('Invalid file quarantined at $corrupt: $primaryError');
    }
    return null;
  }
}
