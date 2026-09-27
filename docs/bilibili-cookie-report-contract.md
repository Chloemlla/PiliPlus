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
| Trigger | edits + 5 min timer | **login completed** |
| Kill switch | `synapseSyncEnabled` | `synapseCookieReportEnabled` (default on) |

## Where it fires

- `lib/pages/login/controller.dart` — `setAccount()` (QR poll, password, SMS,
  safe-center SMS verification) and `loginByCookie()` (pasted cookie).
- `lib/utils/login_utils.dart` — `onLoginMain()`, i.e. the main account session
  becoming logged in (including switching to a logged-in account).

A single login reaches more than one of those callbacks, so the same UID is
reported at most once per `SynapseCookieReport.duplicateWindow` (45 s). After
the window a re-login reports again — this channel deliberately does **not**
dedupe by cookie hash the way `syncAllBilibiliAccounts()` does, because the
requirement is "one report per completed login".

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

`reportAfterLogin()` never throws and never shows UI: no toast, no dialog, no
retry loop. Outcomes are `SynapseCookieReportDecision` values used for
breadcrumbs and tests. Failures record the error *type* only; the cookie text
must never enter a log line, crash context, or breadcrumb.

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
(disabled / anonymous / duplicate / window expiry / per-UID), the payload
key set against the contract, cookie serialization, and the header-vs-body
device id agreement the server enforces.
