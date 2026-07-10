import 'package:pili_plus/services/crash/crash_report.dart';
import 'package:pili_plus/services/crash/crash_report_archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashReportArchive', () {
    test('migrates a legacy single report and keeps it pending', () {
      final report = _report(1);

      final archive = CrashReportArchive.fromJson(report.toJson());

      expect(archive.reports.single.reportId, report.reportId);
      expect(archive.pendingReport?.reportId, report.reportId);
    });

    test('marks a startup report seen without deleting history', () {
      final report = _report(1);
      final archive = const CrashReportArchive.empty().add(report);

      final updated = archive.markSeen(report.reportId);

      expect(updated.pendingReport, isNull);
      expect(updated.reports, [report]);
    });

    test('deduplicates repeated callbacks for the same occurrence', () {
      final first = _report(1000);
      final duplicate = _report(1500, reportId: 'duplicate');

      final archive = const CrashReportArchive.empty()
          .add(first)
          .add(duplicate);

      expect(archive.reports, [first]);
      expect(archive.pendingReport?.reportId, first.reportId);
    });

    test('retains only the newest bounded history', () {
      var archive = const CrashReportArchive.empty();
      for (var i = 0; i < CrashReportArchive.maxReports + 2; i++) {
        archive = archive.add(_report(i, rootCause: 'failure-$i'));
      }

      expect(archive.reports, hasLength(CrashReportArchive.maxReports));
      expect(archive.reports.first.crashedAtMillis, 21);
      expect(archive.reports.last.crashedAtMillis, 2);
    });
  });
}

CrashReport _report(
  int crashedAtMillis, {
  String? reportId,
  String rootCause = 'failure',
}) {
  return CrashReport(
    reportId: reportId ?? 'report-$crashedAtMillis',
    crashedAtMillis: crashedAtMillis,
    crashedAtText: crashedAtMillis.toString(),
    exceptionType: 'StateError',
    rootCause: rootCause,
    threadName: 'main',
    processName: 'pid:1',
    systemInfo: 'test',
    stackTrace: 'stack',
  );
}
