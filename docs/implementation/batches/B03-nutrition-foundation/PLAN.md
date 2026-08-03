# B03 — Nutrition Foundation and Food Context: Implementation-Ready Plan

Status: planning proposal only. No implementation branch is authorized until B02 is merged and the Sol High gates in this plan are resolved.

Baseline: B02 application schema v16 and backup format v7. Proposed B03 boundary: schema v17 and backup format v8, subject to Sol High approval.

## Architecture summary

B03 should introduce a typed nutrition domain beside the existing `FoodItems`, `FoodLogs`, `MealTemplates`, and profile stores. The existing tables remain readable and exportable while the new domain becomes the authority for new nutrition flows:

```text
catalogue food/preparation
  → typed quantity and reviewed conversion
  → recipe, thali, or estimate composition
  → one calculation engine
  → immutable consumption snapshot
  → daily/history read models
```

The catalogue owns identity and nutrient facts. The quantity service owns dimension-safe arithmetic. Recipes and thalis own composition, not duplicated nutrient totals. A calculation run materializes a snapshot at logging time; history reads the snapshot rather than re-reading today’s catalogue. Missing nutrients remain missing, and estimates retain bounds, source, assumptions, and provenance. Existing `FoodLogs` are preserved through an adapter until migration has been verified.

This is an offline-first architecture. Server-backed AI is an optional estimate source, never the only path to logging. Controllers and screens call repositories/services; they do not write Drift rows or maintain alternate totals.

## Domain model

There are three related graphs:

1. Identity graph: a stable `nutrition_foods.id` identifies an ingredient, prepared food, recipe, imported item, or user-created item. Aliases and provider identifiers resolve to that ID; display text is presentation only.
2. Recipe graph: a recipe points to a published immutable version. A version contains ingredient quantities, preparation references, yield, and serving definition. A nested recipe points to a specific version.
3. Consumption graph: a logged meal points to a snapshot. Snapshot items point to food or recipe-version references and retain the selected quantity and calculated nutrient result at that time.

No graph may use a display name as its foreign key. A display name can be duplicated across regions, brands, preparations, or languages.

## Identity contract

- Seeded catalogue rows use stable manifest IDs derived from the reviewed seed manifest. The ID is independent of insertion order and portable across devices and backups.
- Base ingredients, preparations, recipes, user-created foods, and imported foods use UUIDs. Provider IDs are retained as source identifiers, never used as local primary keys.
- Aliases are normalized only for case folding and Unicode whitespace. Resolution is exact after that normalization: zero matches is unresolved, one is resolved, and multiple candidates are ambiguous. There is no fuzzy matching, substring matching, punctuation stripping, or technique-stripping migration.
- A correction creates a user correction/alias overlay with provenance. It does not rewrite the seeded identity or silently merge near-duplicates.
- Legacy integer `FoodItems.id` values are retained in an explicit mapping table. A legacy row is mapped only when identity and variant evidence is explicit; otherwise the row remains legacy and its copied log text remains authoritative for that old log.

## Quantity and unit contract

| Dimension | Canonical units | Example | Rule |
|---|---|---|---|
| Mass | `g`, `kg` | 180 g rice | Only mass-to-mass conversion without density. |
| Volume | `ml`, `l` | 240 ml milk | Only volume-to-volume conversion. |
| Count | `count` | 2 eggs | Count requires a food-specific count-to-mass/volume fact or remains count-only. |
| Nutrition serving | `serving` | 1 labelled serving | Serving is a food-defined quantity, not a universal dimension. |
| Household measure | typed measure key | 1 katori | Resolves through a food/preparation-specific reviewed or user calibration. |
| Fraction | `edible_fraction` | 0.75 edible | Explicit transformation input, never an implicit unit conversion. |

Every quantity stores value, dimension, unit, context, source, approximation flag, and optional lower/upper bounds. Values must be finite and non-negative. Zero is valid only where the quantity itself is zero; negative quantities are rejected. `NutritionQuantityService` is a pure deterministic service. `NutritionConversionRepository` owns reviewed conversions and user calibrations. There is no global fallback that converts an unknown household key to grams, and no gram assumption for liquids or countable foods. Density is food/preparation-specific and may be unknown.

Calculations retain full stored precision and round only at display/export boundaries. A missing conversion produces an unavailable or bounded result with an explanation; it does not silently use `1 g = 1 ml`, `serving = 100 g`, or another global multiplier.

## Recipe, scaling, and raw/cooked rules

