import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/synapse_oauth.dart';
import 'package:pili_plus/services/synapse_cookie_report.dart';
import 'package:pili_plus/utils/accounts/account.dart';

LoginAccount _account({
  String mid = '12345',
  String sessdata = 'session-value',
}) => LoginAccount(
  BiliCookieJar.fromJson({
    'DedeUserID': mid,
    'bili_jct': 'csrf-value',
    'SESSDATA': sessdata,
  }),
  'access-token',
  'refresh-token',
);

const _identity = SynapseClientIdentity(
  deviceId: 'device-abc',
  platform: 'Android',
  clientVersion: '2.3.4',
  buildNumber: 5678,
);

void main() {
  group('SynapseCookieReport.decide', () {
    final now = DateTime.parse('2026-09-26T10:00:00Z');

    test('stays silent when the switch is off', () {
      expect(
        SynapseCookieReport.decide(
          enabled: false,
          account: _account(),
          reportedAt: {},
          now: now,
        ),
        SynapseCookieReportDecision.skippedDisabled,
      );
    });

    test('has nothing to report for an anonymous account', () {
      expect(
        SynapseCookieReport.decide(
          enabled: true,
          account: AnonymousAccount(),
          reportedAt: {},
          now: now,
        ),
        SynapseCookieReportDecision.skippedAnonymous,
      );
    });

    test('reports a login that has not been reported yet', () {
      expect(
        SynapseCookieReport.decide(
          enabled: true,
          account: _account(),
          reportedAt: {},
          now: now,
        ),
        SynapseCookieReportDecision.sent,
      );
    });

    test('collapses the extra callbacks of one login', () {
      final reportedAt = {'12345': now.subtract(const Duration(seconds: 5))};
      expect(
        SynapseCookieReport.decide(
          enabled: true,
          account: _account(),
          reportedAt: reportedAt,
          now: now,
        ),
        SynapseCookieReportDecision.skippedDuplicate,
      );
    });

    test('reports again once the window passed and per UID', () {
      final reportedAt = {
        '12345': now.subtract(SynapseCookieReport.duplicateWindow),
      };
      expect(
        SynapseCookieReport.decide(
          enabled: true,
          account: _account(),
          reportedAt: reportedAt,
          now: now,
        ),
        SynapseCookieReportDecision.sent,
      );
      expect(
        SynapseCookieReport.decide(
          enabled: true,
          account: _account(mid: '99999'),
          reportedAt: reportedAt,
          now: now,
        ),
        SynapseCookieReportDecision.sent,
      );
    });
  });

  group('SynapseCookieReport.buildPayload', () {
    test('serializes the account jar into a Bilibili cookie header', () {
      final cookie = SynapseCookieReport.cookieOf(
        _account(sessdata: 'session-value'),
      );

      expect(cookie, contains('DedeUserID=12345'));
      expect(cookie, contains('SESSDATA=session-value'));
      expect(cookie, contains('bili_jct=csrf-value'));
      // buvid3 is injected by the jar constructor, so the header has four pairs.
      expect(cookie.split('; '), hasLength(4));
    });

    test('carries exactly the fields Synapse reads', () {
      final payload = SynapseCookieReport.buildPayload(
        account: _account(),
        identity: _identity,
      );

      expect(
        payload.keys,
        unorderedEquals([
          'client_id',
          'device_id',
          'uid',
          'cookie',
          'isPrimary',
          'client',
        ]),
      );
      expect(payload['client_id'], 'piliplus');
      expect(payload['device_id'], 'device-abc');
      expect(payload['uid'], '12345');
      expect(
        payload['cookie'],
        allOf(
          contains('SESSDATA=session-value'),
          contains('bili_jct=csrf-value'),
        ),
      );
      expect(payload['isPrimary'], isFalse);
      expect(
        payload['client'],
        allOf(
          isA<Map<String, dynamic>>(),
          equals(<String, dynamic>{
            'client_id': 'piliplus',
            'client_name': 'PiliPlus',
            'client_version': '2.3.4',
            'client_build': '5678',
            'device_id': 'device-abc',
            'device_name': 'PiliPlus Android',
            'platform': 'Android',
          }),
        ),
      );
    });

    test('does not ship OAuth tokens or the Bilibili access key', () {
      final encoded = SynapseCookieReport.buildPayload(
        account: _account(),
        identity: _identity,
      ).toString();

      expect(encoded, isNot(contains('access-token')));
      expect(encoded, isNot(contains('refresh-token')));
      expect(encoded, isNot(contains('accessToken')));
    });

    test(
      'device identity in the body matches the headers Synapse compares',
      () {
        final payload = SynapseCookieReport.buildPayload(
          account: _account(),
          identity: _identity,
        );
        final headers = _identity.requestHeaders;

        expect(headers['X-Device-Id'], payload['device_id']);
        expect(headers['X-Synapse-Device-Id'], payload['device_id']);
        expect(headers['X-Synapse-Client-Id'], payload['client_id']);
      },
    );
  });
}
