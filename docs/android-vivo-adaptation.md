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

### 7b. Media notification / MediaSession (API 30–37)
- `NativeMediaService` posts a standard `Notification.MediaStyle` with
  `MediaSession` token (no custom RemoteViews).
- Android 12+ (`S`): `setForegroundServiceBehavior(FOREGROUND_SERVICE_IMMEDIATE)`
  so the media FGS notification is not delayed in the shade.
- Channel: `IMPORTANCE_LOW`, no sound/vibration/badge (transport controls only).
- PendingIntents for content / actions: `FLAG_IMMUTABLE` (API 23+).
- Seek / scrubber: `ACTION_SEEK_TO` only when non-live and `durationMs > 0`;
  player duration write-back via Flutter `onDurationChange`.
- Android 13+ runtime `POST_NOTIFICATIONS` is requested by the first-launch
  permission gate (media notification posts are no-ops without it on OEM builds).
- Android 14+: FGS type required — already `mediaPlayback`.
- Android 17: sustained media needs `mediaPlayback` FGS while-in-use capability;
  PiliPlus keeps playback on that typed service path.

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

## Code touchpoints (2026-07-17 / 2026-07-24)

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/xml/network_security_config.xml`
- `android/app/src/main/res/values*/styles.xml`
- `android/app/src/main/kotlin/.../QrScannerActivity.kt`
- `android/app/src/main/kotlin/.../SealDownloadChannel.kt`
- `android/app/src/main/kotlin/.../NativeMediaService.kt` (FGS immediate + channel)

## Verification checklist

- Cold start under edge-to-edge: system bars transparent, content not covered incorrectly.
- System predictive back dismisses QR scanner (cancel) and Flutter routes still intercept where `PopScope` requires.
- UCrop still opens only from in-app image crop flows (not externally).
- HTTPS API traffic works with cleartext denied by default.
- Seal open/share of a content URI still succeeds with grant + ClipData.
- Background media notification / media buttons still control playback.
- API 31–33: media FGS notification appears promptly; scrubber when duration > 0.
- API 33+: denying POST_NOTIFICATIONS does not crash playback; re-grant restores shade controls.
- Bilibili deeplink VIEW filters still open MainActivity.

### Media notification verification record (2026-07-31)

- Source review confirmed the standard `MediaSession` / `MediaStyle` path keeps
  `ACTION_SEEK_TO` gated by non-live `durationMs > 0`, writes buffered position,
  uses optimistic seek state, and drops short-lived stale position ticks.
- GitHub Actions run `30550668539` completed Analyze/Test and the Android release
  build successfully with the notification adaptation and progress code present.
- Physical-device OEM checks remain a release QA item: expanded scrubber + drag
  seek should be sampled on AOSP/Pixel, Vivo/OriginOS and one additional OEM.
  This record does not claim hardware execution; rewind/fast-forward remain the
  documented fallback where an OEM hides the standard scrubber.

## Known device faults (native crash fingerprints)

### hwui `ShaderCache::store` SIGSEGV (MediaTek / Mali, Android 16)

- Fingerprint: `ApplicationExitInfo` native crash (`reason = native_crash`),
  stack inside `libhwui.so` at
  `android::uirenderer::skiapipeline::ShaderCache::store(...)::$_0` — the
  View-system shader disk cache's deferred write thread. Frames are
  bionic/libc + libhwui only; no app / libflutter / libmpv frames in the
  crashing thread.
- First seen: 2026-08-04, build `2.1.0-faeb17343` (5413), vivo V2426A
  (MediaTek MT6991 / Mali), Android 16 (SDK 36), while backgrounded with audio
  playback active.
- Verdict: system/firmware-level fault, not an app-code bug. Not introduced by
  the 2026-08-04 background-audio refactor (a Dart-only diff); that feature
  keeps the process + UI inflated longer in the background, which increases
  exposure to the faulty hwui path rather than causing it.
- Handling: `CrashReportFilter.isKnownDeviceIssue` matches this fingerprint
  (`shadercache::store` + `libhwui` in the tombstone) and persists matched
  reports as history (`makePending:false`) instead of surfacing a fatal startup
  crash.
- Untested lever: `EnableImpeller=true` removes Flutter's own GL context
  alongside hwui's (a known Mali dual-context stressor) but hwui still compiles
  / stores View shaders, so it is not a proven fix; Impeller was disabled
  deliberately in `7ae92970e` and would need real-device QA before switching.

## Refresh log

- 2026-07-17: Mapped Lumen Android 11-17 Vivo notes onto PiliPlus; enabled predictive back; added network security config + intent matching flags; fixed UCrop exported; hardened Seal URI grants; documented N/A product differences.
- 2026-07-24: Media notification API 11–17: FGS immediate behavior (S+), silent LOW channel, seekable MediaStyle duration write-back; documented POST_NOTIFICATIONS / mediaPlayback while-in-use expectations.
- 2026-07-31: Recorded source/CI verification and kept physical-device OEM validation as an explicit release QA item rather than assuming it was executed.
- 2026-08-04: Recorded the vivo V2426A / MediaTek hwui `ShaderCache::store` native crash as a known device fault; wired its fingerprint into the crash pipeline (history-only, not fatal).
