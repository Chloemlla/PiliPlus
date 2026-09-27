# Bilibili Login Cookie Report Contract

Client side of the cross-repository contract documented on the backend in
`Synapse/docs/bilibili-cookie-report-contract.md`. Implementation lives in
`lib/services/synapse_cookie_report.dart`.

## What it does

Every time a Bilibili login completes, PiliPlus files one copy of the cookie
that just worked with Synapse. This is **not** the settings-sync channel
(`docs/bilibili-settings-sync-contract.md`); it is a report-only sink:

| | settings/search sync | login cookie report |
|---|---|---|
| Synapse account, OAuth token, bind | required | **not required** |
| Identity of the caller | Synapse user + device | **device id only** |
| Reads anything back | yes | **no** |
| Trigger | edits + 5 min timer | **login completed + one sweep per launch** |
| Kill switch | `synapseSyncEnabled` | `synapseCookieReportEnabled` (default on) |

## Where it fires

- `lib/pages/login/controller.dart` — `setAccount()` (QR poll, password, SMS,
  safe-center SMS verification) and `loginByCookie()` (pasted cookie).
- `lib/utils/login_utils.dart` — `onLoginMain()`, i.e. the main account session
  becoming logged in (including switching to a logged-in account).
- `lib/utils/login_utils.dart` — `initializeSession()` runs
  `reportExistingAccounts()` once per launch, which walks every account already
  logged in on this device (main first) so a session that predates this channel
  — or one restored from a backup — still gets archived. Sequential, so a
  multi-account device never fires a burst.

## Counting contract (no repeated uploads)

The channel must not keep uploading the same session. `SynapseCookieReportLedger`
is persisted under `SettingBoxKey.synapseCookieReported` as
`uid -> {cookieHash, at, count, attempts}`:

| State | Decision |
|---|---|
| switch off | `skippedDisabled` |
| anonymous account / missing `DedeUserID` + `bili_jct` | `skippedAnonymous` |
| same UID sent again within `duplicateWindow` (45 s) | `skippedDuplicate` |
| `count > 0` for this exact cookie hash | `skippedAlreadyReported` |
| `attempts >= maxAttemptsPerCookie` (3) for this exact cookie hash | `skippedAttemptCap` |
| anything else | `sent` |

- A successful send bumps `count` and clears `attempts`, so a cookie leaves the
  device exactly once — relaunches, the startup sweep, and a session hook that
  re-sees the same cookie are all no-ops.
- A new login normally carries a new `SESSDATA`, so its hash is unseen and it is
  filed once. Pasting the *identical* cookie again does not re-upload it.
- A failed send burns one attempt against that hash and stops after three, so an
  unreachable or rejecting server is not hammered on every launch.
- `_inFlight` guards the same UID while a send is in progress: the login callback
  and the startup sweep can both look at a fresh cookie, and without it both
  would pass the ledger check before either result was recorded.
- Entries for accounts that are no longer on the device are dropped on load, and
  the ledger is capped at `maxLedgerEntries` (64) so the settings box cannot grow
  without bound.

## Request

```text
POST <provider base>/api/bilibili-reports/cookie
X-Device-Id / X-Synapse-Device-Id: identity.deviceId
{client_id, device_id, uid, cookie, isPrimary, client{…}}
```

- `cookie` is `name=value; name=value` from the account's own `cookieJar`
  (the same serialization the sync vault stores).
- No `Authorization` header: the endpoint accepts a report from a device that
  never logged into Synapse.
- The Dio instance is private to this file. It must not be `Request()`, which
  installs the Bilibili `AccountManager` interceptor and would leak the
  Synapse payload into Bilibili account routing, and it must not carry the
  first-visit human-check interceptor, which can show a dialog.
- HTTPS only, enforced by the shared base URL parser.

## Silence contract

`reportAfterLogin()` and `reportExistingAccounts()` never throw and never show
UI: no toast, no dialog, no retry loop. Outcomes are
`SynapseCookieReportDecision` values used for breadcrumbs and tests. Failures
record the error *type* only; the cookie text must never enter a log line, crash
context, or breadcrumb.

Disabled state is honored before anything is built, so switching the setting off
means zero outbound traffic on this channel (records already filed with Synapse
are unaffected).

## Server-side guarantees to rely on

- The claimed UID is never trusted: Synapse replays the cookie against
  `x/web-interface/nav` and rejects a mismatch, so a wrong or expired cookie is
  dropped instead of archived.
- Storage is AES-GCM ciphertext keyed by `(clientId, deviceId, bilibiliUid)`,
  capped at 32 UIDs per device, and no endpoint returns the plaintext.

## Tests

`test/services/synapse_cookie_report_test.dart` covers the decision table
(disabled / anonymous / new cookie / same cookie again / refreshed cookie /
attempt cap), the ledger state machine (success clears attempts, failure burns
one against the current cookie only), encode-decode round-trips including
malformed input, pruning of removed accounts and the entry cap, plus the payload
key set against the Synapse contract and the header-vs-body device id agreement.
