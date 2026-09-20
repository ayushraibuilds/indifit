# PV1-CLOUD-01A: Cloud Backup Threat Model, Architecture & Contracts

- **Status:** Complete (Contracts & Threat Model Frozen)
- **Date:** 2026-09-03
- **Branch:** `codex/post-v1-net-01-capability-boundary`
- **Parent Program:** [`../POST_V1_CLEANUP_PROGRAM.md`](../POST_V1_CLEANUP_PROGRAM.md)
- **Implementation Plan:** [`../POST_V1_IMPLEMENTATION_PLAN.md`](../POST_V1_IMPLEMENTATION_PLAN.md)
- **Prerequisite:** [`NET01_OFFLINE_CAPABILITY_MATRIX.md`](NET01_OFFLINE_CAPABILITY_MATRIX.md) (PV1-NET-01A)

---

## 1. Product & Architecture Position

Automatic Cloud Backup is the first connected service for IndiFit. It provides seamless data protection and multi-device restore without compromising IndiFit's foundational **local-first personal truth**.

```text
Local SQLite (Drift)
        ↓  Periodic / on-demand trigger (BackupV10Data)
V10 Immutable Snapshot Payload (JSON)
        ↓  Client-Side Envelope Encryption (AES-256-GCM)
Encrypted Snapshot Blob (.indifit-cloud-backup)
        ↓  Asynchronous Outbox Dispatch (any active connection)
IndiFit Cloud API (FastAPI) ──► S3 / Cloudflare R2 Bucket
        ▲
Hardware KMS / HSM (AWS KMS / GCP Cloud KMS / Cloudflare Key Vault)
(Keys strictly bound to verified Apple / Google OIDC Subject ID 'sub')
```

### Core Invariants

1. **Local Independence:** Local workout logging, food tracking, and weight entry never wait for cloud backup.
2. **Frictionless Consumer Auth:** Users authenticate via 1-tap **Sign in with Apple** (iOS) or **Sign in with Google** (Android / iOS). No manual registration or memorized passwords required.
3. **Identity-Bound Envelope Encryption:** Data is encrypted on-device via AES-256-GCM with a single-use Data Encryption Key (DEK). The DEK is wrapped by a hardware KMS/HSM keyed to the verified Apple/Google subject identifier (`sub`). The wrapping key itself is derived via HKDF-SHA256; the client refuses to encrypt when no per-user secret is configured (fail-closed, no shared default key).
4. **Zero Plaintext Storage:** S3/R2 storage holds only encrypted ciphertext blobs. Even in a complete storage bucket breach, user fitness records, body weights, and food logs remain encrypted.
5. **Manual Backup Coexistence:** Manual local export/restore (`.indifit-backup`) and device-local auto-backups (`indifit_auto_backup_1.json`) remain 100% operational.
6. **Key Loss Means Data Loss:** There is no backdoor recovery. If the user loses access to their Apple/Google account (`sub` rotated or unrecoverable) the wrapped DEKs cannot be unwrapped and cloud snapshots become permanently unreadable. The restore UI states this explicitly before upload is enabled.

### Key Custody, Rotation & Revocation

- **Custody:** The KMS wrapping key is bound to the OIDC `sub` and never leaves the HSM boundary; the app holds only short-lived unwrap grants, never the raw key.
- **Rotation:** KMS key rotation versions the wrapping key. Snapshots record the wrapping-key version; new uploads always use the latest version while older snapshots remain readable under their recorded version.
- **Device revocation:** Signing out or revoking a device drops local unwrap grants immediately. Queued uploads stay queued (never uploaded while unauthenticated) and retry after the next successful sign-in; they are never failed permanently by an auth transition.
- **Account deletion:** Purges the KMS grant, the device registry entry, and all snapshot blobs within 24 hours (see §6).

---

## 2. Threat Vector Analysis & Security Guarantees

| Threat Vector | Mitigation & Technical Countermeasure | Severity / Impact |
|---|---|:---:|
| **Storage Bucket / S3 Breach** | Backups are stored exclusively as AES-256-GCM ciphertext blobs. Plaintext JSON never exists in cloud storage. | **Mitigated (Zero Exposure)** |
| **Backend Database Compromise** | Server database stores only snapshot metadata (UUID, user ID, byte size, timestamp) and encrypted wrapped DEKs. No plaintext fitness data. | **Mitigated (Zero Exposure)** |
| **Man-in-the-Middle (MitM) / Tampering** | Encrypted blobs use AES-256-GCM authenticated encryption (`INDIFIT_GCM_v2:`) with a 16-byte authentication tag and TLS 1.3 in transit. Any byte modification causes decryption to abort. | **Mitigated (Tamper-Proof)** |
| **Corrupted or Truncated Payload** | Restore requires successful GCM authentication, JSON parsing, schema validation, and SQLite `PRAGMA foreign_key_check` in a staging database before atomic database swap. | **Mitigated (Fail-Closed Rollback)** |
| **Token Theft / Session Hijacking** | Short-lived OIDC tokens with token binding and revocation checks. Refresh tokens stored in Android Keystore / iOS Keychain. | **Mitigated** |
| **Malicious Server Injecting Newer Schema** | Client checks `schemaVersion` and `backupFormatVersion`. Unknown future versions fail closed before SQLite ingestion. | **Mitigated** |

---

## 3. Snapshot Lifecycle & Retention Policy

### Retention Architecture (The 5+3 Rule)

To prevent unbounded cloud storage costs while ensuring historical recoverability, each user account maintains a maximum of **8 snapshots**:

