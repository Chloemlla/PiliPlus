# Bilibili Settings Sync Contract

This document defines the cross-repository contract for synchronizing
Bilibili-related settings through Synapse.

## Security gates

The feature is disabled unless the PiliPlus account currently has a validated
Bilibili login with a non-empty UID.

- Logged-out users must not see an active sync action, create a bind request,
  or send records to `/api/bilibili-sync`.
- A local UID alone is not proof of login. The bind operation must send the
  transient Bilibili cookie to the backend over TLS.
- The backend must validate the cookie against Bilibili's authenticated user
  endpoint and compare the returned UID with the requested UID. Missing,
  expired, invalid, or mismatched cookies fail closed.
- The backend must not trust a client-supplied `isLoggedIn`, nickname, or UID
  without the cookie validation result.
- After a successful validation, the backend stores the cookie only in an
  encrypted credential archive scoped to the authenticated Synapse user and
  verified Bilibili UID. It is never stored in plaintext, sync records, logs,
  analytics, or response bodies.

Recommended failure codes are `BILIBILI_AUTH_REQUIRED`,
`BILIBILI_COOKIE_INVALID`, and `BILIBILI_UID_CONFLICT`. They must not reveal
the cookie value or the detailed upstream response.

## API shape

All routes below require the existing Synapse account session. PiliPlus
opens the Synapse `/login` page in `flutter_inappwebview`, reads the
HttpOnly `synapse_token` cookie after login, and stores that credential in its
encrypted secret sidecar. The user never pastes or sees a JWT.

```http
POST /api/bilibili-sync/uid
Authorization: Bearer <sync-access-token>
Content-Type: application/json
```

The bind request is the only request that may contain a cookie, and its
cookie is transient input rather than synchronized data:

```json
{
  "uid": "12345",
  "cookie": "session-cookie-placeholder"
}
```

On success, the response contains only the verified identity and capability:

```json
{
  "success": true,
  "data": {
    "bound": true,
    "uid": "12345",
    "boundAt": "2026-08-01T00:00:00.000Z"
  }
}
```

Settings use optimistic versioning:

```http
GET /api/bilibili-sync/settings
PUT /api/bilibili-sync/settings
```

Search history uses batch upsert/tombstones and time-based incremental reads:

```json
{
  "records": [{
    "id": "client-record-id",
    "keyword": "搜索词",
    "updatedAt": "2026-08-01T00:00:00.000Z",
    "isDeleted": false
  }]
}
```

`POST /api/bilibili-sync/search-records/batch` and
`GET /api/bilibili-sync/search-records/changes?since=<ISO-8601>` are the
corresponding endpoints. The server-side credential archive is encrypted
with AES-GCM and is separate from synchronized settings/search records.
Synchronized settings must not contain `cookie`, `cookies`, `SESSDATA`,
`bili_jct`, `DedeUserID`, authorization headers, or access/refresh tokens.

## Conflict protocol

- Settings use `baseVersion`; a stale write returns `409` and an opaque
  summary, never decrypted values.
- Search records are isolated by authenticated user, deduplicated by stable
  record ID/normalized keyword, and deleted records remain as tombstones.
- Incremental search reads use the server timestamp cursor and include
  tombstones so another device cannot resurrect deleted entries.
- When a binding is revoked or Bilibili login is lost, the client stops sync;
  the server must reject further Bilibili-category writes until a new bind is
  validated. Existing opaque records may be retained according to the normal
  account retention policy, but must not be decrypted for recovery.

## Privacy and logging boundary

Cookie handling is deliberately narrower than settings handling:

1. Receive only over TLS.
2. Use it for an upstream UID/validity check before accepting the bind.
3. After successful validation, encrypt it with the server credential key and
   store it only as ciphertext in the dedicated per-user/per-UID credential
   archive. Never store it in plaintext sync fields, files, caches, sync
   payloads, analytics, crash reports, audit details, or HTTP response bodies.
4. Do not include it in request/response logging, exception messages, tracing,
   metrics labels, or test snapshots. Redact the `Cookie`, `Set-Cookie`,
   `SESSDATA`, `bili_jct`, and `DedeUserID` fields before logging.
5. Do not treat the UID as a secret, but do minimize exposure: it may appear
   in the bind result and opaque-record metadata only when needed for routing.

The client must also exclude cookies from settings export/import. A settings
restore must never turn an imported UID into an authenticated Bilibili session.

## Boundary test matrix

The repositories include contract-vector tests and service-level coverage for
the binding, archive, conflict, deduplication, and tombstone rules. Full
handler/client integration remains a CI deployment concern because this
contract depends on the live Bilibili verification endpoint and MongoDB.

| Case | Required result |
| --- | --- |
| No Bilibili login | Sync capability is disabled; no bind or sync request |
| Invalid/expired cookie | Bind rejected; no settings write |
| Cookie UID differs from requested UID | Bind rejected; no settings write |
| Valid cookie and matching UID | Bind succeeds; response has no cookie and the archive stores ciphertext only |
| Cookie in a settings record | Serialization rejects or strips it |
| Cookie in logs/errors/response | Test fails; secret must be redacted/absent |
| Older concurrent record | Conflict is explicit and opaque |
| Lost/revoked binding | Later Bilibili writes rejected |
| Unbind/revalidation failure | Encrypted archive is deleted or marked invalid; sync fails closed |

