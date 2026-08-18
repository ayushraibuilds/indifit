# R07D-2 — Food Search & Discovery Quality

## Baseline and scope

- Baseline: `29864f3` on `main`, with R07D-1 integrated.
- Branch: `ux/r07d-food-search-discovery`.
- Scope: deterministic query normalization, bounded retrieval vocabulary, local/history/remote ranking, duplicate suppression, typo tolerance, and poor-result filtering.
- Non-goals: diary redesign, canonical identity changes, catalog expansion, new providers, recipes, barcode, AI, and nutrition/serving semantics.

## Existing production path

Before this slice, `FoodSearchScreen` debounced input, read
`FoodRepository.searchFoodLocal`, requested `FoodApiService.searchOnline`,
and only then loaded custom canonical options when the earlier sources were
empty. Rows were rendered by source, so provider response order survived into
the UI. Recent/frequent data was available through
`canonicalRecentFoodsProvider`, but was not used to rank active search results.

The R07D-2 path keeps the fast local compatibility catalog as the first
retrieval source, expands only the reviewed retrieval vocabulary, adds a
bounded three-character prefix retrieval for typo candidates, and ranks the
local and remote candidates together. B03 identity adaptation still happens
when a local or provider row is opened. A catalog-wide canonical candidate
cache is intentionally not placed on the active keystroke path.

## Ranking contract

`NutritionFoodSearchRanking` is a pure, testable layer. It normalizes query/name text, expands only explicit retrieval vocabulary, assigns match quality, applies bounded history/locality/generic-vs-branded/quality tie-breaks, deduplicates only by canonical or stable provider identity, and applies a remote minimum-quality threshold. Exact and prefix matches always outrank fuzzy matches; history cannot rescue a weak lexical match.

## Retrieval vocabulary

Manually maintained retrieval-only groups are deliberately small:

- `dahi` ↔ `curd`
- `roti` ↔ `chapati`
- `poha` ↔ `flattened rice` / `beaten rice`

These terms expand retrieval and scoring only; they do not mutate B03 aliases, identity IDs, facts, or provider records. Existing B03 canonical aliases remain authoritative when already attached to a food identity.

## Merge and privacy rules

- Local candidates appear first; remote enrichment never clears selection or replaces the current generation. Canonical identity conversion remains at the B03 catalog boundary when a result is opened.
- Canonical identity IDs and provider IDs/barcodes are trusted dedupe keys. Display names alone never merge records.
- Remote candidates below the relevance threshold are hidden; a truthful no-strong-match state is preferred to unrelated products.
- Diagnostics retain query length/count/category information only; literal search text is not logged.

## Validation and deferrals

Cover the relevance matrix, aliases without identity mutation, fuzzy/short-query bounds, history gating, custom foods, raw/cooked and branded/generic distinctions, dedupe, remote merge/stale response behavior, compact/large-text search rows, and affected goldens. Defer a startup-safe catalog-wide canonical candidate cache, broader vocabulary, and richer discovery sections to R07D-3+.
