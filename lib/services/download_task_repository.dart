import 'package:pili_plus/models/download/download_task.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

abstract interface class DownloadTaskStorage {
  Object? read(String key);

  Future<void> write(String key, Object? value);

  Future<void> delete(String key);
}

/// Typed, bounded persistence boundary for Seal download manager history.
final class DownloadTaskRepository {
  DownloadTaskRepository({DownloadTaskStorage? storage, this.maxTasks = 200})
    : _storage = storage ?? const _LocalCacheDownloadTaskStorage();

  static const schemaVersion = 1;

  final DownloadTaskStorage _storage;
  final int maxTasks;
  Future<void> _writeTail = Future<void>.value();

  Future<List<DownloadTask>> load() async {
    final raw = _storage.read(LocalCacheKey.sealDownloadTaskHistory);
    final rawTasks = switch (raw) {
      {'tasks': final List tasks} => tasks,
      final List tasks => tasks,
      _ => const <Object?>[],
    };
    final tasks = <DownloadTask>[];
    final identities = <String>{};
    for (final item in rawTasks) {
      if (item is! Map) continue;
      try {
        final task = DownloadTask.fromJson(Map<String, dynamic>.from(item));
        if (identities.add(task.identity)) tasks.add(task);
      } on Object {
        // A malformed history row must not prevent recovery of later rows.
      }
    }
    return _bounded(tasks);
  }

  Future<void> replaceAll(Iterable<DownloadTask> tasks) {
    final snapshot = _bounded(tasks).map((task) => task.toJson()).toList();
    final operation = _writeTail
        .catchError((Object _) {})
        .then<void>(
          (_) => _storage.write(LocalCacheKey.sealDownloadTaskHistory, {
            'version': schemaVersion,
            'tasks': snapshot,
          }),
        );
    _writeTail = operation;
    return operation;
  }

  Future<void> clear() {
    final operation = _writeTail
        .catchError((Object _) {})
        .then<void>(
          (_) => _storage.delete(LocalCacheKey.sealDownloadTaskHistory),
        );
    _writeTail = operation;
    return operation;
  }

  List<DownloadTask> _bounded(Iterable<DownloadTask> source) {
    if (maxTasks <= 0) return const <DownloadTask>[];
    final unique = <String, DownloadTask>{};
    for (final task in source) {
      unique.putIfAbsent(task.identity, () => task);
    }
    final active = <DownloadTask>[];
    final history = <DownloadTask>[];
    for (final task in unique.values) {
      (task.status.isTerminal ? history : active).add(task);
    }
    active.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    history.sort((a, b) {
      final aTime = a.completedAt ?? a.createdAt;
      final bTime = b.completedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return List<DownloadTask>.unmodifiable(
      <DownloadTask>[...active, ...history].take(maxTasks),
    );
  }
}

final class _LocalCacheDownloadTaskStorage implements DownloadTaskStorage {
  const _LocalCacheDownloadTaskStorage();

  @override
  Object? read(String key) => GStorage.localCache.get(key);

  @override
  Future<void> write(String key, Object? value) =>
      GStorage.localCache.put(key, value);

  @override
  Future<void> delete(String key) => GStorage.localCache.delete(key);
}
