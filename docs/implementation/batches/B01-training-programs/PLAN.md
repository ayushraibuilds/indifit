# B01 — Training Programs and Scheduling: Implementation Architecture

Status: implementation-ready proposal; no code is changed by this document.

## 1. Executive architecture summary

B01 adds a small, offline-first planning layer beside—not in place of—the
legacy routine and history layer. A **Program** owns immutable
**ProgramVersions**. A version contains ordered blocks, ordered weeks,
session templates, and exercise prescriptions. Activation materializes dated
**ScheduledSessionOccurrences**. Occurrences are the only things rendered on
the calendar or rescheduled. Starting an occurrence freezes an execution
snapshot; finishing it writes the existing `WorkoutSessions` and
`WorkoutSets` history records with nullable new ancestry columns.

The v15 migration retains the v14 routine tables and copies each legacy
routine into a one-block, one-week ProgramVersion. Legacy screens continue
through a compatibility adapter until their B01 replacements are complete.
Historical sessions are deliberately not guessed into programs. New profiles,
travel contexts, program settings, and exercise preferences are Drift data and
therefore Backup v6 data. Riverpod owns only transient screen state and
derived read models.

This is deliberately not the roadmap’s later complete activity/execution
redesign: B01 does not add adaptive progression, automatic loads, advanced set
groups, cardio redesign, substitution recommendations, or volume analytics.

## 2. Final domain model and data categories

| Concept | Meaning and minimum B01 fields | Category / owner |
|---|---|---|
| Program | Stable user-facing container: `id`, name, goal, notes, created/archived timestamps. It has many versions. | Durable template data / Drift |
| Program version | A numbered release of one program: lifecycle (`draft`, `active`, `retired`, `archived`), source version, creation metadata. Its child rows are immutable once active. | Durable template data / Drift |
| Program block | Ordered phase within a version: ordinal, name, optional description. | Durable template data / Drift |
| Program week | Ordered week within a block and globally within the version: block/week ordinals and `isDeload`. A deload is a declarative flag and label only in B01; it does not calculate loads/volume. | Durable template data / Drift |
| Session template | One planned session in a program week: name, ordinal, planned weekday (1–7), optional local start-time minutes. Rest days are derived from no template, not records. | Durable template data / Drift |
| Exercise prescription | Ordered exercise in a session template: canonical exercise FK when resolved, immutable name snapshot, planned sets and reps text. No automatic load/RPE/rest engine is introduced. | Durable template data / Drift |
| Scheduled session occurrence | Materialized instance for a template/week with planning ordinal, original/effective local date, IANA zone, current status, and execution linkage. | Durable scheduled planning data / Drift |
| Occurrence status/event | Current state resides on occurrence; append-only `OccurrenceEvents` retain transition, previous/current date, reason, and actor timestamp. | Durable scheduled planning/history / Drift |
| Reschedule ancestry | An occurrence retains original date; every move is an `OccurrenceEvent`. A reschedule does not make a new occurrence. | Durable history / Drift |
| Repeated occurrence | A new occurrence with `repeatedFromOccurrenceId`; source stays terminal. | Durable scheduled planning / Drift |
| Travel-week context | Inclusive local-date range plus equipment-profile override. It affects the occurrence read model and snapshot at start; it does not rewrite programs or occurrences. | Durable planning context / Drift |
| Equipment profile/item | Named inventory and default increment. Items use canonical equipment codes, availability, and optional per-item increment. | Durable user preference / Drift |
| Setup preference | One exercise preference identity with general note; child setup values and personal cues. | Durable user preference / Drift |
| Personal cue/note | User-authored, ordered cue or a general exercise note. Seeded catalog cues remain on `Exercises`; set notes remain on `WorkoutSets`. | Durable user preference / Drift / existing execution history |
| Reminder | No new B01 entity. Existing global workout notification preferences remain their current owner; per-exercise reminders are deferred. | Existing preference; no B01 table |
| Calendar selection, visible range/view | Selected local date, week/month view, sheet state, filters. | Riverpod memory only; derived query state |
| Today/week/month, program block label, travel banner, unavailable-equipment flags | Derived from the authoritative rows and device timezone. | Derived query state |

All new B01 IDs are app-generated text UUIDs. This makes backup graph
validation and references stable without leaking auto-increment IDs into the
domain. Existing `Exercises.id` remains the current integer catalog identity.

## 3. Ownership decisions

