# C0B Visual, Semantics, and State Coverage Inventory

- Status: Frozen baseline
- Date: 2026-09-01
- Checked-in golden images: 111
- Golden-producing/inspection test files: 32

## Golden distribution

Filename-classified coverage currently includes:

| Dimension/state | Golden count | Notes |
|---|---:|---|
| Light theme | 35 | Today, Food, Training, Progress, profile/settings, visual system, and representative secondary flows |
| Dark theme | 62 | Broadest theme coverage, including execution, Food, Progress, calendar, notifications, Health, and education |
| Compact width / large text | 16 | `320`, `compact`, `2x`, or `1_5` fixtures |
| Empty / zero evidence | 10 | Today, Quick Workout, Progress, calendar, core empty state, and Training |
| Populated / mixed / partial evidence | 14 | Today, Progress, diary, and completion variants |
| Explicit loading | 1 | Calendar loading |
| Explicit failure/blocked/conflict | 3 | Food AI failure, notification blocked, Quick Workout conflict |

Counts use stable filename labels and are an inventory aid, not proof that every
unlabelled fixture lacks the state. Fourteen additional visual assets cover
muscle maps, exercise-family review, guides, and named states without an
explicit light/dark suffix.

## Domain coverage

| Domain | Representative golden/test families |
|---|---|
| Today/dashboard | `ux_r02_today_*`, `ux_w03_today_*`, R08 evidence/nutrition semantics tests |
| Food/diary/Saved Meals | `ux_r03_food_*`, `ux_r07d_*`, Saved Meal large-text and lifecycle tests |
| Training/execution | `ux_r04_*`, `ux_r07b_*`, `ux_r07c_*`, `ux_w06_workout_*`, R08 preview/review tests |
| Progress | `ux_r05_*`, `ux_r07e_*`, `ux_r08f_*`, sparse/mixed/populated repository tests |
| Onboarding/profile/settings | `ux_r06_*`, `ux_r08g1_*`, `phase5_*`, `ux_w06_*` |
| Exercise library/media | muscle-map, exercise-family, detail, picker, and media state tests |
| Calendar/plans | calendar empty/loading/actions goldens plus plan/calendar widget tests |

## Semantics and adaptability

- `ux_w06_visual_accessibility_certification_test.dart` is the broad visual,
  semantics, focus, text-scaling, theme, bottom-sheet, and reduced-motion gate.
- Reduced motion is explicitly injected with `MediaQueryData.disableAnimations`
  across Today, Food, education, Health, Progress, Data Management, and the W06
  certification suite.
- Compact/large-text protection exists for each primary tab and the six fragile
  flows listed in `C0B_FRAGILE_FLOW_MATRIX.md`.
- Semantics tests cover labelled actions, non-drag alternatives, focus order,
  state announcements, chart summaries, error/retry actions, and danger actions.

## Loading, empty, error, retry, and offline behavior

Outcome tests provide broader state coverage than golden filenames:

- loading/empty/error/retry: Saved Meals, Recipes, Food search, Progress,
  calendar, Health, notifications, backup inspection/restore, coaching, and
  product failure presentation;
- offline: privacy enforcement blocks network/telemetry, local Food remains
  searchable, downloaded/local education and media behavior is explicit, and
  workout/plan/nutrition persistence tests have no network dependency;
- strict-offline media and optional connected assistance fail into local or
  unavailable states without mutating canonical records.

There is no golden literally named `offline`. Offline is primarily a policy and
behavior contract, so it is protected through service/controller/widget tests
rather than a visually distinct app mode.

## Recorded gaps and disposition

1. Loading and failure goldens are sparse compared with behavior tests. Add a
   golden only when later extraction changes a high-risk screen owning that
   state; do not manufacture a full Cartesian matrix.
2. Light-theme coverage is smaller than dark-theme coverage. Each mechanical
   split must select at least one representative light and dark contract for the
   affected screen.
3. Reduced motion is strongly behavior-tested but not named consistently in
   golden files. Preserve `disableAnimations` cases during test relocation.
4. Offline has no separate visual identity by design. Future connected features
   need explicit pending/last-success/error states without turning normal
   offline use into an error screen.
5. Generated diff images under `test/failures/` are test-run artifacts, not
   approved golden contracts, and remain excluded from cleanup commits.

## Mechanical-refactor gate

Before splitting a presentation hotspot, select the smallest relevant set from
this inventory covering its normal state plus any high-risk sparse/error state,
one compact/large-text case, semantics, and both themes where materially
different. Existing approved goldens must not be regenerated merely because a
file moved.
