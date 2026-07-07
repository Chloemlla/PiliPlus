import 'package:pili_plus/services/crash/crash_reporter.dart';
import 'package:catcher_2/catcher_2.dart';

class CrashReportHandler extends ReportHandler {
  @override
  Future<bool> handle(Report report) async {
    final stackTrace = report.stackTrace;
    CrashReporter.recordErrorSync(
      report.error,
      stackTrace is StackTrace ? stackTrace : null,
    );
    return true;
  }
}
