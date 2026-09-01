# C0B Drift Schema v20 Contract

- Status: Frozen baseline
- Date: 2026-09-01
- Characterization: `test/c0b_schema_v20_contract_test.dart`
- Schema version: 20
- Normalized SQLite DDL SHA-256:
  `34193f1c6686140daef89e9722b6493fe5f32589b704b7437dc819ffca78b0c3`

## Frozen SQLite boundary

A fresh production-equivalent database contains:

| Object | Count | Contract coverage |
|---|---:|---|
| Application tables | 88 | Names and complete `CREATE TABLE` SQL, including columns, types, nullability, defaults, primary/unique keys, checks, and foreign keys |
| Named indexes | 85 | Names, owners, uniqueness, columns, ordering, and any predicates through complete `CREATE INDEX` SQL |
| Triggers | 73 | Names, owners, timing/events, guards, and actions through complete `CREATE TRIGGER` SQL |

`PRAGMA user_version` is 20 and `PRAGMA foreign_keys` is enabled. SQLite-owned
`sqlite_*` objects are excluded. The contract test sorts every remaining
`sqlite_master` object, normalizes insignificant whitespace, and hashes the
complete result. A count or DDL change therefore requires explicit review;
generated Drift files remain untouched.

## Table inventory

### Core profile, legacy logging, and local evidence

`user_profiles`, `user_settings`, `body_measurements`, `daily_hydrations`,
`health_provenances`, `achievement_unlocks`, `food_items`, `food_logs`,
`meal_templates`, `meal_template_items`, `workout_routines`, `routine_days`,
`routine_exercises`, `workout_sessions`, `workout_sets`, `workout_drafts`, and
`exercises`.

### Plans, equipment, scheduling, and execution

`programs`, `program_versions`, `program_blocks`, `program_weeks`,
`session_templates`, `exercise_prescriptions`, `scheduled_session_occurrences`,
`occurrence_events`, `training_plan_settings`, `legacy_routine_program_mappings`,
`travel_contexts`, `travel_context_occurrences`, `equipment_profiles`,
`equipment_profile_items`, `exercise_user_preferences`, `exercise_setup_values`,
`exercise_personal_cues`, `exercise_groups`, `exercise_group_members`,
`strength_set_prescriptions`, `cardio_session_details`, `cardio_intervals`,
`mobility_session_details`, `performed_exercise_groups`, `performed_exercises`,
`exercise_target_recommendations`, `performed_sets`, `performed_set_segments`,
`performed_rest_periods`, `muscles`, and `exercise_muscle_mappings`.

### Canonical nutrition and consumption evidence

`nutrition_foods`, `nutrition_food_aliases`, `nutrition_food_preparations`,
`nutrition_legacy_food_mappings`, `nutrition_nutrient_definitions`,
`nutrition_food_nutrient_facts`, `nutrition_household_measures`,
`nutrition_quantity_conversions`, `nutrition_personal_vessels`,
`nutrition_vessel_calibrations`, `nutrition_recipes`,
`nutrition_recipe_versions`, `nutrition_recipe_ingredients`,
`nutrition_user_corrections`, `nutrition_estimates`,
`nutrition_estimate_nutrients`, `nutrition_thalis`, `nutrition_thali_items`,
`nutrition_consumption_snapshots`, `nutrition_snapshot_items`,
`nutrition_snapshot_nutrients`, `nutrition_food_constraint_evidence`,
`nutrition_constraint_definitions`, `nutrition_user_constraints`,
`nutrition_snapshot_constraint_results`, and
`nutrition_snapshot_constraint_result_evidence`.

### Targets, consent, coaching, and recovery

`nutrition_goal_versions`, `coaching_consent_events`,
`nutrition_coaching_preferences`, `recovery_observations`,
`readiness_snapshots`, `readiness_snapshot_evidence`, `recommendations`,
`recommendation_evidence`, `coaching_eligibility_evaluations`, and
`recommendation_feedback`.

### B05 local personalization and content state

`dashboard_module_preferences`, `education_content_progress`,
`media_pack_preferences`, and `workout_playlist_preferences`.

## Index and trigger ownership

The 85 named indexes comprise:

- 19 B01 planning/equipment/occurrence indexes plus the unique stable-exercise
  ID index;
- 21 B02 typed-execution and performed-evidence indexes;
- 26 B03 nutrition identity, recipe, consumption, constraint, and vessel
  indexes;
- 14 B04 goal/coaching/recovery indexes;
- four B05 dashboard/content/media/playlist indexes.

The 73 triggers comprise:

- one stable-exercise-ID assignment trigger;
- eight typed B02 activity/execution validation triggers;
- 36 B03 nutrition ownership, state, registry-unit, recipe/thali, snapshot,
  conversion, and vessel-lineage triggers;
- 28 B04 append-only and ownership triggers.

The normalized DDL digest is the exact index/constraint/trigger inventory.
Changing a name, indexed column, uniqueness rule, check, foreign key, trigger
guard, or trigger action changes the digest even when object counts remain the
same.

## Migration evidence

| Boundary | Primary regression evidence | Preserved contract |
|---|---|---|
| v14 → v15 | `test/b01_schema_v15_migration_test.dart`, `test/db_migration_test.dart` | B01 plan graph, stable exercise IDs, indexes/triggers, rollback |
| v15 → v16 | `test/b02_schema_v16_migration_test.dart` | typed execution graph, compatibility backfill, constraints, rollback/retry |
| v16 → v17 | `test/b03_schema_v17_migration_test.dart` | nutrition identity/evidence graph, seed contracts, staged rollback/retry |
| v17 → v18 | `test/b04_schema_v18_migration_test.dart` | goal/coaching/recovery graph, append-only ownership contracts |
| v18 → v19 | `test/b05_schema_v19_migration_test.dart` | B05 tables/indexes, old-row preservation, rollback/retry |
| v19 → v20 | `test/c0b_schema_v20_contract_test.dart` | real v19 file, preserved singleton settings row, exactly four nullable end-marker columns |

The v19→v20 characterization rebuilds a genuine v19
`training_plan_settings` shape on disk, labels it with `user_version = 19`,
opens it through the production migrator, and proves:

- the version advances to 20;
- the existing row and timestamp survive unchanged;
- `last_ended_program_version_id`, `last_ended_outcome`,
  `last_ended_at_utc`, and `last_ended_command_id` are added;
- all four new fields remain null rather than fabricating lifecycle history.

## C0B boundary

This slice adds no tables, columns, indexes, triggers, seed changes, or schema
version change. It only freezes the existing boundary. Extracting migration,
index, seeding, or connection helpers later must preserve this digest and the
migration results above.

## Verification

- `flutter test test/c0b_schema_v20_contract_test.dart --reporter expanded` —
  2/2 passed.
