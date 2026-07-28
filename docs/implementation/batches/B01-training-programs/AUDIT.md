# B01 — Training Programs and Scheduling: Repository Audit

Status: Completed
Audit Date: 2026-07-29
Base Commit: `056f959`
Target Document: `docs/implementation/batches/B01-training-programs/AUDIT.md`
Scope: Read-only repository audit of training programs, scheduling, and related foundations.

---

## 1. Feature Classification Matrix

| ID | Feature | Classification | Evidence and Repository Gap |
|---|---|---|---|
| 1 | Periodized programs and progression blocks | Not supported | `WorkoutRoutines`, `RoutineDays`, and `RoutineExercises` in `lib/data/database/tables/workout_tables.dart#L61-L84` represent a 1-level flat routine without versions, blocks, weeks, ordinals, or periodization models. |
| 2 | Deload weeks | Not supported | No deload model, week configuration, volume/load multiplier, or deload flag exists anywhere in database tables, repositories, or services. |
| 3 | Program calendar | Blocked by current architecture | `RoutineDays.dayOfWeek` (`lib/data/database/tables/workout_tables.dart#L72`) is a static weekly integer (1=Mon..7=Sun). `RoutineDisplayScreen` (`lib/features/workout_player/routine_display_screen.dart#L21,L40-L57`) computes tabs for the current week dynamically from system time. There is no `ScheduledSessionOccurrence` entity, date-anchored calendar model, or timezone representation. |
| 4 | Workout rescheduling | Blocked by current architecture | Sessions only exist as static weekly day-of-week slots (1-7). Rescheduling an occurrence to another date or day is impossible because workouts are not scheduled occurrence instances with dates, state, or ancestry. |
| 5 | Skip and repeat behavior | Not supported | No skip status, repeat status, occurrence event history, or progression advancement logic exists in `WorkoutRepository` (`lib/data/repositories/workout_repository.dart`) or `WorkoutPlayerController` (`lib/features/workout_player/workout_player_controller.dart`). |
| 6 | Travel-week mode | Not supported | No travel mode preference, temporary profile override, or substitute week generation logic exists in `UserProfiles` (`lib/data/database/tables/user_tables.dart`) or `AiRoutineService` (`lib/data/repositories/ai_routine_service.dart`). |
| 7 | Named gym-equipment profiles | Partially supported | `UserProfiles.equipmentAccess` (`lib/data/database/tables/user_tables.dart#L19`) stores a single string (default `'full_gym'`), and `AiRoutineService.generateRoutine` accepts a single `equipment` string. Multiple named profiles (e.g. Home Gym, Commercial Gym), equipment inventory, available weight increments, and travel overrides are absent. |
| 8 | Exercise notes, setup preferences and personal reminders | Partially supported | `Exercises.formCues` and `commonMistakes` (`lib/data/database/tables/workout_tables.dart#L12-L13`) store static catalog cues, and `WorkoutSets.setNotes` (`lib/data/database/tables/workout_tables.dart#L40`) stores notes per logged set. Machine setup preferences (e.g., seat height, pin position), user custom cues, and exercise reminder records do not exist. |

---

## 2. Technical Findings & Current Repository State

### 2.1 Current Routine, Routine-Day, and Routine-Exercise Models
File: `lib/data/database/tables/workout_tables.dart`
* **`WorkoutRoutines`** (lines 61-67):
  * Fields: `id` (int PK autoIncrement), `name` (text), `goal` (text), `notes` (text nullable), `createdAt` (DateTime).
  * Missing: versioning, immutability flag, active status, author, blocks, progression rules.
* **`RoutineDays`** (lines 69-75):
  * Fields: `id` (int PK autoIncrement), `routineId` (int FK -> `WorkoutRoutines.id`), `dayOfWeek` (int: 1=Mon, 7=Sun), `name` (text), `isRestDay` (bool default false).
  * Scope: Represents a static weekly template tab (1-7), NOT a calendar date or scheduled occurrence instance.
