Repository Guidelines

Do not write to a super file!!!! Do not write to a super file!!!! Do not write to a super file!!!!
All actual build and test commands must be executed within the GitHub workflow; running them on your local machine is prohibited—local device performance is insufficient.

don't run any Flutter and Gradle; modify the code.

Regarding the garbled text issue you mentioned, it has been confirmed that it is not caused by file corruption. The file can be read correctly in PowerShell using the following method:
powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
Get-Content -Encoding UTF8 file-path
Each time you complete the addition or modification of a feature according to my requirements, a commit message should be automatically generated and submitted and pushed after you finish modifying the code. When submitting a GPG key, you can temporarily omit the signature.auto push

apply_patch 在当前环境可用。

  原因
  之前失败是因为 patch 头写成了：

  *** Begin Patch ***

  正确格式必须是：

  *** Begin Patch
  ...
  *** End Patch

  末尾不能多写 ***。工具只认精确的 *** Begin Patch 作为第一行。

## Build Whats-New Guide (mandatory for user-facing commits)

Every user-facing feature/fix commit must update the immersive "本次更新说明" content:

- Edit `lib/pages/onboarding/whats_new_data.dart` (`WhatsNewData.pages`) in the same change set.
- Detection is by `BuildConfig.commitHash` + `BuildConfig.buildTime` (not a one-shot boolean).
- Keep welcome identity bullets dynamic via `WhatsNewData` label getters; never hard-code hash/time.
- Branch-long fork deltas go to first-install `ImprovementsGuideData`; this-build notes go to `WhatsNewData`.
- Full contract: `docs/flutter-build-whats-new.md` (tracked) and local Trellis `.trellis/spec/frontend/flutter-build-whats-new.md`.

Skip only for pure docs/CI/format/lockfile changes with no user-visible app behavior change.

## CI / Failed Actions Auto-Repair (mandatory)

When repairing PRs or failed GitHub Actions:

1. Use **gh CLI** to inventory and inspect **all** failures (`gh pr checks`, `gh run list`, `gh run view --log-failed`). Do not stop at the first red job.
2. Auto-delegate **parallel subagents** by independent root-cause class; merge patches in the main session.
3. **Forbidden**: local Flutter / Gradle / emulator / full test builds. CI is the only build/test authority.
4. **Allowed**: declarative dependency installs for static inspection (`dart pub get` / `flutter pub get`).
5. After commit/push, verify with gh (`gh run rerun --failed` / `gh pr checks`) and loop until every inventoried failure is green or explicitly blocked.
6. Full contract: `docs/ci-action-auto-repair.md` (tracked) and local Trellis `.trellis/spec/frontend/ci-action-auto-repair.md`.
