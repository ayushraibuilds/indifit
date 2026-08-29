# R08D.2 — Food search + fast logging

Status: implementation complete; fresh Sol High correctness review passed
with fixes.

## Boundary

R08D.2 keeps B03 as the authority for food identity, typed quantities,
nutrient calculation, meal/date context, immutable snapshots, and command
idempotency. The search surface only retrieves and ranks existing facts before
the selected result is handed to the existing catalog and logging
coordinators.

## Implemented

- Local discovery searches the existing food name, Hindi name, brand,
  category, and regional/package metadata. `NutritionFoodSearchRanking` then
  orders the candidates deterministically using normalized name, searchable
  metadata, exact/prefix/token/fuzzy match, bounded locality and facts-
  availability signals, and stable identity tie-breakers. Usage frequency and
  recency do not affect D.2 ranking.
- Search input waits 300 ms after the last edit before starting retrieval.
  Local results still render before the asynchronous online response, and the
  existing generation/cancellation guard drops stale responses.
- Legacy candidates carry existing category and regional metadata into the
  ranking vocabulary. These fields affect discovery only; they do not alter
  the candidate's food ID or nutrient facts.
- A provider result without a barcode or provider product ID, or with
  conflicting identity fields, is visible only as an unavailable result. It
  cannot be logged or converted into a durable food identity from its display
  name.
- Quantity selection remains the existing typed B03 path. The UI offers only
  deterministic same-dimension units and opens quantity confirmation for
  mass/volume facts rather than pretending they are a serving.
- Fast Add continues to lock before its first await and finalizes one
  canonical snapshot with the selected meal, local date, timezone, quantity,
  and exact food identity. Save failure leaves the flow recoverable and shows
  consumer-safe retry language.

## Deliberate deferrals

R08D.2 does not add Recent/Frequent repeat policy, multi-select behavior,
saved meals, recipes, AI/photo recognition, nutrition-target changes, new
food data, household conversions, or nutrient calculations. Existing
compatibility surfaces remain unchanged until their owning R08D package.

## Review focus

Sol High should verify that searchable metadata remains retrieval-only, that
provider identity never falls back to mutable display text, and that fast log
continues to rely on B03 snapshot finalization rather than an optimistic UI
record.
