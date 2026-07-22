# CI Action Auto-Repair

## Scenario: Repair every open PR fix set and every failed GitHub Action via gh CLI + parallel subagents

### 1. Scope / Trigger

- Trigger (any of):
  - user asks to fix CI / Actions / PR checks
  - after push/PR open, checks are red
  - session finds failed workflow runs for the current branch or open PRs
  - bulk recovery after sync/merge waves
- Scope:
  - all open PRs that need fixes for failing checks
  - all failed workflow runs on the active branch / those PRs
  - workflow YAML under `.github/workflows/`
  - app/code fixes required to make CI green
- Out of scope:
  - local Flutter/Gradle/Android emulator builds
  - inventing secrets the repo does not have
  - force-pushing other authors' branches without explicit ask

### 2. Signatures

```bash
# Inventory
gh pr list --state open --json number,title,headRefName,url,statusCheckRollup
gh run list --branch <branch> --limit 20 --json databaseId,workflowName,status,conclusion,url,headSha,displayTitle,event
gh run list --status failure --limit 30 --json databaseId,workflowName,status,conclusion,url,headBranch,headSha,event

# Inspect one failure
gh run view <run-id>
gh run view <run-id> --json jobs,conclusion,status,url,headSha,workflowName
gh run view <run-id> --log-failed
gh run view <run-id> --job <job-id> --log

# PR-centric
gh pr checks <pr-number>
gh pr view <pr-number> --json statusCheckRollup,commits,files,baseRefName,headRefName

# Re-run after fix push
gh run rerun <run-id> --failed
# or rely on push-triggered re-run when commits land

# Optional declarative deps only (NO build/test)
dart pub get
# or: flutter pub get   # only if required to resolve analyzer/import graph textually
# NEVER: flutter build / flutter test / gradle / emulator
```

### 3. Contracts

#### Hard bans

1. **No local builds/tests**: do not run Flutter, Gradle, Android emulator, Xcode, or full app test suites on the local machine.
2. **CI is the verifier**: build/test proof comes from GitHub Actions after push.
3. **No secret printing**: redact tokens from logs when quoting Action output.
4. **No silent scope drop**: every failed Action for the target PR/branch set must be classified (fixed / deferred with reason / blocked).

#### Required tool

- Use **`gh` CLI** as the primary control plane for:
  - listing failed runs
  - reading failed job logs
  - reading PR check rollups
  - re-running failed jobs after fixes
- Do not ask the user to paste CI logs when `gh` can fetch them.

#### Parallel subagent dispatch (mandatory when multi-failure)

When there is more than one independent failure class, the main agent **must** fan out:

| Failure class example | Subagent task shape |
|---|---|
| Workflow YAML / permissions / cache | fix workflow wiring |
| Analyzer / Dart compile | fix Dart sources |
| Android baseline / emulator | fix baseline profile / emulator script contracts |
| iOS/macOS packaging | fix platform project files |
| Dependency/lock mismatch | fix pubspec/lock pins (no local full resolve if avoidable) |

Rules:

1. Group failures by **root cause**, not by raw job name spam.
2. Spawn **one subagent per independent root cause** in parallel.
3. Each subagent prompt must include:
   - active branch / PR number
   - run id(s) + job name(s)
   - failed log excerpts or `gh` commands to fetch them
   - hard ban: no local Flutter/Gradle builds
   - allowed: declarative installs (`pub get`) if needed for static inspection
   - required: edit code/workflow, commit message suggestion, and residual risk
4. Main agent merges non-overlapping patches, resolves conflicts, commits, pushes, then uses `gh` to verify/re-run.
5. If the platform is Codex inline with no spawn capability, still **simulate parallelization** by:
   - inventory all failures first
   - fix independent classes in separate sequential mini-passes without dropping any class
   - never stop after the first red job

#### Declarative dependency installs (allowed)

Allowed when needed for static understanding only:

- `dart pub get` / `flutter pub get`
- reading lockfiles, workflow YAML, generated contracts
- lightweight text/search tooling

Still forbidden after install:

- `flutter build *`
- `flutter test`
- `gradlew` / Android emulator runner locally
- packaging/signing

