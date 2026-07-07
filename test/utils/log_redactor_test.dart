import 'package:pili_plus/utils/log_redactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogRedactor', () {
    test('redacts sensitive map keys recursively', () {
      final redacted = LogRedactor.redact({
        'url': 'https://example.com/?access_key=token',
        'headers': {
          'cookie': 'SESSDATA=session;bili_jct=csrf',
          'authorization': 'Bearer token',
        },
        'webdav': {'password': 'secret'},
      });

      expect(redacted, {
        'url': 'https://example.com/?access_key=[REDACTED]',
        'headers': {
          'cookie': LogRedactor.redacted,
          'authorization': LogRedactor.redacted,
        },
        'webdav': {'password': LogRedactor.redacted},
      });
    });

    test('redacts sensitive text values', () {
      final redacted = LogRedactor.redactText(
        'Cookie: SESSDATA=session;bili_jct=csrf\n'
        'url=https://example.com/?access_key=token&foo=bar\n'
        '"password":"secret"',
      );

      expect(redacted, contains('Cookie: [REDACTED]'));
      expect(redacted, contains('access_key=[REDACTED]'));
      expect(redacted, contains('"password":"[REDACTED]"'));
      expect(redacted, isNot(contains('session')));
      expect(redacted, isNot(contains('secret')));
      expect(redacted, isNot(contains('token')));
    });
  });
}
