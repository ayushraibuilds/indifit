# UX R07F-0 — Trust, Release Hygiene & Perceived Performance

**Status**: Implemented (this document is the plan and completion record)
**Branch**: `ux/r07f-release-cleanup`
**Baseline**: `e3f6a7c` (R07E review commit; merged to main at `a95523c`)
**Scope rule**: pre-release cleanup only — no hydration, PR engine, plan
lifecycle, media, or other feature work (explicitly deferred, §Non-goals).

Source audit: `docs/audit/UI_UX_PRODUCT_AUDIT.md` (GLM product audit).

---

## Audit authority rule applied

Every audit claim was re-verified against production code before any change.
Two claims were **stale** and produced no code change:

| Audit claim | Verification result |
|---|---|
| Photo-AI disclosure claims local processing while uploading | **Stale.** The pre-capture dialog (`ai_meal_logger_screen.dart:113-116`), privacy card (`privacy_disclosure_card.dart`), and estimate-review copy already state the photo is *sent* to an estimation service and deleted after processing. The roadmap note predates the privacy wave. Only residue fixed: "provider secrets" wording. |
| Dead-end workout-playlist setting | **Stale.** The Settings row is gated behind `b05PlaylistProviderRegistryProvider.providers.isNotEmpty` (`settings_screen.dart:39-41,201`) and the registry ships empty until product approval supplies entries — the row is already invisible. |
| "Double tap to inspect this meal" forces double-tap interaction | **Stale.** The meal row has `onTap: showDetails` (single tap). The string is the `Semantics.hint` for screen readers ("double tap" is standard VoiceOver/TalkBack activation phrasing). Left as-is. |
| `Occurrence <id> not found.` StateError reaches consumers | **Not reaching UI.** All calendar sheet catches route through `ProductFailurePresentation.fromError`, which never interpolates `error.toString()` (verified in `product_failure_presentation.dart`). The thrown message (with ID) stays internal for diagnostics. |

Confirmed and fixed: fabricated workout calories; terminology residue;
Saved Meals / Data Management / Privacy card legacy dark-only colors; blocking
startup work; router SharedPreferences-per-navigation; runtime Google Fonts
fetching; fat-macro water-drop icon; "Add Food" capitalization.

---

## Trust fixes

1. **No fabricated workout calories.**
   - Removed `_calculateCaloriesBurned()` (6.5 kcal/min), the "Active burn"
     metric tile, and `Burned: …` from the share text in
     `workout_summary_screen.dart`.
   - New records persist `estimatedCalories: 0` ("not estimated") — the column
     is non-nullable and no UI/backup reader displays it as a real value
     (verified: only backup round-trip touches it). Historical rows untouched.
   - The B02 summary path never displayed calories (verified) — nothing to fix.
2. **Photo-AI copy** verified truthful (see stale table); residue
   "Photos and provider secrets are not backed up." → "Photos are not
   included in backups." No invented retention claims added or removed.

## Consumer terminology corrected

| Before | After | Site |
|---|---|---|
| "Canonical workout" / row label | removed (legacy rows keep "Earlier workout") | `workout_history_screen.dart` |
| "Occurrence cancelled." | "Workout cancelled." | `occurrence_actions_sheet.dart:280` |
| "Occurrence history" | "Session history" | `occurrence_actions_sheet.dart:395` |
| "…could not reach the provider…" / "The online food provider is unavailable…" | "Online food search is unavailable…" | `food_search_screen.dart:598-602` |
| "Pasting a legacy backup remains available below." | "You can also paste an older IndiFit export below." | `data_management_section.dart` |
| "Optional: paste a legacy JSON backup..." | "Optional: paste an older IndiFit export…" | `data_management_section.dart` |
| "Backup format: vN" (schema version) | removed | `data_management_section.dart` |
| "imported provider" | "imported" | `protein_distribution_screen.dart:397` |
| "legacy record" | "earlier entry" | `protein_distribution_screen.dart:401` |
| "B02 strength draft is unavailable." ×2 | "This workout draft is unavailable." | `app_router.dart` |
| "No B02 strength draft is loaded." ×5 | "This workout draft is unavailable. Recover it or start over." | `b02_strength_execution_controller.dart` |
| "The current group is missing from the frozen draft." | "This workout is missing a required detail. Recover the draft and try again." | `b02_strength_execution_controller.dart:310` |
| "The typed activity draft is unavailable or legacy-shaped." | "This activity draft is unavailable. Try recovering it." | `b02_activity_controller.dart:174` |
| "Add Food" | "Add food" | `food_search_screen.dart:3133` |

## Light/dark theme fixes

Migrated off the dark-only legacy palette (`core/theme/colors.dart`) to
`B05SemanticColors`:

- `saved_meals_screen.dart` — cards, chips, buttons, error banner, delete
  dialog; destructive styling now uses the `danger.container/foreground` pair
  (the `danger.indicator` + white text pairing fails contrast in dark mode).
- `data_management_section.dart` — dialogs, snackbars, tinted action buttons,
  header; destructive confirms use the danger container/foreground pair.
- `privacy_disclosure_card.dart` — surfaces, text tiers, switch track.

Loading idiom (localized per §15): Saved Meals loading now renders content-
shaped `SkeletonCard`s instead of a full-screen `CircularProgressIndicator`;
success feedback uses the shared `indiFitSuccessSnackBar` primitive.

**Boundary guard**: `test/r07f_legacy_color_boundary_test.dart` freezes the
42-file legacy-importer baseline; any NEW import of `core/theme/colors.dart`
fails CI. The list may only shrink. No repo-wide migration attempted.