* **`RoutineExercises`** (lines 77-84):
  * Fields: `id` (int PK autoIncrement), `dayId` (int FK -> `RoutineDays.id`), `exerciseName` (text), `sets` (int), `repsRange` (text, e.g. `"8-12"`), `orderIndex` (int).
  * Missing: `exerciseId` (FK to `Exercises.id`), prescriptions (target load, target RPE, rest seconds, tempo, set types), block/week association.

### 2.2 Completed Workout Sessions and Sets
File: `lib/data/database/tables/workout_tables.dart`
* **`WorkoutSessions`** (lines 18-28):
  * Fields: `id` (int PK autoIncrement), `name` (text), `totalVolume` (real in kg), `durationSeconds` (int), `estimatedCalories` (int), `completedAt` (DateTime default currentDateAndTime), `isSynced` (bool default false), `uuid` (text nullable).
  * Scope: Completely detached from routine ancestry. Contains no reference to parent program, routine day, program version, block, week, or scheduled occurrence ID.
* **`WorkoutSets`** (lines 30-48):
  * Fields: `id` (int PK autoIncrement), `sessionId` (int FK -> `WorkoutSessions.id`), `exerciseName` (text), `weight` (real in kg), `reps` (int), `setNumber` (int), `isPr` (bool), `rpe` (int nullable), `isWarmUp` (bool), `setNotes` (text nullable), `uuid` (text nullable), `setType` (text default `'working'`), `durationSeconds` (int nullable), `distanceKm` (real nullable), `inclinePercentage` (real nullable).
  * Missing: `exerciseId` (FK), target vs performed tracking, prescription link, equipment used snapshot.

### 2.3 Active Workout Draft Storage
File: `lib/data/database/tables/workout_tables.dart` & `lib/data/repositories/workout_repository.dart`
* **`WorkoutDrafts`** (lines 86-95):
  * Fields: `id` (int PK autoIncrement), `routineName` (text), `currentExerciseIndex` (int), `currentSetIndex` (int), `elapsedSeconds` (int), `loggedSetsJson` (text - JSON string of completed sets), `updatedAt` (DateTime).
* **Draft Mechanics**:
  * `WorkoutRepository.getActiveDraft()` (`lib/data/repositories/workout_repository.dart#L510-L522`): returns the single most recently updated draft.
  * `WorkoutRepository.saveWorkoutDraft()` (`lib/data/repositories/workout_repository.dart#L524-L528`): deletes all existing draft rows before inserting a new draft (`_db.delete(_db.workoutDrafts).go()`). Only 1 active draft can exist globally.
  * `WorkoutPlayerController.saveDraft()` (`lib/features/workout_player/workout_player_controller.dart#L324-L349`): serializes sets into JSON (`[{'sessionId', 'exerciseName', 'weight', 'reps', 'setNumber', 'isPr'}]`). Note: `rpe`, `setType`, `isWarmUp`, `durationSeconds`, `distanceKm`, and `inclinePercentage` are **not** serialized in `saveDraft()`, resulting in data loss if a draft is resumed.

### 2.4 Name-Based Exercise Relationships
File: `lib/data/database/tables/workout_tables.dart`, `lib/data/repositories/workout_repository.dart`, & `assets/data/exercises.json`
* Neither `RoutineExercises` nor `WorkoutSets` contains an `exerciseId` foreign key referencing `Exercises.id`. Relationships rely strictly on `exerciseName` string matching.
* `WorkoutRepository` queries (`getLatestSetsForExercise`, `getPersonalRecord`, `getExerciseHistory`) execute exact string matching: `tbl.exerciseName.equals(exerciseName)`.
* `assets/data/exercises.json` contains duplicate/technique variants with technique baked into the string name:
  * `"Flat Barbell Bench Press"`
  * `"Flat Barbell Bench Press (Standard)"`
  * `"Pause Flat Barbell Bench Press"`
  * `"Slow Eccentric Flat Barbell Bench Press"`
* Impact: Editing an exercise name or using technique variants breaks history lookups, PR calculations, and progressive overload prefill.