1. A recipe starts as a draft and may be edited freely before publishing.
2. Publishing creates an immutable recipe version with ingredient references, quantities, preparation state, yield, serving definition, calculation-rule version, and source metadata.
3. Editing a published recipe creates a new version; it never changes an old version used by a log.
4. A saved recipe points to the selected version. Nested recipes point to an immutable version, not a mutable recipe name.
5. Scaling changes the requested output yield or servings and recalculates from ingredient quantities. It never scales a rounded total.
6. Logging a recipe stores the selected recipe version, selected serving/quantity, ingredient context, and calculated nutrient snapshot. It is not a live reference to the recipe.
7. A raw/cooked transformation is directional and keyed by source food, source preparation, target preparation, method, yield/loss factor, evidence, and rule version. Water gain and dry-matter loss are represented separately where needed.
8. The reverse direction is a separate reviewed transformation or unknown. No universal rice, dal, meat, vegetable, pasta, or noodle factor is invented by the migration.
9. Preparation variants such as raw, boiled, pressure-cooked, fried, restaurant, homemade, low-oil, or extra-oil remain distinct when their evidence or nutrient basis differs.

Raw/cooked conversion is `SOL-GATE REQUIRED`. Fixtures must cover rice, pulses, pasta/noodles, meat, vegetables, oil/frying, and an unknown transformation. The result must expose whether it is exact, reviewed approximate, user-entered approximate, or unavailable.

## Household measures, vessels, and thalis

`NutritionHouseholdMeasure` is a vocabulary and display layer for katori, bowl, ladle, glass, cup, tablespoon, teaspoon, roti/chapati, piece, and thali. A measure label alone has no universal mass. A food/preparation-specific conversion may define a volume or mass range with source and confidence.

`NutritionVesselCalibration` is user-owned and device-portable. It records vessel identity, measured volume, method, date, optional food/preparation calibration, and uncertainty. A calibrated vessel volume does not establish the mass of every food. Food-specific weighing is required before using mass-based nutrient values. The UI must show “approximate” where the calibration or density is approximate.

A thali is an ordered composition of canonical foods and recipe versions with typed quantities. It reuses the same calculation engine as individual logging and recipes. A saved thali is reusable; a logged thali becomes a consumption snapshot. A thali result reports `confirmed_conflict`, `possible_conflict`, `no_known_conflict`, and `insufficient_information` independently for dietary constraints. It must support offline creation, partial completion, unknown components, keyboard/screen-reader labels, and a clear distinction between “not entered” and zero.

## Nutrients, missing data, and estimates

The initial nutrient registry should include energy, protein, carbohydrate, fat, fibre, sodium, added sugar, saturated fat, cholesterol, potassium, calcium, iron, vitamin B12, vitamin D, magnesium, zinc, folate, and leucine where evidence exists. Each nutrient fact has a typed unit, status, source, version, and optional lower/upper bounds. Statuses are `known`, `known_zero`, `missing`, `not_applicable`, and `estimated`; `missing` is never coerced to zero.

Totals are sums of available facts with completeness metadata. A daily total may show a known subtotal and bounds/unknown nutrients; it must not imply that absent micronutrients were consumed at zero. Macro and micronutrient units are typed in the registry and validated at calculation time. Historical snapshots retain the fact/version and result used at logging time.

AI and photo analysis use `NutritionEstimate` plus per-nutrient child rows. Each estimate stores source (`catalogue`, `manufacturer`, `user`, `recipe`, `AI`, `photo`, `heuristic`, or `import`), provider/model/rule identifiers, prompt or input hash where safe, assumptions, created time, confidence label, and optional bounds. A correction creates a new estimate/fact with provenance and supersedes the prior estimate; it does not rewrite a historical snapshot. Images are not persisted by default. Network failure falls back to a local manual/unknown path. The UI must not display an exact-looking point value when only a range or weak estimate exists.

## Protein distribution and leucine guidance

Meal boundaries use existing `mealGroupId` where available, otherwise explicit meal category and timestamp rules approved by product. Protein distribution is derived from immutable consumption snapshots and is a read model, not a second persisted total. Leucine is measured, estimated, or unknown per source; any estimate retains its heuristic version and bounds. Guidance is bounded and educational, with no muscle-protein-synthesis or medical guarantee. This is `SOL-GATE REQUIRED`.

## Dietary constraint taxonomy

The model distinguishes `allergy`, `intolerance`, `religious_restriction`, `ethical_preference`, `dietary_pattern`, `taste_dislike`, `temporary_avoidance`, and `regional_preference`. A user constraint stores type, value, strictness, severity where relevant, cross-contact sensitivity where relevant, effective dates, source, and notes. Food evidence is ingredient-level where known and can be `confirmed`, `possible`, `not_indicated`, or `unknown`; names alone cannot prove safety.

