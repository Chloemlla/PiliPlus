final class WebQrAuthScene {
  const WebQrAuthScene({
    required this.target,
    required this.allowTransient,
    required this.requiresEnvironment,
    required this.environments,
    required this.locationDiffers,
    required this.location,
    required this.requiresPhoneVerification,
  });

  final WebQrAuthTarget target;
  final bool allowTransient;
  final bool requiresEnvironment;
  final List<WebQrAuthEnvironment> environments;
  final bool locationDiffers;
  final String? location;
  final bool requiresPhoneVerification;

  factory WebQrAuthScene.fromJson(Object? json) {
    final map = _asMap(json);
    final environments = switch (map['env_show_list']) {
      final Iterable values =>
        values
            .map(WebQrAuthEnvironment.tryParse)
            .whereType<WebQrAuthEnvironment>()
            .toList(growable: false),
      _ => const <WebQrAuthEnvironment>[],
    };
    final requiresEnvironment = map['obtain_env'] == true;
    if (requiresEnvironment && environments.isEmpty) {
      throw const FormatException('授权接口未返回可用的登录环境');
    }

    return WebQrAuthScene(
      target: WebQrAuthTarget.fromJson(map['app']),
      allowTransient: map['transient'] == true,
      requiresEnvironment: requiresEnvironment,
      environments: environments,
      locationDiffers: map['location_diff'] == true,
      location: _nonEmptyString(map['qrcode_location']),
      requiresPhoneVerification: map['verify_tel'] == true,
    );
  }
}

final class WebQrAuthTarget {
  const WebQrAuthTarget({
    required this.title,
    this.description,
    this.iconUrl,
  });

  final String title;
  final String? description;
  final String? iconUrl;

  factory WebQrAuthTarget.fromJson(Object? json) {
    final map = _asMap(json, allowNull: true);
    return WebQrAuthTarget(
      title:
          _nonEmptyString(map['title']) ??
          _nonEmptyString(map['name']) ??
          '哔哩哔哩网页端',
      description:
          _nonEmptyString(map['description']) ?? _nonEmptyString(map['desc']),
      iconUrl: _nonEmptyString(map['icon']),
    );
  }
}

final class WebQrAuthEnvironment {
  const WebQrAuthEnvironment({required this.key, required this.description});

  final String key;
  final String description;

  static WebQrAuthEnvironment? tryParse(Object? json) {
    final map = _asMap(json, allowNull: true);
    final key = _nonEmptyString(map['env_key']);
    final description = _nonEmptyString(map['env_desc']);
    if (key == null || description == null) {
      return null;
    }
    return WebQrAuthEnvironment(key: key, description: description);
  }
}

Map<String, Object?> _asMap(Object? value, {bool allowNull = false}) {
  if (value == null && allowNull) {
    return const {};
  }
  if (value case final Map map) {
    return {
      for (final entry in map.entries)
        if (entry.key case final String key) key: entry.value,
    };
  }
  throw const FormatException('授权接口返回的数据格式无效');
}

String? _nonEmptyString(Object? value) {
  if (value case final String text when text.trim().isNotEmpty) {
    return text.trim();
  }
  return null;
}