### 2.5 Equipment Fields and Filters
File: `lib/data/database/tables/user_tables.dart` & `lib/data/repositories/ai_routine_service.dart`
* `UserProfiles.equipmentAccess` (`lib/data/database/tables/user_tables.dart#L19`): single text column (default `'full_gym'`).
* `Exercises.equipment` (`lib/data/database/tables/workout_tables.dart#L8`): single text string (`"Barbell"`, `"Dumbbell"`, `"Cable"`, `"Bodyweight"`).
* `AiRoutineService.generateRoutine` (`lib/data/repositories/ai_routine_service.dart#L44-L50,L117-L212`): accepts a single `equipment` string (`'bodyweight'`, `'dumbbells'`, `'full_gym'`) and picks hardcoded preset exercise arrays (`pushEx`, `pullEx`, `legEx`).
* Missing: Named gym profiles, equipment item inventory, available weight increments, and travel overrides.

### 2.6 Existing Schedule and Day-of-Week Behavior
File: `lib/data/database/tables/workout_tables.dart` & `lib/features/workout_player/routine_display_screen.dart`
* `RoutineDays.dayOfWeek` (int 1-7): static template day of the week.
* `RoutineDisplayScreen` (`lib/features/workout_player/routine_display_screen.dart#L21,L40-L57`):
  * Sets `_selectedDayOfWeek` to `DateTime.now().weekday` (1=Mon..7=Sun).
  * Calculates current week bounds (`monday` to `sunday`) in local system time.
  * Queries `WorkoutSessions` in that date range, maps `completedAt.weekday`, and highlights weekday tabs as completed (`_completedDayOfWeeks`).
* Missing: Real calendar dates, scheduled occurrences, timezone handling, skip/repeat state, reschedule ancestry, travel-week mode.

### 2.7 Relevant Riverpod Providers and Controllers
* `databaseProvider` (`lib/core/di/providers.dart#L14-L18`): `Provider<AppDatabase>`.
* `workoutRepositoryProvider` (`lib/data/repositories/workout_repository.dart#L7-L10`): `Provider<WorkoutRepository>`.
* `aiRoutineServiceProvider` (`lib/data/repositories/ai_routine_service.dart#L8-L12`): `Provider<AiRoutineService>`.
* `userProfileProvider` (`lib/core/di/user_profile_provider.dart`): `StateNotifierProvider<UserProfileNotifier, UserProfile?>`.
* `_controllerProvider` (`lib/features/workout_player/workout_player_screen.dart#L42-L57`): `StateNotifierProvider<WorkoutPlayerController, WorkoutPlayerState>`.
* `onboardingCompletedProvider` (`lib/core/router/app_router.dart#L22`): `StateProvider<bool>`.

### 2.8 Screens and Navigation Involved
* `RoutineDisplayScreen` (`lib/features/workout_player/routine_display_screen.dart`): `/workout` route. Shows active routine by weekday tabs (Mon-Sun), lists day exercises, start workout button, resume draft banner.
* `RoutineEditorScreen` (`lib/features/workout_player/routine_editor_screen.dart`): `/routine-editor` route. Manual CRUD editor for routines, day names, adding/removing exercises and sets/reps. Overwrites existing database rows in-place.
* `RoutineWizardScreen` (`lib/features/onboarding/routine_wizard_screen.dart`): `/routine-wizard` route. Multi-step wizard selecting goal, experience, days per week, equipment, and injuries, triggering `AiRoutineService.generateRoutine`.
* `WorkoutPlayerScreen` (`lib/features/workout_player/workout_player_screen.dart`): `/workout-player` route. Active workout execution UI with exercise page view, set counter, timer, set inputs, PR confetti, rest timer sheet, exercise substitution.
* `WorkoutSummaryScreen` (`lib/features/workout_player/workout_summary_screen.dart`): `/workout-summary` route. Displays duration, volume, calories, set breakdown; calls `workoutRepository.logSession(...)` and deletes active draft.
* `ExerciseLibraryScreen` (`lib/features/exercise_library/exercise_library_screen.dart`): exercise browser with details modal (`ExerciseDetailsSheet`) and link to history.
* `ExerciseHistoryScreen` (`lib/features/exercise_library/exercise_history_screen.dart`): displays past sessions and set history for a selected exercise name.
* `ManualLogSheet` (`lib/features/workout_player/widgets/manual_log_sheet.dart`): modal to log a historical workout for a selected date.

