import 'package:pili_plus/models/common/member/tab_type.dart';
import 'package:pili_plus/models/common/theme/theme_type.dart';
import 'package:pili_plus/plugin/pl_player/models/play_repeat.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';

abstract final class SettingsBackupValidator {
  static const int currentSchemaVersion = 1;

  static void validateSchemaVersion(Map<String, dynamic> backup) {
    final version = backup['schemaVersion'] ?? 0;
    if (version is! int || version < 0 || version > currentSchemaVersion) {
      throw FormatException('Unsupported settings schema version: $version');
    }
  }

  static Map<dynamic, dynamic> validateSection(
    Map<String, dynamic> backup,
    String boxName,
    Map<dynamic, dynamic> currentValues,
  ) {
    final section = backup[boxName];
    if (section is! Map) {
      throw FormatException('Invalid settings backup: missing $boxName');
    }
    final candidate = Map<dynamic, dynamic>.from(section);
    for (final entry in candidate.entries) {
      final current = currentValues[entry.key];
      if (current != null && !_sameStoredType(current, entry.value)) {
        throw FormatException(
          'Invalid value type for $boxName.${entry.key}: '
          '${entry.value.runtimeType}',
        );
      }
    }
    if (boxName == 'setting') _validateStartupSettings(candidate);
    if (boxName == 'video') _validateVideoSettings(candidate);
    return candidate;
  }

  static void _validateStartupSettings(Map<dynamic, dynamic> values) {
    _enumIndex(values, SettingBoxKey.memberTab, MemberTabType.values.length);
    _enumIndex(values, SettingBoxKey.themeMode, ThemeType.values.length);
    _enumIndex(
      values,
      SettingBoxKey.schemeVariant,
      FlexSchemeVariant.values.length,
    );
    _enumIndex(
      values,
      SettingBoxKey.audioPlayMode,
      PlayRepeat.values.length,
    );
    _intRange(values, SettingBoxKey.customColor, 0, 0xFFFFFFFF);
    _positivePair(values, SettingBoxKey.windowSize);
    _numberPair(values, SettingBoxKey.windowPosition);
  }

  static void _validateVideoSettings(Map<dynamic, dynamic> values) {
    final speeds = values[VideoBoxKey.speedsList];
    if (speeds != null &&
        (speeds is! List ||
            speeds.isEmpty ||
            speeds.any((value) => value is! num || value <= 0))) {
      throw const FormatException('Invalid video.speedsList');
    }
  }

  static void _enumIndex(Map<dynamic, dynamic> values, String key, int length) {
    final value = values[key];
    if (value != null && (value is! int || value < 0 || value >= length)) {
      throw FormatException('Invalid enum index for setting.$key: $value');
    }
  }

  static void _intRange(
    Map<dynamic, dynamic> values,
    String key,
    int min,
    int max,
  ) {
    final value = values[key];
    if (value != null && (value is! int || value < min || value > max)) {
      throw FormatException('Invalid integer for setting.$key: $value');
    }
  }

  static void _positivePair(Map<dynamic, dynamic> values, String key) {
    _numberPair(values, key, requirePositive: true);
  }

  static void _numberPair(
    Map<dynamic, dynamic> values,
    String key, {
    bool requirePositive = false,
  }) {
    final value = values[key];
    if (value == null) return;
    if (value is! List ||
        value.length != 2 ||
        value.any(
          (item) =>
              item is! num || !item.isFinite || (requirePositive && item <= 0),
        )) {
      throw FormatException('Invalid numeric pair for setting.$key');
    }
  }

  static bool _sameStoredType(Object current, Object? candidate) {
    if (candidate == null) return false;
    if (current is num) return candidate is num;
    if (current is List) return candidate is List;
    if (current is Map) return candidate is Map;
    if (current is Set) return candidate is Set || candidate is List;
    return candidate.runtimeType == current.runtimeType;
  }
}
