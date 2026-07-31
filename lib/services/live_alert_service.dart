import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_ce/hive.dart';
import 'package:pili_plus/http/live.dart';
import 'package:pili_plus/models/live_keyword_rule.dart';
import 'package:pili_plus/models_new/live/live_room_info_h5/data.dart';
import 'package:pili_plus/utils/accounts.dart';

class LiveAlertService {
  LiveAlertService._();

  static final LiveAlertService instance = LiveAlertService._();

  static const String boxName = 'liveKeywordRules';
  static const int rateLimitHours = 4; // Don't notify same UP more than once per 4 hours
  static const int pollingIntervalMinutes = 15;

  Box<LiveKeywordRule>? _box;
  Box<LiveKeywordRule> get box {
    if (_box == null) {
      throw StateError('LiveAlertService not initialized. Call init() first.');
    }
    return _box!;
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Timer? _pollingTimer;
  final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    if (!Hive.isAdapterRegistered(101)) {
      Hive.registerAdapter(LiveKeywordRuleAdapter());
    }

    _box = await Hive.openBox<LiveKeywordRule>(boxName);

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - deep link to live room
    if (kDebugMode) {
      debugPrint('Notification tapped: ${response.payload}');
    }
  }

  /// Start polling for live status
  void startPolling() {
    if (!_isInitialized) return;
    stopPolling();

    // Poll immediately
    checkLiveStatus();

    // Then poll every 15 minutes
    _pollingTimer = Timer.periodic(
      Duration(minutes: pollingIntervalMinutes),
      (_) => checkLiveStatus(),
    );
  }

  /// Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Check live status for all followed UPs with rules
  Future<void> checkLiveStatus() async {
    if (!_isInitialized) return;

    final rules = getAllRules();
    if (rules.isEmpty) return;

    // Get unique mids from rules
    final midsToCheck = rules.map((r) => r.mid).toSet();

    for (final mid in midsToCheck) {
      await _checkUpLiveStatus(mid);
    }
  }

  Future<void> _checkUpLiveStatus(int mid) async {
    final result = await LiveHttp.liveRoomInfoH5(roomId: mid);

    if (result case Success(:final response)) {
      final isLive = response.roomInfo?.liveStatus == 1;
      if (isLive) {
        await _handleLiveStatus(mid, response);
      }
    }
  }

  Future<void> _handleLiveStatus(int mid, RoomInfoH5Data roomInfo) async {
    final rules = getRulesForMid(mid);
    if (rules.isEmpty) return;

    final title = roomInfo.roomInfo?.title ?? '';
    final areaName = roomInfo.roomInfo?.areaName ?? '';
    final roomId = roomInfo.roomInfo?.roomId?.toString() ?? mid.toString();

    for (final rule in rules) {
      if (_shouldNotify(rule)) {
        if (rule.matches(streamTitle: title, areaName: areaName)) {
          await _sendNotification(rule, title, roomId);
          await _updateLastNotified(rule);
        }
      }
    }
  }

  bool _shouldNotify(LiveKeywordRule rule) {
    if (!rule.enabled) return false;

    // Rate limit: check if we notified for this UP recently
    if (rule.lastNotifiedAt > 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final hoursSinceLastNotify =
          (now - rule.lastNotifiedAt) / 3600;
      if (hoursSinceLastNotify < rateLimitHours) {
        return false;
      }
    }
    return true;
  }

  Future<void> _sendNotification(
    LiveKeywordRule rule,
    String streamTitle,
    String roomId,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'live_alerts',
      '直播提醒',
      channelDescription: '直播开播提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      rule.mid,
      '${rule.upName} 正在直播',
      streamTitle,
      details,
      payload: 'bilibili://live/$roomId',
    );
  }

  Future<void> _updateLastNotified(LiveKeywordRule rule) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final updated = rule.copyWith(lastNotifiedAt: now);
    await rule.delete();
    await box.put(rule.id, updated);
  }

  /// Get all rules
  List<LiveKeywordRule> getAllRules() {
    if (!_isInitialized) return [];
    return box.values.toList();
  }

  /// Get rules for a specific UP
  List<LiveKeywordRule> getRulesForMid(int mid) {
    if (!_isInitialized) return [];
    return box.values.where((r) => r.mid == mid).toList();
  }

  /// Get all enabled rules
  List<LiveKeywordRule> getEnabledRules() {
    if (!_isInitialized) return [];
    return box.values.where((r) => r.enabled).toList();
  }

  /// Add a new rule
  Future<void> addRule(LiveKeywordRule rule) async {
    if (!_isInitialized) return;
    await box.put(rule.id, rule);
  }

  /// Update a rule
  Future<void> updateRule(LiveKeywordRule rule) async {
    if (!_isInitialized) return;
    await box.put(rule.id, rule);
  }

  /// Delete a rule
  Future<void> deleteRule(String ruleId) async {
    if (!_isInitialized) return;
    await box.delete(ruleId);
  }

  /// Toggle rule enabled status
  Future<void> toggleRule(String ruleId) async {
    if (!_isInitialized) return;
    final rule = box.get(ruleId);
    if (rule != null) {
      final updated = rule.copyWith(enabled: !rule.enabled);
      await box.put(ruleId, updated);
    }
  }

  /// Generate a unique rule ID
  String generateRuleId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Accounts.main.mid}';
  }

  /// Close the service
  Future<void> close() async {
    stopPolling();
    await _box?.close();
    _isInitialized = false;
  }
}
