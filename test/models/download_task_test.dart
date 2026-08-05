import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/download/download_task.dart';

void main() {
  group('DownloadStatus', () {
    test('should have correct status flags', () {
      expect(DownloadStatus.waiting.isActive, true);
      expect(DownloadStatus.downloading.isActive, true);
      expect(DownloadStatus.paused.isActive, false);
      expect(DownloadStatus.completed.isActive, false);
      expect(DownloadStatus.failed.isActive, false);

      expect(DownloadStatus.completed.isTerminal, true);
      expect(DownloadStatus.failed.isTerminal, true);
      expect(DownloadStatus.waiting.isTerminal, false);
      expect(DownloadStatus.downloading.isTerminal, false);
      expect(DownloadStatus.paused.isTerminal, false);
    });
  });

  group('DownloadTask', () {
    test('should create task with all fields', () {
      final now = DateTime.now();
      final task = DownloadTask(
        requestId: 'req_1',
        bvid: 'BV123456',
        title: 'Test Video',
        quality: '1080P',
        format: 'video',
        status: DownloadStatus.downloading,
        progress: 0.5,
        downloadedBytes: 50000000,
        totalBytes: 100000000,
        errorMessage: null,
        createdAt: now,
        completedAt: null,
        taskId: 'task_1',
        contentUri: null,
        displayName: 'Test Video.mp4',
        source: 'https://bilibili.com/video/BV123456',
        extractAudio: false,
      );

      expect(task.requestId, 'req_1');
      expect(task.bvid, 'BV123456');
      expect(task.title, 'Test Video');
      expect(task.quality, '1080P');
      expect(task.format, 'video');
      expect(task.status, DownloadStatus.downloading);
      expect(task.progress, 0.5);
      expect(task.downloadedBytes, 50000000);
      expect(task.totalBytes, 100000000);
      expect(task.errorMessage, null);
      expect(task.createdAt, now);
      expect(task.completedAt, null);
      expect(task.taskId, 'task_1');
      expect(task.contentUri, null);
      expect(task.displayName, 'Test Video.mp4');
      expect(task.extractAudio, false);
    });

    test('should use default values for optional fields', () {
      final now = DateTime.now();
      final task = DownloadTask(
        requestId: 'req_1',
        bvid: 'BV123456',
        title: 'Test Video',
        quality: '',
        format: 'video',
        status: DownloadStatus.waiting,
        createdAt: now,
      );

      expect(task.progress, 0.0);
      expect(task.downloadedBytes, 0);
      expect(task.totalBytes, 0);
      expect(task.errorMessage, null);
      expect(task.completedAt, null);
      expect(task.taskId, null);
      expect(task.contentUri, null);
      expect(task.displayName, null);
      expect(task.source, null);
      expect(task.extractAudio, false);
    });

    test('should identify audio format', () {
      final videoTask = DownloadTask(
        requestId: 'req_1',
        bvid: 'BV123456',
        title: 'Test',
        quality: '',
        format: 'video',
        status: DownloadStatus.waiting,
        createdAt: DateTime.now(),
      );
      final audioTask = DownloadTask(
        requestId: 'req_2',
        bvid: 'BV123456',
        title: 'Test Audio',
        quality: '',
        format: 'audio',
        status: DownloadStatus.waiting,
        createdAt: DateTime.now(),
      );

      expect(videoTask.isAudio, false);
      expect(audioTask.isAudio, true);
    });

    test('should have correct action flags', () {
      final waitingTask = DownloadTask(
        requestId: 'req_1',
        bvid: 'BV123456',
        title: 'Test',
        quality: '',
        format: 'video',
        status: DownloadStatus.waiting,
        createdAt: DateTime.now(),
      );
      final downloadingTask = DownloadTask(
        requestId: 'req_2',
        bvid: 'BV123456',
        title: 'Test',
        quality: '',
        format: 'video',
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
      );
      final pausedTask = DownloadTask(
        requestId: 'req_3',
        bvid: 'BV123456',
        title: 'Test',
        quality: '',
        format: 'video',
        status: DownloadStatus.paused,
        createdAt: DateTime.now(),
      );
      final completedTask = DownloadTask(
        requestId: 'req_4',
        bvid: 'BV123456',
        title: 'Test',
        quality: '',
        format: 'video',
        status: DownloadStatus.completed,
        createdAt: DateTime.now(),
        contentUri: 'content://test',
      );
      final failedTask = DownloadTask(
        requestId: 'req_5',
        bvid: 'BV123456',
        title: 'Test',
        quality: '',
        format: 'video',
        status: DownloadStatus.failed,
        createdAt: DateTime.now(),
        contentUri: 'content://test',
      );

      expect(waitingTask.canPause, true);
      expect(waitingTask.canResume, false);
      expect(waitingTask.canRetry, false);
      expect(waitingTask.canOpen, false);

      expect(downloadingTask.canPause, true);
      expect(downloadingTask.canResume, false);
      expect(downloadingTask.canRetry, false);

      expect(pausedTask.canPause, false);
      expect(pausedTask.canResume, true);
      expect(pausedTask.canRetry, false);

      expect(completedTask.canPause, false);
      expect(completedTask.canResume, false);
      expect(completedTask.canRetry, false);
      expect(completedTask.canOpen, true);

      expect(failedTask.canPause, false);
      expect(failedTask.canResume, false);
      expect(failedTask.canRetry, true);
      expect(failedTask.canOpen, false);
    });

    test('should format size correctly', () {
      final task1 = DownloadTask(
        requestId: 'req_1',
        bvid: 'BV123456',
        title: 'Test',
        quality: '',
        format: 'video',
        status: DownloadStatus.downloading,
        downloadedBytes: 500,
        totalBytes: 1000,
        createdAt: DateTime.now(),
      );
      expect(task1.formattedSize, '500 B / 1000 B');

      final task2 = DownloadTask(
        requestId: 'req_2',
        bvid: 'BV123456',
        title: 'Test',
        quality: '',
        format: 'video',
        status: DownloadStatus.downloading,
        downloadedBytes: 50000,
        totalBytes: 100000,
        createdAt: DateTime.now(),
      );
      expect(task2.formattedSize, '48.8 KB / 97.7 KB');

      final task3 = DownloadTask(
        requestId: 'req_3',
        bvid: 'BV123456',
        title: 'Test',
        quality: '',
        format: 'video',
        status: DownloadStatus.downloading,
        downloadedBytes: 50000000,
        totalBytes: 100000000,
        createdAt: DateTime.now(),
      );
      expect(task3.formattedSize, '47.7 MB / 95.4 MB');

      final task4 = DownloadTask(
        requestId: 'req_4',
        bvid: 'BV123456',
        title: 'Test',
        quality: '',
        format: 'video',
        status: DownloadStatus.downloading,
        downloadedBytes: 5000000000,
        totalBytes: 10000000000,
        createdAt: DateTime.now(),
      );
      expect(task4.formattedSize, '4.66 GB / 9.31 GB');

      final task5 = DownloadTask(
        requestId: 'req_5',
        bvid: 'BV123456',
        title: 'Test',
        quality: '',
        format: 'video',
        status: DownloadStatus.waiting,
        downloadedBytes: 0,
        totalBytes: 0,
        createdAt: DateTime.now(),
      );
      expect(task5.formattedSize, '--');
    });

    test('should return correct status labels', () {
      expect(
        DownloadTask(
          requestId: 'req_1',
          bvid: 'BV123456',
          title: 'Test',
          quality: '',
          format: 'video',
          status: DownloadStatus.waiting,
          createdAt: DateTime.now(),
        ).statusLabel,
        '等待中',
      );

      expect(
        DownloadTask(
          requestId: 'req_2',
          bvid: 'BV123456',
          title: 'Test',
          quality: '',
          format: 'video',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
        ).statusLabel,
        '下载中',
      );

      expect(
        DownloadTask(
          requestId: 'req_3',
          bvid: 'BV123456',
          title: 'Test',
          quality: '',
          format: 'video',
          status: DownloadStatus.paused,
          createdAt: DateTime.now(),
        ).statusLabel,
        '已暂停',
      );

      expect(
        DownloadTask(
          requestId: 'req_4',
          bvid: 'BV123456',
          title: 'Test',
          quality: '',
          format: 'video',
          status: DownloadStatus.completed,
          createdAt: DateTime.now(),
        ).statusLabel,
        '已完成',
      );

      expect(
        DownloadTask(
          requestId: 'req_5',
          bvid: 'BV123456',
          title: 'Test',
          quality: '',
          format: 'video',
          status: DownloadStatus.failed,
          createdAt: DateTime.now(),
        ).statusLabel,
        '失败',
      );
    });

    test('should copyWith create new instance with updated fields', () {
      final now = DateTime.now();
      final original = DownloadTask(
        requestId: 'req_1',
        bvid: 'BV123456',
        title: 'Original Title',
        quality: '720P',
        format: 'video',
        status: DownloadStatus.waiting,
        createdAt: now,
      );

      final copied = original.copyWith(
        title: 'New Title',
        status: DownloadStatus.completed,
        completedAt: DateTime.now(),
      );

      expect(copied.requestId, original.requestId);
      expect(copied.bvid, original.bvid);
      expect(copied.title, 'New Title');
      expect(copied.quality, '720P');
      expect(copied.status, DownloadStatus.completed);
      expect(copied.completedAt, isNotNull);
      expect(original.title, 'Original Title');
      expect(original.status, DownloadStatus.waiting);
    });

    test('should compare tasks by requestId', () {
      final now = DateTime.now();
      final task1 = DownloadTask(
        requestId: 'req_1',
        bvid: 'BV123456',
        title: 'Title 1',
        quality: '',
        format: 'video',
        status: DownloadStatus.waiting,
        createdAt: now,
      );
      final task2 = DownloadTask(
        requestId: 'req_1',
        bvid: 'BV789012',
        title: 'Title 2',
        quality: '',
        format: 'audio',
        status: DownloadStatus.completed,
        createdAt: now,
      );
      final task3 = DownloadTask(
        requestId: 'req_2',
        bvid: 'BV123456',
        title: 'Title 1',
        quality: '',
        format: 'video',
        status: DownloadStatus.waiting,
        createdAt: now,
      );

      expect(task1 == task2, true);
      expect(task1 == task3, false);
      expect(task1.hashCode, task2.hashCode);
    });

    test('should keep batch tasks distinct by Seal task id', () {
      final now = DateTime.now();
      final task1 = DownloadTask(
        requestId: 'request-1',
        taskId: 'task-1',
        bvid: 'BV1',
        title: 'P1',
        quality: '1080p',
        format: 'video',
        status: DownloadStatus.downloading,
        createdAt: now,
      );
      final task2 = task1.copyWith(taskId: 'task-2', title: 'P2');

      expect(task1.identity, 'task-1');
      expect(task2.identity, 'task-2');
      expect(task1 == task2, false);
    });

    test('should round-trip persisted task metadata', () {
      final original = DownloadTask(
        requestId: 'request-1',
        taskId: 'task-1',
        bvid: 'BV1',
        title: 'Title',
        quality: '1080p',
        format: 'video',
        status: DownloadStatus.completed,
        progress: 1,
        downloadedBytes: 1024,
        totalBytes: 1024,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        completedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        contentUri: 'content://seal/task-1',
        source: 'https://www.bilibili.com/video/BV1',
      );

      final restored = DownloadTask.fromJson(original.toJson());
      expect(restored.identity, 'task-1');
      expect(restored.status, DownloadStatus.completed);
      expect(restored.quality, '1080p');
      expect(restored.downloadedBytes, 1024);
      expect(restored.contentUri, original.contentUri);
    });
  });
}
