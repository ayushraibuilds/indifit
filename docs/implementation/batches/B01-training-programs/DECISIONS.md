# B01 Decisions — Sol Architecture Gate

Status: Gate reviewed at baseline commit `78851f6` on 2026-07-29.

The canonical roadmap and `CHARTER.md` remain binding. These decisions amend
conflicting proposals in `PLAN.md`; implementation must follow this document
where the two differ.

## Gate inventory

| Decision | Gate result | Principal risk |
|---|---|---|
| B01-D01 Schema v15 / Backup v6 | Amended | The schema depended on unstable integer exercise IDs and unresolved product scope. |
| B01-D02 Legacy routine migration | Amended | Migration-time auto-activation would invent dates and change user state. |
| B01-D03 Program-version lifecycle and active owner | Amended | `ProgramVersions.status=active` duplicated `TrainingPlanSettings.activeProgramVersionId`. |
| B01-D04 Activation and replacement versions | Amended | Prior occurrences and replacement activation needed final retention rules. |
| B01-D05 Occurrence state machine | Amended | Idempotency, crash recovery, past/future starts, and duplicate completion were unspecified. |
| B01-D06 Progression, skip, and repeat semantics | Amended | A terminal status alone cannot represent whether a program ordinal is fulfilled. |
| B01-D07 Default skip UX | Deferred | Canonical roadmap assigns this user-visible default to the product owner. |
| B01-D08 Date and timezone semantics | Amended | Program timezone, travel rescheduling, DST, and date-query behavior needed exact rules. |
| B01-D09 Travel-week behavior | Deferred | Canonical roadmap explicitly requires a product-owner choice. |
| B01-D10 Durable-state ownership | Amended | The proposed lifecycle and legacy equipment mirror created duplicate authorities. |
| B01-D11 Reminder scope | Deferred | The charter includes reminders, but the intended behavior is not defined. |
| B01-D12 Draft persistence and finalization | Amended | Current code deletes the draft before the summary saves the session. |
| B01-D13 Backup v6 graph and v5 import | Amended | Stable exercise identity, FK order, and conditional reminder/travel records were incomplete. |
| B01-D14 Repository/provider boundaries | Accepted | Boundaries are sound once transaction ownership is made explicit. |
| B01-D15 Exercise notes and setup preferences | Accepted | The proposed aggregate avoids overlapping note systems. |
| B01-D16 Archive and delete rules | Amended | Hard-delete constraints must protect published ancestry and occurrences. |

Critical items Terra did not independently mark for Sol review were: portable
exercise identity rather than `Exercises.id`; the duplicate active-version
authority; migration-time auto-activation; atomic/idempotent finalization;
partial-completion progression; travel-range membership across timezones; the
existing notification preference-key mismatch; and the absence of a real v14
upgrade fixture in `test/db_migration_test.dart`.

## B01-D01 — Stable exercise identity before program tables

- **Status:** Amended.
- **Final rule:** Add a stable, unique text UUID/canonical ID to every
  `Exercises` record as a prerequisite subtask. Seeded exercises receive IDs
  from a reviewed, versioned catalogue manifest; custom exercises receive
  persisted UUIDs. New prescriptions and new nullable compatibility columns
  reference this stable ID, not the current auto-increment integer ID. Legacy
  display-name snapshots remain required.
- **Rationale:** `Exercises.id` is database-local and custom exercise IDs are
  remapped by Backup v5 restore. It therefore cannot be the portable identity
  required by the roadmap or safely referenced from Backup v6.
- **Invariants:**
  - Automatic backfill uses only exact normalized matches or an explicitly
    approved one-to-one alias manifest.
  - Normalization may case-fold and normalize Unicode whitespace; it may not
    strip technique qualifiers or use fuzzy/substring matching.
  - Zero-match and multi-match names remain unresolved with null stable ID and
    their original display name.
  - Custom exercises and catalogue variants remain distinct records.
  - A catalogue rename preserves the stable ID and cannot sever history.
  - Existing exact-name history/PR/prefill queries continue during B01.
