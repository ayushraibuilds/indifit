# PV1-SYNC-01A — Multi-Device Synchronization Architecture & Protocol Specification

## 1. Executive Summary & Core Invariant

This specification establishes the architectural, cryptographic, and algorithmic foundation for optional multi-device synchronization in IndiFit.

### Core Invariant: Local-First Autonomy
> **Local persistence never blocks on or waits for network connectivity.**
> Every write (logging a set, recording food, updating body weight, editing preferences) executes and commits immediately to the local Drift/SQLite database. Multi-device synchronization runs purely in the background through the durable outbox and capability layer. If the device is offline, in airplane mode, or the sync relay is unreachable, the user experiences zero lag and 100% app functionality.

---

## 2. Entity Inventory & Boundary Classification

IndiFit data is partitioned into strictly synchronized domains versus strictly device-local/cached domains:

### 2.1 Synchronized Domains

| Domain | Entities / SQLite Tables | Sync Semantics | Identity Model |
| :--- | :--- | :--- | :--- |
| **Workouts** | `workout_sessions`, `workout_sets`, custom `exercises` | Append-only evidence with tombstone deletions | Global UUID (`sync_id`) |
| **Nutrition Logs** | `food_logs` | Mutable daily logs (LWW by HLC) | Global UUID (`sync_id`) |
| **Nutrition Recipes**| custom `foods`, `recipes`, `recipe_ingredients` | Mutable templates (LWW by HLC) | Global UUID (`sync_id`) |
| **Body Weight** | `body_weights` | Append-only evidence with tombstone deletions | Global UUID (`sync_id`) |
| **Programs** | `routine_plans`, `routine_days`, `routine_exercises` | Mutable active plan & templates (LWW by HLC) | Global UUID (`sync_id`) |
| **Preferences** | `user_profile`, daily goals (water, calories, macros) | Key-value mutable state (LWW by HLC) | Preference Key |

### 2.2 Strictly Excluded (Device-Local / Cache Only)

1. **Local Outbox & Sync Logs:** `outbox_operations`, mutation queues, sync run histories. Each device manages its own durable transmission spool.
2. **Device-Local Notifications:** Alarm clock schedules, quiet hours, local notification IDs. Each device retains independent notification delivery.
3. **Hardware & Biometric Secrets:** Secure storage items, biometric tokens, local database encryption keys.
4. **Remote Catalog & Barcode Caches:** Downloaded food items from external provider APIs (cached with TTL, not synced).
5. **App Lifecycle & View State:** Navigation history, scroll positions, draft text fields, onboarding progress flags.

---

## 3. Clock Ordering: Hybrid Logical Clocks (HLC)

Standard physical wall-clocks (`DateTime.now()`) are unreliable across distributed consumer devices due to clock drift, manual user timezone adjustments, and leap seconds. Pure logical clocks (Lamport) lose physical causality and cannot determine whether a workout occurred in the morning or evening.

IndiFit utilizes **Hybrid Logical Clocks (HLC)** combining physical milliseconds with a monotonic sequence counter and deterministic device tie-breaking:

$$\text{HLC} = \langle l, c, d \rangle$$

- $l$: Physical millisecond timestamp ($\ge \text{wall clock}$, monotonically non-decreasing).
- $c$: Logical counter for operations occurring within the same physical millisecond.
- $d$: Globally unique originating device ID (RFC 4122 UUID).

### 3.1 Total Ordering Relation
For two timestamps $T_1 = \langle l_1, c_1, d_1 \rangle$ and $T_2 = \langle l_2, c_2, d_2 \rangle$:

$$T_1 < T_2 \iff (l_1 < l_2) \lor (l_1 = l_2 \land c_1 < c_2) \lor (l_1 = l_2 \land c_1 = c_2 \land d_1 < d_2)$$

This guarantees **strict total ordering** across all devices without centralized coordination.

### 3.2 Monotonic Clock Progression
When local event occurs at physical time $pt$:
1. If $pt > l$: $l \leftarrow pt, c \leftarrow 0$
2. If $pt \le l$: $c \leftarrow c + 1$

When remote timestamp $\langle l_{remote}, c_{remote}, d_{remote} \rangle$ is received:
1. $l' \leftarrow \max(l, pt, l_{remote})$
2. If $l' = l = l_{remote}$: $c \leftarrow \max(c, c_{remote}) + 1$
3. Else if $l' = l$: $c \leftarrow c + 1$
4. Else if $l' = l_{remote}$: $c \leftarrow c_{remote} + 1$
5. Else: $c \leftarrow 0$
6. $l \leftarrow l'$

