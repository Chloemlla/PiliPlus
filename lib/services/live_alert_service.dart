import 'dart:async';

import 'package:hive_ce/hive.dart';
import 'package:pili_plus/models/live_keyword_rule.dart';
import 'package:pili_plus/services/live_alert_data_source.dart';
import 'package:pili_plus/services/live_alert_decision.dart';
import 'package:pili_plus/services/live_alert_notification_service.dart';
import 'package:pili_plus/utils/accounts.dart';

class LiveAlertService {
  LiveAlertService._({
    LiveAlertStatusSource? statusSource,
    LiveAlertNotificationGateway? notificationGateway,
    DateTime Function()? clock,
  }) : _statusSource = statusSource ?? BiliLiveAlertStatusSource(),
       _notificationGateway =
           notificationGateway ?? LiveAlertNotificationService.instance,
       _clock = clock ?? DateTime.now;

  static final LiveAlertService instance = LiveAlertService._();

  static const String boxName = 'liveKeywordRules';
  static const String notificationHistoryBoxName = 'liveAlertLastNotified';
  static const Duration rateLimit = Duration(hours: 4);
  static const Duration pollingInterval = Duration(minutes: 15);

  final LiveAlertStatusSource _statusSource;
  final LiveAlertNotificationGateway _notificationGateway;
  final DateTime Function() _clock;

  Box<LiveKeywordRule>? _box;
  Box<int>? _notificationHistoryBox;
  Future<void>? _initializing;
  Timer? _pollingTimer;
  bool _isInitialized = false;
  bool _pollInFlight = false;
  bool _pollingEnabled = false;
  int _pollGeneration = 0;

  bool get isInitialized => _isInitialized;
  bool get isPolling => _pollingTimer?.isActive == true;
  bool get hasActiveAccount => currentAccountMid > 0;
  int get currentAccountMid => Accounts.main.isLogin ? Accounts.main.mid : 0;

  Box<LiveKeywordRule> get _rulesBox =>
      _box ?? (throw StateError('LiveAlertService is not initialized'));

  Box<int> get _historyBox =>
      _notificationHistoryBox ??
      (throw StateError('LiveAlertService is not initialized'));