- **Required tests:** stable seeded IDs across fresh installs; custom UUID
  backup/restore; exact/alias/ambiguous/unresolved fixtures; rename-preserves-
  history; no fuzzy match regression.
- **Affected tasks:** B01-01, B01-03, B01-05, B01-07, B01-09, B01-10.

## B01-D02 — Schema v15 and legacy routine migration

- **Status:** Amended.
- **Final rule:** Use schema v15 for the accepted B01 graph and Backup v6, but
  migrate and temporarily retain legacy routines. Each legacy routine is copied
  deterministically to a one-block, one-week, immutable `legacyImport`
  ProgramVersion with a source-routine mapping. Legacy rows remain through B01.
  Migration does **not** select an active B01 version, create occurrences, or
  assign an activation date. The compatibility adapter continues the de facto
  legacy selection using greatest routine ID until the user explicitly
  activates a B01 version.
- **Rationale:** The repository has no durable active-routine field;
  `getSavedRoutines()` is unordered and screens use `routines.last`. Creating an
  activation date from migration time would invent user intent and scheduled
  history. Copy-and-retain satisfies the roadmap while keeping rollback and
  legacy backup paths safe.
- **Invariants:**
  - The upgrade is transactional and never deletes legacy routines, days,
    exercises, sessions, sets, or drafts.
  - Historical sessions keep null program/occurrence ancestry.
  - Imported legacy versions are immutable snapshots; editing them creates a
    new draft version.
  - After the compatibility adapter is enabled, program data is authoritative;
    retained legacy rows are compatibility/export data, not a second mutable
    owner.
  - No calendar occurrence exists without explicit activation.
  - Migration is deterministic by source IDs/order and safe for zero routines.
- **Required tests:** real v14 file upgrade with zero/one/multiple routines,
  rest days, custom/unresolved exercises, active draft, known/unknown equipment,
  historical sessions/sets, deterministic source mapping, no activation rows,
  and injected rollback failure.
- **Affected tasks:** B01-02, B01-03, B01-13, B01-10.

## B01-D03 — Program-version lifecycle and active owner

- **Status:** Amended.
- **Final rule:** `ProgramVersion` lifecycle is `draft`, `published`, or
  `archived`. `publishedAtUtc` is the immutability boundary. The sole current
  active-version authority is `TrainingPlanSettings.activeProgramVersionId`;
  active Program is derived through that FK. There is no independent
  `active`/`retired` lifecycle status and no second active Program field.
- **Rationale:** A lifecycle status and a settings pointer could disagree.
  Separating immutable publication from current selection gives one authority
  while retaining historical versions.
- **Invariants:**
  - Only draft versions and draft children are mutable.
  - Publishing/activating is one-way; a published or archived version never
    becomes editable.
  - Reusing an old published structure requires copying it to a new draft.
  - At most one settings row and one non-null active-version pointer exist.
  - The pointer may reference only a published, non-archived version.
- **Required tests:** draft edit succeeds; published/archived child mutation
  fails; copy creates a new version number/source link; singleton and FK guards;
  active Program derives from active version.
- **Affected tasks:** B01-03, B01-05, B01-06, B01-10.

## B01-D04 — Activation and replacement versions

- **Status:** Amended.
- **Final rule:** Activation validates and publishes a draft, materializes its
  occurrences, and changes the singleton active-version pointer in one
  transaction. A replacement version always starts as a copied draft. Existing
  occurrences keep their original version and never switch to the replacement.
  Future nonterminal occurrences from the previous version are retained by
  default; the activation review may explicitly cancel selected ones, producing
  events rather than deletions.
- **Rationale:** This is the only behavior that preserves ancestry while
  avoiding silent loss of previously planned work.
- **Invariants:**
  - Activation is rejected when graph validation fails or another workout draft
    is active.
  - A client-supplied activation command ID makes retry idempotent.
  - Existing completed sessions/snapshots never change.
  - Prior-version occurrences remain queryable and startable unless explicitly
    cancelled.
  - A published historical version is not “reactivated”; the user copies it to
    a new version.
