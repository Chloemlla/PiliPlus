abstract final class NetworkSecurityPolicy {
  static bool shouldBypassCertificateValidation({
    required bool explicitBadCertificateBypass,
  }) {
    return explicitBadCertificateBypass;
  }
}
