# B03 Audit — Nutrition Foundation and Food Context

Audit status: complete, read-only repository audit.
Audited baseline: `batch/b03-nutrition-foundation` at B03 planning commit
`efb8a6d`, based on B02 schema v16 and Backup v7.
Scope: application, backend, tests and bundled food assets only. No application
code or food data was modified.

## Executive finding

IndiFit already has a useful offline food-log shell: 573 bundled catalogue
items, local and Open Food Facts search, custom-food entry, barcode lookup,
regional packs, meal templates, a basic thali list, a natural-language parser,
AI text/photo estimation, weekly calorie/protein totals and v7 backup coverage
for the existing food tables. These are reusable foundations, not a B03 data
contract.

The current authority is a display-oriented `FoodItems` row containing one
serving and four numeric nutrient fields. `FoodLogs` then stores copied totals
and a copied name. There is no canonical food identity, ingredient graph,
preparation state, recipe/version graph, normalized nutrient registry,
dimension-safe quantity type, estimate record, or typed dietary constraint
taxonomy. Existing rows remain readable, but most new B03 capabilities cannot
be added safely by extending the current name/serving fields alone.

B01’s final identity decision is directly relevant: database-local integer IDs
are not portable identity, and exact/approved alias resolution must not become
fuzzy matching. B02’s final gate likewise freezes completed facts, preserves
unknown data, prohibits name-derived classification and requires complete
backup/restore coverage. B03 should apply those same rules to food identity,
recipe versions, nutrient facts and consumption snapshots.

## Current capability matrix

| B03 capability | Status | Repository evidence |
|:--|:--|:--|
| Recipe builder | Blocked by architecture | No recipe or ingredient tables; `MealTemplates` stores named macro rows only (`lib/data/database/tables/food_tables.dart:29-53`). |
| Saved reusable recipes | Partially supported | `FoodRepository.saveMealTemplate`, `getMealTemplates` and `logFromMealTemplate` save/replay names, servings and macros, but not food IDs, ingredients or versions (`lib/data/repositories/food_repository.dart:262-384`). |
| Ingredient and recipe scaling | Partially supported | Search, thali and log sheets multiply one serving (`lib/features/food_log/food_search_screen.dart:147-155`, `thali_builder_screen.dart:393-426`); there is no ingredient-level scaling calculator. |
| Raw/cooked conversions | Not supported | “Cooked”, “Raw” and preparation variants occur only in asset names; no state, yield or directional transformation field exists. |
| Visual thali builder | Partially supported | `ThaliBuilderScreen` composes an in-memory list and logs a `mealGroupId`; it has no durable plate geometry or canonical portion graph (`lib/features/food_log/thali_builder_screen.dart:30-201`). |
| Indian household measures | Partially supported | `HouseholdMeasure` has fixed global gram equivalents for katori, cup, roti, piece, ml and thali (`lib/core/utils/household_measures.dart:1-116`), which are not food-specific. |
| Personal vessel calibration | Not supported | No vessel table, calibration flow, user-owned conversion or calibration persistence exists. |
| Estimate confidence ranges | Partially supported | AI UI labels estimates “Moderate Confidence” or “Approximate”, but backend responses contain only point macros and `is_fallback`; no numeric bounds or confidence record is stored. |
| Expanded nutrients | Partially supported | `FoodItems` has nullable `fiberG`; logs and totals use calories/protein/carbs/fat, with no nutrient registry or micronutrient table (`food_tables.dart:3-27`). |
| Protein distribution | Not supported | Weekly totals sum protein across all logs; no meal-level distribution model or threshold calculation exists (`lib/data/repositories/progress_statistics_repository.dart:146-169`). |
| Leucine and protein-quality guidance | Not supported | No leucine, amino-acid, digestibility or protein-quality symbol is present in application or backend code. |
| Structured dietary constraints | Requires product decision | Current storage is one string, `UserProfiles.dietPreference`, mirrored through SharedPreferences; taxonomy, severity, evidence and observance semantics are undefined. |
| Allergy and intolerance handling | Not supported | No allergy or intolerance fields, ingredient evidence, severity, exclusions or safety decision path exists. |
| Regional foods and preparation variants | Partially supported | Five regional packs and a 573-row Indian catalogue exist, with `regionPack` and Hindi display names, but no aliases, canonical IDs, preparation/state fields or variant relations. |

