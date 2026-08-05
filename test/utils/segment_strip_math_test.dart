import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/utils/segment_strip_math.dart';

void main() {
  group('SegmentStripMath.filterSegments', () {
    test('empty input', () {
      final out = SegmentStripMath.filterSegments(
        const [],
        categories: {'sponsor'},
        minMs: 1000,
      );
      expect(out, isEmpty);
    });

    test('drops (0,0) full-video labels', () {
      final out = SegmentStripMath.filterSegments(
        const [
          SegmentStripInput(category: 'sponsor', startMs: 0, endMs: 0),
          SegmentStripInput(category: 'sponsor', startMs: 1000, endMs: 5000),
        ],
        categories: {'sponsor'},
        minMs: 1000,
      );
      expect(out.length, 1);
      expect(out.first.startMs, 1000);
    });

    test('drops invalid and short ranges', () {
      final out = SegmentStripMath.filterSegments(
        const [
          SegmentStripInput(category: 'sponsor', startMs: 5000, endMs: 1000),
          SegmentStripInput(category: 'sponsor', startMs: 0, endMs: 500),
          SegmentStripInput(category: 'sponsor', startMs: 0, endMs: 2000),
        ],
        categories: {'sponsor'},
        minMs: 1000,
      );
      expect(out.length, 1);
      expect(out.first.endMs, 2000);
    });

    test('category filter excludes poi_highlight when not selected', () {
      final out = SegmentStripMath.filterSegments(
        const [
          SegmentStripInput(
            category: 'poi_highlight',
            startMs: 1000,
            endMs: 2000,
          ),
          SegmentStripInput(category: 'sponsor', startMs: 3000, endMs: 5000),
          SegmentStripInput(category: 'selfpromo', startMs: 6000, endMs: 8000),
        ],
        categories: {'sponsor', 'selfpromo'},
        minMs: 500,
      );
      expect(out.map((e) => e.category).toList(), ['sponsor', 'selfpromo']);
    });

    test('default product categories never include poi by themselves', () {
      const defaults = {'sponsor', 'selfpromo'};
      expect(defaults.contains('poi_highlight'), isFalse);
    });
  });

  group('SegmentStripMath.mergeRanges', () {
    test('overlap merge', () {
      final merged = SegmentStripMath.mergeRanges(const [
        TimedRange(0, 5000),
        TimedRange(3000, 8000),
      ]);
      expect(merged, [const TimedRange(0, 8000)]);
    });

    test('adjacent within gap merges', () {
      final merged = SegmentStripMath.mergeRanges(const [
        TimedRange(0, 1000),
        TimedRange(1100, 2000),
      ], gapMs: 200);
      expect(merged, [const TimedRange(0, 2000)]);
    });

    test('far ranges stay separate', () {
      final merged = SegmentStripMath.mergeRanges(const [
        TimedRange(0, 1000),
        TimedRange(2000, 3000),
      ], gapMs: 200);
      expect(merged, [const TimedRange(0, 1000), const TimedRange(2000, 3000)]);
    });
  });

  group('SegmentStripMath.invertToKeep', () {
    test('empty removed keeps full duration', () {
      final keep = SegmentStripMath.invertToKeep(
        const [],
        durationMs: 10000,
      );
      expect(keep, [const TimedRange(0, 10000)]);
    });

    test('invert multiple holes', () {
      final keep = SegmentStripMath.invertToKeep(
        const [TimedRange(1000, 2000), TimedRange(5000, 6000)],
        durationMs: 10000,
        minKeepMs: 100,
      );
      expect(keep, [
        const TimedRange(0, 1000),
        const TimedRange(2000, 5000),
        const TimedRange(6000, 10000),
      ]);
    });

    test('head and tail removal keeps middle', () {
      final keep = SegmentStripMath.invertToKeep(
        const [TimedRange(0, 1000), TimedRange(9000, 10000)],
        durationMs: 10000,
        minKeepMs: 100,
      );
      expect(keep, [const TimedRange(1000, 9000)]);
    });

    test('drops short keep fragments', () {
      final keep = SegmentStripMath.invertToKeep(
        const [TimedRange(100, 9900)],
        durationMs: 10000,
        minKeepMs: 500,
      );
      // 0-100 and 9900-10000 are shorter than 500
      expect(keep, isEmpty);
    });
  });

  group('SegmentStripMath.plan', () {
    test('no removable segments → keep full, no failure', () {
      final plan = SegmentStripMath.plan(
        segments: const [
          SegmentStripInput(
            category: 'poi_highlight',
            startMs: 1000,
            endMs: 2000,
          ),
        ],
        durationMs: 60000,
        categories: {'sponsor', 'selfpromo'},
        minMs: 1000,
      );
      expect(plan.hasRemovals, isFalse);
      expect(plan.failure, isNull);
      expect(plan.keepRanges, [const TimedRange(0, 60000)]);
      expect(plan.shouldStrip, isFalse);
    });

    test('full cover → fullCover failure', () {
      final plan = SegmentStripMath.plan(
        segments: const [
          SegmentStripInput(category: 'sponsor', startMs: 0, endMs: 60000),
        ],
        durationMs: 60000,
        categories: {'sponsor'},
        minMs: 1000,
      );
      expect(plan.failure, SegmentStripFailure.fullCover);
      expect(plan.shouldStrip, isFalse);
      expect(plan.removed, isNotEmpty);
    });

    test('duration unknown', () {
      final plan = SegmentStripMath.plan(
        segments: const [
          SegmentStripInput(category: 'sponsor', startMs: 0, endMs: 1000),
        ],
        durationMs: 0,
        categories: {'sponsor'},
        minMs: 100,
      );
      expect(plan.failure, SegmentStripFailure.durationUnknown);
    });

    test('happy path with report segments and keep sections seconds', () {
      final plan = SegmentStripMath.plan(
        segments: const [
          SegmentStripInput(
            category: 'sponsor',
            startMs: 10000,
            endMs: 20000,
            uuid: 'u1',
          ),
          SegmentStripInput(
            category: 'selfpromo',
            startMs: 40000,
            endMs: 45000,
            uuid: 'u2',
          ),
        ],
        durationMs: 60000,
        categories: {'sponsor', 'selfpromo'},
        minMs: 1000,
      );
      expect(plan.shouldStrip, isTrue);
      expect(plan.removed.length, 2);
      expect(plan.estimatedResultMs, 60000 - 10000 - 5000);
      final secs = plan.keepSectionsSeconds();
      expect(secs.length, 3);
      expect(secs.first['start'], 0.0);
      expect(secs.first['end'], 10.0);
    });

    test('min length filter applied before merge', () {
      final plan = SegmentStripMath.plan(
        segments: const [
          SegmentStripInput(category: 'sponsor', startMs: 0, endMs: 500),
          SegmentStripInput(category: 'sponsor', startMs: 10000, endMs: 20000),
        ],
        durationMs: 60000,
        categories: {'sponsor'},
        minMs: 1000,
      );
      expect(plan.removed.length, 1);
      expect(plan.removed.first.startMs, 10000);
    });
  });
}
