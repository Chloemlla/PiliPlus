import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:pili_plus/pages/setting/widgets/synapse_verification_dialog.dart';
import 'package:pili_plus/services/crash/crash_breadcrumbs.dart';
import 'package:pili_plus/utils/setting_secret_store.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

/// Synapse 首访闸门（`/api/ip-verification`）的客户端实现。
///
/// 语义与 Synapse-Client 的 `SynapseIpVerificationInterceptor`、网页端
/// `frontend/src/utils/ipVerification.ts` 完全对齐：
///
///  - 指纹必须匹配服务端的 `^[a-zA-Z0-9_-]{8,200}$`（`normalizeFingerprint`）；
///  - 令牌绑定 `(指纹, IP)`，有效期一律听服务端：`expiresAt` 优先，其次
///    `tokenTtlMinutes`，都没有才退回默认 40 分钟；本地提前 60 秒换新；
///  - 干净 IP 由服务端直接签发 `issuedBy: "auto"` 的令牌，不弹验证；被标记的 IP 回
///    `requiresVerification: true`，这时才渲染人机验证模块，拿 `captchaToken` 走
///    `/api/ip-verification/complete`；
///  - 403 上带 `IP_VERIFICATION_REQUIRED` 说明请求根本没进业务逻辑，重放一次是安全的；
///  - 高风险 IP 会被直接封禁（403 + `error === "IP已被封禁"`），此时不再给验证机会。
abstract final class SynapseIpVerification {
  /// 令牌保存在加密 sidecar 里，和 OAuth 凭据同一套存储约定。
  static const _tokenSecretKey = 'ipVerificationToken';
  static const _fingerprintSettingKey = SettingBoxKey.synapseFingerprint;

  /// 与网页端一致的提前换新窗口。
  static const _refreshSkewMs = 60 * 1000;
  static const _defaultTtlMinutes = 40;

  static const errorCode = 'IP_VERIFICATION_REQUIRED';
  static const bannedErrorText = 'IP已被封禁';

  /// 一次性重试标记：避免拦截器在同一个请求上反复刷新令牌。
  static const _retriedFlag = 'synapseIpVerificationRetried';

  static String? _providerBaseUrl;
  static Map<String, String> Function()? _identityHeaders;
  static String? _userAgent;
  static String? _sessionFingerprint;
  static _CachedToken? _cachedToken;
  static Future<void>? _inFlightRefresh;
  static SynapseIpVerificationConfig? _captchaConfig;

  /// 服务端最近一次判定「需要人机验证」的原因，用于界面文案与诊断。
  static String? lastChallengeReason;

  // ── 指纹 ─────────────────────────────────────────────────────────────

  /// 稳定的安装指纹。网页端用 FingerprintJS 的 canvas/WebGL 结果，这里用随机
  /// 装置标识：服务端只要求「同一设备稳定、跨设备不同」，并不校验采集方式。
  static String fingerprint() {
    final cached = _sessionFingerprint;
    if (cached != null) return cached;
    final stored = GStorage.setting.get(_fingerprintSettingKey) as String?;
    final normalized = _normalizeFingerprint(stored);
    if (normalized != null) {
      _sessionFingerprint = normalized;
      return normalized;
    }
    final generated = _generateFingerprint();
    _sessionFingerprint = generated;
    unawaited(GStorage.setting.put(_fingerprintSettingKey, generated));
    return generated;
  }

