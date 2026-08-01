# Flutter Seal Download Delegate and Manager

This document tracks the PiliPlus side of Seal protocol v3. Seal remains the
download/queue/file owner; PiliPlus provides a typed status panel and a
persisted management surface for caller-owned tasks.

## Runtime flow

```text
Seal directed broadcast or Activity result
→ Android SealDownloadStatusBridge
→ SealDownloadChannelDispatcher
→ SealDownloadUtils / DownloadManagerService
→ DownloadTaskRepository / download manager UI
```

`SealDownloadChannelDispatcher` is the sole Dart owner of the
`pili_plus/seal_download` MethodChannel handler. Feature consumers register
typed listeners instead of calling `setMethodCallHandler` themselves.

## Live status payload

The bridge accepts the existing error/file/strip fields plus:

| Key | Meaning |
|---|---|
| `task_id` / `task_ids` | Seal task identity; batch callbacks expand per task |
| `caller_request_id` | PiliPlus request correlation |
| `status` | waiting/downloading/paused/completed/failed/canceled and compatibility aliases |
| `progress` | normalized `0.0..1.0` |
| `downloaded_bytes` / `total_bytes` | non-negative byte counts |
| `title` / `quality` | resolved display metadata |
| `source_url` | original delegated URL |
| `extract_audio` | audio-only hint |

Stable local identity is `taskId ?? callerRequestId`. This lets one batch
request produce multiple independent queue rows without duplicating the
request-only placeholder.

## Task control

PiliPlus calls `taskAction` with `pause`, `resume`, `retry`, or `delete`. The
Android channel launches Seal's explicit
`com.chloemlla.seal.ExternalDownloadControlActivity` with a request code that
is independent of the download launch request.

Seal trusts only `Activity.callingPackage`, verifies persisted ownership, and
returns the action result through Activity Result. Paused and failed tasks keep
ownership and task-scoped cookies for resume/retry. Completed, canceled, and
deleted tasks clean them up. Natural cancellation must never be reclassified as
pause. A process-restart interruption of an owned waiting/downloading task is
explicitly recovered as resumable `paused`.

## Persistence and startup

- `DownloadTaskRepository` stores typed JSON under
  `LocalCacheKey.sealDownloadTaskHistory`.
- Malformed rows are skipped; identities are deduplicated; storage is bounded
  to 200 active/newest history rows.
- Writes are serialized and best-effort failures use the central handled
  persistence reporter.
- `registerFeatureServices()` awaits restore ordering, but
  `DownloadManagerService.initialize()` contains storage/channel failures,
  records handled diagnostics under `download_manager`, and cannot make this
  optional feature a fatal startup dependency.
- Full app-data reset clears the download-task repository before shared boxes.

## Verification contract

Local Flutter/Gradle builds are prohibited for this repository. CI must run the
actual compile/tests. Focused tests cover typed parsing, stable identity,
persistence recovery, ownership authorization, live snapshots, pause recovery,
and natural cancellation semantics.
