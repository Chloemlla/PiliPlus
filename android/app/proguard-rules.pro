-dontwarn javax.annotation.Nullable
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.OpenSSLProvider

############################################################
# Lumen Crash SDK minify exemption
# Artifact: com.chloemlla.lumen:lumen-crash-core (capture-only host)
# Synced from Project-Lumen lumen-crash/host-proguard-template.pro
############################################################

-keepattributes *Annotation*, InnerClasses, EnclosingMethod, Signature, RuntimeVisibleAnnotations

-keep class com.chloemlla.lumen.crash.CrashAuthorAttribution {
    public static final java.lang.String *;
    public static *** payload();
}
-keepclassmembers class com.chloemlla.lumen.crash.CrashAuthorAttribution {
    public static final java.lang.String *;
}

-keep class com.chloemlla.lumen.crash.AuthorIntegrity {
    public static *** verifyOrThrow(...);
    public static *** fingerprintHex();
    public static *** verifiedAuthorBlock();
}
-keep class com.chloemlla.lumen.crash.AuthorBlock { *; }

-keep class com.chloemlla.lumen.crash.LumenCrash { *; }
-keep class com.chloemlla.lumen.crash.LumenCrashConfig { *; }
-keep class com.chloemlla.lumen.crash.LumenCrashConfigBuilder { *; }
-keep class com.chloemlla.lumen.crash.LumenCrashDefaults { *; }
-keep class com.chloemlla.lumen.crash.LumenCrashFileProvider { *; }
-keep class com.chloemlla.lumen.crash.CrashReport { *; }
-keep class com.chloemlla.lumen.crash.CrashAppInfo { *; }
-keep class com.chloemlla.lumen.crash.CrashReportStore { *; }
-keep class com.chloemlla.lumen.crash.CrashBreadcrumbs { *; }
-keep class com.chloemlla.lumen.crash.CrashReportPasteUploader { *; }
-keep class com.chloemlla.lumen.crash.ui.LumenCrashReportScreenKt { *; }
-keep class com.chloemlla.lumen.crash.ui.LumenCrashGateKt { *; }

-keep class com.chloemlla.lumen.crash.** { *; }
-keepclassmembers class com.chloemlla.lumen.crash.** { *; }
-dontwarn com.chloemlla.lumen.crash.**

############################################################
# Huawei HMS Scan Kit (scanplus) — optional OEM/network stubs
# R8 full-mode treats missing optional refs as errors unless
# dontwarn/keep rules are present. Local decode does not need
# Cronet/HQUIC/BI/analytics optional modules at runtime.
############################################################

-keep class com.huawei.hms.hmsscankit.** { *; }
-keep class com.huawei.hms.scankit.** { *; }
-keep class com.huawei.hms.ml.scan.** { *; }
-keep class com.huawei.hms.mlsdk.** { *; }
-keep class com.huawei.hms.mlkit.** { *; }
-keep class com.huawei.hms.ml.** { *; }
-keep class com.huawei.hms.feature.** { *; }
-keep class com.huawei.hianalytics.** { *; }
-keep class com.huawei.updatesdk.** { *; }

-dontwarn com.huawei.hms.hmsscankit.**
-dontwarn com.huawei.hms.scankit.**
-dontwarn com.huawei.hms.ml.scan.**
-dontwarn com.huawei.hms.mlsdk.**
-dontwarn com.huawei.hms.mlkit.**
-dontwarn com.huawei.hms.ml.**
-dontwarn com.huawei.hms.feature.**
-dontwarn com.huawei.hianalytics.**
-dontwarn com.huawei.updatesdk.**

# Optional Huawei framework / network / analytics stubs pulled by scanplus.
-dontwarn com.huawei.android.os.**
-dontwarn com.huawei.hms.framework.**
-dontwarn com.huawei.hms.network.**
-dontwarn com.huawei.hms.hquic.**
-dontwarn com.huawei.hms.support.hianalytics.**
-dontwarn com.huawei.hms.utils.**
-dontwarn com.huawei.libcore.io.**
-dontwarn com.huawei.secure.android.common.**
-dontwarn com.android.org.conscrypt.**
-dontwarn org.bouncycastle.crypto.**
-dontwarn org.bouncycastle.crypto.engines.**
-dontwarn org.bouncycastle.crypto.prng.**
-dontwarn org.chromium.net.**
-dontwarn org.conscrypt.**
