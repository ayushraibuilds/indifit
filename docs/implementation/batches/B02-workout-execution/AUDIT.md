# B02 — Workout Execution and Modalities Audit

## Scope and conclusion

This audit covers the B01-complete repository at schema version 15 and backup schema version 6. The B01 execution foundation is usable: scheduled occurrences create an immutable execution snapshot and durable draft, each set is persisted into the draft, scheduled finalization is transactional and idempotent, and partial completion exists in the occurrence state machine. The B02 surface above that foundation is not yet a coherent execution model. The player still receives legacy-shaped `RoutineExercise` objects, most behavior keys off display names, strength rows are the only first-class performed detail, and analytics use session totals rather than modality-aware working-set or muscle data.

The findings below are repository-specific. They identify gaps and decision points; they do not prescribe the final B02 schema.

## Current capability matrix

| Included feature | Classification | Current evidence and boundary |
|---|---|---|
| Automatic load and repetition targets | Partially supported | `ExercisePrescriptions` stores `plannedSets` and free-text `repsRange`; the player pre-fills a midpoint and suggests the latest weight plus a hardcoded 2.5 kg. User edits are recorded, but target, rationale, confidence, equipment rounding and recovery inputs are not represented. |
| Supersets, circuits and giant sets | Blocked by architecture | Execution is a linear exercise/set index. No ordered exercise-group model reaches the snapshot, player, draft codec, summary or final records. |
| Tempo, paused-rep, assisted-rep and rest-pause techniques | Not supported | The set-type allowlist is `working`, `warmup`, `dropset`, `failure`, `amrap`; no tempo, pause, assistance or cluster boundary fields exist. Catalog entries such as “Pause …” are separate names, not typed techniques. |
| Exercise-specific warm-up calculator and ramping sets | Partially supported | `isWarmUp` can be toggled and warm-ups are draft-persisted. There is no calculator, ramp sequence, equipment-increment rounding, or exercise-specific policy. Equipment increments exist in B01 profiles but are not consumed by the player. |
| Custom rest times | Partially supported | A local rest timer exists, but it receives a recommendation only and has no persisted custom value or prescription/user override. Recommendations are name-based 60/90/120 second buckets. |
| Automatic rest based on intensity | Not supported | RPE is an input, but rest is calculated before recording from the exercise display name; no intensity policy, recovery fallback, or explainable recommendation is stored. |
| Cardio intervals, running, cycling and walking | Partially supported | Manual duration/distance/incline fields can be stored on `WorkoutSets`; Health import creates zero-volume `WorkoutSessions` for walking/running only. Cycling, explicit intervals, typed modality detail and cardio history are absent. |
| Yoga and mobility | Not supported | There is no typed activity representation, mobility/yoga prescription, pose/flow completion model, or import path. |
| Muscle-volume heat map | Not supported | Exercises contain comma-separated muscle text, but no normalized reviewed mapping or contribution values. Progress charts aggregate session volume only. |
| Weekly working sets per muscle group | Blocked by architecture | There is no canonical working/effective-set definition across warm-ups, dropsets, AMRAP, clusters or modalities, and no normalized exercise-to-muscle query model. |

## Required flow traces

### Scheduled occurrence to history

`ProgramCalendarScreen` and `OccurrenceActionsSheet` start an occurrence through `WorkoutExecutionCompatibilityAdapter.startScheduledOccurrence`. `CalendarRepository.start` marks the occurrence `inProgress`, freezes a snapshot containing the program/template/prescriptions, and creates a v1 `WorkoutDrafts` row. The router opens `WorkoutPlayerScreen`, whose `WorkoutPlayerController` advances linearly through `RoutineExercise` and set indexes. After every recorded set, `WorkoutDraftCodec` persists the draft, including current weight, reps, RPE, warm-up flag, set type and the current cardio fields.

The summary screen calls `finalizeScheduledWorkoutSession`. The adapter validates the exact occurrence and draft, inserts `WorkoutSessions` and `WorkoutSets`, calls `CalendarRepository.completeWithPersistedSessionInTransaction`, writes completion event metadata, and deletes the draft last. Repeating the same command and payload returns the original session; a different payload is rejected. This is a strong B01 foundation.

The path after finalization is less complete. `WorkoutRepository.getExerciseHistory` and `getPersonalRecord` query exact `WorkoutSets.exerciseName`; `ProgressStatisticsRepository` totals `WorkoutSessions.totalVolume`, and `ProgressScreen` charts those totals. The system therefore retains a valid session but can fragment history after substitution/renaming and cannot derive modality-aware volume. “Finish Workout Early” exits the player without the scheduled partial-finalization path, so the tested partial state machine is not fully exposed in the UI.

