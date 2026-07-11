abstract final class LogRedactor {
  static const redacted = '[REDACTED]';

  static final RegExp _sensitiveKey = RegExp(
    r'^(authorization|cookie|set-cookie|sessdata|bili_jct|csrf|access[_-]?key|accesskey|refresh[_-]?token|refreshtoken|qrcode[_-]?key|captcha[_-]?key|verify[_-]?key|verify[_-]?code|sms[_-]?code|recaptcha[_-]?token|password|passwd|pwd|keypassword|storepassword)$',
    caseSensitive: false,
  );

  static final RegExp _queryParam = RegExp(
    r'\b(SESSDATA|bili_jct|csrf|access_key|accessKey|refresh_token|refreshToken|qrcode_key|captcha_key|verify_key|verify_code|recaptcha_token|code|password|passwd|pwd)=([^&\s;,]+)',
    caseSensitive: false,
  );
  static final RegExp _header = RegExp(
    r'\b(authorization|cookie|set-cookie)\s*[:=]\s*([^\r\n]+)',
    caseSensitive: false,
  );
  static final RegExp _jsonString = RegExp(
    r'("?(?:SESSDATA|bili_jct|csrf|access_key|accessKey|refresh_token|refreshToken|qrcode_key|captcha_key|verify_key|verify_code|recaptcha_token|password|passwd|pwd|authorization|cookie)"?\s*:\s*)"[^"]*"',
    caseSensitive: false,
  );
  static final RegExp _structuredValue = RegExp(
    r'''(["']?(?:SESSDATA|bili_jct|csrf|access_key|accessKey|refresh_token|refreshToken|qrcode_key|captcha_key|verify_key|verify_code|sms_code|recaptcha_token|password|passwd|pwd|authorization|cookie)["']?\s*:\s*)(?:"[^"]*"|'[^']*'|[^,}\]\r\n]+)''',
    caseSensitive: false,
  );
  static final RegExp _shortSecretCode = RegExp(
    r'''\b(code|verify_code|sms_code)\s*[:=]\s*["']?(\d{6,8})''',
    caseSensitive: false,
  );
  static final RegExp _windowsUserHome = RegExp(r'[A-Za-z]:\\Users\\[^\\\s]+');
  static final RegExp _unixUserHome = RegExp(r'/(?:home|Users)/[^/\s]+');
  static final RegExp _contentUri = RegExp(
    r'\bcontent://[^\s]+',
    caseSensitive: false,
  );
  static final RegExp _fileUri = RegExp(
    r'\bfile://[^\s]+',
    caseSensitive: false,
  );

  static Object? redact(Object? value, {Object? key}) {
    if (key != null && _sensitiveKey.hasMatch(key.toString())) {
      return redacted;
    }
    return switch (value) {
      String() => redactText(value),
      Map() => {
        for (final entry in value.entries)
          entry.key: redact(entry.value, key: entry.key),
      },
      Iterable() => [for (final item in value) redact(item)],
      _ => value,
    };
  }

  static String redactText(String value) {
    return value
        .replaceAllMapped(_queryParam, (match) => '${match.group(1)}=$redacted')
        .replaceAllMapped(_header, (match) => '${match.group(1)}: $redacted')
        .replaceAllMapped(
          _jsonString,
          (match) => '${match.group(1)}"$redacted"',
        )
        .replaceAllMapped(
          _structuredValue,
          (match) => '${match.group(1)}"$redacted"',
        )
        .replaceAllMapped(
          _shortSecretCode,
          (match) => '${match.group(1)}=$redacted',
        )
        .replaceAll(_windowsUserHome, '[user-home]')
        .replaceAll(_unixUserHome, '[user-home]')
        .replaceAll(_contentUri, '[content-uri]')
        .replaceAll(_fileUri, '[file-uri]');
  }
}
