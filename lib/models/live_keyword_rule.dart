import 'package:hive_ce/hive.dart';

part 'live_keyword_rule.g.dart';

enum MatchTarget {
  titleOnly,
  areaOnly,
  both,
}

@HiveType(typeId: 101)
class LiveKeywordRule extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int mid;

  @HiveField(2)
  final String upName;

  @HiveField(3)
  final String keyword;

  @HiveField(4)
  final int matchTargetIndex;

  @HiveField(5)
  final bool enabled;

  @HiveField(6)
  final int createdAt;

  @HiveField(7)
  final int lastNotifiedAt;

  LiveKeywordRule({
    required this.id,
    required this.mid,
    required this.upName,
    required this.keyword,
    required this.matchTargetIndex,
    required this.enabled,
    required this.createdAt,
    this.lastNotifiedAt = 0,
  });

  MatchTarget get matchTarget => MatchTarget.values[matchTargetIndex];

  LiveKeywordRule copyWith({
    String? id,
    int? mid,
    String? upName,
    String? keyword,
    int? matchTargetIndex,
    bool? enabled,
    int? createdAt,
    int? lastNotifiedAt,
  }) {
    return LiveKeywordRule(
      id: id ?? this.id,
      mid: mid ?? this.mid,
      upName: upName ?? this.upName,
      keyword: keyword ?? this.keyword,
      matchTargetIndex: matchTargetIndex ?? this.matchTargetIndex,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      lastNotifiedAt: lastNotifiedAt ?? this.lastNotifiedAt,
    );
  }

  /// Check if this rule matches the given stream info
  bool matches({
    required String streamTitle,
    required String areaName,
  }) {
    if (!enabled) return false;

    final keywordLower = keyword.toLowerCase();

    switch (matchTarget) {
      case MatchTarget.titleOnly:
        return streamTitle.toLowerCase().contains(keywordLower);
      case MatchTarget.areaOnly:
        return areaName.toLowerCase().contains(keywordLower);
      case MatchTarget.both:
        return streamTitle.toLowerCase().contains(keywordLower) ||
            areaName.toLowerCase().contains(keywordLower);
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mid': mid,
    'upName': upName,
    'keyword': keyword,
    'matchTarget': matchTarget.name,
    'enabled': enabled,
    'createdAt': createdAt,
    'lastNotifiedAt': lastNotifiedAt,
  };

  factory LiveKeywordRule.fromJson(Map<String, dynamic> json) {
    return LiveKeywordRule(
      id: json['id'] as String,
      mid: json['mid'] as int,
      upName: json['upName'] as String,
      keyword: json['keyword'] as String,
      matchTargetIndex: MatchTarget.values
          .indexWhere((e) => e.name == json['matchTarget']),
      enabled: json['enabled'] as bool,
      createdAt: json['createdAt'] as int,
      lastNotifiedAt: json['lastNotifiedAt'] as int? ?? 0,
    );
  }
}