### Prescription to suggestion to performance

`ExercisePrescriptions` provides `exerciseId` when available, an `exerciseNameSnapshot`, `plannedSets`, and `repsRange`. The scheduled adapter converts the snapshot to legacy `RoutineExercise` values and creates name-keyed execution contexts. The controller then asks `WorkoutRepository.getLatestSetsForExercise` and `getPersonalRecord` by exact display name. The screen uses the last weight, or a hardcoded default, and the controller applies a hardcoded 2.5 kg progression when the previous reps meet the parsed maximum. Reps default to the range midpoint.

The user can override weight, reps, RPE, set type, duration, distance and incline. The actual values are recorded, but the target that was shown, the reason for the suggestion, the prescription identity, and the user override are not recorded as separate facts. Scheduled finalization can backfill an exercise stable ID only by exact snapshot-name matching; substitution and duplicate names remain unresolved. This is insufficient for explainable automatic targets and stable exercise history.

### Health/cardio source to activity history

`HealthService.importOutdoorActivities` reads native workout values for the prior seven days and accepts only type strings containing `walking` or `running`. `persistOutdoorActivity` creates a `WorkoutSessions` row with title, duration, calories and zero total volume, then links it through `HealthProvenances`. The activity appears in session/history lists and contributes session count, but not strength volume or set history. `writeWorkoutSession` exports every workout as `STRENGTH_TRAINING`, which is not modality-safe. There is no cycling, interval, yoga or mobility mapping and no typed activity detail for progress/history.

## Repository impact

| Path and symbol | Current responsibility | B02 impact | Risk |
|---|---|---|---|
| `lib/data/database/app_database.dart` — `AppDatabase`, `_migrateV14ToV15` | Owns schema v15, B01 tables, stable-ID backfill and legacy import | B02 fields/tables and backup compatibility will require a migration strategy from v15 | High: existing legacy tables and imported data must remain readable and restorable |
| `lib/data/database/tables/workout_tables.dart` — `Exercises`, `WorkoutSessions`, `WorkoutSets`, `WorkoutDrafts` | Stores exercises, sessions, sets and one active draft | Needs modality, target/performed, grouping/technique and provenance decisions | High: current rows conflate strength, imported cardio and draft execution details |
| `lib/data/database/tables/training_program_tables.dart` — `SessionTemplates`, `ExercisePrescriptions`, `ScheduledSessionOccurrences` | Stores immutable B01 program graph and occurrence snapshot/state | Prescription and snapshot contracts must carry B02 execution semantics | High: published program immutability and occurrence idempotency must survive extension |
| `lib/data/repositories/calendar_repository.dart` — `start`, `completeWithPersistedSessionInTransaction` | Owns occurrence lifecycle, snapshots, partial/full completion | Extend snapshot/versioning only after B02 execution contract is agreed | Medium-high: changing snapshot payload can strand drafts and retry commands |
| `lib/data/repositories/workout_execution_compatibility_adapter.dart` — launch/finalize helpers | Bridges B01 snapshots to legacy player and atomically finalizes sessions | Must become the compatibility boundary for typed/grouped execution, substitution and target provenance | High: name-keyed contexts currently lose identity and advanced fields |
| `lib/features/workout_player/workout_player_controller.dart` — `prefillInputs`, `recordSet`, `substituteExercise` | Linear player state, suggestions, set recording, draft save | Needs group-aware state, target/performed distinction, techniques and modality-specific input | High: a linear controller cannot express ordered groups or cluster/rest-pause boundaries |
| `lib/features/workout_player/workout_player_screen.dart` — `_completeSet`, `_getRecommendedRestSeconds` | Validates inputs, detects cardio, starts rest timer and navigates | Replace name checks with typed metadata and expose custom/intensity rest and partial completion | High: false modality detection and fixed rest policy affect recorded behavior |
| `lib/features/workout_player/widgets/exercise_set_input_card.dart` — `_getExerciseFormCue`, set-type/cardio controls | Displays cues and strength/cardio input controls | Move cues/modality/techniques to canonical metadata and compact-screen flows | Medium-high: current controls cannot represent B02 techniques |
| `lib/core/fixtures/workout_draft_codec.dart` — v1 encoder/decoder | Round-trips active draft set fields and five set types | Versioned draft evolution is needed for groups and advanced fields | High: unknown future set types currently reject restoration |
| `lib/data/repositories/workout_repository.dart` — history/PR/latest-set queries | Legacy name-based history and Epley PR calculations; unscheduled save | Migrate reads to stable identity and explicit working-set rules | High: substitution, technique variants and warm-ups contaminate history/PRs |
| `lib/data/repositories/health_service.dart` — import/persist/export | Imports walking/running into sessions and exports as strength | Introduce reviewed modality mapping and preserve provider provenance | High: current type detection is narrow and export is semantically wrong |
| `lib/data/repositories/progress_statistics_repository.dart`, `lib/features/progress/progress_screen.dart` | Session totals, PR counts and volume chart/heatmap | Add modality-aware and muscle-aware read models only after semantics are fixed | High: existing “volume” is not working-set or muscle volume |

