import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/download/download_task.dart';
import 'package:pili_plus/services/download_task_repository.dart';

void main() {
  test('persists a bounded typed history and skips malformed rows', () async {
    final storage = _MemoryDownloadTaskStorage();
    final repository = DownloadTaskRepository(storage: storage, maxTasks: 2);
    final tasks = <DownloadTask>[
      _task('active', DownloadStatus.downloading, createdAtMs: 1),
      _task('completed-new', DownloadStatus.completed, createdAtMs: 3),
      _task('failed-old', DownloadStatus.failed, createdAtMs: 2),
    ];

    await repository.replaceAll(tasks);
    final payload = storage.value as Map;
    (payload['tasks'] as List).add(<String, Object?>{'broken': true});

    final restored = await repository.load();
    expect(restored.length, 2);
    expect(restored.map((task) => task.identity), <String>[
      'active',
      'completed-new',
    ]);
  });

  test('deduplicates by task identity instead of caller request id', () async {
    final storage = _MemoryDownloadTaskStorage();
    final repository = DownloadTaskRepository(storage: storage);
    final first = _task('task-1', DownloadStatus.waiting, requestId: 'batch');
    final second = _task('task-2', DownloadStatus.waiting, requestId: 'batch');

    await repository.replaceAll(<DownloadTask>[first, second]);
    final restored = await repository.load();

    expect(restored.map((task) => task.identity).toSet(), {
      'task-1',
      'task-2',
    });
  });
}

DownloadTask _task(
  String taskId,
  DownloadStatus status, {
  String? requestId,
  int createdAtMs = 1,
}) {
  return DownloadTask(
    requestId: requestId ?? taskId,
    taskId: taskId,
    bvid: '',
    title: taskId,
    quality: '',
    format: 'video',
    status: status,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    completedAt: status.isTerminal
        ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
        : null,
  );
}

final class _MemoryDownloadTaskStorage implements DownloadTaskStorage {
  Object? value;

  @override
  Future<void> delete(String key) async {
    value = null;
  }

  @override
  Object? read(String key) => value;

  @override
  Future<void> write(String key, Object? value) async {
    this.value = value;
  }
}