---

## 4. Conflict Resolution & Convergence Policies

Different data types require distinct conflict resolution semantics:

### 4.1 Append-Only Historical Evidence (Workouts & Weights)
- **Rule:** Union/append. When Device A records a workout set at 10:00:00 and Device B records a set at 10:00:01, both sets are valid distinct records. They never overwrite each other.
- **Deletions:** Explicit user deletion generates a `SyncTombstone` with the current HLC.

### 4.2 Mutable State (Food Logs, Recipes, Preferences)
- **Rule:** Last-Write-Wins (LWW) strictly ordered by HLC.
- If Mutation $M_A$ has $HLC_A$ and Mutation $M_B$ has $HLC_B$, the mutation with the higher HLC prevails:
  $$\text{winner} = \max_{HLC}(M_A, M_B)$$
- Because HLC includes node ID tie-breaking, every device evaluates the identical winner regardless of arrival order ($A \to B \equiv B \to A$).

### 4.3 Tombstone Dominance (Anti-Resurrection)
- A major distributed synchronization hazard is the resurrection of deleted entities when an older delayed write arrives after a deletion.
- **Invariant:** A tombstone with timestamp $T_d$ supersedes and extinguishes any write with timestamp $T_w \le T_d$.
- If $T_w > T_d$, the entity was explicitly recreated or modified after deletion and the new write is accepted.
- **Retention:** Tombstones are retained for a minimum of 30 days, allowing offline devices to catch up before tombstones are purged during compaction.
- **Current status:** Tombstone dominance is implemented in `SyncConflictResolver` and exercised by contract tests, but tombstones are not yet persisted (relay-memory + hard deletes only). A `sync_tombstones` table with the 30-day compactor is required before any multi-device claim (schema track).

### 4.4 LWW Tie Rule (Commutativity)
- HLC comparison already tie-breaks on node id, so `comparison == 0` means an identical HLC (same millis+counter+node — should be impossible with a correct clock). In that case the winner is the payload-max (order-independent string comparison), so `reconcile(A,B) ≡ reconcile(B,A)` in all cases. Implemented in `SyncConflictResolver`.

---

## 4B. Identity, Schema & Lifecycle Decisions (added post-01B audit)

### Identity mechanics
- **Entity identity is the opaque `entityId` string** (UUID v4 for all new records). Local autoincrement integer ids are never derived from or overwritten by remote ids (that caused cross-device collisions).
- **Operation identity:** outbox `operationId` (`sync_<entityId>_<hlc>`) is unique per enqueue and never overwritten; the idempotency key (`idem_<entityId>_<hlc>`) dedups only while an op is active (pending/in-flight/transient), never after terminal states.
- **Dedup key everywhere** (client relay, server relay): `(domain, entity_id, hlc)` — domain is included so the same numeric id in two domains cannot collide.
- **Device identity:** HLC `nodeId` = `AccountCapability.deviceId` (per-install). Guest devices must not share one static id.

### Per-domain CRUD & ordering
| Domain | Insert | Update | Delete | Ordering |
|---|---|---|---|---|
| workouts / weights | append (union, never overwrite distinct rows) | LWW by HLC on same `entityId` | tombstone, dominant per §4.3 | HLC total order |
| nutritionLogs / nutritionRecipes / programs / preferences | LWW by HLC | LWW by HLC | tombstone, dominant per §4.3 | HLC total order |
- **Immutable vs mutable:** workout/weight *rows* are append-only evidence; corrections arrive as new writes or tombstone+recreate, never in-place history rewrites. Mutable domains converge by LWW.
- **Deferred writers:** `nutritionRecipes`, `programs`, `preferences` have no canonical applicator yet — the cursor still advances past them so sync converges, and they must never be fabricated. Writers land with their domain packages.

### Schema-version compatibility
- Mutations carry no schema version today. Until a versioned envelope lands, a receiver applies only domains/fields it understands and ignores unknown fields; unknown domains are skipped (cursor advances). A skew policy (reject vs apply-subset) must be specified before the first production relay.

