import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/danmaku/danmaku_highlight_rule.dart';
import 'package:pili_plus/utils/storage.dart';

/// Service that manages danmaku highlight rules and applies them.
class DanmakuHighlightService extends GetxService {
  static const String _boxKey = 'danmakuHighlightRules';
  static const int maxRules = 50;

  /// All highlight rules.
  final rules = <DanmakuHighlightRule>[].obs;

  /// Compiled regex patterns for active rules.
  final _compiledPatterns = <String, RegExp>{};

  /// Non-regex rules indexed by lowercase keyword for O(1) lookup.
  final _keywordIndex = <String, DanmakuHighlightRule>{};

  /// Regex rules to match sequentially.
  final _regexRules = <DanmakuHighlightRule>[];

  @override
  void onInit() {
    super.onInit();
    _loadRules();
  }

  void _loadRules() {
    final raw = GStorage.localCache.get(_boxKey);
    if (raw is List) {
      final loaded = <DanmakuHighlightRule>[];
      for (final item in raw) {
        if (item is Map) {
          try {
            loaded.add(DanmakuHighlightRule.fromJson(
              Map<String, dynamic>.from(item),
            ));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Failed to load highlight rule: $e');
            }
          }
        }
      }
      loaded.sort((a, b) => b.priority.compareTo(a.priority));
      rules.value = loaded;
      _compilePatterns();
    }
  }

  Future<void> _saveRules() async {
    final data = rules.map((r) => r.toJson()).toList();
    await GStorage.localCache.put(_boxKey, data);
    _compilePatterns();
  }

  void _compilePatterns() {
    _compiledPatterns.clear();
    _keywordIndex.clear();
    _regexRules.clear();

    final activeRules = rules.where((r) => r.enabled).toList();
    for (final rule in activeRules) {
      if (rule.isRegex) {
        try {
          _compiledPatterns[rule.id] = RegExp(
            rule.keyword,
            caseSensitive: false,
          );
          _regexRules.add(rule);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Invalid regex pattern: ${rule.keyword}');
          }
        }
      } else {
        _keywordIndex[rule.keyword.toLowerCase()] = rule;
      }
    }
  }

  /// Apply highlights to danmaku text.
  /// Returns the highlight color if matched, null otherwise.
  HighlightColor? applyHighlight(String text) {
    if (rules.isEmpty) return null;

    // O(1) lookup for exact match (case-insensitive)
    final lowerText = text.toLowerCase();
    final exactMatch = _keywordIndex[lowerText];
    if (exactMatch != null) {
      return exactMatch.color;
    }

    // Sequential regex match (O(m) where m = regex rules count, capped at 50)
    for (final rule in _regexRules) {
      try {
        final regex = _compiledPatterns[rule.id];
        if (regex != null && regex.hasMatch(text)) {
          return rule.color;
        }
      } catch (_) {
        // Skip invalid regex
      }
    }

    return null;
  }

  /// Get the highlight rule that matches the text (for glow/border effect).
  DanmakuHighlightRule? getMatchingRule(String text) {
    if (rules.isEmpty) return null;

    final lowerText = text.toLowerCase();
    final exactMatch = _keywordIndex[lowerText];
    if (exactMatch != null) return exactMatch;

    for (final rule in _regexRules) {
      final regex = _compiledPatterns[rule.id];
      if (regex != null && regex.hasMatch(text)) {
        return rule;
      }
    }

    return null;
  }

  /// Add a new rule.
  Future<bool> addRule(DanmakuHighlightRule rule) async {
    if (rules.length >= maxRules) return false;
    if (rule.keyword.trim().isEmpty) return false;

    rules.add(rule);
    rules.sort((a, b) => b.priority.compareTo(a.priority));
    await _saveRules();
    return true;
  }

  /// Update an existing rule.
  Future<void> updateRule(DanmakuHighlightRule rule) async {
    final index = rules.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      rules[index] = rule;
      rules.sort((a, b) => b.priority.compareTo(a.priority));
      await _saveRules();
    }
  }

  /// Delete a rule by id.
  Future<void> deleteRule(String id) async {
    rules.removeWhere((r) => r.id == id);
    await _saveRules();
  }

  /// Toggle rule enabled state.
  Future<void> toggleRule(String id) async {
    final index = rules.indexWhere((r) => r.id == id);
    if (index >= 0) {
      rules[index] = rules[index].copyWith(enabled: !rules[index].enabled);
      await _saveRules();
    }
  }

  /// Add a quick rule.
  Future<bool> addQuickRule(DanmakuQuickRule quickRule) async {
    final rule = DanmakuHighlightRule(
      id: 'quick-${DateTime.now().microsecondsSinceEpoch}',
      keyword: quickRule.keyword,
      isRegex: false,
      color: quickRule.color,
      priority: 0,
      enabled: true,
      createdAt: DateTime.now(),
    );
    return addRule(rule);
  }

  /// Check if a keyword already exists.
  bool hasKeyword(String keyword) {
    return rules.any(
      (r) => r.keyword.toLowerCase() == keyword.toLowerCase(),
    );
  }

  /// Get enabled rules count.
  int get enabledCount => rules.where((r) => r.enabled).length;
}
