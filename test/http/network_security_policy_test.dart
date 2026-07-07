import 'package:pili_plus/http/network_security_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkSecurityPolicy', () {
    test('keeps certificate validation enabled unless explicitly bypassed', () {
      expect(
        NetworkSecurityPolicy.shouldBypassCertificateValidation(
          explicitBadCertificateBypass: false,
        ),
        isFalse,
      );
      expect(
        NetworkSecurityPolicy.shouldBypassCertificateValidation(
          explicitBadCertificateBypass: true,
        ),
        isTrue,
      );
    });
  });
}
