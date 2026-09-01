# IndiFit Post-V1 Prioritized Implementation Plan

- Status: Active; Gate 0 and PV1-ENG-01 complete, PV1-ENG-02 next
- Effective date: 2026-08-30
- Product roadmap: [`post-v1-roadmap.md`](../roadmap/post-v1-roadmap.md)
- Cleanup execution program: [`POST_V1_CLEANUP_PROGRAM.md`](POST_V1_CLEANUP_PROGRAM.md)
- Decision baseline: frozen R08 product decisions and completed R08 packages

## 1. Objective

This plan converts the post-V1 roadmap into an ordered, gated delivery program.
It prioritizes production trust and change safety, then improves existing
consumer loops and data continuity, and only then introduces new domains or
external/AI behavior.

It does not authorize post-V1 implementation before the V1 manual real-device
acceptance and release sign-off are complete.

## 2. Priority model

Work is ranked by five factors:

1. **Trust impact:** data integrity, privacy, safety, truthful presentation, and
   production reliability.
2. **Unblocking value:** how many later initiatives become safer or possible.
3. **Consumer value:** improvement to an existing high-frequency journey.
4. **Authority readiness:** whether the canonical data/read/write boundary
   already exists.
5. **Delivery risk:** migration, backup, platform, licensing, AI, and behavioral
   uncertainty.

Priority classes:

- **P0:** release or production-trust gate; interrupt lower priorities.
- **P1:** next planned work; high leverage or high consumer value with a sound
  authority.
- **P2:** valuable follow-on after P1 exit criteria pass.
- **P3:** option requiring discovery, a new domain, or a separate product
  decision.
- **REJECTED:** not eligible without a new product decision and architecture.

## 3. Non-negotiable execution rules

- Do not mix V1.0.x reliability patches with roadmap features.
- Make structural extraction behavior-preserving: same pixels, semantics,
  keys, callbacks, navigation, persistence, and error behavior.
- Give shared hotspots one owner at a time: database/migrations, backup codecs,
  app bootstrap/provider registry, router, workout execution, nutrition target
  authority, and Progress aggregation.
- Separate schema or backup changes from broad UI refactors.
- Keep historical backup decoders immutable unless a dedicated compatibility
  task proves all supported formats.
- Add characterization coverage before deleting or splitting ambiguous code.
- Profile before performance work and record the before/after evidence.
- Treat manual device, visual, accessibility, licensing, and product approval
  as human gates; automated success does not claim those gates passed.
- Keep core fitness actions account-optional and connectivity-independent.
- Commit core writes to the local canonical authority before enqueueing any
  upload; never put a server spinner in the set/meal/weight/plan commit path.
- Treat offline operation as an expected state. Report connected capability and
  last-success/pending/error state without presenting normal offline use as a
  product failure.
- Validate, normalize, attribute, and—where personal truth changes—review
  connected results before canonical persistence.
- Make downloaded/imported/confirmed content useful offline after acquisition.
- Prevent remote config, subscription entitlement, analytics, or provider
  outage from disabling or redefining the offline core.
- Never introduce synthetic e1RM, inferred PR authority, homemade calorie burn,
  numeric readiness, or unsupported strength standards.

## 4. Connected systems contract

### Core state transition

```text
user action
  → validate against local canonical rules
  → commit local transaction
  → update local UI/read models
  → enqueue durable connected work when applicable
  → retry when policy and connectivity allow
  → reconcile idempotently
```

The network may be required for an explicitly connected acquisition action,
such as finding a new remote food or streaming a video. It is never required
to use already-local plans, records, content, targets, or history.

### Shared connected primitives

Specify these once before feature teams create independent versions:

- optional account/session and device identity;
- secure token/key storage, revocation, recovery, and account deletion;
- typed network client policy, redaction, retry/backoff, rate-limit handling,
  and server/content compatibility;
- durable outbox/background jobs with stable operation IDs and bounded retry;
- sync/backup status and user-controlled mobile-data/Wi-Fi policy;
- cache/download manifest, integrity, freshness, eviction, and storage budget;
- provider/content provenance and correction history;
- privacy-minimized crash/performance diagnostics and product-event consent.

Immutable encrypted backup and bidirectional sync are separate protocols.
Backup proves snapshot upload, retention, and restore. Sync additionally needs
per-domain identity, ordering, deletion, conflict, and convergence semantics.

### Required offline acceptance matrix

At minimum, run the app with no network at cold launch, during an active
workout, while logging/editing food and weight, during plan/calendar use, while
viewing Progress/history, and after a connected action has been queued. Also
test loss/recovery of connectivity mid-request, expired credentials, provider
outage, malformed responses, repeated callbacks, process death, and clock/date
changes. The local record must remain correct in every case.

