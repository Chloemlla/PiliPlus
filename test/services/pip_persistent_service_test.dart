import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/services/pip_persistent_service.dart';
import 'package:pili_plus/utils/storage_key.dart';

void main() {
  group('PipPersistentService', () {
    late _MemoryPipStateStore store;
    late DateTime now;
    late PipPersistentService service;

    setUp(() {
      store = _MemoryPipStateStore();
      now = DateTime(2026, 7, 31, 12);
      service = PipPersistentService(store: store, clock: () => now);
    });

    test(
      'saves one coherent state and restores only the matching video',
      () async {
        await service.savePipState(
          bvid: 'BV1pip',
          cid: 100,
          positionMs: 12345,
          title: 'PiP video',
          cover: 'https://example.com/cover.jpg',
        );

        expect(service.hasPipState, isTrue);
        expect(
          service.restorePositionFor(bvid: 'BV1pip', cid: 100),
          const Duration(milliseconds: 12345),
        );
        expect(service.restorePositionFor(bvid: 'BV1other', cid: 100), isNull);
        expect(service.state?.title, 'PiP video');
      },
    );

    test(
      'clearIfMatches never clears a newer or unrelated playback state',
      () async {
        await service.savePipState(
          bvid: 'BV1pip',
          cid: 100,
          positionMs: 1000,
        );
        await service.clearIfMatches(bvid: 'BV1other', cid: 100);
        expect(service.hasPipState, isTrue);

        await service.clearIfMatches(bvid: 'BV1pip', cid: 100);
        expect(service.hasPipState, isFalse);
        expect(store.values, isEmpty);
      },
    );

    test(
      'expired state is not restored after the bounded recovery window',
      () async {
        await service.savePipState(
          bvid: 'BV1pip',
          cid: 100,
          positionMs: 1000,
        );
        now = now.add(const Duration(hours: 13));

        expect(service.restorePositionFor(bvid: 'BV1pip', cid: 100), isNull);
        expect(service.hasPipState, isFalse);
      },
    );

    test('reads legacy split keys and clears them after restoration', () async {
      store.values.addAll({
        LocalCacheKey.pipVideoBvid: 'BV1legacy',
        LocalCacheKey.pipVideoCid: 88,
        LocalCacheKey.pipVideoPosition: 9000,
        LocalCacheKey.pipVideoTitle: 'Legacy',
      });

      expect(
        service.restorePositionFor(bvid: 'BV1legacy', cid: 88),
        const Duration(milliseconds: 9000),
      );
      await service.clearPipState();
      expect(store.values, isEmpty);
    });
  });
}

final class _MemoryPipStateStore implements PipStateStore {
  final Map<String, Object?> values = {};

  @override
  Object? read(String key) => values[key];

  @override
  Future<void> write(String key, Object? value) {
    values[key] = value;
    return Future<void>.value();
  }

  @override
  Future<void> delete(String key) {
    values.remove(key);
    return Future<void>.value();
  }
}