  Future<void> init() {
    if (_isInitialized) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (!Hive.isAdapterRegistered(101)) {
        Hive.registerAdapter(LiveKeywordRuleAdapter());
      }
      _box = await Hive.openBox<LiveKeywordRule>(boxName);
      _notificationHistoryBox = await Hive.openBox<int>(
        notificationHistoryBoxName,
      );
      await _notificationGateway.init();
      _isInitialized = true;
      await activateCurrentAccount();
    } finally {
      _initializing = null;
    }
  }

  Future<void> activateCurrentAccount() async {
    if (!_isInitialized) return;
    final accountMid = currentAccountMid;
    if (accountMid <= 0) return;

    final legacyUpdates = <dynamic, LiveKeywordRule>{};
    for (final entry in _rulesBox.toMap().entries) {
      if (entry.value.accountMid == 0) {
        legacyUpdates[entry.key] = entry.value.copyWith(accountMid: accountMid);
      }
    }
    if (legacyUpdates.isNotEmpty) {
      await _rulesBox.putAll(legacyUpdates);
    }

    final latestByMid = <int, int>{};
    for (final rule in _rulesForAccount(accountMid)) {
      if (rule.lastNotifiedAt > (latestByMid[rule.mid] ?? 0)) {
        latestByMid[rule.mid] = rule.lastNotifiedAt;
      }
    }
    for (final entry in latestByMid.entries) {
      final key = _historyKey(accountMid, entry.key);
      if (entry.value > (_historyBox.get(key) ?? 0)) {
        await _historyBox.put(key, entry.value);
      }
    }
  }

  void startPolling() {
    if (!_isInitialized) return;
    stopPolling();
    _pollingEnabled = true;
    _pollGeneration++;
    unawaited(_notificationGateway.flushPendingNavigation());
    unawaited(checkLiveStatus());
    _pollingTimer = Timer.periodic(
      pollingInterval,
      (_) => unawaited(checkLiveStatus()),
    );
  }

  void stopPolling() {
    _pollingEnabled = false;
    _pollGeneration++;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> checkLiveStatus() async {
    if (!_isInitialized || !_pollingEnabled || _pollInFlight) return;
    final pollGeneration = _pollGeneration;
    _pollInFlight = true;
    try {
      await activateCurrentAccount();
      final accountMid = currentAccountMid;
      if (!_isCurrentPoll(pollGeneration, accountMid)) return;

      final mids = _rulesForAccount(
        accountMid,
      ).where((rule) => rule.enabled).map((rule) => rule.mid).toSet();
      for (final mid in mids) {
        if (!_isCurrentPoll(pollGeneration, accountMid)) return;
        await _checkUpLiveStatus(
          accountMid: accountMid,
          mid: mid,
          pollGeneration: pollGeneration,
        );
      }
    } on Exception {
      return;
    } finally {
      _pollInFlight = false;
      if (_pollingEnabled && pollGeneration != _pollGeneration) {
        unawaited(checkLiveStatus());
      }
    }
  }

  Future<void> _checkUpLiveStatus({
    required int accountMid,
    required int mid,
    required int pollGeneration,
  }) async {
    final historyKey = _historyKey(accountMid, mid);
    final nowSeconds = _clock().millisecondsSinceEpoch ~/ 1000;
    if (isLiveAlertRateLimited(
      lastNotifiedAt: _historyBox.get(historyKey) ?? 0,
      nowSeconds: nowSeconds,
      cooldown: rateLimit,
    )) {
      return;
    }

    final snapshot = await _statusSource.resolveByMid(mid);
    if (snapshot == null || !_isCurrentPoll(pollGeneration, accountMid)) {
      return;
    }

    final rules = _rulesForAccount(
      accountMid,
    ).where((rule) => rule.mid == mid).toList();
    final decision = chooseLiveAlertDecision(
      rules: rules,
      snapshot: snapshot,
    );
    if (decision == null) return;

    final upName = snapshot.upName.isNotEmpty
        ? snapshot.upName
        : decision.rule.upName;
    final didShow = await _notificationGateway.showLiveAlert(
      accountMid: accountMid,
      mid: mid,
      roomId: snapshot.roomId,
      upName: upName,
      streamTitle: snapshot.title,
      matchedKeyword: decision.matchedKeyword,
    );
    if (!didShow) return;

    await _markNotified(
      accountMid: accountMid,
      mid: mid,
      notifiedAt: nowSeconds,
    );
  }

  Future<void> _markNotified({
    required int accountMid,
    required int mid,
    required int notifiedAt,
  }) async {
    await _historyBox.put(_historyKey(accountMid, mid), notifiedAt);
    final updates = <dynamic, LiveKeywordRule>{};
    for (final entry in _rulesBox.toMap().entries) {
      final rule = entry.value;
      if (rule.accountMid == accountMid && rule.mid == mid) {
        updates[entry.key] = rule.copyWith(lastNotifiedAt: notifiedAt);
      }
    }
    if (updates.isNotEmpty) await _rulesBox.putAll(updates);
  }

  List<LiveKeywordRule> getAllRules() {
    if (!_isInitialized || currentAccountMid <= 0) return const [];
    return _rulesForAccount(currentAccountMid)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<LiveKeywordRule> _rulesForAccount(int accountMid) =>
      _rulesBox.values.where((rule) => rule.accountMid == accountMid).toList();

  Future<LiveAlertRoomSnapshot?> resolveUp(int mid) =>
      _statusSource.resolveByMid(mid);

  Future<bool> addRule(LiveKeywordRule rule) async {
    final accountMid = currentAccountMid;
    if (!_isInitialized || accountMid <= 0 || !_isValidRule(rule)) {
      return false;
    }
    await _rulesBox.put(rule.id, rule.copyWith(accountMid: accountMid));
    return true;
  }

  Future<bool> updateRule(LiveKeywordRule rule) async {
    final accountMid = currentAccountMid;
    if (!_isInitialized || accountMid <= 0 || !_isValidRule(rule)) {
      return false;
    }
    final existing = _rulesBox.get(rule.id);
    if (existing == null || existing.accountMid != accountMid) return false;
    await _rulesBox.put(rule.id, rule.copyWith(accountMid: accountMid));
    return true;
  }

  Future<bool> deleteRule(String ruleId) async {
    final accountMid = currentAccountMid;
    if (!_isInitialized || accountMid <= 0) return false;
    final existing = _rulesBox.get(ruleId);
    if (existing == null || existing.accountMid != accountMid) return false;
    await _rulesBox.delete(ruleId);
    return true;
  }

  Future<bool> toggleRule(String ruleId) async {
    final accountMid = currentAccountMid;
    if (!_isInitialized || accountMid <= 0) return false;
    final rule = _rulesBox.get(ruleId);
    if (rule == null || rule.accountMid != accountMid) return false;
    await _rulesBox.put(ruleId, rule.copyWith(enabled: !rule.enabled));
    return true;
  }

  String generateRuleId() =>
      '${currentAccountMid}_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> clearAllData() async {
    await init();
    stopPolling();
    await Future.wait([
      _rulesBox.clear(),
      _historyBox.clear(),
    ]);
  }

  Future<void> close() async {
    stopPolling();
    await _box?.close();
    await _notificationHistoryBox?.close();
    _box = null;
    _notificationHistoryBox = null;
    _isInitialized = false;
  }

  static String _historyKey(int accountMid, int mid) => '$accountMid:$mid';

  static bool _isValidRule(LiveKeywordRule rule) =>
      rule.id.trim().isNotEmpty &&
      rule.mid > 0 &&
      rule.keyword.trim().isNotEmpty &&
      rule.matchTargetIndex >= 0 &&
      rule.matchTargetIndex < MatchTarget.values.length;

  bool _isCurrentPoll(int generation, int accountMid) =>
      _pollingEnabled &&
      generation == _pollGeneration &&
      accountMid > 0 &&
      currentAccountMid == accountMid;
}