- **Required tests:** atomic activation rollback; idempotent retry; replacement
  with retained/cancelled prior occurrences; overlapping version calendar;
  immutable completed snapshot.
- **Affected tasks:** B01-05, B01-06, B01-09, B01-11A.

## B01-D05 — Scheduled-occurrence state machine

- **Status:** Amended.
- **Final rule:** Retain `planned`, `rescheduled`, `inProgress`, `completed`,
  `partiallyCompleted`, `skipped`, and `cancelled`. Every command carries a
  unique command ID; `OccurrenceEvents` has a uniqueness constraint on
  `(occurrenceId, commandId)`. A retry of the same command returns its prior
  result without adding another event. A different command against a stale
  source state is rejected.
- **Rationale:** The proposed states are useful, but status alone does not make
  retries or the current multi-screen completion flow safe.
- **Invariants and transitions:**

| Source | Trigger | Destination | Advancement | Calendar/history | Undo | Idempotency |
|---|---|---|---|---|---|---|
| none | activation materializes | `planned` | pending | dated card + created event | activation rollback only before any occurrence starts | activation command returns existing graph |
| `planned` / `rescheduled` | reschedule | `rescheduled`, or `planned` when restored to original pair | unchanged | update effective date/zone; append before/after event | another reschedule while unstarted | same command returns current row/event |
| `planned` / `rescheduled` | start | `inProgress` | unchanged/pending | freeze snapshot and link sole draft | discard returns to exact pre-start state only when no session exists | same command returns same draft; another active draft rejects |
| `inProgress` | save full | `completed` | satisfied | atomically insert session/sets, event, status; delete draft last | none in B01 | retry returns the one existing session |
| `inProgress` | save partial | `partiallyCompleted` | pending | atomically retain performed work and reason | no state rollback; create make-up repeat | retry returns the one existing session |
| `planned` / `rescheduled` | skip with explicit disposition | `skipped` | pending for hold; bypassed for advance | retain card/event/reason | guarded restore to pre-skip state | same command has no second event |
| `planned` / `rescheduled` | cancel | `cancelled` | pending; never silently bypassed | retained in filtered calendar/history | guarded restore while no dependent occurrence has started | same command has no second event |
| terminal source | repeat | source unchanged; new `planned` row | determined by repeat purpose | linked new occurrence; source history unchanged | cancel new occurrence while unstarted | command ID returns same new occurrence |
| no occurrence | start/log unscheduled | no occurrence state | no program effect | `WorkoutSession.scheduledOccurrenceId = null` | existing manual-log rules | existing session UUID/idempotency rule |

  - Rescheduling across weeks or blocks is allowed with confirmation; original
    program ordinals never change.
  - Starting past or future occurrences is allowed only after an explicit date/
    order confirmation. It never auto-skips earlier ordinals.
  - Multiple occurrences may share one local date and are independently keyed.
  - App termination leaves `inProgress` plus its draft. Resume uses the same
    snapshot. A missing/corrupt draft requires explicit discard/recovery and
    never implies completion.
  - A unique non-null `WorkoutSessions.scheduledOccurrenceId` and conditional
    state update prevent two completions for one occurrence.
- **Required tests:** exhaustive transition table; cross-week/block moves;
  past/future starts; same-day occurrences; app kill/resume; corrupt/missing
  draft recovery; duplicate and competing completion commands; stale-command
  rejection.
- **Affected tasks:** B01-03, B01-06, B01-08A, B01-09, B01-10, B01-11A.

## B01-D06 — Progression disposition and repeat purpose

- **Status:** Amended.
- **Final rule:** Store or deterministically derive a progression disposition
  separate from occurrence status: `pending`, `satisfied`, or `bypassed`.
  Completed original work is satisfied; partial, cancelled, and skip-without-
  advance remain pending; skip-and-advance is bypassed. A repeat has explicit
  purpose `makeUp` or `extra`.
- **Rationale:** `skipped` and `partiallyCompleted` are terminal execution
  states but do not necessarily fulfill the program ordinal. Without a separate
  disposition, the next-workout query would silently advance.
