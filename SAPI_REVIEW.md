# SAPI-SK Implementation Review & Repository Cleanup Guide

> **Repository:** `skrabytomo/Epostak`  
> **Scope:** `EpostakClient.pas` + supporting files vs. official SAPI-SK documentation  
> **Date:** 2026-08-20  
> **Status:** ✅ Functional for sandbox / low-volume; ⚠️ needs hardening before production

---

## 1. Implementation Accuracy Checklist

### ✅ Correctly Implemented

| Feature | Evidence | Notes |
|---------|----------|-------|
| **Endpoint paths** | `POST /auth/token`, `POST /document/send`, `GET /document/receive`, `GET /document/receive/{id}`, `POST /document/receive/{id}/acknowledge` | All 4 document endpoints + auth present |
| **Mandatory headers** | `Authorization: Bearer`, `X-Peppol-Participant-Id`, `Idempotency-Key` | Sent exactly where required |
| **Metadata wrapper** | `documentId`, `documentTypeId`, `processId`, `senderParticipantId`, `receiverParticipantId`, `creationDateTime` | All required fields present in `SendInvoice` |
| **Payload format** | `payloadFormat: "XML"`, `payloadEncoding: "UTF-8"` | Payload is JSON-escaped string (not base64), matching spec |
| **Token caching** | `FTokenExpiresAtUTC` with 60-second reserve | `EnsureToken` avoids minting before every request |
| **Participant switch on send** | `FParticipantId` temporarily overridden to `ASenderParticipantId` with `try..finally` | Correct for partner tokens (`sk_int_*`) |
| **Raw byte handling** | `SaveRawBytesToFile` + `GetDocumentXML` | UTF-8 preserved without ANSI/Unicode conversion; critical for Delphi 6 |
| **Demo credentials** | `EpostakDemoCreds.pas` | Both Firm A and Firm B populated; `ResolveDemoCredentials` helper is practical |
| **WinInet transport** | `DoRequest` using `InternetOpen` → `InternetConnect` → `HttpOpenRequest` → `HttpSendRequest` | Zero external dependencies, Delphi 6 compatible |

---

### ⚠️ Minor Deviations / Missing Optional Features

| Item | Spec Requirement | Current Implementation | Impact |
|------|------------------|----------------------|--------|
| **`checksum`** | Optional SHA-256 hex digest of payload | Not computed or sent | Functional, but no wrapper-level integrity check |
| **`scope` in auth** | Optional scope restriction (`documents:send documents:read`) | Not sent | Functional; server returns default scopes |
| **`pageToken`** | Pagination for `GET /document/receive` | Not implemented | **Risk:** >100 unacknowledged documents will be invisible |
| **202 response details** | `providerDocumentId`, `status`, `receivedAt`, `timestamp` | Only `providerDocumentId` extracted | Functional; timestamps ignored |
| **Acknowledge response** | `acknowledgedDateTime` | Only HTTP 200 checked | Functional; confirmation timestamp not logged |
| **`/auth/token/status`** | Recommended health check before document ops | Not implemented | Non-critical; useful for diagnostics |
| **`/auth/revoke`** | Revoke token on incident / logout | Not implemented | Security gap if token leaks |

---

### ❌ Bugs & Pre-Production Deficiencies

#### 1. `creationDateTime` uses local time instead of UTC
**Location:** `EpostakClient.pas` (~line 340)
```pascal
NowUtc := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now);
```
`Now` returns **local system time**, but the trailing `Z` claims it is UTC.
During CEST (summer time), the timestamp is **+2 hours ahead** of actual UTC.

**Fix:** Use `GetSystemTime` (Windows API) or calculate `Now - TimeZoneBias`.
```pascal
// Delphi 6 compatible UTC fix
var
  ST: TSystemTime;
begin
  GetSystemTime(ST);
  NowUtc := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', 
    SystemTimeToDateTime(ST));
end;
```

---

#### 2. Chýba `/auth/renew` — refresh token sa vôbec neukladá
**Location:** `EpostakClient.Authenticate`
`refresh_token` is extracted from JSON but **never stored** in any field.
When token expires, the code performs a full `client_credentials` exchange instead of `refresh_token` rotation.

**Spec:**
> *"Cacheujte access_token 15 minút a refresh_token 30 dní. Pri prvej 401 alebo pred expiráciou zavolajte `/auth/renew`."*

**Impact:**
- Adds ~100 ms latency per docs on every token refresh.
- Increases rate-limit risk.
- Less efficient for partner (`sk_int_*`) workflows.

**Fix:**
1. Add `FRefreshToken: string`.
2. Store `refresh_token` in `Authenticate`.
3. Implement `RenewToken` calling `POST /auth/renew` with `grant_type=refresh_token`.
4. Call `RenewToken` when `should_refresh` is true or on first `401`.

---

#### 3. No retry logic for retryable errors
**Spec marks these as retryable with exponential backoff:**
- `409 CONFLICT` (Idempotency key in-flight / mismatch)
- `429 RATE_LIMITED`
- `503 TEMPORARY`

