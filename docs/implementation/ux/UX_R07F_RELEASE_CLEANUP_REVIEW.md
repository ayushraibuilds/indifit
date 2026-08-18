# UX R07F-0 — Trust & Release Cleanup Review (Review-and-Resolve)

**Status**: Reviewed & resolved
**Branch**: `ux/r07f-release-cleanup`
**Implementation commit under review**: `9b380a0`
**Baseline**: `e3f6a7c` (R07E review) / `a95523c` (main merge point) — both verified in ancestry
**Review commit**: see §Review commit below
**Scope**: fresh trust / product / correctness / release-readiness pass over R07F-0. No physical-device testing (deferred to product owner per review charter).

---

## Baseline

- Branch `ux/r07f-release-cleanup`, HEAD = `9b380a0` (the implementation commit itself).
- `9b380a0`, `e3f6a7c`, `a95523c` all verified in HEAD ancestry.
- User-owned dirty working-tree changes (old-dashboard screenshot deletions, `ios/Flutter/Release.xcconfig`, pre-existing `ux_r07d_multiselect_light.png` + `ux_r07d_recipes_saved_meals_test.dart` modifications, untracked reference/audit docs) were preserved untouched and excluded from the review commit.

## Audit claims — verified classifications

| Audit claim | Review verdict |
|---|---|
| Photo-AI disclosure claims local processing while uploading | **Stale — confirmed.** Full path traced: permission primer (`ai_meal_logger_screen.dart:113-116`) → privacy-policy gate (`isImageUploadAllowed`) → multipart POST to `AppConfig.backendUrl` (HTTPS default) → enforced local temp-file cleanup (estimate cannot be saved unless the temp photo is deleted) → review copy. Every visible string states the photo is *sent* to an estimation service; none claims on-device processing, remote deletion, retention duration, or unproven encryption. "Secure servers" is supportable by the HTTPS-only default endpoint. |
| Dead-end playlist setting | **Stale — confirmed.** Row gated behind `b05PlaylistProviderRegistryProvider.providers.isNotEmpty` (`settings_screen.dart:39-42`); registry ships empty, so the row (and its section) is not rendered. No empty divider remains (section is conditionally included). |
| "Double tap to inspect this meal" | **Stale — confirmed.** String is the `Semantics.hint` on a single-tap row; "double tap" is standard VoiceOver/TalkBack activation phrasing. Correctly left as-is. |
| `Occurrence <id> not found.` reaches consumers | **Not consumer-reachable — confirmed.** `ProductFailurePresentation.fromError` never interpolates `error.toString()` (explicitly documented at `product_failure_presentation.dart:94`); the ID-bearing `StateError` stays internal. Documented, not changed. |
| Fabricated 6.5 kcal/min calories | **Confirmed & fixed in 9b380a0.** No `6.5`/`kcal/min`/`Active burn` string or calculation remains in reachable production code (summary display, share text, new-record persistence all verified). |
| Terminology residue / legacy-color screens / runtime font fetching / blocking startup / per-navigation prefs I/O | **Confirmed & fixed in 9b380a0**, with review additions below. |

## Trust / Photo AI

Truthful. Disclosure says exactly what production does: send to the approved estimation service, local temp photo deleted after processing (enforced — save is blocked if cleanup fails), photos excluded from backups (backup payloads are DB+prefs JSON only). Nothing added for legal-sounding completeness. The "provider secrets" residue is gone ("Photos are not included in backups").

## Workout Metric Truthfulness

- Legacy summary (`workout_summary_screen.dart`): volume + duration only; no calorie tile; share text has no burn line; persistence passes `calories: 0` with an explicit "not estimated" comment.
- B02 strength completion (`b02_strength_execution_repository.dart`): persists `estimatedCalories: 0` — same sentinel.
- No current B02 summary, workout history, activity history, or Progress surface displays `estimatedCalories` (Progress calorie figures are nutrition-side). HealthKit/Health writes are import-side only; no caller writes fabricated calories to Health.
- Historical rows untouched (immutable execution facts), and no UI renders their legacy values.

## `estimatedCalories` Storage Semantics

**Verdict: deprecated compatibility sentinel, now explicit and structurally guarded.**

The implementation kept `0` for new records (schema column is non-nullable; no migration launched — correct per review constraints), but the sentinel was previously documented only in a screen comment: a future reader could have treated `0` as a known-zero measurement, or summed legacy non-zero rows as evidence. Review resolution (smallest coherent correction, review option A+B):

- The column now carries an explicit **NON-AUTHORITATIVE contract** in `workout_tables.dart`: `0` = "not estimated" for local completions; only Health-import rows (provenance-linked) may carry provider values; historical rows must never be presented as factual evidence.
- `B02TypedActivityHistoryRecord` now exposes **`providerEstimatedCaloriesKcal`** — the only trusted read: non-null only for health imports with a real provider estimate (`isImported && > 0`). An imported `0` can never masquerade as a known-zero measurement, and legacy fabricated non-zero rows cannot pass as provider evidence.
- Write sites (`completeDraft`, `logSession`, B02 strength completion) document the sentinel contract.
- Regression tests added (`b02_activity_repositories_test.dart` → "estimated calories compatibility contract"): manual completion persists 0 and accessor is null; import 350 → accessor 350; import 0 → accessor null.