- **Invariants:**
  - The next required program work is the lowest pending ordinal, derived rather
    than maintained as a second mutable cursor.
  - A make-up repeat of held-skip/partial work can satisfy the source ordinal
    when completed; the source status remains historical.
  - A repeat of completed work is extra and never advances program order.
  - A repeat of skip-and-advance is extra unless the user first reverses the
    skip disposition.
  - Out-of-order completion satisfies only its own ordinal.
- **Required tests:** progression truth table; partial make-up; completed extra;
  held-skip make-up; skip-and-advance repeat; out-of-order start/completion.
- **Affected tasks:** B01-03, B01-06, B01-08A, B01-09.

## B01-D07 — Default skip interaction

- **Status:** Deferred to product owner.
- **Final rule:** Both hold and advance are valid domain commands, but the UI
  must not silently choose one until the product owner decides. Recommended
  default is an explicit, unselected choice with “Keep this workout pending”
  presented first.
- **Rationale:** The canonical roadmap explicitly assigns this user-visible
  behavior to the product owner. The domain implementation can support both
  without waiting.
- **Invariants:** no single-tap skip with implicit advancement; choice is stored
  in the occurrence event/disposition; later undo follows B01-D05 guards.
- **Required tests:** controller requires a disposition; UI has no implicit
  advance; both commands produce correct progression.
- **Affected tasks:** B01-06 is not blocked; skip UI in B01-11A is blocked until
  the choice is recorded.

## B01-D08 — Date, timezone, and DST semantics

- **Status:** Amended.
- **Final rule:** Program weeks and initial occurrences use the activation
  timezone (“program/home timezone”). Store original and effective local date,
  optional local minute, and IANA timezone. Travel mode alone does not change
  either occurrence pair. Rescheduling while travelling explicitly writes the
  new effective local date and destination IANA zone; original values never
  change. Audit/start/terminal/event timestamps are UTC.
- **Rationale:** A date-only workout is a civil-calendar object, not UTC
  midnight. Device timezone changes must not move it.
- **Invariants:**
  - Program week arithmetic uses TZDB calendar construction in the activation
    zone, not repeated 24-hour UTC durations.
  - Device timezone changes affect “current device date” and labels only; they
    do not mutate stored schedule data.
  - Calendar date queries use indexed effective local-date fields and explicit
    calendar zone, not UTC-midnight ranges.
  - Date-only occurrences render on their stored effective date with a zone
    badge when it differs from the current device zone.
  - For an optional local time in a DST gap, resolve to the first valid instant
    after the gap; for an overlap, use the earlier offset unless the user
    explicitly selects the later one. Persist the resolved offset/choice in the
    start snapshot or event metadata.
- **Required tests:** Asia/Kolkata baseline; New York/London DST gap and overlap;
  dateline travel; device-zone change without mutation; travel-zone reschedule;
  local-date indexed query boundaries.
- **Affected tasks:** B01-03, B01-06, B01-08A, B01-08B, B01-11A, B01-14.

## B01-D09 — Travel-week MVP

- **Status:** Deferred to product owner; implementation blocked.
- **Final rule:** Recommended option is preserve normal program order, weeks,
  dates, and deload flags while applying a temporary equipment-profile override.
  No automatic volume reduction, substitute-week generation, or week
  consumption is permitted. Because the roadmap reserves this choice for the
  product owner, TravelContext schema and behavior are not approved until that
  option is confirmed.
- **Rationale:** The recommended option is the smallest reversible behavior,
  but other listed choices require materially different schedule data.
- **Invariants if accepted:**
  - Start/end are inclusive local dates with destination IANA zone.
  - Applying/cancelling travel never rewrites occurrences or program weeks.
  - A persisted `TravelContextOccurrences` membership set records the
    occurrences confirmed by the preview, avoiding implicit date conversion for
    date-only workouts across zones.
  - The override and membership are Drift data and Backup v6 data.
  - Started/completed snapshots retain the effective profile after cancellation.
  - Deload remains deload; normal profile resumes after end/cancellation.
  - All behavior works offline.
