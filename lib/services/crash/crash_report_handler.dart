import 'package:pili_plus/services/crash/crash_reporter.dart';
import 'package:catcher_2/catcher_2.dart';

class CrashReportHandler extends ReportHandler {
  @override
  Future<bool> handle(Report report) async {
    CrashReporter.recordErrorSync(report.error, report.stackTrace);
    return true;
  }
}