## Food model and identity audit

### Tables and stores

`FoodItems` has an auto-increment `id`, `name`, nullable `nameHindi`, integer
calories, protein/carbs/fat in grams, nullable fiber, `servingSize`, free-text
`servingUnit`, free-text `category`, `isCustom`, nullable `brand` and nullable
`regionPack` (`lib/data/database/tables/food_tables.dart:3-18`). There is no
stable UUID, source/provider identifier, barcode column, alias table, food
state, preparation, density, ingredient composition or source revision.

`FoodLogs` has an optional local `foodItemId`, but also requires copied `name`,
calories, protein, carbs, fat, serving amount/unit, free-text `mealType`, time,
optional group and UUID (`food_tables.dart:21-41`). The copied numbers are a
useful historical snapshot for the existing four nutrients, but the schema does
not say which source revision, calculation rule or completeness state produced
them. `MealTemplateItems` repeats the same name/numbers without even an optional
food ID (`food_tables.dart:45-62`).

The current local ID is not portable. Backup v7 exports only custom food rows,
not the seeded catalogue (`lib/core/backup/backup_schema.dart:148-156`), then
deletes custom rows and re-inserts them with new IDs during restore, remapping
custom log references (`backup_schema.dart:3276-3315`). A log pointing at a
seeded local ID is retained only if the destination already has that same ID;
otherwise it is nulled. That makes the integer useful as a local FK, not a
cross-device food identity.

### Display-text identity locations

The following are all current text-based identity or grouping points found in
the repository:

| File and symbol | Current behavior | Risk | Stable replacement |
|:--|:--|:--|:--|
| `lib/data/database/app_database.dart:218-273`, `AppDatabase.upsertSeededFoodsFromAsset` | Matches non-custom seed rows by exact `name` and overwrites their nutrient/serving fields. | Catalogue rename, duplicate name or translation change can create a new row or mutate a source without provenance. | Reviewed stable catalogue ID plus versioned seed manifest; exact alias mapping only. |
| `lib/data/repositories/food_repository.dart:19-34`, `searchFoodLocal` | Case-folded `name`/`nameHindi` contains search. | Search text is treated as discovery only but has no canonical resolution result. | Return stable food/variant ID and retain query as UI text. |
| `FoodLogs.name`, `FoodRepository.getRecentFoods` (`food_repository.dart:395-440`) | Recent foods are `GROUP BY name`, and results reconstruct a synthetic `FoodItem` with `id: -1` when no FK exists. | Same display name can merge distinct brand, preparation or portion rows. | Group by stable identity plus preparation/source, with explicit unresolved legacy bucket. |
| `MealTemplateItems.name` and `saveMealTemplate` | Reusable meals store names and copied macros only. | Template replay cannot prove which catalogue item or recipe version was used. | Versioned recipe/portion references and immutable template snapshots. |
| `AiMealLoggerScreen._logMeal` (`lib/features/food_log/ai_meal_logger_screen.dart:233-285`) | AI result always logs `foodItemId: null` and uses returned display name. | AI-generated identity is unlinked and cannot be audited or corrected as a source record. | Estimate record with source, candidate matches, user decision and frozen snapshot. |
| `NaturalMealParser.parse` (`lib/core/utils/natural_meal_parser.dart:13-47`) | Parses free text into `foodName`, quantity and unit; it never resolves a catalogue ID. | “dal”, “bowl” and aliases remain ambiguous. | Parse intent, then require a reviewed resolver with unresolved/ambiguous states. |
| `FoodApiService` / `FoodApiResult` (`lib/data/repositories/food_api_service.dart:12-161`) | Open Food Facts result carries name and optional barcode only in memory; macro fields default to zero. | Provider identity and missingness are lost when the result is logged or made custom. | Persist provider/product ID, raw provenance, field completeness and user correction. |
| Backend `/api/ai/meal-plan` and meal text prompts (`backend/main.py:245-353`) | Prompt and output use free-text dish names and a three-value diet string. | Names are not composition or dietary evidence. | Structured ingredients/evidence and explicit uncertainty; no safety inference. |

