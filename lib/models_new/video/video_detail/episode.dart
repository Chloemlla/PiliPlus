import 'package:pili_plus/models_new/video/video_detail/arc.dart';
import 'package:pili_plus/models_new/video/video_detail/page.dart';

class EpisodePlaybackFlags {
  final String? badge;
  final bool isCharging;
  final bool isChargingPurchased;

  const EpisodePlaybackFlags({
    this.badge,
    this.isCharging = false,
    this.isChargingPurchased = false,
  });

  factory EpisodePlaybackFlags.fromJson(Map<String, dynamic> json) {
    final badge = _badgeText(json['badge']);
    final chargingPay = json['charging_pay'];
    final isCharging =
        _isChargingValue(chargingPay) ||
        _isChargingBadge(badge) ||
        _asBool(json['is_upower_exclusive']) == true ||
        ((_asInt(json['attribute']) ?? 0) & 8) != 0;
    final isChargingPurchased =
        _hasPurchaseMarker(json, includeGeneric: false) ||
        _hasPurchaseMarker(chargingPay);

    return EpisodePlaybackFlags(
      badge: badge,
      isCharging: isCharging,
      isChargingPurchased: isChargingPurchased,
    );
  }

  static int? parseInt(Object? value) => _asInt(value);

  static bool _isChargingValue(Object? value) {
    if (value is Map) {
      if (value.isEmpty) return false;
      if (value['level'] != null) return true;
      for (final key in const [
        'is_upower_exclusive',
        'is_charging',
        'is_charging_pay',
        'charging',
      ]) {
        if (_asBool(value[key]) == true) return true;
      }
      return true;
    }
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return _isChargingBadge(value);
    return false;
  }

  static bool _hasPurchaseMarker(
    Object? value, {
    bool includeGeneric = true,
  }) {
    if (value is Map) {
      for (final key in const [
        'is_purchased',
        'is_purchase',
        'purchased',
        'has_purchased',
        'is_paid',
        'paid',
        'has_paid',
        'is_charged',
        'buy_status',
        'purchase_status',
        'pay_status',
      ]) {
        if (_isPositivePurchaseValue(value[key])) return true;
      }
      if (includeGeneric &&
          (_isPositivePurchaseValue(value['status']) ||
              _isPositivePurchaseValue(value['state']))) {
        return true;
      }
      for (final key in const ['user_status', 'purchase', 'payment', 'user']) {
        final nested = value[key];
        if (_isPositivePurchaseValue(nested) || _hasPurchaseMarker(nested)) {
          return true;
        }
      }
    } else if (value is String) {
      return _isPositivePurchaseValue(value);
    }
    return false;
  }

  static bool _isPositivePurchaseValue(Object? value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return const {
        '1',
        'true',
        'yes',
        'paid',
        'purchased',
        'bought',
        'unlocked',
        '已购买',
        '已购',
        '已支付',
        '已解锁',
      }.contains(normalized);
    }
    return false;
  }

  static bool _isChargingBadge(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    return normalized.contains('充电') ||
        normalized.contains('upower') ||
        normalized.contains('charging');
  }

  static String? _badgeText(Object? value) {
    if (value is String) return value;
    if (value is Map) {
      for (final key in const ['text', 'label', 'title']) {
        final text = _badgeText(value[key]);
        if (text != null && text.isNotEmpty) return text;
      }
    } else if (value is List) {
      for (final item in value) {
        final text = _badgeText(item);
        if (text != null && text.isNotEmpty) return text;
      }
    }
    return null;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return switch (value.trim().toLowerCase()) {
        '1' || 'true' || 'yes' => true,
        '0' || 'false' || 'no' || '' => false,
        _ => null,
      };
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return value is String ? int.tryParse(value.trim()) : null;
  }
}

class BaseEpisodeItem {
  int? id;
  int? aid;
  int? cid;
  int? epId;
  String? bvid;
  String? badge;
  String? title;
  String? cover;
  bool isCharging;
  bool isChargingPurchased;

  bool get shouldSkipForAutoPlay => isCharging && !isChargingPurchased;

  BaseEpisodeItem({
    this.id,
    this.aid,
    this.cid,
    this.epId,
    this.bvid,
    this.badge,
    this.title,
    this.cover,
    this.isCharging = false,
    this.isChargingPurchased = false,
  });
}

class EpisodeItem extends BaseEpisodeItem {
  int? seasonId;
  int? sectionId;
  int? attribute;
  Arc? arc;
  Part? page;
  List<Part>? pages;
  @override
  String? get cover => arc?.pic;

  EpisodeItem({
    this.seasonId,
    this.sectionId,
    super.id,
    super.aid,
    super.cid,
    super.title,
    this.attribute,
    this.arc,
    this.page,
    super.bvid,
    this.pages,
    super.badge,
    super.isCharging,
    super.isChargingPurchased,
  });

  factory EpisodeItem.fromJson(Map<String, dynamic> json) {
    final flags = EpisodePlaybackFlags.fromJson(json);
    return EpisodeItem(
      seasonId: json['season_id'] as int?,
      sectionId: json['section_id'] as int?,
      id: json['id'] as int?,
      aid: json['aid'] as int?,
      cid: json['cid'] as int?,
      title: json['title'] as String?,
      attribute: EpisodePlaybackFlags.parseInt(json['attribute']),
      arc: json['arc'] == null
          ? null
          : Arc.fromJson(json['arc'] as Map<String, dynamic>),
      page: json['page'] == null
          ? null
          : Part.fromJson(json['page'] as Map<String, dynamic>),
      bvid: json['bvid'] as String?,
      pages: (json['pages'] as List<dynamic>?)
          ?.map((e) => Part.fromJson(e as Map<String, dynamic>))
          .toList(),
      badge: flags.badge,
      isCharging: flags.isCharging,
      isChargingPurchased: flags.isChargingPurchased,
    );
  }
}
