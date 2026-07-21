import 'package:pili_plus/models/common/sponsor_block/segment_type.dart';
import 'package:pili_plus/utils/segment_strip_math.dart';

/// One removed marked segment for the detailed strip report (PiliPlus-owned).
final class StripRemovalItem {
  const StripRemovalItem({
    required this.type,
    required this.startMs,
    required this.endMs,
    this.uuid,
    this.source = 'sponsorblock',
  });

  factory StripRemovalItem.fromInput(SegmentStripInput input) {
    SegmentType type;
    try {
      type = SegmentType.values.byName(input.category);
    } catch (_) {
      type = SegmentType.sponsor;
    }
    return StripRemovalItem(
      type: type,
      startMs: input.startMs,
      endMs: input.endMs,
      uuid: input.uuid,
      source: input.source,
    );
  }

  final SegmentType type;
  final int startMs;
  final int endMs;
  final String? uuid;
  final String source;

  int get durationMs => endMs - startMs;

  String get typeTitle => type.title;
  String get shortTitle => type.shortTitle;

  String get timeRangeLabel {
    return '${_fmtMs(startMs)}–${_fmtMs(endMs)} (${_fmtDuration(durationMs)})';
  }

  static String _fmtMs(int ms) {
    final totalSec = (ms / 1000).floor();
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  static String _fmtDuration(int ms) {
    final totalSec = (ms / 1000).round().clamp(0, 1 << 30);
    if (totalSec < 60) return '${totalSec}s';
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    if (m < 60) return s == 0 ? '${m}m' : '${m}m${s}s';
    final h = m ~/ 60;
    final rm = m % 60;
    return rm == 0 ? '${h}h' : '${h}h${rm}m';
  }
}

/// Full strip report for a single bvid+cid (or one multi-P entry).
final class StripRemovalReport {
  const StripRemovalReport({
    required this.bvid,
    required this.cid,
    required this.removed,
    required this.keepRanges,
    required this.originalDurationMs,
    required this.estimatedResultMs,
    this.pageLabel,
  });

  factory StripRemovalReport.fromPlan({
    required String bvid,
    required int cid,
    required SegmentStripPlan plan,
    String? pageLabel,
  }) {
    return StripRemovalReport(
      bvid: bvid,
      cid: cid,
      removed: [for (final s in plan.removed) StripRemovalItem.fromInput(s)],
      keepRanges: plan.keepRanges,
      originalDurationMs: plan.originalDurationMs,
      estimatedResultMs: plan.estimatedResultMs,
      pageLabel: pageLabel,
    );
  }

  final String bvid;
  final int cid;
  final List<StripRemovalItem> removed;
  final List<TimedRange> keepRanges;
  final int originalDurationMs;
  final int estimatedResultMs;
  final String? pageLabel;

  int get removedCount => removed.length;

  int get removedDurationMs =>
      removed.fold<int>(0, (sum, e) => sum + e.durationMs);

  String get summaryLabel {
    final n = removedCount;
    final dur = StripRemovalItem._fmtDuration(removedDurationMs);
    final est = StripRemovalItem._fmtDuration(estimatedResultMs);
    final page = pageLabel != null ? ' · $pageLabel' : '';
    return '已去除 $n 段（$dur），预计成品 $est$page';
  }

  /// Protocol payload: keep ranges as seconds JSON list.
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
