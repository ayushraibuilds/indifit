# B02 Decisions — Sol Architecture and Readiness Gate

Status: **Accepted with amendments; product decisions accepted**

Gate baseline: `ffbe87f`

Reviewed: 2026-08-01

The canonical roadmap, B01 accepted decisions, B01 verification, and the B02
charter remain binding. This document amends `PLAN.md`; implementation must
follow this document where they differ. No B02 production implementation may
start before the applicable prerequisite and review in `TASKS.md` is satisfied.

## Gate disposition

| ID | Decision | Status |
|---|---|---|
| B02-D01 | One activity identity and modality boundaries | **Amended** |
| B02-D02 | Schema v16 and v15 migration | **Amended — SOL-GATE PASSED FOR CONTRACT** |
| B02-D03 | Exercise identity, ancestry, and substitution | **Accepted with clarification — SOL-GATE PASSED** |
| B02-D04 | Snapshot, draft v2, and finalization | **Amended — SOL-GATE PASSED FOR CONTRACT** |
| B02-D05 | Exercise-group prescription and execution | **Amended** |
| B02-D06 | Advanced technique representation | **Amended — SOL-GATE PASSED FOR CONTRACT** |
| B02-D07 | Warm-up calculator rule v1 | **Amended** |
| B02-D08 | Rest precedence and performed rest | **Amended** |
| B02-D09 | Cardio, yoga, and mobility ownership | **Amended — SOL-GATE PASSED FOR CONTRACT** |
| B02-D10 | Exercise-muscle mappings | **Amended — SOL-GATE PASSED FOR CONTRACT** |
| B02-D11 | Load/repetition target MVP | **Amended — SOL-GATE PASSED FOR CONTRACT** |
| B02-D12 | Repository/provider ownership | **Amended** |
| B02-D13 | Backup v7 compatibility | **Amended — SOL-GATE PASSED FOR CONTRACT** |
| B02-D14 | Muscle-volume metrics | **Amended; effective-set estimate deferred — SOL-GATE PASSED** |
| B02-D15 | Health-import identity and deduplication | **Amended — SOL-GATE PASSED FOR CONTRACT** |

The gate approves contracts, not implementation. Schema, restore, finalization,
health, mapping, volume, and target code still require the task-level Sol High
reviews specified below.

## B02-D01 — One activity identity and typed detail boundaries

- **Status:** Amended.
- **Final rule:** Extend `WorkoutSessions` as the one physical activity-session
  header; do not create a parallel activity table or a second completion owner.
  Add common nullable `startedAtUtc`, `endedAtUtc`, `origin` (`scheduledManual`,
  `unscheduledManual`, `healthImport`), and schema-version fields. Add a 1:1
  `StrengthSessionDetails` row for new strength sessions, alongside 1:1 cardio
  or mobility details. Exactly one matching detail row is required for every
  new canonical session. The existing non-null `name`, `totalVolume`,
  `estimatedCalories`, and `completedAt` columns remain compatibility fields;
  zero in those legacy columns is not evidence of zero distance, energy, or
  strength volume.
- **Rationale:** Reusing the integer header preserves B01 session, occurrence,
  history, and health ancestry. A strength detail discriminator makes modality
  pairing enforceable and gives session-level strength notes/RPE a bounded
  owner without forcing them onto cardio or mobility.
- **Invariants:** one completed workout has one session ID; one and only one
  modality detail; completed rows are immutable evidence; later prescriptions
  never update performed rows; legacy sessions remain `legacy` and are not
  reclassified from names, set fields, or zero volume; manual and imported
  origins remain distinguishable.
- **Failure behavior:** reject missing, duplicate, or mismatched detail graphs
  before commit; unknown legacy modality remains `legacy`.
- **Required tests:** legacy history projection; every valid/invalid
  type/detail pairing; nullable observed facts; scheduled/manual/imported
  provenance; immutable completed rows.
- **Affected tasks:** B02-01, B02-02, B02-03, B02-05, B02-09A, B02-09B,
  B02-13, B02-14.

## B02-D02 — Schema v16 and deterministic v15 migration

- **Status:** Amended; contract approved, implementation requires Sol High.
- **Final rule:** v16 is one explicit Drift transaction. Add header/template/
  draft/preference extensions first; create referenced catalogs and
  prescription parents before child tables; create activity headers before
  performed/modality children; create indexes after columns/tables. In addition
  to the proposal, v16 must include `StrengthSessionDetails`, typed cardio and
  mobility prescription tables, interval-prescription rows, health dedup fields,
  versioned mapping identity, repetition/load-side semantics, and prescribed/
  actual duration fields for isometric strength work. Preserve all v15 tables
  and columns.
