import 'dart:async';

import 'package:pili_plus/services/crash/crash_context.dart';
import 'package:pili_plus/services/crash/crash_reporter.dart';

abstract final class Persistence {
  static void background(Future<void> operation, {required String label}) {
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        CrashReporter.recordErrorSync(
          error,
          stackTrace,
          severity: CrashSeverity.handled,
          module: 'persistence',
          operation: label,
          reason: 'background_persistence_failed',
        );
      }),
    );
  }
}