**Current behavior:** `CheckResult` immediately raises an exception on any non-2xx status.

**Impact:** Transient network issues or idempotency collisions cause hard failures that should self-heal.

**Fix:** Wrap `DoRequest` with a retry loop (max 3–5 attempts, exponential backoff). Read `Retry-After` header when present.

---

#### 4. Error parser is brittle and ignores `requestId`
**Spec format:**
```json
{"error":{"code":"...","message":"...","requestId":"..."}}
```

**Current behavior:** `ExtractJSONString(ResponseBody, 'code')` does a flat string search. It does not:
- Parse the nested `error` object.
- Extract `requestId` (essential for support tickets).
- Guard against false positives if `"code"` appears inside `message`.

**Fix:** Parse the `error` wrapper explicitly, or at minimum extract `requestId` alongside `code` and `message`.

---

#### 5. `ListReceived` ignores `nextPageToken`
**Spec:**
> *"Zoznam je stránkovaný od najstarších nespracovaných dokumentov; ak príde `nextPageToken`, pokračujte ďalšou stránkou."*

**Current behavior:** The function accepts `ALimit` (max 100) but never follows pagination. If a firm has >100 unacknowledged documents, older ones are unreachable.

**Fix:** Return `nextPageToken` as an `out` parameter or add it to a result record. Provide a helper that auto-pages.

---

#### 6. Rate-limit headers are not parsed
**Spec headers on `429`:** `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`, `Retry-After`.

**Current behavior:** Headers are never read from the WinInet response.

**Fix:** After `HttpQueryInfo` for status code, also query `HTTP_QUERY_RAW_HEADERS_CRLF` and parse the rate-limit values.

---

#### 7. `SendInvoice` nevaliduje dĺžku `documentId`
**Spec:** `metadata.documentId` max **255 znakov**.

**Current behavior:** `ADocumentId` is used directly without length check.

**Impact:** Server returns `400 VALIDATION`, but client could catch this locally.

**Fix:** Add `if Length(ADocumentId) > 255 then raise Exception.Create(...)` in `SendInvoice`.

---

#### 8. Bezpečnostné upozornenie: `client_secret` v `.ini` a zdrojáku
**Location:** `INTEGRATION.md` shows loading `ClientId` / `ClientSecret` from `.ini` via `TIniFile`.

**Spec warning:**
> *"client_secret: Nikdy neposielať do frontendu, do logov ani do support screenshotov."*

**Impact:** GUI app stores secrets in plain text on disk; backup files (`.~pas`) may leak them into git.

**Fix for production:**
- Use Windows DPAPI (`CryptProtectData`) or Credential Manager.
- At minimum, encrypt the `.ini` section or store secrets in registry with restricted ACL.
- Never commit real secrets to version control.

---

## 2. Repository Cleanup & File Optimization

### Files That Should Be Removed

| File | Reason | Action |
|------|--------|--------|
| `EpostakClient.~pas` | Delphi editor backup | **Delete** |
| `EpostakDemoCreds.~pas` | Delphi editor backup | **Delete** |
| `EpostakApp.~dpr` | Delphi editor backup | **Delete** |
| `EpostakTest.~dpr` | Delphi editor backup | **Delete** |
| `UMainForm.~pas` | Delphi editor backup | **Delete** |
| `UMainForm.~dfm` | Delphi editor backup | **Delete** |
| `EpostakClient.dcu` | Compiled unit | **Delete** + add to `.gitignore` |
| `EpostakDemoCreds.dcu` | Compiled unit | **Delete** + add to `.gitignore` |
| `UMainForm.dcu` | Compiled unit | **Delete** + add to `.gitignore` |
| `UTestForm.dcu` | Compiled unit | **Delete** + add to `.gitignore` |
| `EpostakApp.exe` | Compiled binary | **Delete** + add to `.gitignore` |
| `EpostakGuiApp.exe` | Compiled binary | **Delete** + add to `.gitignore` |
| `EpostakTest.exe` | Compiled binary | **Delete** + add to `.gitignore` |
| `EpostakTestGUI.exe` | Compiled binary | **Delete** + add to `.gitignore` |
| `EpostakApp.cfg` | Delphi config (regenerable) | **Delete** + add to `.gitignore` |
| `EpostakApp.dof` | Delphi options (regenerable) | **Delete** + add to `.gitignore` |
| `EpostakTest.cfg` | Delphi config (regenerable) | **Delete** + add to `.gitignore` |
| `EpostakTest.dof` | Delphi options (regenerable) | **Delete** + add to `.gitignore` |
| `files.zip` | Empty / 22-byte artifact | **Delete** |
| `Ep24Sender.ini` | Legacy epodatelna24 config (superseded by `INTEGRATION.md`) | **Delete** or move to `archive/` |
| `UMainForm.ddp` | Delphi diagram file (empty / unused) | **Delete** |

### Files That Could Be Merged or Consolidated