| State | Authoritative owner | Why / replication rule |
|---|---|---|
| Active program version and activation date/timezone | `TrainingPlanSettings` singleton in Drift | Relational, portable, and used to generate/query calendar data. Never SharedPreferences. |
| Selected/default equipment profile | `TrainingPlanSettings.defaultEquipmentProfileId` in Drift | Durable user selection; travel selects an override through its own context. |
| Travel-week state | `TravelContexts` in Drift | Date range and profile relationship are planning data, must work offline and backup. |
| Calendar selection/view | Riverpod `CalendarUiState` only | Ephemeral navigation state. It is intentionally neither backed up nor a database setting. |
| Program activation date | `TrainingPlanSettings.activeSinceLocalDate` and `activeSinceTimezoneId` in Drift | Civil-date scheduling needs both values. |
| Scheduled workout status | `ScheduledSessionOccurrences.status`, verified through `OccurrenceEvents`, in Drift | Must be transactional/auditable. |
| Reschedule history | `OccurrenceEvents` in Drift | Append-only durable history; the occurrence stores current effective date for fast queries. |
| Personal setup values/cues/general notes | Exercise preference tables in Drift | Durable relational user data; backed up. |
| Reminder scheduling | No new B01 reminder state. Existing global notification keys stay in their existing preference mechanism and backup allow-list. | A per-exercise notification contract is deferred. |
| Draft player state | Existing `WorkoutDrafts` in Drift, extended with occurrence and snapshot columns | It is durable recovery state, not Riverpod-only. |

`UserSettings` is not used as a generic escape hatch. `TrainingPlanSettings`
is a typed singleton because it holds FKs and date/timezone semantics.

## 4. Program versioning and activation rules

1. Creating a Program creates version `1` in `draft`; no calendar records
   exist yet. Importing a template follows the same path.
2. A draft and all of its blocks/weeks/templates/prescriptions are editable
   transactionally. It may be discarded while unreferenced.
3. Activating a draft validates a contiguous block/week/session ordering,
   resolved-or-explicit-fallback exercise identity, valid weekdays, no invalid
   profile/travel references, and no existing active player draft. In one
   transaction it computes local dates from the requested activation local date
   and IANA zone, creates occurrences, makes this version active, and retires
   the prior active version. The version and children become immutable.
4. Editing an active or retired version means “Create new version”. Copy its
   child graph into `versionNumber + 1`, set `sourceVersionId`, and edit that
   new draft. Direct writes to immutable child tables are rejected by repository
   guards (and covered by tests); UI affordances never offer in-place edit.
5. Existing occurrences retain their `programVersionId`, template reference,
   planning ordinal, and original/effective dates after a new version activates.
   They are neither regenerated nor overwritten. The new active version creates
   only its own occurrences from its requested activation date. The calendar
   displays both when their dates overlap, labelled by version.
6. Activation normally requires the prior active version’s non-terminal future
   occurrences to be explicitly retained or cancelled. B01’s safe default is
   **retain**; the activation review shows their count. Cancelling is an
   explicit occurrence transition and never deletes them.
7. An active version may not be deleted. It may be retired when another version
   becomes active and archived only after all its occurrences are terminal or
   explicitly retained. Archiving hides it from authoring selectors but retains
   history and backup. A draft with no occurrences may be deleted transactionally.
8. Starting an occurrence only permits a currently effective, non-terminal
   occurrence. The player receives a frozen snapshot (template name,
   prescription IDs/IDs-or-name fallbacks, sets/reps and user-visible cues at
   start). Later preference/profile/version edits cannot change it. Completion
   writes the snapshot to `WorkoutSessions`; a resumed draft uses the same
   snapshot.

Example: “Strength Base” v1 has Block 1 Weeks 1–4 and Week 4 is deload.
Activated on Monday 2026-08-03 in `Asia/Kolkata`, its Week 2 Thursday Pull
template creates one occurrence with ordinal `(block 1, week 2, session 2)`.
On 2026-08-10 the user copies v1 to v2 and changes only Week 3. Activating v2
on 2026-08-17 does not change v1’s Week 2 Thursday record, including if it was
rescheduled to Friday; v2 has its own Week 1 schedule beginning 2026-08-17.

## 5. Calendar semantics and occurrence state machine

### Local-date/timezone rule

An occurrence is scheduled for a civil local date plus `timezone_id` and an
optional local start time. Date construction and week boundaries use that
zone’s local calendar, not `DateTime.now()` UTC and not a weekday-only field.
The original planned date/zone never changes. A reschedule updates only the
effective date/zone and creates an event that records before/after values.
When travelling, display date according to the occurrence’s effective zone;
the device’s current zone is only a presentation conversion aid. A timezone
change alone must never shift its stored `local_date`. “Today” is calculated
in device zone, while its query includes occurrences whose local civil date is
today in their own stored zone; ambiguous cross-zone display must show the
zone abbreviation.

Program progression is ordinal-based: a reschedule across a week/block never
changes `programWeekOrdinal` or session ordinal. “Advance” is a terminal
decision on one ordinal, not an algorithm that moves dates.