Evaluation returns exactly one of `confirmed_conflict`, `possible_conflict`, `no_known_conflict`, or `insufficient_information`, with evidence references. Jain, halal, allergen, intolerance, preference, and vegan/vegetarian choices are not collapsed into one string. Recommendations must not claim safety when evidence is insufficient. This taxonomy and UX are `SOL-GATE REQUIRED`.

## Proposed schema (v17)

All IDs below are portable text UUIDs or stable seed-manifest IDs. Timestamps are UTC. Numeric fields are finite `REAL` values with no display rounding in storage. Every table has `created_at` and `updated_at` unless noted.

| Table | Purpose | PK | Important fields | FKs | Indexes |
|---|---|---|---|---|---|
| `nutrition_foods` | Canonical food/prepared/custom/imported identity | `id` | `kind`, `display_name`, `locale`, `source_type`, `source_ref`, `source_version`, `brand`, `region`, `lifecycle`, `variant_of_food_id`, `legacy_food_item_id` | self `variant_of_food_id` | kind/lifecycle; source_type/source_ref; legacy ID |
| `nutrition_food_aliases` | Locale/provider/user aliases | `id` | `food_id`, `alias`, `normalized_alias`, `locale`, `source`, `confidence`, `is_active` | food | normalized alias/locale; food |
| `nutrition_food_preparations` | Explicit raw/cooked/method variants | `id` | `food_id`, `state`, `method`, `oil_context`, `region`, `source`, `version` | food | food/state/method; source/version |
| `nutrition_legacy_food_mappings` | Auditable bridge from v16 rows | `legacy_food_item_id` | `food_id`, `mapping_status`, `evidence`, `mapped_at` | food | food; mapping status |
| `nutrition_nutrient_definitions` | Typed nutrient vocabulary | `id` | `key`, `display_name`, `unit`, `kind`, `sort_order`, `version`, `is_active` | — | unique key/version |
| `nutrition_food_nutrient_facts` | Versioned food nutrient facts | `id` | `food_id`, `nutrient_id`, `amount`, `lower`, `upper`, `status`, `source`, `source_ref`, `confidence`, `fact_version`, `is_current` | food, nutrient | food/current; nutrient; source |
| `nutrition_quantity_conversions` | Reviewed/user food-specific conversions | `id` | `food_id`, `preparation_id`, `source_unit`, `target_unit`, `factor`, `lower`, `upper`, `method`, `source`, `confidence`, `rule_version`, `owner_scope` | food, preparation | food/source unit; preparation |
| `nutrition_household_measures` | Measure vocabulary and display metadata | `id` | `key`, `display_name`, `dimension`, `base_unit`, `nominal_value`, `lower`, `upper`, `locale`, `version` | — | unique key/locale; dimension |
| `nutrition_personal_vessels` | User-owned portable vessel identity | `id` | `user_id`, `display_name`, `vessel_type`, `created_at`, `updated_at`, `archived_at` | — | user/archive |
| `nutrition_vessel_calibrations` | Versioned volume-only vessel calibration | `id` | `vessel_id`, `volume_amount`, `volume_unit`, `lower`, `upper`, `method`, `confidence`, `supersedes_calibration_id`, `version`, `notes` | vessel; self supersession | vessel/version; supersession |
| `nutrition_recipes` | Stable saved recipe identity | `id` | `user_id`, `name`, `description`, `lifecycle`, `current_version_id` | version after creation | user/lifecycle; current version |
| `nutrition_recipe_versions` | Immutable recipe definition | `id` | `recipe_id`, `version_number`, `status`, `yield_quantity`, `yield_unit`, `serving_quantity`, `calc_rule_version`, `source` | recipe | recipe/version unique; status |
| `nutrition_recipe_ingredients` | Version ingredient graph | `id` | `recipe_version_id`, `position`, `food_id`, `preparation_id`, `nested_recipe_version_id`, `quantity_value`, `quantity_dimension`, `quantity_unit`, `measure_id`, `lower`, `upper`, `notes` | version, food/prep, nested version, measure | version/position; food |
| `nutrition_user_corrections` | Auditable corrections and mappings | `id` | `user_id`, `target_type`, `target_id`, `field`, `old_value`, `new_value`, `reason`, `source`, `created_at` | target by typed discriminator | user/target; target/time |
| `nutrition_estimates` | Estimate header/provenance | `id` | `user_id`, `source`, `provider`, `model`, `rule_version`, `input_hash`, `assumptions`, `confidence`, `lower`, `upper`, `status`, `supersedes_id` | self supersedes | user/time; source; status |
| `nutrition_estimate_nutrients` | Per-nutrient estimate bounds | `id` | `estimate_id`, `nutrient_id`, `amount`, `lower`, `upper`, `status`, `unit` | estimate, nutrient | estimate; nutrient |
| `nutrition_thalis` | Stable saved thali identity | `id` | `user_id`, `name`, `description`, `lifecycle`, `current_version` | — | user/lifecycle |
| `nutrition_thali_items` | Ordered thali composition | `id` | `thali_id`, `position`, `food_id`, `recipe_version_id`, `quantity_value`, `quantity_dimension`, `quantity_unit`, `measure_id`, `optional`, `notes` | thali, food, recipe version, measure | thali/position; food |
| `nutrition_consumption_snapshots` | Immutable logged meal result | `id` | `user_id`, `logged_at`, `meal_category`, `meal_group_id`, `source_type`, `recipe_version_id`, `thali_id`, `calculator_version`, `completeness`, `estimate_status` | optional recipe/thali | user/time; meal group; source |
| `nutrition_snapshot_items` | Frozen item quantities and references | `id` | `snapshot_id`, `position`, `food_id`, `preparation_id`, `recipe_version_id`, `quantity_value`, `quantity_dimension`, `quantity_unit`, `lower`, `upper`, `source_ref` | snapshot, food/prep, recipe | snapshot/position; food |
| `nutrition_snapshot_nutrients` | Frozen item/meal nutrient outputs | `id` | `snapshot_id`, `item_id`, `nutrient_id`, `amount`, `lower`, `upper`, `status`, `unit`, `source_version` | snapshot/item, nutrient | snapshot/nutrient; item |
| `nutrition_food_constraint_evidence` | Food/ingredient restriction evidence | `id` | `food_id`, `constraint_key`, `status`, `evidence_source`, `confidence`, `notes`, `version` | food | food/key; key/status |
| `nutrition_constraint_definitions` | Constraint taxonomy vocabulary | `id` | `key`, `type`, `display_name`, `severity_supported`, `cross_contact_supported`, `version` | — | unique key/version; type |
| `nutrition_user_constraints` | User restrictions/preferences | `id` | `user_id`, `definition_id`, `value`, `strictness`, `severity`, `cross_contact`, `effective_from`, `effective_to`, `source`, `notes` | definition | user/effective; definition/type |
| `nutrition_snapshot_constraint_results` | Explainable per-snapshot evaluation | `id` | `snapshot_id`, `constraint_id`, `result`, `evidence_ids`, `rule_version`, `evaluated_at` | snapshot, user constraint | snapshot; constraint/result |

