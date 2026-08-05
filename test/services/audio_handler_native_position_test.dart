import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/services/audio_handler.dart';

void main() {
  const pushInterval = Duration(seconds: 3);
  const jumpThreshold = Duration(seconds: 2);

  group('VideoPlayerServiceHandler.shouldPushNativePosition', () {
    test('paused always pushes (no SystemUI interpolation)', () {
      expect(
        VideoPlayerServiceHandler.shouldPushNativePosition(
          playing: false,
          deltaFromPrevious: const Duration(milliseconds: 100),
          deltaFromLastPushed: const Duration(milliseconds: 100),
          sinceLastPush: const Duration(milliseconds: 100),
          pushInterval: pushInterval,
          jumpThreshold: jumpThreshold,
        ),
        isTrue,
      );
    });

    test('first push (sinceLastPush null) always pushes', () {
      expect(
        VideoPlayerServiceHandler.shouldPushNativePosition(
          playing: true,
          deltaFromPrevious: const Duration(milliseconds: 100),
          deltaFromLastPushed: const Duration(milliseconds: 100),
          sinceLastPush: null,
          pushInterval: pushInterval,
          jumpThreshold: jumpThreshold,
        ),
        isTrue,
      );
    });

    test('playing small delta within interval is throttled', () {
      expect(
        VideoPlayerServiceHandler.shouldPushNativePosition(
          playing: true,
          deltaFromPrevious: const Duration(milliseconds: 500),
          deltaFromLastPushed: const Duration(milliseconds: 500),
          sinceLastPush: const Duration(milliseconds: 500),
          pushInterval: pushInterval,
          jumpThreshold: jumpThreshold,
        ),
        isFalse,
      );
    });

    test('playing past interval pushes', () {
      expect(
        VideoPlayerServiceHandler.shouldPushNativePosition(
          playing: true,
          deltaFromPrevious: const Duration(milliseconds: 1200),
          deltaFromLastPushed: const Duration(milliseconds: 3200),
          sinceLastPush: const Duration(milliseconds: 3200),
          pushInterval: pushInterval,
          jumpThreshold: jumpThreshold,
        ),
        isTrue,
      );
    });

    test('playing with a jump >= threshold pushes immediately', () {
      expect(
        VideoPlayerServiceHandler.shouldPushNativePosition(
          playing: true,
          deltaFromPrevious: const Duration(seconds: 3),
          deltaFromLastPushed: const Duration(milliseconds: 100),
          sinceLastPush: const Duration(milliseconds: 100),
          pushInterval: pushInterval,
          jumpThreshold: jumpThreshold,
        ),
        isTrue,
      );
    });

    test('playing backward jump pushes immediately', () {
      expect(
        VideoPlayerServiceHandler.shouldPushNativePosition(
          playing: true,
          deltaFromPrevious: const Duration(seconds: -5),
          deltaFromLastPushed: const Duration(seconds: -5),
          sinceLastPush: const Duration(milliseconds: 100),
          pushInterval: pushInterval,
          jumpThreshold: jumpThreshold,
        ),
        isTrue,
      );
    });

    test('exactly at interval boundary pushes (>= is inclusive)', () {
      expect(
        VideoPlayerServiceHandler.shouldPushNativePosition(
          playing: true,
          deltaFromPrevious: const Duration(milliseconds: 800),
          deltaFromLastPushed: const Duration(milliseconds: 800),
          sinceLastPush: const Duration(seconds: 3),
          pushInterval: pushInterval,
          jumpThreshold: jumpThreshold,
        ),
        isTrue,
      );
    });

    test('playing mid-interval small delta is still throttled', () {
      // Both deltas must stay strictly below jumpThreshold (2s) and
      // sinceLastPush must stay below pushInterval (3s).
      expect(
        VideoPlayerServiceHandler.shouldPushNativePosition(
          playing: true,
          deltaFromPrevious: const Duration(seconds: 1),
          deltaFromLastPushed: const Duration(milliseconds: 1900),
          sinceLastPush: const Duration(seconds: 2),
          pushInterval: pushInterval,
          jumpThreshold: jumpThreshold,
        ),
        isFalse,
      );
    });
  });

  group('VideoPlayerServiceHandler.shouldAcceptPositionAfterSeek', () {
    const settle = Duration(seconds: 2);

    test('accepts position near seek target', () {
      expect(
        VideoPlayerServiceHandler.shouldAcceptPositionAfterSeek(
          position: const Duration(seconds: 61),
          seekTarget: const Duration(seconds: 60),
          settleThreshold: settle,
          graceExpired: false,
        ),
        isTrue,
      );
    });

    test('drops stale position far from seek target within grace', () {
      expect(
        VideoPlayerServiceHandler.shouldAcceptPositionAfterSeek(
          position: const Duration(seconds: 10),
          seekTarget: const Duration(seconds: 60),
          settleThreshold: settle,
          graceExpired: false,
        ),
        isFalse,
      );
    });

    test('accepts any position once grace expires', () {
      expect(
        VideoPlayerServiceHandler.shouldAcceptPositionAfterSeek(
          position: const Duration(seconds: 10),
          seekTarget: const Duration(seconds: 60),
          settleThreshold: settle,
          graceExpired: true,
        ),
        isTrue,
      );
    });
  });
}
