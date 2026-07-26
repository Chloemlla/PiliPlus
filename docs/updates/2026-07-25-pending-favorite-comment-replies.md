# Favorite Comment Replies with View Entry

- Date: 2026-07-25
- Commit: pending
- Author: Implement Agent
- Type: feat

## Summary

Expose local comment favorites in production UI (not only debug), fix the saveReply storage default mismatch so the reply box opens by default, and make the view entry for favorited comments clear on Mine and MyReply.

## Changes

- `ReplyItemGrpc.morePanel`: production **收藏评论** / **取消收藏** near **保存评论**, using `ReplyCacheStore` (LRU); when store disabled, toast + open extra settings highlight for **记录评论**
- Mine header tooltip/icon: **收藏的评论** with star icon; quick action row **收藏的评论** → `/myReply` (or enable-setting toast)
- MyReply AppBar title **收藏的评论**; empty state hints more-menu favorite; import/clear/delete go through `replyCacheStore`
- `GStorage.init`: `saveReply` `defaultValue: true` to match Pref / extra settings

## Verification

- Code review against existing reply storage / morePanel / mine patterns
- Local Flutter build/test not run (project policy: GitHub Actions only)

## Impact

- Users can favorite any comment from the more menu and browse them under Mine
- Default installs with unset `saveReply` now open the reply box (aligned with settings UI default)
- Risk: low (local storage + UI only)

## Follow-ups

- Parent agent: commit, push, green CI via `gh`
- Rename notes file SHA after commit
