import 'dart:async';

import 'package:flutter/foundation.dart';

abstract final class Persistence {
  static void background(Future<void> operation, {required String label}) {
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        debugPrintStack(
          label: 'Background persistence failed ($label): $error',
          stackTrace: stackTrace,
        );
      }),
    );
  }
}