- **Rationale:** The proposed schema had no enforceable strength-detail row, no
  durable scheduled cardio/mobility prescription, no static-hold/unilateral
  semantics, and no provider-scoped dedup key. Those omissions would make the
  execution graph incomplete before its first writer.
- **Invariants:** existing sessions get only nullable additions plus
  `activityType=legacy`; no `WorkoutSets` to `PerformedSets` copy; no v1 draft
  rewrite; no group, technique, modality, target, rest, mapping, or muscle result
  is inferred; custom/unresolved exercises retain their exact identity state;
  no historical mapping result is backfilled.
- **Index/constraint minimum:** retain unique scheduled occurrence ancestry;
  index activity type/time, performed exercise session/ordinal and stable ID,
  performed set role/exercise, interval parent/ordinal, group parent/ordinal,
  mapping exercise/muscle/version/status, and provider dedup keys. Enforce
  non-negative observed values, contiguous-order validation, legal enum values,
  and unique 1:1 detail rows.
- **Failure behavior:** any DDL, seed, backfill, index, or verification failure
  rolls back the entire upgrade and leaves `user_version=15` and source rows
  unchanged.
- **Required tests:** real on-disk v15 fixture containing B01 program/occurrence,
  completed legacy strength, imported health session/provenance, active v1
  scheduled draft, custom and unresolved exercises; fresh v16 creation; FK and
  check failures; injected rollback; query-plan/index assertions; bounded
  upgrade performance fixture.
- **Affected tasks:** B02-01, B02-02, B02-03, B02-13.

## B02-D03 — Canonical identity, ancestry, and substitution

- **Status:** Accepted with clarification.
- **Final rule:** Every new B02 strength prescription/performed write requires
  an exact stable exercise ID and immutable display-name snapshot. Each actual
  slot retains source prescription, expected identity, actual identity,
  original group/member/round slot, and substitution reason when supplied.
  Repeated use of the same exercise is valid through distinct prescription/
  member IDs. History and recommendations use actual identity and load basis.
- **Rationale:** This preserves prescription adherence and actual training
  evidence without claiming substituted exercises are equivalent.
- **Invariants:** no fuzzy, substring, lowercase-only, or technique-stripping
  merge; aliases require the B01 reviewed manifest; unresolved legacy history
  stays separate; substitution never mutates template/snapshot; rename with a
  stable ID preserves canonical history.
- **Failure behavior:** unresolved or ambiguous identity suppresses canonical
  B02 execution/recommendations and offers explicit resolution/manual legacy
  flow; it never guesses.
- **Required tests:** duplicate names; rename; custom ID restore; unresolved
  legacy; substitution; repeated exercise members; expected-versus-actual
  history.
- **Affected tasks:** B02-01, B02-03, B02-04, B02-05, B02-08, B02-11,
  B02-13.

## B02-D04 — Frozen snapshot, one draft, and idempotent finalization

- **Status:** Amended; contract approved, cutover requires Sol High.
- **Final rule:** `WorkoutDrafts` remains the sole active durable draft. A v2
  envelope is bound to the exact frozen snapshot ID/version/hash and stores
  modality route state, every planned slot status, actual order, substitutions,
  group round/member cursor, set/segment cursor, interval cursor, offered
  targets/warm-ups, overrides, and active rest timestamps. v0/v1 stays readable
  only through the legacy path. Finalization uses the existing B01 transaction:
  insert the one header and matching detail graph, transition occurrence and
  append command event, record the canonical payload digest/result, then delete
  the exact draft last.
- **Rationale:** B01 already proves the correct transaction seam. A digest of
  the complete canonical payload is needed so a retry cannot accept a changed
  group/segment/detail graph.
- **Invariants:** unique non-null occurrence-to-session ancestry; same command
  and same payload returns the same session; same command/different payload and
  competing commands fail; resume never creates/refreezes a session; failure
  retains `inProgress` plus draft; no post-commit cleanup; empty strength work
  is discard/cancel, not a false partial completion.
- **Failure behavior:** corrupt/mismatched/future drafts are recoverable errors;
  zero mutation on graph validation failure; imported/unscheduled activities
  use idempotent import/local command keys without occurrence mutation.
