package com.chloemlla.piliplus

internal object NativeCrashSanitizer {
    private const val REDACTED = "[REDACTED]"

    private val queryValue = Regex(
        "(?i)\\b(SESSDATA|bili_jct|csrf|access_key|accessKey|refresh_token|" +
            "refreshToken|qrcode_key|captcha_key|verify_key|verify_code|" +
            "sms_code|recaptcha_token|code|password|passwd|pwd)=([^&\\s;,]+)",
    )
    private val structuredValue = Regex(
        "(?i)([\\\"']?(?:SESSDATA|bili_jct|csrf|access_key|accessKey|" +
            "refresh_token|refreshToken|qrcode_key|captcha_key|verify_key|" +
            "verify_code|sms_code|recaptcha_token|password|passwd|pwd|" +
            "authorization|cookie)[\\\"']?\\s*:\\s*)" +
            "(?:\\\"[^\\\"]*\\\"|'[^']*'|[^,}\\]\\r\\n]+)",
    )
    private val headerValue = Regex(
        "(?i)\\b(authorization|cookie|set-cookie)\\s*[:=]\\s*([^\\r\\n]+)",
    )

    fun sanitize(value: String): String {
        return value
            .replace(queryValue) { match -> "${match.groupValues[1]}=$REDACTED" }
            .replace(structuredValue) { match -> "${match.groupValues[1]}$REDACTED" }
            .replace(headerValue) { match -> "${match.groupValues[1]}: $REDACTED" }
    }
}
