import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart' show sha256;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pili_plus/build_config.dart';
import 'package:pili_plus/models/synapse_oauth.dart';
import 'package:pili_plus/models/search/search_history_entry.dart';
import 'package:pili_plus/services/startup_overlay_coordinator.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/app_scheme.dart';
import 'package:pili_plus/utils/persistence.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage/synapse_credential_store.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:pili_plus/utils/storage/search_history_store.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

enum SynapseSyncChoice { remote, local, merge }

final class SynapseRemoteSnapshot {
  const SynapseRemoteSnapshot({
    required this.records,
    required this.revision,
    this.settings,
    this.settingsVersion = 0,
    this.settingsUpdatedAt,
  });

  final List<Map<String, dynamic>> records;
  final int revision;
  final Map<String, dynamic>? settings;
  final int settingsVersion;
  final String? settingsUpdatedAt;
}

/// Synapse transport and sync state are deliberately isolated from [Request].
/// The Bilibili AccountManager interceptor must never see these requests.
abstract final class SynapseSyncService {
  static const defaultBaseUrl = 'https://tts.chloemlla.com';
  static const oauthTokenPath = 'api/oauth/token';
  static const _syncApiSuffix = '/api/bilibili-sync';
  static const redirectUri = 'piliplus://synapse-auth';
  static const _oauthTimeout = Duration(minutes: 2);
  static bool _isRunning = false;
  static bool _watchersStarted = false;
  static bool _syncWriteInProgress = false;
  static Timer? _syncTimer;

  static String get baseUrl =>
      (GStorage.setting.get(SettingBoxKey.synapseBaseUrl) as String?)?.trim().isNotEmpty == true
          ? (GStorage.setting.get(SettingBoxKey.synapseBaseUrl) as String).trim()
          : defaultBaseUrl;

  static bool get isEnabled =>
      GStorage.setting.get(SettingBoxKey.synapseSyncEnabled, defaultValue: false) == true;

  static int get boundMid =>
      (GStorage.setting.get(SettingBoxKey.synapseSyncBoundMid) as num?)?.toInt() ?? 0;

  static String? get accessToken => SynapseCredentialStore.readAccessToken();

  static bool get isConfigured => accessToken?.isNotEmpty == true;

  static String? get deviceId {
    final value = GStorage.setting.get(SettingBoxKey.synapseDeviceId) as String?;
    final trimmed = value?.trim();
    return trimmed?.isNotEmpty == true ? trimmed : null;
  }

  static bool get isDeviceTracked =>
      GStorage.setting.get(SettingBoxKey.synapseDeviceTracked, defaultValue: false) == true;

  static String get deviceTrackingStatus {
    final id = deviceId;
    if (id == null) return '设备追踪：首次授权时登记';
    if (isDeviceTracked) return '设备追踪：已登记（${_shortDeviceId(id)}）';
    if (isConfigured) return '设备追踪：已上报（${_shortDeviceId(id)}）';
    return '设备追踪：待授权上报（${_shortDeviceId(id)}）';
  }

  static Future<void> disableForLogout() async {
    _syncTimer?.cancel();
  }

  static Future<void> configure({
    required String accessToken,
    required String baseUrl,
    String? refreshToken,
    bool? deviceTracked,
  }) async {
    final uri = _parseBaseUrl(baseUrl);
    if (Accounts.main.mid == 0) {
      throw StateError('请先登录 B 站主账号');
    }
    await _ensureClientIdentity();
    final normalizedBaseUrl = _providerBaseUri(uri).toString().replaceFirst(RegExp(r'/$'), '');
    await Future.wait([
      Future<void>.sync(() => SynapseCredentialStore.writeAccessToken(accessToken)),
      Future<void>.sync(() => _storeRefreshToken(refreshToken)),
      GStorage.setting.put(SettingBoxKey.synapseBaseUrl, normalizedBaseUrl),
      GStorage.setting.put(SettingBoxKey.synapseSyncBoundMid, Accounts.main.mid),
      if (deviceTracked != null)
        GStorage.setting.put(SettingBoxKey.synapseDeviceTracked, deviceTracked),
    ]);
    _startWatchers();
  }

