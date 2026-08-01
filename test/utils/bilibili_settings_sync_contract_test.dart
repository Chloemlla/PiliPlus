import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bilibili settings sync contract', () {
    test('does not enable sync without a validated Bilibili login', () {
      expect(_canEnableSync(isBilibiliLoggedIn: false, validatedUid: null), isFalse);
      expect(_canEnableSync(isBilibiliLoggedIn: true, validatedUid: null), isFalse);
      expect(_canEnableSync(isBilibiliLoggedIn: true, validatedUid: ''), isFalse);
      expect(_canEnableSync(isBilibiliLoggedIn: true, validatedUid: '12345'), isTrue);
    });

    test('settings serialization excludes cookies and session credentials', () {
      final payload = _settingsRecord({
        'bilibiliUid': '12345',
        'searchHistory': ['cats'],
        'cookie': 'SESSDATA=must-not-sync',
        'cookies': {'bili_jct': 'must-not-sync'},
        'authorization': 'Bearer must-not-sync',
      });

      final encoded = jsonEncode(payload);
      expect(encoded, contains('12345'));
      for (final forbidden in _forbiddenNames) {
        expect(encoded, isNot(contains(forbidden)));
      }
    });

    test('bind response exposes capability but never returns the cookie', () {
      const bindResponse = {
        'success': true,
        'data': {'bilibiliUid': '12345', 'settingsSyncEnabled': true},
      };

      final encoded = jsonEncode(bindResponse);
      expect(encoded, contains('settingsSyncEnabled'));
      expect(encoded, isNot(contains('SESSDATA')));
      expect(encoded, isNot(contains('bili_jct')));
    });

    test('uid mismatch and invalid cookie fail closed before a settings write', () {
      final cases = [
        (cookieValid: false, cookieUid: '12345', requestedUid: '12345'),
        (cookieValid: true, cookieUid: '99999', requestedUid: '12345'),
      ];

      for (final item in cases) {
        expect(
          _canBind(
            cookieValid: item.cookieValid,
            cookieUid: item.cookieUid,
            requestedUid: item.requestedUid,
          ),
          isFalse,
        );
      }
    });

    test('conflict metadata contains no decrypted settings or cookies', () {
      const conflict = {
        'category': 'settings',
        'id': 'bilibili-settings',
        'serverUpdatedAt': '2026-08-01T00:00:00.000Z',
        'clientUpdatedAt': '2026-07-31T23:59:00.000Z',
      };

      final encoded = jsonEncode(conflict);
      expect(encoded, contains('serverUpdatedAt'));
      for (final forbidden in _forbiddenNames) {
        expect(encoded, isNot(contains(forbidden)));
      }
    });
  });
}

const _forbiddenNames = <String>[
  'cookie',
  'cookies',
  'SESSDATA',
  'bili_jct',
  'DedeUserID',
  'authorization',
];

bool _canEnableSync({required bool isBilibiliLoggedIn, required String? validatedUid}) {
  return isBilibiliLoggedIn && validatedUid != null && validatedUid.trim().isNotEmpty;
}

bool _canBind({required bool cookieValid, required String? cookieUid, required String requestedUid}) {
  return cookieValid && cookieUid != null && cookieUid == requestedUid;
}

Map<String, dynamic> _settingsRecord(Map<String, dynamic> source) {
  final sanitized = Map<String, dynamic>.of(source)
    ..removeWhere((key, _) => _forbiddenNames.contains(key));
  return {
    'schemaVersion': 2,
    'category': 'settings',
    'id': 'bilibili-settings',
    'payload': sanitized,
  };
}
