Future<List<T>> runBoundedTasks<T>(
  int count,
  Future<T> Function(int index) task, {
  required int concurrency,
}) async {
  if (count <= 0) {
    return <T>[];
  }
  if (concurrency <= 0) {
    throw ArgumentError.value(concurrency, 'concurrency', 'must be positive');
  }

  final results = List<T?>.filled(count, null);
  var nextIndex = 0;
  Object? firstError;
  StackTrace? firstStackTrace;
  final workerCount = concurrency < count ? concurrency : count;

  Future<void> worker() async {
    while (firstError == null) {
      final index = nextIndex++;
      if (index >= count) {
        return;
      }
      try {
        results[index] = await task(index);
      } catch (e, s) {
        firstError ??= e;
        firstStackTrace ??= s;
        return;
      }
    }
  }

  await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
  if (firstError case final error?) {
    Error.throwWithStackTrace(error, firstStackTrace!);
  }

  return [for (final result in results) result as T];
}