- **Required tests:** kill/resume at each cursor/rest position; v0/v1/v2 matrix;
  corrupt/future codec; full/partial retry and competing payload; injected child
  insert/event/draft-delete rollback; imported and unscheduled idempotency.
- **Affected tasks:** B02-03, B02-05, B02-07B, B02-09A, B02-09B, B02-13,
  B02-15.

## B02-D05 — Exercise-group MVP

- **Status:** Amended.
- **Final rule:** Groups exist in both frozen prescriptions and performed
  history. Prescription groups use stable IDs, type (`superset`, `circuit`,
  `giantSet`), ordered distinct member records, and shared round count.
  Supersets have exactly two members, circuits two or more, giant sets three or
  more. Each member has exactly one working-set prescription per round in B02;
  member target ordinal maps deterministically to round ordinal. Group rest is
  after a round; optional member transition rest is between members.
- **Rationale:** A shared-round slot model is the smallest deterministic graph
  that supports the charter without uneven or nested execution ambiguity.
- **Invariants:** grouping is ID-based; planned order and actual action order
  are separate; partial work is never full; substitution retains ancestry;
  later prescription edits never alter performed snapshots.
- **Execution:** traversal is group ordinal, round, member, set/segment. A slot
  is `pending`, `performed`, `skipped`, or `partial`. Advancing past an
  unfinished slot requires explicit skip/partial action. Starting a later round
  never marks a prior round complete. Actual action ordinal is stored so
  performed history retains deviations from planned traversal. A group is full
  only when every planned slot is performed; otherwise the activity is partial.
- **MVP limits:** no nested groups, branching, lap-until-time, unequal member
  round counts, or mutation after publication/start. Repeated exercise identity
  is allowed only via separate member/prescription IDs. Future prescription
  reorder never changes performed group snapshots.
- **Failure behavior:** invalid cardinality/order/target count rejects authoring
  or snapshot start; inconsistent resume cursor rejects recovery without
  changing the draft.
- **Required tests:** cardinality matrix; duplicate identity with distinct
  members; target-to-round mapping; skip/partial/out-of-order action; exact
  resume; substitution; published immutability; backup/history order.
- **Affected tasks:** B02-03, B02-04, B02-05, B02-10, B02-13.

## B02-D06 — Hybrid composable technique model

- **Status:** Amended.
- **Final rule:** Use a hybrid model: exclusive typed axes for `setRole`
  (`warmup`, `working`) and `effortMode` (`standard`, `amrap`, `toFailure`),
  plus composable validated tempo, pause, assistance, drop, and rest-pause
  attributes/segments. Do not extend the legacy free-text taxonomy.
- **Rationale:** Exclusive effort/role axes prevent contradictions while
  composable attributes preserve legitimate technique combinations.
- **Invariants:** prescribed and actual facts remain distinct; completed
  segment order is immutable; external load is never replaced with an inferred
  effective load; legacy types remain readable.
- **Tempo:** each of eccentric, bottom pause, concentric, and top/lockout is a
  tagged component: `timed` with 0–30 seconds, `userPaced`, or `unknown` for
  performed/imported evidence. A prescribed tempo cannot use `unknown`; when
  enabled all four components exist and at least one is timed above zero or
  user-paced.
- **Paused repetitions:** prescribed and actual values are separate. Location
  is a controlled enum (`bottom`, `top`, `midRange`, `customPosition`) with an
  optional note for custom position; intended/actual duration is 0–30 seconds
  or user-paced/unknown as applicable.
- **Assistance:** store assistance mode/category and positive amount separately
  from external load. `loadBasis` states total external, per implement, per
  side, bodyweight, or assisted-bodyweight. Repetition basis records total,
  per-side, or alternating and completed-side evidence. No net-load inference.
- **Rest-pause/drop:** ordered segments are the cluster boundaries; header reps
  equal segment reps; non-first rest-pause clusters require positive recorded
  intra-cluster rest; drop intent requires at least one supported load decrease.
  A segment may be both after rest and lower load.
- **Validity:** warm-ups are never working volume or PR candidates regardless
  of attached technique. A warm-up must use `standard`, cannot be marked ended
  at failure, and cannot use drop/rest-pause or assisted-effort metadata; tempo
  or a pause may be retained as technique rehearsal. In B02, `amrap` and
  `toFailure` are mutually exclusive; `endedAtFailure` is an observed outcome.
  Negative values, partial tempo, contradictory role/effort, or segment/header
  mismatch reject. Isometrics use explicit target/actual duration rather than
  fake repetitions.
