# UX-R07C Workout Experience Redesign Plan

## Baseline and authority

- Branch: `ux/r07c-workout-experience`
- Starting commit: `d6e42a09795cc0525aecae5a83814751e2bf985c`
- Expected parent: `ux/r07c-reliability-gate`
- B01 owns programs, versions, occurrences, schedules, frozen prescriptions,
  and planned-workout ancestry.
- B02 owns strength drafts, performed evidence, set roles/load basis, grouped
  sets, substitutions, warm-ups, rest timing, finalization, and recovery.
- This plan changes consumer presentation and interaction composition only.

## Production surface map

| Surface | Production route/widget/controller | Shared Quick/planned boundary |
| --- | --- | --- |
| Training landing | `/training` → `MainNavigationScaffold` → `TrainingScreen`; `trainingLandingSnapshotProvider` reads `CalendarReadRepository` and `WorkoutRepository` | Reads both scheduled occurrences and the single B02 active draft |
| Current plan | `RoutineDisplayScreen`, `RoutineEditorScreen`, `RoutineDisplayScreen` plan-management entry points | B01 plan reads/writes; not a Quick draft |
| Planned preview | `ProgramCalendarScreen`, `CalendarOccurrenceReadItem`, `WorkoutContextualLauncher` | B01 occurrence + frozen prescription, then shared B02 launch |
| Quick Workout entry | `/quick-workout` → `QuickWorkoutScreen`; `quickWorkoutActiveDraftProvider`; B02 compatibility adapter | Starts an occurrence-less B02 draft, never a B01 occurrence |
| Shared workout player | `/b02-strength-player` → `B02StrengthPlayerScreen`; `b02StrengthExecutionScreenControllerProvider` | Same player for Quick and planned `B02StrengthExecutionLaunch` |
| Set logging | `B02StrengthPlayerScreen._record` → `B02StrengthExecutionController.recordSet` → `B02StrengthExecutionDraftService` | Shared B02 mutation; planned writes retain prescription ancestry |
| Exercise switching | Shared player slot selection (`_selectedSlotId`) and exercise chips/dropdown | Quick slots remain dynamic; planned slots remain frozen |
| Substitution | Shared player exercise actions → `QuickExercisePicker`; controller records actual identity only for permitted planned substitution | Planned substitution is locked after performed sets; Quick substitutions affect the next set |
| Rest timer | Shared player `_RestCard` → `B02StrengthExecutionController` + `B02RestCoordinator`; legacy `RestTimerBottomSheet` remains for the legacy player | B02 wall-clock rest authority and grouped-set scope are unchanged |
| Exercise detail/guidance | `ExerciseDetailsSheet` → `ExerciseHistoryScreen` and B05 education provider | Detail presentation only; reads catalog/education/history authorities |
| Workout review | `/b02-strength-summary` → `B02StrengthSummaryScreen`; legacy `/workout-summary` remains for legacy player | Shared B02 draft review; finalization uses the stable command ID |
| Successful completion | `B02StrengthSummaryScreen` → `B02StrengthExecutionController.finalize`; legacy `WorkoutSummaryScreen` for legacy flow | B02/B01 finalization remains authoritative and idempotent |
| Performance/history | `ExerciseHistoryScreen`, `WorkoutRepository.getExerciseHistory`, progress history projections | Uses performed evidence; missing data is not coerced to zero |
| Active-draft recovery | `TrainingScreen` and `QuickWorkoutScreen` preflight/recovery → `B02StrengthExecutionController.recover`, `discardDraft` | One safe active draft; recovery actions never expose internal IDs or exceptions |

## Shared presentation changes

1. Recompose `TrainingScreen` around one dominant daily action: Resume when an
   active draft exists, today’s planned workout when actionable, otherwise
   Quick Workout. Keep plan, upcoming, recent history, calendar, and exercise
   library as compact secondary paths.
2. Replace the player’s form-first body with a compact execution hierarchy:
   exercise navigation, current exercise, truthful last-session/recommendation
   context, completed sets, Weight + Reps, Log Set, then progressive disclosure
   for RPE, set type, cues, tools, substitution, and finish.
3. Keep one shared player implementation for Quick and planned launches. Quick
   keeps add/remove/dynamic exercise actions; planned keeps frozen slots,
   ancestry, grouping, and canonical substitution restrictions.
4. Make rest a clearly bounded state with countdown, context, -15/+15, custom
   adjustment, and Skip, while delegating all mutations and wall-clock behavior
   to the existing B02 coordinator.
5. Make review/completion structured by exercise, preserve missing-load
   evidence, show only canonical metrics, and celebrate only genuine canonical
   PR evidence.
6. Recompose exercise detail into Guide and Performance, remove duplicate
   education/checklist presentation and unavailable-media copy, and make small
   history datasets useful without empty charts.

## Verification plan

- Add shared presentation tests for landing, active player, rest, summary,
  Guide, and Performance at 320/390/430 widths and 1.0×/1.5×/2.0× text.
- Add representative goldens for Quick/planned active sets, rest, normal and
  PR completion, Guide, and Performance; visually inspect generated images.
- Retain and run existing R7A/R7B/R07C, B01, and B02 lifecycle tests covering
  draft recovery, set evidence, grouping, rest, substitution, ancestry,
  retry/idempotency, and finalization.
- Run formatting, `flutter analyze`, `git diff --check`, the full serial test
  suite, and a signed iOS Release build if the environment permits it.

## Out of scope

No schema, B01/B02 authority, database, exercise-variant deduplication, AI
plan generation, third-party media, nutrition, onboarding, travel,
equipment-profile, settings, monetization, or social changes.

## Implementation and validation record

- Implemented the shared R07C player hierarchy in
  `B02StrengthPlayerScreen`: exercise strip, elapsed/status header, truthful
  target context, dominant Weight + Reps logging, progressive disclosure for
  RPE/set type/warm-ups, performed-set evidence, Quick add actions, bounded
  rest controls, and secondary review/finish actions.
- Implemented compact Training landing priority surfaces, structured B02
  review/completion metrics, and Guide/Performance exercise detail language.
- Added five representative R07C visual tests/goldens for Quick, planned,
  rest, Guide, and Performance states. Existing Training, Quick, completion,
  and exercise-detail goldens were updated for the new presentation contract.
- `dart format` and `flutter analyze --no-pub` pass. Focused R04/R07B/R07C,
  B02 activity, and R07C presentation validation passed (45 tests in the
  complete focused run; the post-format rerun also passed).
- The full serial suite reached 91 passing tests before the shared machine
  `/var` volume exhausted space while compiling `b03_leucine_test.dart`; the
  runner then stalled in an existing onboarding teardown. The no-codesign
  iOS release build reached Xcode but failed because the Xcode build database
  reported the same disk-full condition. No product failure was reported by
  either run.