### States and transitions

`planned` is an unmodified future/past instance. `rescheduled` is an
unstarted instance whose effective date differs from original. `in_progress`
has the one allowed active draft. `completed` and `partially_completed` have a
completed session. `skipped` records a deliberate skip. `cancelled` is an
explicitly removed future plan (for example, activation cleanup), not a missed
session. Past planned/rescheduled records are **overdue**, a derived display
flag—not a persisted status.

| Trigger | Allowed source → result | Program progression | Calendar/history | Undo |
|---|---|---|---|---|
| Activate schedule | none → `planned` | Creates fixed ordinal; no execution progress. | Shows original local date. | Activation reversal only before any start, as a guarded admin/repository operation. |
| Reschedule | `planned`/`rescheduled` → `rescheduled` | Unchanged. May cross week/block with warning. | Effective date changes; event records old/new local dates/zones/reason. | Yes, while not started; another reschedule can restore original date and state becomes `planned`. |
| Start | `planned`/`rescheduled` → `in_progress` | Ordinal is locked; snapshot freezes. | Calendar marks in progress; draft links occurrence. | “Discard draft” returns to prior `planned`/`rescheduled` before any saved session; no undo after a completed session. |
| Save full execution | `in_progress` → `completed` | This ordinal is fulfilled. | Existing session/sets are permanent history; occurrence links session. | No state undo in B01; correcting a logged session is outside this batch. |
| Save partial execution | `in_progress` → `partially_completed` | This ordinal is terminal and recorded as partial; no automatic make-up. | Permanent session/sets plus completion fraction/reason in snapshot/event. | No B01 state undo. User may create a repeat. |
| Skip without advance | `planned`/`rescheduled` → `skipped` (`skipMode=hold`) | The ordinal remains unfulfilled in the progression read model; later occurrences retain dates. | Calendar shows skipped; event has reason. | Yes until a later action starts/repeats it; restore original/effective schedule. |
| Skip and advance | `planned`/`rescheduled` → `skipped` (`skipMode=advance`) | Ordinal is terminally bypassed; later ordinals become the next planned work. | Calendar/history retain skipped record and reason. | Yes until a later ordinal begins; reopening requires explicit confirmation. |
| Cancel | `planned`/`rescheduled` → `cancelled` | No automatic advance; only activation/plan management uses it. | Remains visible in history/calendar filter. | Yes while no start; restores previous effective state. |
| Repeat completed/partial | terminal source → create a **new** `planned` occurrence | Original ordinal does not change; repeat has `isRepeat=true` and a new non-program progression ordinal. | New date card links to source; old history unchanged. | Delete/cancel only while unstarted. |
| Repeat skipped | `skipped` → create new `planned` occurrence | Does not reopen source. Default is the next selectable local date, not automatic same-day. | Source retains skip; new card links source. | Cancel new unstarted repeat. |
| Start unscheduled workout | no occurrence → new `WorkoutSession` with null occurrence ancestry | No program progression effect. | It appears only in history, as today’s manual/unscheduled entry. | Existing log flow rules. |

Multiple occurrence records may share a date, including repeats and overlapping
versions. They sort by optional local start time, then version/week/session
ordinal, then creation time. The controller may allow only one global active
draft because that is the existing player constraint; starting a second asks
the user to resume/discard the first. Missed past occurrences are never
auto-skipped, auto-advanced, or silently moved. Their action sheet offers
reschedule, skip with the explicit mode, repeat only after terminal state, or
start (with a past-date warning).

## 6. Travel-mode MVP

| Option | Assessment |
|---|---|
| 1. Preserve order and only substitute unavailable exercises | **Recommended B01 MVP**, constrained to user-selected/manual replacements rather than an automatic substitution engine. |
| 2. Reduce volume while preserving patterns | Needs volume/pattern semantics and a validated prescription transform; defer. |
| 3. Insert temporary travel week without consuming normal weeks | Requires schedule shifting/reconciliation and nontrivial progression semantics; defer. |
| 4. Replace scheduled week and advance normally | Destructively changes the program and obscures normal-period history; defer. |

A travel context is activated by choosing inclusive start/end local dates,
their IANA timezone, and an existing equipment profile. It is rejected if it
overlaps another active context. Existing occurrences are not cloned, moved,
or altered. The calendar read model adds a travel badge and resolves effective
equipment as travel profile first, then default profile. The start snapshot
records the applicable context and effective profile. An incompatible exercise
is visibly flagged; the user may select a compatible exercise for that one
execution snapshot, leave the original if they still have access, or skip/
reschedule. The source template is never changed.

