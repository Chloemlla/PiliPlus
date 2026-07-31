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

  /// Active rules in descending priority order.
  final _activeRules = <DanmakuHighlightRule>[];

  /// Pre-normalized keywords for substring matching.
  final _normalizedKeywords = <String, String>{};

  @override
  void onInit() {
    super.onInit();
    _loadRules();
  }

  void _loadRules() {
    final raw = GStorage.setting.get(_boxKey);
    if (raw is List) {
      final loaded = <DanmakuHighlightRule>[];
      for (final item in raw) {
        if (item is Map) {
          try {
            loaded.add(
              DanmakuHighlightRule.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Failed to load highlight rule: $e');
            }
          }
        }
      }
      loaded.sort((a, b) => b.priority.compareTo(a.priority));
      if (loaded.length > maxRules) {
        loaded.removeRange(maxRules, loaded.length);
      }
      rules.value = loaded;
    }
    _compilePatterns();
  }

  Future<void> _saveRules() async {
    _compilePatterns();
    final data = rules.map((r) => r.toJson()).toList();
    await GStorage.setting.put(_boxKey, data);
  }

  void _compilePatterns() {
    _compiledPatterns.clear();
    _keywordIndex.clear();
    _activeRules.clear();
    _normalizedKeywords.clear();

    final activeRules = rules.where((r) => r.enabled).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    for (final rule in activeRules) {
      final keyword = rule.keyword.trim();
      if (keyword.isEmpty) continue;

      if (rule.isRegex) {
        try {
          _compiledPatterns[rule.id] = RegExp(
            keyword,
            caseSensitive: false,
          );
          _activeRules.add(rule);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Invalid regex pattern: ${rule.keyword}');
          }
        }
      } else {
        final normalizedKeyword = keyword.toLowerCase();
        _keywordIndex.putIfAbsent(normalizedKeyword, () => rule);
        _normalizedKeywords[rule.id] = normalizedKeyword;
        _activeRules.add(rule);
      }
    }
  }

  /// Apply highlights to danmaku text.
  /// Returns the highlight color if matched, null otherwise.
  HighlightColor? applyHighlight(String text) => getMatchingRule(text)?.color;

  /// Get the highlight rule that matches the text (for glow/border effect).
  DanmakuHighlightRule? getMatchingRule(String text) {
    if (_activeRules.isEmpty) return null;

    final lowerText = text.toLowerCase();
    final exactMatch = _keywordIndex[lowerText];
    for (final rule in _activeRules) {
      if (exactMatch != null && rule.priority <= exactMatch.priority) {
        return exactMatch;
      }

      final normalizedKeyword = _normalizedKeywords[rule.id];
      final matches = rule.isRegex
          ? _compiledPatterns[rule.id]?.hasMatch(text) == true
          : normalizedKeyword != null && lowerText.contains(normalizedKeyword);
      if (matches) return rule;
    }

    return exactMatch;
  }

  /// Add a new rule.
  Future<bool> addRule(DanmakuHighlightRule rule) async {
    if (rules.length >= maxRules) return false;
    final keyword = rule.keyword.trim();
    if (keyword.isEmpty || hasKeyword(keyword)) return false;

    rules
      ..add(rule.copyWith(keyword: keyword))
      ..sort((a, b) => b.priority.compareTo(a.priority));
    await _saveRules();
    return true;
  }

  /// Update an existing rule.
  Future<bool> updateRule(DanmakuHighlightRule rule) async {
    final keyword = rule.keyword.trim();
    if (keyword.isEmpty || hasKeyword(keyword, excludingId: rule.id)) {
      return false;
    }

    final index = rules.indexWhere((r) => r.id == rule.id);
    if (index < 0) return false;

    rules[index] = rule.copyWith(keyword: keyword);
    rules.sort((a, b) => b.priority.compareTo(a.priority));
    await _saveRules();
    return true;
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
  Future<bool> addQuickRule(DanmakuQuickRule quickRule) {
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
  bool hasKeyword(String keyword, {String? excludingId}) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    return rules.any(
      (r) =>
          r.id != excludingId &&
          r.keyword.trim().toLowerCase() == normalizedKeyword,
    );
  }

  /// Get enabled rules count.
  int get enabledCount => rules.where((r) => r.enabled).length;
}
