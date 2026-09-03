# C0B Fragile-Flow Characterization Matrix

- Status: Core weak-flow matrix frozen; broader visual-state inventory remains
- Date: 2026-09-01

| Flow | Frozen observable outcomes | Primary tests |
|---|---|---|
| Saved Meals | typed food/recipe identity, duplicate/order preservation, pinned recipe version, fast re-log, transient edit-before-log, delete lifecycle, diary-history preservation, loading/error/detail/editor UI, large text | `ux_r07d_recipes_saved_meals_test.dart`, `r08d6_saved_meals_test.dart` |
| Recipes | create/publish, immutable successor edit, archive with historical snapshots, search/empty/error/retry, unresolved identity, nutrition preview/warning acknowledgement, persistence confirmation | `ux_r07d_recipes_saved_meals_test.dart`, `r08d7_recipes_consumer_test.dart` |
| Plan authoring/editing | exact ordered content, reopen/edit, validation, stable exercise identity, save failure retaining edits, labelled actions at large text | `r08c4_plan_builder_test.dart`, `program_authoring_controller_test.dart` |
| Data Management | danger-zone separation, consequence copy, export/restore entry points, destructive confirmation, failure visibility, narrow/large-text behavior | `r08g7_settings_danger_zone_deep_screen_test.dart`, backup transactional matrix |
| Today/dashboard | action-before-context hierarchy, date context, unavailable-module omission, future/narrow/large-text behavior, semantic and keyboard-accessible module customization | `r08e3_today_foundation_test.dart`, `b05_dashboard_module_customization_panel_test.dart` |
| Notifications | persisted schedules, invalid-value fallbacks, recurring weekday behavior, quiet-hour deferral, evidence-aware skip, permission denied/failure states, factual destinations, narrow/large-text behavior | `phase5_notifications_test.dart`, `r08g5_notifications_quiet_hours_test.dart` |
| Onboarding keyboard | form actions with TextInputAction progression, large-text accessibility at 2x text scale, non-obstruction of page CTAs, invalid measurement rejection | `rc_m1_onboarding_keyboard_test.dart` |
| Offline starter plans | fresh-install availability without network, 8 reviewed starter plans resolving to canonical exercise UUIDs, Gym/Home discovery, non-mutating copy customization | `rc_m1_offline_starter_plan_library_test.dart` |
| Food search relevance | concept matrix matching for common Indian staples (roti, chapati, dal, rice, etc.), de-prioritization of raw/preparation variants, bounded ranking execution | `rc_m1_food_search_relevance_test.dart` |
| Transient feedback | 4-second auto-dismiss window, rapid operation replacement without duplicate snackbars, non-leaking across screen navigation | `rc_m1_food_logging_snackbar_test.dart` |

## Verification

- Nine focused current-flow files: 62/62 passed.
- Saved Meal/Recipe lifecycle and edit-before-log file: 11/11 passed.
- Four V1 Release Candidate fragile-flow files: 25/25 passed.
- Total weak-flow matrix: 98/98 passed.

These tests protect product outcomes and user-visible state rather than private
widget decomposition. They are the minimum focused gate for later deletion or
mechanical extraction in the affected areas.

## Remaining C0B visual inventory

Before C0B closes, catalogue the exact goldens and semantics coverage for
light/dark, compact widths, large text, reduced motion, loading, empty, error,
retry, and offline states. Missing combinations should be recorded explicitly;
the gate does not require a Cartesian product when a state is irrelevant.