  static Future<Map<String, dynamic>> authorizeAndBind(BuildContext context, {required String baseUrl}) async {
    final uri = _providerBaseUri(_parseBaseUrl(baseUrl));
    final handoff = await _SynapseOAuthHandoff.start(uri);
    Object? outcome;
    try {
      outcome = await showDialog<Object?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _SynapseAuthorizationDialog(handoff: handoff),
      );
    } finally {
      handoff.cancel();
    }
    if (outcome is SynapseOAuthException) throw outcome;
    if (outcome is! SynapseOAuthCallback) {
      throw const SynapseOAuthException(
        SynapseOAuthErrorCode.cancelled,
        'Synapse 授权已取消',
      );
    }
    final callback = outcome;
    if (!callback.isSuccess) {
      throw SynapseOAuthException(
        SynapseOAuthErrorCode.authorizationDenied,
        'Synapse-Client 未完成授权：${callback.errorDescription ?? callback.error}',
        serverCode: callback.error,
      );
    }
    final token = await _exchangeOAuthToken(
      baseUrl: uri,
      session: handoff.session,
      callback: callback,
      identity: handoff.identity,
    );
    try {
      await configure(
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        deviceTracked: token.deviceTracked,
        baseUrl: baseUrl,
      );
      final result = await bindCurrentBilibiliAccount();
      await setEnabled(true);
      await syncNow();
      return result;
    } catch (_) {
      SynapseCredentialStore.delete();
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> bindCurrentBilibiliAccount() async {
    final account = Accounts.main;
    if (!account.isLogin || account.mid <= 0) {
      throw StateError('请先登录 B 站主账号');
    }
    final identity = await _ensureClientIdentity();
    final cookie = account.cookieJar.toList()
        .map((entry) => '${entry.name}=${entry.value}')
        .join('; ');
    final response = await _client().post<Object?>('uid', data: {
      'uid': account.mid.toString(),
      'cookie': cookie,
      'client_id': SynapseClientIdentity.clientId,
      'client_name': SynapseClientIdentity.clientName,
      'client_version': identity.clientVersion,
      'client_build': identity.buildNumber,
      'device_id': identity.deviceId,
      'device_name': identity.deviceName,
      'platform': identity.platform,
    });
    final data = _responseData(response);
    await _recordDeviceStatus(data);
    if (data['bound'] != true || data['uid']?.toString() != account.mid.toString()) {
      throw StateError('Synapse 返回的绑定账号与当前 B 站 UID 不一致');
    }
    await GStorage.setting.put(SettingBoxKey.synapseSyncBoundMid, account.mid);
    return data;
  }

  static Future<void> setEnabled(bool value) async {
    if (value) {
      if (!isConfigured || !Accounts.main.isLogin || Accounts.main.mid == 0) {
      throw StateError('请先完成 Synapse 授权并登录 B 站主账号');
      }
      await GStorage.setting.put(SettingBoxKey.synapseSyncBoundMid, Accounts.main.mid);
    }
    await GStorage.setting.put(SettingBoxKey.synapseSyncEnabled, value);
    if (value) _startWatchers();
  }

  static void scheduleSync() {
    if (!isEnabled || !isConfigured || !Accounts.main.isLogin || _syncWriteInProgress) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), () async {
      try {
        await syncNow();
      } on Object {
        // A later edit or manual sync can retry after a transient failure.
      }
    });
  }

  static void _startWatchers() {
    if (_watchersStarted) return;
    _watchersStarted = true;
    GStorage.setting.watch().listen((event) {
      if (event.key is String && event.key.toString().startsWith('synapse')) return;
      GStorage.setting.put(
        SettingBoxKey.synapseLocalSettingsChangedAt,
        DateTime.now().toUtc().toIso8601String(),
      );
      scheduleSync();
    });
    GStorage.historyWord.watch().listen((_) => scheduleSync());
  }

  static Future<void> clearCredentials() async {
    if (isConfigured) {
      try {
        await _ensureClientIdentity();
        await _client().delete<Object?>('uid');
      } on DioException {
        // Local credentials can still be cleared if the remote is unavailable.
      }
    }
    SynapseCredentialStore.delete();
    await GStorage.setting.put(SettingBoxKey.synapseSyncEnabled, false);
    await GStorage.setting.put(SettingBoxKey.synapseSyncBoundMid, 0);
    await GStorage.setting.put(SettingBoxKey.synapseDeviceTracked, false);
  }

  static Future<void> maybeShowStartupPrompt() async {
    if (_isRunning || !isEnabled || !isConfigured || Accounts.main.mid == 0 || boundMid != Accounts.main.mid) {
      return;
    }
    _isRunning = true;
    try {
      _startWatchers();
      if (!Accounts.main.isLogin) return;
      await _ensureClientIdentity();
      // Startup discovery is best-effort: bound it so an unreachable Synapse
      // server can never hold the post-first-frame startup / login restore.
      final remote = await fetchSnapshot().timeout(
        const Duration(seconds: 8),
      );
      if (remote.records.isEmpty && remote.settings == null) return;
      final navigator = await StartupOverlayCoordinator.waitForNavigator(
        debugLabel: 'Synapse-sync',
      );
      if (navigator == null || !navigator.mounted) return;
      final choice = await showDialog<SynapseSyncChoice>(
        context: navigator.context,
        builder: (context) => AlertDialog(
          title: const Text('发现 Synapse 云端数据'),
          content: const Text('是否合并到当前 B 站主账号？设置冲突可选择远端、本地或安全字段合并。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, SynapseSyncChoice.local), child: const Text('保留本地')),
            TextButton(onPressed: () => Navigator.pop(context, SynapseSyncChoice.remote), child: const Text('使用远端')),
            FilledButton(onPressed: () => Navigator.pop(context, SynapseSyncChoice.merge), child: const Text('安全合并')),
          ],
        ),
      );
      if (choice == null) return;
      await applyRemote(remote, choice);
    } catch (error, stackTrace) {
      // Startup discovery is best effort; a later manual sync can recover it.
      Persistence.background(Future<void>.error(error, stackTrace), label: 'Synapse startup discovery');
    } finally {
      _isRunning = false;
    }
  }

  static Future<SynapseRemoteSnapshot> fetchSnapshot() async {
    if (!Accounts.main.isLogin || Accounts.main.mid <= 0) throw StateError('Bilibili account is not logged in');
    await _ensureClientIdentity();
    final response = await _client().get<Object?>('search-records/changes', queryParameters: {
      'since': DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String(),
    });
    final settingsResponse = await _client().get<Object?>('settings');
    final data = _responseData(response);
    final settingsData = _responseData(settingsResponse);
    final records = (data['records'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
    return SynapseRemoteSnapshot(
      records: records,
      revision: (data['revision'] as num?)?.toInt() ?? 0,
      settings: settingsData['settings'] is Map
          ? Map<String, dynamic>.from(settingsData['settings'] as Map)
          : null,
      settingsVersion: (settingsData['version'] as num?)?.toInt() ?? 0,
      settingsUpdatedAt: settingsData['updatedAt']?.toString(),
    );
  }

  static Future<void> applyRemote(
    SynapseRemoteSnapshot remote,
    SynapseSyncChoice choice,
    {bool allowConflictPrompt = true,}
  ) async {
    final localSearch = SearchHistoryStore.read();
    final remoteSearch = <SearchHistoryEntry>[];
    final remoteSettings = remote.settings;
    for (final record in remote.records) {
      if (record['keyword'] != null) {
        final updatedAt = DateTime.tryParse(record['updatedAt']?.toString() ?? '');
        if (updatedAt != null) {
          remoteSearch.add(SearchHistoryEntry(
            id: record['id']?.toString() ?? '',
            keyword: record['keyword'].toString(),
            updatedAt: updatedAt.toUtc(),
            deleted: record['isDeleted'] == true,
          ));
        }
      }
    }
    _syncWriteInProgress = true;
    try {
      if (choice != SynapseSyncChoice.local) {
        await SearchHistoryStore.write(
          choice == SynapseSyncChoice.merge
              ? SearchHistoryStore.merge(localSearch, remoteSearch)
              : remoteSearch,
        );
        await GStorage.historyWord.put(
          'cacheList',
          SearchHistoryStore.visible().map((entry) => entry.keyword).toList(growable: false),
        );
        if (remoteSettings != null) {
          final values = _safeSettings(remoteSettings);
          if (choice == SynapseSyncChoice.merge) {
            final local = _safeSettings(GStorage.setting.toMap());
            values.addAll(local);
          }
          await GStorage.setting.putAll(values);
        }
      }
      await GStorage.setting.put(SettingBoxKey.synapseSettingsVersion, remote.settingsVersion);
      if (remote.settingsUpdatedAt != null) {
        await GStorage.setting.put(SettingBoxKey.synapseSettingsUpdatedAt, remote.settingsUpdatedAt);
      }
    } finally {
      _syncWriteInProgress = false;
    }
    await _upload(revision: remote.revision, allowConflictPrompt: allowConflictPrompt);
  }

  static Future<void> syncNow() async {
    if (!isEnabled || !isConfigured || boundMid != Accounts.main.mid) return;
    final remote = await fetchSnapshot();
    await applyRemote(remote, SynapseSyncChoice.merge);
  }

  static Future<void> _upload({required int revision, bool allowConflictPrompt = true}) async {
    await _ensureClientIdentity();
    final localRecords = SearchHistoryStore.read();
    final data = localRecords.isEmpty
        ? const <String, dynamic>{}
        : _responseData(await _client().post<Object?>('search-records/batch', data: {
            'records': [
              for (final entry in localRecords) {
                'id': entry.id,
                'keyword': entry.keyword,
                'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
                'isDeleted': entry.deleted,
                'deletedAt': entry.deleted ? entry.updatedAt.toUtc().toIso8601String() : null,
              },
            ],
          }));
    final settings = _safeSettings(GStorage.setting.toMap());
    Response<Object?> settingsResponse;
    try {
      settingsResponse = await _client().put<Object?>('settings', data: {
        'settings': settings,
        'baseVersion': (GStorage.setting.get(SettingBoxKey.synapseSettingsVersion) as num?)?.toInt() ?? 0,
        'includeSummary': true,
      });
    } on DioException catch (error) {
      if (!allowConflictPrompt || error.response?.statusCode != 409) rethrow;
      final remote = await fetchSnapshot();
      final navigator = await StartupOverlayCoordinator.waitForNavigator(debugLabel: 'Synapse-conflict');
      if (navigator == null || !navigator.mounted) return;
      final choice = await showDialog<SynapseSyncChoice>(
        context: navigator.context,
        builder: (context) => AlertDialog(
          title: const Text('Synapse 设置发生冲突'),
          content: const Text('检测到另一端刚刚修改了设置，请选择远端、本地或安全字段合并。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, SynapseSyncChoice.local), child: const Text('保留本地')),
            TextButton(onPressed: () => Navigator.pop(context, SynapseSyncChoice.remote), child: const Text('使用远端')),
            FilledButton(onPressed: () => Navigator.pop(context, SynapseSyncChoice.merge), child: const Text('安全合并')),
          ],
        ),
      );
      if (choice != null) {
        await applyRemote(remote, choice, allowConflictPrompt: false);
      }
      return;
    }
    final settingsData = _responseData(settingsResponse);
    _syncWriteInProgress = true;
    try {
      await Future.wait([
        GStorage.setting.put(SettingBoxKey.synapseSyncRevision, (settingsData['version'] as num?)?.toInt() ?? (data['revision'] as num?)?.toInt() ?? revision),
        GStorage.setting.put(SettingBoxKey.synapseSettingsVersion, (settingsData['version'] as num?)?.toInt() ?? 0),
        if (settingsData['updatedAt'] != null)
          GStorage.setting.put(SettingBoxKey.synapseSettingsUpdatedAt, settingsData['updatedAt'].toString()),
        GStorage.setting.put(SettingBoxKey.synapseLastSyncedAt, DateTime.now().toUtc().toIso8601String()),
      ]);
    } finally {
      _syncWriteInProgress = false;
    }
  }

  static Map<String, dynamic> _safeSettings(Map<dynamic, dynamic> source) {
    const excluded = {
      SettingBoxKey.synapseBaseUrl,
      SettingBoxKey.synapseSyncEnabled,
      SettingBoxKey.synapseSyncBoundMid,
      SettingBoxKey.synapseDeviceId,
      SettingBoxKey.synapseDeviceTracked,
      SettingBoxKey.synapseSyncRevision,
      SettingBoxKey.synapseLastSyncedAt,
      SettingBoxKey.synapseSettingsUpdatedAt,
      SettingBoxKey.synapseSettingsVersion,
      SettingBoxKey.synapseLocalSettingsChangedAt,
      SettingBoxKey.webdavPassword,
    };
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      final key = entry.key.toString();
      if (excluded.contains(key) || _isSensitiveKey(key)) continue;
      result[key] = _sanitizeValue(entry.value);
    }
    return result;
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value is Map) {
      return _safeSettings(value);
    }
    if (value is List) {
      return value.map(_sanitizeValue).toList(growable: false);
    }
    return value;
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.contains('password') ||
        normalized.contains('cookie') ||
        normalized.contains('token') ||
        normalized.contains('secret') ||
        normalized.contains('apikey') ||
        normalized.contains('accesskey') ||
        normalized.contains('privatekey');
  }

  static Dio _client() {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw const SynapseOAuthException(
        SynapseOAuthErrorCode.tokenExchangeFailed,
        'Synapse 会话已失效，请重新授权',
      );
    }
    final syncBaseUrl = _syncBaseUri(_parseBaseUrl(baseUrl));
    return Dio(BaseOptions(
      baseUrl: syncBaseUrl.toString().endsWith('/')
          ? syncBaseUrl.toString()
          : '${syncBaseUrl.toString()}/',
      headers: {
        'accept': 'application/json',
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
        ..._clientIdentity().requestHeaders,
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  static Uri _parseBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const SynapseOAuthException(
        SynapseOAuthErrorCode.invalidBaseUrl,
        'Synapse 地址必须是没有查询参数的 HTTPS URL',
      );
    }
    return uri;
  }

  static Uri _providerBaseUri(Uri value) {
    final path = _normalizedPath(value);
    if (!path.endsWith(_syncApiSuffix)) return value;
    final providerPath = path.substring(0, path.length - _syncApiSuffix.length);
    return value.replace(path: providerPath.isEmpty ? '' : providerPath);
  }

  static Uri _syncBaseUri(Uri value) {
    final path = _normalizedPath(value);
    if (path.endsWith(_syncApiSuffix)) return value;
    final provider = _providerBaseUri(value);
    final providerPath = _normalizedPath(provider);
    return provider.replace(path: '${providerPath.isEmpty ? '' : providerPath}$_syncApiSuffix');
  }

  static String _normalizedPath(Uri value) {
    final path = value.path.replaceFirst(RegExp(r'/+$'), '');
    return path == '/' ? '' : path;
  }

  static SynapseClientIdentity _clientIdentity() => SynapseClientIdentity(
    deviceId: deviceId ?? 'unregistered',
    platform: Platform.operatingSystem,
    clientVersion: BuildConfig.versionName,
    buildNumber: BuildConfig.versionCode,
  );

  static Future<SynapseClientIdentity> _ensureClientIdentity() async {
    final existing = deviceId;
    if (existing == null) {
      final generated = base64Url
          .encode(List<int>.generate(24, (_) => Random.secure().nextInt(256)))
          .replaceAll('=', '');
      await GStorage.setting.put(SettingBoxKey.synapseDeviceId, generated);
    }
    return _clientIdentity();
  }

  static String _shortDeviceId(String value) =>
      value.length <= 8 ? value : value.substring(0, 8);

  static void _storeRefreshToken(String? token) {
    final value = token?.trim();
    if (value == null || value.isEmpty) {
      SynapseCredentialStore.deleteRefreshToken();
    } else {
      SynapseCredentialStore.writeRefreshToken(value);
    }
  }

  static Future<void> _recordDeviceStatus(Map<String, dynamic> data) async {
    final tracked = _readDeviceTracked(data);
    if (tracked != null) {
      await GStorage.setting.put(SettingBoxKey.synapseDeviceTracked, tracked);
    }
  }

  static bool? _readDeviceTracked(Map<String, dynamic> data) {
    final direct = data['deviceTracked'] ??
        data['device_tracked'] ??
        data['deviceRegistered'] ??
        data['device_registered'];
    if (direct is bool) return direct;
    final device = data['device'];
    if (device is Map) {
      final nested = device['tracked'] ?? device['registered'];
      if (nested is bool) return nested;
    }
    return null;
  }

  static Future<SynapseOAuthToken> _exchangeOAuthToken({
    required Uri baseUrl,
    required _SynapseOAuthSession session,
    required SynapseOAuthCallback callback,
    required SynapseClientIdentity identity,
  }) async {
    final code = callback.code;
    if (code == null || code.isEmpty) {
      throw const SynapseOAuthException(
        SynapseOAuthErrorCode.invalidTokenResponse,
        'Synapse OAuth 回调缺少授权 code',
      );
    }
    final client = Dio(BaseOptions(
      baseUrl: baseUrl.toString().endsWith('/')
          ? baseUrl.toString()
          : '${baseUrl.toString()}/',
      headers: {
        'accept': 'application/json',
        'content-type': 'application/x-www-form-urlencoded',
        ...identity.requestHeaders,
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    try {
      final response = await client.post<Object?>(
        oauthTokenPath,
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': session.codeVerifier,
          ...identity.tokenParameters,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          extra: {'synapseSensitive': true},
        ),
      );
      final token = SynapseOAuthToken.fromResponse(response.data);
      if (token.deviceTracked != null) {
        await GStorage.setting.put(
          SettingBoxKey.synapseDeviceTracked,
          token.deviceTracked,
        );
      }
      return token;
    } on SynapseOAuthException {
      rethrow;
    } on FormatException catch (error) {
      throw SynapseOAuthException(
        SynapseOAuthErrorCode.invalidTokenResponse,
        'Synapse OAuth token 响应格式无效',
        serverCode: error.message,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw SynapseOAuthException(
        SynapseOAuthErrorCode.tokenExchangeFailed,
        status == null
            ? 'Synapse OAuth token 请求失败'
            : 'Synapse OAuth token 请求失败（HTTP $status）',
      );
    }
  }

  static Map<String, dynamic> _responseData(Response<Object?> response) {
    if (response.data is! Map) throw StateError('Synapse 返回格式无效');
    final body = Map<String, dynamic>.from(response.data as Map);
    if (body['success'] != true || body['data'] is! Map) {
      throw StateError(body['error']?.toString() ?? body['message']?.toString() ?? 'Synapse 请求失败');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

}

class SynapseSyncGate extends StatefulWidget {
  const SynapseSyncGate({required this.child, super.key});
  final Widget child;

  @override
  State<SynapseSyncGate> createState() => _SynapseSyncGateState();
}

final class _SynapseOAuthSession {
  _SynapseOAuthSession({
    required this.state,
    required this.codeVerifier,
    required this.codeChallenge,
  });

  final String state;
  final String codeVerifier;
  final String codeChallenge;

  factory _SynapseOAuthSession.create() {
    final codeVerifier = _randomUrlToken(64);
    return _SynapseOAuthSession(
      state: _randomUrlToken(32),
      codeVerifier: codeVerifier,
      codeChallenge: base64Url
          .encode(sha256.convert(utf8.encode(codeVerifier)).bytes)
          .replaceAll('=', ''),
    );
  }
}

String _randomUrlToken(int byteLength) => base64Url
    .encode(List<int>.generate(byteLength, (_) => Random.secure().nextInt(256)))
    .replaceAll('=', '');

final class _SynapseOAuthHandoff {
  _SynapseOAuthHandoff({
    required this.session,
    required this.identity,
  });

  final _SynapseOAuthSession session;
  final SynapseClientIdentity identity;
  final _resultCompleter = Completer<SynapseOAuthCallback>();
  StreamSubscription<SynapseOAuthCallback>? _callbackSubscription;
  bool _completed = false;

  static Future<_SynapseOAuthHandoff> start(Uri baseUrl) async {
    final handoff = _SynapseOAuthHandoff(
      session: _SynapseOAuthSession.create(),
      identity: await SynapseSyncService._ensureClientIdentity(),
    );
    await handoff._start(baseUrl);
    return handoff;
  }

  Future<SynapseOAuthCallback> get result async {
    try {
      return await _resultCompleter.future.timeout(
        SynapseSyncService._oauthTimeout,
        onTimeout: () => throw const SynapseOAuthException(
          SynapseOAuthErrorCode.callbackTimeout,
          '等待 Synapse-Client 回调超时',
        ),
      );
    } finally {
      await _callbackSubscription?.cancel();
    }
  }

  Future<void> _start(Uri baseUrl) async {
    _callbackSubscription = PiliScheme.pendingOAuthCallback.listen(_onCallback);
    final pending = PiliScheme.takePendingOAuthCallback(session.state);
    if (pending != null) _onCallback(pending);
    if (_completed) return;

    final authorizeUri = Uri(
      scheme: 'synapse',
      host: 'oauth',
      path: '/authorize',
      queryParameters: {
        ...identity.authorizeParameters,
        'response_type': 'code',
        'redirect_uri': SynapseSyncService.redirectUri,
        'state': session.state,
        'code_challenge': session.codeChallenge,
        'code_challenge_method': 'S256',
        'provider_origin': baseUrl.toString(),
      },
    );
    try {
      final launched = await launcher.launchUrl(
        authorizeUri,
        mode: launcher.LaunchMode.externalApplication,
      );
      if (!launched) {
        _completeError(const SynapseOAuthException(
          SynapseOAuthErrorCode.clientUnavailable,
          '未找到可处理 Synapse-Client 授权的应用',
        ));
      }
    } on Object {
      _completeError(const SynapseOAuthException(
        SynapseOAuthErrorCode.clientUnavailable,
        '无法启动 Synapse-Client 授权',
      ));
    }
  }

  void _onCallback(SynapseOAuthCallback callback) {
    if (_completed) return;
    PiliScheme.discardPendingOAuthCallback(callback);
    if (callback.state != session.state) {
      _completeError(const SynapseOAuthException(
        SynapseOAuthErrorCode.callbackStateMismatch,
        'Synapse OAuth 回调 state 不匹配',
      ));
      return;
    }
    _completed = true;
    _resultCompleter.complete(callback);
  }

  void _completeError(Object error, [StackTrace? stackTrace]) {
    if (_completed) return;
    _completed = true;
    _resultCompleter.completeError(error, stackTrace);
  }

  void cancel() {
    if (!_completed) {
      _completeError(const SynapseOAuthException(
        SynapseOAuthErrorCode.cancelled,
        'Synapse 授权已取消',
      ));
    }
    _callbackSubscription?.cancel();
  }
}

class _SynapseAuthorizationDialog extends StatefulWidget {
  const _SynapseAuthorizationDialog({required this.handoff});

  final _SynapseOAuthHandoff handoff;

  @override
  State<_SynapseAuthorizationDialog> createState() =>
      _SynapseAuthorizationDialogState();
}

class _SynapseAuthorizationDialogState
    extends State<_SynapseAuthorizationDialog> {
  @override
  void initState() {
    super.initState();
    _awaitCallback();
  }

  Future<void> _awaitCallback() async {
    try {
      final callback = await widget.handoff.result;
      if (mounted) Navigator.pop(context, callback);
    } on Object catch (error) {
      if (mounted) Navigator.pop(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('连接 Synapse-Client'),
    content: SizedBox(
      width: 400,
      height: 170,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_clock_outlined, size: 48),
          const SizedBox(height: 16),
          const Text(
            '请在 Synapse-Client 中确认授权',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '授权完成后会自动返回 PiliPlus，不会打开浏览器。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
    ],
  );
}

class _SynapseSyncGateState extends State<SynapseSyncGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SynapseSyncService.maybeShowStartupPrompt();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

