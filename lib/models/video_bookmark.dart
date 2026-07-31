import 'package:hive_ce/hive.dart';

part 'video_bookmark_adapter.dart';

@HiveType(typeId: 100)
class VideoBookmark extends HiveObject {
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
  String name;

  @HiveField(6)
  String? note;

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

  String get formattedTimestamp {
    final hours = timestampSeconds ~/ 3600;
    final minutes = (timestampSeconds % 3600) ~/ 60;
    final seconds = timestampSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
    return VideoBookmark(
      id: json['id'] as String,
      bvid: json['bvid'] as String,
      videoTitle: json['videoTitle'] as String,
      authorMid: json['authorMid'] as int?,
      timestampSeconds: json['timestampSeconds'] as int,
      name: json['name'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