### 2.9 Backup and Restore Coverage
File: `lib/core/backup/backup_schema.dart` (Backup Version 5)
* **Included in Backup v5**:
  * `WorkoutRoutines`, `RoutineDays`, `RoutineExercises` (lines 88-90)
  * `WorkoutSessions`, `WorkoutSets` (lines 85-86)
  * `WorkoutDrafts` (line 92)
  * `UserProfiles` (line 72 - single `equipmentAccess` string)
  * `UserSettings` (line 73)
  * `SharedPreferences` keys (lines 100-150)
* **Excluded / Missing for B01**:
  * No tables or fields exist for programs, program versions, blocks, weeks, scheduled occurrences, travel mode state, named equipment profiles, equipment items, exercise setup preferences, personal exercise notes, or personal reminders.
  * Introducing B01 tables requires Backup Schema Version 6 (v6) with full serialization, deserialization, and transactional migration logic in `backup_schema.dart` and `backup_file_adapter.dart`.

### 2.10 Schema Migration Impact
* Current Database Version: Drift v14 (`lib/data/database/app_database.dart#L52`).
* B01 Training Foundation Migration Requirements (Database Schema v15):
  * Introduce programs, versions, blocks, weeks, session templates, scheduled occurrences, occurrence reschedule history, travel mode state, named equipment profiles, equipment profile items, exercise notes, setup preferences, and reminders.
  * Existing schema v14 `WorkoutRoutines`, `RoutineDays`, `RoutineExercises` must be migrated into single-block legacy programs to ensure backward compatibility and prevent user data loss.
  * `WorkoutSessions` and `WorkoutSets` must remain compatible with historical records. Nullable foreign keys or mapping tables will be required to link historical sessions to legacy programs without corrupting past logs.

### 2.11 Reusable Components
* `WorkoutRepository` transaction wrappers (`saveRoutine`, `logSession`) and streams (`watchSessions`).
* `WorkoutPlayerController` timer logic (`_startTimer`, `syncElapsedOnResume`), Epley 1RM PR detection (`getPersonalRecord`), and vibration feedback.
* `ManualLogSheet` (`lib/features/workout_player/widgets/manual_log_sheet.dart`) for historical date selection and session logging.
* `ExerciseDetailsSheet` (`lib/features/exercise_library/exercise_details_sheet.dart`) for viewing form cues and common mistakes.
* `WorkoutDrafts` single-draft persistence mechanics (`getActiveDraft`, `saveWorkoutDraft`, `deleteActiveDraft`).
* `BackupData` DTO structure and atomic transactional restore strategy (`lib/core/backup/backup_schema.dart`).

---

## 3. Main Current Training Flow Trace

```text
Routine creation
→ routine storage
→ workout selection
→ workout execution
→ completed session
→ history and progress
```

1. **Routine creation**:
   * User opens `RoutineWizardScreen` (`lib/features/onboarding/routine_wizard_screen.dart`) or `RoutineEditorScreen` (`lib/features/workout_player/routine_editor_screen.dart`).
   * In wizard: User selects goal, experience, days per week, equipment string, and injuries. Taps "Generate Routine", invoking `AiRoutineService.generateRoutine(...)` (`lib/data/repositories/ai_routine_service.dart#L44`).
   * `AiRoutineService` returns `GeneratedRoutineResult` containing a list of `RoutineDayWithExercises` (`dayName`, `dayOfWeek`, `isRestDay`, `exercises` list of `RoutineExerciseInput`).

2. **Routine storage**:
   * `RoutineWizardScreen` or `RoutineEditorScreen` calls `WorkoutRepository.saveRoutine(...)` (`lib/data/repositories/workout_repository.dart#L74-L150`).
   * Inside a database transaction:
     * Inserts a row into `WorkoutRoutines` (`name`, `goal`, `notes`).
     * Loops through `days`: inserts rows into `RoutineDays` (`routineId`, `dayOfWeek`, `name`, `isRestDay`).
     * For non-rest days: loops through `exercises`: inserts rows into `RoutineExercises` (`dayId`, `exerciseName` [text string], `sets`, `repsRange`, `orderIndex`).