- **Required tests:** inclusive boundaries; explicit membership; cancellation;
  reschedule into/out of context; deload preservation; restart/offline; snapshot
  retention.
- **Affected tasks:** blocks travel portions of B01-03, B01-08B, B01-10, and
  B01-11B.

## B01-D10 — Durable-state ownership

- **Status:** Amended.
- **Final rule:** Drift owns the active-version pointer, default equipment
  profile, travel interval/profile/membership, occurrence state/events,
  setup values, cues/notes, stable exercise IDs, and drafts. Active Program is
  derived from the active version. Riverpod memory owns calendar selection,
  visible range/view, filters, and transient command state. SharedPreferences
  owns no B01 relational data.
- **Rationale:** This produces one authority for every durable relationship and
  meets backup/offline requirements.
- **Invariants:**
  - `UserProfiles.equipmentAccess` is a frozen legacy import/export field, not a
    synchronized mirror after profile migration.
  - Effective equipment profile is derived: travel override when applicable,
    otherwise Drift default.
  - Controllers invoke repositories; they do not maintain durable shadow state.
  - Simple display preferences may use the approved settings owner only when
    they are non-relational and included in backup policy.
- **Required tests:** restart persistence; no B01 SharedPreferences keys;
  single active pointer; derived active Program/effective profile; Riverpod
  recreation does not lose durable state.
- **Affected tasks:** B01-03, B01-07, B01-08A, B01-08B, B01-10.

## B01-D11 — Reminder scope and existing preference compatibility

- **Status:** Deferred to product owner; reminder implementation blocked.
- **Final rule:** The product owner must decide whether B01 “personal
  reminders” means passive exercise cues shown during execution or scheduled
  per-exercise notifications. If passive, B01-D15 satisfies the scope and no
  reminder table is added. If scheduled, reminders are typed Drift records with
  Backup v6 support and a single notification coordinator; they are not raw
  SharedPreferences.
- **Rationale:** The charter includes reminders, while the proposed plan
  silently deferred them. The current global workout reminder cannot represent
  per-exercise reminders. Source verification also found an existing key
  mismatch: Backup v5 allow-lists `prefRemindWorkout`, while
  `NotificationService` uses `pref_remind_workout`.
- **Invariants:** no duplicate reminder authority; timezone/permission/quiet-
  hours behavior is explicit if scheduled; Backup v5 accepts the historical key
  alias without inventing per-exercise reminders.
- **Required tests:** key-alias backup compatibility; conditional reminder DTO/
  restore tests if retained; notification timezone/permission tests if
  scheduled.
- **Affected tasks:** blocks reminder portions of B01-03, B01-07R, B01-10, and
  B01-12R. B01-10 owns the historical global-key alias compatibility.

## B01-D12 — Draft compatibility and sole finalization owner

- **Status:** Amended.
- **Final rule:** The backward-compatible draft codec/lifecycle repair is an
  independently testable prerequisite and does not wait for schema v15. New
  JSON in the existing `loggedSetsJson` field preserves RPE, set type, warm-up,
  notes, duration, distance, incline, and existing fields; old bare arrays parse
  with documented defaults. `WorkoutExecutionCompatibilityAdapter` becomes the
  sole owner of scheduled finalization. It writes session, sets, occurrence
  terminal state/event, and draft deletion in one Drift transaction.
- **Rationale:** Current `WorkoutPlayerScreen` calls `finishWorkout()` and
  deletes the draft before navigating to `WorkoutSummaryScreen`; the summary
  then saves the session separately and its button has no idempotency guard.
  Termination or double tap can lose or duplicate data.
- **Invariants:**
  - Invalid JSON returns a typed recoverable error and never marks an occurrence
    complete.
  - A draft remains until successful session finalization or explicit discard.
  - Resume does not recreate/freeze a different snapshot.
  - Completion is conditional on `inProgress`, with unique occurrence ancestry.
  - Duplicate completion returns the existing session; conflicting payload/
    command is rejected.
  - No controller, screen, and repository combination can each “finish” the
    same occurrence.
