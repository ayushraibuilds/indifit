# UX R07D-3 — Recipes & Saved Meals Review & Resolution

**Baseline:** `68735a4` (Merge R07D-2 food search discovery)
**Implementation:** `5b30bef50499e444b25ad0d73f94aef646de2b3d`
**Branch:** `ux/r07d-recipes-saved-meals`

## Assessment

R07D-3 now provides a fast, understandable repeated-meal path while retaining
B03 calculation and history authority. The review inspected the current IndiFit
and Healthify reference material. No MyFitnessPal reference files were present
in the reference library, so none were inferred or fabricated.

Consumer concepts are deliberately distinct:

- **Food** — one canonical `NutritionFoods`/Custom Food item.
- **Recipe** — a prepared food owned by `NutritionRecipes`, immutable published
  versions, and recipe ingredients.
- **Saved Meal** — a reusable group owned only by `NutritionThalis` and
  `NutritionThaliItems`; its components are typed Food or Recipe-version IDs.

`NutritionThali` is structurally a generic ordered composition, despite its
historical name. Consumer surfaces call it **Saved meal**. `MealTemplates`
remains an isolated legacy compatibility surface for pre-existing data; R07D-3
does not dual-write, synchronize, or use it as the authority for new Saved
Meals.

## Findings resolved

| Severity | Finding | Resolution |
| --- | --- | --- |
| High | Saving a logged meal could reconstruct components through legacy/name-oriented data and create a second durable authority. | `SaveLoggedMealHelper` now accepts canonical historical rows only, retains type + ID, quantity, duplicate rows and order, rejects unsafe/mixed legacy rows with actionable copy, and writes one `NutritionThaliDraft`. |
| High | A Recipe successor could make an otherwise valid Saved Meal appear stale; edit-before-log persisted a temporary Saved Meal. | Saved Meals stay pinned to their immutable Recipe version. Edit-before-log finalizes a transient composition variation against the existing Saved Meal rather than saving a temporary draft. |
| High | Fast logging did not make local-day semantics and synchronous double-tap protection explicit at the Saved Meal boundary. | Logging receives IANA timezone/local date and selected-day instant, uses stable command/consumption IDs, and blocks repeated in-flight submissions before asynchronous work. |
| Medium | Retaining a successful command for retry could suppress a later intentional re-log of the same Saved Meal on the same day. | A concurrent tap still shares the in-flight command; a successful completion clears it so a later explicit action receives fresh idempotency IDs. |
| Medium | Partial/unavailable aggregate nutrition could look actionable or precise. | Cards disclose partial/unavailable state, unsafe cases route to adjustment/review, and acknowledgement is required for critical partial nutrition. |
| Medium | Saved Meal composition made Food versus Recipe and responsive quantity editing too easy to confuse. | Editor and adjustment sheet label types, preserve immutable recipe references, and stack controls on narrow/large-text layouts. |
| Medium | Consumer copy exposed internal Thali/template/version terminology and the R07D-3 Food-search render lacked its updated golden. | Consumer copy uses Saved meal/Recipe wording, selection no longer exposes RecipeVersion, and the inspected R07D-3 multi-select golden was updated. |

## Lifecycle and historical truth

- Recipe edits publish immutable successors. Existing logs and Saved Meals retain
  their version-1 references; new normal logging uses the current recipe
  version.
- A Recipe archive preserves historical consumption snapshots and causes an
  affected Saved Meal to show an actionable unavailable/repair state rather
  than silently dropping, replacing, or zeroing the component.
- Saved Meal edits change only the Saved Meal. Edit-before-log changes only the
  one consumption snapshot and records `temporary_variation` evidence. Neither
  action rewrites old diary data.
- Saved Meal deletion is lifecycle-only: it does not cascade into Food, Recipe,
  Recipe-version, or historical-consumption records.
- Recipe nutrition and yield remain calculated by the B03 ingredient authority;
  unknown and partial values remain unknown/partial, known zero remains zero,
  and unsupported conversions are not invented.

## Product and visual review

The primary path is compact: Food/Today → Saved meals → **Log to meal**. Valid
Saved Meals keep one-tap re-log; **Adjust for this log** is separate from
**Edit saved meal**. Food-search preserves R07D-2 ranked, local-first discovery
and keeps Food, Custom Food, provider Food, Recipe, and Saved Meal identities
separate rather than deduplicating by display name.

The 320 px / 2x Saved Meals golden was visually inspected: actions stack,
partial nutrition remains prominent, and the primary logging action remains
reachable. Focused existing Food, Today, recipe, and R03 goldens cover normal,
dark, compact, and large-text states. Object type is also supplied in visible
copy and semantics rather than by colour alone.

## Regression coverage

`test/ux_r07d_recipes_saved_meals_test.dart` now has **11** focused tests,
including typed same-name/duplicate preservation, recipe-v1 pinning through a
v2 successor, safe recipe archival, immutable edit-before-log variation,
selected local date/timezone, concurrent-tap idempotency plus later intentional
re-log, partial-nutrition disclosure, and the 320 px / 2x golden.

The required focused serial set completed with **200 passed, 0 failed, 0
skipped**. It includes R07D-1/R07D-2/R07A/R03, B03 recipe/thali/consumption,
and relevant B04/B05/Today coverage.

The original R07D-1 multi-select golden was compared in three worktrees:

- R07D-2 baseline: historical `0.20%` / `650 px` mismatch.
- R07D-3 implementation and reviewed branch: matching `21.11%` / `69,470 px`
  rendering caused by intentional R07D-3 Food-search presentation changes.

It was therefore not treated as a baseline-only failure or blindly regenerated:
the resulting state was visually inspected and the stale current golden was
updated. The complete serial suite then completed with **1,378 passed, 0
failed, 0 skipped**.

## Validation

- `dart format`: 12 review-touched Dart files checked; 0 changes required.
- `flutter analyze`: clean.
- `git diff --check`: clean.
- `flutter build ios --release --no-codesign --dart-define=INDIFIT_API_KEY=test_key`:
  passed; build-only validation, with no physical-device activity.

## Deliberate deferrals

No schema rewrite, household-measure expansion, barcode/photo/AI logging,
planning/grocery/social features, recommendations, or physical-device testing
was introduced. Legacy `MealTemplates` remains compatibility-only pending its
separate retirement/migration work.

## Review commit

`fix(r07d): resolve recipes and saved meals review findings` (local only; the
exact hash is recorded in the review handoff).