3. **Workout selection**:
   * User navigates to `/workout` (`RoutineDisplayScreen` in `lib/features/workout_player/routine_display_screen.dart`).
   * `_loadActiveRoutine()` (`lines 31-80`) fetches `repo.getSavedRoutines()` (uses `routines.last` as active routine), calls `repo.getRoutineDetails(active.id)` to load days and exercises.
   * Reads system local date: `_selectedDayOfWeek = DateTime.now().weekday` (1=Mon..7=Sun).
   * Displays weekday tabs (Mon..Sun) and exercises for the selected day from `_routineDays`.
   * User taps "Start Workout" button (`lines 268-300`), executing `context.push('/workout-player', extra: {'routineName': ..., 'exercises': ...})`.

4. **Workout execution**:
   * `WorkoutPlayerScreen` (`lib/features/workout_player/workout_player_screen.dart`) initializes `_controllerProvider` with `WorkoutPlayerController` (`lib/features/workout_player/workout_player_controller.dart#L83-L107`).
   * Controller starts 1-second `Timer.periodic` for elapsed time and calls `prefillInputs()` (`lines 136-173`).
   * `prefillInputs()` calls `WorkoutRepository.getLatestSetsForExercise(exerciseName)` and `getPersonalRecord(exerciseName)` to suggest weights based on past sets of matching `exerciseName`.
   * User enters weight, reps, RPE, set type, and taps "Checkmark / Next Set", triggering `recordSet(...)` (`lines 200-245`).
   * `recordSet(...)` appends a `WorkoutSetsCompanion` to `state.loggedSets`, calculates 1RM to trigger PR confetti if new PR, calls `saveDraft()` (`lines 324-349`) to persist `WorkoutDrafts` row with `loggedSetsJson`.
   * User advances through sets and exercises using `advanceSetOrExercise()` (`lines 247-263`).
   * On final set of final exercise, user taps "Finish Workout", navigating to `/workout-summary` (`WorkoutSummaryScreen` in `lib/features/workout_player/workout_summary_screen.dart`).

5. **Completed session**:
   * `WorkoutSummaryScreen` (`lib/features/workout_player/workout_summary_screen.dart`) displays total time, total volume (sum of weight * reps for working sets), estimated calories.
   * User taps "Save Workout" button (`lines 225-240`), calling `WorkoutRepository.logSession(name, volume, durationSeconds, calories, sets)` (`lib/data/repositories/workout_repository.dart#L185-L222`).
   * Inside a database transaction:
     * Inserts row into `WorkoutSessions` (`name`, `totalVolume`, `durationSeconds`, `estimatedCalories`, `uuid`, `completedAt`).
     * Loops through `sets`: updates each set with generated `sessionId` and `uuid`, inserts rows into `WorkoutSets`.
   * Calls `controller.finishWorkout()` (`WorkoutPlayerController.dart#L351-L355`) to delete the active draft row from `WorkoutDrafts`.

6. **History and progress**:
   * User views completed workouts in `ProgressScreen` or `ExerciseHistoryScreen` (`lib/features/exercise_library/exercise_history_screen.dart`).
   * `WorkoutRepository.getExerciseHistory(exerciseName)` (`lib/data/repositories/workout_repository.dart#L474-L507`) queries `WorkoutSets` joined with `WorkoutSessions` where `exerciseName` matches string equality, grouped by `sessionId`.
   * `WorkoutRepository.watchSessions()` (`lines 174-182`) streams all `WorkoutSessions` ordered by `completedAt` desc for progress charts and weekly metrics (`WeeklyReportService` in `lib/data/repositories/weekly_report_service.dart`).

---

## 4. Analytical Tables

### 4.1 Repository Impact Table