## Data impact

| Table/store | Current role | Likely B02 change | Migration concern |
|---|---|---|---|
| `Exercises` | Stable ID, name, comma-separated muscle/equipment text, cues | Canonical modality/technique and reviewed muscle metadata may be needed | Preserve seeded IDs, custom exercises, legacy names and unresolved identity policy |
| `SessionTemplates`, `ExercisePrescriptions` | Published template and planned sets/reps/name snapshot | Carry target/group/modality semantics after Terra/Sol agreement | Published versions are immutable; old snapshots must still launch |
| `WorkoutSessions`, `WorkoutSets` | Strength-like session/set records plus some cardio columns | Separate or extend typed execution details; preserve target/performed and provenance | Do not force imported cardio, yoga or mobility into strength-set semantics |
| `WorkoutDrafts` | One active draft, JSON set payload, occurrence/snapshot linkage | Version group/technique/modality state and restore it safely | Codec v1 and partially written/legacy drafts must remain decodable |
| `ScheduledSessionOccurrences`, `OccurrenceEvents` | Lifecycle, command idempotency, completion disposition | Connect richer completion payloads and partial/group outcomes | Keep unique occurrence/session and retry guarantees |
| `EquipmentProfiles`, `EquipmentItems` | Availability, default/item weight increments and travel context | Consume increments for target/warm-up rounding | Existing profiles lack enough context for arbitrary equipment; fallback must be explicit |
| `HealthProvenances` | Provider/external ID/fingerprint linked to local session | Link typed activity records and import modality details | Preserve duplicate suppression and provider provenance across restore |
| `WorkoutRoutines`, `RoutineDays`, `RoutineExercises` | Legacy editable routine compatibility | Remain read-compatible while B02 moves execution to B01 graph | B01 deliberately retains these tables; no destructive removal is safe yet |
| Backup schema v6 and migration fixtures | B01 graph/session/draft/health backup and v5 import | Cover every new user-owned B02 record and version transition | Need forward/backward policy, FK prevalidation and old-backup fixtures before implementation |

## Test coverage

| Behavior | Existing tests | Missing coverage |
|---|---|---|
| Scheduled start, draft, resume and finalization | `test/execution_bridge_test.dart`, `test/occurrence_state_machine_test.dart` | B02 snapshot fields, grouped resume, technique restoration and modality-specific finalization |
| Full/partial completion and idempotency | `test/execution_bridge_test.dart`, `test/workout_summary_lifecycle_test.dart` | Early-finish UI, partial summary payloads, retry after grouped/cardio completion |
| Draft round trips | `test/workout_draft_codec_test.dart` | New set types, target/performed fields, groups, techniques, substitution provenance and schema upgrades |
| Set recording, RPE, cardio columns and PR | `test/wave3_features_test.dart`, `test/progressive_overload_test.dart` | Target override facts, working/effective filtering, assisted/rest-pause/tempo and stable-ID history |
| Grouped execution and substitution | No dedicated B02 coverage; substitution is UI/controller behavior | Ordered superset/circuit/giant set progression, skip behavior, duplicate names and stable-ID substitution history |
| Rest timers and warm-ups | No dedicated rest-timer or warm-up behavior suite found | Custom rest persistence, intensity policy, timer interruption, deterministic warm-up/ramping and increment rounding |
| Cardio, health import and activity history | `test/health_service_test.dart`, `test/phase5_health_backup_notifications_test.dart` test persistence/provenance, not native modality matrix | Running/cycling/walking intervals, provider mapping, export type, yoga/mobility and typed history |
| Muscle volume and weekly working sets | No coverage | Reviewed mappings, missing-versus-zero, warm-up exclusion, multi-muscle contribution and date/timezone aggregation |
| Migration and backup | `test/b01_schema_v15_migration_test.dart`, `test/db_migration_test.dart`, `test/b01_backup_v6_test.dart`, `test/backup_restore_transaction_test.dart` | B02 version transition, old v5/v6 restore with new/absent fields, rollback and all modality records |