- **Required tests:** old/new codec matrix and defaults; malformed JSON; kill on
  player and summary; single/double completion; DB failure retains draft and
  `inProgress`; success deletes draft last; unscheduled regression.
- **Affected tasks:** B01-04, B01-06, B01-09, B01-10.

## B01-D13 — Backup v6 and Backup v5 import

- **Status:** Amended.
- **Final rule:** Backup v6 exports every accepted B01 user-owned table and all
  new session/set/draft ancestry fields, including stable exercise IDs,
  progression/repeat metadata, travel membership if approved, and reminder
  records if approved. A v5 restore first validates its legacy graph, restores
  legacy/custom records, assigns/resolves stable exercise IDs under B01-D01,
  and creates inactive legacy-import program snapshots inside the same database
  transaction. It never activates or schedules them.
- **Rationale:** Current restore already prevalidates core relationships,
  remaps auto-increment IDs, wraps DB writes in one transaction, and compensates
  SharedPreferences. The extension must preserve those guarantees.
- **Invariants:**
  - Unsupported future versions and invalid graphs fail before mutation.
  - Delete order is child-first; insert order is parent-first. Sessions reference
    occurrences, never the reverse, so no completion FK cycle is introduced.
  - Seeded exercise references resolve by stable catalogue ID; custom exercise
    UUIDs survive restore; unresolved references retain names/null IDs.
  - Legacy routines remain present in v6 while the adapter exists.
  - Derived calendar UI state is excluded.
  - Existing envelope, encryption, checksum, preference compensation, and
    single-DB-transaction behavior remain intact.
- **Required tests:** v5 import; v6 full graph round trip; seeded/custom stable
  ID restore; orphan/event/enum/date/zone rejection; child/parent order;
  injected rollback; unsupported v7; encrypted envelope regression.
- **Affected tasks:** B01-02, B01-03, B01-10, B01-14.

## B01-D14 — Repository and provider boundaries

- **Status:** Accepted with transaction clarification.
- **Final rule:** Keep separate `ProgramRepository`,
  `ProgramActivationCoordinator`, `CalendarRepository`,
  `EquipmentProfileRepository`, `ExercisePreferenceRepository`, and
  `WorkoutExecutionCompatibilityAdapter`. Repositories depend on Drift DAOs and
  pure domain services, not on each other in cycles. Activation/finalization
  coordinators own cross-aggregate transactions. Widgets never access Drift
  directly and controllers never reimplement scheduling/progression.
- **Rationale:** This prevents further expansion of the already broad
  `WorkoutRepository`.
- **Invariants:** one scheduling transition service; one active-version owner;
  one finalization owner; existing `WorkoutRepository` remains a legacy/history
  adapter only.
- **Required tests:** dependency construction test; controller delegates typed
  commands; no widget DB imports; targeted provider invalidation tests.
- **Affected tasks:** B01-05, B01-06, B01-07, B01-08A, B01-08B, B01-09,
  B01-13.

## B01-D15 — Exercise notes, cues, and setup preferences

- **Status:** Accepted with stable-ID amendment.
- **Final rule:** One Drift-owned per-exercise preference aggregate contains an
  optional general personal note, ordered personal cues, and ordered setup
  label/value pairs, referenced by stable exercise ID. Seeded catalogue cues
  remain on `Exercises`; performed-set notes remain on `WorkoutSets`. The
  current execution snapshot freezes displayed personal material at start.
- **Rationale:** This is the minimum non-overlapping model and can be shown in
  the current player without a redesign.
- **Invariants:** later preference edits do not alter an active/completed
  snapshot; no second general note system; unresolved legacy prescriptions may
  display no preferences until explicitly linked.
- **Required tests:** aggregate CRUD/order; snapshot freeze; seeded/personal/set
  note separation; player quick-panel widget.
- **Affected tasks:** B01-03, B01-07, B01-09, B01-10, B01-12.

## B01-D16 — Archive and delete rules