1. **Rolling 5 Daily Snapshots:** Captured daily after active workout completion or during quiet hours.
2. **3 Weekly Milestone Snapshots:** The first snapshot of each week (Sunday midnight UTC) is tagged as a weekly milestone and retained for 3 rolling weeks.

$$\text{Total Cloud Storage per User} \le 8 \times 5\text{MB} \approx 40\text{MB max (typical } < 15\text{MB)}$$

At representative object-storage pricing this is fractions of a cent per user per month; cost scales with retained bytes only (no per-request charges of note at one upload/day). No regional pinning is promised in V1: buckets live in the provider's default region and this is disclosed in the privacy policy. A region-pinning/DPA review is required before any EU-specific rollout.

### Automatic Pruning Algorithm
When a new daily snapshot is successfully uploaded:
1. Fetch current user snapshot list.
2. If total snapshots > 8, identify non-milestone daily snapshots older than 5 days.
3. Delete the oldest daily snapshot from S3/R2 and remove its metadata.
4. Weekly milestones are retained until superseded by a 4th weekly milestone.

---

## 4. Network Transfer Policy

- **Default:** Any active network connection (both cellular and Wi-Fi allowed, as compressed V10 backup blobs are small, typically 1–3 MB).
- **User Preference:** Preference key `cloud_backup_wifi_only` (`bool`, default: `false`) in Settings allowing users on metered cellular data to restrict uploads to Wi-Fi. The policy is enforced both at enqueue time and at outbox-dispatch time (sign-out or transport change after enqueue never uploads; the op stays queued).
- **Outbox Integration:** Backup uploads are queued in `OutboxRepository` with exponential backoff and retry, ensuring reliable background upload across app restarts.
- **Background constraints:** Uploads run as opportunistic foreground/outbox work only. No BGTask/WorkManager guarantee is claimed in V1: iOS may defer work to `BGProcessingTask` windows and Android to Doze maintenance windows. "Quiet hours" are not enforced; uploads are small and infrequent by construction (content-fingerprint dedup + offline coalescing).

---

## 5. Transactional Restore Protocol & Rollback UX

Restoring from cloud backup follows a strict **6-step atomic protocol**:

```text
Step 1: Download ciphertext blob to sandboxed temporary file
           ↓ (fail: network error -> abort, no local change)
Step 2: Authenticate user OIDC session & unwrap DEK via KMS
           ↓ (fail: auth error -> abort, no local change)
Step 3: Decrypt AES-256-GCM payload and verify authentication tag
           ↓ (fail: wrong key / corrupted data -> abort, no local change)
Step 4: Parse V10 JSON, verify schema compatibility (versions 5–10 supported)
           ↓ (fail: invalid schema -> abort, no local change)
Step 5: Load into staging database and run PRAGMA integrity_check + foreign_key_check
           ↓ (fail: relationship error -> abort, staging wiped, active DB untouched)
Step 6: Atomically swap staging DB into active app SQLite database and sync preferences
           ↓
[Restore Succeeded]
```

**Invariant:** If any check in Steps 1–5 fails, the active database and preferences are completely untouched. Existing user data is never destroyed by a failed restore.

---

## 6. Privacy, Erasure & GDPR Compliance

- **User Action: "Delete All Cloud Backups"**:
  - Immediately invokes `DELETE /v1/backup/snapshots`.
  - Permanently purges all snapshot blobs from S3/R2 storage.
  - Revokes and purges user wrapped keys in KMS/HSM.
  - Resets cloud status to `neverConfigured`.
- **Account Deletion**:
  - Purges user auth record, device registry, and all backup snapshots within 24 hours.

---

## 7. Backend API Contract (FastAPI + S3/R2)

### Endpoints

#### `POST /v1/backup/snapshots`
- **Request Body:**
  ```json
  {
    "snapshotId": "uuid-v4",
    "encryptedBlobBase64": "...",
    "wrappedKeyBase64": "...",
    "sha256Checksum": "...",
    "byteSize": 1542380,
    "schemaVersion": 20,
    "backupFormatVersion": 10,
    "deviceName": "iPhone 15 Pro",
    "isWeeklyMilestone": false
  }
  ```
- **Response:** `201 Created` with snapshot summary on first upload.
- **Idempotent retry:** Re-uploading the same `snapshotId` with identical content returns `200 OK` with the existing summary (no duplicate row). Same `snapshotId` with different content returns `409 Conflict`.
- **Validation:** `400` for malformed ids/versions/base64/checksum mismatch/byteSize mismatch; `401` without `Authorization: Bearer` or valid `x-indifit-key`; `413` over 5 MB.

#### `GET /v1/backup/snapshots`
- **Response:** `200 OK`
  ```json
  {
    "snapshots": [
      {
        "snapshotId": "uuid-v4",
        "createdAtUtc": "2026-09-03T04:00:00Z",
        "byteSize": 1542380,
        "schemaVersion": 20,
        "backupFormatVersion": 10,
        "deviceName": "iPhone 15 Pro",
        "isWeeklyMilestone": false
      }
    ],
    "totalCount": 1,
    "totalStorageBytes": 1542380
  }
  ```

#### `GET /v1/backup/snapshots/{snapshotId}`
- **Response:** `200 OK` (binary stream of encrypted blob + wrapped key header).

#### `DELETE /v1/backup/snapshots/{snapshotId}`
- **Response:** `204 No Content`.

#### `DELETE /v1/backup/snapshots`
- **Response:** `204 No Content` (purges all user snapshots).

## 8. Sync wrapping-secret custody (sync track)

Sync per-mutation envelopes follow the same per-user KMS binding decision pending at the account gate (§1 invariant 3): until that gate lands, sync wrapping secrets are explicitly configured per deployment/test and never defaulted or shared.