## Name-based logic and hardcoded rules

| File and symbol | Current string-based behavior | Risk | Canonical replacement |
|---|---|---|---|
| `lib/features/workout_player/workout_player_screen.dart` — `_completeSet` | Lowercase `exerciseName.contains(...)` detects run/treadmill/cardio/cycle/walk/swim | False modality classification and no interval/yoga/mobility path | Typed exercise/prescription/activity modality metadata |
| Same file — `_getRecommendedRestSeconds` | Name contains squat/deadlift/bench → 120; curl/tricep/lateral/raise → 60; else 90 | Cannot honor intensity, custom rest or equipment/recovery context | Explicit rest policy input with explainable fallback |
| `lib/features/workout_player/widgets/exercise_set_input_card.dart` — `_getExerciseFormCue` | Name contains bench/press/squat/deadlift/pull/curl/raise terms | Cues can be wrong, duplicated or absent for canonical exercises | Stable exercise ID to catalog cues; user cues remain separate |
| Same widget — cardio field visibility and set-type choices | Name checks decide fields; hardcoded five set-type strings define controls | UI and codec cannot evolve with typed modality/technique | Typed modality and versioned technique/set semantics |
| `lib/data/repositories/workout_repository.dart` — latest/PR/history methods | Exact `WorkoutSets.exerciseName == exerciseName` | Renames, substitutions and technique variants fragment history and PRs | Stable ID plus preserved display-name snapshot; no fuzzy fallback |
| `lib/features/workout_player/workout_player_controller.dart` — `prefillInputs`, `recordSet`, `substituteExercise` | Fetches prior performance and replaces exercises by display name | Suggestion and substitution lose prescription identity | Stable exercise/prescription identity with explicit substitution provenance |
| `lib/data/repositories/workout_execution_compatibility_adapter.dart` — `_withSafeSnapshotExerciseIds` | Exact snapshot-name matching backfills stable IDs; duplicates remain unresolved | A useful safe bridge, but substituted names cannot be linked | Carry canonical identity through execution; retain exact-only legacy fallback |
| `lib/features/exercise_library/exercise_library_screen.dart` — muscle filter | Lowercase `muscleGroups` substring and comma splitting | Text taxonomy cannot support reviewed contribution or heat maps | Normalized exercise-to-muscle mappings with explicit review status |
| `lib/data/repositories/health_service.dart` — `importOutdoorActivities` | Health workout type string contains walking/running; source checks use lowercase contains | Narrow provider mapping and semantic loss at import/export | Provider mapping layer to typed activity modalities |

## Highest-risk findings

1. The target contract is not present. Planned sets/reps are free-text, the suggestion algorithm is hardcoded, and no target-versus-performed or rationale/confidence fact survives the draft or session.
2. Grouped execution and advanced techniques are architectural gaps, not missing widgets. The controller, snapshot, codec, set rows and summary all assume a linear list of ordinary sets.
3. Modality boundaries are unsafe. Imported walking/running is stored as a zero-volume `WorkoutSession`, manual cardio is detected by names, and export labels every workout as strength training. Cycling, intervals, yoga and mobility have no typed path.
4. Muscle analytics cannot be made reliable from the current comma-separated `Exercises.muscleGroups` text. Contribution values, working-set semantics and missing-data behavior are all undecided or absent.
5. Existing PR, history and progression queries are exact-name based even though B01 introduced stable IDs and explicitly forbids fuzzy mapping. Substitution currently changes a name in the player without a durable substitution relationship.
6. Warm-up and rest are UI conveniences, not execution policies. `isWarmUp` exists, but there is no deterministic ramping calculator; rest is local, fixed and not persisted.
7. Partial completion is robust in the repository state machine but incomplete in the player flow. Early finish pops the player and does not visibly finalize a scheduled occurrence as partial.
8. Backup and migration are strong B01 foundations but only cover the current graph. B02 must establish versioning and compatibility before adding user-owned execution/modality records.

## Reusable B01 foundations

