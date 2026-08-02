# B03 Audit — Nutrition Foundation and Food Context

## Scope and baseline

This audit records the planning baseline at commit `330bda5`, schema v16 and
Backup v7. B02 is verified for integration but is not yet merged into the
accepted release branch. This document therefore authorizes B03 contract
planning only; implementation branches remain gated by the B02 final Sol gate.

## Existing nutrition surface

| Area | Current implementation | B03 implication |
|:--|:--|:--|
| Food catalogue | `FoodItems` has an auto-increment integer ID, display names, Hindi name, fixed calories/macros, one serving size/unit, category, brand and region pack. | Add stable canonical identity, aliases, preparation/state context, nutrient facts and source/version metadata without making display text identity. |
| Food logs | `FoodLogs` stores a name and aggregate calories/macros plus serving value/unit, optional catalogue ID, meal type, timestamp and group ID. | Preserve existing rows and add immutable snapshot/provenance fields for new records; legacy rows must remain readable with explicit unknown states where data is absent. |
| Meal templates | `MealTemplates` and `MealTemplateItems` store reusable names and fixed macro totals. | Recipes need a separate versioned owner; templates require a compatibility/read-through policy rather than silent reinterpretation. |
| Repository | `FoodRepository` searches locally, inserts custom foods, logs entries, updates logs and copies meal groups. | Introduce typed quantity, recipe, portion and snapshot services; keep legacy repository reads compatible during migration. |
| Thali UI | The current builder multiplies a catalogue serving and writes separate food-log rows into a meal group. | Replace multiplier-only semantics with canonical portions, units, uncertainty and a durable thali/consumption snapshot contract. |
| Existing data | Regional JSON packs and local food search provide useful seed material, but aliases and regional variants are not canonicalized. | Audit and version seed data; distinguish materially different preparations and retain user corrections separately. |
| Backup/restore | Backup v7 serializes existing food logs, food items and meal templates. | Add every B03 user-owned entity to a versioned format with v5/v6/v7 imports and transactional restore coverage. |

## Main risks

1. Existing `FoodLogs` aggregate values can be mistaken for authoritative
   nutrient facts. Historical rows need a compatibility adapter and explicit
   provenance/unknown semantics.
2. A single `servingSize` plus `servingUnit` cannot safely represent mass,
   volume, count, raw/cooked state or food-specific household measures.
3. Recipe edits can rewrite history if logs retain only a recipe ID. B03 must
   freeze the consumed version and resolved ingredient quantities at log time.
4. Dish names, Hindi names and regional pack labels are insufficient for
   allergy or dietary filtering. Incomplete composition must produce an
   uncertainty disclosure.
5. Nutrient totals can silently turn missing values into zero through current
   numeric fields and UI defaults. The new value model must carry known/missing
   completeness independently of numeric value.
6. AI/photo estimates can be presented as exact portions unless range,
   confidence, source and model/rule version travel with the estimate.
7. Migration and backup omissions are high-impact because recipes, custom foods,
   calibrations and constraints are user-owned records.

## Required reconnaissance before implementation

- Inventory all food-log writers and readers, including AI logger, barcode,
  custom-food editor, meal templates and thali flows.
- Inventory seed assets and define canonical IDs, alias ownership and release
  versioning for each regional pack.
- Inspect existing database migration and backup fixtures at v15/v16 and v5/v6/v7.
- Establish a reviewed nutrient registry and unit policy before adding columns
  or calculation code.
- Capture fixture cases for raw/cooked food states, household measures,
  unknown nutrients, incomplete ingredients and user corrections.

## Audit conclusion

The current foundation is useful for backward-compatible reads and simple meal
logging, but it is not a safe authority for recipes, conversions, expanded
nutrients or constraint filtering. B03 should add a typed, versioned nutrition
domain beside the legacy tables, migrate only where semantics are provable, and
make all new writes snapshot- and provenance-first.