Program/week order and deload flags continue unchanged. If travel covers a
deload week, it remains a deload week; there is no separate travel deload
algorithm. Ending/cancelling a context restores the default profile for dates
outside it and future starts; completed snapshots remain untouched. All data is
local, so it works offline. The product owner must decide whether manual
substitution is required before start or only warned about (see decisions).

## 7. Equipment profiles and compatibility

An equipment profile has a unique name (case-insensitive in repository
validation), an optional default load increment in kg, an archived flag, and
many item rows. Item codes come from a small canonical equipment registry
defined alongside the exercise identity audit (for example `barbell`,
`dumbbell`, `cable`, `machine`, `bench`, `pull_up_bar`, `bodyweight`). An item
is either available or unavailable and may override the profile’s increment.
`bodyweight` is an equipment capability, not a numeric weight increment; a
“No equipment” profile contains bodyweight only and has no load increment.

Profile compatibility is deliberately boolean/minimum-capability only:
an exercise with a resolved canonical equipment requirement is compatible
when every required code is available, or the profile has the legacy
`full_gym` capability. Unknown requirement or unresolved exercise identity is
shown as “compatibility unknown”, never quietly excluded. B01 may filter the
picker and flag scheduled exercises; it does not rank or propose substitutions.

On v14 migration create exactly one unarchived profile named `Default gym`
(rename collision-safe), with `legacy_access_code` set to the old
`UserProfiles.equipmentAccess`. Map only exact known legacy values to registry
capabilities (including `full_gym`); preserve unknown string as a display note
and mark compatibility unknown. Retain and continue exporting
`UserProfiles.equipmentAccess` for v5/legacy compatibility; after profile
edits, update it only with a representable legacy access code, otherwise leave
the imported value unchanged. The default profile is selected in
`TrainingPlanSettings`. A profile cannot be deleted when selected by settings,
a non-ended travel context, or a nonterminal occurrence snapshot; offer
archive or choose a replacement instead.

## 8. Exercise identity dependency

Introduce nullable `exercise_id` FKs before B01 prescription tables are used.
Every new prescription must use a selected `Exercises` row and stores
`exercise_name_snapshot` for display/backup stability. A nullable fallback is
allowed only for preserved migration/import data or an explicitly created
custom/unresolved exercise. Exact backfill normalizes only Unicode whitespace
and compares exact case-folded catalog name after duplicate detection. It must
not remove technique qualifiers or use substring/fuzzy matching. A name with
zero or multiple canonical candidates stays `exercise_id = NULL`, retains its
raw name, and is reported in a migration/audit fixture.

New `WorkoutSets.exercise_id` is populated only for exact existing set names;
the legacy `exercise_name` remains required and is never rewritten. Existing
history queries continue using name equality. New history read models prefer
ID when an exercise is selected and include legacy exact-name sets as a clearly
labelled compatibility union; no historical record is relabelled. A separate
foundation data-audit task must establish aliases, duplicate policy, canonical
equipment code mappings, and remediation of ambiguous seeded/custom names
before any automatic production backfill is approved.

## 9. Notes, setup preferences, and draft compatibility

Seeded `Exercises.formCues`/`commonMistakes` remain catalogue-owned and
read-only in B01. A user exercise preference supplies one general note,
ordered personal cues, and labelled setup values such as `Seat height: 5` or
`Pin: 7`; it is per exercise, not per gym, to avoid multiplying overlapping
note systems. `WorkoutSets.setNotes` remains a performed-set note. B01 does
not add a separate workout-level note because the current player does not have
a stable session-note model; that is a future execution-domain decision.

The player’s existing exercise detail/quick info surface gets a compact
“Your setup & cues” section from the preference read model. It does not require
a redesign: show setup pairs and up to three cues above the active set, with a
link to edit; general notes stay in an expandable section. The frozen snapshot
stores the values displayed at start so later edits do not alter execution
history.

**Draft decision:** fix serialization as a small B01 prerequisite, before
starting scheduled occurrences. Add a `draft_schema_version` and optional
`scheduled_occurrence_id`/`execution_snapshot_json` columns. New JSON is an
object envelope with `sets` and each set preserves RPE, set type, warm-up,
duration, distance, incline, notes, plus existing fields. Parser accepts old
bare `List` JSON and supplies existing defaults (`rpe=null`, `working`, false,
null metrics); it also accepts the new envelope and rejects malformed values
with a recoverable “discard draft” path. No B02 deferral is acceptable because
the current implementation drops user-entered data.

## 10. Proposed database schema (v15)

All timestamps named `...Utc` are ISO/Drift UTC instants; `localDate` is a
non-null `YYYY-MM-DD` text value and `timezoneId` is an IANA TZDB identifier.
Repository validation enforces lifecycle/status enums, date format, ordinal
contiguity, supported equipment codes, and cross-row business constraints that
SQLite cannot express alone.

### Required new tables

