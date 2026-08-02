# B03 — Nutrition Foundation and Food Context: Architecture Plan

## 1. Delivery posture

B03 is currently a planning branch. No implementation/task branches may be
created until B02 has passed its final Sol gate and has been merged into the
accepted base. The plan below is the contract to review at that gate.

## 2. Ownership model

| Concept | Canonical owner | Historical rule |
|:--|:--|:--|
| Food identity | `CanonicalFoods` plus versioned aliases | Display names are labels only. |
| Preparation/state | `FoodPreparations` and directional conversion rules | Raw/cooked state is part of food context. |
| Nutrient definition | `NutrientDefinitions` | Every value carries unit and completeness. |
| Food nutrient fact | Versioned food-nutrient facts | Source catalogue revisions do not rewrite snapshots. |
| Recipe | Recipe header and immutable `RecipeVersions` | Editing creates a new version. |
| Recipe ingredient | Versioned ingredient rows with typed quantity and context | Ingredient resolution is frozen in consumption snapshots. |
| Household measure | Reviewed food-specific conversion or user calibration | No global cooked-weight multiplier. |
| Consumption | Immutable meal/recipe/thali snapshot | Later edits never rewrite history. |
| Estimate | Estimate provenance record | Point estimate never replaces bounds/confidence. |
| Dietary constraint | Stable typed taxonomy and user profile records | Matching is structured; unknown composition remains unknown. |

## 3. Quantity and calculation contract

Every quantity is represented by a numeric value, dimension (`mass`, `volume`,
`count`, `serving` or `household`), unit, food/preparation context and
approximation metadata. Conversions are explicit and directional. A conversion
must identify its rule version and source; a missing conversion remains
unknown rather than falling back to a global factor.

Recipe totals resolve each ingredient through its selected food state, quantity,
yield/conversion transformation and nutrient fact version. Scaling is a pure
deterministic operation over the typed quantities and must reject incompatible
dimensions rather than silently converting them.

## 4. Snapshot and version contract

Recipes have a stable identity and immutable versions. A logged recipe, thali or
estimated meal stores the resolved ingredient/portion graph, quantities, nutrient
fact references, conversion references, calculation rule version and estimate
metadata. The read model may recalculate a presentation total, but historical
truth is the immutable snapshot, not the current recipe catalogue.

## 5. Nutrient and uncertainty contract

The registry must include explicit units, display precision, category and source
policy for energy, macros, fiber, vitamins, minerals, amino acids and any
additional supported nutrient. A nutrient value is one of `known`, `knownZero`,
`missing` or `notApplicable`; `missing` is never serialized as numeric zero.

An estimate stores point value (when available), lower bound, upper bound,
confidence, source (`user`, `catalogue`, `photo`, `AI`, `heuristic` or
`import`), source reference and model/rule version. UI summaries must preserve
the distinction between exact, estimated and unknown totals.

## 6. Dietary constraints

Use stable identifiers for allergens, intolerances, religious restrictions,
ethical preferences and dislikes. Food and recipe composition expose positive,
negative and unknown evidence. Filtering returns a reason and uncertainty state;
absence of a detected conflict is not a medical-safety claim. Dish-name matching
may improve search only and cannot establish safety.

## 7. Migration and backup strategy

Retain legacy food tables and compatibility readers. Add one reviewed schema
version for the B03 durable graph only after the final table set is approved.
Migration must be transactional and must not fabricate canonical identities or
ingredient composition from names alone. Existing food logs are imported as
legacy snapshots with their known fields and unknown completeness where needed.

The next backup format must serialize every B03 user-owned row, seed/catalogue
references needed for offline restore, calibration, corrections, recipe versions,
consumption snapshots, estimates and constraints. v5/v6/v7 imports remain
accepted according to the existing compatibility policy. Restore must validate
references before mutation and roll back on failure.

## 8. Proposed implementation sequence

1. Freeze fixtures, identity rules, nutrient registry and compatibility matrix.
2. Add domain value objects and pure quantity/conversion/nutrient calculators.
3. Add canonical catalogue, aliases, preparations and user-correction ownership.
4. Add immutable recipes, scaling and consumption snapshots.
5. Add household measures, vessel calibration, thali composition and estimates.
6. Add constraints, regional variants and explainable filtering.
7. Add repositories, UI adapters and legacy read/write compatibility.
8. Add schema migration, backup/restore and release verification.

## 9. Explicit deferrals

Adaptive calorie changes, coaching prompts, fasting/festival/eating-out modes,
medical safety claims, full image recognition and a full Today-page redesign are
outside this architecture. B04 may consume B03 contracts only after snapshots,
uncertainty and constraint semantics are stable.

