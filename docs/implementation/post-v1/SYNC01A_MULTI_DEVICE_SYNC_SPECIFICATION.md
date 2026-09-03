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

---

## 5. Server Delta Protocol & Privacy

### 5.1 Blind Relay Architecture
The sync backend acts as an authenticated, blind change-feed relay. It does not inspect or query plaintext user records:
- Each mutation payload is encrypted using the client-side AES-256-GCM envelope established in PV1-CLOUD-01.
- The server indexes metadata only: `(user_id, domain, hlc, entity_id, operation)`.

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
