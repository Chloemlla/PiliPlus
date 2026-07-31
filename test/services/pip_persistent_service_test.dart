import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/services/pip_persistent_service.dart';

void main() {
  group('PipPersistentService', () {
    test('hasPipState returns false initially', () {
      final service = PipPersistentService.instance;
      // Service instance should exist
      expect(service, isNotNull);
      // Initial state should have no PiP state
      expect(service.hasPipState, isFalse);
    });

    test('clearPipState removes stored state', () async {
      final service = PipPersistentService.instance;
      await service.clearPipState();
      expect(service.hasPipState, isFalse);
    });
  });
}
