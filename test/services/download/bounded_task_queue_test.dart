import 'package:pili_plus/services/download/bounded_task_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runBoundedTasks', () {
    test('keeps task concurrency under the configured limit', () async {
      var running = 0;
      var maxRunning = 0;

      final result = await runBoundedTasks<int>(12, (index) async {
        running++;
        maxRunning = maxRunning < running ? running : maxRunning;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        running--;
        return index;
      }, concurrency: 3);

      expect(result, List<int>.generate(12, (index) => index));
      expect(maxRunning, lessThanOrEqualTo(3));
    });

    test('fails fast without scheduling every pending task', () async {
      final started = <int>[];

      await expectLater(
        runBoundedTasks<int>(8, (index) async {
          started.add(index);
          if (index == 1) {
            throw StateError('segment failed');
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
          return index;
        }, concurrency: 2),
        throwsStateError,
      );

      expect(started, [0, 1]);
    });
  });
}
