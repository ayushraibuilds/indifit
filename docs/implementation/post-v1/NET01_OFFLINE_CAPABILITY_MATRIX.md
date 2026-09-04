# PV1-NET-01A: Offline-Core Matrix and Connected Capability / Outbox Contracts

- **Status:** Complete (Contracts Frozen)
- **Date:** 2026-09-03
- **Branch:** `codex/post-v1-net-01-capability-boundary`
- **Parent Program:** [`../POST_V1_CLEANUP_PROGRAM.md`](../POST_V1_CLEANUP_PROGRAM.md)
- **Implementation Plan:** [`../POST_V1_IMPLEMENTATION_PLAN.md`](../POST_V1_IMPLEMENTATION_PLAN.md)

---

## 1. Architectural Position: The Three-Layer Product Boundary

IndiFit operates strictly on a **local-first, personal-truth foundation**:

```text
Connected services
AI · sync · cloud backup · remote catalogues · media downloads · platform integrations
                           ↓ validated suggestions / imports / events
IndiFit canonical domain
plans · workouts · food · targets · Progress · coaching · history
                           ↓ durable local read/write authority
Local-first storage
Drift SQLite · preferences · cached media · downloads · durable outbox
```

### Inviolable Invariants

1. **Local-First Writes:** User actions (logging workout sets, logging food, recording weight, adjusting targets, editing plans) commit to the local SQLite authority **FIRST**.
2. **Zero Server Spinners:** Core tracking journeys never display a network loading spinner or block the user interface waiting for remote acknowledgment.
3. **Account Independence:** The offline core has **zero required dependency** on accounts, network connectivity, cloud subscriptions, or remote analytics.
4. **Connected Once, Useful Offline Afterwards:** Any acquired food, plan, or media asset is cached locally and functions without subsequent connectivity.
5. **Fail-Closed AI / Recommendations:** AI and cloud suggestions are accelerators, never canonical authorities. They fail closed without altering local records or targets.

---

## 2. The 10 Capability Contracts

All connected features communicate across typed abstract boundaries defined in [`lib/core/capabilities/`](../../../lib/core/capabilities/):

| Capability | Interface | Offline / Default Driver | Invariant Guarantee |
|---|---|---|---|
| **Account** | `AccountCapability` | `NoOpAccountCapability` | Guest mode default. Sign-out never erases local personal truth. |
| **Network** | `NetworkCapability` | `OfflineNetworkCapability` | Local writes never query network state; network gates background tasks only. |
| **Cloud Backup** | `CloudBackupCapability` | `DisabledCloudBackupCapability` | Uploads immutable snapshots. Manual export/restore remains fully independent. |
| **Sync** | `SyncCapability` | `DisabledSyncCapability` | Local writes commit to Drift first. Bidirectional sync reconciles in background. |
| **Food Catalog** | `FoodCatalogCapability` | `DisabledFoodCatalogCapability` | Remote search results are visually distinct until saved/logged locally. |
| **Content Download**| `ContentDownloadCapability`| `DisabledContentDownloadCapability` | Missing/failed downloads never remove bundled SVGs, stills, or text. |
| **AI Assistance** | `AiAssistanceCapability` | `DisabledAiAssistanceCapability` | Never originates canonical targets, history, or PRs. Fails closed. |
| **Integrations** | `IntegrationCapability` | `DisabledIntegrationCapability` | External health sync failures never block local workout completion. |
| **Diagnostics** | `DiagnosticsCapability` | `NoOpDiagnosticsCapability` | Workout weights, reps, food logs, and personal metrics are strictly redacted. |
| **Entitlements** | `EntitlementCapability` | `FullLocalEntitlementCapability` | Core fitness tracking is never locked by expired offline subscription tokens. |

---

## 3. Standardized Status Language and Tokens

User-facing connection, sync, and backup status tokens are standardized in [`connected_status.dart`](../../../lib/core/capabilities/connected_status.dart):

| Token (`ConnectedStatus`) | Semantic Meaning | Consumer Display Copy | Local Work Allowed? |
|---|---|---|:---:|
| `neverConfigured` | Feature not turned on | "Not configured" | **Yes** |
| `pending` | Operations queued in outbox | "N updates waiting to sync" | **Yes** |
| `inFlight` | Network operation active | "Syncing updates…" | **Yes** |
| `synced` | Confirmed up to date | "Up to date" | **Yes** |
| `offline` | Device is disconnected | "Offline — updates will sync when connected" | **Yes** |
| `authenticationRequired` | Session expired / login needed | "Sign in required" | **Yes** |
| `providerUnavailable` | Cloud service temporary 503 | "Service temporarily unavailable" | **Yes** |
| `permanentError` | Fatal error requiring resolution | "Sync issue — action needed" | **Yes** |

*Rule:* Status language never exposes internal database terminology, Drift class names, SQLite error codes, or UUIDs.

---

## 4. Durable Outbox and Background-Job Primitives

Defined in [`lib/core/outbox/`](../../../lib/core/outbox/):

### Outbox State Machine

```text
[Created] ──► [pending] ──► [inFlight] ──► [succeeded] (Terminal)
                 ▲              │
                 │              ├──► [transientFailure] (Exponential Backoff + Jitter)
                 │              │          │
                 └──────────────┴──────────┘ (if attempts < maxAttempts)
                                │
                                └──► [permanentFailure] (Terminal, if non-retryable or attempts exhausted)
```

### Properties & Guarantees
- **Idempotency Key:** Every outbox operation requires an `idempotencyKey` (e.g. `workout:<uuid>:create`). Deduplication occurs at enqueue time, preventing duplicate queueing across crashes.
- **Exponential Backoff:** Configured in `OutboxRetryPolicy`:
  $$\text{Delay} = \min\left(\text{initialDelay} \times (\text{multiplier})^{\text{attempt} - 1}, \text{maxDelay}\right) \pm \text{jitter}$$
  Defaults: `initialDelay: 2s`, `maxDelay: 24h`, `multiplier: 2.0`, `jitter: 10%`, `maxAttempts: 5`.
- **Transient vs. Permanent Discrimination:**
  - *Transient (retryable):* `SocketException`, `TimeoutException`, HTTP 502/503/504, HTTP 429.
  - *Permanent (fail-closed):* Malformed payloads, HTTP 400, revoked credentials.

---

## 5. Offline Acceptance Matrix

Automated verification in [`test/pv1_net01_offline_capability_test.dart`](../../../test/pv1_net01_offline_capability_test.dart) certifies:

1. **Dependency Isolation:** Core repositories (`FoodRepository`, `ProgramRepository`, `AppDatabase`) do not require or instantiate connected capabilities.
2. **Offline CRUD Resilience:** Local meal logging and workout execution succeed under total network outage and 503 errors.
3. **Outbox State Progression:** Correct state transitions (`pending` → `inFlight` → `transientFailure` → `succeeded`), backoff calculation, and permanent error trapping.
4. **Idempotency Deduplication:** Redundant operations with matching keys are safely ignored.
5. **Consumer Language Hygiene:** All status tokens produce factual, jargon-free copy.
