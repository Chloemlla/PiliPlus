import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pili_plus/services/startup_overlay_coordinator.dart';
import 'package:pili_plus/utils/page_utils.dart';

abstract interface class LiveAlertNotificationGateway {
  Future<void> init();

  Future<bool> showLiveAlert({
    required int accountMid,
    required int mid,
    required int roomId,
    required String upName,
    required String streamTitle,
    required String matchedKeyword,
  });

  Future<void> flushPendingNavigation();
}

class LiveAlertNotificationService implements LiveAlertNotificationGateway {
  LiveAlertNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static final LiveAlertNotificationService instance =
      LiveAlertNotificationService();

  static const String _payloadPrefix = 'live-room:';

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void>? _initializing;
  bool _isInitialized = false;
  bool _canShowNotifications = false;
  bool _navigationInFlight = false;
  int? _pendingRoomId;

  @override
  Future<void> init() {
    if (_isInitialized) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (!_supportsNotifications) return;

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      _canShowNotifications =
          await _plugin.initialize(
            initializationSettings,
            onDidReceiveNotificationResponse: _onNotificationResponse,
          ) ??
          false;

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _queuePayload(launchDetails?.notificationResponse?.payload);
      }
    } on Exception {
      _canShowNotifications = false;
    } finally {
      _isInitialized = true;
      _initializing = null;
    }
  }

  bool get _supportsNotifications =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS => true,
        _ => false,
      };

  void _onNotificationResponse(NotificationResponse response) {
    _queuePayload(response.payload);
  }

  void _queuePayload(String? payload) {
    final roomId = roomIdFromPayload(payload);
    if (roomId == null) return;
    _pendingRoomId = roomId;
    unawaited(flushPendingNavigation());
  }

  @override
  Future<bool> showLiveAlert({
    required int accountMid,
    required int mid,
    required int roomId,
    required String upName,
    required String streamTitle,
    required String matchedKeyword,
  }) async {
    if (!_canShowNotifications || roomId <= 0) return false;

    final normalizedTitle = streamTitle.trim().isEmpty ? '直播中' : streamTitle;
    final title = '[$upName] 正在直播: $normalizedTitle';
    final body = '命中关键词「$matchedKeyword」';
    final bigText = androidBigText(
      streamTitle: normalizedTitle,
      matchedKeyword: matchedKeyword,
    );
    final androidDetails = AndroidNotificationDetails(
      'live_alerts',
      '直播提醒',
      channelDescription: '直播开播提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        bigText,
        htmlFormatBigText: true,
        contentTitle: title,
      ),
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'live-alerts',
    );

    try {
      await _plugin.show(
        notificationId(accountMid: accountMid, mid: mid),
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        ),
        payload: '$_payloadPrefix$roomId',
      );
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> flushPendingNavigation() async {
    if (_pendingRoomId == null || _navigationInFlight) return;
    _navigationInFlight = true;
    try {
      await StartupOverlayCoordinator.runWhenNavigatorReady(
        (_) {
          final roomId = _pendingRoomId;
          if (roomId == null) return Future<void>.value();
          _pendingRoomId = null;
          PageUtils.toLiveRoom(roomId);
          return Future<void>.value();
        },
        rounds: 4,
        debugLabel: 'live-alert-notification',
      );
    } finally {
      _navigationInFlight = false;
    }
  }

  static int? roomIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
    final roomId = int.tryParse(payload.substring(_payloadPrefix.length));
    return roomId != null && roomId > 0 ? roomId : null;
  }

  static int notificationId({required int accountMid, required int mid}) =>
      ((accountMid * 31) ^ mid) & 0x7fffffff;

  static String androidBigText({
    required String streamTitle,
    required String matchedKeyword,
  }) {
    const htmlEscape = HtmlEscape();
    return '命中关键词：<b>${htmlEscape.convert(matchedKeyword)}</b><br>'
        '${htmlEscape.convert(streamTitle)}';
  }
}
