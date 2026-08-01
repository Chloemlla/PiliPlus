import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as web;
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:pili_plus/main.dart' as app;
import 'package:pili_plus/models/search/search_history_entry.dart';
import 'package:pili_plus/services/startup_overlay_coordinator.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/persistence.dart';
import 'package:pili_plus/utils/setting_secret_store.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:pili_plus/utils/storage/search_history_store.dart';

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
  static const defaultBaseUrl = 'https://tts.chloemlla.com/api/bilibili-sync';
  static const _accessToken = 'accessToken';
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

  static String? get accessToken => SettingSecretStore.readSynapse(_accessToken);

  static bool get isConfigured => accessToken?.isNotEmpty == true;

  static Future<void> disableForLogout() async {
    _syncTimer?.cancel();
  }

  static Future<void> configure({
    required String accessToken,
    required String baseUrl,
  }) async {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Synapse 地址必须是 HTTPS URL');
    }
    if (Accounts.main.mid == 0) {
      throw StateError('请先登录 B 站主账号');
    }
    await Future.wait([
      Future<void>.sync(() => SettingSecretStore.writeSynapse(_accessToken, accessToken.trim())),
      GStorage.setting.put(SettingBoxKey.synapseBaseUrl, uri.toString().replaceFirst(RegExp(r'/$'), '')),
      GStorage.setting.put(SettingBoxKey.synapseSyncBoundMid, Accounts.main.mid),
    ]);
    _startWatchers();
  }

  static Future<Map<String, dynamic>> authorizeAndBind(BuildContext context, {required String baseUrl}) async {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Synapse 地址必须是 HTTPS URL');
    }
    final token = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SynapseAuthorizationDialog(
        loginUrl: uri.replace(path: '/login', query: '', fragment: '').toString(),
      ),
    );
    if (token == null || token.isEmpty) throw StateError('Synapse 登录未完成');
    try {
      await configure(accessToken: token, baseUrl: baseUrl);
      final result = await bindCurrentBilibiliAccount();
      await setEnabled(true);
      await syncNow();
      return result;
    } catch (_) {
      SettingSecretStore.deleteSynapse(_accessToken);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> bindCurrentBilibiliAccount() async {
    final account = Accounts.main;
    if (!account.isLogin || account.mid <= 0) {
      throw StateError('请先登录 B 站主账号');
    }
    final cookie = account.cookieJar.toJson().entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
    final response = await _client().post<Object?>('uid', data: {
      'uid': account.mid.toString(),
      'cookie': cookie,
    });
    final data = _responseData(response);
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
        await _client().delete<Object?>('uid');
      } on DioException {
        // Local credentials can still be cleared if the remote is unavailable.
      }
    }
    SettingSecretStore.deleteSynapse(_accessToken);
    await GStorage.setting.put(SettingBoxKey.synapseSyncEnabled, false);
    await GStorage.setting.put(SettingBoxKey.synapseSyncBoundMid, 0);
  }

  static Future<void> maybeShowStartupPrompt() async {
    if (_isRunning || !isEnabled || !isConfigured || Accounts.main.mid == 0 || boundMid != Accounts.main.mid) {
      return;
    }
    _isRunning = true;
    try {
      _startWatchers();
      if (!Accounts.main.isLogin) return;
      final remote = await fetchSnapshot();
      if (remote.records.isEmpty && remote.settings == null) return;
      final navigator = await StartupOverlayCoordinator.waitForNavigator(
        debugLabel: 'Synapse-sync',
      );
      if (navigator == null) return;
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
    final response = await _client().get<Object?>('search-records/changes', queryParameters: {
      'since': DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String(),
    });
    final settingsResponse = await _client().get<Object?>('settings');
    final data = _responseData(response);
    final settingsData = _responseData(settingsResponse);
    final records = (data['records'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
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

  static Dio _client() => Dio(BaseOptions(
    baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
    headers: {
      'accept': 'application/json',
      'content-type': 'application/json',
      'authorization': 'Bearer ${accessToken!}',
    },
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

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

class _SynapseAuthorizationDialog extends StatefulWidget {
  const _SynapseAuthorizationDialog({required this.loginUrl});

  final String loginUrl;

  @override
  State<_SynapseAuthorizationDialog> createState() => _SynapseAuthorizationDialogState();
}

class _SynapseAuthorizationDialogState extends State<_SynapseAuthorizationDialog> {
  web.InAppWebViewController? _controller;
  Timer? _poller;
  bool _checking = false;
  bool _completed = false;

  Future<void> _readSession() async {
    if (_checking || _completed) return;
    _checking = true;
    try {
      final cookies = await web.CookieManager.instance(
        webViewEnvironment: app.webViewEnvironment,
      ).getCookies(
        url: web.WebUri(widget.loginUrl),
      );
      final token = cookies
          .where((cookie) => cookie.name == 'synapse_token')
          .map((cookie) => cookie.value.trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (token.isNotEmpty && mounted) {
        _completed = true;
        Navigator.pop(context, token);
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _poller = Timer.periodic(const Duration(seconds: 1), (_) => _readSession());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('登录 Synapse'),
        content: SizedBox(
          width: 520,
          height: 640,
          child: web.InAppWebView(
            webViewEnvironment: app.webViewEnvironment,
            initialSettings: web.InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true,
              thirdPartyCookiesEnabled: true,
            ),
            initialUrlRequest: web.URLRequest(url: web.WebUri(widget.loginUrl)),
            onWebViewCreated: (controller) => _controller = controller,
            onLoadStop: (_, __) => _readSession(),
            onUpdateVisitedHistory: (_, __, ___) => _readSession(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
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

