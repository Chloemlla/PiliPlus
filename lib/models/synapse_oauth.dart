final class SynapseOAuthCallback {
  const SynapseOAuthCallback({
    required this.state,
    this.code,
    this.error,
    this.errorDescription,
  });

  final String state;
  final String? code;
  final String? error;
  final String? errorDescription;

  bool get isSuccess => code != null;

  static SynapseOAuthCallback? tryParse(Uri uri) {
    try {
      return SynapseOAuthCallback.fromUri(uri);
    } on FormatException {
      return null;
    }
  }

  factory SynapseOAuthCallback.fromUri(Uri uri) {
    if (uri.scheme != 'piliplus' ||
        uri.host != 'synapse-auth' ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.fragment.isNotEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.query.isEmpty) {
      throw const FormatException('Invalid Synapse OAuth callback URI');
    }

    const allowedKeys = {'code', 'error', 'error_description', 'state'};
    final parameters = uri.queryParametersAll;
    if (parameters.keys.any((key) => !allowedKeys.contains(key)) ||
        parameters.values.any((values) => values.length != 1)) {
      throw const FormatException('Invalid Synapse OAuth callback parameters');
    }

    final state = parameters['state']?.single.trim();
    final code = parameters['code']?.single.trim();
    final error = parameters['error']?.single.trim();
    final errorDescription = parameters['error_description']?.single.trim();
    if (state == null || state.isEmpty ||
        (code == null && error == null) ||
        (code != null && error != null) ||
        (code != null && code.isEmpty) ||
        (error != null && error.isEmpty)) {
      throw const FormatException('Invalid Synapse OAuth callback values');
    }

    return SynapseOAuthCallback(
      state: state,
      code: code,
      error: error,
      errorDescription: errorDescription,
    );
  }
}

enum SynapseOAuthErrorCode {
  invalidBaseUrl,
  clientUnavailable,
  cancelled,
  callbackTimeout,
  callbackStateMismatch,
  authorizationDenied,
  tokenExchangeFailed,
  invalidTokenResponse,
}

final class SynapseOAuthException implements Exception {
  const SynapseOAuthException(
    this.code,
    this.message, {
    this.serverCode,
  });

  final SynapseOAuthErrorCode code;
  final String message;
  final String? serverCode;

  @override
  String toString() => message;
}

final class SynapseOAuthToken {
  const SynapseOAuthToken({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
    this.deviceTracked,
  });

  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int? expiresIn;
  final bool? deviceTracked;

  factory SynapseOAuthToken.fromResponse(Object? response) {
    if (response is! Map) {
      throw const FormatException('Invalid Synapse OAuth token response');
    }
    final root = Map<String, dynamic>.from(response);
    final payload = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    final error = root['error']?.toString().trim();
    if (error?.isNotEmpty == true) {
      throw SynapseOAuthException(
        SynapseOAuthErrorCode.tokenExchangeFailed,
        'Synapse OAuth token 请求被拒绝',
        serverCode: error,
      );
    }
    final accessToken = payload['access_token']?.toString().trim() ??
        payload['accessToken']?.toString().trim() ??
        '';
    if (accessToken.isEmpty) {
      throw const FormatException('Synapse OAuth response has no access token');
    }

    final device = payload['device'];
    bool? deviceTracked = _boolValue(payload['device_tracked']) ??
        _boolValue(payload['device_registered']) ??
        _boolValue(payload['deviceRegistered']);
    if (device is Map) {
      deviceTracked ??= _boolValue(device['tracked']) ??
          _boolValue(device['registered']);
    }

    return SynapseOAuthToken(
      accessToken: accessToken,
      refreshToken: payload['refresh_token']?.toString().trim() ??
          payload['refreshToken']?.toString().trim(),
      tokenType: payload['token_type']?.toString() ??
          payload['tokenType']?.toString() ??
          'Bearer',
      expiresIn: (payload['expires_in'] as num?)?.toInt() ??
          (payload['expiresIn'] as num?)?.toInt(),
      deviceTracked: deviceTracked,
    );
  }

  static bool? _boolValue(Object? value) => value is bool ? value : null;
}

final class SynapseClientIdentity {
  const SynapseClientIdentity({
    required this.deviceId,
    required this.platform,
    required this.clientVersion,
    required this.buildNumber,
  });

  static const clientId = 'piliplus';
  static const clientName = 'PiliPlus';
  static const oauthScope = 'openid profile email bilibili:sync';

  final String deviceId;
  final String platform;
  final String clientVersion;
  final int buildNumber;

  String get deviceName => '$clientName $platform';

  Map<String, String> get authorizeParameters => {
    'client_id': clientId,
    'client_name': clientName,
    'scope': oauthScope,
    'client_version': clientVersion,
    'client_build': buildNumber.toString(),
    'device_id': deviceId,
    'device_name': deviceName,
    'platform': platform,
  };

  Map<String, String> get requestHeaders => {
    'X-Synapse-Client-Id': clientId,
    'X-Synapse-Client-Name': clientName,
    'X-Synapse-Client-Version': clientVersion,
    'X-Synapse-Client-Build': buildNumber.toString(),
    'X-Synapse-Device-Id': deviceId,
    'X-Synapse-Device-Name': deviceName,
    'X-Synapse-Platform': platform,
  };

  Map<String, String> get tokenParameters => {
    ...authorizeParameters,
  };
}
