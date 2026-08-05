import 'package:flutter/material.dart';

/// Available highlight colors for danmaku.
enum HighlightColor {
  red(Color(0xFFFF4444)),
  orange(Color(0xFFFF8800)),
  yellow(Color(0xFFFFFF00)),
  green(Color(0xFF44FF44)),
  blue(Color(0xFF4488FF)),
  purple(Color(0xFFAA44FF)),
  pink(Color(0xFFFF44AA)),
  white(Color(0xFFFFFFFF));

  const HighlightColor(this.value);
  final Color value;

  String get label {
    return switch (this) {
      red => '红色',
      orange => '橙色',
      yellow => '黄色',
      green => '绿色',
      blue => '蓝色',
      purple => '紫色',
      pink => '粉色',
      white => '白色',
    };
  }
}

/// A danmaku keyword highlight rule.
class DanmakuHighlightRule {
  const DanmakuHighlightRule({
    required this.id,
    required this.keyword,
    this.isRegex = false,
    this.color = HighlightColor.yellow,
    this.priority = 0,
    this.enabled = true,
    required this.createdAt,
  });

  final String id;
  final String keyword;
  final bool isRegex;
  final HighlightColor color;
  final int priority;
  final bool enabled;
  final DateTime createdAt;

  DanmakuHighlightRule copyWith({
    String? id,
    String? keyword,
    bool? isRegex,
    HighlightColor? color,
    int? priority,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return DanmakuHighlightRule(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      isRegex: isRegex ?? this.isRegex,
      color: color ?? this.color,
      priority: priority ?? this.priority,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'keyword': keyword,
    'isRegex': isRegex,
    'color': color.index,
    'priority': priority,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DanmakuHighlightRule.fromJson(Map<String, dynamic> json) {
    return DanmakuHighlightRule(
      id: json['id'] as String,
      keyword: json['keyword'] as String,
      isRegex: json['isRegex'] as bool? ?? false,
      color: HighlightColor.values[json['color'] as int? ?? 2],
      priority: json['priority'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DanmakuHighlightRule && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Quick rules that can be added with one tap.
class DanmakuQuickRule {
  const DanmakuQuickRule({
    required this.keyword,
    required this.color,
  });

  final String keyword;
  final HighlightColor color;
}

const danmakuQuickRules = <DanmakuQuickRule>[
  DanmakuQuickRule(keyword: '主播', color: HighlightColor.yellow),
  DanmakuQuickRule(keyword: '谢谢', color: HighlightColor.yellow),
  DanmakuQuickRule(keyword: '厉害', color: HighlightColor.yellow),
  DanmakuQuickRule(keyword: '注意', color: HighlightColor.yellow),
];