  static String? _normalizeFingerprint(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.length < 8 || trimmed.length > 200) {
      return null;
    }
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed) ? trimmed : null;
  }

  static String _generateFingerprint() {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(24, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  // ── 令牌缓存 ─────────────────────────────────────────────────────────

  static _CachedToken? _readCachedToken() {
    final inMemory = _cachedToken;
    if (inMemory != null) return inMemory;
    final raw = _readPersistedToken();
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('token payload is not a map');
      final token = decoded['token']?.toString();
      final fingerprintValue = decoded['fingerprint']?.toString();
      final expiresAt = (decoded['expiresAt'] as num?)?.toInt();
      if (token == null || token.isEmpty || fingerprintValue == null || expiresAt == null) {
        throw const FormatException('incomplete token payload');
      }
      final parsed = _CachedToken(
        token: token,
        fingerprint: fingerprintValue,
        expiresAtMillis: expiresAt,
      );
      _cachedToken = parsed;
      return parsed;
    } catch (error) {
      if (kDebugMode) debugPrint('Synapse IP verification token unreadable: $error');
      _clearPersistedToken();
      return null;
    }
  }

  static String? _readPersistedToken() {
    try {
      final fromSecretStore = SettingSecretStore.readSynapse(_tokenSecretKey);
      if (fromSecretStore != null && fromSecretStore.isNotEmpty) return fromSecretStore;
    } catch (_) {
      // 加密 sidecar 未就绪时退回 Hive，避免启动早期拿不到令牌。
    }
    return GStorage.setting.get(SettingBoxKey.synapseIpVerificationToken) as String?;
  }

  static void _persistToken(_CachedToken token) {
    _cachedToken = token;
    final raw = jsonEncode({
      'token': token.token,
      'fingerprint': token.fingerprint,
      'expiresAt': token.expiresAtMillis,
    });
    try {
      SettingSecretStore.writeSynapse(_tokenSecretKey, raw);
    } catch (error) {
      if (kDebugMode) debugPrint('Synapse IP verification token sidecar unavailable: $error');
      unawaited(GStorage.setting.put(SettingBoxKey.synapseIpVerificationToken, raw));
    }
  }

  static void _clearPersistedToken() {
    _cachedToken = null;
    try {
      SettingSecretStore.deleteSynapse(_tokenSecretKey);
    } catch (_) {
      // ignore: the fallback copy is removed below.
    }
    unawaited(GStorage.setting.delete(SettingBoxKey.synapseIpVerificationToken));
  }

  /// 当前可用令牌；过期、指纹不匹配或不存在时返回 null。
  static String? currentToken() {
    final token = _readCachedToken();
    if (token == null) return null;
    if (token.fingerprint != fingerprint()) {
      _clearPersistedToken();
      return null;
    }
    if (DateTime.now().millisecondsSinceEpoch >= token.expiresAtMillis - _refreshSkewMs) {
      _clearPersistedToken();
      return null;
    }
    return token.token;
  }

  /// 对外暴露的验证状态，供设置页展示。
  static String get statusText {
    final cached = _readCachedToken();
    final token = currentToken();
    if (token != null && cached != null) {
      final remaining = cached.expiresAtMillis - DateTime.now().millisecondsSinceEpoch;
      final minutes = (remaining / 60000).floor().clamp(0, 999);
      return '网络访问验证：已授权，约 $minutes 分钟后需要重新获取';
    }
    if (_inNoTokenWindow) return '网络访问验证：当前服务地址未要求验证';
    return '网络访问验证：需要时会自动提示完成';
  }

  /// 闸门所需的两个头。没有令牌时只带指纹 —— 服务端会以 403 要求验证，
  /// 与网页端「先发指纹、被拦再握手」的行为一致。
  static Map<String, String> requestHeaders() {
    final result = <String, String>{'X-Fingerprint': fingerprint()};
    final token = currentToken();
    if (token != null) {
      result['X-IP-Verification-Token'] = token;
    }
    return result;
  }

  // ── 拦截器 ───────────────────────────────────────────────────────────

  /// 给 Dio 装上首访闸门：请求带指纹/令牌，403 时握手一次再重放。
  ///
  /// [providerBaseUrl] 是要访问的服务根地址（不含 `/api/bilibili-sync` 之类后缀），
  /// 因为 `/api/ip-verification/*` 挂在服务根上。
  static Interceptor interceptor({
    required String Function() providerBaseUrl,
    required Map<String, String> Function() identityHeaders,
    required String Function() userAgent,
  }) {
    _providerBaseUrl = providerBaseUrl().trim().replaceAll(RegExp(r'/+$'), '');
    _identityHeaders = identityHeaders;
    _userAgent = userAgent();
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        requestHeaders().forEach((key, value) {
          if (!options.headers.containsKey(key)) {
            options.headers[key] = value;
          }
        });
        handler.next(options);
      },
      onError: (error, handler) async {
        if (!_isVerificationRequired(error)) {
          handler.next(error);
          return;
        }
        if (error.requestOptions.extra[_retriedFlag] == true) {
          handler.next(error);
          return;
        }
        try {
          // 403 本身就是「此刻闸门开着」的证据：之前的静默判定作废。
          _noTokenNeededUntilMillis = 0;
          await _refreshSession();
        } catch (refreshError) {
          if (kDebugMode) debugPrint('Synapse IP verification refresh failed: $refreshError');
          handler.next(error);
          return;
        }
        final token = currentToken();
        if (token == null) {
          handler.next(error);
          return;
        }
        final options = error.requestOptions;
        options.extra[_retriedFlag] = true;
        options.headers['X-Fingerprint'] = fingerprint();
        options.headers['X-IP-Verification-Token'] = token;
        try {
          final response = await _dioFor(options.baseUrl).fetch<Object?>(options);
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    );
  }

  static bool _isVerificationRequired(DioException error) {
    if (error.response?.statusCode != 403) return false;
    final body = error.response?.data;
    if (body is! Map) return false;
    if (body['error'] == bannedErrorText || body['errorCode'] == 'IP_BANNED' || body['banned'] == true) {
      // 已封禁不是「验证一下就好」：不再重试，交给上层展示封禁原因。
      return false;
    }
    return body['errorCode'] == errorCode || body['requiresVerification'] == true;
  }

  /// 解析 403 里的封禁载荷，供界面展示。
  static SynapseIpVerificationBan? banFromDioException(DioException error) {
    final body = error.response?.data;
    if (error.response?.statusCode != 403 || body is! Map) return null;
    final isBanned =
        body['error'] == bannedErrorText || body['errorCode'] == 'IP_BANNED' || body['banned'] == true;
    if (!isBanned) return null;
    return SynapseIpVerificationBan(
      reason: body['reason']?.toString(),
      expiresAt: body['expiresAt']?.toString(),
    );
  }

  // ── 握手 ─────────────────────────────────────────────────────────────

  /// 服务端判定「不需要令牌」（闸门未启用、或 IPQS/proxycheck 两侧都关）时的静默窗口。
  /// 不记下这个结论的话，闸门关着的部署会每 5 分钟白 POST 一次 session。
  static int _noTokenNeededUntilMillis = 0;

  static bool get _inNoTokenWindow =>
      DateTime.now().millisecondsSinceEpoch < _noTokenNeededUntilMillis;

  /// 公开入口：让同步流程在真正发请求前先把令牌拿到手，省掉一次必然的 403。
  static Future<void> ensureSession() async {
    if (currentToken() != null || _inNoTokenWindow) return;
    try {
      await _refreshSession();
    } catch (error) {
      // 拿不到令牌不是致命错误：真正的请求会被闸门拦下，拦截器那时再处理一次。
      if (kDebugMode) debugPrint('Synapse IP verification preflight failed: $error');
    }
  }

  /// 同一个进程内只允许一次在途握手，避免并发请求各发一次。
  static Future<void> _refreshSession() {
    final inFlight = _inFlightRefresh;
    if (inFlight != null) return inFlight;
    final future = _performRefresh();
    _inFlightRefresh = future;
    return future.whenComplete(() => _inFlightRefresh = null);
  }

  static Future<void> _performRefresh() async {
    final result = await initializeSession();
    final issued = result.token;
    if (issued != null && result.verified) {
      _persistToken(
        _CachedToken(
          token: issued,
          fingerprint: fingerprint(),
          expiresAtMillis: result.expiresAtMillis,
        ),
      );
      _noTokenNeededUntilMillis = 0;
      lastChallengeReason = null;
      return;
    }
    if (!result.requiresVerification) {
      // 闸门没开（或该路径被豁免）：服务端会直接 verified 但不发令牌。
      _noTokenNeededUntilMillis = result.expiresAtMillis;
      lastChallengeReason = null;
      return;
    }
    lastChallengeReason = result.reason;
    final completed = await _completeChallenge();
    if (completed?.token == null) {
      throw const SynapseIpVerificationRequired('需要完成人机验证');
    }
  }

  /// `POST /api/ip-verification/session`。
  static Future<SynapseIpVerificationSession> initializeSession() async {
    final dio = _bootstrapDio();
    try {
      final response = await dio.post<Object?>(
        '/api/ip-verification/session',
        data: {'fingerprint': fingerprint()},
      );
      return SynapseIpVerificationSession.fromResponse(response.data);
    } on DioException catch (error) {
      final ban = banFromDioException(error);
      if (ban != null) throw SynapseIpVerificationBanned(ban);
      rethrow;
    }
  }

  /// 渲染人机验证模块并换取令牌；用户取消、组件不可用或服务端没发令牌时返回
  /// 一个不带 token 的结果（或 null）。
  static Future<SynapseIpVerificationSession?> _completeChallenge() async {
    final config = await _loadCaptchaConfig();
    if (config == null || !config.hasUsableWidget) {
      CrashBreadcrumbs.record('Synapse IP verification: no usable captcha site key');
      return null;
    }
    _captchaConfig = config;
    final captchaToken = await SynapseVerificationDialog.show(
      config: config,
      pageBaseUrl: _providerBaseUrl ?? '',
    );
    if (captchaToken == null || captchaToken.trim().isEmpty) return null;

    final dio = _bootstrapDio();
    final response = await dio.post<Object?>(
      '/api/ip-verification/complete',
      data: {
        'fingerprint': fingerprint(),
        'captchaToken': captchaToken,
        // 服务端只认 "turnstile" / "hcaptcha" 两个字面量（`captchaType === 'hcaptcha'`），
        // 直接传枚举会让 jsonEncode 抛 Unsupported operation。
        'captchaType': config.type == SynapseCaptchaType.hcaptcha ? 'hcaptcha' : 'turnstile',
      },
    );
    final result = SynapseIpVerificationSession.fromResponse(response.data);
    final issued = result.token;
    if (issued != null && result.verified) {
      _persistToken(
        _CachedToken(
          token: issued,
          fingerprint: fingerprint(),
          expiresAtMillis: result.expiresAtMillis,
        ),
      );
      _noTokenNeededUntilMillis = 0;
      lastChallengeReason = null;
    }
    return result;
  }

  /// 手动触发一次验证（设置页入口）。闸门没开时同样返回 true。
  static Future<bool> verifyNow() async {
    _clearPersistedToken();
    _noTokenNeededUntilMillis = 0;
    await _refreshSession();
    return currentToken() != null || _inNoTokenWindow;
  }

  /// `GET /api/turnstile/public-config`：服务端同时给出 Turnstile 与 hCaptcha
  /// 的公开配置，由本端按「先 Turnstile 后 hCaptcha」挑选。
  static Future<SynapseIpVerificationConfig?> _loadCaptchaConfig() async {
    final cached = _captchaConfig;
    if (cached != null) return cached;
    try {
      final response = await _bootstrapDio().get<Object?>('/api/turnstile/public-config');
      return SynapseIpVerificationConfig.fromResponse(response.data);
    } catch (error) {
      if (kDebugMode) debugPrint('Synapse captcha config failed: $error');
      return null;
    }
  }

  static Dio _bootstrapDio() => _dioFor(_providerBaseUrl ?? '');

  static final Map<String, Dio> _dioCache = {};

  /// 引导请求必须用不带本拦截器的 Dio，否则会自我递归。
  static Dio _dioFor(String baseUrl) {
    return _dioCache.putIfAbsent(baseUrl, () {
      final headers = <String, Object>{'Accept': 'application/json'};
      final identity = _identityHeaders?.call();
      if (identity != null) headers.addAll(identity);
      final agent = _userAgent;
      if (agent != null && agent.isNotEmpty) headers['User-Agent'] = agent;
      return Dio(
        BaseOptions(
          baseUrl: baseUrl,
          headers: headers,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
    });
  }
}

/// 服务端「需要人机验证但用户没有完成」时抛出。
final class SynapseIpVerificationRequired implements Exception {
  const SynapseIpVerificationRequired(this.message);
  final String message;

  @override
  String toString() => message;
}

final class SynapseIpVerificationBan {
  const SynapseIpVerificationBan({this.reason, this.expiresAt});
  final String? reason;
  final String? expiresAt;
}

final class SynapseIpVerificationBanned implements Exception {
  const SynapseIpVerificationBanned(this.ban);
  final SynapseIpVerificationBan ban;

  @override
  String toString() => 'IP 已被封禁${ban.reason == null ? '' : '：${ban.reason}'}';
}

final class SynapseIpVerificationSession {
  const SynapseIpVerificationSession({
    required this.verified,
    required this.requiresVerification,
    required this.expiresAtMillis,
    this.token,
    this.issuedBy,
    this.reason,
    this.fraudScore,
    this.riskFlags = const [],
  });

  final bool verified;
  final bool requiresVerification;
  final int expiresAtMillis;
  final String? token;
  final String? issuedBy;
  final String? reason;
  final num? fraudScore;
  final List<String> riskFlags;

  /// 有效期一律听服务端的：`expiresAt` 优先，其次 `tokenTtlMinutes`，
  /// 都没有才退回 40 分钟（与网页端 `resolveExpiryMillis` 同序）。
  factory SynapseIpVerificationSession.fromResponse(Object? response) {
    final body = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
    final expiresAtRaw = body['expiresAt']?.toString();
    final parsedExpiry = DateTime.tryParse(expiresAtRaw ?? '')?.millisecondsSinceEpoch;
    final ttlMinutes = (body['tokenTtlMinutes'] as num?)?.toInt();
    final expiresAtMillis = parsedExpiry ??
        DateTime.now().millisecondsSinceEpoch +
            (ttlMinutes != null && ttlMinutes > 0 ? ttlMinutes : SynapseIpVerification._defaultTtlMinutes) *
                60 *
                1000;
    final riskFlags = (body['riskFlags'] as List?)
            ?.whereType<Object>()
            .map((item) => item.toString())
            .toList(growable: false) ??
        const <String>[];
    return SynapseIpVerificationSession(
      verified: body['verified'] == true,
      requiresVerification: body['requiresVerification'] == true,
      expiresAtMillis: expiresAtMillis,
      token: body['token']?.toString(),
      issuedBy: body['issuedBy']?.toString(),
      reason: body['reason']?.toString(),
      fraudScore: body['fraudScore'] as num?,
      riskFlags: riskFlags,
    );
  }
}

enum SynapseCaptchaType { turnstile, hcaptcha }

final class SynapseIpVerificationConfig {
  const SynapseIpVerificationConfig({
    required this.type,
    required this.siteKey,
    this.turnstileEnabled = false,
    this.turnstileSiteKey,
    this.hcaptchaEnabled = false,
    this.hcaptchaSiteKey,
  });

  final SynapseCaptchaType type;
  final String siteKey;
  final bool turnstileEnabled;
  final String? turnstileSiteKey;
  final bool hcaptchaEnabled;
  final String? hcaptchaSiteKey;

  bool get hasUsableWidget => siteKey.trim().isNotEmpty;

  factory SynapseIpVerificationConfig.fromResponse(Object? response) {
    final body = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
    final turnstileEnabled = body['enabled'] == true;
    final turnstileSiteKey = body['siteKey']?.toString();
    final hcaptchaEnabled = body['hcaptchaEnabled'] == true;
    final hcaptchaSiteKey = body['hcaptchaSiteKey']?.toString();

    if (turnstileEnabled && (turnstileSiteKey?.isNotEmpty ?? false)) {
      return SynapseIpVerificationConfig(
        type: SynapseCaptchaType.turnstile,
        siteKey: turnstileSiteKey!,
        turnstileEnabled: true,
        turnstileSiteKey: turnstileSiteKey,
        hcaptchaEnabled: hcaptchaEnabled,
        hcaptchaSiteKey: hcaptchaSiteKey,
      );
    }
    if (hcaptchaEnabled && (hcaptchaSiteKey?.isNotEmpty ?? false)) {
      return SynapseIpVerificationConfig(
        type: SynapseCaptchaType.hcaptcha,
        siteKey: hcaptchaSiteKey!,
        turnstileEnabled: turnstileEnabled,
        turnstileSiteKey: turnstileSiteKey,
        hcaptchaEnabled: true,
        hcaptchaSiteKey: hcaptchaSiteKey,
      );
    }
    return SynapseIpVerificationConfig(
      type: SynapseCaptchaType.turnstile,
      siteKey: '',
      turnstileEnabled: turnstileEnabled,
      turnstileSiteKey: turnstileSiteKey,
      hcaptchaEnabled: hcaptchaEnabled,
      hcaptchaSiteKey: hcaptchaSiteKey,
    );
  }
}

final class _CachedToken {
  const _CachedToken({
    required this.token,
    required this.fingerprint,
    required this.expiresAtMillis,
  });

  final String token;
  final String fingerprint;
  final int expiresAtMillis;
}