Reuse the v15 Drift migration transaction, stable exercise IDs and exact/approved alias policy, immutable program/version/template/prescription graph, occurrence state machine, execution snapshot, draft codec boundary, transactional finalization and command-idempotency events. Also reuse equipment profiles/items and increments, exercise preferences/setup/personal-cue storage, health provenance/fingerprint handling, backup v6 FK validation, v5 import compatibility, and the existing calendar/read-model test harness.

These are foundations, not proof that B02 fields can be appended without design work. In particular, the compatibility adapter should remain the seam between legacy player data and richer execution records; it should not silently infer groups, techniques, muscle contributions or modalities from names.

## Questions for Terra High

- What should the compact player interaction be for ordered supersets, circuits, giant sets, skipped exercises and partial completion?
- Which target presets, override behavior, and visible explanation should users see for load/reps recommendations when recovery data is absent?
- What should the warm-up calculator display, permit editing, and do when equipment increments or a baseline load are unavailable?
- Are custom rest values per prescription, per user, or per session override? How should automatic intensity rest and rest-pause clusters appear in the timer?
- What are the required entry and summary fields for running, cycling, walking intervals, yoga and mobility?
- Should a substituted exercise count toward the original prescription, the replacement, or both in history and analytics?
- What definition of weekly working sets should be user-visible, and how should unknown muscle mappings be shown rather than treated as zero?
- What heat-map palette and compact-screen fallback meet accessibility expectations?

## Questions requiring Sol High

- What is the canonical boundary between strength execution, typed cardio/activity records, and yoga/mobility records while preserving shared history ownership?
- How should prescription identity, stable exercise identity, substitution provenance, target/performed values, groups and technique details flow through snapshot, draft, final session and analytics?
- Which working/effective-set semantics apply to warm-ups, dropsets, failure, AMRAP, assisted reps, rest-pause clusters and multi-muscle exercises?
- What migration and backup versioning policy preserves schema v15, backup v6, old drafts, v5 imports and user-owned health records?
- How should equipment increments and missing equipment context determine deterministic rounding and fallback without silently inventing loads?
- How should stable-ID history, PR, progression and exercise-history queries treat approved aliases, intentionally distinct technique variants, unresolved legacy names and explicit substitutions?
- What draft/snapshot version contract allows grouped execution and retry-safe partial completion without overwriting performed data?
- What provider mapping and idempotency contract is required for walking/running/cycling/interval imports and modality-correct export?

## Recommended prerequisite tasks

1. Run a short Terra/Sol semantic gate for modality boundaries, groups, techniques, target explainability, rest, working/effective sets, substitutions and partial completion.
2. Produce a reviewed B02 metadata inventory for exercise modality, technique flags and normalized muscle mappings. Keep unresolved mappings explicit; do not infer or fuzzy-match them.
3. Define the execution contract from prescription to suggestion, user override, draft, performed record, summary and analytics, including compatibility behavior for legacy rows.
4. Do a v15/backup-v6 migration and restore spike with old drafts, legacy imported routines, unresolved exercises, health provenance and rollback fixtures before implementation.
5. Build modality and analytics read-model spikes for strength, cardio and mobility, with explicit working-set rules and missing-versus-zero behavior.
6. Build a mocked health-import matrix for walking, running, cycling and intervals, including duplicate providers and export semantics.
7. Specify compact-screen player flows for groups, advanced techniques, warm-up/ramping, custom/intensity rest, substitutions and partial completion.
8. Expand the test matrix first: codec/draft, grouped execution, target override, stable-ID history, warm-up/rest, modality import/export, muscle analytics, migration and backup.

## Final verification update — 2026-08-02

B02 implementation now has automated evidence for the previously identified
execution, modality, mapping, target, backup and legacy-ownership risks. The
release-gate record is [VERIFICATION.md](VERIFICATION.md). It records 391 full
suite tests and 92 B02-matrix tests passing, schema v15→v16 and Backup v5/v6/v7
compatibility/rollback evidence, stable-ID and unknown-data behavior, and
successful unsigned Android/iOS release builds.

The audit is **passed for B02 integration**. The requester attests that the
required physical Android Health Connect/iOS HealthKit, offline kill/resume,
compact-device, text-scale, accessibility and Backup v7 checks passed after
retest. Build success was not used as a substitute for those checks. No B04
readiness behavior, inferred modality/muscle mapping, destructive migration,
or release waiver was added during verification. Merge remains limited to
`batch/b02-workout-execution`; `main` and `develop` are not changed.