- **Status:** Amended.
- **Final rule:** A draft version may be hard-deleted only when it has never
  been published and has no references. Published and archived versions are
  never hard-deleted in B01. A Program may be hard-deleted only when it contains
  draft-only, unreferenced versions; otherwise it can only be archived. The
  current active version must be replaced or cleared before archiving.
- **Rationale:** Published versions, occurrences, snapshots, and sessions must
  retain queryable ancestry.
- **Invariants:** no cascade can delete occurrence/session history; archived
  versions remain readable and backed up; archiving does not hide their
  occurrences from calendar history.
- **Required tests:** guarded draft delete; published/program archive; active
  archive rejection; FK/history retention; Backup v6 archive round trip.
- **Affected tasks:** B01-03, B01-05, B01-10, B01-11A.

## Product-owner decisions required

1. **Skip interaction:** recommended explicit unselected choice, with “keep
   pending” first. Alternative is a preselected default. Only skip UI is
   blocked; both domain commands may be implemented.
2. **Travel mode:** recommended preserve program dates/order/deload and apply an
   equipment-profile override to explicitly previewed occurrences. Alternatives
   reduce volume, insert a temporary week, or consume/replace a week. Travel
   schema, coordination, backup, and UI are blocked.
3. **Personal reminders:** recommended interpret them as passive personal cues
   in the workout player for B01. Alternative is scheduled per-exercise
   notifications with typed Drift records and platform scheduling. Reminder
   schema/backup/UI are blocked.

Cross-week and cross-block rescheduling is an engineering rule, not a pending
product decision: it is allowed with confirmation and never changes program
ordinal.

## Explicit deferrals

No recovery-driven progression, automatic load/repetition adaptation,
supersets or advanced techniques, full cardio/mobility execution redesign,
automatic substitution engine, muscle-volume analytics, drag-and-drop
rescheduling, or other Batch 2+ execution models belong in B01.

## B01 Product Decisions

### B01-PD01 — Skip interaction

Status: Accepted

The skip action must require an explicit user choice. No option is selected by default.

Available choices:

1. Keep pending
2. Skip and advance
3. Cancel

“Keep pending” appears first, but the user must actively select it.

The application must never infer progression advancement from a generic skip action.

#### Invariants

- Closing the dialog causes no mutation.
- A skipped occurrence advances progression only when the user explicitly selects “Skip and advance.”
- “Keep pending” retains the occurrence without progression advancement.
- Repeated commands remain idempotent.

---

### B01-PD02 — Travel-week MVP

Status: Accepted

Travel mode preserves:

- Program dates
- Program order
- Program ordinals
- Existing deload weeks
- Existing scheduled occurrences

Travel mode temporarily applies a selected equipment profile to explicitly previewed occurrences within a chosen date interval.

Travel mode does not:

- Insert replacement program weeks
- Consume additional program weeks
- Shift scheduled dates automatically
- Reduce training volume automatically
- Rewrite normal program templates
- Advance progression by itself

Before applying travel mode, the user must preview affected occurrences and any unavailable exercises or proposed substitutions.

When travel mode ends, the normal equipment profile becomes active again.

#### Invariants

- Original program structure remains unchanged.
- Travel mode can be removed without losing the original plan.
- Occurrences outside the travel interval remain unaffected.
- Deload semantics remain unchanged.
- No exercise substitution is silently applied without user-visible preview.

---

### B01-PD03 — Personal reminders scope

Status: Accepted

In B01, personal reminders are passive workout-context cues stored with an exercise preference.

Examples include:

- Machine seat position
- Pin or cable position
- Setup instructions
- Personal technique cue
- Equipment reminder
- Load-specific reminder text

B01 does not include scheduled per-exercise notifications.

Passive cues may be shown:

- On exercise details
- Before the first set
- In a collapsible section during workout execution

#### Invariants

- Passive cues do not request notification permissions.
- Passive cues work offline.
- Passive cues participate in backup and restore.
- Seeded catalogue cues remain separate from user-created personal cues.
- Workout-specific set notes remain separate from reusable exercise preferences.
