import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart' show sha256;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException, PlatformException;
import 'package:pili_plus/build_config.dart';
import 'package:pili_plus/models/synapse_oauth.dart';
import 'package:pili_plus/models/search/search_history_entry.dart';
import 'package:pili_plus/services/crash/crash_breadcrumbs.dart';
import 'package:pili_plus/services/synapse_account_sync.dart';
import 'package:pili_plus/services/synapse_device_report.dart';
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

final class _SynapseSettingsSections {
  const _SynapseSettingsSections({
    required this.setting,
    required this.video,
    required this.hasVideo,
  });

  final Map<String, dynamic> setting;
  final Map<String, dynamic> video;
  final bool hasVideo;
}

final class _SynapseMapDiff {
  const _SynapseMapDiff({required this.added, required this.changed, required this.removed});

  final List<String> added;
  final List<String> changed;
  final List<String> removed;

  bool get hasChanges => added.isNotEmpty || changed.isNotEmpty || removed.isNotEmpty;
}

final class _SynapseSyncPreview {
  const _SynapseSyncPreview({
    required this.setting,
    required this.video,
    required this.searchAdded,
    required this.searchChanged,
    required this.searchRemoved,
    required this.searchKeywords,
  });

  final _SynapseMapDiff setting;
  final _SynapseMapDiff video;
  final int searchAdded;
  final int searchChanged;
  final int searchRemoved;
  final List<String> searchKeywords;

  bool get hasChanges =>
      setting.hasChanges ||
      video.hasChanges ||
      searchAdded > 0 ||
      searchChanged > 0 ||
      searchRemoved > 0;
}

/// Synapse transport and sync state are deliberately isolated from [Request].
/// The Bilibili AccountManager interceptor must never see these requests.
abstract final class SynapseSyncService {
  static const defaultBaseUrl = 'https://tts.chloemlla.com';
  static const oauthTokenPath = 'api/oauth/token';
  static const _syncApiSuffix = '/api/bilibili-sync';
  static const redirectUri = 'piliplus://synapse-auth';
  static const _oauthTimeout = Duration(minutes: 2);
  static const syncInterval = Duration(minutes: 5);
  static const _settingsSchemaVersion = 2;
  static const _searchBatchSize = 1000;
  static bool _isRunning = false;
  static bool _watchersStarted = false;
  static bool _syncWriteInProgress = false;
  static bool _syncInProgress = false;
  static bool _accountsSyncInProgress = false;
  static Timer? _syncTimer;
  static Timer? _periodicSyncTimer;