#### End-to-end repair loop

```
1. Inventory
   - open PRs + current branch failed runs via gh
2. Classify
   - map each failed job -> root cause class
3. Dispatch
   - parallel subagents per class (or sequential multi-pass if spawn unavailable)
4. Patch
   - code and/or workflow edits only
5. Commit + push
   - auto commit/push per AGENTS.md
   - if user-facing app change: also update WhatsNewData.pages
6. Verify with gh
   - watch new run / `gh run rerun --failed`
   - pull new failed logs if still red
7. Repeat until green or blocked
```

#### Definition of done for a CI repair session

- Every inventoried failed Action is either green or explicitly blocked with reason.
- No local build was used as proof.
- PR checks for the target PR/branch are re-checked via `gh pr checks` / `gh run list`.
- Residual flaky infra (runner OOM, GitHub outage) is labeled as blocked, not "fixed".

### 4. Validation & Error Matrix

| Condition | Expected |
|---|---|
| Multiple failed jobs, same root cause | one subagent/pass fixes shared root |
| Multiple failed jobs, different roots | parallel subagents / multi-pass; do not fix only one |
| `gh` auth missing | stop and report; do not invent logs |
| Failed log too large | use `--log-failed` + targeted job logs; summarize root lines |
| Fix requires binary proof | push and let Actions rebuild; do not run local Flutter/Gradle |
| Need packages for analyzer reading | declarative `pub get` only |
| Action still fails after push | re-fetch logs with `gh`; continue loop |
| Baseline profile PR noise | follow `android-baseline-profile.md` (e.g. skip on PR if policy) |
| Secret in log excerpt | redact before writing to chat/docs |

### 5. Good/Base/Bad Cases

- Good: inventory 4 red jobs → 2 root causes (workflow cache + Dart null-safety) → two parallel fix agents → one push → `gh run rerun --failed` → green.
- Good: only workflow syntax failure → single pass edits `.github/workflows/*` → push → verify with `gh`.
- Base: one failed job, clear stack frame in app code → direct patch + push + gh verify.
- Bad: run `flutter build apk` locally "just to check".
- Bad: fix the first failed job and ignore the rest of the PR check rollup.
- Bad: ask user to open GitHub UI and paste logs while `gh` is authenticated.
- Bad: mark done because local `dart analyze` is clean while Actions are still red.

### 6. Tests Required

Process assertions for agents (no local app test runner required):

- Assert inventory used `gh pr checks` / `gh run list` before coding.
- Assert every failed conclusion from inventory appears in the final status table.
- Assert no command history contains local `flutter build`, `flutter test`, or `gradlew` for verification.
- Assert post-fix verification used `gh` run/PR checks.
- Assert multi-root failures produced multi-agent or multi-pass handling notes.

### 7. Wrong vs Correct

#### Wrong

```bash
flutter build apk   # local proof
# fix one job only
# declare CI done
```

#### Correct

```bash
gh pr checks 12
gh run list --branch ci/foo --status failure
gh run view 123456789 --log-failed
# parallel/root-cause patches
git commit && git push
gh run rerun 123456789 --failed
gh pr checks 12
```

#### Wrong

```text
Subagent: "I couldn't run Gradle so I skipped Android baseline failure."
```

#### Correct

```text
Subagent: edit workflow/script/contracts from failed log via gh;
push; verify Android job on Actions; no local emulator.
```

## Main-agent operating checklist

1. `gh pr list` + `gh run list` inventory
2. Build root-cause board
3. Dispatch parallel subagents (or multi-pass)
4. Merge patches, commit, push
5. `gh` re-check / rerun failed
6. Loop until all inventoried failures are green or blocked
7. Report table: run/job → cause → fix → final status

## Design Decisions

- **Why gh-first**: local machines are too weak; Actions already hold the real matrix (Android emulator, multi-OS).
- **Why parallel subagents**: PR repair waves often mix unrelated failures; serial-only handling drops work.
- **Why allow pub get**: static import/analyzer inspection sometimes needs packages, but never full builds.
- **Why ban local Flutter/Gradle**: project policy in `AGENTS.md`; CI is the system of record.