`FoodItems.brand` exists and the custom editor collects it, but the seeded JSON
has no brand field and `FoodApiResult` does not expose manufacturer/brand. The
barcode flow returns an online result to the search screen; it does not create a
durable provider-backed food record by itself (`barcode_scanner_screen.dart:44-115`).

### Asset inventory

`assets/data/indian_foods.json` contains 573 entries. It has display name,
Hindi name, calories, protein/carbs/fat/fiber, serving size/unit and category;
none of its rows has aliases, brand, raw/cooked state or preparation metadata.
Units include `g`, `ml`, `piece`, `serving`, `bowl`, `cup`, `glass`, `katori`,
`plate` and `thali`. Categories are not normalized: for example both “Dals &
Curries” and “Dals & Legumes”, and both “Vegetables & Sabji” and “Vegetables &
Sabjis”, occur.

The catalogue includes explicit names such as `Basmati White Rice (Cooked)`,
`Amul Fresh Paneer (Raw)` and `Boiled Eggs (2 pieces)`, plus generated-looking
suffix variants such as `(Mini)`, `(Double)`, `(Premium ghee / extra oil)`,
`(Low Oil cooking)` and `(Dhaba Style (High oil))`. These are separate rows,
not structured relationships. Exact duplicate names within the base asset were
not found; exact overlaps between base and regional packs include `Dal
Makhani`, `Gujarati Kadhi`, `Masala Dosa` and `Tomato Rasam`. This audit does
not merge or infer relationships.

Regional assets contain five rows each in Bengali, Gujarati, Maharashtrian,
Punjabi and South Indian packs. They add useful names such as `Machher Jhol
(Rohu)`, `Khaman Dhokla`, `Poha (Kanda Poha)`, `Sarson ka Saag` and `Masala
Dosa`, but remain the same flat macro shape. `FoodRepository.importRegionalPack`
deletes all rows for a `regionPack` before inserting the asset (`food_repository.dart:443-484`);
this is a destructive catalogue refresh, not versioned data ownership.

## Quantity and unit behavior

The only reusable conversion engine is `HouseholdMeasure`. It defines `ml` as
1 gram, `piece` as 50 grams, `serving` as 100 grams, katori as 150/200 grams,
cup as 240 grams, thali as 400 grams, and fixed roti/oil equivalents. Its
`getScaleMultiplier` converts every pair by multiplying those global gram
equivalents (`household_measures.dart:101-116`). Thus unlike dimensions are
silently interchangeable: one ml is treated like one gram, every piece is 50
grams regardless of food, and a katori of water, rice or dal has the same mass.
`findByKey` silently maps an unknown unit to a 100-gram serving (`:89-98`).

The database accepts any non-empty `servingUnit` and any real `servingSize`;
there is no dimension enum, unit registry, density source, lower/upper bound or
database check for finite, positive quantities. The custom editor validates
parseability but not positivity or unit compatibility (`custom_food_editor_screen.dart:47-74,
145-180`). Search logging uses a UI multiplier from 0.25 upward and rounds
calories per item (`food_search_screen.dart:147-281`); thali uses 0.5 steps and
stores the resulting numeric amount (`thali_builder_screen.dart:393-426`).