## 5. Ordered delivery program

### Gate 0 — V1 release and observation window

- **Priority:** P0
- **Outcome:** the frozen V1 release is signed off and post-release issues have a
  single triage path.

Work:

- Complete the R08 manual real-device acceptance matrix and traceability.
- Record release build identifiers and the accepted automated baseline.
- Establish a V1.0.x lane limited to crash, correctness, data-loss, privacy,
  accessibility, and platform-reliability fixes.
- Capture production issues with reproduction evidence and affected data
  authority; do not opportunistically bundle feature work.

Exit criteria:

- Human release sign-off is recorded.
- The accepted test/build baseline is reproducible.
- Any open P0 defect has an owner or explicitly blocks post-V1 work.

### Wave 1 — Deterministic engineering foundation

- **Priority:** P0/P1
- **Target horizon:** V1.1 engineering
- **Dependency:** Gate 0

#### PV1-ENG-01 — Deterministic Flutter test harness

**Priority:** P0; first post-release engineering project

**Status:** Complete on 2026-09-01. C0A exit evidence is recorded in the
cleanup program and its baseline report.

Detailed gate and execution order: C0A in
[`POST_V1_CLEANUP_PROGRAM.md`](POST_V1_CLEANUP_PROGRAM.md).

Deliverables:

- One documented test-app/container builder with explicit database,
  preferences, clock/date/timezone, and platform-service overrides.
- Per-test isolated `SharedPreferences` state and database lifecycle.
- Standard fakes for notifications, health, secure/platform storage, sharing,
  file picking, connectivity/network adapters, and lifecycle callbacks used by
  tests.
- Elimination or owned suppression of multiple-`AppDatabase` warnings.
- Order-sensitive test audit with reproducible shuffle/repeat evidence.
- A reliable serial CI lane plus smaller focused lanes where isolation is
  proven.

Acceptance:

- The full serial suite passes repeatedly from a clean process.
- Selected historically fragile groups pass under reordered execution.
- No test depends on another test's preferences, database, clock, or platform
  state.
- A harness usage guide and migration examples exist for future tests.

#### PV1-ENG-02 — Fragile-flow characterization

**Priority:** P1; may run in parallel only after ENG-01 contracts are frozen

Detailed contract inventory and weak-flow scope: C0B in
[`POST_V1_CLEANUP_PROGRAM.md`](POST_V1_CLEANUP_PROGRAM.md).

Cover at minimum:

- app bootstrap, onboarding gate, date rollover, and lifecycle resume;
- active workout draft/resume/finalize/idempotency and rest timer;
- nutrition target history, food fast logging, edit/delete/undo;
- plan activation/reschedule/complete/history invalidation;
- sparse/populated Progress and Today states;
- backup export/restore failure atomicity and platform-storage boundaries.

Acceptance: each selected flow has observable-behavior tests suitable for
protecting mechanical extraction; tests assert product outcomes rather than
private widget structure where possible.

**Wave 1 gate:** repeated deterministic suites pass, characterization gaps are
recorded, and no known harness pollution remains mislabeled as a product bug.

### Wave 2 — Retired-code cleanup and mechanical decomposition

- **Priority:** P1
- **Target horizon:** V1.1 engineering
- **Dependency:** Wave 1 gate

#### PV1-ENG-03 — Reachability and ownership inventory

Classify each candidate as:

- production-reachable;
- intentionally dormant/feature-gated;
- compatibility required;
- test fixture;
- developer tooling;
- evidence-confirmed retired.

Begin with legacy AI surfaces, old dashboard widgets, reports, routine code,
historical fixtures, MealTemplates-era UI, and the legacy workout/player path.
Reachability from `main.dart` alone is not deletion evidence; inspect routes,
deep links, notification callbacks, restore compatibility, tests, and dynamic
registries.

Output: a checked-in inventory with evidence, owner, action, and compatibility
reason. No bulk deletion belongs in the inventory task.

#### PV1-ENG-04 — Bounded retired-code removals and relocations

Use one small change set per coherent area. Delete confirmed retired product
code, move fixtures to `test/`, move tooling to `tool/`, and retain documented
compatibility adapters. Remove or update tests that exist only to preserve
retired behavior; do not convert old UI into a new feature implicitly.

Acceptance: focused and full suites pass; route/callback searches prove no live
entry point; deleted behavior and recovery implications are recorded.

#### PV1-ENG-05 — Mechanical God-file splits

Suggested order after characterization strength is confirmed:

1. Progress.
2. Today action surface.
3. Workout player/execution presentation.
4. Food Search.
5. Program authoring.

