import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/synapse_oauth.dart';
import 'package:pili_plus/services/synapse_account_sync.dart'
    show synapseCookieHash;
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

final _now = DateTime.parse('2026-09-26T10:00:00Z');

SynapseCookieReportLedger _ledgerFor(
  String cookie, {
  int attempts = 0,
  int count = 1,
}) => SynapseCookieReportLedger(
  cookieHash: synapseCookieHash(cookie),
  at: _now.toIso8601String(),
  count: count,
  attempts: attempts,
);

SynapseCookieReportDecision _decide({
  bool enabled = true,
  required Account account,
  required String cookie,
  Map<String, SynapseCookieReportLedger> ledger = const {},
  Map<String, DateTime> sentAt = const {},
  DateTime? now,
}) => SynapseCookieReport.decide(
  enabled: enabled,
  account: account,
  sentAt: sentAt,
  ledger: ledger,
  cookie: cookie,
  now: now ?? _now,
);

void main() {
  group('SynapseCookieReport.decide', () {
    test('stays silent when the switch is off', () {
      expect(
        _decide(enabled: false, account: _account(), cookie: 'SESSDATA=a'),
        SynapseCookieReportDecision.skippedDisabled,
      );
    });

    test('has nothing to report for an anonymous account', () {
      expect(
        _decide(account: AnonymousAccount(), cookie: ''),
        SynapseCookieReportDecision.skippedAnonymous,
      );
    });

    test('files a cookie the ledger has never seen', () {
      expect(
        _decide(account: _account(), cookie: 'SESSDATA=new'),
        SynapseCookieReportDecision.sent,
      );
    });

    test('never files the same cookie twice', () {
      const cookie = 'SESSDATA=archived; bili_jct=x; DedeUserID=12345';
      expect(
        _decide(
          account: _account(),
          cookie: cookie,
          ledger: {'12345': _ledgerFor(cookie)},
        ),
        SynapseCookieReportDecision.skippedAlreadyReported,
      );
    });

    test('files a refreshed cookie for the same account', () {
      expect(
        _decide(
          account: _account(),
          cookie: 'SESSDATA=fresh',
          ledger: {'12345': _ledgerFor('SESSDATA=old')},
        ),
        SynapseCookieReportDecision.sent,
      );
    });

    test('gives up on a cookie that keeps failing', () {
      const cookie = 'SESSDATA=stuck';
      expect(
        _decide(
          account: _account(),
          cookie: cookie,
          ledger: {
            '12345': _ledgerFor(
              cookie,
              count: 0,
              attempts: SynapseCookieReport.maxAttemptsPerCookie,
            ),
          },
        ),
        SynapseCookieReportDecision.skippedAttemptCap,
      );
    });

    test('a failed cookie is still retried until the budget is spent', () {
      const cookie = 'SESSDATA=stuck';
      expect(
        _decide(
          account: _account(),
          cookie: cookie,
          ledger: {
            '12345': _ledgerFor(cookie, count: 0, attempts: 1),
          },
        ),
        SynapseCookieReportDecision.sent,
      );
    });

    test('a refreshed cookie resets the failed-attempt budget', () {
      expect(
        _decide(
          account: _account(),
          cookie: 'SESSDATA=fresh',
          ledger: {
            '12345': _ledgerFor(
              'SESSDATA=stuck',
              count: 0,
              attempts: SynapseCookieReport.maxAttemptsPerCookie + 5,
            ),
          },
        ),
        SynapseCookieReportDecision.sent,
      );
    });

    test('collapses the extra callbacks of one login', () {
      expect(
        _decide(
          account: _account(),
          cookie: 'SESSDATA=new',
          sentAt: {'12345': _now.subtract(const Duration(seconds: 5))},
        ),
        SynapseCookieReportDecision.skippedDuplicate,
      );
    });

    test('tracks each UID on its own', () {
      const cookie = 'SESSDATA=archived';
      expect(
        _decide(
          account: _account(mid: '99999'),
          cookie: 'SESSDATA=other-account',
          ledger: {'12345': _ledgerFor(cookie)},
        ),
        SynapseCookieReportDecision.sent,
      );
    });
  });

  group('SynapseCookieReportLedger', () {
    test(
      'a successful report counts itself and clears the attempt counter',
      () {
        final entry = _ledgerFor(
          'a',
          attempts: 2,
          count: 3,
        ).succeeded(synapseCookieHash('b'), _now);

        expect(entry.cookieHash, synapseCookieHash('b'));
        expect(entry.count, 4);
        expect(entry.attempts, 0);
      },
    );

    test('a failure on the tracked cookie only burns an attempt', () {
      final entry = _ledgerFor(
        'a',
        count: 3,
      ).failed(synapseCookieHash('a'), _now);

      expect(entry.count, 3);
      expect(entry.attempts, 1);
    });

    test('a failure on a new cookie starts a fresh attempt budget', () {
      final entry = _ledgerFor(
        'a',
        count: 3,
        attempts: 2,
      ).failed(synapseCookieHash('b'), _now);

      expect(entry.cookieHash, synapseCookieHash('b'));
      expect(entry.count, 0);
      expect(entry.attempts, 1);
    });

    test('counts attempts against the current cookie only', () {
      final capped = _ledgerFor(
        'a',
        count: 0,
        attempts: SynapseCookieReport.maxAttemptsPerCookie,
      );

      expect(
        capped.attemptCapped(
          SynapseCookieReport.maxAttemptsPerCookie,
          synapseCookieHash('a'),
        ),
        isTrue,
      );
      expect(
        capped.attemptCapped(
          SynapseCookieReport.maxAttemptsPerCookie,
          synapseCookieHash('b'),
        ),
        isFalse,
      );
      // A cookie that only ever failed is not "archived", so the two checks
      // never mask each other.
      expect(capped.isArchived(synapseCookieHash('a')), isFalse);
      expect(
        _ledgerFor('a', count: 1).isArchived(synapseCookieHash('a')),
        isTrue,
      );
    });
  });

  group('cookie report ledger persistence', () {
    test('round-trips through the settings box format', () {
      final ledger = {
        '12345': _ledgerFor('SESSDATA=a', count: 2, attempts: 1),
      };
      expect(
        decodeCookieReportLedger(encodeCookieReportLedger(ledger), null),
        ledger,
      );
    });

    test('degrades to an empty ledger on malformed input', () {
      expect(decodeCookieReportLedger(null, null), isEmpty);
      expect(decodeCookieReportLedger('', null), isEmpty);
      expect(decodeCookieReportLedger('not-json', null), isEmpty);
      expect(decodeCookieReportLedger('[1,2]', null), isEmpty);
    });

    test('drops accounts that are no longer on this device', () {
      final encoded = encodeCookieReportLedger({
        '12345': _ledgerFor('a'),
        '99999': _ledgerFor('b'),
      });

      expect(decodeCookieReportLedger(encoded, {'12345'}).keys, ['12345']);
    });

    test('caps how many entries one device keeps', () {
      final encoded = encodeCookieReportLedger({
        for (var i = 0; i < SynapseCookieReport.maxLedgerEntries + 10; i++)
          '$i': _ledgerFor('cookie-$i'),
      });

      expect(
        decodeCookieReportLedger(encoded, null),
        hasLength(SynapseCookieReport.maxLedgerEntries),
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
        equals(<String, dynamic>{
          'client_id': 'piliplus',
          'client_name': 'PiliPlus',
          'client_version': '2.3.4',
          'client_build': '5678',
          'device_id': 'device-abc',
          'device_name': 'PiliPlus Android',
          'platform': 'Android',
        }),
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