`NaturalMealParser` recognizes only simple numeric prefixes and normalizes `g`
and `ml`; `bowl`, `piece`, `katori` and unknown words remain arbitrary strings.
It does not reject negative quantities or resolve food density. Backend AI
prompts ask for relative servings such as “plate” or “pieces”, but do not define
dimension semantics (`backend/main.py:247-262`). No raw/cooked conversion,
yield factor, liquid density, countable-food weight or user-entered vessel
calibration exists.

## Nutrition calculation trace

The current path is:

`FoodItems or API/AI point result -> UI multiplier or backend returned serving ->
FoodRepository.logFoodEntry -> copied FoodLogs calories/macros -> dashboard and
ProgressStatisticsRepository sums`

There is no central nutrition calculator. Search and thali calculate
`base nutrient * multiplier` in screen state; AI returns totals; meal-plan
fallback scales each textual meal’s base kcal/protein independently and rounds
each meal (`lib/data/repositories/meal_plan_service.dart:118-146`). `FoodLog`
stores calories as an integer and macro values as doubles. Dashboard totals sum
stored calories (`dashboard_meal_section.dart:511-513`), and weekly totals sum
stored calories/protein (`progress_statistics_repository.dart:146-169`).

Rounding occurs before persistence for calories in search/thali and in the
Open Food Facts adapter (`FoodApiService:69-95`); protein/carbs/fat retain
calculated doubles but are rounded for display. No macro consistency check is
performed. Micronutrients have no typed unit or aggregate path. `fiberG` is
nullable on `FoodItems`, but `FoodRepository.getFiberForLog` returns `0.0` when
the FK or fibre is missing and re-reads the current food definition
(`food_repository.dart:178-188`). That is both a missing-to-zero presentation
and a catalogue-dependent historical value.

Catalogue refreshes overwrite seeded `FoodItems` values by name, but stored
calories/protein/carbs/fat in old `FoodLogs` do not change automatically. An
explicit edit does change the historical row in place through
`updateFoodLog` (`food_repository.dart:201-218`, dashboard editor). Therefore
old totals are mostly stable against catalogue edits, not immutable: fibre can
change indirectly, and user edits rewrite the row without a correction or
provenance record. Recipe edits cannot yet occur because recipes do not exist.

## AI and photo-estimate audit

`AiMealLoggerScreen` sends free text to `/api/ai/meal-estimate-text` or an
800x800, quality-85 selected image to `/api/ai/meal-estimate-photo` when the
privacy policy allows cloud AI (`ai_meal_logger_screen.dart:132-231`). The
backend calls Gemini with prompts requiring `name`, integer calories, protein,
carbs, fat, serving size and unit, parses untyped JSON and adds `is_fallback`
(`backend/main.py:132-198, 245-320`). The prompt even supplies a hard-coded
roti heuristic (“1 roti = 70-80 kcal”), but no rule/model version is returned.

When Gemini is unavailable, backend `_mock_meal_estimate` uses substring checks
for roti/chapati/chicken/egg and returns fixed point values plus
`is_fallback`/`fallback_reason` (`backend/main.py:523-560`). The Flutter screen
labels an absent match as “Moderate Confidence · AI Estimate”, a fallback as
“Approximate · Offline Rule”, and a non-null `matched_food_id` as “High
Confidence · Verified Dish” (`ai_meal_logger_screen.dart:604-620`). The backend
contract shown here does not define a typed match or range, and the screen never
persists the returned map.

Before saving, the user can edit name and four macro fields. `_logMeal` then
persists only the edited point values, serving and free-text name, with
`foodItemId: null`; no estimate source, confidence, bounds, provider/model,
prompt version, ingredient candidates or correction lineage survives. Image
bytes are sent to the backend and not stored in the local database; the screen
does not expose a durable image-deletion policy. Network/HTTP errors show a
snackbar; there is no durable retry or offline estimate record. Privacy gates
and backend authentication/rate limiting are reusable security foundations,
but they do not supply nutrition uncertainty semantics.

## Dietary restrictions and Indian context