First pass extracts widgets, immutable view data, formatters, and local
presentation helpers only. Controller/orchestration redesign is a separate
task after the split settles.

Acceptance per file:

- no intentional behavior, layout, semantics, keys, copy, callback, or route
  changes;
- affected goldens/semantics/widget tests pass;
- dependency direction and new ownership are documented;
- `flutter analyze`, focused tests, full serial tests, and `git diff --check`
  pass.

**Wave 2 gate:** the inventory is complete for targeted areas, removals are
evidence-backed, and the selected large files have smaller coherent ownership
without observable product change.

### Connected Track C0–C6 — local-first services

- **Priority:** P1–P3 within the connected portfolio
- **Earliest start:** C0 may begin after the Wave 1 harness contracts are frozen
- **Parallelism:** may overlap unrelated Wave 2/3 UI work; one owner controls
  backup, schema, identity, outbox, and sync hotspots

This track has its own order. Automatic backup is the first connected product
package; multi-device sync is second. Later capabilities reuse—not fork—the
account, network, provenance, cache, download, and background-job foundations.

#### PV1-NET-01 — Offline/connected capability boundary

**Priority:** P0 foundation for connected work

Deliverables:

- explicit capability interfaces for account, network, backup, sync, remote
  catalogues, downloads, AI, integrations, analytics, and entitlements;
- a dependency test proving core feature/domain packages do not require those
  implementations to construct or perform local actions;
- durable background-job/outbox contract with stable operation IDs,
  idempotency, retry/backoff, cancellation, retention, and observability;
- shared user-facing status language for never configured, pending, synced,
  offline, authentication required, provider unavailable, and permanent error;
- the no-network acceptance matrix from §4 automated where possible.

Exit: existing core journeys behave identically with all connected adapters
disabled, unavailable, slow, or failing.

#### PV1-CLOUD-01 — Automatic encrypted cloud backup

**Priority:** P1; first connected product release

Split into decision and implementation packages:

1. **CLOUD-01A threat/product contract:** provider/account model, encryption
   scope, key custody/recovery, loss behavior, retention count, Wi-Fi/mobile
   policy, background constraints, privacy/export/deletion, restore UX, costs,
   and regional/legal review.
2. **CLOUD-01B immutable upload:** produce the existing verified export through
   the platform-safe file/secret boundary, encrypt/authenticate, upload with a
   stable snapshot ID, and record local last-success/remote metadata.
3. **CLOUD-01C restore and operations:** list eligible snapshots, verify before
   mutation, restore transactionally, preserve manual local export/restore,
   support back-up-now, schedule/retry, retention pruning, and remote deletion.

Acceptance:

- plaintext fitness data and keys never appear in logs, analytics, or temporary
  files outside the approved protected boundary;
- upload retry cannot create unbounded duplicates or mark a failed snapshot as
  successful;
- corrupt, truncated, wrong-key, newer-version, and partially uploaded backups
  fail before local mutation;
- app use and manual backup remain available during account/provider outage;
- a new-device restore is manually verified on supported platforms.

#### PV1-SYNC-01 — Optional account and multi-device sync

- **Priority:** P1; second connected product program
- **Dependency:** CLOUD-01 security/account lessons and stable canonical IDs

SYNC-01A must specify before coding:

- supported entity inventory and excluded local-only/secret/cache data;
- global record/device/operation identity and server protocol;
- per-domain creation, update, deletion/tombstone, ordering, and conflict rules;
- immutable evidence versus mutable settings/content semantics;
- schema/content version compatibility, migration, bootstrap, pagination, and
  compaction;
- auth expiry, device revocation, account deletion, export, retention, quotas,
  clock skew, duplicates, and partial-batch recovery;
- end-to-end versus service-side encryption decision and its search/conflict
  implications.

Implementation should start with one low-risk vertical slice and a reusable
convergence harness, then expand in deliberate families:

1. account/session, device registration, bootstrap, and sync status;
2. append/immutable workout and weight evidence;
3. food logs, Saved Meals/Recipes, and nutrition target history;
4. plans, settings, achievements, and remaining approved user-owned domains.

Acceptance: core writes remain local and immediate; repeated/out-of-order
delivery converges; deletions do not resurrect; two-device concurrent edits
follow the documented domain rule; offline queues survive process restart; and
logout/device revocation do not delete local data without an explicit choice.

#### PV1-CATALOG-01 — Online food search, barcode, and local reuse

- **Priority:** P1; third/fourth connected product capabilities
- **Dependency:** PV1-NET-01 and canonical food normalization/provenance

Delivery order:

1. provider evaluation and typed normalized remote-food candidate contract;
2. local results first with a separate “more online results” state;
3. review/correction and save-to-local cache before logging;
4. barcode camera/input flow: local cache → remote lookup → review → local
   canonical food;
