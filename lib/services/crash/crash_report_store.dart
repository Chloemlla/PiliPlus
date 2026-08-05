import 'dart:convert';
import 'dart:io';

import 'package:pili_plus/services/crash/crash_report.dart';
import 'package:pili_plus/services/crash/crash_report_archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract final class CrashReportStore {
  static const _fileName = 'crash_report.json';
  static List<File>? _files;

  static bool get isInitialized => _files != null;

  static Future<void> ensureInitialized() async {
    if (_files != null) return;
    final dirs = await Future.wait([
      getApplicationSupportDirectory(),
      getApplicationDocumentsDirectory(),
      getTemporaryDirectory(),
    ]);
    _files = [for (final dir in dirs) File(p.join(dir.path, _fileName))];
  }

  static void saveSync(CrashReport report, {required bool makePending}) {
    _saveArchiveSync(_loadArchive().add(report, makePending: makePending));
  }

  static Future<void> save(
    CrashReport report, {
    required bool makePending,
  }) => Future.sync(() => saveSync(report, makePending: makePending));

  static CrashReport? load() => _loadArchive().pendingReport;

  static List<CrashReport> loadAll() => _loadArchive().reports;

  static Future<void> markSeen(String reportId) =>
      Future.sync(() => _saveArchiveSync(_loadArchive().markSeen(reportId)));

  static Future<void> remove(String reportId) =>
      Future.sync(() => _saveArchiveSync(_loadArchive().remove(reportId)));

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
    final replicas = <({int modifiedAt, CrashReportArchive archive})>[];
    for (final file in _requireFiles()) {
      if (!file.existsSync()) continue;
      try {
        replicas.add(
          (
            modifiedAt: file.lastModifiedSync().millisecondsSinceEpoch,
            archive: CrashReportArchive.fromJson(
              jsonDecode(file.readAsStringSync()),
            ),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    if (replicas.isEmpty) return const CrashReportArchive.empty();
    var latestModifiedAt = replicas.first.modifiedAt;
    for (final replica in replicas.skip(1)) {
      if (replica.modifiedAt > latestModifiedAt) {
        latestModifiedAt = replica.modifiedAt;
      }
    }
    return CrashReportArchive.mergeReplicas(
      replicas
          .where((replica) => replica.modifiedAt == latestModifiedAt)
          .map((replica) => replica.archive),
    );
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