### Bootstrap, pagination, compaction
- **Bootstrap:** first sync pulls from the zero HLC; no snapshot protocol yet (acceptable at current scale; specify one before >10k-mutation streams).
- **Pagination:** pull pages `limit` (1–500, default 100) following `has_more`; the client loops until exhausted and only then advances the persisted cursor.
- **Compaction:** no compactor exists yet. Required: tombstone purge after 30 days + per-user stream caps, as a separate job with its own tests.

### Auth expiry, revocation, deletion, quotas
- Push/pull require `Authorization: Bearer` (or valid `x-indifit-key` for service use); anything else is `401` — there is no guest bucket.
- Sign-out keeps all local data and leaves queued ops queued (retry on next sign-in); nothing is failed permanently by an auth transition.
- Account deletion, export, retention windows, per-user quotas, and device revocation lists are unspecified — required before production (SYNC-01A follow-up).

### Encryption decision (status correction)
- §5.1 describes an AES-256-GCM envelope per mutation. **Status: not implemented** — 01B transmits plaintext `payload` maps. The "blind relay" privacy claim does not hold until per-mutation envelopes (or a documented service-side-encryption decision with its search/conflict implications) land. Do not quote §5.1 as built.

### Wire-format note (implementation truth)
- Canonical HLC string on the wire is the implementation's hex-padded form (`millis_hex(12)_counter_hex(4)_nodeId`, e.g. `0193..._0001_device-A`), **not** the decimal example in §5.2. The decimal example is stale documentation; parsers must accept the hex form. A future revision may adopt a single canonical encoding — until then, code (round-trip tested) wins over the example.

---

## 5. Server Delta Protocol & Privacy

### 5.1 Blind Relay Architecture
The sync backend acts as an authenticated, blind change-feed relay. It does not inspect or query plaintext user records:
- Each mutation payload is encrypted using the client-side AES-256-GCM envelope established in PV1-CLOUD-01.
- The server indexes metadata only: `(user_id, domain, hlc, entity_id, operation)`.

> Status note (2026-09-05, Stream B relay acceptance): per-mutation `encrypted_envelope`s are now implemented on the client (AES-256-GCM, SYNC AAD domain, HKDF-wrapped DEK) behind an explicitly configured wrapping secret with a plaintext dev fallback; the relay remains blind by construction (stores opaque dicts, indexes metadata only, never decrypts). Wire format: each mutation carries an optional `encrypted_envelope` dict (`mutation_id`, `ciphertext_base64`, `wrapped_key_base64`, `sha256_checksum`); pushes validate structure/base64 plus a 256 KB decoded-ciphertext cap (400 malformed / 413 oversize) and pulls return stored dicts byte-identical. Still pending before any production claim: account deletion, device revocation, per-user quotas/retention, and snapshot/compaction policy (see §4B).

### 5.2 Delta Synchronization Endpoints

#### Pull Changes:
```http
GET /v1/sync/deltas?since_hlc=<hlc_string>&limit=100
Authorization: Bearer <oidc_jwt>
```
Response:
```json
{
  "mutations": [
    {
      "entity_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
      "domain": "workouts",
      "operation": "insert",
      "hlc": "1725350000000_0001_iPhone-15-Pro",
      "payload_base64": "<ciphertext>",
      "wrapped_key_base64": "<wrapped_dek>",
      "iv_base64": "<iv>",
      "auth_tag_base64": "<tag>"
    }
  ],
  "has_more": false,
  "latest_hlc": "1725350000000_0001_iPhone-15-Pro"
}
```

#### Push Changes:
```http
POST /v1/sync/mutations
Authorization: Bearer <oidc_jwt>
```
Payload:
```json
{
  "mutations": [ ... ]
}
```
Response:
```json
{
  "accepted_count": 1,
  "server_received_hlc": "1725350000000_0001_iPhone-15-Pro"
}
```

---

## 6. Edge Case Handling & Fault Tolerance

1. **Clock Skew Attack / Excessive Time Drift:**
   - If a client attempts to commit a mutation with a physical timestamp more than 1 hour into the future ($l > \text{server\_now} + 3600\,\text{s}$), the server rejects it with `400 Bad Request: Clock skew exceeded`.
2. **Idempotent Retries:**
   - The server deduplicates mutations based on `(user_id, entity_id, hlc)`. Resending an unacknowledged outbox operation is completely safe and produces zero duplicates.
3. **Device Revocation / Sign Out:**
   - Signing out on a device does NOT delete local records unless the user explicitly selects "Wipe data on this device".
   - The device simply ceases polling or pushing sync mutations.