5. correction/freshness policy for previously cached provider records.

Validate serving basis, units, calories/macros/nutrients, brand/product/barcode
identity, source timestamps, duplicates, incomplete records, provider conflicts,
rate limits, offline states, and camera permission denial. No provider response
silently becomes trusted nutrition.

#### PV1-CONTENT-01 — Signed catalogue and plan updates

**Priority:** P1/P2; enables extensible food/exercise/plan content

Define one signed pack envelope with pack ID/version, source/provenance,
minimum/maximum app compatibility, file hashes, dependencies, size, and atomic
activation/rollback. Domain-specific validators still own exercise identity,
food quantities/nutrients, and plan structure.

Deliver in small families:

- food catalogue deltas and aliases/serving corrections;
- exercise instructions/metadata and approved exact media bindings;
- online plan catalogue with preview/download;
- optional plan-version updates presented as a diff and never auto-applied to
  the active plan.

Reject invalid signatures, unknown canonical changes, incompatible packs,
partial downloads, downgrade/replay where prohibited, and changes that would
rewrite personal history. Retain the last known-good active pack.

#### PV1-MEDIA-03 — Exercise video streaming and offline downloads

- **Priority:** P1/P2; fifth connected product capability
- **Dependency:** media licensing/identity gate and download/content foundation

- Stream reviewed movement/setup/mistake demonstrations from an approved CDN.
- Allow per-video, category-pack, and “media for this plan” downloads with size
  preview, progress, cancellation, integrity, storage budget, and removal.
- Preserve local still/anatomy/instruction fallback at all times.
- Bind every asset to exact canonical exercise IDs and disclose when one
  movement illustration/video does not demonstrate tempo or technique detail.

Acceptance includes interrupted/resumed downloads, offline playback, expired
URLs, corrupt cache, storage pressure, cellular policy, app upgrade, removed
content, captions/semantics, reduced motion, package impact, memory, and
representative device playback.

#### PV1-INTEL-01 — Reviewable connected acquisition and explanation

**Priority:** P2/P3; follows canonical catalogue foundations

Recommended order:

1. nutrition-label OCR with field-level confidence and review;
2. recipe URL import with ingredient/unit resolution;
3. natural-language meal text → canonical food candidates;
4. deterministic “What can I eat?” candidates with optional AI explanation;
5. AI plan draft → canonical exercise IDs → validator → user review → local
   versioned plan;
6. contextual coaching explanation/adaptation, one approved context at a time;
7. generic meal-photo estimation only after the safer paths are validated.

All paths use typed provider responses, consent/transmission disclosure,
timeouts/offline/malformed behavior, correction flows, provenance, evaluation
metrics, and user confirmation before changing canonical personal truth.

#### PV1-CONNECT-01 — Integrations, sharing, and collaboration

**Priority:** P2/P3; follows account/sync maturity where identity is required

Sequence independently bounded packages:

1. direct provider imports (initial provider chosen by evidence and demand),
   normalized/deduplicated into local sourced evidence;
2. local factual workout share image, then optional privacy-scoped web link;
3. coach/trainer data sharing and review-before-apply plan changes;
4. verified trainer plan catalogue/marketplace;
5. friends and sustainable-consistency challenges;
6. optional running/cycling route, map, elevation, and weather enrichment;
7. supported music-provider integration;
8. moderated verified community tips only after governance exists.

Global leaderboards for weight lifted, calories, or streaks are out of scope.
Every share has an audience/revocation/delete model; coach changes are audited
and never silently applied; imported evidence remains visible offline.

#### PV1-OBS-01 — Privacy-minimized operations and entitlement

**Priority:** P1 enabler; not a dependency of the offline core

- Add opt-in crash reporting, performance traces, and minimal product events
  without workout/food/health payloads in ordinary events or breadcrumbs.
- Establish remote-config allowlists for rollout/content only; canonical rules
  remain versioned app/domain logic.
- If monetized, cache signed entitlement state with an explicit grace/failure
  policy. Basic offline workout, food logging, stored history, and core Progress
  remain usable without entitlement or account connectivity.

**Connected track gate:** each shipped connected feature passes the no-network
matrix, preserves immediate local authority, exposes provenance/status/recovery,
and leaves acquired/confirmed/imported results useful offline where promised.

### Wave 3 — Existing-loop product payoff

- **Priority:** P1
- **Target horizon:** V1.1 product
- **Dependency:** Waves 1–2 for touched areas

These packages may be sequenced independently after shared contracts are
frozen. They are not all required for one release.

#### PV1-PROD-01 — Workout completion recap and factual share card

Deliver:

- a clearer completed-session recap;
- actual logged set/load/repetition/duration facts where applicable;
- useful previous-session comparison from exact canonical evidence;
- shareable image/card with privacy-aware preview and user-triggered sharing;
- honest sparse states when comparison data is unavailable.

Must not include e1RM, inferred PRs, calorie estimates, readiness, or generated
performance claims.

Acceptance: exact-session identity tests, partial/complete session states,
unit formatting, large text/light/dark rendering, no-data behavior, and share
payload golden/content tests.

#### PV1-PROD-02 — Approved exercise media completion

Deliver priority/top-exercise stills first through the existing exact UUID
binding and fallback chain. Motion/video is a separate follow-on.

Entry gate: approved licensing/provenance, human movement review, checksums,
attribution, and legal distribution path. Acceptance includes offline fallback,
unknown/custom exercise behavior, package delta, decode/cache/memory evidence,
dense-list scrolling, light/dark, semantics, and reduced motion.

#### PV1-PROD-03 — Small Progress and achievement expansion

Start with a deliberately small set of deterministic milestones and richer
collection/history presentation. Each achievement needs a stable definition,
event identity/idempotency, backup behavior, missing-data semantics, and an
explanation of the evidence used.

Do not implement an inferred PR badge or reward unsafe frequency. Streak freeze
requires its own product rule and is not part of the first expansion.

#### PV1-PROD-04 — Background rest-timer presence

Recommended order: Android ongoing notification, then iOS Live Activity.

Define one rest-session lifecycle across foreground, background, process
recreation, cancellation, expiry, and completed workout cleanup. Validate
permission denial, stale notification/activity cleanup, clock changes, audio,
accessibility, battery impact, and platform version fallbacks on real devices.

**Wave 3 gate:** every shipped metric is factual, media is approved, platform
presence cleans itself up, and manual visual/device acceptance is recorded.

### Wave 4 — Plans, health context, and presentation consolidation

- **Priority:** P2
- **Target horizon:** V1.2
- **Dependency:** stable V1.1 product/read authorities

#### PV1-PLAN-01 — Plan analytics and history

- Plan completion summaries and durable history.
- Phase/week progress and planned-versus-performed adherence.
- Honest handling of skipped, rescheduled, partial, replaced, and unscheduled
  sessions.
- Useful period comparison without synthetic strength scoring.

Entry gate: occurrence/execution identity and history queries are stable and
bounded. Acceptance includes timezone/date-boundary and incomplete-data cases.

#### PV1-PLAN-02 — Consumer plan customization

- Per-day and per-exercise changes with explicit effect on future occurrences.
- Clear distinction between editing the active plan, a future occurrence, and
  historical frozen execution.
- Equipment-profile UX integrated where it helps selection/substitution.

Entry gate: versioning and mutation semantics are specified before UI work.

#### PV1-HEALTH-01 — Authoritative sleep, steps, and active-energy context

- Revalidate HealthKit/Health Connect read provenance, permissions, date zones,
  deduplication, missingness, revocation, and source priority.
- Add consumer surfaces only for reliable data.
- Use descriptive context; do not derive a numeric readiness score or homemade
  workout calorie estimate.

#### PV1-PROD-05 — Plate-calculator presentation consolidation

Move access closer to relevant strength set/exercise flows while preserving the
existing calculation authority. Do not fork formulas or store presentation
state as a new domain record.

**Wave 4 gate:** plan edits are version-safe, analytics distinguish plan from
execution truth, and every health value exposes an approved source and honest
unknown state.

### Wave 5 — New-domain discovery and foundation

- **Priority:** P2/P3
- **Target horizon:** V1.x/V2
- **Dependency:** explicit product approval per initiative

#### PV1-HYD-01 — Canonical hydration domain

This is a new-domain program, not an “unhide water widget” task.

Discovery must decide:

- authoritative log model and units;
- daily target provenance and override behavior;
- civil date/timezone and historical edit semantics;
- quick-add idempotency, edit/delete, and source provenance;
- reminders and target-change behavior;
- Today/Progress/history read models;
- migration of useful legacy values, if truthfully possible;
- backup/export/restore and complete-erasure participation.

Suggested delivery: domain/repository and migration → backup/restore → focused
logging/history tests → quick logging → Today → Progress → reminders. No
surface ships until cross-surface reads agree.

#### PV1-DATA-01 — Verifiable complete erasure

Inventory database records, preferences, local and user-selected backups,
caches/imports, temporary media, secure secrets, notification state, and
integration data. Define what can and cannot be erased automatically. Implement
an idempotent orchestrator, interruption recovery, and post-delete verification
before exposing a “Delete all data” promise.

#### PV1-MEDIA-01 — Supported music provider decision

