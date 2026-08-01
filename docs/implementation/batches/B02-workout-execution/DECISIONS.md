# B02 Decisions — Workout Execution and Modalities

Status: proposed architecture gate. The decisions marked **SOL-GATE REQUIRED**
must be approved before the dependent implementation task begins. Product
choices are intentionally not encoded as defaults until the product owner
records them.

`CHARTER.md`, the B01 decisions, and B01 verification remain binding. In a
conflict, this document controls B02 implementation; `PLAN.md` explains the
resulting architecture.

## Gate inventory

| ID | Decision | Status | Principal risk |
|---|---|---|---|
| B02-D01 | Reuse `WorkoutSessions` as the physical activity-session header | Proposed | Breaking history/provenance ancestry |
| B02-D02 | Schema v16 and Backup v7 compatibility | **SOL-GATE REQUIRED** | Data loss or un-restorable records |
| B02-D03 | Canonical identity and substitution provenance | **SOL-GATE REQUIRED** | Fragmented history/fuzzy mapping |
| B02-D04 | Frozen snapshot, v2 draft and idempotent finalization | **SOL-GATE REQUIRED** | Draft loss or duplicate completion |
| B02-D05 | Explicit ordered exercise groups | Proposed | Invalid group execution/partial state |
| B02-D06 | Composable technique representation | **SOL-GATE REQUIRED** | Lossy technique history |
| B02-D07 | Deterministic warm-up recommendation | Proposed | Unsafe/invented load recommendation |
| B02-D08 | Rest precedence and actual-rest persistence | Proposed | Silent override/incorrect rest history |
| B02-D09 | Typed cardio, yoga and mobility activity records | **SOL-GATE REQUIRED** | Misclassified health/import data |
| B02-D10 | Reviewed muscle mapping and metric semantics | **SOL-GATE REQUIRED** | False precision in analytics |
| B02-D11 | Explainable load/repetition target rule v1 | **SOL-GATE REQUIRED** | Unsafe opaque progression |
| B02-D12 | Bounded ownership and legacy-adapter retirement | Proposed | Global repository/dual-authority growth |
| B02-PD01–PD05 | Product-visible choices | Product owner required | Unexpected UX defaults |

## B02-D01 — Reuse the existing session as the activity header

- **Final rule:** Extend `WorkoutSessions`; do not add a parallel
  `ActivitySessions` table. In B02 documentation and code, refer to it as the
  activity-session header. Add a typed `activityType` with `legacy` as the
  migration value and use separate detail tables for cardio and mobility.
- **Rationale:** The current integer session identity already owns scheduled
  occurrence linkage, health provenance, history, backup and legacy set FKs.
  A parallel table would demand a risky backfill and duplicate ownership.
- **Invariants:** exactly one applicable modality detail exists for every new
  non-strength B02 session; strength detail is its `Performed*` graph; legacy
  sessions remain queryable; no UI guesses a type from `name`.
- **Required tests:** legacy header/history read; type/detail validation;
  scheduled strength, manual cardio and manual mobility finalization.

## B02-D02 — Schema v16 and Backup v7

- **Final rule:** B02 is one migration from v15 to v16 and one backup format
  from v6 to v7. It adds the exact extension/new-table set in `PLAN.md`.
- **Migration policy:** run all DDL, safe defaults, indexes, catalog seeding
  and migration checks within one explicit transaction. Retain every B01 table
  and column. Existing sessions become `legacy`; existing sets/drafts are not
  fabricated into rich B02 records.
- **Backup policy:** v7 serializes every user-owned B02 row and all B02
  extensions. v5/v6 imports accept missing B02 collections and restore B01
  state unchanged. Restore prevalidates then inserts in FK order, and deletes
  in reverse order inside the existing transaction/compensation protocol.
- **Prohibited:** dropping `WorkoutSets`, replacing `WorkoutDrafts`, backfilling
  groups/modalities/muscle weights from display text, or making a later B02
  table optional in backup.
- **Required tests:** real on-disk v15→v16 fixture with legacy session/set,
  scheduled draft, B01 graph, custom/unresolved exercise and health provenance;
  forced rollback; v5/v6/v7 valid and orphan restore; future format rejection.
- **Gate:** **SOL-GATE REQUIRED** before the schema task.

## B02-D03 — Identity, history and substitution

- **Final rule:** Every B02 prescribed/performed exercise write needs an exact
  resolved `Exercises.stableId`, an immutable name snapshot, and source
  prescription ID where applicable. `PerformedExercises` owns actual identity;
  substitution stores both expected and actual identity plus the original
  frozen member slot.
- **History rule:** B02 PR/history/target queries use actual stable exercise
  identity and `loadBasis`. Legacy name-only rows remain a separate fallback
  projection; they are never merged through fuzzy, lowercase, substring or
  technique-stripping matching.
- **Substitution rule:** a replacement uses its own history and mappings. It
  may satisfy a source group slot, but it never mutates the template/snapshot or
  asserts equivalence to the planned exercise.