## Typography / offline font

- Outfit bundled as a variable font from the official `google/fonts`
  repository (`assets/fonts/Outfit-Variable.ttf`, Thin→Black wght axis).
- `pubspec.yaml` registers family `Outfit`; `app_theme.dart` applies
  `fontFamily: 'Outfit'` via `textTheme.apply`; explicit `FontWeight`
  overrides drive the variable axis. 28 `GoogleFonts.outfit().fontFamily`
  references across 6 screens replaced with `'Outfit'`; the `google_fonts`
  dependency and all test references removed.
- Typography is now fully network-independent. (Golden risk assessed: the
  bundled file is the same font the runtime fetcher used; goldens were
  re-run — see Validation.)

## Startup

Pre-frame (required): config validation, error hooks, SharedPreferences +
ProviderContainer, DB construction (migrations), notification plugin init
(timezone + tap handling), Sentry wrapping `runApp` (documented correct
integration — kept).

Post-frame (moved): `NotificationService.scheduleAllReminders(db)` (cancelAll
+ prefs + DB queries) and `AutoBackupService.performBackup(db)` now run from
`_runPostFrameBootstrap()` via `addPostFrameCallback` in `_IndiFitAppState`,
with logged failures. Trade-off: a user who kills the app within the first
frames after a cold start may skip one reminder rescheduling pass; the
resume lifecycle hook re-runs timezone/reschedule as before. No ms claims
made (not measured reproducibly).

## Router redirect

- `onboardingCompletedProvider` (already declared, previously unwired) is now
  seeded in `main()` from SharedPreferences and the GoRouter `redirect` is
  synchronous — no async preference I/O per navigation.
- Writers keep the gate current: onboarding completion/skip (existing),
  "Reset Onboarding Wizard" (now sets gate false), and restore/erase flows in
  Data Management (`_syncOnboardingGate` after `performRestore`,
  `deleteAllData`, reset). Backup restores that flip `onboarding_completed`
  are covered by the same sync.

## Settings cleanup

No dead-end found (playlist row hidden behind empty registry — documented
above). Data Management copy simplified per the table above; capability
unchanged (older-export restore still available).

## Today / Food / Training small fixes

- Fat macro icon: `water_drop_outlined` → `oil_barrel_outlined`
  (`today_daily_action_surface.dart:907`).
- "Add Food" → "Add food" (single occurrence).
- Training: only terminology (above). No router migration, week strip, or
  plan lifecycle (deferred).

## Accessibility / responsive

Copy changes preserve semantics (history-row Semantics label recomposed for
the optional source note). Destructive dialogs keep 48dp targets. No new
goldens for copy-only changes; Saved Meals light rendering is covered by a
widget test (colors + skeleton + empty/error states in light and dark).

## Tests added

- `test/r07f_release_cleanup_test.dart` — no-calorie regression (summary +
  share text), privacy-card truthfulness, forbidden-string source scan,
  offline-font assertions, startup pre/post-frame classification, router gate
  (redirect both directions, runtime gate value).
- `test/r07f_legacy_color_boundary_test.dart` — frozen legacy-color boundary.
- `test/r07f_saved_meals_light_mode_test.dart` — light/dark rendering, error
  banner contrast token, skeleton loading replaces spinner.

## Explicit deferrals (R07F-1+)

Hydration module + WaterLogs; PR celebration engine + shareable workout card;
finish/leave plan flow; Training week strip; go-router migration completion;
exercise media; rest-timer background presence; achievements expansion;
e1RM/PR-badge authority; god-file splits; MealTemplates retirement; legacy
player sunset; broad design-token migration (beyond the frozen boundary);
onboarding payoff screen; `MASTER_TRACKER`/roadmap re-baselining.

## Validation record

- **Focused R07F tests**: 18/18 passing
  (`r07f_release_cleanup_test.dart` 12, `r07f_legacy_color_boundary_test.dart`
  3, `r07f_saved_meals_light_mode_test.dart` 3).
- **Regression batches** (pre-suite): phase4 theme, widget, phase3 UI, B02
  execution controller, R07E progress (incl. goldens), R06 secondary goldens,
  R07D diary/search/recipes, R07C workout + reliability gate, W05 settings,
  B05 today surface — all passing.
- **Goldens**: 2 regenerated, both verified intentional before regeneration:
  - `ux_r07d_saved_meals_320_2x_light.png` — 0.68% diff confined to a single
    ~34px band (partial-nutrition notice color-token shift); layout and
    functional assertions unchanged. (Vision service was unavailable; the
    diff PNG was analyzed pixel-region-by-region programmatically instead.)
  - `ux_w06_workout_summary_dark.png` — 22.4% diff confined to the
    metric-card band (rows 429–648 of 390×844): the removed "Active burn"
    card with local reflow; header/footer regions clean.
  - The pre-existing user-owned `ux_r07d_multiselect_light.png` modification
    (documented 0.20% baseline mismatch from the R07D-2 review) was preserved
    untouched.
- **Test-contract update**: `b05_final_production_wiring_test.dart` now seeds
  `onboardingCompletedProvider: true` in its container — the router gate is
  synchronous and seeded from `main()`; the test previously relied on the
  redirect reading SharedPreferences itself.
- **dart format**: clean (500 files).
- **flutter analyze**: 0 issues.
- **git diff --check**: clean.
- **Full serial suite** (`flutter test -j 1`): see final report for exact
  counts.
- **iOS release build**: see final report.
