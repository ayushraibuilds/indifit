# B02 — Workout Execution and Modalities

Status: Chartered  
Base commit: `9eb7fb6b637cf0cc2aa703056f1e30885c6fd593`  
Base branch: `main`  
Current database schema: `v15`  
Current backup format: `v6`  
Platforms: Android and iOS

## Goal

Expand IndiFit’s workout-execution system to support advanced strength techniques, structured warm-ups and rest, multiple activity modalities, muscle-volume analytics and explainable load/repetition targets.

The batch must build on B01’s canonical exercise identities, programs, session templates and scheduled occurrences.

## Included features

1. Automatic load and repetition targets
2. Supersets, circuits and giant sets
3. Tempo, paused-rep, assisted-rep and rest-pause techniques
4. Exercise-specific warm-up calculator and ramping sets
5. Custom rest time by exercise or prescription
6. Automatic rest recommendations based on set intensity
7. Cardio intervals, running, cycling and walking sessions
8. Yoga and mobility sessions
9. Muscle-volume heat map
10. Weekly working sets per muscle group

## Required foundations

- B01 program, scheduling and occurrence architecture
- Portable canonical exercise identities
- Canonical performed-session ancestry
- Normalized exercise-to-muscle mappings
- Typed strength, cardio and mobility activity records
- Target-versus-performed set representation
- Explicit working-set and effective-set definitions
- Backup and migration coverage for every new user-owned record

## Excluded from B02

- Full recovery/readiness score
- Adaptive calorie targets
- Daily briefing
- Weekly coaching recommendations
- Nutrition features
- Program-generation redesign
- Visual design-system migration
- Exercise animations and education
- Medical or injury recommendations

B02 may define a typed optional recovery-input contract for load targeting, but it must not implement the full readiness engine planned for B04.

## Binding principles

- Existing workout history remains valid.
- Existing B01 scheduled-occurrence behavior remains valid.
- No exercise behavior may depend on display-name substring checks when canonical metadata is available.
- Warm-up sets do not count as working-set volume.
- Missing recovery data is unknown, not zero.
- Automatic targets are recommendations and can be overridden.
- Every recommendation must explain its main inputs.
- Strength, cardio and mobility share common activity-history ownership while retaining modality-specific details.
- Actual performed data must never be overwritten by later prescription changes.
- Local and offline workout execution must continue working.
- Every new user-owned table participates in backup and restore.

## Preliminary domain rules

These rules require confirmation during the Sol architecture gate:

- A superset, circuit or giant set is an ordered exercise group, not an exercise-name convention.
- Tempo is represented using explicit eccentric, pause, concentric and lockout components.
- Rest-pause work preserves actual repetitions and cluster boundaries.
- Assisted repetitions store assistance separately from external resistance.
- Cardio intervals store work and recovery segments explicitly.
- Muscle volume uses normalized exercise-muscle mappings.
- Warm-up recommendations round to equipment-supported increments.
- Load/repetition targets must have confidence, rationale and fallback behavior.

## Batch exit criteria

- Existing strength workouts remain usable.
- Grouped exercises execute reliably and resume from drafts.
- Advanced set techniques survive draft, completion, history, backup and restore.
- Warm-up recommendations are deterministic, equipment-aware and overridable.
- Custom and automatic rest recommendations work without blocking manual control.
- Running, cycling, walking, intervals, yoga and mobility have typed session records.
- Muscle-volume calculations use reviewed canonical mappings.
- Heat maps and weekly muscle-set summaries distinguish missing data from zero.
- Automatic load/repetition targets are bounded, explainable and safely handle missing recovery data.
- Schema migration succeeds from the completed B01 baseline.
- Previous backups remain importable according to the approved compatibility policy.
- Full tests, analysis and supported release builds pass.
- Final Sol High verification passes.

## Non-goals

- Do not build the B04 readiness score.
- Do not make automatic targets mandatory.
- Do not create medical advice.
- Do not count every advanced technique as one identical working set without an approved rule.
- Do not redesign the entire workout player in one task.
- Do not remove compatibility fields until migration and backup behavior are proven.
