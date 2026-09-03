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
3. **Identity-Bound Envelope Encryption:** Data is encrypted on-device via AES-256-GCM with a single-use Data Encryption Key (DEK). The DEK is wrapped by a hardware KMS/HSM keyed to the verified Apple/Google subject identifier (`sub`).
4. **Zero Plaintext Storage:** S3/R2 storage holds only encrypted ciphertext blobs. Even in a complete storage bucket breach, user fitness records, body weights, and food logs remain encrypted.
5. **Manual Backup Coexistence:** Manual local export/restore (`.indifit-backup`) and device-local auto-backups (`indifit_auto_backup_1.json`) remain 100% operational.

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

### Automatic Pruning Algorithm
When a new daily snapshot is successfully uploaded:
1. Fetch current user snapshot list.
2. If total snapshots > 8, identify non-milestone daily snapshots older than 5 days.
3. Delete the oldest daily snapshot from S3/R2 and remove its metadata.
4. Weekly milestones are retained until superseded by a 4th weekly milestone.

---

## 4. Network Transfer Policy

- **Default:** Any active network connection (both cellular and Wi-Fi allowed, as compressed V10 backup blobs are small, typically 1–3 MB).
- **User Preference:** Preference key `cloud_backup_wifi_only` (`bool`, default: `false`) in Settings allowing users on metered cellular data to restrict uploads to Wi-Fi.
- **Outbox Integration:** Backup uploads are queued in `OutboxRepository` with exponential backoff and retry, ensuring reliable background upload across app restarts.

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
- **Response:** `201 Created` with snapshot summary.

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
