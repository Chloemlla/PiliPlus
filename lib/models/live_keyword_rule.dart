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

  @HiveField(8)
  final int accountMid;

  LiveKeywordRule({
    required this.id,
    required this.mid,
    required this.upName,
    required this.keyword,
    required this.matchTargetIndex,
    required this.enabled,
    required this.createdAt,
    this.lastNotifiedAt = 0,
    this.accountMid = 0,
  });

  MatchTarget get matchTarget =>
      matchTargetIndex >= 0 && matchTargetIndex < MatchTarget.values.length
      ? MatchTarget.values[matchTargetIndex]
      : MatchTarget.titleOnly;

  LiveKeywordRule copyWith({
    String? id,
    int? mid,
    String? upName,
    String? keyword,
    int? matchTargetIndex,
    bool? enabled,
    int? createdAt,
    int? lastNotifiedAt,
    int? accountMid,
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
      accountMid: accountMid ?? this.accountMid,
    );
  }

  /// Check if this rule matches the given stream info
  bool matches({
    required String streamTitle,
    required String areaName,
  }) {
    if (!enabled) return false;

    final keywordLower = keyword.trim().toLowerCase();
    if (keywordLower.isEmpty) return false;

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
    'accountMid': accountMid,
  };

  factory LiveKeywordRule.fromJson(Map<String, dynamic> json) {
    final matchTargetIndex = MatchTarget.values.indexWhere(
      (item) => item.name == json['matchTarget'],
    );
    return LiveKeywordRule(
      id: json['id']?.toString() ?? '',
      mid: _readInt(json['mid']),
      upName: json['upName']?.toString() ?? '',
      keyword: json['keyword']?.toString() ?? '',
      matchTargetIndex: matchTargetIndex < 0
          ? MatchTarget.titleOnly.index
          : matchTargetIndex,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      createdAt: _readInt(json['createdAt']),
      lastNotifiedAt: _readInt(json['lastNotifiedAt']),
      accountMid: _readInt(json['accountMid']),
    );
  }

  static int _readInt(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}