- **Failure behavior:** unknown future enum/technique values fail closed in
  drafts/backups with zero mutation; legacy set types remain readable only in
  legacy projection.
- **Required tests:** valid combination matrix; every contradiction; tempo
  tags/bounds; pause intended/actual; assistance/load/repetition basis;
  segment totals/rest/load drop; isometric duration; codec/backup/history.
- **Affected tasks:** B02-02, B02-03, B02-06, B02-11, B02-13.

## B02-D07 — Warm-up recommendation rule v1

- **Status:** Amended.
- **Final rule:** Retain the deterministic 1–4 stage percentages/repetitions in
  `PLAN.md`, but resolve equipment increment, minimum usable load, implement
  count/load basis, and bar/implement empty weight from the frozen equipment
  context before rounding. Never recommend below the physical minimum or at/
  above the working load; collapse duplicates. Per-hand/per-side values remain
  in that basis. Bodyweight gets an optional unloaded preparation set; assisted
  and unsupported bases return unavailable unless an explicit valid target
  exists.
- **Inputs/order:** explicit draft target, accepted target recommendation,
  prescribed load, then recent exact comparable load; exercise/equipment IDs,
  increment, bar/minimum, load basis, user preference/count, and rule version.
  No history is required. User edits are always allowed and stored as actual
  warm-up sets.
- **Rationale:** Percentage rounding without bar/minimum-load knowledge can
  create impossible or duplicate ramps.
- **Invariants:** pure, deterministic, unit-safe, offline, bounded, non-medical;
  no invented 20 kg/default increment; zero/negative/duplicate stages are not
  emitted; warm-ups never count as working volume.
- **Failure behavior:** malformed/missing load, equipment, increment, or basis
  returns an explainable unavailable/manual state, never a guessed plan.
- **Required tests:** stage tables; bar/minimum floor; dumbbell per-hand;
  machine stack; bodyweight/assisted; very light; unknown increment; no history;
  edit/skip/add; kg/display-unit round trip.
- **Affected tasks:** B02-01, B02-03, B02-07A, B02-10.

## B02-D08 — Rest precedence and actual-rest evidence

- **Status:** Amended.
- **Final rule:** `actualRest` is an observation, never an input to selection.
  The duration that starts a timer is, highest first: (1) current manual timer
  adjustment, (2) temporary workout-scoped override, (3) context prescription
  — rest-pause intra-cluster, member transition, or group-after-round,
  (4) set/program prescription, (5) saved exercise preference/default,
  (6) automatic recommendation, (7) app default 90 seconds. Only applicable
  contexts participate. An automatic/technique “minimum” is advisory unless it
  is an explicit prescription and never raises a user/prescription value
  silently.
- **Rationale:** Context-aware precedence preserves explicit program/user intent
  while retaining a bounded fallback and performed evidence.
- **Invariants:** automatic rest never overrides an explicit value; actual rest
  never selects the timer; cluster/group contexts cannot invoke the wrong
  timer; timer failure never blocks execution.
- **Context:** no generic rest between group members unless transition rest is
  explicit; after the final member use group-after-round rest; after the final
  round use the same value unless explicitly skipped. Rest-pause cluster rest
  never invokes the generic timer. AMRAP/failure influence only automatic
  fallback. Missing RPE causes no adjustment.
- **Persistence:** selected/recommended/source, start/end UTC, actual elapsed,
  and end reason are stored when a timer is entered. Current adjustment applies
  once; workout override survives draft resume but ends with the workout;
  exercise preference changes only through an explicit save action.
- **Failure behavior:** timer/background/notification failure never blocks the
  next record; elapsed time is recomputed from wall clock; missing configuration
  falls to the app default with source shown.
- **Required tests:** complete precedence matrix; group/final member;
  rest-pause; AMRAP/failure; manual/temporary persistence; background/resume;
  skip/extend; clock anomaly; notification denied.
- **Affected tasks:** B02-03, B02-07A, B02-07B, B02-10, B02-13.

## B02-D09 — Typed modality prescriptions and performed records