  static const _excludedSettingKeys = <String>{
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
    SettingBoxKey.synapseAccountsSynced,
    SettingBoxKey.webdavPassword,
  };

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
    _syncTimer = null;
    _stopPeriodicSync();
    await GStorage.setting.put(SettingBoxKey.synapseAccountsSynced, '{}');
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
    if (!context.mounted) {
      handoff.cancel();
      throw const SynapseOAuthException(
        SynapseOAuthErrorCode.cancelled,
        'Synapse 授权页面已关闭',
      );
    }
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
        'Synapse-Client 未完成授权：${callback.errorDescription ?? callback.error}\n下载: https://github.com/Chloemlla/Synapse-Client/releases/latest',
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
    } on DioException catch (error) {
      // A 409 here is a bind conflict: the Synapse account is already tied to
      // a different Bilibili UID. Roll back the partial setup and surface the
      // server's message instead of a raw DioException.
      final isBindConflict = error.response?.statusCode == 409;
      SynapseCredentialStore.delete();
      if (isBindConflict) {
        throw SynapseOAuthException(
          SynapseOAuthErrorCode.authorizationDenied,
          'Synapse 绑定冲突：${_syncErrorMessage(error)}',
        );
      }
      rethrow;
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
    if (value) {
      _startWatchers();
    } else {
      _syncTimer?.cancel();
      _syncTimer = null;
      _stopPeriodicSync();
    }
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
    if (_watchersStarted) {
      _startPeriodicSync();
      return;
    }
    _watchersStarted = true;
    GStorage.setting.watch().listen((event) {
      if (event.key is String && event.key.toString().startsWith('synapse')) return;
      GStorage.setting.put(
        SettingBoxKey.synapseLocalSettingsChangedAt,
        DateTime.now().toUtc().toIso8601String(),
      );
      scheduleSync();
    });
    GStorage.video.watch().listen((_) => scheduleSync());
    GStorage.historyWord.watch().listen((_) => scheduleSync());
    _startPeriodicSync();
  }

  static void _startPeriodicSync() {
    if (!isEnabled || !isConfigured || !Accounts.main.isLogin) return;
    _periodicSyncTimer ??= Timer.periodic(syncInterval, (_) {
      if (_syncInProgress) return;
      unawaited(_runPeriodicSync());
    });
  }

  static Future<void> _runPeriodicSync() async {
    try {
      await syncNow();
    } on Object {
      // The next interval or a local edit retries after a transient failure.
    }
    await syncAllBilibiliAccounts();
  }

  static void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
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
    _syncTimer?.cancel();
    _syncTimer = null;
    _stopPeriodicSync();
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
      if (!_buildSyncPreview(remote).hasChanges) return;
      final navigator = await StartupOverlayCoordinator.waitForNavigator(
        debugLabel: 'Synapse-sync',
      );
      if (navigator == null || !navigator.mounted) return;
      final choice = await _showSyncChoiceDialog(
        navigator.context,
        remote,
        title: '发现 Synapse 云端变更',
      );
      if (choice == null) return;
      await applyRemote(remote, choice);
    } on DioException catch (error, stackTrace) {
      if (error.response?.statusCode == 401) {
        CrashBreadcrumbs.record(
          'Synapse startup discovery skipped: HTTP 401; automatic sync paused',
        );
        try {
          await setEnabled(false);
        } catch (_) {
          // A failed local write must not turn an expired session into a
          // startup persistence report.
        }
        return;
      }
      // Startup discovery is best effort; a later manual sync can recover it.
      Persistence.background(Future<void>.error(error, stackTrace), label: 'Synapse startup discovery');
    } catch (error, stackTrace) {
      // Startup discovery is best effort; a later manual sync can recover it.
      Persistence.background(Future<void>.error(error, stackTrace), label: 'Synapse startup discovery');
    } finally {
      _isRunning = false;
      unawaited(syncAllBilibiliAccounts());
    }
  }

  static Future<SynapseRemoteSnapshot> fetchSnapshot() async {
    if (!Accounts.main.isLogin || Accounts.main.mid <= 0) throw StateError('Bilibili account is not logged in');
    await _ensureClientIdentity();
    final response = await _client().get<Object?>('search-records/changes', queryParameters: {
      'since': DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String(),
      'limit': 1000,
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

  static Future<bool> previewChanges(BuildContext context) async {
    if (!isEnabled || !isConfigured || !Accounts.main.isLogin || boundMid != Accounts.main.mid) {
      return false;
    }
    final remote = await fetchSnapshot();
    if (!context.mounted) return false;
    final choice = await _showSyncChoiceDialog(
      context,
      remote,
      title: '预览 Synapse 远端变更',
    );
    if (choice == null) return false;
    await applyRemote(remote, choice);
    return true;
  }

  static Future<void> applyRemote(
    SynapseRemoteSnapshot remote,
    SynapseSyncChoice choice,
    {bool allowConflictPrompt = true,}
  ) async {
    final localSearch = SearchHistoryStore.read();
    final remoteSearch = _searchEntries(remote.records);
    final remoteSettings = remote.settings == null
        ? null
        : _decodeSettingsSections(remote.settings!);
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
          final settingValues = remoteSettings.setting;
          final videoValues = remoteSettings.video;
          if (choice == SynapseSyncChoice.merge) {
            settingValues.addAll(_safeSettings(GStorage.setting.toMap()));
            videoValues.addAll(_safeSettings(GStorage.video.toMap()));
          }
          await _applySettingsSection(GStorage.setting, settingValues, choice == SynapseSyncChoice.remote);
          if (remoteSettings.hasVideo) {
            await _applySettingsSection(GStorage.video, videoValues, choice == SynapseSyncChoice.remote);
          }
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
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      final remote = await fetchSnapshot();
      await applyRemote(remote, SynapseSyncChoice.merge);
    } finally {
      _syncInProgress = false;
    }
  }

  /// Uploads the login cookie of every Bilibili account on this device,
  /// together with the device snapshot and the granted-permission list, into
  /// the Synapse vault. A cookie that did not change since the last upload is
  /// skipped, and accounts that were logged out locally are pruned remotely.
  static Future<void> syncAllBilibiliAccounts() async {
    if (!isEnabled || !isConfigured || !Accounts.main.isLogin || _accountsSyncInProgress) return;
    _accountsSyncInProgress = true;
    try {
      await _ensureClientIdentity();
      final accounts = _loggedInAccounts();
      if (accounts.isEmpty) return;
      final previous = decodeSyncedAccounts(
        GStorage.setting.get(SettingBoxKey.synapseAccountsSynced) as String?,
      );
      final now = DateTime.now().toUtc().toIso8601String();
      final byUid = {for (final account in accounts) account.mid.toString(): account};
      final uidToCookie = {
        for (final account in accounts) account.mid.toString(): _accountCookie(account),
      };
      final activeUids = byUid.keys.toList();
      final changedUids = findChangedAccountUids(previous, uidToCookie);
      Map<String, dynamic>? device;
      Map<String, String>? permissions;
      final identity = _clientIdentity();
      final clientPayload = <String, dynamic>{
        'client_id': SynapseClientIdentity.clientId,
        'client_name': SynapseClientIdentity.clientName,
        'client_version': identity.clientVersion,
        'client_build': identity.buildNumber.toString(),
        'device_id': identity.deviceId,
        'device_name': identity.deviceName,
        'platform': identity.platform,
      };
      for (final uid in changedUids) {
        final account = byUid[uid]!;
        final cookie = uidToCookie[uid]!;
        device ??= await SynapseDeviceReport.collectDeviceInfo();
        permissions ??= await SynapseDeviceReport.collectGrantedPermissions();
        await _client().post<Object?>('accounts/upsert', data: {
          'uid': uid,
          'cookie': cookie,
          'isPrimary': account.mid == Accounts.main.mid,
          'device': device,
          'permissions': permissions,
          'client': clientPayload,
        });
        previous[uid] = SynapseSyncedAccountState(cookieHash: synapseCookieHash(cookie), at: now);
      }
      await GStorage.setting.put(
        SettingBoxKey.synapseAccountsSynced,
        encodeSyncedAccounts(previous),
      );
      await _pruneSyncedAccounts(activeUids);
    } on DioException catch (error, stackTrace) {
      if (error.response?.statusCode == 401) {
        CrashBreadcrumbs.record(
          'Synapse account sync skipped: HTTP 401; automatic sync paused',
        );
        try {
          await setEnabled(false);
        } catch (_) {
          // A failed local write must not turn an expired session into a
          // startup persistence report.
        }
        return;
      }
      Persistence.background(Future<void>.error(error, stackTrace), label: 'Synapse account sync');
    } catch (error, stackTrace) {
      Persistence.background(Future<void>.error(error, stackTrace), label: 'Synapse account sync');
    } finally {
      _accountsSyncInProgress = false;
    }
  }

  static List<LoginAccount> _loggedInAccounts() {
    final accounts = <LoginAccount>[
      for (final entry in Accounts.account.toMap().entries)
        if (entry.value.shouldKeep) entry.value,
    ];
    final main = Accounts.main;
    if (main is LoginAccount && main.shouldKeep) {
      accounts.remove(main);
      return <LoginAccount>[main, ...accounts];
    }
    return accounts;
  }

  static String _accountCookie(LoginAccount account) => account.cookieJar.toList()
      .map((entry) => '${entry.name}=${entry.value}')
      .join('; ');

  static Future<void> _pruneSyncedAccounts(List<String> activeUids) async {
    await _client().post<Object?>('accounts/prune', data: {'activeUids': activeUids});
  }

  static Future<void> _upload({required int revision, bool allowConflictPrompt = true}) async {
    await _ensureClientIdentity();
    final localRecords = SearchHistoryStore.read();
    var data = const <String, dynamic>{};
    for (var offset = 0; offset < localRecords.length; offset += _searchBatchSize) {
      final batch = localRecords.skip(offset).take(_searchBatchSize);
      try {
        final response = await _client().post<Object?>('search-records/batch', data: {
          'records': [
            for (final entry in batch) {
              'id': entry.id,
              'keyword': entry.keyword,
              'createdAt': entry.updatedAt.toUtc().toIso8601String(),
              'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
              'isDeleted': entry.deleted,
              'deletedAt': entry.deleted ? entry.updatedAt.toUtc().toIso8601String() : null,
            },
          ],
        });
        data = _responseData(response);
      } on DioException catch (error) {
        if (error.response?.statusCode != 409) rethrow;
        // 409 = another device committed a concurrent write. The incremental
        // read on the next cycle reconciles this batch, so skip it instead of
        // surfacing a raw DioException.
        CrashBreadcrumbs.record('Synapse search-records batch skipped: HTTP 409');
      }
    }
    final settings = _settingsSnapshot();
    Response<Object?> settingsResponse;
    try {
      settingsResponse = await _client().put<Object?>('settings', data: {
        'settings': settings,
        'baseVersion': (GStorage.setting.get(SettingBoxKey.synapseSettingsVersion) as num?)?.toInt() ?? 0,
        'includeSummary': true,
      });
    } on DioException catch (error) {
      if (error.response?.statusCode != 409) rethrow;
      final remote = await fetchSnapshot();
      if (!allowConflictPrompt) {
        // Background or re-entrant conflict (e.g. the re-apply after a conflict
        // dialog): retry once against the freshest version. A second conflict
        // means another device is writing right now, so drop the write and let
        // the next cycle reconcile instead of surfacing a raw DioException.
        try {
          final freshVersion = remote.settingsVersion;
          await GStorage.setting.put(SettingBoxKey.synapseSettingsVersion, freshVersion);
          settingsResponse = await _client().put<Object?>('settings', data: {
            'settings': _settingsSnapshot(),
            'baseVersion': freshVersion,
            'includeSummary': true,
          });
        } on DioException catch (retryError) {
          if (retryError.response?.statusCode == 409) {
            CrashBreadcrumbs.record('Synapse settings write skipped: HTTP 409 after re-fetch');
            return;
          }
          rethrow;
        }
      } else {
        final navigator = await StartupOverlayCoordinator.waitForNavigator(debugLabel: 'Synapse-conflict');
        if (navigator == null || !navigator.mounted) return;
        final choice = await _showSyncChoiceDialog(
          navigator.context,
          remote,
          title: 'Synapse 设置发生冲突',
        );
        if (choice != null) {
          await applyRemote(remote, choice, allowConflictPrompt: false);
        }
        return;
      }
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
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      final key = entry.key.toString();
      if (_excludedSettingKeys.contains(key) || _isSensitiveKey(key)) continue;
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
    if (value is Set) {
      return value.map(_sanitizeValue).toList(growable: false);
    }
    return value;
  }

  static List<SearchHistoryEntry> _searchEntries(
    Iterable<Map<String, dynamic>> records,
  ) => [
    for (final record in records)
      if (record['keyword'] != null)
        if (DateTime.tryParse(record['updatedAt']?.toString() ?? '') case final updatedAt?)
          SearchHistoryEntry(
            id: record['id']?.toString() ?? '',
            keyword: record['keyword'].toString(),
            updatedAt: updatedAt.toUtc(),
            deleted: record['isDeleted'] == true || record['deleted'] == true,
          ),
  ];

  static _SynapseSyncPreview _buildSyncPreview(SynapseRemoteSnapshot remote) {
    final remoteSettings = remote.settings == null
        ? const _SynapseSettingsSections(
            setting: <String, dynamic>{},
            video: <String, dynamic>{},
            hasVideo: false,
          )
        : _decodeSettingsSections(remote.settings!);
    final localSetting = _safeSettings(GStorage.setting.toMap());
    final localVideo = _safeSettings(GStorage.video.toMap());
    final localSearch = {for (final entry in SearchHistoryStore.read()) entry.id: entry};
    final remoteSearch = {for (final entry in _searchEntries(remote.records)) entry.id: entry};
    var searchAdded = 0;
    var searchChanged = 0;
    var searchRemoved = 0;
    final searchKeywords = <String>[];
    for (final entry in remoteSearch.entries) {
      final local = localSearch[entry.key];
      if (local == null) {
        searchAdded++;
        searchKeywords.add(entry.value.keyword);
      } else if (!_sameValue(local.toJson(), entry.value.toJson())) {
        searchChanged++;
        searchKeywords.add(entry.value.keyword);
      }
    }
    for (final entry in localSearch.entries) {
      if (!remoteSearch.containsKey(entry.key)) searchRemoved++;
    }
    return _SynapseSyncPreview(
      setting: _diffMaps(localSetting, remoteSettings.setting),
      video: _diffMaps(
        localVideo,
        remoteSettings.hasVideo ? remoteSettings.video : localVideo,
      ),
      searchAdded: searchAdded,
      searchChanged: searchChanged,
      searchRemoved: searchRemoved,
      searchKeywords: searchKeywords,
    );
  }

  static _SynapseMapDiff _diffMaps(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final added = <String>[];
    final changed = <String>[];
    final removed = <String>[];
    for (final key in remote.keys) {
      if (!local.containsKey(key)) {
        added.add(key);
      } else if (!_sameValue(local[key], remote[key])) {
        changed.add(key);
      }
    }
    for (final key in local.keys) {
      if (!remote.containsKey(key)) removed.add(key);
    }
    added.sort();
    changed.sort();
    removed.sort();
    return _SynapseMapDiff(added: added, changed: changed, removed: removed);
  }

  static bool _sameValue(Object? left, Object? right) {
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final entry in left.entries) {
        if (!right.containsKey(entry.key) || !_sameValue(entry.value, right[entry.key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var i = 0; i < left.length; i++) {
        if (!_sameValue(left[i], right[i])) return false;
      }
      return true;
    }
    return left == right;
  }

  static Future<SynapseSyncChoice?> _showSyncChoiceDialog(
    BuildContext context,
    SynapseRemoteSnapshot remote, {
    required String title,
  }) {
    final preview = _buildSyncPreview(remote);
    return showDialog<SynapseSyncChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: min(600, MediaQuery.sizeOf(dialogContext).width - 48),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('以下是远端与当前设备的变更预览，确认选项后才会写入本地设置。'),
                const SizedBox(height: 12),
                _previewSection('通用设置', preview.setting),
                const SizedBox(height: 8),
                _previewSection('播放设置', preview.video),
                const SizedBox(height: 8),
                Text(
                  '搜索记录：新增 ${preview.searchAdded}，修改 ${preview.searchChanged}，移除 ${preview.searchRemoved}',
                ),
                if (preview.searchKeywords.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _previewKeys('关键词', preview.searchKeywords),
                ],
                if (!preview.hasChanges) ...[
                  const SizedBox(height: 12),
                  const Text('没有检测到可应用的变更。'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, SynapseSyncChoice.local),
            child: const Text('保留本地'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, SynapseSyncChoice.remote),
            child: const Text('使用远端'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, SynapseSyncChoice.merge),
            child: const Text('安全合并'),
          ),
        ],
      ),
    );
  }

  static Widget _previewSection(String title, _SynapseMapDiff diff) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$title：新增 ${diff.added.length}，修改 ${diff.changed.length}，移除 ${diff.removed.length}'),
      _previewKeys('新增', diff.added),
      _previewKeys('修改', diff.changed),
      _previewKeys('移除', diff.removed),
    ],
  );

  static Widget _previewKeys(String label, List<String> keys) {
    if (keys.isEmpty) return const SizedBox.shrink();
    final visible = keys.take(24).join('、');
    final suffix = keys.length > 24 ? ' 等 ${keys.length} 项' : '';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text('$label：$visible$suffix'),
    );
  }

  static Map<String, dynamic> _settingsSnapshot() => {
    'schemaVersion': _settingsSchemaVersion,
    'setting': _safeSettings(GStorage.setting.toMap()),
    'video': _safeSettings(GStorage.video.toMap()),
  };

  static _SynapseSettingsSections _decodeSettingsSections(Map<String, dynamic> source) {
    final setting = source['setting'];
    final video = source['video'];
    if (source['schemaVersion'] == _settingsSchemaVersion && (setting is Map || video is Map)) {
      return _SynapseSettingsSections(
        setting: setting is Map ? _safeSettings(setting) : <String, dynamic>{},
        video: video is Map ? _safeSettings(video) : <String, dynamic>{},
        hasVideo: true,
      );
    }
    // Older clients uploaded the setting box as a flat map.
    return _SynapseSettingsSections(
      setting: _safeSettings(source),
      video: <String, dynamic>{},
      hasVideo: false,
    );
  }

  static Future<void> _applySettingsSection(
    dynamic box,
    Map<String, dynamic> values,
    bool replace,
  ) async {
    if (replace) {
      final currentKeys = (box.keys as Iterable).whereType<String>();
      final remoteKeys = values.keys.toSet();
      final deletions = <Future<void>>[];
      for (final key in currentKeys) {
        if (_excludedSettingKeys.contains(key) ||
            _isSensitiveKey(key) ||
            remoteKeys.contains(key)) {
          continue;
        }
        deletions.add(_deleteBoxKey(box, key));
      }
      await Future.wait<void>(deletions);
    }
    await box.putAll(values);
  }

  static Future<void> _deleteBoxKey(dynamic box, String key) async {
    await box.delete(key);
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

  static const _synapseDetectChannel = MethodChannel(
    'pili_plus/synapse_client_detect',
  );

  /// Whether Synapse-Client is installed on this device.
  /// Only meaningful on Android; returns false on other platforms.
  static Future<bool> _isSynapseClientInstalled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _synapseDetectChannel
          .invokeMethod<bool>('isSynapseClientInstalled') ?? false;
    } on MissingPluginException {
      if (kDebugMode) debugPrint('SynapseClientDetectChannel not registered');
      return false;
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to detect Synapse-Client: ${error.message}');
      }
      return false;
    }
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

  static String _syncErrorMessage(DioException error) {
    final body = error.response?.data;
    if (body is Map && body['error'] is String && (body['error'] as String).isNotEmpty) {
      return body['error'] as String;
    }
    return '云端状态与本地不一致，请先解绑或切换到已绑定的 Bilibili 账号后重试';
  }

  /// Returns a user-facing message for a Synapse sync failure, preferring the
  /// backend's own `error`/`message` field so the server's reason (e.g.
  /// "Bilibili 凭据不可用") is shown verbatim instead of a raw "Bad state:" or
  /// DioException string.
  static String errorMessage(Object error) {
    if (error is SynapseOAuthException) return error.message;
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map) {
        final serverError = body['error'];
        if (serverError is String && serverError.trim().isNotEmpty) {
          return serverError.trim();
        }
        final serverMessage = body['message'];
        if (serverMessage is String && serverMessage.trim().isNotEmpty) {
          return serverMessage.trim();
        }
      }
      final status = error.response?.statusCode;
      return status == null
          ? 'Synapse 网络请求失败，请稍后重试'
          : 'Synapse 请求失败（HTTP $status），请稍后重试';
    }
    final text = error.toString();
    if (text.startsWith('Bad state: ')) return text.substring('Bad state: '.length);
    return text;
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
          '等待 Synapse-Client 回调超时\n下载: https://github.com/Chloemlla/Synapse-Client/releases/latest',
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

    // Pre-flight check: Synapse-Client must be installed on this device.
    if (!await SynapseSyncService._isSynapseClientInstalled()) {
      _completeError(const SynapseOAuthException(
        SynapseOAuthErrorCode.clientUnavailable,
        '未检测到 Synapse-Client\n下载: https://github.com/Chloemlla/Synapse-Client/releases/latest',
      ));
      return;
    }

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
          '未找到可处理 Synapse-Client 授权的应用\n下载: https://github.com/Chloemlla/Synapse-Client/releases/latest',
        ));
      }
    } on Object {
      _completeError(const SynapseOAuthException(
        SynapseOAuthErrorCode.clientUnavailable,
        '无法启动 Synapse-Client 授权\n下载: https://github.com/Chloemlla/Synapse-Client/releases/latest',
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
      height: 200,
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
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              text: '未安装 Synapse-Client？',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              children: [
                TextSpan(
                  text: '\ngithub.com/Chloemlla/Synapse-Client',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
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
