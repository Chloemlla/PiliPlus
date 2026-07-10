import 'dart:convert';
import 'dart:io';

import 'package:pili_plus/services/crash/crash_report.dart';
import 'package:pili_plus/services/crash/crash_report_archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract final class CrashReportStore {
  static const _fileName = 'crash_report.json';
  static List<File>? _files;

  static Future<void> ensureInitialized() async {
    if (_files != null) return;
    final dirs = await Future.wait([
      getApplicationSupportDirectory(),
      getApplicationDocumentsDirectory(),
      getTemporaryDirectory(),
    ]);
    _files = [for (final dir in dirs) File(p.join(dir.path, _fileName))];
  }

  static void saveSync(CrashReport report) {
    _saveArchiveSync(_loadArchive().add(report));
  }

  static Future<void> save(CrashReport report) async => saveSync(report);

  static CrashReport? load() => _loadArchive().pendingReport;

  static List<CrashReport> loadAll() => _loadArchive().reports;

  static Future<void> markSeen(String reportId) async {
    _saveArchiveSync(_loadArchive().markSeen(reportId));
  }

  static Future<void> remove(String reportId) async {
    _saveArchiveSync(_loadArchive().remove(reportId));
  }

  static void _saveArchiveSync(CrashReportArchive archive) {
    final files = _requireFiles();
    final payload = jsonEncode(archive.toJson());
    var saved = false;
    for (final file in files) {
      try {
        _writeAtomically(file, payload);
        saved = true;
      } catch (_) {
        continue;
      }
    }
    if (!saved) {
      throw FileSystemException(
        'Unable to persist crash report.',
        files.first.path,
      );
    }
  }

  static CrashReportArchive _loadArchive() {
    for (final file in _requireFiles()) {
      if (!file.existsSync()) continue;
      try {
        return CrashReportArchive.fromJson(
          jsonDecode(file.readAsStringSync()),
        );
      } catch (_) {
        continue;
      }
    }
    return const CrashReportArchive.empty();
  }

  static Future<void> clear() async {
    for (final file in _requireFiles()) {
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  static List<File> _requireFiles() {
    final files = _files;
    if (files == null) {
      throw StateError('CrashReportStore.ensureInitialized() was not called.');
    }
    return files;
  }

  static void _writeAtomically(File file, String payload) {
    file.parent.createSync(recursive: true);
    final tempFile = File('${file.path}.tmp')
      ..writeAsStringSync(payload, flush: true);
    if (file.existsSync()) {
      file.deleteSync();
    }
    try {
      tempFile.renameSync(file.path);
    } on FileSystemException {
      tempFile.deleteSync();
      file.writeAsStringSync(payload, flush: true);
    }
  }
}
