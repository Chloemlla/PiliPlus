# Flutter Build Whats-New Guide

> Tracked mirror of the Trellis frontend code-spec.
> Local AI path: `.trellis/spec/frontend/flutter-build-whats-new.md`
> (`.trellis/` is gitignored; keep this file in sync when the contract changes.)

## Rule

**Every user-facing commit must update the in-app “本次更新说明” pages.**

- Content file: `lib/pages/onboarding/whats_new_data.dart` (`WhatsNewData.pages`)
- Show service: `lib/services/whats_new_guide_service.dart`
- Identity: `BuildConfig.commitHash` + `BuildConfig.buildTime`
- Ack storage: `SettingBoxKey.whatsNewAckCommitHash` + `SettingBoxKey.whatsNewAckBuildTime`
- UI shell: reuse `ImprovementsGuidePage(pages:, finishLabel: '知道了')`
- About entry: 「设置 → 关于 → 本次更新说明」

## When it applies

Update `WhatsNewData.pages` in the **same change set** when the commit changes:

- user-visible behavior or UI
- startup / onboarding / permissions
- download / playback / comments / settings copy
- any other path a user can notice after installing the new build

## When it does not apply

Content rewrite is optional for:

- pure docs under `.trellis/` or process-only notes
- CI-only workflow tweaks with no app binary behavior change
- formatting-only diffs
- lockfile churn with no runtime path change

## Content requirements

1. Prefer **replace** the current release narrative over infinite history.
   Keep the guide scannable: welcome + about 3–6 topic slides + finish.
2. Keep welcome identity bullets dynamic:
   - `versionLabel`
   - `buildTimeLabel`
   - `commitLabel`
   Do **not** hard-code commit hash / build time strings.
3. Label accurately:
   - intentional feature/UI → enhancement / refactor
   - accidental regression fixed in-branch → 修复 / 已修回
4. Branch-long fork deltas belong in `ImprovementsGuideData.pages`
   (first install). Build-scoped notes belong in `WhatsNewData.pages`
   (first open of each new commit/buildTime).

## Show / ack contracts

Auto-show only when all are true:

1. `firstLaunchOssNoticeSeen == true`
2. `firstLaunchImprovementsGuideSeen == true`
3. stored `(hash, buildTime)` differs from current `BuildConfig`

First install: after improvements guide completes, mark the current build
acknowledged so the same install does not immediately re-open what's-new.

Upgrade: returning-user migration silences first-install flags; what's-new
opens when build identity changes.

Startup order:

`crash report > OSS notice > improvements guide > what's-new > Android permissions`

## Agent commit checklist

Before committing app code:

1. Is this user-facing? If yes → edit `WhatsNewData.pages` in the same commit.
2. Keep welcome identity bullets dynamic.
3. Label fixes vs intentional features accurately.
4. Do not rely on README alone; the in-app guide is the user-facing surface.
5. CI/docs-only with no binary behavior change → content update optional.

## Wrong vs correct

### Wrong

Ship a user-visible fix/feature but leave `WhatsNewData.pages` describing the previous build.

### Correct

Update `lib/pages/onboarding/whats_new_data.dart` in the same change set so the next build's first open explains the change.

### Wrong

```dart
bullets: [
  'Commit Hash: a11b6ad56',
  'Build Time: 2026-07-22 12:00:00',
],
```

### Correct

```dart
bullets: [
  '版本：$versionLabel',
  'Build Time：$buildTimeLabel',
  'Commit Hash：$commitLabel',
],
```