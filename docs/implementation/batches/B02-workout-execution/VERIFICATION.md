# B02 Critical Architecture and Implementation-Readiness Gate

Baseline reviewed: `ffbe87f`

Review date: 2026-08-01

Repository baseline: schema v15 / Backup v6 / B01 verified

## Gate verdict

**Passed.**

B02 may begin only with B02-01. The architecture and product defaults are safe as amended by
`DECISIONS.md`; the unamended Terra proposal is not implementation-ready.
Schema v16, codec v2, and Backup v7 are mandatory sequential foundations, and
Backup v7 must exist before any B02 feature repository writes durable data.

No application feature was implemented during this gate. The existing B01
transactional finalization remains authoritative and must be extended, not
replaced. All product defaults are now fixed; only normal task prerequisites
and Sol review gates remain.

## Evidence inspected

- Canonical roadmap, master tracker, B01 accepted decisions and final
  verification, B02 charter/audit/plan/tasks/decisions.
- `app_database.dart`, workout/training/health tables, v14→v15 migration and
  fixture rollback tests.
- `WorkoutExecutionCompatibilityAdapter`, `CalendarRepository` occurrence
  completion, draft codec/controller/summary lifecycle and idempotency tests.
- Backup v6 schema, FK prevalidation/transactional restore, v5/v6 fixtures.
- `HealthService`, health provenance table and duplicate-import tests.
- Legacy history/PR/progression repositories and their name-based tests.

Source evidence confirms: B01 scheduled completion already inserts the session
and sets, conditionally completes the occurrence, writes the command event, and
deletes the exact draft last in one transaction; retry payload comparison and
unique occurrence ancestry prevent duplicate completion. Health provenance
currently uses globally unique external/fingerprint strings and imported
activities are legacy zero-volume sessions; those paths are compatibility
evidence, not an adequate B02 typed/dedup contract.

## Gate inventory

### Items marked `SOL-GATE REQUIRED` at the planning baseline

| Location | Gate |
|---|---|
| `DECISIONS.md` | B02-D02 schema/backup compatibility; D03 identity; D04 draft/finalization; D06 techniques; D09 modalities/import; D10 mappings/metrics; D11 targets |
| `PLAN.md` | Target rule constants, deload factor, comparator safety |
| `TASKS.md` | B02-01 contracts; B02-02 migration; B02-05 finalization cutover; B02-08 targets; B02-09 modality/provenance; B02-11 volume; B02-13 backup; B02-15 final release |

The amended backlog preserves these gates, splits health provenance from manual
modality execution, and adds mandatory Sol review to codec v2, rich technique
serialization, pure warm-up/rest boundaries, timer persistence, and manual
modality finalization.

### Proposed schema inventory

Baseline extensions were `WorkoutSessions.activityType/activitySchemaVersion`,
`SessionTemplates.activityType/defaultRestSeconds`,
`WorkoutDrafts.activityType/executionStateJson`, and warm-up/rest fields on
`ExerciseUserPreferences`.

Baseline new tables were `ExerciseGroups`, `ExerciseGroupMembers`,
`StrengthSetPrescriptions`, `CardioSessionDetails`, `CardioIntervals`,
`MobilitySessionDetails`, `PerformedExerciseGroups`, `PerformedExercises`,
`ExerciseTargetRecommendations`, `PerformedSets`, `PerformedSetSegments`,
`PerformedRestPeriods`, `Muscles`, and `ExerciseMuscleMappings`.

The gate requires these amendments before v16 is frozen:

- `StrengthSessionDetails` as the canonical strength discriminator.
- Common start/end/origin fields; existing non-null session total/calorie/name
  fields remain legacy compatibility and cannot supply typed analytics.
- Durable cardio and mobility session prescriptions plus interval
  prescriptions; scheduled modality planning cannot live only in snapshot JSON.
- Typed tempo components, isometric duration, load/repetition/side basis, and
  prescribed-versus-actual technique facts.
- Append-only mapping versions and review/provenance/confidence fields.
- Provider-scoped ID/dedup keys, payload/update/deletion metadata, while
  retaining old health provenance columns for compatibility.
- Indexes for activity/time, performed stable identity/role, parent/ordinal,
  mapping version/status, and provider deduplication.

### Proposed backup-format inventory

Backup v7 is a format increment from v6. It must include every v16 extension,
all modality prescriptions/details, groups/members, strength prescriptions and
performed graph, technique segments, rest selected/actual facts, target evidence
and overrides, intervals, user preferences/custom rest, versioned mappings when
user-owned, v2 drafts, and health dedup/provenance metadata. Derived heat-map or
weekly aggregates are excluded because they are reproducible read models.

V5/v6 remain importable; unknown/future values and orphan graphs fail before
mutation; restore preserves stable custom exercise IDs, never fuzzy-merges an
exercise or invents a mapping, and retains the existing DB transaction plus
preference compensation. B02-13 was moved before all durable writers.

### High/critical and Sol-routed task inventory