| Table | Purpose | Primary key | Important columns | Foreign keys | Unique constraints | Indexes |
|---|---|---|---|---|---|---|
| `Programs` | Stable program identity | `id TEXT` | `name`, `goal`, `notes`, `createdAtUtc`, `archivedAtUtc` | — | active-name uniqueness is not required | `archivedAtUtc`, `createdAtUtc` |
| `ProgramVersions` | Version lifecycle | `id TEXT` | `programId`, `versionNumber`, `status`, `sourceVersionId`, `createdAtUtc`, `activatedAtUtc`, `retiredAtUtc`, `archivedAtUtc` | Programs; self source nullable | `(programId, versionNumber)` | `(programId,status)`, `sourceVersionId` |
| `ProgramBlocks` | Ordered phase | `id TEXT` | `programVersionId`, `ordinal`, `name`, `description` | ProgramVersions | `(programVersionId, ordinal)` | `programVersionId` |
| `ProgramWeeks` | Ordered week / deload declaration | `id TEXT` | `programBlockId`, `ordinalInBlock`, `programWeekOrdinal`, `name`, `isDeload` | ProgramBlocks | `(programBlockId, ordinalInBlock)`, `(programVersionId-derived validation, programWeekOrdinal)` | `programBlockId`, `programWeekOrdinal` |
| `SessionTemplates` | Planned session slot | `id TEXT` | `programWeekId`, `ordinal`, `name`, `plannedWeekday`, `plannedStartMinute`, `notes` | ProgramWeeks | `(programWeekId, ordinal)`, `(programWeekId, plannedWeekday, ordinal)` | `(programWeekId, plannedWeekday)` |
| `ExercisePrescriptions` | Ordered B01 exercise plan | `id TEXT` | `sessionTemplateId`, `ordinal`, `exerciseId NULL`, `exerciseNameSnapshot`, `plannedSets`, `repsRange` | SessionTemplates; Exercises nullable | `(sessionTemplateId, ordinal)` | `sessionTemplateId`, `exerciseId` |
| `ScheduledSessionOccurrences` | Calendar instance/current state | `id TEXT` | version/template IDs, block/week/session ordinals, `repeatOrdinal` (0 for planned source), `originalLocalDate`, `originalTimezoneId`, `effectiveLocalDate`, `effectiveTimezoneId`, `status`, `skipMode NULL`, `repeatedFromOccurrenceId NULL`, `startedAtUtc`, `terminalAtUtc`, `createdAtUtc` | ProgramVersions, SessionTemplates, self repeat | `(programVersionId, programWeekOrdinal, sessionTemplateId, repeatOrdinal)` | `(effectiveLocalDate,status)`, `(programVersionId,status)`, `repeatedFromOccurrenceId` |
| `OccurrenceEvents` | Append-only transition/reschedule history | `id TEXT` | `occurrenceId`, `eventType`, `fromStatus`, `toStatus`, `beforeLocalDate`, `beforeTimezoneId`, `afterLocalDate`, `afterTimezoneId`, `reason`, `metadataJson`, `occurredAtUtc` | Scheduled occurrences | — | `(occurrenceId,occurredAtUtc)`, `eventType` |
| `TrainingPlanSettings` | One typed selection/activation owner | fixed `id INTEGER=1` | `activeProgramVersionId NULL`, `activeSinceLocalDate NULL`, `activeSinceTimezoneId NULL`, `defaultEquipmentProfileId NULL`, `updatedAtUtc` | ProgramVersions, EquipmentProfiles nullable | PK/check id=1 | active version/profile FKs |
| `TravelContexts` | Durable date-range override | `id TEXT` | `startLocalDate`, `endLocalDate`, `timezoneId`, `equipmentProfileId`, `status`, `createdAtUtc`, `endedAtUtc`, `note` | EquipmentProfiles | repository-enforced non-overlap for active records | `(status,startLocalDate,endLocalDate)`, `equipmentProfileId` |
| `EquipmentProfiles` | Named equipment inventory | `id TEXT` | `name`, `defaultWeightIncrementKg NULL`, `legacyAccessCode NULL`, `note`, `archivedAtUtc`, `createdAtUtc`, `updatedAtUtc` | — | case-insensitive active-name validation | `archivedAtUtc`, `name` |
| `EquipmentProfileItems` | Profile capability/increment | `id TEXT` | `equipmentProfileId`, `equipmentCode`, `isAvailable`, `weightIncrementKg NULL` | EquipmentProfiles | `(equipmentProfileId,equipmentCode)` | `(equipmentProfileId,isAvailable)`, `equipmentCode` |
| `ExerciseUserPreferences` | Per-exercise personal material | `id TEXT` | `identityKey`, `exerciseId NULL`, `exerciseNameFallback`, `generalNote`, timestamps | Exercises nullable | `identityKey` (`exercise:<id>` or `name:<raw>`) | `exerciseId`, `identityKey` |
| `ExerciseSetupValues` | Label/value setup details | `id TEXT` | `exerciseUserPreferenceId`, `ordinal`, `label`, `value` | ExerciseUserPreferences | `(exerciseUserPreferenceId,ordinal)` | `exerciseUserPreferenceId` |
| `ExercisePersonalCues` | Ordered personal cues | `id TEXT` | `exerciseUserPreferenceId`, `ordinal`, `cueText` | ExerciseUserPreferences | `(exerciseUserPreferenceId,ordinal)` | `exerciseUserPreferenceId` |

