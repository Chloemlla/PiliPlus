import 'package:hive_ce/hive.dart';

part 'watch_stats_session.g.dart';

@HiveType(typeId: 102)
class WatchStatsSession extends HiveObject {
  @HiveField(0)
  final String bvid;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String authorName;

  @HiveField(3)
  final int authorMid;

  @HiveField(4)
  final int watchedSeconds;

  @HiveField(5)
  final int timestamp;

  @HiveField(6)
  final String date;

  WatchStatsSession({
    required this.bvid,
    required this.title,
    required this.authorName,
    required this.authorMid,
    required this.watchedSeconds,
    required this.timestamp,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'bvid': bvid,
    'title': title,
    'authorName': authorName,
    'authorMid': authorMid,
    'watchedSeconds': watchedSeconds,
    'timestamp': timestamp,
    'date': date,
  };

  factory WatchStatsSession.fromJson(Map<String, dynamic> json) {
    return WatchStatsSession(
      bvid: json['bvid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorMid: (json['authorMid'] as num?)?.toInt() ?? 0,
      watchedSeconds: (json['watchedSeconds'] as num?)?.toInt() ?? 0,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
    );
  }
}