Discovery only until a real provider is selected. Define authentication,
supported actions, background behavior, offline/failure UX, privacy, regional
availability, and provider lifecycle. Do not expose the dormant empty registry
or resurrect placeholder YouTube behavior.

### Wave 6 — Reviewable intelligence and contextual coaching

- **Priority:** P3
- **Target horizon:** V1.x/V2
- **Dependency:** canonical inputs from earlier waves and separate safety/privacy
  approval

#### PV1-AI-01 — Food description/photo assistance

Use one typed suggestion-review contract for description and photo inputs:

- candidate foods/amounts/nutrients with source and uncertainty;
- explicit missing or unresolvable fields;
- editable review before logging;
- user confirmation as the only canonicalization step;
- consent, transmission disclosure, temporary-file cleanup, offline and
  malformed-response behavior;
- correction provenance suitable for evaluation without silently retraining on
  private data.

Start with natural-language candidates and nutrition-label OCR over a narrow,
measurable food set. Generic meal-photo estimation is a later package after
those safer review paths. Do not ship a point estimate that looks authoritative.

#### PV1-AI-02 — Deterministic “What can I eat?”

Build deterministic candidate filtering from remaining canonical targets,
dietary constraints, available foods/recipes, known quantities, and logged
evidence. AI may explain or reorder already-valid candidates. It may not invent
food nutrition, household conversions, constraints, or target changes.

#### PV1-COACH-01 — Contextual coaching increments

Treat festival, travel, eating out, and intermittent fasting as separate
packages. Each requires canonical context, bounded deterministic behavior,
missing-data semantics, user control, non-medical copy review, and tests that
prove no silent target mutation. Ship one context at a time; do not create a
generic mode framework before the first accepted use case proves it is needed.

**Wave 6 gate:** all generated output is reviewable or explanatory, canonical
numbers remain deterministic, privacy boundaries are tested, and the feature
fails closed offline or on malformed provider output.

## 6. Parallel engineering tracks

These tracks are intentionally not folded into feature packages.

| Track | Earliest start | Required sequencing |
|---|---|---|
| App composition/DI and injected clock/date/preferences | After Wave 1 | Feature-owned provider modules first; persisted keys unchanged |
| Routing normalization and typed payloads | After route inventory in Wave 2 | Destination classification before migration; legacy sunset last |
| Persistence modularization | After deterministic migration tests | Extract helpers/seeders/indexes/lifecycle without schema change first |
| Backup codec consolidation | After dedicated equivalence harness | One historical boundary at a time; never mixed with general DB cleanup |
| Performance optimization | After representative profiling | One measured bottleneck per change; query-plan evidence for indexes |
| Backend modularization | After endpoint contract tests | Config/schemas/app factory first; distributed rate limiting separate |
| Connected backend/security | After PV1-NET-01 and package threat models | Auth/device registry, backup storage, sync, catalogues, AI, and social stay bounded; secrets/redaction/deletion are shared policies |
| Privacy-minimized observability | After consent/redaction contract | Crash/performance first; product events later; fitness payloads excluded by default |
| Dependency/platform upgrades | Last | Small dependency-family batches; no simultaneous architecture refactor |

## 7. First issue queue

Create implementation issues in this order after Gate 0. Items whose
dependencies are satisfied may run in parallel; the order breaks priority ties.

