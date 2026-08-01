import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/download/seal_download_status.dart';

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
    expect(
      status.isUnconfirmedCompletedStrip(stripRequested: true),
      isTrue,
    );
    expect(
      status.isUnconfirmedCompletedStrip(stripRequested: false),
      isFalse,
    );
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

  test('expands task_ids and preserves real task metadata', () {
    final status = SealDownloadStatus.fromMap(const <String, dynamic>{
      'protocol_version': 3,
      'status': 'downloading',
      'task_id': 'task-1',
      'task_ids': <String>['task-1', 'task-2'],
      'caller_request_id': 'request-1',
      'progress': 0.42,
      'downloaded_bytes': 420,
      'total_bytes': 1000,
      'title': 'Example title',
      'quality': '1080p',
      'source_url': 'https://www.bilibili.com/video/BV1xx',
      'extract_audio': false,
    });

    final expanded = status.expandTaskIds();
    expect(expanded.map((item) => item.taskId), <String>['task-1', 'task-2']);
    expect(expanded.every((item) => item.callerRequestId == 'request-1'), true);
    expect(expanded.first.progress, 0.42);
    expect(expanded.first.downloadedBytes, 420);
    expect(expanded.first.totalBytes, 1000);
    expect(expanded.first.title, 'Example title');
    expect(expanded.first.quality, '1080p');
    expect(expanded.first.sourceUrl, contains('BV1xx'));
    expect(expanded.first.extractAudio, false);
  });

  test('uses task id before request id as stable identity', () {
    final withTask = SealDownloadStatus.fromMap(const <String, dynamic>{
      'status': 'waiting',
      'task_id': 'task-1',
      'caller_request_id': 'request-1',
    });
    final requestOnly = SealDownloadStatus.fromMap(const <String, dynamic>{
      'status': 'waiting',
      'caller_request_id': 'request-1',
    });

    expect(withTask.stableIdentity, 'task-1');
    expect(requestOnly.stableIdentity, 'request-1');
  });
}