| Current State | Proposal | Rationale |
|---------------|----------|-----------|
| `EpostakTest.dpr` + `EpostakTestGUI.dpr` | Keep **one** primary test. Merge GUI features into `EpostakTestGUI.dpr` and delete `EpostakTest.dpr`, OR keep console test as the canonical CI test. | Two test executables with identical logic create maintenance debt. |
| `EpostakApp.dpr` + `EpostakGuiApp.dpr` | Clarify or merge. `EpostakGuiApp.dpr` appears to be a lightweight launcher; `EpostakApp.dpr` + `UMainForm` is the full GUI. | Having two GUI entry points is confusing. Keep `EpostakApp.dpr` as main, delete `EpostakGuiApp.dpr` if it adds no value. |
| `EpostakDemoCreds.pas` | **Keep separate** — do not merge into `EpostakClient.pas`. | Demo credentials should be opt-in and easily excluded from production builds. |
| `INTEGRATION.md` | **Keep**, but rename to `MIGRATION.md` or `EP24_MIGRATION.md` for clarity. | Valuable for existing epodatelna24 users; name should reflect purpose. |

### Proposed Clean Repository Structure

```
Epostak/
├── README.md                          # Missing — should describe project, build steps, link to SAPI docs
├── SAPI_REVIEW.md                     # This file
├── .gitignore                         # Missing — exclude *.exe, *.dcu, *.~*, *.cfg, *.dof, *.local
├── src/
│   ├── EpostakClient.pas              # Core library (with fixes below applied)
│   ├── EpostakDemoCreds.pas           # Sandbox demo credentials
│   └── EpostakClientUtils.pas         # Optional: Extract SaveRawBytesToFile, JSON helpers, UTC utils here
├── gui/
│   ├── EpostakApp.dpr                 # Main GUI application
│   ├── UMainForm.pas
│   ├── UMainForm.dfm
│   ├── UTestForm.pas                  # Optional: in-app test panel
│   └── UTestForm.dfm
├── test/
│   ├── EpostakTest.dpr                # Console test (CI-friendly, no VCL)
│   └── sample-invoice.xml             # Renamed from UUID filename
└── docs/
    └── EP24_MIGRATION.md              # Renamed from INTEGRATION.md
```

---

## 3. Recommended `.gitignore` (Delphi 6/7)

```gitignore
# Delphi compiled binaries
*.exe
*.dll
*.bpl

# Compiled units
*.dcu
*.dcp
*.bpi

# Delphi backups
*.~*
*.bak

# Project local config
*.cfg
*.dof
*.dsk
*.local
*.identcache
*.tvsconfig

# Debug / output
__history/
__recovery/
```

---

## 4. Priority Fix List (Pre-Production)

| Priority | Fix | Effort | Risk if Ignored |
|----------|-----|--------|-----------------|
| 🔴 **P0** | Fix `creationDateTime` to real UTC | 10 min | Invalid timestamps, potential rejection by strict receivers |
| 🔴 **P0** | Implement `/auth/renew` + store `refresh_token` | 30 min | Rate-limit hits, unnecessary latency on every token expiry |
| 🟡 **P1** | Add retry logic for `409`, `429`, `503` | 1–2 h | False failures under load or transient errors |
| 🟡 **P1** | Parse `nextPageToken` in `ListReceived` | 1 h | Lost documents in high-volume inboxes |
| 🟡 **P1** | Extract `requestId` from error responses | 30 min | Impossible to trace failures with support |
| 🟢 **P2** | Validate `documentId` ≤ 255 chars | 5 min | Unnecessary 400 errors from server |
| 🟢 **P2** | Add `/auth/token/status` health check | 30 min | Harder to diagnose auth issues |
| 🟢 **P2** | Secure credential storage (not `.ini`) | 2–4 h | Secret leakage, compliance issues |
| ⚪ **P3** | Repository cleanup (delete backups/binaries) | 15 min | Repo bloat, accidental secret commits |

---

## 5. Quick Reference: SAPI-SK Spec vs. Code Mapping

| Spec Concept | Code Location | Status |
|--------------|---------------|--------|
| `POST /auth/token` | `TEpostakClient.Authenticate` | ✅ |
| `POST /auth/renew` | *Missing* | ❌ |
| `POST /auth/revoke` | *Missing* | ❌ |
| `GET /auth/token/status` | *Missing* | ⚠️ |
| `POST /document/send` | `TEpostakClient.SendInvoice` | ✅ |
| `GET /document/receive` | `TEpostakClient.ListReceived` | ⚠️ (no pagination) |
| `GET /document/receive/{id}` | `TEpostakClient.GetDocumentXML` | ✅ |
| `POST /document/receive/{id}/acknowledge` | `TEpostakClient.AcknowledgeDocument` | ✅ |
| `X-Peppol-Participant-Id` | `DoRequest` header | ✅ |
| `Idempotency-Key` | `SendInvoice` auto-generated UUID | ✅ |
| `checksum` (SHA-256) | *Missing* | ⚠️ |
| `scope` | *Missing* | ⚠️ |

---

*Generated for inclusion in `skrabytomo/Epostak` repository. Apply P0 fixes before production go-live.*