The exact Drift types, nullability, cascade behavior, and uniqueness constraints are implementation details for B03-06 but must preserve these semantics. A polymorphic target in `nutrition_user_corrections` is not a foreign-key substitute; implementation must validate target type in the repository.

## Migration and backup

The v16→v17 migration runs transactionally and keeps all legacy tables. It creates the new registry, mappings, and empty B03 user-owned stores before any opt-in mapping. It never backfills a `FoodLog` name into a canonical identity by string alone. Seed rows are mapped only from the reviewed manifest; custom/imported rows are mapped only when provenance is present. Existing logs remain queryable through a legacy adapter until a snapshot is created. Meal templates remain readable and are copied into new recipe versions only through an explicit user action or deterministic reviewed mapping.

The v7→v8 backup envelope exports all user-owned B03 entities, stable IDs, source references, definition versions, personal vessels and retained calibration ancestry, constraints, estimates, recipe/thali versions, and consumption snapshots. Restore order is: validate envelope and supported version; validate manifest and definitions; restore foods/aliases/preparations/facts; measures/personal vessels/calibrations; constraints/evidence; recipes/versions/ingredients; estimates; thalis; snapshots/items/nutrients/results; then legacy data/preferences. Invalid references, bounds, dimensions, vessel ownership, supersession ancestry, or unsupported future versions fail before mutation and roll back. v5/v6/v7 imports remain accepted with B03 sections absent. Derived daily totals are not exported.

The migration must run against a real on-disk v16 fixture and a real backup fixture, not only an in-memory fresh database. A downgrade/rollback test must prove that a failed restore leaves the database unchanged.

## Ownership and read models