| Path and Symbol | Current Responsibility | B01 Impact | Risk |
|---|---|---|---|
| `lib/data/database/tables/workout_tables.dart` (`WorkoutRoutines`, `RoutineDays`, `RoutineExercises`, `WorkoutDrafts`, `WorkoutSessions`, `WorkoutSets`) | Defines database schema for routines, routine days, routine exercises, workout sessions, workout sets, and active workout drafts. | Must introduce program, program version, block, week, session template, exercise prescription, scheduled occurrence, and occurrence event tables; must retain legacy routine tables for migration. | High risk of schema migration failure for existing v14 installs; history detachment if foreign keys are enforced without backfill. |
| `lib/data/database/app_database.dart` (`AppDatabase`, `schemaVersion`, `migration`) | Drift database setup, v14 schema version, transactional migration strategy, asset seeding. | Schema version bump (v14 -> v15), `MigrationStrategy` update to add new B01 tables and execute data migration from legacy `WorkoutRoutines` to single-block programs. | High risk of silent migration failures or data corruption during v14 to v15 upgrade. |
| `lib/data/repositories/workout_repository.dart` (`WorkoutRepository`, `saveRoutine`, `logSession`, `saveWorkoutDraft`, `getActiveDraft`) | Encapsulates CRUD for routines, sessions, sets, body measurements, and active drafts. | Must expand or delegate to program/scheduling repositories to handle versioned programs, blocks, weeks, occurrence rescheduling, skipping, and equipment filtering. | High blast radius across screens that call `WorkoutRepository` directly. |
| `lib/features/workout_player/workout_player_controller.dart` (`WorkoutPlayerController`, `prefillInputs`, `saveDraft`, `recordSet`) | State management for active workout session execution, timer, set prefill, PR detection, draft saving. | Must bind execution to scheduled occurrence instances and frozen session templates instead of flat `RoutineExercise` lists; must serialize all set fields (RPE, `setType`, warmup) in draft persistence. | High risk of draft state loss or mismatch between scheduled prescriptions and performed sets. |
| `lib/features/workout_player/routine_display_screen.dart` (`RoutineDisplayScreen`) | Renders the active routine by weekday tabs (Mon-Sun) and handles starting workouts. | Must be redesigned to display program calendar, scheduled occurrences, block/week indicators, deload markers, travel mode banners, and reschedule/skip actions. | High risk of UI regressions for users with existing flat routines. |
| `lib/features/workout_player/routine_editor_screen.dart` (`RoutineEditorScreen`) | Provides manual CRUD editing for 1-level routines and exercises. | Must support editing program versions, blocks, weeks, session templates, and exercise prescriptions (or creating new immutable versions). | High risk of overwriting active immutable program versions if mutability rules are violated. |
| `lib/data/repositories/ai_routine_service.dart` (`AiRoutineService`, `generateRoutine`, `_generateOfflineFallback`) | Generates routines via online API or offline fallback rule engine based on single equipment string and days per week. | Must generate structured programs with blocks, weeks, deloads, and named equipment profile constraints. | High risk of incompatible structure output with new program models. |
| `lib/core/backup/backup_schema.dart` (`BackupData`, `createFromDatabase`, `restoreToDatabase`) | Backup DTO v5, serialization, deserialization, preference backup. | Version bump to v6, adding program, version, block, week, scheduled occurrence, equipment profile, exercise notes, setup preferences, and reminder tables. | High risk of incomplete backup/restore causing user data loss on restore. |
| `lib/data/database/tables/user_tables.dart` (`UserProfiles`) | Stores user profile including single `equipmentAccess` string. | Expansion or relation to new `EquipmentProfiles` and `EquipmentItems` tables. | Medium risk of deprecating `equipmentAccess` without migration path. |

### 4.2 Data Impact Table

