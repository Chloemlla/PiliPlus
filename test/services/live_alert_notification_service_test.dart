import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/services/live_alert_notification_service.dart';

void main() {
  group('LiveAlertNotificationService payload', () {
    test('accepts only positive live-room payloads', () {
      expect(
        LiveAlertNotificationService.roomIdFromPayload('live-room:1234'),
        1234,
      );
      expect(
        LiveAlertNotificationService.roomIdFromPayload('bilibili://live/1234'),
        isNull,
      );
      expect(
        LiveAlertNotificationService.roomIdFromPayload('live-room:0'),
        isNull,
      );
    });

    test('escapes notification text before highlighting keyword', () {
      final text = LiveAlertNotificationService.androidBigText(
        streamTitle: '<Concert>',
        matchedKeyword: 'A&B',
      );

      expect(text, contains('<b>A&amp;B</b>'));
      expect(text, contains('&lt;Concert&gt;'));
    });

    test('notification IDs are stable and account-specific', () {
      final first = LiveAlertNotificationService.notificationId(
        accountMid: 1,
        mid: 2,
      );
      expect(
        LiveAlertNotificationService.notificationId(accountMid: 1, mid: 2),
        first,
      );
      expect(
        LiveAlertNotificationService.notificationId(accountMid: 2, mid: 2),
        isNot(first),
      );
    });
  });
}
