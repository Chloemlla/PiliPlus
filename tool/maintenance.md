# Maintenance Notes

## Flutter SDK patches

`lib/scripts/patch.ps1` mutates the Flutter SDK checkout referenced by
`FLUTTER_ROOT` during CI builds. This is release-critical behavior and must stay
owned by the release maintainer for the target platform.

Rules for changing SDK patches:

- Keep every patch file under `lib/scripts/` and reference the upstream Flutter
  issue or pull request in `patch.ps1` when one exists.
- Before upgrading Flutter, run `lib/scripts/patch.ps1 <platform>` against a
  clean SDK checkout and confirm every `git apply`, revert, or cherry-pick still
  applies intentionally.
- Remove a local patch as soon as the target Flutter version contains the
  upstream fix.
- Never point `FLUTTER_ROOT` at the project repository. The script intentionally
  refuses to run when `FLUTTER_ROOT == GITHUB_WORKSPACE`.

## Large UI and playback modules

The video page, player controls, settings, and download service are high-change
areas. Avoid broad refactors without tests around the behavior being moved.

Preferred split order:

- Extract pure parsing, scheduling, and validation helpers first.
- Move network or storage work behind small service methods before changing UI.
- Keep layout-only changes separate from state or persistence changes.
- Add regression tests for the extracted helper before deleting the original
  inline logic.

Current priority seams:

- `lib/services/download/download_service.dart`: scheduler and persisted task
  state.
- `lib/plugin/pl_player/**`: controller state and command handling.
- `lib/pages/video/**`: view composition versus request/state orchestration.
- `lib/pages/setting/**`: reusable setting item models and import validation.