Onboarding and profile screens offer only Vegetarian, Non-Vegetarian and Vegan
and store a single string in both SharedPreferences and `UserProfiles.dietPreference`
(`lib/features/onboarding/onboarding_screen.dart:632-661`,
`lib/data/database/tables/user_tables.dart:3-26`). `UserProfileNotifier` reads
SharedPreferences first and then Drift, while profile updates write Drift and
legacy preference keys (`lib/core/di/user_profile_provider.dart:94-180,
302-340`). The two storage paths are a compatibility burden and can disagree.

`MealPlanService._normalizeDiet` uses substring matching to collapse arbitrary
input into `vegan`, `non_veg` or `veg` (`meal_plan_service.dart:92-101`). The
offline meal-plan assets and backend prompts contain free-text titles and
grocery strings, not ingredient evidence. No Jain, halal, kosher, religious
observance, allergy, intolerance, severity, cross-contact, dislike or explicit
ingredient-exclusion model exists. The current AI warning tells the user to
check allergies, but no application filter or safety result exists. B03 must
separate preference, ethical choice, observance, intolerance and allergy and
must disclose incomplete composition rather than infer safety from a dish name.

## Repository impact

| Path and symbol | Current responsibility | B03 impact | Risk |
|:--|:--|:--|:--|
| `lib/data/database/tables/food_tables.dart`, `FoodItems`/`FoodLogs` | Stores flat catalogue, copied log totals and meal groups. | Add or coexist with canonical identity, quantities, facts, recipes, snapshots and constraints. | High migration and historical-authority risk. |
| `lib/data/repositories/food_repository.dart`, `FoodRepository` | Search, insert, log, edit, copy, templates and regional-pack import. | Split catalogue, recipe, calculation and consumption ownership; preserve legacy adapters. | Competing calculation authorities. |
| `lib/data/database/app_database.dart`, `AppDatabase` | Seeds foods; v2–v16 migrations; name-based seed upsert. | New migration and seed manifest/version policy. | Silent name match and rollback/data loss. |
| `lib/core/utils/household_measures.dart`, `HouseholdMeasure` | Global gram-equivalent conversion. | Replace or isolate with dimension-safe, food-specific conversion contracts. | False precision and unlike-unit conversion. |
| `lib/features/food_log/food_search_screen.dart` / `thali_builder_screen.dart` | Multiplier UI and direct numeric logging. | Become consumers of canonical portions/snapshots. | UI-local totals diverge from domain totals. |
| `lib/features/food_log/meal_templates_screen.dart` and `MealTemplate*` | Saves/replays reusable named macro bundles. | Compatibility read model or migration to recipe versions. | Existing templates cannot be semantically reconstructed. |
| `lib/data/repositories/food_api_service.dart` | Open Food Facts barcode/search adapter. | Persist provider identity and field completeness; retain offline result policy. | API zero defaults and lost provenance. |
| `backend/main.py`, AI endpoints | Gemini text/photo/plan calls and heuristics. | Contract for typed estimates, bounds, provenance and safe correction. | Unvalidated exact-looking AI output. |
| `lib/core/di/user_profile_provider.dart` and profile/onboarding screens | Diet string, targets and dual persistence. | Typed constraints and one durable owner. | Preference drift and unsafe filtering. |
| `lib/data/repositories/progress_statistics_repository.dart` | Seven-day sum of stored calories/protein. | Read canonical nutrient snapshots with completeness-aware aggregates. | Unknown nutrients and meal distribution lost. |

## Data impact