| Order | ID | Issue outcome | Priority | Depends on |
|---:|---|---|---|---|
| 1 | PV1-ENG-01A | Inventory current test construction, global state, warnings, and order-sensitive groups | P0 | Gate 0 |
| 2 | PV1-ENG-01B | Specify and implement the shared isolated test harness | P0 | PV1-ENG-01A |
| 3 | PV1-ENG-01C | Migrate fragile suites and establish repeat/shuffle/serial CI evidence | P0 | PV1-ENG-01B |
| 4 | PV1-ENG-02 | Add missing characterization for release-critical flows | P1 | PV1-ENG-01B |
| 5 | PV1-NET-01A | Freeze the offline-core matrix and connected capability/outbox contracts | P0/P1 | PV1-ENG-01B |
| 6 | PV1-CLOUD-01A | Decide cloud-backup provider/account, encryption/key recovery, retention, deletion, and restore contracts | P1 | PV1-NET-01A |
| 7 | PV1-CLOUD-01B | Implement immutable encrypted upload and verified restore vertical slice | P1 | PV1-CLOUD-01A, PV1-ENG-01C |
| 8 | PV1-SYNC-01A | Specify per-domain identity, tombstone, conflict, version, and convergence rules | P1 | PV1-CLOUD-01A |
| 9 | PV1-CATALOG-01A | Evaluate food providers and specify normalized remote-food/provenance/cache contract | P1 | PV1-NET-01A |
| 10 | PV1-ENG-03 | Produce reachability/ownership inventory for dormant and legacy code | P1 | PV1-ENG-01C |
| 11 | PV1-ENG-04A | Remove or relocate the first evidence-confirmed retired area | P1 | PV1-ENG-03 |
| 12 | PV1-ENG-05A | Mechanically split Progress behind characterization tests | P1 | PV1-ENG-02 |
| 13 | PV1-ENG-05B | Mechanically split Today action surface | P1 | PV1-ENG-02 |
| 14 | PV1-ENG-05C | Mechanically split workout player presentation | P1 | PV1-ENG-02 |
| 15 | PV1-PROD-01A | Specify factual completion/share read model and privacy contract | P1 | Wave 1 |
| 16 | PV1-PROD-01B | Implement recap and local share card with visual/device verification | P1 | PV1-PROD-01A |
| 17 | PV1-CONTENT-01A | Specify signed content-pack envelope, compatibility, activation, and rollback | P1/P2 | PV1-NET-01A |
| 18 | PV1-PROD-02A | Close approved-media acquisition/distribution/performance gate | P1 | licensing approval |
| 19 | PV1-PROD-03A | Specify a small achievement catalog and event identity | P1 | Wave 1 |
| 20 | PV1-PROD-04A | Specify cross-platform rest presence lifecycle; implement Android first | P1/P2 | stable rest lifecycle |

Do not pre-create detailed implementation issues for Waves 4–6 until the prior
wave evidence can inform their scope. Track those as epics/discovery records.

## 8. Unscheduled candidate register

These candidates remain visible without pretending they are committed to a
release. Promote one only when its entry gate is met and higher-priority work is
healthy.

| ID | Candidate | Priority | Entry gate |
|---|---|---|---|
| PV1-NUT-01 | Optional snack slots/configurable diary structure | P2 | V1 diary behavior and migration/backup semantics are stable |
| PV1-PROG-01 | Richer evidence-backed historical drill-downs and period comparison | P2 | Bounded queries and completeness rules are specified |
| PV1-GAME-01 | Expanded streak concepts or streak protection | P3 discovery | Product rules prove the mechanic will not reward unsafe training behavior |
| PV1-UX-01 | Quick light/dark/system theme control | P3 | Settings authority is stable and higher-value core work is complete |
| PV1-MEDIA-02 | Exercise motion demonstrations | P3 | Still-media gate has passed plus motion licensing, size, performance, reduced-motion, and accessibility approval |
| PV1-PR-01 | Canonical PR event product | P3 product decision | New exact-evidence event identity and lifecycle are approved; removed inference code is excluded |
| PV1-CARDIO-01 | Running/cycling routes, maps, elevation, and weather enrichment | P3 | Core modality/GPS product decision, offline recording contract, map/privacy/provider review |
| PV1-MARKET-01 | Verified trainer plan marketplace | P3 | Account/sync, content signing, payments, moderation, refunds, and plan-version governance |
| PV1-COMMUNITY-01 | Verified community exercise tips | P3 | Editorial/moderation, credentialing, misinformation reporting, and canonical-content separation |

## 9. Roadmap-to-package traceability

| Roadmap theme | Planned package or track |
|---|---|
| Deterministic tests and characterization | PV1-ENG-01/02 |
| Retired/dead-code cleanup | PV1-ENG-03/04 |
| God-file decomposition | PV1-ENG-05 |
| Offline/connected architecture and background work | PV1-NET-01 |
| Automatic encrypted cloud backup | PV1-CLOUD-01 |
| Account and multi-device sync | PV1-SYNC-01 |
| Online/branded food search and barcode | PV1-CATALOG-01 |
| Signed food/exercise/plan catalogue updates | PV1-CONTENT-01 |
| Streamed/downloaded exercise videos and packs | PV1-MEDIA-03 |
| Nutrition-label OCR, recipe URL import, meal/plan AI | PV1-INTEL-01 plus PV1-AI-01/02 |
| Direct provider imports, sharing, coach, friends/challenges | PV1-CONNECT-01 |
| Crash/performance diagnostics, analytics, remote config, entitlement | PV1-OBS-01 |
| Workout completion and share | PV1-PROD-01 |
| Exercise media | PV1-PROD-02; motion remains PV1-MEDIA-02 |
| Achievements, Progress, and streaks | PV1-PROD-03, PV1-PROG-01, PV1-GAME-01 |
| Background rest presence | PV1-PROD-04 |
| Plan analytics/customization | PV1-PLAN-01/02 |
| Sleep, steps, and active energy | PV1-HEALTH-01 |
| Plate-calculator consolidation | PV1-PROD-05 |
| Hydration | PV1-HYD-01 |
| Complete erasure | PV1-DATA-01 |
| Playlist/music | PV1-MEDIA-01 |
| Food photo/description and “What can I eat?” | PV1-AI-01/02 |
| Festival/travel/eating-out/fasting coaching | PV1-COACH-01 |
| App composition, routing, persistence, backup, performance, backend, dependencies | Parallel engineering tracks in §6 |
| Diary structure and quick theme | PV1-NUT-01 and PV1-UX-01 |
| Possible future canonical PR product | PV1-PR-01 decision record only |

