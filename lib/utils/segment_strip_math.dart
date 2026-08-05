/// Pure Dart math for stripping marked ad/SponsorBlock segments.
///
/// No Flutter / HTTP deps — unit-tested in isolation.
library;

/// Half-open-friendly closed range in milliseconds: `[startMs, endMs)`.
/// Display uses inclusive end; duration is `endMs - startMs`.
final class TimedRange {
  const TimedRange(this.startMs, this.endMs);

  final int startMs;
  final int endMs;

  int get durationMs => endMs - startMs;

  bool get isValid => endMs > startMs && startMs >= 0;

  TimedRange clampTo(int durationMs) {
    final start = startMs.clamp(0, durationMs);
    final end = endMs.clamp(0, durationMs);
    return TimedRange(start, end);
  }

  @override
  bool operator ==(Object other) =>
      other is TimedRange && other.startMs == startMs && other.endMs == endMs;

  @override
  int get hashCode => Object.hash(startMs, endMs);

  @override
  String toString() => 'TimedRange($startMs-$endMs)';
}

/// Raw segment input for strip planning (category is [SegmentType.name]).
final class SegmentStripInput {
  const SegmentStripInput({
    required this.category,
    required this.startMs,
    required this.endMs,
    this.uuid,
    this.source = 'sponsorblock',
  });

  final String category;
  final int startMs;
  final int endMs;
  final String? uuid;
  final String source;

  int get durationMs => endMs - startMs;

  TimedRange get range => TimedRange(startMs, endMs);
}

enum SegmentStripFailure {
  /// duration unknown / non-positive — cannot invert keep ranges
  durationUnknown,

  /// filtered removals cover the entire video; nothing left to keep
  fullCover,

  /// after invert + min-keep filter, no keep ranges remain
  emptyKeep,
}

/// Outcome of [SegmentStripMath.plan].
final class SegmentStripPlan {
  const SegmentStripPlan({
    required this.removed,
    required this.keepRanges,
    required this.originalDurationMs,
    required this.estimatedResultMs,
    this.failure,
  });

  /// Filtered individual segments for the removal report (not merged).
  final List<SegmentStripInput> removed;

  /// Merged inverted keep ranges for Seal `--download-sections`.
  final List<TimedRange> keepRanges;

  final int originalDurationMs;
  final int estimatedResultMs;
  final SegmentStripFailure? failure;

  bool get hasRemovals => removed.isNotEmpty;
  bool get shouldStrip =>
      failure == null && hasRemovals && keepRanges.isNotEmpty;
  bool get isFullCover => failure == SegmentStripFailure.fullCover;

  /// JSON array of `{start,end}` in **seconds** (fractional OK) for protocol.
  List<Map<String, double>> keepSectionsSeconds() {
    return [
      for (final r in keepRanges)
        <String, double>{
          'start': r.startMs / 1000.0,
          'end': r.endMs / 1000.0,
        },
    ];
  }
}

/// Filter / merge / invert helpers for ad-segment stripping.
abstract final class SegmentStripMath {
  /// Default merge gap: adjacent removals within this are merged.
  static const int defaultGapMs = 200;

  /// Drop keep holes shorter than this after invert.
  static const int defaultMinKeepMs = 500;

  /// Full-video label used by SB (`segment == (0,0)`).
  static bool isFullVideoLabel(int startMs, int endMs) =>
      startMs == 0 && endMs == 0;

  /// Filter by category set, min length, validity, and drop (0,0) labels.
  ///
  /// [categories] uses [SegmentType.name] strings.
  /// [poi_highlight] is never a default strip target; callers exclude it.
  static List<SegmentStripInput> filterSegments(
    Iterable<SegmentStripInput> segments, {
    required Set<String> categories,
    required int minMs,
  }) {
    if (categories.isEmpty) return const [];
    final out = <SegmentStripInput>[];
    for (final s in segments) {
      if (!categories.contains(s.category)) continue;
      if (isFullVideoLabel(s.startMs, s.endMs)) continue;
      if (s.endMs <= s.startMs) continue;
      if (s.startMs < 0 || s.endMs < 0) continue;
      if (s.durationMs < minMs) continue;
      out.add(s);
    }
    out.sort((a, b) => a.startMs.compareTo(b.startMs));
    return out;
  }

