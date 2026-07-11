import 'package:pili_plus/services/crash/crash_report.dart';

class CrashReportArchive {
  static const maxReports = 20;
  static const currentVersion = 2;

  final String? pendingReportId;
  final List<CrashReport> reports;

  const CrashReportArchive({
    required this.pendingReportId,
    required this.reports,
  });

  const CrashReportArchive.empty() : pendingReportId = null, reports = const [];

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
        final pending = pendingReportId is String ? pendingReportId : null;
        return CrashReportArchive(
          pendingReportId: pending,
          reports: _retainReports(reports, pending),
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

  CrashReportArchive add(CrashReport report, {bool makePending = true}) {
    final updated = List<CrashReport>.of(reports);
    final duplicateIndex = updated.indexWhere(
      (existing) => _isSameOccurrence(existing, report),
    );
    final candidate = duplicateIndex == -1
        ? report
        : updated[duplicateIndex].mergeWith(report);
    if (duplicateIndex != -1) {
      updated.removeAt(duplicateIndex);
    }
    updated
      ..add(candidate)
      ..sort((a, b) => b.crashedAtMillis.compareTo(a.crashedAtMillis));
    final nextPending = _selectPending(
      reports: updated,
      currentPendingId: pendingReportId,
      candidate: candidate,
      makePending: makePending,
    );
    return CrashReportArchive(
      pendingReportId: nextPending,
      reports: _retainReports(updated, nextPending),
    );
  }

  static CrashReportArchive mergeReplicas(
    Iterable<CrashReportArchive> archives,
  ) {
    final reportsById = <String, CrashReport>{};
    final pendingIds = <String>{};
    for (final archive in archives) {
      if (archive.pendingReportId case final pending?) pendingIds.add(pending);
      for (final report in archive.reports) {
        reportsById.update(
          report.reportId,
          (existing) => existing.mergeWith(report),
          ifAbsent: () => report,
        );
      }
    }
    final reports = reportsById.values.toList()
      ..sort((a, b) => b.crashedAtMillis.compareTo(a.crashedAtMillis));
    String? pendingReportId;
    for (final report in reports) {
      if (pendingIds.contains(report.reportId)) {
        pendingReportId = report.reportId;
        break;
      }
    }
    return CrashReportArchive(
      pendingReportId: pendingReportId,
      reports: _retainReports(reports, pendingReportId),
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
    return reports;
  }

  static String? _selectPending({
    required List<CrashReport> reports,
    required String? currentPendingId,
    required CrashReport candidate,
    required bool makePending,
  }) {
    if (!makePending) return currentPendingId;
    final current = _findById(reports, currentPendingId);
    return current == null ||
            candidate.crashedAtMillis >= current.crashedAtMillis
        ? candidate.reportId
        : current.reportId;
  }

  static List<CrashReport> _retainReports(
    List<CrashReport> reports,
    String? pendingReportId,
  ) {
    final retained = reports.take(maxReports).toList(growable: true);
    if (pendingReportId == null ||
        retained.any((report) => report.reportId == pendingReportId)) {
      return retained.toList(growable: false);
    }
    final pending = _findById(reports, pendingReportId);
    if (pending != null) {
      if (retained.length >= maxReports) retained.removeLast();
      retained
        ..add(pending)
        ..sort((a, b) => b.crashedAtMillis.compareTo(a.crashedAtMillis));
    }
    return retained.toList(growable: false);
  }

  static CrashReport? _findById(
    Iterable<CrashReport> reports,
    String? reportId,
  ) {
    if (reportId == null) return null;
    for (final report in reports) {
      if (report.reportId == reportId) return report;
    }
    return null;
  }

  static bool _isSameOccurrence(CrashReport a, CrashReport b) {
    return (a.crashedAtMillis - b.crashedAtMillis).abs() <= 2000 &&
        a.exceptionType == b.exceptionType &&
        a.rootCause == b.rootCause &&
        a.stackTrace == b.stackTrace;
  }
}