## Consumer Terminology

All reported corrections verified in production sources (forbidden-string source scan now part of `r07f_release_cleanup_test.dart`, extended by this review). Review found **one missed leak family** — the manual activity creation screen (`b02_activity_creation_screen.dart`) still rendered internal jargon: `'Start typed draft'`, `'Offline-first typed activity'`, `'Required for every typed modality'`, `'Activity saved to typed history.'`, `'Your typed fields are still local and editable.'`, and raw storage values (`activityType.dbValue` → "running", `source.dbValue` → "healthImport") in the history card. Fixed to consumer copy ("Start activity", "Offline-first activity", "Required", "Activity saved to your history.", "Your entered details are still saved and editable.", title-cased activity labels, "Imported from Health" / "Logged in IndiFit"), and the four phrases joined the forbidden-string regression list. Internal-only technical wording in comments/exceptions (mapped at the presentation boundary) was deliberately left alone.

## Light / Dark Theme

- Saved Meals: fully on `B05SemanticColors` — search field, cards, error banner (danger container/indicator/foreground), delete dialog, destructive button pair, skeleton loading, success snackbars via `indiFitSuccessSnackBar`. Light golden re-inspected: correct light surfaces/contrast.
- Data Management: migrated; dialogs, warning rows, destructive confirms use the danger `container/foreground` pair (light #991B1B on #FEE2E2 ≈ 7:1; dark #FCA5A5 on #4C1117 ≈ 7:1).
- Review finding (fixed): the **"Inspect Backup"** button had been mechanically converted to `danger.indicator` background — white on light-red `#F87171` ≈ 2.7:1 in dark mode, the exact failing pattern the wave set out to remove. Converted to the container/foreground pair like its sibling buttons. Remaining `danger.indicator` backgrounds are SnackBars only (pre-existing app-wide idiom; M3 dark SnackBar content uses `onInverseSurface`) — acceptable, not R07F scope.
- Legacy-color boundary guard (`r07f_legacy_color_boundary_test.dart`): sound — repo-relative frozen 42-file list, deterministic, shrink-only, clear failure message, no absolute paths. Approved; no repo-wide migration demanded.

## Offline Typography

- `google_fonts` fully removed (pubspec, 28 call sites, 26 test files — verified by grep: zero `GoogleFonts` references outside the regression assertions).
- Outfit bundled as a variable font (`assets/fonts/Outfit-Variable.ttf`, 110,884 bytes), registered as family `Outfit`, applied via `textTheme.apply(fontFamily:)` with `FontWeight` driving the variable axis. No runtime font-fetch path remains; typography is network-independent.
- Goldens stable: W06 dark, R07D Saved Meals light 320/2x, theme-system and visual-certification suites all pass without regeneration (post-fix).

### Font licensing (review addition)

The vendored binary had **no licensing metadata in the repository** — a real redistribution gap (the runtime package previously carried its license automatically; a vendored asset must bring its own). Added `assets/fonts/Outfit-OFL.txt` (not declared as a bundled asset): copyright/designer lines extracted from the font's own name table ("Copyright 2021 The Outfit Project Authors", Rodrigo Fuenzalida / fragTYPE) plus the SIL OFL 1.1 text and provenance note. No internet re-download performed; no font binary redistributed outside the app artifact.

## Startup / First Frame

Pre-frame (verified in `main.dart`): config validation, FlutterError/PlatformDispatcher hooks, SharedPreferences + single ProviderContainer (with router-gate seed), eager DB construction (migrations run pre-UI), notification plugin init (timezone + tap handling), Sentry wrapping `runApp` (documented correct integration — kept). Post-frame: reminder rescheduling + auto-backup via `addPostFrameCallback` — accurate to the report.

## Reminder & Backup Post-Frame Safety

- Both post-frame tasks use `unawaited(...catchError(log))` — no lost failures, no unhandled async exceptions; auto-backup additionally catches internally and never throws.
- Reminders: `scheduleAllReminders` cancels all first → idempotent; resume lifecycle re-runs timezone/reschedule; kill-before-first-frame at worst skips one rescheduling pass (documented trade-off, converges on next launch/resume).
- Auto-backup: single trigger per launch (no concurrent rotation risk); no user "disable" feature exists to respect; failures logged, non-fatal, DB untouched.
- New logs are privacy-safe (status text + exceptions only; no meal/photo/body/backup-payload content).

## Router Gate Correctness

- `onboardingGateRedirect` is a pure, unit-tested function; the GoRouter redirect is synchronous — zero SharedPreferences I/O per navigation.
- Single authority: `onboardingCompletedProvider`, seeded once in `main()`. All state-changing writers verified to keep it current: onboarding complete (`onboarding_screen.dart:413`), skip (`:311`, covering `markProfileOnboardingSkipped`), file restore + auto-backup restore (`_syncOnboardingGate` after `performRestore`), erase (`deleteAllData`), reset-onboarding (sets false and navigates to the wizard). Deep links and the routine-wizard exemption behave per contract. Process restart re-seeds from prefs. No stale-routing path found (the one candidate — `b05_adaptive_onboarding.dart` — writes the pref only via the skip flow that immediately updates the gate).

## Settings / Small Surface Cleanup

Playlist hidden behind empty registry (no dead end, no empty section); Data Management copy consumer-grade ("older IndiFit export", schema-version line removed; capability intact); Fat macro icon now `oil_barrel_outlined` (no water/hydration implication); "Add food" capitalization consistent; meal single-tap inspection + VoiceOver hint semantics untouched; Food/Training business behavior (ranking, fast-add, B02 execution) unchanged.

## Responsive / Accessibility

Touched surfaces verified at 320/390-class widths and 1.0–2.0 text scales via existing goldens/widget tests (W06 certification, Saved Meals light-mode suite, R07D goldens) — no critical truncation introduced by this review's copy changes (all shorter than the jargon they replaced). Destructive states remain non-color-only (text labels + icons). 48dp targets preserved.

## Canonical Integrity

- **B02 execution unchanged** — no player/controller behavior edits (error-string mapping only).
- **B03 nutrition unchanged** — no repository/read-model edits.
- **B04 target semantics unchanged** — untouched.
- **No unsupported new metrics** — the only new domain surface is the null-safe provider-calorie accessor, which *reduces* the evidence surface.

## Goldens

- `ux_w06_workout_summary_dark.png` (regenerated by implementation): visually inspected — metric band now volume + duration only; no burn tile; header/footer clean.
- `ux_r07d_saved_meals_320_2x_light.png` (regenerated by implementation): visually inspected — light surfaces, white cards, correct contrast; the only change is the partial-nutrition notice token.
- This review's changes required **no golden regeneration** (copy strings in non-golden screens, dialog button styling, comments, tests).
- User-owned `ux_r07d_multiselect_light.png` dirty state preserved untouched.

## Tests

- Focused (this review): `r07f_release_cleanup_test.dart` (16), `r07f_legacy_color_boundary_test.dart` (3), `r07f_saved_meals_light_mode_test.dart` (3), `b02_activity_repositories_test.dart` (+3 new contract tests), `b02_player_activity_widget_test.dart` (updated assertions) — 39/39 passing.
- Regression batches re-run: theme system, W05 settings, W06 visual/accessibility certification — 48/48 passing.
- **Full serial suite (`flutter test -j 1`): 1,416 passed / 0 failed / 0 skipped** (baseline 1,413; +3 calorie-contract tests).

## Analyze / Format / Diff

- `flutter analyze`: 0 issues.
- `dart format`: clean.
- `git diff --check`: clean.

## iOS Release Build

`flutter build ios --release --no-codesign --dart-define=INDIFIT_API_KEY=test_key` — **passed**: `✓ Built build/ios/iphoneos/Runner.app (59.9MB)`. Build-only validation; no physical-device activity.

## Findings resolved (summary)

| # | Severity | Symptom | Root cause | Fix |
|---|---|---|---|---|
| 1 | High | `estimatedCalories: 0` was an ambiguous false-zero sentinel documented only in a screen comment; future code could read it (or legacy fabricated rows) as canonical evidence | Non-nullable compatibility column kept writing 0 without an explicit domain contract or safe read path | Explicit NON-AUTHORITATIVE column contract + provenance-aware `providerEstimatedCaloriesKcal` accessor + write-site docs + 3 regression tests |
| 2 | Medium | "Inspect Backup" button: white on `#F87171` ≈ 2.7:1 in dark mode — the exact contrast failure R07F-0 set out to remove | Mechanical `AppColors.danger` → `danger.indicator` conversion skipped the container/foreground pair applied to sibling buttons | Converted to `danger.container/foreground` |
| 3 | Medium | Manual activity screen rendered internal jargon ("typed draft/modality/history", raw `healthImport`/`running` db values) | First terminology sweep fixed the screen's error strings but missed its labels | Consumer copy + title-cased labels + source labels ("Imported from Health"/"Logged in IndiFit"); phrases added to forbidden-string regression scan |
| 4 | Medium | Vendored Outfit binary shipped with no license metadata in-repo (redistribution compliance gap) | Font moved from pub package (auto-licensed) to a vendored asset without attribution | `assets/fonts/Outfit-OFL.txt` with OFL 1.1 + copyright extracted from the font's own name table |

## Deferred to R07F-1+ (unchanged)

Hydration/WaterLogs; PR celebration engine + share card; finish/leave plan; Training week strip; go_router migration completion; exercise media; rest-timer background presence; achievements expansion; e1RM/PR badges; god-file splits; MealTemplates retirement; legacy-player sunset; broad token migration beyond the frozen boundary; onboarding payoff; SnackBar danger-idiom consolidation (pre-existing, Low); docs re-baselining.

## Review commit

`review(r07f): resolve trust review findings — calorie sentinel contract, contrast, jargon, font license` — on `ux/r07f-release-cleanup`, containing only the files listed above. Not merged; not pushed.