| Table/store | Current role | Likely B03 change | Migration concern |
|:--|:--|:--|:--|
| `food_items` | Seeded/custom flat foods; local integer IDs. | Stable identity, source/version, state/preparation, aliases, nutrient facts. | Do not reinterpret names or mutate custom provenance. |
| `food_logs` | Historical copied macro rows. | Add snapshot/provenance or compatibility projection; preserve legacy values. | Existing rows lack enough evidence for safe reconstruction. |
| `meal_templates` / `meal_template_items` | Named reusable macro bundles. | Keep readable; optionally map only when identity is proven. | No ingredient IDs or version link today. |
| `user_profiles` and SharedPreferences keys | Targets plus one diet string. | Typed constraint records and single source of truth. | Preserve existing strings without claiming richer semantics. |
| Regional JSON and `regionPack` rows | Replaceable five-row packs. | Versioned seed manifests, variants and aliases. | Current import deletes a pack before reinsertion. |
| Backup v7 envelope | Custom foods, all food logs/templates and profile/prefs. | New collections and likely version increment after contract approval. | v5/v6/v7 import and local-ID remap rules must remain tested. |

## Calculation impact

| Service or function | Current calculation | Risk | Required replacement |
|:--|:--|:--|:--|
| `FoodSearchScreen._showLogDialog` | Multiplies one base serving; rounds kcal. | Serving dimensions are assumed compatible. | Typed quantity calculator with explicit conversion result/unknown. |
| `ThaliBuilderScreen` getters and `_logThali` | Multiplies catalogue serving; logs one row per item. | No canonical portion or snapshot; totals can drift. | Portion graph resolved once into an immutable meal snapshot. |
| `HouseholdMeasure.getScaleMultiplier` | Global gram-equivalent ratio for all units. | ml/piece/katori density and food context are ignored. | Food-specific reviewed conversion or calibrated user rule. |
| `MealPlanService._generateOfflineFallback` | Scales each text meal’s base kcal/protein and rounds. | Text plan is not a nutrient calculation or ingredient graph. | Use only as educational fallback, not B03 nutrition authority. |
| `ProgressStatisticsRepository.getWeeklyMetrics` | Sums stored log kcal/protein; missing fibre helper returns zero. | Unknownness and micronutrients disappear. | Completeness-aware aggregation with typed units and bounds. |
| `FoodRepository.getFiberForLog` | Re-reads current food fibre and scales by serving. | Historical result changes after catalogue update; null becomes 0. | Snapshot nutrient facts and explicit unknown state. |

## Test coverage

| Behavior | Existing tests | Missing coverage |
|:--|:--|:--|
| Local food search | `test/food_repository_test.dart` covers English/Hindi name contains and no match. | Stable identity, aliases, ambiguity, brand, regional variant and provenance. |
| Household conversion | `test/data_quality_gaps_test.dart:63-97` checks fixed katori/roti ratios. | Unlike dimensions, density, unknown units, negative/zero/finite validation and calibration. |
| Natural-language quantity parsing | `test/natural_meal_parser_test.dart` covers `2 rotis`, `100g paneer`, `1 bowl dal`. | Resolution, aliases, invalid/negative quantities, count/liquid semantics and offline calculation. |
| Custom foods | `test/food_repository_test.dart` inserts a custom row for search; backup tests include custom rows. | Form validation, source/brand/barcode, unit safety, edits and provenance. |
| Templates/thali | `data_quality_gaps_test.dart` covers template CRUD/logging; no thali screen test was found. | Recipe versions, ingredient scaling, thali snapshot, raw/cooked state and history immutability. |
| Food logging/editing | `phase1_data_foundation_test.dart` and dashboard paths cover weekly sums; UI edit has no focused test. | Catalogue-change stability, explicit correction lineage, rounding and unknown nutrient behavior. |
| Daily/weekly totals | `phase1_data_foundation_test.dart:231-301` verifies seven-day calorie/protein sums. | Micronutrients, ranges, meal distribution, local timezone boundaries and completeness. |
| Backup/restore | `backup_schema_test.dart`, `b01_backup_v6_test.dart`, `b02_backup_v7_test.dart`, `backup_restore_transaction_test.dart`. | Portable seeded identity, all future B03 rows, snapshot provenance and unknown preservation. |
| Migration | v14→v15 and v15→v16 real fixtures and rollback suites exist. | B03 nutrition fixture with legacy food logs, custom foods, templates and no reinterpretation. |
| AI estimates | `backend/tests/test_ai_security.py` tests authentication/security; no nutrition payload contract test found. | JSON schema, bounds/confidence, model metadata, fallback, correction, persistence and privacy deletion. |
| Dietary preferences | `phase3_profile_and_meal_plans_test.dart` covers veg/vegan/non-veg fallback behavior. | Typed allergies/intolerances/religious/ethical/dislike evidence and uncertainty. |
| Offline behavior | `meal_plan_service_test.dart` and privacy tests cover fallback/policy. | Offline catalogue/quantity/calculation/estimate persistence and restart continuity. |

