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

    test('keeps unrelated failures reportable', () {
      expect(CrashReportFilter.shouldIgnore('Could not open codec'), isFalse);
      expect(CrashReportFilter.shouldIgnore(StateError('boom')), isFalse);
    });
  });
}