`ProgramWeeks` needs `programVersionId` denormalized as a non-null FK in the
actual table to enforce the global `(programVersionId, programWeekOrdinal)`
unique constraint; it must agree with its block’s version in repository
validation. This small redundancy makes calendar queries/indexes safe.

### Required existing-table changes

| Table | v15 change | Compatibility rule |
|---|---|---|
| `WorkoutSessions` | Nullable `scheduledOccurrenceId` FK (unique where non-null), `executionSnapshotJson NULL`, `executionTimezoneId NULL`, `completionKind` nullable/`full` or `partial`. | Existing rows remain null-ancestry and valid. Session columns/queries remain. This is the only completion FK, avoiding a circular FK with occurrences. |
| `WorkoutSets` | Nullable `exerciseId` FK. | Keep required `exerciseName`; legacy history remains exact-name-based. |
| `WorkoutDrafts` | Nullable `scheduledOccurrenceId`, `executionSnapshotJson`, non-null `draftSchemaVersion` default 1. | Preserve one-draft invariant and existing columns; parser supports old JSON. |
| `UserProfiles` | No destructive change. Keep `equipmentAccess`. | It is migrated into the first profile and retained for old flows/backup compatibility. |
| `RoutineExercises` | No B01 table change required. | Legacy name relationships remain only in legacy compatibility paths; B01 does not write new routine rows. |

### Optional / deferred

`EquipmentDefinitions` as a database catalog, `ExerciseAliases`, canonical
muscle mapping, exercise-group/set-prescription tables, `PerformedExercise`,
`PerformedSet`, session-level notes, reminders, full activity modalities, and
substitution recommendations are deferred. B01 uses a reviewed, versioned
static registry for equipment codes until the foundation catalog work lands.

## 11. v14 → v15 migration strategy

The upgrade is a single Drift transaction after all v15 tables/columns are
created. It must be idempotent for a clean v14 snapshot and deterministic by
sorting legacy IDs. It never deletes legacy routines, session, set, or draft
data.

1. Create v15 tables/columns and indexes. Seed/validate the static equipment
   code registry before data mapping.
2. For each legacy `WorkoutRoutine` ordered by `id`, insert one Program and a
   version 1 named as the legacy routine, labelled `legacy-imported`. Create
   one block and one ProgramWeek. Convert each `RoutineDay` ordered by
   `dayOfWeek,id` into a SessionTemplate only when it is not a rest day;
   retain its exact weekday and name. Convert its exercises ordered by
   `orderIndex,id` into prescriptions, with raw name snapshot and only an
   approved exact unique `Exercises.name` match. Rest days remain represented
   by lack of template; the source rows remain available to the adapter.
3. Do **not** activate every imported program or manufacture calendar
   occurrences. Select one legacy source deterministically using the existing
   screen’s behavior: greatest `WorkoutRoutines.id` (the screen uses
   `routines.last`). Activate its imported version only if no player draft
   exists, with `activeSinceLocalDate` equal to migration device local date and
   device IANA zone; materialize only current-and-future occurrences for its
   one-week template. If an in-flight draft exists, leave all imported versions
   inactive and let the post-upgrade compatibility screen complete/discard it;
   prompt activation later. This avoids mis-anchoring a draft.
4. Create one `EquipmentProfile` from the single profile row’s
   `equipmentAccess`, exact-map only known values, and set it as default in
   `TrainingPlanSettings`. Preserve unknown access string verbatim.
5. Add nullable set IDs using the exact mapping policy; leave ambiguous/custom
   values null. Do not add program/occurrence ancestry to historical sessions
   and do not infer it from date/weekday/name.
6. Keep old draft JSON and add default schema version 1. Do not parse/rewrite
   it during migration. New player parsing is backward compatible.
7. Commit all rows together. Any mapping/foreign-key/write failure aborts the
   upgrade and leaves the v14 database intact. Report unresolved name counts
   in logs/diagnostics only, never as an upgrade failure.