## Highest-risk findings

1. `FoodItems.id` is device-local and seeded food rows are not exported in v7;
   seeded log references are therefore not backup-stable across installations.
2. Seed refresh updates food definitions by exact display name and can change
   current catalogue facts without a source/version boundary.
3. Logged kcal and macros are copied and usually stable, but explicit log edits
   rewrite history and fibre is re-derived from the current catalogue, so the
   existing model is not fully immutable.
4. `HouseholdMeasure` silently converts unlike dimensions and unknown units to
   serving equivalents; this is an unsafe foundation for katori, cup, glass,
   piece or liquid logging.
5. No raw/cooked or preparation data exists beyond strings, so safe yield
   conversion cannot be migrated from current rows without reinterpretation.
6. Missing fibre and Open Food Facts nutrient fields can become numeric zero;
   there is no missing/known-zero distinction or micronutrient unit registry.
7. AI/photo estimates are exact-looking point macros. Ranges, confidence,
   model/provider, prompt/rule version, ingredients and user correction lineage
   are not persisted.
8. Allergy, intolerance, religious, ethical and dislike concepts are absent;
   the current diet string and free-text meal plans cannot establish safety.
9. Templates, thalis and natural-language parsing operate outside a shared
   calculation authority, so the same food can produce different meanings and
   totals in different flows.
10. B03 will require a schema/backup transition for durable recipes, facts,
    snapshots, calibrations, estimates and constraints; existing v5/v6/v7
    compatibility must be proven before any legacy reinterpretation.

## Reusable foundations

- Drift tables, transactions, FK enforcement and explicit migration rollback
  injectors in `AppDatabase` provide a strong persistence base.
- B01’s stable-ID/alias policy, immutable published-version rule and
  compatibility-adapter pattern provide the right precedent for canonical food
  identity and recipe versions.
- B02’s final verification freezes completed facts, preserves unknowns and
  requires typed Backup v7 graph validation; these are directly reusable.
- `FoodRepository` already owns local food operations, meal grouping and
  template transactions, so B03 can evolve ownership without scattering writes.
- Bundled `indian_foods.json`, five regional packs and Hindi labels provide a
  valuable seed corpus, subject to audit and versioning rather than merging.
- Privacy policy gates, backend API authentication/rate limiting, file type/size
  checks and offline meal-plan fallbacks are useful platform foundations.
- Existing v5/v6/v7 backup fixtures, real schema migration fixtures and weekly
  metric clock injection provide patterns for B03 regression coverage.

## Questions for Terra High

- Which current seed rows are authoritative catalogue facts, and which are
  product examples or estimates that must remain visibly approximate?
- Which user-visible B03 portion vocabulary is required for MVP: grams,
  millilitres, count, serving, katori, bowl, cup, glass, ladle, spoon, plate
  and thali? Which labels need Hindi/regional aliases?
- Should the current meal template concept remain a reusable macro snapshot,
  become a recipe, or coexist as a legacy template with a clear distinction?
- Which five regional packs are release-critical, and which regional dishes need
  separate preparation variants rather than aliases?
- What user correction flows are required for custom foods, barcode foods and AI
  estimates, including edit, duplicate, archive and delete behavior?
- Which protein-distribution and leucine guidance is acceptable as general
  wellness education, and how should measured data differ from heuristics?