- **Status:** Amended.
- **Final rule:** Running, walking, cycling, yoga, and mobility share only the
  activity header. Add durable cardio/mobility session prescriptions and
  ordered cardio interval prescriptions so scheduled frozen snapshots are not
  JSON-only authoring authorities. Cardio performed details use canonical SI
  storage with an input/display-unit snapshot: nullable duration, distance,
  observed pace/speed, incline, elevation gain/loss, HR summary, RPE/intensity,
  energy, indoor/outdoor, notes, and origin. Unknown observed values stay null.
  Yoga/mobility details require duration and allow typed practice/style,
  intensity, focus/body region/goal, notes, and HR; they never require distance,
  pace, or strength sets.
- **Rationale:** Modality-specific prescriptions/details prevent strength-set
  columns and snapshot JSON from becoming inappropriate duplicate authorities.
- **Invariants:** one matching detail; canonical units plus display basis;
  missing is null; origin is retained; later prescriptions cannot change
  performed intervals or session facts.
- **Intervals:** ordered prescription and performed segments use work/recovery,
  a target/actual basis, partial status, and deterministic cursor. Repeats are
  expanded into immutable segment ordinals at snapshot time while retaining
  source repeat-group/count metadata. B02 default MVP exposes time-based
  segments; distance-based authoring is deferred by accepted B02-PD04.
- **Completion:** aggregate duration is required and greater than zero. Interval
  completion records performed/partial/skipped segments; missing distance is
  null, never zero. Completed manual/imported activities are immutable in B02.
- **Failure behavior:** invalid units, negative metrics, missing duration,
  mismatched modality/detail, or unknown provider type reject without a header.
- **Required tests:** required/optional matrix; unit conversions; missing-not-
  zero; time/distance segment validation; repeat expansion; partial resume;
  yoga/mobility no-distance; scheduled/manual/imported finalization.
- **Affected tasks:** B02-02, B02-03, B02-09A, B02-09B, B02-10, B02-13.

## B02-D10 — Versioned, reviewed exercise-muscle mappings

- **Status:** Amended; manifest requires Sol approval before volume code.
- **Final rule:** Use stable muscle IDs and append-only mapping catalog versions.
  A mapping row records exercise ID, muscle ID, role (`primary`, `secondary`,
  `stabilizer`), contribution basis points, source/provenance, confidence,
  review status/reviewer, and mapping version. Uniqueness includes mapping
  version. Only a checked-in deterministic manifest with reviewed status may
  feed analytics. Luna may inventory labels and unresolved cases but may not
  choose anatomical weights.
- **Rationale:** The proposed unique exercise/muscle pair would overwrite
  versions and prevent historical reproduction. Comma-separated legacy labels
  are not evidence for allocations.
- **Invariants:** unknown/custom/unreviewed mappings remain unknown; no fuzzy
  mapping; changes append a version and never update performed facts; analytics
  select an explicit current or requested rule/mapping version and report
  coverage. Technique, unilateral, isometric, cardio, yoga, and mobility do not
  alter anatomical weights in B02. A complete volume-eligible exercise mapping
  version sums to exactly 10,000 contribution basis points across its reviewed
  roles; an incomplete allocation remains unreviewed and unavailable.
- **Failure behavior:** incomplete/unreviewed allocations go to the unallocated
  bucket; invalid totals/IDs/version are rejected; restore never invents or
  merges mappings.
- **Required tests:** manifest determinism/provenance; stable IDs; version
  coexistence; reviewed/unreviewed/custom/unknown; role and allocation checks;
  restore without inference.
- **Affected tasks:** B02-01, B02-02, B02-03, B02-11, B02-13.

## B02-D11 — Automatic target B02 MVP

- **Status:** Amended; deterministic history rule accepted, recovery adaptation
  deferred to B04.
- **Final rule:** The B02 engine may recommend only from an exact stable exercise
  ID, identical load/repetition basis, a valid prescription range, and the most
  recent eligible working evidence within 12 weeks. At/above max with RPE ≤8
  permits +one known increment; below min or explicit failure before min permits
  -one increment; within range, high/unknown RPE, conflicting recent outcomes,
  or low confidence keeps the prescribed/prior stable value. A deload snapshot
  may apply the accepted 90% rule then equipment rounding. No generic load,
  ambiguous identity, assisted-load, or bodyweight-load recommendation.
- **Fallbacks:** new/no/stale history uses an explicit prescription at low
  confidence or returns no load; no rep range preserves a prior achieved rep as
  a non-prescriptive hint only; missing equipment increment suppresses load
  change; failed/abnormal/invalid observations are evidence, not silently
  normalized. Low confidence falls back to prescription or prior stable value.