Representative migration fixtures must include: no routine; one routine with
rest day; multiple routines (selection is greatest ID); duplicate/exact/
unresolved/custom exercise names; profile with known and unknown string;
historical sessions/sets; draft with legacy basic JSON; all new FKs null where
required; and a forced failure proving transaction rollback. A fresh v15
database creates no legacy compatibility program.

## 12. Backup v6 impact

Set `BackupData.currentVersion = 6`. Export/import the full B01 graph in FK
order: Programs, ProgramVersions, Blocks, Weeks, SessionTemplates,
Prescriptions, EquipmentProfiles/items, TrainingPlanSettings, TravelContexts,
Occurrences, OccurrenceEvents, ExerciseUserPreferences/setup values/cues, and
the extended session/set/draft fields. Preserve legacy routine tables in v6 as
well: they are still user-owned and required for compatibility adapters.

`fromJson` accepts v3–v5 and supplies empty B01 collections plus null new
columns. Restoring a v5 backup onto v15 restores its legacy entities exactly,
then invokes the same deterministic legacy-program import helper inside the
restore transaction (not the device migration callback); no user data is lost
and no guessed session ancestry is created. A v6 restore pre-validates every
new FK, enum/date/timezone value, ordinal uniqueness, and event/occurrence
relationship before it writes anything. Restore deletes/reinserts new tables
in dependency-safe order inside the existing single database transaction and
extends the existing SharedPreferences compensation behavior unchanged.

Backups do not export derived calendar UI state. They do export durable travel
contexts even when ended/archived, since they can explain execution snapshots
and are user-owned records. v6 retains existing encryption/envelope/hash and
atomic restore behavior; it is not an atomic-restore redesign.

## 13. Repository and Riverpod boundaries

| Boundary | Interface responsibility | Dependencies / prohibitions |
|---|---|---|
| `ProgramRepository` | Create/copy/edit draft versions; validate and query authoring graph; archive/destroy eligible draft. | Depends on DB and exercise identity resolver. Does not schedule, log workouts, or own equipment. |
| `ProgramActivationCoordinator` | Validate activation, retire/retain prior plan choice, materialize occurrences and update `TrainingPlanSettings` atomically. | Depends on ProgramRepository + CalendarRepository; no widget logic. |
| `CalendarRepository` | Occurrence date queries, transitions, reschedule/skip/repeat/start guards, events, travel-context application/read model. | Depends on DB and injected timezone clock. Does not mutate templates. |
| `EquipmentProfileRepository` | CRUD/default selection, exact legacy conversion, capability checks, profile archival safety. | Depends on DB + static canonical equipment registry; no AI routine generation rewrite. |
| `ExercisePreferenceRepository` | CRUD for one preference aggregate, quick player read model. | Depends on DB; owns no seeded catalog cue. |
| `WorkoutExecutionCompatibilityAdapter` | Build frozen snapshot, bridge occurrence start/finalize to existing player/draft/session APIs, preserve legacy unscheduled launch. | May call existing `WorkoutRepository` only for completed session/set persistence and legacy history. |
| Existing `WorkoutRepository` | Continue legacy routines, history, sets, draft primitives during transition. | Must not become the B01 authoring/calendar/equipment god repository. Refactor narrowly behind adapter. |

Providers: database/repository providers are simple `Provider`s. `activeProgram
read model`, `calendar range occurrences`, `occurrence detail`, `travel banner`,
and `player preference panel` are `StreamProvider`/derived providers watching
repository queries. `ProgramEditorController`, `CalendarController`,
`TravelModeController`, and `EquipmentProfileController` own user commands
and expose typed loading/error/success state. `CalendarUiState` alone holds
selected local date/view in memory. Mutations invalidate only affected version,
date-range, occurrence, active-plan, travel, equipment, and player providers;
never issue global refreshes.

## 14. MVP UX flows

**Program creation / activation.** Start with Create or Import. The authoring
wizard builds a draft with blocks, weeks, deload toggles, session weekdays, and
prescriptions. Review displays unresolved exercise names and calendar preview.
Activate selects local start date/timezone and shows retained/cancelled prior
occurrences. Editing an active program always opens “Create vN+1 draft,” then
the same review/activation path.

**Calendar.** The training route opens Today with a compact week strip and a
switch to month; month is a query/view, not a separate schedule. Tapping an
occurrence shows original/effective date, program week/block, status, travel
badge, equipment compatibility, and actions: Start, Reschedule (date/timezone
picker), Skip (explicit advance choice), Repeat when terminal, or view event
history. Drag-to-reschedule is explicitly an enhancement; use accessible
action sheet/date picker in B01.

**Travel mode.** Choose travel dates, timezone, and profile; preview affected
occurrence count and incompatible exercises, then Apply. The calendar shows a
range banner and per-occurrence flags. End/cancel context restores normal
profile resolution without changing dates; normal plan order remains visible.