- What UX should show an approximate portion, unknown nutrient, incomplete
  ingredient composition or unresolved dietary conflict?

## Questions requiring Sol High

- What is the canonical food identity contract, including seeded manifest IDs,
  custom/imported identity, provider/barcode identity, aliases and ambiguous
  matches?
- Are recipes immutable-versioned, snapshot-only, or both, and exactly which
  resolved quantities/facts must be frozen in a historical consumption record?
- What typed quantity dimensions and conversion rules prevent mass/volume/count
  interchange, and what is the approved policy for food density and personal
  vessel calibration?
- What is the B03 schema version and backup version, and how will v5/v6/v7
  imports preserve legacy rows without inventing composition or identity?
- How are missing, known-zero, not-applicable and estimated nutrient values
  represented and aggregated, including bounds and partial totals?
- What provenance contract is mandatory for Open Food Facts, bundled data,
  custom entries, AI/photo results, user corrections and offline heuristics?
- What structured evidence is sufficient to classify an allergy, intolerance,
  religious restriction, ethical preference or dislike, and how is unknown
  composition exposed without a medical-safety claim?
- Which repository is the sole writer for catalogue facts, recipes, snapshots,
  estimates and constraints, and how will legacy `FoodRepository` APIs adapt?

## Recommended prerequisite tasks

1. Freeze Terra/Sol product and architecture decisions above before schema work.
2. Produce a read-only seed-data manifest audit: stable candidate IDs, aliases,
   regional overlaps, preparation/state candidates and source/completeness flags;
   do not merge or rewrite rows in the audit phase.
3. Add executable contract fixtures for dimensions, unknown units, known zero vs
   missing, raw/cooked directionality, household measures, estimates and typed
   dietary evidence.
4. Define the canonical quantity/nutrient/provenance value objects and pure
   calculation rules before adding UI or repository writes.
5. Design a legacy adapter that reads existing `FoodItems`, `FoodLogs` and
   templates without claiming facts that cannot be recovered.
6. Build a real v16 database fixture containing seeded/custom foods, logs,
   edited logs, grouped meals, templates and profile preferences; prove
   migration rollback and no reinterpretation.
7. Specify the B03 backup graph and add v5/v6/v7 import plus new-format
   round-trip/rollback fixtures for every new user-owned row.
8. Only then implement recipes, portions/thali, estimates, constraints and
   screens as consumers of the shared contracts.

## Existing behavior to freeze with regression fixtures

- Existing v16 databases open with every current food table and seeded catalogue
  row readable.
- Existing `FoodLogs` retain their stored calorie/protein/carbs/fat values after
  catalogue refresh, migration and restore; legacy names remain visible.
- Existing custom food rows, brands, regional-pack tags and optional fibre
  values survive v7 restore, including local-ID remapping behavior.
- Existing meal templates replay the same item count, serving labels and stored
  macro values until an explicit product-approved migration occurs.
- Existing meal grouping, repeat-last-meal, thali logging and food-log editing
  continue to work without creating duplicate totals.
- Existing v5/v6 imports and v7 restore remain accepted and transactional.
- Existing offline food search, meal-plan fallback and privacy refusal behavior
  remain intact when no network is available.
- Existing three-value diet preference behavior remains readable, but must be
  treated as legacy preference input rather than upgraded silently into allergy
  or safety evidence.

## Audit conclusion

B03 should add a typed, versioned nutrition domain beside the legacy flat food
tables and migrate only semantics that are provable from stored evidence. The
current code supports basic logging and useful product journeys, but it cannot
reliably support recipes, raw/cooked conversion, calibrated household measures,
expanded nutrients, estimate ranges or allergy-aware filtering without first
freezing identity, quantity, provenance, uncertainty, snapshot and backup
contracts. No implementation branch should begin until the Terra High choices
and Sol High decisions above are recorded and the legacy regression fixtures
pass.