| Existing Table or Store | Current Role | Likely B01 Change | Migration Concern |
|---|---|---|---|
| `WorkoutRoutines` | Stores 1-level routine metadata (`name`, `goal`, `notes`, `createdAt`). | Migrated to or wrapped by `Programs` / `ProgramVersions` / `ProgramBlocks` (single-block legacy program). | Existing routines must remain readable without data loss; active routine selection must be preserved. |
| `RoutineDays` | Stores static day-of-week slots (`routineId`, `dayOfWeek`, `name`, `isRestDay`). | Migrated to `SessionTemplates` and `ProgramWeeks`. | Static `dayOfWeek` (1-7) must be converted into repeatable weekly session templates. |
| `RoutineExercises` | Stores routine exercise prescriptions (`dayId`, `exerciseName`, `sets`, `repsRange`, `orderIndex`). | Migrated to `ExercisePrescriptions`, adding `exerciseId` FK, target weight/RPE/rest. | `exerciseName` matching to `Exercises.id` requires string normalization; legacy un-matched names must not throw or crash. |
| `WorkoutSessions` | Stores completed workout sessions (`totalVolume`, `durationSeconds`, `calories`, `completedAt`, `uuid`). | Added nullable `scheduledOccurrenceId` or `programVersionId` FK/ancestry link. | Historical sessions must remain valid with null program ancestry. |
| `WorkoutSets` | Stores logged set details (`sessionId`, `exerciseName`, `weight`, `reps`, `setNumber`, `isPr`, `rpe`, `isWarmUp`, `setNotes`, `setType`, etc.). | Added nullable `exerciseId` FK or prescription ID link. | Historical sets use string `exerciseName`; must support nullable `exerciseId`. |
| `WorkoutDrafts` | Stores single active workout draft state (`routineName`, `currentExerciseIndex`, `currentSetIndex`, `elapsedSeconds`, `loggedSetsJson`). | Expanded JSON schema to preserve RPE, `setType`, `isWarmUp`, `durationSeconds`, `distanceKm`, `inclinePercentage`, or linked to `scheduledOccurrenceId`. | In-flight drafts during schema upgrade could fail JSON parsing if schema changes without fallback. |
| `UserProfiles` | Stores profile info including single string `equipmentAccess`. | `equipmentAccess` string retained for backward compatibility, while new `EquipmentProfiles` table handles multiple named profiles. | Initial default `EquipmentProfile` ("Default Gym") must be created from legacy `equipmentAccess` string. |
| `SharedPreferences` | Stores settings, streak data, notification flags (`prefRemindWorkout`, etc.). | UI state preferences (e.g. active tab). Note: Durable state such as active program version, selected equipment profile, and travel-week scheduling must be evaluated by Sol High and Terra High for placement in Drift database tables rather than SharedPreferences. | Ensure all user-owned preference keys are registered in `backup_schema.dart` and avoid storing relational or scheduling state in raw key-value preferences. |

### 4.3 Test Coverage Table

| Behavior | Existing Test | Missing Coverage |
|---|---|---|
| Routine creation & storage | `test/backup_schema_test.dart` (round-trip test for `WorkoutRoutines`, `RoutineDays`, `RoutineExercises`); `test/wave3_features_test.dart` (saving/getting routines). | No unit or integration tests for program versions, progression blocks, deload week generation, or version immutability. |
| Workout execution & draft saving | `test/wave3_features_test.dart` (`logSession`, `getLatestSetsForExercise`, `getPersonalRecord`); `test/progressive_overload_test.dart` (1RM math). | No tests for draft serialization of RPE/setType/cardio metrics; no tests for starting workouts from scheduled calendar occurrences; no tests for partial completion or exercise substitution in draft state. |
| Calendar & scheduling semantics | None (0 tests). | Complete lack of test coverage for calendar date calculation, timezone shifts, rescheduling across days, skip-and-advance progression, or travel-week volume reduction. |
| Equipment filtering & profiles | `test/phase3_profile_and_meal_plans_test.dart` (verifies `UserProfiles.equipmentAccess` field persistence). | No tests for multiple named equipment profiles, available weight plate matching, equipment-based exercise catalog filtering, or travel equipment overrides. |
| Exercise notes & setup preferences | None (0 tests). | Complete lack of test coverage for personal exercise notes, machine setup preferences (e.g. seat height), or exercise-specific reminder schedules. |
| Backup & restore (B01 schema) | `test/backup_schema_test.dart` (verifies v5 backup round-trip for v14 tables). | No tests for Backup Version 6 (v6); no tests for exporting/restoring program versions, blocks, scheduled occurrences, or equipment profiles. |
| Schema migration (v14 -> v15) | `test/db_migration_test.dart` (verifies migrations up to v14). | No migration tests for v14 to v15 upgrading legacy flat routines into single-block versioned programs. |

