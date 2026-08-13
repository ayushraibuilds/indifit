# UX-R7A Physical-Device Remediation Plan

1. Preserve the reviewed R7A head and all unrelated user-owned worktree
   changes while tracing each physical-device failure through its production
   presenter, adapter, repository, and canonical read authority.
2. Keep the indexed Food destination meal-neutral and stable. Meal selection
   from Food Home will push a meal-specific `FoodSearchScreen`, whose Back and
   successful save both return to Food Home and refresh canonical history.
3. Preserve authoritative dimensional food metadata during B03 adaptation:
   normalize legacy gram/millilitre facts to per-100-unit facts, retain Open
   Food Facts per-100-gram facts, and keep abstract servings when no safe
   conversion basis exists. Do not invent katori/glass gram calibrations.
4. Harden Open Food Facts transport with provider identification, a bounded
   response field set, measured production timeouts, actual request
   cancellation, stale-query protection, and debug-only structured timing and
   exception diagnostics that never include credentials or sensitive headers.
5. Fix the actual manual-workout presentation boundary by enabling safe-area
   handling on the shared modal route, then test the modal presenter with top,
   bottom, and keyboard insets.
6. Bridge consumer suggested/template routine activation through the existing
   B01 legacy-import snapshot and `ProgramActivationCoordinator`. Exclude rest
   days from session templates, preserve weekday and exercise ordering, and do
   not show success until an active program and canonical occurrences exist.
7. Standardize success feedback in the directly touched flows as compact,
   floating SnackBars without expanding into R7C celebration work.
8. Add focused production-boundary coverage for Food hierarchy/save return,
   representative quantity authorities, provider success/timeout/cancellation,
   modal safe area, canonical template activation, idempotency, and compact
   feedback. Run formatter, analyzer, diff checks, the full serial Flutter
   suite, and a signed physical-device build/install before committing.

Resolved evidence:

- Poha and cooked-rice seeds contain only `1 katori`; no mass calibration is
  present. Their serving-only behavior is an honest source-data limitation.
- Other local foods with `g`/`mL` metadata were incorrectly collapsed to an
  abstract serving by `NutritionFoodCatalogRepository`.
- Open Food Facts requires a custom product `User-Agent`; the existing client
  had none, used a three-second connect timeout, requested unrestricted product
  objects, and did not cancel Dio work when the query changed.
- `showIndiFitBottomSheet` passed `useSafeArea: false`, which removes top
  padding before the inner `SafeArea` can consume it.
- suggested/template flows saved a legacy routine and draft B01 import but did
  not call canonical B01 activation, so Training and Calendar correctly saw no
  active plan.
