import 'package:pili_plus/services/crash/crash_report.dart';

class CrashReportArchive {
  static const maxReports = 20;
  static const currentVersion = 1;

  final String? pendingReportId;
  final List<CrashReport> reports;

  const CrashReportArchive({
    required this.pendingReportId,
    required this.reports,
  });

  const CrashReportArchive.empty()
      : pendingReportId = null,
        reports = const [];

  CrashReport? get pendingReport {
    final id = pendingReportId;
    if (id == null) return null;
    for (final report in reports) {
      if (report.reportId == id) return report;
    }
    return null;
  }

  factory CrashReportArchive.fromJson(Object? json) {
    if (json is Map<String, dynamic>) {
      final items = json['reports'];
      if (items is List<dynamic>) {
        final reports = _decodeReports(items);
        final pendingReportId = json['pendingReportId'];
        return CrashReportArchive(
          pendingReportId: pendingReportId is String ? pendingReportId : null,
          reports: reports,
        );
      }
      final report = CrashReport.fromJson(json);
      return CrashReportArchive(
        pendingReportId: report.reportId,
        reports: [report],
      );
    }
    return const CrashReportArchive.empty();
  }

  CrashReportArchive add(CrashReport report) {
    if (reports.isNotEmpty && _isSameOccurrence(reports.first, report)) {
      final latest = reports.first;
      return CrashReportArchive(
        pendingReportId: latest.reportId,
        reports: reports,
      );
    }
    return CrashReportArchive(
      pendingReportId: report.reportId,
      reports: [report, ...reports].take(maxReports).toList(growable: false),
    );
  }

  CrashReportArchive markSeen(String reportId) => CrashReportArchive(
    pendingReportId: pendingReportId == reportId ? null : pendingReportId,
    reports: reports,
  );

  CrashReportArchive remove(String reportId) {
    final updated = reports
        .where((report) => report.reportId != reportId)
        .toList(growable: false);
    return CrashReportArchive(
      pendingReportId: pendingReportId == reportId ? null : pendingReportId,
      reports: updated,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': currentVersion,
    'pendingReportId': pendingReportId,
    'reports': [for (final report in reports) report.toJson()],
  };

  static List<CrashReport> _decodeReports(List<dynamic> items) {
    final reports = <CrashReport>[];
    final ids = <String>{};
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      try {
        final report = CrashReport.fromJson(item);
        if (ids.add(report.reportId)) reports.add(report);
      } catch (_) {
        continue;
      }
    }
    reports.sort((a, b) => b.crashedAtMillis.compareTo(a.crashedAtMillis));
    return reports.take(maxReports).toList(growable: false);
  }

  static bool _isSameOccurrence(CrashReport a, CrashReport b) {
    return (a.crashedAtMillis - b.crashedAtMillis).abs() <= 2000 &&
        a.exceptionType == b.exceptionType &&
        a.rootCause == b.rootCause &&
        a.stackTrace == b.stackTrace;
  }
}