---

## 5. Five Highest-Risk Findings

1. **Name-Based Exercise Identity & Duplicate Catalog Strings**:
   * `RoutineExercises.exerciseName` and `WorkoutSets.exerciseName` use raw string equality rather than a foreign key `exerciseId` to `Exercises.id`.
   * `assets/data/exercises.json` contains duplicate/technique variants ("Flat Barbell Bench Press", "Flat Barbell Bench Press (Standard)", "Pause Flat Barbell Bench Press", "Slow Eccentric Flat Barbell Bench Press").
   * Any variation in spelling, capitalization, technique prefix, or catalog updates breaks exercise history, PR tracking, and progressive overload calculations.

2. **Static Day-of-Week Template Model Blocks Calendar & Rescheduling**:
   * `RoutineDays.dayOfWeek` (integer 1-7) represents a static weekly tab, not a dated occurrence instance.
   * `WorkoutSessions` stores only a `completedAt` timestamp with no reference to program version, block, week, or scheduled occurrence ID.
   * Consequently, true calendar scheduling, date-based rescheduling, skip/repeat progression, and travel-week overrides are fundamentally blocked by the current data model.

3. **Mutable Routine Editing Violates Version Immutability**:
   * `WorkoutRepository.saveRoutine` (`lib/data/repositories/workout_repository.dart#L81-L104`) updates existing `WorkoutRoutines` and deletes/re-creates `RoutineDays` and `RoutineExercises` in place when editing.
   * B01 CHARTER.md mandates: "Activated program versions are immutable. Editing an active program creates a new version." In-place overwriting destroys program history and invalidates historical session ancestry.

4. **Incomplete Active Draft Serialization (Data Loss Risk)**:
   * `WorkoutPlayerController.saveDraft` (`lib/features/workout_player/workout_player_controller.dart#L324-L349`) serializes only basic set fields (`sessionId`, `exerciseName`, `weight`, `reps`, `setNumber`, `isPr`) into `WorkoutDrafts.loggedSetsJson`.
   * RPE (`rpe`), set type (`setType`), warmup flag (`isWarmUp`), duration (`durationSeconds`), distance (`distanceKm`), and incline (`inclinePercentage`) are dropped when saving drafts, causing state corruption if a workout player is restored from a draft.

5. **Single Equipment String Prevents Named Profiles & Inventory**:
   * `UserProfiles.equipmentAccess` (`lib/data/database/tables/user_tables.dart#L19`) is a single text string (`'full_gym'`), and `AiRoutineService.generateRoutine` accepts only a single equipment string.
   * There is no model for multiple named gym profiles (Home, Commercial, Travel), equipment item inventory, available weight increments, or travel overrides.

---

## 6. Questions for Terra High & Sol High

### 6.1 Questions for Terra High
1. How should `RoutineDisplayScreen` transition from the current 7-weekday tab bar (Mon-Sun) to a multi-week calendar view showing blocks, deload weeks, and scheduled occurrences?
2. What UI controls should be provided for workout rescheduling (e.g., drag-and-drop on calendar vs modal date picker) and travel-week mode activation?
3. How should exercise-specific setup preferences (e.g., seat height, pin location) and personal notes be exposed during active workout player execution?

### 6.2 Questions for Sol High
1. How should legacy 1-level `WorkoutRoutines` / `RoutineDays` / `RoutineExercises` be migrated to `Programs` / `ProgramVersions` / `ProgramBlocks` / `ProgramWeeks` / `SessionTemplates` in database schema v15 (B01 migration) without breaking existing historical sessions?
2. Should durable state such as active program version, selected equipment profile, and travel scheduling mode be persisted as relational database tables in Drift (or setting entries in `UserSettings`) rather than key-value preferences in `SharedPreferences`?
3. What is the precise schema for `ScheduledSessionOccurrence` to track local calendar date, IANA timezone, reschedule ancestry, travel overrides, and execution status?
4. How will Backup Version 6 (v6) maintain backward compatibility when restoring backups from v5 format containing legacy routines?