## 10. Verification matrix

Every implementation package selects the applicable gates below and records
results in its completion note.

| Risk area | Minimum verification |
|---|---|
| Pure documentation/inventory | Link check, source/evidence review, `git diff --check` |
| Mechanical Flutter refactor | Format, analyze, focused characterization/widget/golden tests, full serial suite |
| Database/schema | Fresh create, every supported migration boundary, rollback/failure atomicity, generated-code idempotency, query-plan checks where relevant |
| Backup/export/restore | Historical fixtures, malformed/newer input rejection, export semantic equivalence, restored DB equivalence, interruption/failure behavior |
| Cloud backup | Encryption/key-loss threat cases, upload idempotency, retention/deletion, corrupt/partial/wrong-key restore rejection, provider outage, new-device manual restore |
| Multi-device sync | Two-or-more-device convergence, duplicate/out-of-order replay, tombstones, conflict rules, clock skew, schema skew, offline queue/process death, revoke/logout/delete |
| Remote food/content | Typed normalization, provenance, review/correction, provider conflict/rate limit, signature/hash, compatibility, atomic activation/rollback, offline cached reuse |
| Downloads/streaming | Resume/cancel/integrity, storage budget/eviction, cellular policy, offline playback/fallback, expired URL, upgrade/removal, real-device media performance |
| Platform integration | Unit/adapter tests, denied/revoked permission, lifecycle/process recreation, supported OS matrix, real-device acceptance |
| Media | Provenance/license/checksum validation, exact identity/fallback, bundle/memory/scroll evidence, visual/a11y review |
| AI/network | Strict typed validation, consent/privacy, redaction, timeout/offline/malformed output, user review/correction, no silent persistence |
| Accounts/social/coaching | Consent scope, audience, audit/review-before-apply, revoke/delete, block/report/moderation, safe incentive design, no public sensitive defaults |
| Observability/remote config/entitlement | Payload/breadcrumb redaction, consent off/on, offline buffering bounds, allowlisted config effects, cached entitlement/grace, core unaffected by outage |
| Analytics/coaching | Canonical evidence identity, sparse/unknown states, timezone/history boundaries, no synthetic metric scan |
| Destructive data action | Exact inventory, idempotency, partial-failure recovery, post-action verification, manual acceptance |

## 11. Definition of done

A package is complete only when:

1. its scope and non-goals are explicit;
2. canonical read/write authority is named;
3. migration, backup, privacy, accessibility, and platform impacts are either
   handled or explicitly not applicable with evidence;
4. loading, empty, unknown, error, retry, offline, and historical states are
   defined where relevant;
5. targeted checks and the accepted full regression lane pass;
6. performance claims are measured on the affected path;
7. human visual/device/legal/product gates are recorded rather than inferred;
8. documentation and roadmap status are updated;
9. no rejected synthetic metric or retired implementation has re-entered a
   reachable path;
10. connected packages pass the offline-core matrix, commit core writes locally,
    expose provenance/status/recovery, and preserve promised offline reuse;
11. remote deletion, account revocation, cache eviction, and provider outage
    have explicit user/data behavior;
12. unrelated worktree changes remain untouched.

## 12. Hold register

The following are intentionally not scheduled implementation work:

- old synthetic e1RM and inferred PR code;
- unsupported PR celebration derived from that inference;
- workout calorie formulas;
- numeric readiness/recovery scores;
- unsourced strength standards;
- old Travel Mode UI;
- dormant dashboard architecture;
- hydration widget resurrection without `PV1-HYD-01`;
- placeholder playlist/YouTube behavior;
- unlicensed or unreviewed exercise media;
- server-gated core workout, food, plan, Progress, or history actions;
- remote config that changes canonical workout/nutrition rules;
- silent remote plan/coach changes or unreviewed AI/provider persistence;
- global leaderboards for weight lifted, calorie burn, or unsafe streaks;
- analytics/crash breadcrumbs containing unnecessary fitness records;
- a broad dependency upgrade combined with architecture changes.

If one of these is proposed, open a product-decision record first. The record
must explain what new evidence or architecture changes the previous rejection;
an implementation issue alone is insufficient.
