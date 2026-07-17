# Android / Vivo 11-17 Adaptation Notes (PiliPlus)

Reference decision notes from Project-Lumen:

- `Project-Lumen/docs/ANDROID_11_VIVO_ADAPTATION.md` ... `ANDROID_17_VIVO_ADAPTATION.md`
- Workflow: `Project-Lumen/docs/VIVO_ADAPTATION_DOC_WORKFLOW.md`

PiliPlus ships with `compileSdk/targetSdk = 37`, `minSdk >= 26`. This note records
what still matters for this product and what changed on 2026-07-17.

## High-priority decisions

### 1. Predictive back (Android 13+/16+)
- Before: `android:enableOnBackInvokedCallback="false"`; `QrScannerActivity` used
  deprecated `onBackPressed()`.
- Now:
  - Application enables `android:enableOnBackInvokedCallback="true"`.
  - `QrScannerActivity` cancels via `OnBackPressedDispatcher`.
  - Flutter pages continue to use Material / project `PopScope` helpers.

### 2. Component `android:exported` (Android 12+)
- MainActivity / AudioService / MediaButtonReceiver / QrScanner already declared.
- Now: `com.yalantis.ucrop.UCropActivity` is `android:exported="false"`.

### 3. Network security / cleartext (Android 17 targetSdk path)
- Now: `res/xml/network_security_config.xml` with
  `base-config cleartextTrafficPermitted="false"`.
- Application points to `@xml/network_security_config`.
- No Manifest `usesCleartextTraffic=true`.
- Runtime bad-certificate bypass remains a separate Dio/user setting
  (`NetworkSecurityPolicy`) and is not modeled as cleartext traffic.

### 4. Intent matching hardening (Android 16+)
- Application sets `android:intentMatchingFlags="enforceIntentFilter"`.
- Launcher, bilibili deeplinks, media button, and Seal queries keep explicit
  components / package-scoped intents where applicable.

### 5. Explicit URI grants for open/share (Android 17 prep)
- Seal open/share paths already used `FLAG_GRANT_READ_URI_PERMISSION`.
- Now: also attach `ClipData.newUri(...)` for `ACTION_VIEW` / `ACTION_SEND`.
- Plain-text shares remain unchanged.

### 6. Edge-to-edge / large screen
- Flutter cold start already uses edge-to-edge system UI.
- MainActivity: `resizeableActivity=true`, broad `configChanges`, no forced portrait.
- Cutout: `windowLayoutInDisplayCutoutMode=shortEdges` on activity/theme.
- Now: `NormalTheme` (light/night/v31) sets transparent status/navigation bars.

### 7. Foreground service / background audio
- `AudioService` + `NativeMediaService` declare
  `foregroundServiceType="mediaPlayback"` and
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.
- Continuous playback must stay on typed mediaPlayback FGS paths.
- No untyped FGS components in host Manifest.

### 8. Notifications / media permissions
- Declares `POST_NOTIFICATIONS`.
- First-launch Android permission gate requests notification / photos / videos /
  audio (API 33+) or storage (API < 33).
- `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_MEDIA_AUDIO` retained as
  product-required media access (not legacy full-storage escape).
- Storage permissions use `maxSdkVersion` limits; no
  `MANAGE_EXTERNAL_STORAGE` / `requestLegacyExternalStorage`.

### 9. PendingIntent mutability
- `NativeMediaService` content/service intents: `FLAG_IMMUTABLE`.
- Media-button broadcast helper (`MediaHelper`) uses `FLAG_MUTABLE` on API 31+
  because media-button extras/key events require a mutable PendingIntent contract
  with the media session path. Component is package-scoped / explicit.

### 10. Package visibility
- No `QUERY_ALL_PACKAGES`.
- Uses `<queries>` for Seal packages, http(s) VIEW, and Custom Tabs.

## N/A for PiliPlus (from Lumen lists)

| Item | Why N/A |
|---|---|
| Exact alarms / timer reconciliation | Not a timer/reminder product |
| Camera FGS proximity sampling | Camera is QR scan only, no camera FGS type |
| Shizuku / full installed-app enumeration | Not used |
| Health / body sensors / NPU | Not used |
| LAN/mDNS `ACCESS_LOCAL_NETWORK` | Public HTTPS API traffic only |
| scheduleAtFixedRate backlog behavior | No host fixed-rate executor scheduling found |
| Companion device / Health Connect / bubbles | Not used |

## Already aligned before this change

- `targetSdk/compileSdk = 37`
- mediaPlayback FGS typing
- `resizeableActivity` + adaptive configChanges
- POST_NOTIFICATIONS + first-launch permission UX
- Immutable PendingIntents for native media notification content
- Seal package queries instead of QUERY_ALL_PACKAGES
- Flutter edge-to-edge enablement

## Code touchpoints (2026-07-17)

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/xml/network_security_config.xml`
- `android/app/src/main/res/values*/styles.xml`
- `android/app/src/main/kotlin/.../QrScannerActivity.kt`
- `android/app/src/main/kotlin/.../SealDownloadChannel.kt`

## Verification checklist

- Cold start under edge-to-edge: system bars transparent, content not covered incorrectly.
- System predictive back dismisses QR scanner (cancel) and Flutter routes still intercept where `PopScope` requires.
- UCrop still opens only from in-app image crop flows (not externally).
- HTTPS API traffic works with cleartext denied by default.
- Seal open/share of a content URI still succeeds with grant + ClipData.
- Background media notification / media buttons still control playback.
- Bilibili deeplink VIEW filters still open MainActivity.

## Refresh log

- 2026-07-17: Mapped Lumen Android 11-17 Vivo notes onto PiliPlus; enabled predictive back; added network security config + intent matching flags; fixed UCrop exported; hardened Seal URI grants; documented N/A product differences.