- **Conflict/anomaly rule:** the last three eligible outcomes conflict when they
  contain both an increase signal and a decrease/failure signal; keep the stable
  prescription/prior load and lower confidence. A latest candidate is anomalous
  when it differs from the median load of the prior two eligible sessions by
  more than the greater of 25% or four resolved increments and its own session
  does not contain two working sets within one increment of that candidate;
  suppress it and fall back. With fewer than two prior sessions, do not invent
  an anomaly classification, but confidence cannot be high. Non-finite,
  negative, or domain-invalid values are never eligible.
- **Evidence/output:** load and basis, rep range/hint, confidence, completeness,
  main evidence IDs, missing inputs, rationale codes, rule version, comparator
  cutoff/count, prescription-change flag, and separate user override. Completed
  history is never changed.
- **Recovery boundary:** sleep/recovery and seven-day workload may be displayed
  as missing/available evidence only. They do not change the numeric result or
  implement readiness. Recovery-informed adaptation, calibrated confidence,
  multi-session trend coaching, and automatic substitution are B04.
- **Rationale:** This keeps the charter's explainable progression aid while the
  roadmap's readiness/adaptive coaching remains in B04.
- **Invariants:** recommendations are optional, bounded, versioned and
  reversible; missing recovery is unknown; identity/basis is exact; completed
  history is immutable; low confidence cannot create a novel load.
- **Failure behavior:** conflicting/ambiguous/unsafe input returns the stable
  fallback or no recommendation; recommendation is optional and never blocks or
  silently writes actual values.
- **Required tests:** below/within/above range; RPE bands/failure; one-increment
  bounds/rounding; per-hand/per-side; bodyweight/assisted; deload; no/stale/
  conflicting history; unresolved identity; missing recovery; abnormal invalid
  values; explanation and override persistence.
- **Affected tasks:** B02-01, B02-03, B02-05, B02-07A, B02-08, B02-10,
  B02-13.

## B02-D12 — Bounded ownership

- **Status:** Amended.
- **Final rule:** One finalization coordinator composes bounded repositories;
  it is not itself the activity data repository. Owners are: activity header,
  strength execution, cardio execution, mobility execution, program/group
  authoring, draft/codec, pure warm-up, pure rest selection, rest timer state,
  exercise catalog/mappings, muscle-volume read model, pure target rule, and
  health import/provenance. `CalendarRepository` remains occurrence owner.
  `WorkoutRepository` is legacy projection only.
- **Rationale:** Aggregate-specific repositories and pure algorithms avoid both
  a workout monolith and circular cross-repository writes.
- **Invariants:** no widget SQL; no screen-local algorithm; one draft codec, one
  volume engine, one completion coordinator; repositories depend on DAOs and
  pure services without cycles; health translation never writes legacy sessions
  directly once B02 is live.
- **Failure behavior:** cross-aggregate work is rejected outside the coordinator
  transaction; provider invalidation occurs only after commit.
- **Required tests:** dependency construction/ownership test; no widget DB
  imports; command delegation; single-writer audit; provider invalidation after
  successful commit.
- **Affected tasks:** B02-03 through B02-15.

## B02-D13 — Backup v7 before durable writers

- **Status:** Amended; contract approved, restore implementation requires Sol
  High.
- **Final rule:** Implement Backup v7 immediately after v16 schema and typed
  codecs, before any B02 feature writer is enabled. One backup owner serializes
  every B02 extension and user-owned row: all three modality details and
  prescriptions, groups/members, strength prescriptions/performed graph,
  segments, rest, target evidence/overrides, intervals, custom rest/preferences,
  versioned mappings if user-owned, v2 drafts, and health provenance/dedup
  metadata. Derived heat-map/weekly values are not exported.
- **Rationale:** Enabling writers before portability creates valid user-owned
  data that cannot be restored. The full schema exists after B02-02, so restore
  can and must be proven first.
- **Compatibility/order:** v5/v6 stay importable with absent B02 collections and
  produce only legacy sessions. Prevalidate version, enums, IDs, detail pairing,
  segment totals, mapping version/review state, draft references, and the full
  FK graph before mutation. Insert catalogs/exercises, mapping versions,
  program/prescriptions, session headers, detail/performed children, drafts,
  then health provenance; delete in exact reverse dependency order. Preserve
  the existing single DB transaction and preference compensation.
