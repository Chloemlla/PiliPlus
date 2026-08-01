import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/services/download_manager_service.dart';
import 'package:pili_plus/services/download_task_repository.dart';

void main() {
  test('history restore failure is handled without failing startup', () async {
    final operations = <String>[];
    final service = DownloadManagerService(
      repository: DownloadTaskRepository(
        storage: const _ThrowingDownloadTaskStorage(),
      ),
      errorReporter:
          (
            Object error,
            StackTrace stackTrace, {
            required String operation,
          }) {
            operations.add(operation);
          },
    );

    await expectLater(service.initialize(), completes);

    expect(service.tasks, isEmpty);
    expect(operations, <String>['DownloadManagerService.restoreHistory']);
  });
}

final class _ThrowingDownloadTaskStorage implements DownloadTaskStorage {
  const _ThrowingDownloadTaskStorage();

  @override
  Future<void> delete(String key) async {}

  @override
  Object? read(String key) => throw StateError('history storage unavailable');

  @override
  Future<void> write(String key, Object? value) async {}
}