  /// Sort and merge overlapping / adjacent ranges within [gapMs].
  static List<TimedRange> mergeRanges(
    Iterable<TimedRange> ranges, {
    int gapMs = defaultGapMs,
  }) {
    final sorted = ranges.where((r) => r.isValid).toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    if (sorted.isEmpty) return const [];

    final merged = <TimedRange>[];
    var curStart = sorted.first.startMs;
    var curEnd = sorted.first.endMs;
    for (var i = 1; i < sorted.length; i++) {
      final r = sorted[i];
      if (r.startMs <= curEnd + gapMs) {
        if (r.endMs > curEnd) curEnd = r.endMs;
      } else {
        merged.add(TimedRange(curStart, curEnd));
        curStart = r.startMs;
        curEnd = r.endMs;
      }
    }
    merged.add(TimedRange(curStart, curEnd));
    return merged;
  }

  /// Invert [removed] ranges over `[0, durationMs]` into keep ranges.
  ///
  /// Drops keep pieces shorter than [minKeepMs].
  static List<TimedRange> invertToKeep(
    Iterable<TimedRange> removed, {
    required int durationMs,
    int minKeepMs = defaultMinKeepMs,
    int gapMs = defaultGapMs,
  }) {
    if (durationMs <= 0) return const [];
    final merged = mergeRanges(
      removed.map((r) => r.clampTo(durationMs)),
      gapMs: gapMs,
    );
    if (merged.isEmpty) {
      return durationMs >= minKeepMs
          ? [TimedRange(0, durationMs)]
          : const [];
    }

    final keep = <TimedRange>[];
    var cursor = 0;
    for (final r in merged) {
      if (r.startMs > cursor) {
        final piece = TimedRange(cursor, r.startMs);
        if (piece.durationMs >= minKeepMs) keep.add(piece);
      }
      if (r.endMs > cursor) cursor = r.endMs;
    }
    if (cursor < durationMs) {
      final piece = TimedRange(cursor, durationMs);
      if (piece.durationMs >= minKeepMs) keep.add(piece);
    }
    return keep;
  }

  /// Full plan: filter → report list → merge → invert → validate.
  static SegmentStripPlan plan({
    required Iterable<SegmentStripInput> segments,
    required int durationMs,
    required Set<String> categories,
    required int minMs,
    int gapMs = defaultGapMs,
    int minKeepMs = defaultMinKeepMs,
  }) {
    if (durationMs <= 0) {
      return const SegmentStripPlan(
        removed: [],
        keepRanges: [],
        originalDurationMs: 0,
        estimatedResultMs: 0,
        failure: SegmentStripFailure.durationUnknown,
      );
    }

    final filtered = filterSegments(
      segments,
      categories: categories,
      minMs: minMs,
    );
    if (filtered.isEmpty) {
      return SegmentStripPlan(
        removed: const [],
        keepRanges: [TimedRange(0, durationMs)],
        originalDurationMs: durationMs,
        estimatedResultMs: durationMs,
      );
    }

    final merged = mergeRanges(
      filtered.map((s) => s.range.clampTo(durationMs)),
      gapMs: gapMs,
    );

    // Full cover: single merged range spans entire duration.
    if (merged.length == 1 &&
        merged.first.startMs <= 0 &&
        merged.first.endMs >= durationMs) {
      return SegmentStripPlan(
        removed: filtered,
        keepRanges: const [],
        originalDurationMs: durationMs,
        estimatedResultMs: 0,
        failure: SegmentStripFailure.fullCover,
      );
    }

    final keep = invertToKeep(
      merged,
      durationMs: durationMs,
      minKeepMs: minKeepMs,
      gapMs: gapMs,
    );
    if (keep.isEmpty) {
      return SegmentStripPlan(
        removed: filtered,
        keepRanges: const [],
        originalDurationMs: durationMs,
        estimatedResultMs: 0,
        failure: SegmentStripFailure.emptyKeep,
      );
    }

    final estimated = keep.fold<int>(0, (sum, r) => sum + r.durationMs);
    return SegmentStripPlan(
      removed: filtered,
      keepRanges: keep,
      originalDurationMs: durationMs,
      estimatedResultMs: estimated,
    );
  }
}