- **Invariants:** future version fails before mutation; no orphan dropping,
  fuzzy exercise merge, mapping invention, JSON escape hatch, or incomplete
  graph export; unknown technique/modality fails safely; seeded references use
  stable IDs and custom IDs survive remap.
- **Failure behavior:** any parse/prevalidation/delete/insert/preference failure
  restores the prior database and preferences; unsupported newer version causes
  zero mutation.
- **Required tests:** v5/v6 import; full v7 exact round trip including partial
  sessions and active v2 draft; invalid/future enum/version/graph; custom and
  unresolved exercise; health provenance; forced rollback; encryption/checksum.
- **Affected tasks:** B02-02, B02-03, B02-13 and every later durable writer.

## B02-D14 — Muscle-volume metric contract

- **Status:** Amended; the proposed “effective-set completion ratio” is rejected
  as mislabeled. Physiological effective-set estimation is deferred.
- **Final rule:** B02 exposes four separate deterministic measures:
  (1) raw performed working-set slots, (2) weighted muscle-set allocation using
  the selected reviewed mapping version, (3) prescription completion ratio when
  a target exists, and (4) external-load × repetitions where mathematically
  defined. Time/distance modality metrics remain separate. Do not call
  completion ratio an effective set or biological stimulus.
- **Rationale:** Prescription completion is mechanically reproducible, whereas
  “effective set” implies an unvalidated physiological stimulus estimate.
- **Invariants:** each metric has one name/unit/rule version; warm-ups never
  enter working totals; groups/segments do not multiply slots; unknown mapping
  differs from zero; no derived aggregate becomes historical authority.
- **Rules:** warm-up = zero working sets; working rep set with reps >0 = one raw
  slot; isometric working set with positive duration = one raw slot; a failed or
  partial attempt with performed work remains one raw slot and separately
  reports outcome/completion; zero-work attempt is not a working set; AMRAP,
  drop, and rest-pause segments remain one slot; segment load×reps sum for load
  volume; group membership does not multiply; assisted work is labelled and
  excluded from PR/net-load inference; unilateral work follows stored load and
  repetition basis and is never automatically doubled; cardio/yoga/mobility do
  not contribute strength muscle sets.
- **Allocation:** each raw slot contributes mapping basis points per muscle.
  Primary/secondary/stabilizer roles are displayed; weights come only from the
  reviewed manifest. Unknown/unreviewed mappings contribute to an explicit
  unallocated count and coverage denominator. Zero mapped work and unavailable
  mapping are different states.
- **Versioning:** rule version and mapping version are query inputs and appear in
  the read model. Append-only mapping versions plus immutable performed facts
  reproduce a prior result; no permanent migration backfill or mutable weekly
  aggregate.
- **Failure behavior:** missing target makes completion null, not zero; missing
  load/reps suppresses load volume; missing mapping produces unavailable/
  unallocated, never zero muscle work.
- **Required tests:** truth table for every role/technique/outcome; unilateral/
  assisted/isometric; mapping roles/weights; unknown versus zero; timezone
  windows; rule/mapping-version reproduction.
- **Affected tasks:** B02-01, B02-03, B02-06, B02-11, B02-12, B02-13.

## B02-D15 — Provider-scoped health deduplication and provenance

- **Status:** Amended; this was a critical gate Terra did not separate.
- **Final rule:** Prefer the provider's stable record ID with uniqueness on
  `(provider, providerRecordId)`. Retain the raw ID and provider separately; do
  not depend on a caller-prefixed string. Without a stable ID, use a versioned
  deterministic hash of provider, source/device ID when available, exact start
  and end instants, mapped modality, and canonical observed duration/distance/
  energy fields. Approximate timestamp matching alone is not uniqueness.
- **Rationale:** Provider identity is stronger than time similarity, while
  immutable local evidence needs explicit behavior for revised, deleted,
  partially authorized, or manually duplicated provider records.
- **Invariants:** one provider record creates at most one activity; a provider
  collision never mutates a manual record; origins remain visible; completed
  facts are not silently updated or deleted.
- **Updates/deletes:** the same provider ID never creates a second session.
  Because completed evidence is immutable in B02, changed provider payloads
  update provenance metadata (`lastSeen`, payload hash, provider modified time,
  update/deletion status) and surface a correction-required state; they do not
  silently rewrite or delete the activity. Provider deletion never cascades to
  local history. Partial permission imports only authorized fields and records
  missingness.