- **Required tests:** rename-preserves-stable history; duplicate display name;
  custom ID restore; unresolved legacy remains unresolved; substituted group
  member retains expected/actual facts.
- **Gate:** **SOL-GATE REQUIRED** because it changes analytics/PR provenance.

## B02-D04 — Frozen B02 snapshot, draft v2 and completion

- **Final rule:** Keep B01 `WorkoutDrafts` as the one active durable draft.
  Add `activityType` and `executionStateJson`; v2 draft content includes a
  snapshot ID/version, activity route facts, group progress, substitutions,
  target/warm-up recommendations, actual records and active rest period.
- **Compatibility:** v1 codec rows remain readable. They are completed by the
  B01 compatibility path or explicitly discarded/restarted; migration never
  rewrites them. B02 v2 drafts are validated against their frozen snapshot,
  never against current mutable authoring data.
- **Finalization:** a scheduled command inserts the header and all rich detail,
  invokes the B01 occurrence completion transition, writes retry metadata, and
  deletes only the exact linked draft last. Same command/same payload returns
  the saved session; competing/different payload fails. Early finish must pass
  explicit B01 `partial` completion, not pop the route.
- **Required tests:** app kill/resume at group/member/segment/rest positions;
  corrupt v2 draft recovery; full/partial idempotent retries; failure rollback;
  v1 decoder regression.
- **Gate:** **SOL-GATE REQUIRED** before replacing the scheduled bridge.

## B02-D05 — Exercise groups are ordered plan objects

- **Final rule:** `ExerciseGroups` plus `ExerciseGroupMembers` own group type,
  round count, group rest and member order. Group type is exactly `superset`,
  `circuit`, or `giantSet`; all grouping is ID-based.
- **Cardinality:** supersets have exactly two members; circuits have two or
  more; giant sets have three or more. B02 uses one working slot per member per
  round and a shared round count. Uneven member count plans are rejected rather
  than padded with fake records.
- **Editing:** only a draft ProgramVersion may reorder/remove a group member.
  Publishing/start freezes its order. Execution permits substitute, skip and
  partial completion, preserving the source member slot.
- **History:** B02 stores performed-group headers; it does not reconstruct
  groups from completed exercises.
- **Required tests:** constraint matrix; contiguous reorder transaction;
  standalone/group interleaving; partial round; resume; history grouping.

## B02-D06 — Techniques compose; segments preserve actual work

- **Final rule:** Do not expand the legacy `WorkoutSets.setType` string list.
  B02 `StrengthSetPrescriptions` and `PerformedSets` use independent role,
  effort, tempo, pause, assistance, drop and rest-pause fields. “Standard” is
  the absence of optional attributes, not an incompatible technique enum.
- **Tempo:** enabled tempo has eccentric, bottom pause, concentric and lockout
  pause components. All four are present and non-negative; not all may be zero.
  A separate paused-rep position/duration can coexist with tempo.
- **Assistance:** store positive support separately from external load and its
  explicit load basis. Do not calculate net resistance or assisted 1RM.
- **Segments:** a drop/rest-pause set has ordered actual segments. Header reps
  equal segment total. Drop needs a load decrease; rest-pause needs two or more
  segments and positive rest before later clusters. Combinations are valid.
- **Required tests:** every valid composition; invalid partial tempo; negative
  assistance; segment total/order; technique draft/backup/history round trip.
- **Gate:** **SOL-GATE REQUIRED** before rich set tables/codecs are approved.

## B02-D07 — Warm-up rule v1 is deterministic and overridable

- **Final rule:** Use the percentage and rep stages in `PLAN.md`: counts 1–4,
  3-stage default `[40, 60, 80]`, equipment-profile rounding, collapse after
  rounding, and no invented fallback working load.
- **Inputs:** frozen target selection, stable exercise/equipment metadata,
  frozen profile increment, preference, requested count and optional recent
  comparable load. Bodyweight and very-light fallback are explicit states.
- **Storage:** store the offered plan/rule version/completeness in v2 draft
  state and freeze accepted/edited actual warm-ups as performed sets. Do not
  create a mutable warm-up-history authority.
- **Required tests:** all stage counts; increments/collapse; unknown increment;
  bodyweight; per-hand; machine; very-light; malformed target; user edit/skip.

## B02-D08 — Rest respects user selection

- **Final rule:** Context determines applicable configured rest; the explicit
  precedence table in `PLAN.md` is binding. A current user selection always
  wins. Automatic rest is a recommendation only and runs only with no explicit
  configured value.
- **Actual rest:** persist wall-clock start/end, selected/recommended duration,
  source and end reason as `PerformedRestPeriods`. The timer can be skipped or
  extended and cannot block recording.
- **Rule v1:** fallback 90 seconds, RPE 9–10/failure +30, RPE 6–7 −15, AMRAP
  +15, clamped 45–240; missing RPE produces no adjustment. The UI must show
  why and retain a manual override. These constants do not implement B04.
- **Required tests:** each precedence branch, group/rest-pause context,
  background/resume elapsed timing, +30, skip, no-notification fallback.

