import 'package:pili_plus/services/crash/crash_context.dart';
import 'package:pili_plus/services/crash/crash_report.dart';
import 'package:pili_plus/services/crash/crash_report_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashReportFilter', () {
    test('ignores SSL seek failures regardless of case or punctuation', () {
      expect(CrashReportFilter.shouldIgnore('SSL seek failed'), isTrue);
      expect(
        CrashReportFilter.shouldIgnore('Player error: ssl: avio seek failed'),
        isTrue,
      );
    });

    test('ignores recoverable player transport failures', () {
      expect(
        CrashReportFilter.shouldIgnore(
          'Failed to open https://example.invalid/video.m4s',
        ),
        isTrue,
      );
      expect(
        CrashReportFilter.shouldIgnore(
          'https: Stream ends prematurely at 1, should be 2',
        ),
        isTrue,
      );
    });

    test('ignores bare player diagnostics instead of treating them as code', () {
      const messages = <String>[
        'Seek failed (to 1790, size 18217805)',
        'tcp: Connection to tcp://upos.example:443 failed: Connection refused',
        'tls: mbedtls_ssl_handshake returned -0x7280',
        'amediacodec: java.lang.IllegalStateException: Released state',
        'NULL: Invalid NAL unit size (115387 > 86588).',
        'unsupported format for accessing property',
        '',
      ];

      for (final message in messages) {
        expect(
          CrashReportFilter.shouldIgnore(message),
          isTrue,
          reason: message,
        );
      }
    });

    test('ignores known player diagnostics even when wrapped', () {
      expect(
        CrashReportFilter.shouldIgnore(
          Exception('tcp: Failed to resolve hostname upos.example'),
        ),
        isTrue,
      );
      expect(
        CrashReportFilter.shouldIgnore(
          Exception('NULL: missing picture in access unit with size 86598'),
        ),
        isTrue,
      );
    });

    test('keeps real Dart failures reportable', () {
      final stackTrace = StackTrace.fromString(
        '#0 Navigator.of (package:flutter/src/widgets/navigator.dart:2937)',
      );

      expect(
        CrashReportFilter.shouldIgnore(
          'application invariant failed',
          stackTrace,
        ),
        isFalse,
      );
      expect(
        CrashReportFilter.shouldIgnore(
          StateError('Null check operator used on a null value'),
          stackTrace,
        ),
        isFalse,
      );
      expect(
        CrashReportFilter.shouldIgnore(
          StateError('tcp: Connection refused while updating app state'),
          StackTrace.fromString(
            '#0 Controller.load (package:pili_plus/pages/video/controller.dart:1)',
          ),
        ),
        isFalse,
      );
    });

    test('ignores only the exact HTTP/2 GOAWAY writer-close race', () {
      final goawayStack = StackTrace.fromString('''
#0 BufferedBytesWriter.add (package:http2/src/frames/frame_writer.dart:20)
#1 FrameWriter.writeGoawayFrame (package:http2/src/frames/frame_writer.dart:252)
#2 ConnectionMessageQueueOut._process (package:http2/src/flowcontrol/connection_queues.dart:88)
''');

      expect(
        CrashReportFilter.shouldIgnore(
          StateError('Cannot add event after closing'),
          goawayStack,
        ),
        isTrue,
      );
      expect(
        CrashReportFilter.shouldIgnore(
          StateError('Cannot add event after closing'),
          StackTrace.fromString(
            '#0 StreamController.add (dart:async/stream_controller.dart:1)',
          ),
        ),
        isFalse,
      );
      expect(
        CrashReportFilter.shouldIgnore(
          StateError('Cannot add event after closing'),
          StackTrace.fromString(
            '${goawayStack.toString()}'
            '#3 Request.reset (package:pili_plus/http/init.dart:1)',
          ),
        ),
        isFalse,
      );
      expect(
        CrashReportFilter.shouldIgnore(
          StateError(
            'The `handler` has already been called, '
            'make sure each handler gets called only once.',
          ),
          StackTrace.fromString(
            '#0 RequestInterceptorHandler.reject '
            '(package:dio/src/interceptor.dart:117)',
          ),
        ),
        isFalse,
      );
    });
  });

  group('CrashReportFilter.isKnownDeviceIssue', () {
    CrashReport nativeReport({
      required String trace,
      String reason = 'native_crash',
    }) {
      return CrashReport(
        reportId: 'r',
        crashedAtMillis: 1,
        crashedAtText: 't',
        exceptionType: 'ApplicationExitInfo',
        rootCause: 'crash',
        threadName: 'RenderThread',
        processName: 'com.chloemlla.piliplus',
        systemInfo: 'OS: android',
        stackTrace: trace,
        source: CrashSource.androidExitInfo,
        reason: reason,
      );
    }

    test('matches hwui ShaderCache::store native crash', () {
      const trace = r'''
SIGSEGV SEGV_MAPERR
null pointer dereference RenderThread
nanosleep libc.so
usleep libc.so
void android::uirenderer::skiapipeline::ShaderCache::store(...)::$_0 libhwui.so
__thread_proxy libhwui.so
''';
      expect(
        CrashReportFilter.isKnownDeviceIssue(nativeReport(trace: trace)),
        isTrue,
      );
    });

    test('matches signature case-insensitively', () {
      const trace =
          r'android::uirenderer::skiapipeline::ShaderCache::store libhwui.so';
      expect(
        CrashReportFilter.isKnownDeviceIssue(nativeReport(trace: trace)),
        isTrue,
      );
    });

    test('ignores non-native crash reasons', () {
      const trace = 'ShaderCache::store libhwui.so';
      expect(
        CrashReportFilter.isKnownDeviceIssue(
          nativeReport(trace: trace, reason: 'anr'),
        ),
        isFalse,
      );
    });

    test('ignores unrelated native crashes', () {
      const trace = 'SIGSEGV SEGV_MAPERR\nlibflutter.so unknown frame';
      expect(
        CrashReportFilter.isKnownDeviceIssue(nativeReport(trace: trace)),
        isFalse,
      );
    });
  });
}
