# B03 legacy nutrition compatibility inventory

This artifact records the B03-11B compatibility boundary. It does not claim
that legacy writers or legacy storage have been retired.

## Adapted readers

- `NutritionLegacyAdapter` is the only B03 reader for legacy `FoodLogs`,
  `MealTemplates`, and `MealTemplateItems`.
- `NutritionReadModelRepository` merges adapted legacy food-log records with
  immutable B03-11A consumption snapshots and provides the daily aggregation
  boundary.
- Legacy templates remain a separate read model. Reading them never writes a
  recipe, calculation, or consumption snapshot.
- `NutritionLegacyUsageMetrics` exposes counts for legacy rows, unresolved
  identities, local-ID-only records, and unsupported quantities so retirement
  work can be measured later.

## Stable identity and ambiguity

- A non-duplicated legacy food-log UUID is represented as
  `legacy-food-log:uuid:<uuid>`.
- Rows without a portable UUID, or with duplicate UUIDs, use the explicit
  namespaced local-row identity `legacy-food-log:local-id:<id>` and expose a
  compatibility issue.
- Unified history de-duplicates within a source namespace, so a caller-chosen
  canonical snapshot ID cannot hide a legacy record with the same text.
- Templates and template items use namespaced local identities because the
  legacy tables do not contain portable IDs.
- Food identity resolves only through an explicit reviewed
  `nutrition_legacy_food_mappings` row whose canonical food exists. Missing,
  ambiguous, and corrupt mappings remain visible as typed issues. Display
  names are never identity keys.

## Quantity and nutrient behavior

- Stored grams, millilitres, and genuine piece/count values become typed
  quantities.
- Legacy servings retain a contextual serving definition with an explicit
  limitation; household labels remain unresolved references. No serving,
  household, mass-volume, density, raw/cooked, or water-density conversion is
  performed.
- Non-positive, non-finite, and unknown units remain invalid/unresolved and
  retain the stored value/unit.
- Contextual servings and unresolved household references retain a typed
  quantity object for display but are not reported as resolved quantities.
- Precision-overflow legacy amounts remain readable as invalid compatibility
  state rather than escaping the adapter as an exception.
- Copied legacy energy, protein, carbohydrate, fat, and fibre values are read
  as legacy facts. A stored null remains missing; absent micronutrients remain
  missing; no current catalogue nutrient value is substituted. Completeness is
  therefore partial where coverage is incomplete.

## Active legacy writers and deferred retirement

The existing `FoodRepository` continues to own active legacy food-log and
template writers, including replay/copy flows. Existing dashboard, progress,
history, and template UI callers that still use `FoodRepository` are not
rewritten in B03-11B. Those callers remain measurable migration targets for
B03-12 or the later legacy-retirement work. New B03 feature code must use the
canonical snapshot writer and must not add new calls to the legacy writer.

## Backup coverage

- Backup v5, v6, and v7 are parsed and restored through their existing
  legacy-only path; they do not fabricate B03 recipes or snapshots.
- The checked-in B03 Backup-v7 legacy fixture remains readable through the
  adapter after restore.
- Backup v8 remains the canonical snapshot/lineage format and is outside the
  ordinary legacy read mutation boundary. Its existing graph codec owns v8
  restore validation and portable-ID behavior.
- No schema or backup version was increased.

## Unsupported states

Unresolved food identity, ambiguous mappings, missing custom references,
unsupported or invalid quantities, unknown nutrient values, legacy source
coverage limits, unsupported template structures, corrupt relationships, and
unsupported backup records are returned as explicit compatibility state. They
are never converted into empty valid records or fabricated modern nutrition.
Orphan template-item relationships are rejected with a typed corruption error
instead of being silently omitted from the template read model.