**Equipment profiles.** List profiles and default badge. Create/edit name,
items, availability, and increments; select default. Delete becomes archive
when referenced, otherwise requires explicit replacement if it is default.

**Exercise preferences.** From exercise detail or player, add/edit a general
note, ordered cues, and setup label/value. During player execution show the
compact snapshot-backed panel; an edit link affects future starts, not the
current snapshot.

## 15. Acceptance criteria and test matrix

| Criterion | Required evidence / test level |
|---|---|
| Fresh v15 database creates every required table/index and allows a valid program graph. | Database test |
| v14 fixture upgrade preserves all legacy rows, creates deterministic one-block imports, preserves null historical ancestry, and rolls back on forced failure. | Migration test; **SOL-GATE REQUIRED** |
| Legacy routine screen/actions work through adapter after upgrade; greatest legacy ID selection is preserved until explicit B01 activation. | Repository + widget/integration test |
| Draft version is editable; active/retired child graph writes fail; copy creates a new source-linked version. | Repository + database test; **SOL-GATE REQUIRED** |
| Activation validates graph and atomically creates correctly dated, zone-labelled occurrences and one active setting. | Repository/database test; **SOL-GATE REQUIRED** |
| Civil-date calculations survive DST and device-zone changes; original date remains fixed and display shows stored zone. | Unit + repository + manual Android/iOS timezone test |
| Valid reschedule records event/history and does not change ordinal; invalid/terminal transitions are rejected. | Unit state-machine + repository test; **SOL-GATE REQUIRED** |
| Skip requires explicit mode; hold/advance produce specified progression read models; repeat creates linked new record. | Unit + repository + widget test |
| Full and partial starts create one snapshot/session ancestry; unscheduled start leaves ancestry null; multiple same-day sessions sort correctly. | Repository + controller + integration test |
| Travel context applies profile override without date/order/deload mutation; offline restart retains it. | Repository/controller + widget + integration test |
| Known legacy equipment strings make one default profile; unknown strings remain preserved/unknown; filtering flags compatible/incompatible/unknown correctly. | Migration + unit + repository test |
| Personal setup/general note/cues persist, display during player start, and later changes do not alter frozen snapshot. | Database/repository + widget/controller test |
| Old bare-array draft JSON restores with defaults; new envelope round-trips every listed field. | Unit + repository test; **SOL-GATE REQUIRED** |
| Backup v5 import produces valid v15 legacy compatibility data; v6 round trip preserves the complete B01 graph and rejects orphan graph before writes. | Backup/migration + integration test; **SOL-GATE REQUIRED** |
| All flows work with network disabled and do not require AI/API access. | Integration + manual platform test |

### Required test matrix

| Area | Unit | Database/migration | Repository/provider/controller | Widget/integration | Manual platform |
|---|---|---|---|---|---|
| Versioning/activation | ordinal/lifecycle validators | constraints, v14→v15 | atomic activation/copy | author/review screens | Android+iOS recovery from interruption |
| Calendar/state machine | transition matrix, date/DST | status/event indexes | reschedule/skip/repeat/invalidation | today/week/month/action sheets | timezone change and travel device tests |
| Execution/drafts | JSON parser/defaults | new nullable columns | snapshot/start/finalize guards | player panel/resume | kill/relaunch draft |
| Equipment/travel | code compatibility | profile migration | override resolution | profile/travel flows | offline mode, zone/DST range |
| Preferences | cue/setup validation | preference FK cascade | read model/cache invalidation | editor/player display | dynamic text/accessibility |
| Backup | v5/v6 parsing | restore transaction rollback | graph validation | export/import journey | encrypted file on Android/iOS |

Validation commands for implementation tasks are at minimum `dart format --set-exit-if-changed <changed paths>`, `flutter analyze`, targeted `flutter test <files>`, full `flutter test`, and Android/iOS release builds when platform/plugin code is touched. The implementation owner must use the project’s actual CI build commands if they differ.

## 16. Sol-gate decisions and definition of done

**SOL-GATE REQUIRED:** approval of exact exercise identity and equipment-code
mapping policy; v14→v15 transaction/migration fixture design; activation and
state-machine guards; nullable execution ancestry/snapshot contract; v5/v6
backup graph/restore review; final B01 verification. These gates cannot be
closed by UI-only review.

B01 is done only when the charter exit criteria and every criterion above pass,
all new user-owned B01 state exports/restores, no active version can be mutated
in place, no automatic fuzzy identity mapping occurs, legacy routines/history
remain usable, scheduled behavior is offline/date-zone tested, draft fields no
longer disappear, all invalid transitions reject without partial writes, and
the migration/backup/release test suites are green on Android and iOS.
