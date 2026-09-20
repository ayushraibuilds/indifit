# C0B Navigation and Payload Contract

- Status: Frozen baseline
- Date: 2026-09-01
- Root router: 43 declared `GoRoute` paths
- Local routes: 51 `MaterialPageRoute` constructions across 18 files
- Characterization: `test/c0b_route_contract_test.dart`

## Parameter and fallback matrix

| Route | Input contract | Invalid/missing behavior |
|---|---|---|
| `/food` | optional `mealType`; breakfast/lunch/dinner/snack(s), case-insensitive; optional strict `yyyy-MM-dd` civil date | invalid values become neutral Food context; no current-day substitution by parser |
| `/food/estimate-review` | non-empty `estimateId` query | `No estimate selected.` |
| `/food/recipes/edit` | optional `recipeId` and `draftVersionId` queries | omitted values open create/default editor behavior |
| `/settings/dietary-constraints/review` | optional `foodId` or `recipeVersionId` | review screen owns unavailable/selection behavior |
| `/workout-history/:sessionId` | positive integer SQLite ID | `Workout details are unavailable.` |
| `/activity-history/:sessionId` | positive integer SQLite ID | `Activity details are unavailable.` |
| `/activity-create` | optional supported non-strength activity `type`; optional strict civil `date`; optional positive integer `draftId` | any explicitly supplied invalid value yields `Activity entry is unavailable.`; absent type defaults to running |
| `/program-author` | optional `programId` and `versionId` | omitted values open create mode |
| `/program-review/:versionId` | required opaque version ID | unmatched empty segment never enters builder |
| `/calendar` | optional raw local-date query | Calendar owns validation/presentation |
| `/plan-overview/:versionId` | required opaque version ID | unmatched empty segment never enters builder |
| `/plan-library/:programId` | required opaque program ID | unmatched empty segment never enters builder |
| `/equipment-profile-editor` | optional `profileId` | omitted value opens create mode |
| `/exercise-preference-editor` | optional `stableId`; optional `rawName` | missing name displays `Exercise`; screen owns unavailable stable identity |

`parsePositiveRouteId` now centralizes the already-established positive-ID
rule for workout history, activity history, and activity draft routes without
changing their behavior.

## `state.extra` contracts

| Route | Accepted payload | Fallback |
|---|---|---|
| `/workout-player` | map; preferred `scheduledLaunch: WorkoutPlayerLaunchData`, otherwise `routineName` and `List<RoutineExercise>` | absent map opens empty `Workout`; wrong typed map members retain existing cast behavior |
| `/workout-summary` | map containing optional name, elapsed seconds, `List<WorkoutSetsCompanion>`, occurrence ID, command ID | absent map opens zero-duration empty `Workout`; wrong typed members retain existing cast behavior |
| `/b02-strength-player` | `WorkoutExecutionRouteData`, `B02StrengthExecutionLaunch`, or compatibility map containing typed `launch` | `This workout draft is unavailable.` |
| `/b02-strength-summary` | same typed execution boundary | `This workout draft is unavailable.` |

The two legacy workout map routes remain compatibility surfaces. C0B does not
silently redesign their runtime type-error behavior; their typed replacement is
a later routing task.

## Notification/deep-link destinations

| Payload | Destination |
|---|---|
| `workout` | `/training` |
| `meal_lunch` | `/food?mealType=lunch` |
| `meal_dinner` | `/food?mealType=dinner` |
| `meal_` | `/food` |
| `evening_nudge` | `/` |
| `weekly_report` | `/progress` |
| unknown/empty | ignored |

Notification navigation uses `router.go`, so it replaces the current matched
location rather than adding an arbitrary nested stack. Compatibility redirects
remain listed in `C0B_CONTRACT_BASELINE.md`.

## Local `MaterialPageRoute` inventory

| File | Count | Classification |
|---|---:|---|
| `dashboard/dashboard_screen.dart` | 5 | execution resume/recovery children plus Achievements and nutrition targets |
| `dashboard/main_navigation_scaffold.dart` | 1 | initial meal child task with a result |
| `dashboard/today_daily_action_surface.dart` | 1 | meal-detail child |
| `dashboard/widgets/dashboard_meal_section.dart` | 5 | meal acquisition/logging children |
| `dashboard/widgets/quick_log_bottom_sheet.dart` | 1 | bottom-sheet handoff to Food child |
| `education/learn_screen.dart` | 1 | lesson detail child |
| `exercise_library/exercise_details_sheet.dart` | 1 | exercise history child |
| `exercise_library/exercise_library_screen.dart` | 1 | duplicated app destination (`/learn`) |
| `food_log/ai_meal_logger_screen.dart` | 1 | dormant AI caller; manual Food child compatibility |
| `food_log/barcode_scanner_screen.dart` | 1 | custom-food editor child returning a result |
| `food_log/food_search_screen.dart` | 12 | tightly scoped Food editors, scanners, detail, Saved Meal/Recipe, and edit-result children |
| `food_log/saved_meals_screen.dart` | 3 | editor/detail/legacy-read-only children returning results |
| `food_log/saved_recipe_log_screen.dart` | 5 | recipe create/edit children returning refresh results |
| `profile/profile_screen.dart` | 1 | onboarding replacement when no profile exists |
| `progress/progress_screen.dart` | 6 | Achievements/history/targets/detail children; some duplicate app destinations |
| `settings/settings_screen.dart` | 1 | generic settings-owned child helper |
| `settings/widgets/data_management_section.dart` | 1 | destructive reset to onboarding; removes prior stack |
| `training/training_screen.dart` | 4 | execution, preview, and customization child tasks with refresh on return |

The 51 local routes are not a blanket migration list. Editors, previews,
scanners, sheets-to-tasks, and result-returning children should remain local
unless product navigation changes. Duplicated true app destinations—Learn,
Achievements, Workout History, and onboarding entry—are candidates for the
later typed routing phase.

## Back and replacement behavior

- `context.push` and ordinary `Navigator.push` retain the caller and return a
  result where the child contract requires one.
- Workout completion uses `pushReplacement` so Back does not return to the
  completed legacy player.
- Program review uses `context.go` when returning to the author route after a
  lifecycle action, replacing the review location.
- Missing-profile onboarding uses `pushReplacement`.
- destructive data reset uses `pushAndRemoveUntil(..., false)`, so erased
  content cannot be reached with Back.
- top-level tab and notification destinations use `go`, while details and
  authoring tasks generally use `push`.

## Verification

The route contract test freezes:

- all 43 root paths and order;
- eight compatibility redirects;
- onboarding redirect truth table;
- Food/activity/positive-ID parsing;
- factual notification payload destinations.