| Owner | Sole responsibility | Must not do |
|---|---|---|
| `NutritionCatalogueRepository` | Identity, aliases, preparations, nutrient facts, provenance | Match by display text or rewrite legacy logs |
| `NutritionQuantityService` + `NutritionConversionRepository` | Typed values, dimensions, reviewed/user conversions | Apply global gram/ml/serving assumptions |
| `NutritionRecipeRepository` | Recipe identity, versions, ingredients, lifecycle | Mutate published versions |
| `NutritionCalculationService` | Scaling, composition, nutrient statuses/bounds, calculator version | Persist duplicate daily totals |
| `NutritionConsumptionRepository` | Snapshot creation and immutable history | Recalculate old logs from current catalogue |
| `NutritionEstimateRepository` | AI/photo estimates, uncertainty, corrections, provenance | Store exact-looking values without status/bounds |
| `NutritionThaliRepository` | Saved thali composition and ordering | Maintain a second nutrient engine |
| `NutritionConstraintRepository` | Taxonomy, evidence, conflict evaluation | Infer safety from a name |
| `NutritionReadModelRepository` | Daily/history/analytics projections | Become a source of truth |
| `BackupData` adapter | v8 envelope and legacy compatibility | Export transient derived totals as facts |

## UX flows and state requirements

| Journey | Required behavior | States to design/test |
|---|---|---|
| Create/edit recipe | Draft, ingredient search by identity, scale, publish version | empty, ambiguous, invalid quantity, offline, saved |
| Log partial serving | Choose typed serving/count/measure and show assumptions | unavailable conversion, range, zero, undo |
| Raw/cooked | Select explicit preparation and directional conversion | reviewed, user estimate, unknown, offline |
| Measure/vessel | Choose vocabulary or calibrate a personal vessel | no calibration, approximate, outlier, accessibility |
| Build thali | Add ordered foods/recipes and save or log snapshot | partial, unknown component, constraint results |
| AI/photo estimate | Show source, range, assumptions, correction path | loading, error, retry, offline/manual, deleted image |
| Nutrient detail | Show known, estimated, missing, and bounds distinctly | no data, partial total, history frozen |
| Dietary review | Explain evidence and uncertainty per constraint type | confirmed, possible, no known, insufficient |

## Test matrix

| Area | Required coverage | Gate |
|---|---|---|
| Identity | Stable seed IDs, UUID portability, alias ambiguity, duplicate display names, legacy mapping | Sol High |
| Quantity | Dimension mismatch rejection, finite/nonnegative validation, count/liquid/custom serving, precision/rounding | Sol High |
| Nutrients | Typed units, missing vs known zero, bounds, aggregate completeness, fact-version freeze | Sol High |
| Recipes | Draft/publish, immutable versions, scaling, nested version, substitution provenance | Terra/Sol |
| Raw/cooked | Directional factors, ranges, unknowns, no universal fallback, water/loss cases | Sol High |
| Household/vessel | Vocabulary, food-specific conversion, calibration isolation, approximate display | Sol High |
| Thali | Composition, shared calculator, partial items, save vs log snapshot, offline | Terra/Sol |
| Estimates | JSON validation, range preservation, provider/model/rule, correction/supersession, error fallback | Sol High |
| Protein/leucine | Meal grouping, source classification, unknown leucine, bounded guidance | Sol High |
| Constraints | Taxonomy separation, evidence levels, cross-contact, conflict result, no name inference | Sol High |
| Migration/backup | v16→v17 real fixture, v7→v8 round trip, old imports, invalid rollback, stable IDs | Sol High |
| Compatibility/offline | Existing logs/templates/screens, offline catalogue/logging, concurrent restore guard | Sol High |

## Sol High gates and product decisions

Sol High must explicitly approve: portable identity and legacy mapping; dimension-safe quantity semantics; raw/cooked/yield representation; nutrient status and missing-data behavior; estimate bounds/provenance and image retention; protein/leucine wording; constraint taxonomy and safety language; snapshot authority; schema v17/backup v8 and rollback behavior. Terra High must decide the user-visible recipe/version language, meal boundary semantics, household measure vocabulary, thali component UX, correction flow, and which regional/preparation variants are launch-critical. Neither approval authorizes B04 adaptive coaching.

## B03 definition of done

B03 is complete only when B02 is merged, all Sol/Terra decisions are recorded, schema v17 and backup v8 are reviewed, real v16/v7 fixtures migrate and round-trip, old logs remain stable, new logs use immutable snapshots, quantities reject unlike dimensions, missing nutrients remain visible as missing, estimates preserve bounds and provenance, raw/cooked rules are evidence-backed, constraints are not collapsed, thali/recipe flows use one calculator, offline/error/accessibility states are tested, and `flutter analyze`, the full test suite, Android release build, and iOS no-code-sign release build pass. A final Sol High verification document must record the evidence and list any explicitly deferred capability.