Every task except B02-12 is high or critical. Critical tasks are B02-01,
B02-02, B02-05, B02-07B, B02-08, B02-09B, B02-11, B02-13, and B02-15. High
tasks are B02-03, B02-04, B02-06, B02-07A, B02-09A, B02-10, and B02-14.
B02-12 is medium display correctness and must not calculate domain metrics.

Sol High is the implementation owner for B02-01, B02-02, B02-05, B02-08,
B02-09B, B02-11, B02-13, and B02-15. Sol directly reviews B02-03, B02-06,
B02-07A, B02-07B, and B02-09A. B02-05 was corrected from Terra to Sol because
it owns the occurrence/session/draft atomicity seam.

### Algorithmic and historical-impact inventory

Algorithmic decisions are group traversal/partial status, technique validation,
warm-up stages and equipment rounding, rest selection/elapsed timing, interval
repeat expansion, provider deduplication, mapping allocation, volume metrics,
and target comparison/bounds/confidence. All are now deterministic, versioned,
or explicitly deferred.

Existing workout history is affected by activity-header classification,
legacy/canonical union reads, stable-ID history, substitution, PR filtering,
technique/volume semantics, mapping-version selection, health provenance, and
backup restore. Existing rows remain immutable and are never reinterpreted from
names or backfilled into rich performed records.

B01 occurrence finalization is affected by snapshot v2, draft v2, modality
detail writes, rich child writes, payload digest, partial completion, and draft
deletion. `CalendarRepository` remains the only occurrence transition owner and
the whole durable graph stays in the B01 transaction.

Health imports are affected by activity type/detail pairing, exact provider
enum translation, provider-scoped IDs, fallback fingerprints, manual-collision
handling, immutable provider updates/deletions, partial permissions, export
modality, restore, and restart idempotency.

### Critical decisions Terra failed to gate separately

1. Strength had no 1:1 detail discriminator and legacy non-null `totalVolume`
   would continue making “unknown” look like zero.
2. Scheduled cardio/mobility had no durable prescription tables.
3. Unilateral/isometric execution and tagged tempo unknown/user-paced values
   were absent.
4. Backup v7 was scheduled after feature writers rather than before them.
5. Health uniqueness was not provider-scoped and provider update/delete/manual
   collision behavior was unspecified.
6. Mapping uniqueness could not retain multiple mapping versions.
7. Prescription completion ratio was mislabeled as an effective-set metric.
8. Warm-up rounding lacked bar/minimum usable load.
9. B02-05 left the critical finalization cutover to Terra rather than Sol.
10. B02-03, B02-07, and B02-09 combined unrelated stateful work into overly
    broad Luna/Terra tasks.

## Blocking findings and resolutions

| Finding at baseline | Resolution | Remaining block |
|---|---|---|
| Modality detail graph was not enforceably exclusive. | D01 adds one matching 1:1 strength/cardio/mobility detail and origin/start/end facts. | Schema implementation and constraint proof in B02-02. |
| v16 omitted planned cardio/mobility, isometric/unilateral, and health dedup facts. | D02/D06/D09/D15 add the missing contract. | Sol migration review. |
| Backup was end-loaded. | D13 and task order move v7 before all feature writers. | B02-13 must pass before B02-04/05/06/07B/09A writers. |
| Group partial/out-of-order semantics were ambiguous. | D05 defines slot statuses, action order, round mapping, and MVP exclusions. | None after fixtures. |
| Technique composition allowed underspecified tempo/contradictions. | D06 defines a hybrid model, tags, bounds, bases, and invalid matrix; PD02 accepts composition within that matrix. | None after fixtures. |
| “Effective set” was a completion ratio. | D14 renames it and defers biological stimulus estimation. | Effective-set feature deferred to B04. |
| Health ID/update/delete/manual collision behavior was incomplete. | D15 defines exact provider ID, fallback hash, immutable correction state, and collision suppression. | Platform mapping fixtures in B02-01/09B. |
| Target plan approached B04 recovery adaptation. | D11 limits B02 to stable-ID deterministic progression; recovery is evidence only; PD06 accepts ask/opt-in. | None after fixtures. |

There is no unresolved architecture or product-decision blocker after these
amendments. Normal task prerequisites and Sol review gates still apply.

## Product-owner defaults automatically accepted, plus any exceptional decisions that still require explicit confirmation

All eight recommended defaults are **Accepted** in `DECISIONS.md`; no further
confirmation is required. Exceptional decisions requiring explicit confirmation:
**None**. The rejected alternatives were: standard PR treatment
for assisted work (would mislabel assistance), single-technique-only editing
(would discard valid combinations), idle-time rest capture (would invent
performed evidence), distance interval authoring in B02 (unnecessary MVP scope),
movement-level yoga/mobility (another execution graph), enabled-by-default
targets (silent prescription changes), user-created muscle weights (unreviewed
anatomical claims), and automatic/off warm-ups (respectively unsafe or removes
the review affordance). Their user-visible and schema consequences are recorded
with each accepted decision.

## Task-backlog classification

