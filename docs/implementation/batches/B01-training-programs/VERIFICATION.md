# B01 Critical Architecture Verification

Baseline: commit `78851f6`

Review date: 2026-07-29

Scope: architecture gate only; no feature implementation performed.

## Gate verdict

**Passed with product decisions.**

B01 is safe to begin only with the three prerequisite tasks listed below.
Schema v15, travel, reminders, backup v6 implementation, and feature UI are not
authorized until the two schema-affecting product decisions are recorded. The
skip product decision blocks only the skip interaction, not the underlying
state-machine commands.

The gate passes because every engineering-critical ambiguity now has a final
rule in `DECISIONS.md`: stable exercise identity, inactive legacy imports,
single active-version ownership, immutable versioning, a complete idempotent
state machine, progression disposition, civil-date/timezone semantics, atomic
execution finalization, backup ordering, and repository boundaries.

## Repository evidence verified

- `lib/data/database/tables/workout_tables.dart` confirms local auto-increment
  exercise IDs, name-only routine/set relationships, no program ancestry, and a
  single JSON draft row.
- `lib/data/repositories/workout_repository.dart` confirms routine edits
  delete/recreate children in place, `getSavedRoutines()` has no ordering or
  durable active selection, history uses exact names, and session logging is a
  separate transaction.
- `lib/features/workout_player/workout_player_controller.dart` confirms draft
  JSON drops RPE, set type, warm-up, notes, duration, distance, and incline.
- `lib/features/workout_player/workout_player_screen.dart` deletes the active
  draft before navigating to the summary; the summary then independently calls
  `logSession`, so termination can lose data and duplicate taps can duplicate
  sessions.
- `lib/features/dashboard/dashboard_screen.dart` directly parses the old bare
  array and restores only basic set fields; malformed JSON is caught only by a
  broad screen-level error path.
- `lib/core/backup/backup_schema.dart` verifies Backup v5 prevalidation, custom
  exercise ID remapping, one Drift restore transaction, SharedPreferences
  compensation, and rejection of unsupported newer versions.
- `test/db_migration_test.dart` creates a fresh memory database; it is not a
  real v14-file upgrade test. `test/backup_restore_transaction_test.dart`
  verifies rollback and orphan rejection but has no B01 graph.
- `pubspec.yaml` already includes TZDB support through `timezone` and
  `flutter_timezone`.
- The current exercise asset has 140 rows, five equipment labels, and no exact
  case-folded duplicate names, but that does not make auto-increment IDs stable
  across custom-exercise restore or future catalogue renames.
- `NotificationService.prefRemindWorkout` is `pref_remind_workout`, while the
  Backup v5 preference allow-list contains `prefRemindWorkout`; relying on the
  existing global reminder without reconciliation would not round-trip the
  authoritative key.

## Decision-gate inventory

All original `SOL-GATE REQUIRED` items were reviewed. Final results are:

| Area | Result | Decision |
|---|---|---|
| v15 / Backup v6 ownership | Amended | B01-D01, D10, D13 |
| Legacy routine migration | Amended | B01-D02 |
| Program versioning/activation | Amended | B01-D03, D04, D16 |
| Occurrence transitions/idempotency | Amended | B01-D05, D06 |
| Local date/timezone | Amended | B01-D08 |
| Exercise identity | Amended | B01-D01 |
| Execution ancestry/snapshot | Amended | B01-D12 |
| Travel progression | Product-deferred | B01-D09 |
| Reminders | Product-deferred | B01-D11 |
| Repository/provider boundaries | Accepted | B01-D14 |
| Notes/setup preferences | Accepted | B01-D15 |

## Blocking findings

### Product blockers

1. **Travel behavior is unresolved.** The canonical roadmap assigns the
   preserve/reduce/insert/replace choice to the product owner. This affects the
   v15 travel schema, Backup v6 graph, controllers, and UI.
2. **Reminder scope is unresolved.** Passive cues require no reminder table;
   scheduled per-exercise notifications require Drift records, backup,
   timezone, permission, and quiet-hours behavior. This also affects v15.
3. **Skip interaction default is unresolved.** Both domain commands are
   approved, but calendar UI must not silently choose hold or advance.

### Mandatory engineering amendments, now resolved

These are not pending decisions, but implementation that ignores them fails the
gate:

- Do not use `Exercises.id` as the canonical B01 identity.
- Do not auto-activate a migrated routine or create migration-dated
  occurrences.
- Do not store active state in both ProgramVersion lifecycle and settings.
- Do not treat partial/held-skip status as automatic progression.
- Do not finalize sessions, occurrences, and drafts in separate owners.
- Do not rely on UTC-midnight date queries.
- Do not delete legacy routine tables in B01.
- Do not ship v15 without a real v14 upgrade fixture and rollback test.

## Tasks safe to begin immediately

