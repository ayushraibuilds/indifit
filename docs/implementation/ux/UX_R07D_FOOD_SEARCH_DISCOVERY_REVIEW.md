# R07D-2 Food Search & Discovery Review

## Baseline and scope

- Branch: `ux/r07d-food-search-discovery`
- Implementation reviewed: `f0b4b49` (`feat(r07d): improve food search discovery quality`)
- Baseline: `29864f3`
- This review leaves unrelated reference assets, iOS configuration, and test
  failure artifacts untouched. No merge, push, or physical-device testing was
  performed.

## References inspected

- `docs/reference/ui/REFERENCE_GUIDE.md`
- Current meal-scoped food-entry, search, result, and multi-select captures
- Healthify food-discovery captures, for dense Indian-food scanning principles
- `UX_R07D_FOOD_SEARCH_DISCOVERY_PLAN.md` and R07D-1 logging/review material
- B03 food identity, quantity, and manifest contracts

The reference library did not contain MyFitnessPal screenshots, so no
comparison was fabricated. The applied principle is product-level only:
surface food, serving, energy, and action quickly without exposing storage or
provider architecture.

## Findings and fixes

1. **High — structured brand and pack intent was not retrievable.** Provider
   `brand` was display-only, so a query such as `amul 200g paneer` could miss a
   product named `Fresh Paneer` with `Amul` and `200 g` in structured metadata.
   Search-a-licious now requests the provider quantity and the ranking candidate
   evaluates normalized name, brand, and declared pack text. This does not
   alter provider identity, facts, provenance, serving, or display identity.

2. **High — matching Custom Foods disappeared whenever local or remote results
   existed.** The old canonical query was gated on both result sets being empty.
   Active custom discovery now runs independently through a narrowly scoped,
   active-user-food query. Its row is explicitly labelled `Custom`, and it
   remains separate from same-name provider or canonical identities.

3. **Medium — a weak interior match could suppress useful typo recovery.** The
   local three-character fallback now runs for sufficiently long queries even
   when a weak local result exists. Interior substring weight is below useful
   fuzzy recovery, and short non-leading remote brand fragments are suppressed
   generically; `appe` is not special-cased.

4. **Medium — provider history did not match provider candidates.** Canonical
   recent source references are mapped back to the provider's stable retrieval
   key before applying the existing bounded history boost.

5. **Medium — search result copy exposed implementation details.** The result
   area is one flat, ranked `Search results` list. `Foods on this device`,
   `Best matches`, and `More results` were replaced with consumer language.
   Remote package text is shown only as useful serving/product context.

## Ranking, aliases, and merge assessment

One deterministic ranking service remains the ordering authority. It gives
exact and prefix matches priority, then strong tokens, bounded history and
locality signals, bounded fuzzy recovery, and filtered remote fallback.
Lexical relevance gates history; quality is only secondary. Stable
name/brand/identity tie-breaks avoid database or HTTP response ordering.

`dahi`/`curd`, `roti`/`chapati`, and `poha`/`flattened rice`/`beaten rice`
remain retrieval-only vocabulary. They never change B03 identity, facts,
history, or deduplication. Brand/generic, raw/cooked, and Custom/provider
variants remain distinct. Trusted canonical and stable provider IDs alone drive
deduplication.

Local results remain available before the asynchronous provider response;
generation guards and cancellation retain stale-response protection. The
identity-keyed selection model, Fast Add, quantity fallback, meal/date
attribution, and multi-select command semantics are unchanged.

## B03 integrity

Verified through the focused B03 suites and the production-path review:

- retrieval aliases do not mutate canonical identity;
- branded/generic, raw/cooked, and Custom Food identities remain separate;
- nutrients, missingness, servings, provenance, and conversion semantics are
  unchanged;
- trusted IDs—not display names—deduplicate;
- logging snapshots, meal/date context, Fast Add, quantity fallback, and
  multi-select idempotency remain authoritative B03/R07D-1 behavior.

## Golden inspection

Visually inspected the regenerated 390×844 local exact search in light and
dark themes, the merged local/provider result state, the existing R07D-1
multi-select state, and the existing 320-wide/2× landing coverage. The flat
heading reduces vertical/technical noise while keeping food, serving, energy,
selection, and Add affordances visible. The existing no-results state remains
consumer-facing and offers the established alternate entry paths.

The known R07D-1 multi-select golden was reproduced in an isolated detached
worktree at `29864f3` and on this branch with the exact command:

```text
flutter test test/ux_r07d_food_diary_logging_test.dart --plain-name
"multi-select preserves temporary selection and commits one batch per tap burst"
```

Both runs failed identically at `0.20%` / `650px`; the master, test, masked,
and isolated diff PNGs were byte-identical. The tiny diff is confined to the
header-text region, and the R07D-2 branch output is identical to baseline.
Classification: **A — baseline-only pre-existing mismatch**. It was not
regenerated.

## Validation

- R07D-2 ranking/custom-discovery and provider API tests: passed (21 tests).
- R03 food search/logging, including regenerated affected goldens: passed
  (23 tests).
- Adjacent R07A/R07D-1/B03/B04/B05 regression group: 135 passed, 1 failed —
  only the verified baseline-only R07D-1 golden above.
- `flutter analyze`: passed with no issues.
- `dart format` on changed Dart files: clean.
- `git diff --check`: clean.
- Serial `flutter test --concurrency=1 --reporter compact`: 1,366 passed, 1
  failed — the same verified baseline-only R07D-1 golden; completed, not
  interrupted.
- `flutter build ios --release --no-codesign`: passed; built
  `build/ios/iphoneos/Runner.app` (59.6 MB). The standard MLKit simulator
  architecture warning was informational and did not affect the device build.

## Deferrals

R07D-3+ owns broader Indian-food vocabulary/catalog expansion, deeper brand
normalization, and any new search taxonomy or personalization strategy. This
review deliberately does not add provider, ML, telemetry, recipe, barcode, AI,
or Custom Food redesign scope.

## Review commit

Local-only commit: `fix(r07d): resolve food search review findings`.