| Task | Classification | Reason / prerequisite or block |
|---|---|---|
| B02-01 | **Safe to start immediately** | Contracts are accepted; fixture/manifest work is read-only to production data. |
| B02-02 | **Safe after prerequisite tasks** | Requires accepted B02-01 fixtures; Sol migration owner. |
| B02-03 | **Safe after prerequisite tasks** | Requires frozen v16; bounded pure DTO/codec work with Sol review. |
| B02-13 | **Safe after prerequisite tasks** | Requires v16 and codec; must pass before durable writers. |
| B02-04 | **Safe after prerequisite tasks** | Requires codec and Backup v7; group contract is accepted. |
| B02-05 | **Safe after prerequisite tasks** | Requires groups/backup; Sol owns finalization cutover. |
| B02-06 | **Safe after prerequisite tasks** | D06 and accepted PD02 define the editor combination matrix. |
| B02-07A | **Safe after prerequisite tasks** | Pure accepted algorithm after fixtures/DTOs. |
| B02-07B | **Safe after prerequisite tasks** | Accepted PD03 defines when actual rest is persisted. |
| B02-08 | **Safe after prerequisite tasks** | Engine/evidence and ask/opt-in default are accepted. |
| B02-09A | **Safe after prerequisite tasks** | Accepted PD04/PD05 fix time-based intervals and session-level yoga/mobility. |
| B02-09B | **Safe after prerequisite tasks** | Requires typed modality owner and backup; Sol provenance task. |
| B02-10 | **Safe after prerequisite tasks** | All eight product defaults are accepted and testable. |
| B02-11 | **Safe after prerequisite tasks** | Requires Sol-approved manifest and rich performed records; PD07 excludes user mappings. |
| B02-12 | **Safe after prerequisite tasks** | Assisted PR and session-level modality presentation are accepted; heat map still requires B02-11. |
| B02-14 | **Safe after prerequisite tasks** | Only after typed UI/history and regression coverage. |
| B02-15 | **Safe after prerequisite tasks** | Final gate after every task and product decision. |

No task remains “blocked by architecture” after D01–D15. Before this review,
B02-02, B02-05, B02-09, B02-11, and B02-13 were architecture-blocked by the
findings above.

## First implementation tasks and exact order

The first four tasks are strictly sequential:

1. **B02-01 — contract fixtures and reviewed manifests**

   Implementation model: Sol High. Inventory-only assistance may use Luna, but
   Sol owns anatomical weights, provider mappings, expected outcomes, and sign-off.
2. **B02-02 — schema v16 and migration harness**

   Implementation model: Sol High. Review: independent Sol High schema diff,
   on-disk upgrade, rollback, FK/index and performance evidence.
3. **B02-03 — pure values, validators, and codec v2**

   Implementation model: GPT Luna. Review: Sol High for v0/v1 compatibility,
   future-version failure, snapshot binding, and lossless technique/modality data.
4. **B02-13 — Backup v7 foundation**

   Implementation model: Sol High. Review: independent Sol High restore-order,
   zero-mutation failure, v5/v6 import and v7 round-trip proof.

After those four, the exact dependency order is:

`(B02-04 || B02-06 data layer || B02-07A || B02-09A after product scope)` →
`(B02-05 after 04 || B02-07B after 07A/PD03 || B02-09B after 09A)` →
`(B02-08 after 05/07A || B02-11 after 05/06)` → `B02-10` → `B02-12` →
`B02-14` → `B02-15`.

## Required integration-review points

| Point | Required review |
|---|---|
| B02-01 contract fixtures | Sol accepts every D01–D15 expected outcome, manifest source and unknown case. |
| B02-02 schema | Sol reviews full schema/FK/index diff, transactional upgrade and rollback fixture. |
| B02-03 codec | Sol reviews snapshot binding, v0/v1 compatibility, unknown enum and lossless round trip. |
| B02-13 backup | Sol reviews one owner, v5/v6 compatibility, full v7 graph order and zero-mutation failures. |
| B02-05 finalization | Sol verifies one transaction, payload digest, duplicate command, partial and draft-delete-last. |
| B02-07B rest | Sol verifies wall-clock/draft state and no timer/post-commit data window. |
| B02-09A/09B modalities/health | Sol reviews detail exclusivity, provider enum matrix, dedup, manual collision and export. |
| B02-08 target engine | Sol reviews every comparator/bound/fallback/missing-data fixture and B04 exclusion. |
| B02-11 volume | Sol reviews mapping provenance/version and the full metric truth table before any heat-map UI. |
| B02-14 compatibility | Terra integration plus Sol sign-off on all legacy name/set-type paths and B01 suite. |
| B02-15 final | Sol release gate including migration, backup, platform health, offline resume, accessibility and builds. |

## B04 deferrals

- Recovery/readiness scoring and sleep/workload-driven numeric adaptation.
- Calibrated coaching confidence, trend-based progression, and automatic
  substitution/equivalence.
- Physiological effective-set/stimulus estimates.
- Provider correction/reconciliation after changed/deleted external records.

## Sign-off condition

This is a planning-contract pass, not permission to skip implementation gates.
B02 is safe to begin at B02-01. Any implementation that follows the unamended
`PLAN.md`, enables a durable writer before B02-13, or changes the B01
finalization authority reopens the architecture gate and blocks the batch.