| Order | Task | Why safe | Implementation model | Required review |
|---|---|---|---|---|
| 1 (parallel) | B01-01 — identity/equipment migration fixtures | Read-only/deterministic inputs; no unresolved product behavior. | Gemini Flash | Sol High |
| 1 (parallel) | B01-02 — real v14/v5 fixture harness | Test foundation only; does not commit schema choices. | Gemini Flash | Sol High |
| 1 (parallel) | B01-04 — backward-compatible draft codec/lifecycle repair | Isolated existing data-loss fix; no v15 dependency. | Gemini Flash | Sol High |

B01-04 must remain bounded to the current draft JSON and legacy save lifecycle.
Occurrence columns and scheduled finalization belong to B01-09.

## Tasks safe after prerequisites

| Wave | Tasks | Prerequisite |
|---|---|---|
| 2 | B01-03 | B01-01/B01-02 Sol approval plus travel and reminder product decisions |
| 3 | B01-05, B01-07 | B01-03 |
| 4 | B01-06 | B01-03 and B01-05 |
| 5 | B01-08A, B01-09 | B01-06; B01-09 also needs B01-04/B01-07 |
| 6 | B01-13 | B01-05 and B01-09 |
| 7 | B01-10 | All durable conditional entities plus B01-06/B01-09 |
| 8 | B01-11A, B01-12 | Calendar/execution/compatibility dependencies; skip UI decision for B01-11A |
| 9 | B01-14 | Every applicable task and platform/manual evidence |

## Blocked tasks

| Task | Blocker |
|---|---|
| B01-03 | Travel and reminder decisions can change the one-time v15 graph. |
| B01-08B | Travel behavior not selected. |
| B01-10 | Cannot freeze Backup v6 until travel/reminder entities are known and execution ancestry exists. |
| B01-11A skip interaction | Skip default/explicit-choice decision not recorded. Other UI also awaits dependencies. |
| B01-11B | Travel behavior/controller not selected. |
| B01-07R and B01-12R | Conditional on retaining scheduled per-exercise reminders. |
| B01-14 | Final verification necessarily waits for the full batch. |

Calendar UI must not begin before B01-03 and B01-06 freeze schema and
occurrence semantics.

## High/critical and Sol-routed task inventory

| Task | Risk | Sol role |
|---|---|---|
| B01-01 | High data quality | Required identity-fixture review |
| B01-02 | High test foundation | Required fixture/rollback review |
| B01-03 | Critical data loss | Sol High implementation |
| B01-04 | High user data loss | Required codec/lifecycle review |
| B01-05 | High invariants | Terra implementation; lifecycle contract already gated |
| B01-06 | Critical scheduling semantics | Sol High implementation |
| B01-08A | High scheduling | Terra implementation against gated state machine |
| B01-08B | High multi-domain | Terra implementation; Sol review |
| B01-09 | High compatibility | Terra implementation; Sol atomicity/idempotency review |
| B01-10 | Critical portability | Sol High implementation |
| B01-07R | High platform/state, conditional | Terra implementation; Sol review |
| B01-13 | High regression | Terra implementation; Sol authority/compatibility review |
| B01-14 | Critical final verification | Sol High |

No critical task was left with Flash-only ownership. Flash tasks are bounded to
deterministic fixtures, codecs, CRUD, and clearly specified UI/tests.

## Product-owner decisions required

| Question | Recommended default | Alternative | User-visible consequence | Blocked? |
|---|---|---|---|---|
| How should skip choose progression? | Show an explicit unselected choice; list “Keep this workout pending” first. | Preselect hold or advance. | Determines whether a skipped workout remains the next required ordinal. | Blocks skip UI only; domain supports both. |
| What is the B01 travel-week behavior? | Preserve dates/order/deload and apply a temporary equipment profile to explicitly previewed occurrences. | Reduce volume, insert a non-consuming week, or replace/consume a week. | Determines whether the normal plan changes and which workouts/equipment appear during travel. | Yes: travel schema, backup, coordination, UI, and B01-03. |
| What does “personal reminders” mean in B01? | Passive personal cues/setup notes displayed during workout; no scheduled per-exercise notification. | Scheduled per-exercise reminders. | Passive has no alerts; scheduled adds permissions, quiet hours, timezone behavior, and reminder CRUD. | Yes: reminder schema/backup/UI and B01-03. |

Cross-week/block rescheduling does not require product input: it is accepted
with confirmation, preserves original ancestry, and never changes program
ordinal.

## Exact implementation order

1. B01-01, B01-02, and B01-04 in parallel.
2. Record travel and reminder decisions.
3. B01-03.
4. B01-05 and B01-07 in parallel.
5. B01-06.
6. B01-08A and B01-09 in parallel; B01-08B after the travel decision.
7. B01-07R only if scheduled reminders are retained.
8. B01-13.
9. B01-10.
10. B01-11A and B01-12; then B01-11B/B01-12R when applicable.
11. B01-14.

## Implementation entry criteria

The unrestricted B01 implementation gate opens only when:

- B01-01 and B01-02 receive Sol approval;
- the travel and reminder product decisions are recorded;
- B01-03 implements `DECISIONS.md`, not conflicting Terra proposals;
- no implementation introduces a second active owner, a fuzzy exercise match,
  migration-time activation, or split completion transaction.