## B02-D09 — Typed modality, import and provenance rules

- **Final rule:** New activity types are `strength`, `running`, `cycling`,
  `walking`, `yoga` and `mobility`; `legacy` is compatibility-only. Cardio uses
  typed detail/interval tables. Yoga/mobility use their own detail table and
  never distance or strength-set rows.
- **Import:** Health adapters use a reviewed exact provider-type mapping. An
  unknown provider type is not imported as a guessed modality. Duplicate checks
  use provider/external ID where present, otherwise a stable fingerprint; both
  are stored by `HealthProvenances`. Export selects a matching native type and
  does not label every activity strength.
- **Edit:** drafts are mutable; completed manual/imported activities are
  immutable in B02. Source/provenance remains visible in history.
- **Required tests:** required/optional table; duplicate ID/fingerprint;
  unknown type; import/export mapping; provider missing fields; interval order;
  restore provenance.
- **Gate:** **SOL-GATE REQUIRED** before migration/import code because of
  provenance and cross-platform compatibility.

## B02-D10 — Muscle mapping, working sets and coverage

- **Final rule:** `Muscles` and `ExerciseMuscleMappings` are the only source
  for B02 muscle allocation. `Exercises.muscleGroups` remains a legacy display
  field and cannot feed heat-map arithmetic. Seed mappings require reviewed
  source data; user-created/unreviewed exercises are unknown.
- **Metrics:** working set, effective-set completion ratio, drop/rest-pause,
  assistance, groups, partial work and unknown coverage use the definitions in
  `PLAN.md`. Derived analytics are reproducible read models; no stored mutable
  weekly total.
- **Presentation:** unknown mapping and missing target are not zero. Show the
  allocation metric, date range and mapping coverage with every heat map/weekly
  summary. Do not claim physiological precision.
- **Required tests:** reviewed allocation total; unreviewed/custom mapping;
  warm-up exclusion; each advanced technique; partial/no target; timezone range;
  coverage UI.
- **Gate:** **SOL-GATE REQUIRED** before catalogue import and analytics work.

## B02-D11 — Load/repetition target rule v1

- **Final rule:** Use the exact comparator eligibility, one-increment bound,
  rep/RPE outcome, deload, new-exercise, failure, missing-data, override and
  evidence rules in `PLAN.md`.
- **Safety:** recommendation is nullable and non-blocking. Recent seven-day
  working-set workload and missing recovery are evidence/completeness inputs in
  v1 only; missing recovery is unknown. Neither calculates readiness, penalizes
  a user, or alters a recommendation numerically. The engine must never default
  to a generic load.
- **Evidence:** persist algorithm/rule version, confidence, completeness,
  comparator count/cutoff, increment, rationale codes, offered values and user
  override status. Actual values remain separate and immutable.
- **Required tests:** no history; exact stable-ID comparator; load-basis split;
  max-rep/RPE increase; failed/min-rep decrease; bounds; deload; no increment;
  missing sleep; substitution; explanation and override persistence.
- **Gate:** **SOL-GATE REQUIRED** before implementation or user exposure.

## B02-D12 — Bounded migration from legacy repositories

- **Final rule:** Introduce bounded activity, strength execution, draft,
  modality, mapping/volume and target services. Keep the B01 scheduled adapter
  as the temporary sole owner of occurrence transition until the B02 successor
  passes idempotency tests. `WorkoutRepository` can provide legacy projection
  reads only; it may not gain new B02 write responsibilities.
- **Removal rule:** delete name-based player/cardio/rest/cue and old set-type
  behavior only after a typed replacement, legacy projection tests and backup
  v7 coverage exist. Retained legacy tables are removed only in a later batch
  with explicit proof.
- **Required tests:** no new display-name behavior; route compatibility;
  B01 scheduled/unscheduled regression suite; repository ownership lint/review.

## Product-owner decisions required

| ID | Decision needed | Safe provisional behavior |
|---|---|---|
| B02-PD01 | Player presentation and labels for groups, skipped slots and partial completion | Show explicit type/round/member and require an explicit partial-finish confirmation. |
| B02-PD02 | Default warm-up preference and whether “ask” is default for new users | Store no preference until chosen; show a non-blocking recommendation. |
| B02-PD03 | Rest UX: whether per-exercise preference is surfaced in player, exercise setup, or both | Current-session override only; never persist a silent choice. |
| B02-PD04 | Yoga/mobility fields, intensity labels and history vocabulary | Require duration; style/focus/intensity remain optional. |
| B02-PD05 | Muscle heat-map palette, time ranges and unknown-data treatment | Use accessible neutral unknown state and text coverage; no red/green-only encoding. |

## Sol-gate checklist

Sol approval must explicitly record acceptance or amendment of D02, D03, D04,
D06, D09, D10 and D11 before their implementation tasks start. The review must
include: v15/v6 fixture output; schema/backup FK diagram; no-name-inference
proof; target/warm-up/rest boundary tests; muscle allocation source review;
Android/iOS Health mapping limits; scheduled full/partial retry proof; and the
final B02 read/write ownership map.
