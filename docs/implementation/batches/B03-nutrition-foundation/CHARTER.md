# B03 — Nutrition Foundation and Food Context

Status: Chartered (planning only; implementation remains gated on B02 final Sol approval and merge)  
Base commit: `330bda5`  
Base branch: `batch/b02-workout-execution`  
Current database schema: `v16`  
Current backup format: `v7`  
Platforms: Android and iOS

## Goal

Build IndiFit’s reliable, offline-first nutrition-data foundation for recipes,
Indian household measures, cooked/raw conversions, thali construction, expanded
nutrients, uncertain estimates and structured dietary constraints. B03
establishes data and calculation contracts; B04 will use these contracts for
adaptive nutrition coaching.

## Included features

- Recipe builder, saved/reusable recipes, versioning and deterministic scaling
- Raw-to-cooked and cooked-to-raw food conversions
- Visual thali builder using canonical portions
- Indian household measures and personal vessel calibration
- AI/photo estimate confidence ranges and provenance
- Expanded macro and micronutrient tracking
- Meal-level protein distribution, leucine and protein-quality guidance
- Structured dietary preferences, restrictions, allergies and intolerances
- Regional Indian food variants and aliases

## Required foundations

- Stable canonical food, ingredient, preparation and recipe identities
- Typed quantity and unit representation
- Food-specific household-measure conversions
- Versioned recipes and immutable consumption snapshots
- Nutrient definitions with explicit units; missing values are unknown, not zero
- Estimate provenance, confidence and bounds
- Structured dietary-constraint taxonomy
- Backup and migration coverage for every new user-owned record

## Excluded from B03

- Adaptive calorie changes based on bodyweight trend
- “What can I eat now?”, festival mode, eating-out coaching mode and
  intermittent-fasting coaching mode
- Daily nutrition briefing, weekly adaptive nutrition review and
  recovery-linked food recommendations
- Medical diagnosis or allergy-safety guarantees
- Full AI image-recognition implementation unless an existing provider already
  supplies estimates
- Final Today-page nutrition redesign

## Binding principles

- Existing food logs remain readable.
- Editing a saved recipe must not rewrite historical consumption.
- Display names are not portable identity.
- Quantities retain units and food context; one global cooked-weight multiplier
  is prohibited.
- Household measures may be food-specific or user-calibrated.
- Approximate portions are never displayed as exact measurements.
- Missing nutrient data is unknown, not zero.
- AI or heuristic estimates retain source, range, confidence and rule/model
  version.
- User corrections never silently rewrite the source catalogue.
- Allergies, intolerances, religious restrictions, ethical preferences and
  dislikes remain distinct concepts.
- Constraint filtering discloses uncertainty when ingredient composition is
  incomplete and never claims medical safety from absence of a known conflict.
- Every user-owned entity participates in backup and restore.
- Nutrition calculations work offline once required data is available locally.

## Preliminary domain rules

These require validation during the Sol architecture gate:

- Recipes use immutable versions or immutable consumption snapshots.
- Recipe totals are calculated from ingredient quantities and preparation/yield
  transformations.
- Food quantities use explicit dimensions such as mass, volume, count or
  serving.
- Household measures resolve through reviewed food-specific or user-specific
  conversions.
- Raw/cooked transformations are directional and preparation-specific.
- Nutrient values retain source and completeness.
- AI estimates store point estimate, lower bound, upper bound and confidence.
- Leucine guidance distinguishes measured values from heuristics.
- Dietary constraints use stable typed identifiers rather than display-text
  matching.
- Regional dishes with materially different preparation or ingredients remain
  distinct variants.

## Batch exit criteria

- Users can create, edit, duplicate and save recipes.
- Recipe scaling is deterministic and unit-safe; historical logged meals remain
  unchanged after recipe edits.
- Supported foods convert between approved raw and cooked states.
- Indian household measures and calibrated personal vessels can be used for
  food logging.
- A thali assembles canonical portions and recalculates nutrition correctly.
- Expanded nutrients distinguish known zero from missing data.
- Uncertain meal estimates retain ranges, source and confidence.
- Protein distribution and leucine/protein-quality guidance disclose estimation
  quality.
- Structured dietary constraints are persisted and applied consistently.
- Existing nutrition logs remain compatible.
- Migration from the accepted B02 baseline passes using a real database fixture;
  previous supported backups remain importable and new nutrition data
  round-trips through the new backup format.
- Full tests, analysis, supported release builds and final Sol High verification
  pass.

## Non-goals

- Do not build the B04 adaptive-coaching engine.
- Do not silently infer allergens from dish names alone.
- Do not use approximate household portions as exact gram values without
  uncertainty.
- Do not force every quantity into grams when its source dimension is volume or
  count.
- Do not store calculated nutrient totals as independent competing authorities
  without a versioning or snapshot rule.
- Do not redesign the entire nutrition UI in one task.