- **Manual collision:** health import never auto-merges with a manual session.
  A deterministic overlap candidate returns a visible collision result and is
  not inserted or used to alter the manual row.
  IndiFit-origin records are excluded by stable source metadata when available,
  with the collision policy as fallback.
- **Failure behavior:** unknown provider modality is skipped with a visible
  reason; unstable-ID collision or ambiguous manual overlap creates no session;
  restart/reimport returns the existing provenance result.
- **Required tests:** provider ID restart/reimport; same raw ID across providers;
  fallback fingerprint; changed payload; provider deletion; partial permission;
  unknown modality; manual overlap; source metadata missing; restore uniqueness.
- **Affected tasks:** B02-01, B02-02, B02-09B, B02-13, B02-15.

## Accepted product-owner decisions

The recommended defaults are accepted for B02. Alternatives were considered
and intentionally not selected for the reasons recorded below; no further
product-owner confirmation is required.

| ID | Status | Accepted rule | Alternative not selected and reason | User-visible consequence | Data/schema consequence | Affected tasks |
|---|---|---|---|---|---|---|
| B02-PD01 | **Accepted** | Assisted repetitions are excluded from standard load/1RM PRs and shown only as a separate assisted best. | Counting raw external load would present assisted work as unassisted strength; hiding all assisted bests would lose useful history. | Users see a clearly labelled assisted best, never an unassisted PR. | Read-model classification only; no migration. | B02-08, B02-12, B02-14 |
| B02-PD02 | **Accepted** | Users may combine techniques within D06: one effort mode plus compatible tempo, pause, assistance, drop, or rest-pause attributes. | Restricting to one attribute would reject legitimate combinations and waste the hybrid schema. | Advanced editor exposes composable options and rejects contradictory combinations. | Existing hybrid tables/codec are sufficient. | B02-06, B02-10 |
| B02-PD03 | **Accepted** | Actual rest is recorded when the user enters a timer/rest state; users may skip or extend it, and the source is shown. | Manual-only logging would lose reliable timer evidence; recording every idle second would imply rest the user did not start. | Rest appears in history only when intentionally started, with skip/extend control. | `PerformedRestPeriods.actualSeconds` is populated by timer coordination and backed up. | B02-07B, B02-10, B02-13 |
| B02-PD04 | **Accepted** | B02 interval authoring is time-based. Typed distance basis/nullable fields remain for future compatibility, but distance-segment authoring is deferred. | Supporting both now expands editor, validation, resume, and platform-import scope without being required for the B02 MVP. | Users log timed work/recovery intervals; aggregate distance remains optional. | No second migration; future distance segments can use the shipped basis fields. | B02-09A, B02-10, B02-13 |
| B02-PD05 | **Accepted** | Yoga and mobility store session-level duration, style/intensity, focus/body region, notes, and optional HR; no individual movement list in B02. | Per-movement history requires another prescription/performed graph and draft cursor with limited B02 value. | Fast session logging without distance or strength-set controls. | No movement tables or backup collections in B02. | B02-09A, B02-10, B02-13 |
| B02-PD06 | **Accepted** | Automatic load targets default to `ask`/opt-in and always show explanation before applying. | Enabled-by-default risks silent prescription changes; disabled-by-default hides the charter capability unnecessarily. | No suggested load is silently prefilled; users can opt in and override. | Backed-up preference; target engine schema unchanged. | B02-08, B02-10, B02-13 |
| B02-PD07 | **Accepted** | User-created muscle mappings are not allowed in B02; custom/unreviewed exercises remain unknown. | Unreviewed user weights would create unsupported anatomy claims and add a mapping editor/backup ownership surface. | Custom exercises show incomplete/unknown coverage instead of invented muscle volume. | No user-owned mapping editor; reviewed manifest remains the only analytic source. | B02-01, B02-11, B02-12, B02-13 |
| B02-PD08 | **Accepted** | New users default to `ask` for warm-ups; recommendations are non-blocking and never silently added. | Automatic adds unreviewed sets; off removes the safer preparation option from first use. | Users review, edit, skip, or add the proposed ramp. | One backed-up preference; no algorithm change. | B02-07A, B02-10, B02-13 |

## Explicit B04 deferrals

- Physiological “effective set” or stimulus estimation.
- Recovery/readiness score and any sleep-driven numeric load adjustment.
- Workload-driven progression, calibrated multi-session confidence, coaching,
  and automatic exercise equivalence/substitution.
- Correction/reconciliation workflow for changed or deleted provider records.
