import 'package:hive_ce/hive.dart';

part 'video_bookmark_adapter.dart';

@HiveType(typeId: 100)
class VideoBookmark extends HiveObject {
  static const int maxIdLength = 128;
  static const int maxBvidLength = 32;
  static const int maxVideoTitleLength = 512;
  static const int maxNameLength = 256;
  static const int maxNoteLength = 4096;

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bvid;

  @HiveField(2)
  final String videoTitle;

  @HiveField(3)
  final int? authorMid;

  @HiveField(4)
  final int timestampSeconds;

  @HiveField(5)
  final String name;

  @HiveField(6)
  final String? note;

  @HiveField(7)
  final DateTime createdAt;

  VideoBookmark({
    required this.id,
    required this.bvid,
    required this.videoTitle,
    this.authorMid,
    required this.timestampSeconds,
    required this.name,
    this.note,
    required this.createdAt,
  });

  String get formattedTimestamp => formatTimestamp(timestampSeconds);

  static String formatTimestamp(int timestampSeconds) {
    final safeSeconds = timestampSeconds < 0 ? 0 : timestampSeconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final seconds = safeSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  VideoBookmark copyWithDetails({
    required String name,
    String? note,
  }) {
    return VideoBookmark(
      id: id,
      bvid: bvid,
      videoTitle: videoTitle,
      authorMid: authorMid,
      timestampSeconds: timestampSeconds,
      name: name,
      note: note,
      createdAt: createdAt,
    );
  }

  VideoBookmark copyWith({
    String? id,
    String? bvid,
    String? videoTitle,
    int? authorMid,
    int? timestampSeconds,
    String? name,
    String? note,
    DateTime? createdAt,
  }) {
    return VideoBookmark(
      id: id ?? this.id,
      bvid: bvid ?? this.bvid,
      videoTitle: videoTitle ?? this.videoTitle,
      authorMid: authorMid ?? this.authorMid,
      timestampSeconds: timestampSeconds ?? this.timestampSeconds,
      name: name ?? this.name,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bvid': bvid,
      'videoTitle': videoTitle,
      'authorMid': authorMid,
      'timestampSeconds': timestampSeconds,
      'name': name,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VideoBookmark.fromJson(Map<String, dynamic> json) {
    final timestampSeconds = _requiredInt(json, 'timestampSeconds');
    if (timestampSeconds < 0) {
      throw const FormatException('timestampSeconds 不能为负数');
    }
    final authorMid = _optionalInt(json, 'authorMid');
    if (authorMid != null && authorMid <= 0) {
      throw const FormatException('authorMid 必须为正整数');
    }
    final createdAtValue = _requiredString(json, 'createdAt');
    final createdAt = DateTime.tryParse(createdAtValue);
    if (createdAt == null) {
      throw const FormatException('createdAt 不是有效的日期时间');
    }

    return VideoBookmark(
      id: _requiredString(json, 'id', maxLength: maxIdLength),
      bvid: _requiredString(json, 'bvid', maxLength: maxBvidLength),
      videoTitle: _requiredString(
        json,
        'videoTitle',
        maxLength: maxVideoTitleLength,
      ),
      authorMid: authorMid,
      timestampSeconds: timestampSeconds,
      name: _requiredString(json, 'name', maxLength: maxNameLength),
      note: _optionalString(json, 'note', maxLength: maxNoteLength),
      createdAt: createdAt,
    );
  }

  static String _requiredString(
    Map<String, dynamic> json,
    String key, {
    int? maxLength,
  }) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key 缺失或格式无效');
    }
    final normalized = value.trim();
    if (maxLength != null && normalized.length > maxLength) {
      throw FormatException('$key 过长');
    }
    return normalized;
  }

  static String? _optionalString(
    Map<String, dynamic> json,
    String key, {
    int? maxLength,
  }) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('$key 格式无效');
    }
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    if (maxLength != null && normalized.length > maxLength) {
      throw FormatException('$key 过长');
    }
    return normalized;
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw FormatException('$key 缺失或格式无效');
  }

  static int? _optionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is int) return value;
    throw FormatException('$key 格式无效');
  }
}
