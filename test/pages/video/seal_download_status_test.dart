import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/pages/video/seal_download_utils.dart';

void main() {
  test('parses applied strip outcome from Seal protocol v3', () {
    final status = SealDownloadStatus.fromMap(const <String, dynamic>{
      'status': 'completed',
      'strip_result': 'applied',
    });

    expect(status.stripResult, 'applied');
    expect(status.confirmsAppliedStrip, isTrue);
  });

  test('does not confirm a completed strip task without applied outcome', () {
    final status = SealDownloadStatus.fromMap(const <String, dynamic>{
      'status': 'completed',
      'strip_result': 'failed',
      'strip_message': 'Strip result was not applied; retry the strip task',
      'content_uri': 'content://unexpected-original',
    });

    expect(status.confirmsAppliedStrip, isFalse);
    expect(status.stripFailureMessage, contains('retry the strip task'));
  });

  test('uses failed strip message for a retryable task failure', () {
    final status = SealDownloadStatus.fromMap(const <String, dynamic>{
      'status': 'failed',
      'error_code': 'download_failed',
      'strip_result': 'failed',
      'strip_message':
          'Full-source strip fallback failed; retry the strip task',
    });

    expect(status.stripResult, 'failed');
    expect(status.userFacingErrorMessage, contains('retry the strip task'));
  });

  test('maps invalid keep sections to an actionable message', () {
    final status = SealDownloadStatus.fromMap(const <String, dynamic>{
      'status': 'rejected',
      'error_code': 'invalid_sections',
    });

    expect(status.userFacingErrorMessage, contains('片段区间无效'));
  });
}
