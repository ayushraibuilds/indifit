# B03 — Nutrition Foundation and Food Context: Decision Register

Status: Gate completed at planning commit `c84aa97b8968dae8e4b112f9b0f3a2ab57266ae6` on 2026-08-02. The gate verdict is **Passed with automatically accepted defaults**. These decisions authorize the planning-to-implementation transition only after the dependency and review gates in `TASKS.md` are satisfied; they do not implement B03 application behavior.

The canonical roadmap, accepted B01 decisions, accepted B02 decisions, and
`CHARTER.md` remain binding. This register controls the proposal in `PLAN.md`
where the two differ. No application code, schema, backup code, food asset, or
task branch was changed by this gate.

## Gate inventory

### Items explicitly marked for Sol review

The inspected planning set marked the following as `SOL-GATE REQUIRED`:

- `PLAN.md`: raw/cooked conversion; protein distribution and leucine; dietary-constraint taxonomy.
- `TASKS.md`: B03-01, B03-02, B03-03, B03-04, B03-05, B03-06, B03-09, B03-10, B03-11, B03-14, B03-15, B03-16, and B03-18.
- `DECISIONS.md`: D01–D05, D07–D11, D13–D15 were gated; D06, D12, D16, and D17 were proposed but not explicitly gated.

The gate adds mandatory Sol review to recipe immutability/calculation,
thali/shared-calculation behavior, saved-recipe and food-log integration,
the food-identity manifest, the legacy adapter, and the integrated regression
task. These were important high-risk omissions in Terra’s proposal because they
can mutate history or create a second calculation/safety authority.

The complete amended Sol inventory is B03-01, B03-02, B03-03, B03-04, B03-05,
B03-06A, B03-06B, B03-07, B03-08, B03-09, B03-10, B03-11A, B03-11B,
B03-12, B03-13, B03-14, B03-15, B03-16, B03-17, and B03-18. B03-08,
B03-13, and B03-17 receive mandatory Sol integration review; the remaining
items have a standalone Sol gate. Terra’s review is additive for the UX and
language surfaces named in the task matrix.

### Proposed schema change inspected

The proposal is a v16 → v17 Drift migration and introduces these tables:

`nutrition_foods`, `nutrition_food_aliases`, `nutrition_food_preparations`,
`nutrition_legacy_food_mappings`, `nutrition_nutrient_definitions`,
`nutrition_food_nutrient_facts`, `nutrition_quantity_conversions`,
`nutrition_household_measures`, `nutrition_vessel_calibrations`,
`nutrition_recipes`, `nutrition_recipe_versions`,
`nutrition_recipe_ingredients`, `nutrition_user_corrections`,
`nutrition_estimates`, `nutrition_estimate_nutrients`, `nutrition_thalis`,
`nutrition_thali_items`, `nutrition_consumption_snapshots`,
`nutrition_snapshot_items`, `nutrition_snapshot_nutrients`,
`nutrition_food_constraint_evidence`, `nutrition_constraint_definitions`,
`nutrition_user_constraints`, and `nutrition_snapshot_constraint_results`.

The accepted amendments are: recipes are not foods; the legacy mapping table
is the sole v16 bridge; direct-food recipe ingredients are the B03 MVP;
vessel calibration is volume-only; snapshot nutrient rows are complete source
and result snapshots; constraint evidence is typed and backed by a validated
child relation rather than an unchecked ID string; and any nullable recipe
current-version pointer must not create a foreign-key cycle or a second
mutable authority. The 24-table proposal is therefore amended with the
validated child relation `nutrition_snapshot_constraint_result_evidence`,
which replaces `evidence_ids`-style serialized references and points each
snapshot result to typed food/ingredient evidence. A checked-in
food-identity manifest is a required release artifact at
`assets/data/nutrition_food_identity_manifest.json`, not a runtime substitute
for the database identity tables.

### Proposed backup change inspected

The proposal is Backup v7 → v8. A v8 export must cover every new user-owned
row: user/imported foods, user aliases and corrections, preparation choices,
user conversions and vessel calibrations, nutrient overrides, recipes and
versions, recipe ingredients, saved thalis and items, estimates and
corrections, constraints and user-declared evidence, and consumption snapshots
including item quantities, nutrient rows, source metadata, and lineage. Seeded
catalogue rows are resolved by a checked-in manifest/version rather than
duplicated as user data. Legacy `FoodLogs` and `MealTemplates` remain in the
compatibility sections.

Restore must prevalidate manifest availability, stable IDs, dimensions,
bounds, enum values, one-of relationships, recipe/constraint/snapshot
relationships, and source versions before mutation. The existing transaction
and SharedPreferences compensation contract remains binding. Derived daily
totals and temporary images are not exported.

### High-risk and critical tasks inspected

Critical tasks are B03-01, B03-02, B03-04, B03-05, B03-06, B03-08’s calculation
consumer, B03-09, B03-11, B03-14, B03-15, B03-16, and B03-18. High-risk tasks
are B03-03, B03-07, B03-08, B03-10, B03-12, B03-13, and B03-17. The task
matrix is amended so every one has a named implementation model and an
appropriate Sol and/or Terra review point.

### Sol assignments, algorithms, and historical decisions

- Sol implementation/review is required for identity and manifest validation, quantity dimensions and conversions, nutrient completeness, schema/migration, backup/restore, raw/cooked rules, snapshots, estimate uncertainty/privacy, constraints, protein/leucine boundaries, and final verification.
- Terra owns user-visible language and journey review for recipes, measures, thalis, estimates, constraints, and regional labels. Terra does not approve data-integrity or safety semantics alone.
- GPT Luna is limited to deterministic fixtures, serializers, pure value objects, bounded services after these contracts are frozen, migration mechanics under review, and CRUD/UI wiring with no local calculation authority.
- The algorithms under review are exact/ambiguous identity resolution; typed quantity conversion; directional yield transformation; nutrient scaling and bound aggregation; estimate parsing/correction; descriptive protein distribution; and deterministic four-state constraint evaluation.
- Existing food-log values, timestamps, meal categories, grouping IDs, custom rows, imported provenance, meal templates, and legacy AI-shaped rows are preserved as legacy data. No current catalogue or alias is allowed to reinterpret them.

### Custom/imported foods and dietary restrictions

User-created foods receive portable UUIDs and append-only fact/correction
provenance. Imported foods retain provider namespace, external product ID,
barcode where present, source revision, and field-level missingness. Regional
and preparation variants remain distinct. Allergy, intolerance, religious,
ethical, pattern, dislike, temporary, and regional constraints remain typed and
independent; names alone never establish composition or safety.

### Product-owner questions found in the audit

The audit asked which seed rows are authoritative, which measures/labels are
needed, what to do with meal templates, which regional packs are launch
critical, how correction/archive/delete should work, what protein/leucine
guidance is acceptable, and how incomplete/approximate/conflicting data should
be shown. The defaults below resolve those ordinary questions under the
product-owner authorization. No exceptional confirmation is required.

## Decision summary

| ID | Final decision | Status | Authority |
|---|---|---|---|
| B03-D01 | Separate portable food/preparation identity from recipe, thali, estimate, and legacy identity | Amended | Sol High |
| B03-D02 | Exact-after-narrow-normalization identity resolution with explicit ambiguity | Accepted | Sol High |
| B03-D03 | Preserve legacy food/log/template semantics; do not speculate during migration | Amended | Sol High |
| B03-D04 | Canonical quantity is mass, volume, or count; serving/household input resolves only with evidence | Amended | Sol High |
| B03-D05 | Conversions are scoped, directional where applicable, bounded, and provenance-bearing | Accepted | Sol High |
| B03-D06 | Direct-food recipes use immutable versions; nested recipes are deferred | Amended | Terra High + Sol High |
| B03-D07 | Hybrid immutable consumption snapshots are the historical authority | Amended | Sol High |
| B03-D08 | Raw/cooked transformations use reviewed food/method rules; unsupported direction remains unavailable | Amended | Sol High |
| B03-D09 | Household labels are contextual; personal vessel calibration is volume-only in B03 | Amended | Terra High + Sol High |
| B03-D10 | Nutrient facts use typed rows, explicit status, basis, source, and bounds | Amended | Sol High |
| B03-D11 | Estimates retain per-nutrient uncertainty and correction lineage; images are transient | Amended | Sol High |
| B03-D12 | Thalis are free-form ordered compositions using the shared calculator and snapshots | Amended | Terra High + Sol High |
| B03-D13 | Protein distribution is descriptive; measured leucine is supported, detailed heuristics/thresholds are deferred | Amended | Sol High |
| B03-D14 | Constraints use typed evidence and four cautious evaluation states | Amended | Terra High + Sol High |
| B03-D15 | Schema v17 and Backup v8 are transactional, manifest-aware, and legacy-preserving | Amended | Sol High |
| B03-D16 | Each bounded context has one repository/service owner and one calculation path | Accepted | Sol High |
| B03-D17 | Unknown, approximate, offline, correction, and error states are first-class | Accepted | Terra High + Sol High |
| B03-D18 | A reviewed, versioned food-identity manifest is mandatory for seeded data and regional variants | Accepted | Sol High |
| B03-D19 | AI/photo privacy is minimized; new offline fallback is manual/unknown unless a reviewed heuristic exists | Amended | Sol High |

## Reviewed decisions

### B03-D01 — Portable identity

- **Status:** Amended.
- **Final rule:** `nutrition_foods.id` identifies only a canonical food/ingredient or explicitly distinct branded, prepared, imported, or user-created food. A preparation/state has its own stable identity under that food. Recipe, recipe-version, thali, estimate, correction, and consumption records have separate portable IDs. `kind` must not collapse recipes into foods. Seed IDs are explicit manifest IDs; user/imported IDs are UUIDs; provider IDs are provenance fields with a unique provider-namespace/external-ID scope, never local primary keys.
- **Rationale:** Current `FoodItems.id` is device-local, seeded rows are not exported in Backup v7, and names are rewritten by seeding. The proposal’s identity graph incorrectly allowed a recipe to be a food.
- **Invariants:** Display names, brands, language labels, aliases, region, preparation, and portion labels are never foreign keys. Materially different regional/preparation/restaurant/homemade/branded entries remain distinct. Deprecated IDs remain resolvable for history. A user-created food is never merged into a catalogue row.
- **Failure behavior:** A missing or conflicting identity remains unresolved with its original text and source metadata. Restore never attaches a legacy/local ID to a destination food merely because the integer or name matches.
- **Required tests:** Manifest IDs survive seed reorder and cosmetic rename; duplicate names resolve as ambiguous; custom/imported UUID/provider provenance survives backup; deprecated historical IDs remain readable; no fuzzy migration; legacy mappings cannot target two foods.
- **Affected tasks:** B03-01, B03-03, B03-06A, B03-06B, B03-11A, B03-14, B03-16.

### B03-D02 — Alias resolution

- **Status:** Accepted.
- **Final rule:** Normalize only case and Unicode whitespace. Exact normalized canonical names and approved aliases may resolve to one candidate within the manifest scope. An alias is a spelling/language/display synonym, not a preparation, ingredient, brand, or portion equivalence. A user alias is scoped to that user and is never used for migration or allergy evidence.
- **Rationale:** B01 and B02 require exact/approved alias behavior and explicitly reject fuzzy, substring, punctuation-stripping, and technique-stripping mapping.
- **Invariants:** Zero candidates are unresolved; multiple candidates are ambiguous; alias collisions are rejected by manifest validation; ambiguous names are never auto-selected.
- **Failure behavior:** Search may show candidates, but logging/migration requires explicit selection. Invalid alias manifests fail before seed or restore mutation.
- **Required tests:** Case/whitespace normalization; exact alias; alias collision; ambiguous regional name; unresolved name; punctuation/substring/fuzzy negative cases; user alias isolation.
- **Affected tasks:** B03-01, B03-03, B03-06B, B03-11B, B03-12, B03-16.

### B03-D03 — Legacy preservation

- **Status:** Amended.
- **Final rule:** The v16 `FoodItems`, `FoodLogs`, `MealTemplates`, `MealTemplateItems`, profile rows, preferences, timestamps, meal categories, meal groups, copied calories/macros, and custom/imported fields remain readable and exportable. A v16→v17 migration creates no canonical food mapping or consumption snapshot by display text, does not infer raw/cooked state or allergens, and does not convert a template into a recipe automatically. Legacy `FoodLogs` remain a separate legacy authority; missing legacy fibre is `missing`, never zeroed by the new read model.
- **Rationale:** Existing logs have copied four-nutrient values but lack source revisions, typed units, or preparation evidence. Existing templates lack food IDs and ingredient graphs. The current fibre helper re-reads mutable catalogue data and treats absent fibre as zero.
- **Invariants:** Catalogue refreshes cannot change a legacy log’s stored values. Legacy meal grouping and timestamps remain intact. A new canonical path never calls the legacy in-place update as its history authority. An explicit legacy correction retains an audit/replacement boundary and does not silently delete the original.
- **Failure behavior:** If identity, unit, preparation, nutrient source, or template composition is not provable, the row stays legacy with its original text and copied values. No fabricated snapshot is created.
- **Required tests:** Real v16 fixture with seeded/custom/imported foods, edited logs, AI-shaped rows, grouped meals, templates, preferences, offline markers, and timestamps; migration/restore preserves logical rows; catalogue refresh does not change legacy values; explicit correction lineage is visible.
- **Affected tasks:** B03-01, B03-02, B03-06A, B03-06B, B03-11B, B03-12, B03-17.

### B03-D04 — Canonical quantities and dimensional safety

- **Status:** Amended.
- **Final rule:** The calculation contract has three canonical dimensions: mass (`g`), volume (`ml`), and count (`count`). `serving`, household measures, piece/roti labels, and manufacturer servings are typed input contexts that resolve to one canonical dimension only through a food/preparation/source-specific definition. `edible_fraction` is a bounded transformation factor, not a fourth physical dimension. Every input preserves value, dimension/unit, food/preparation context, source, approximation state, and optional bounds. Values are finite and non-negative; negative values always fail; zero is allowed for internal arithmetic/optional components but user log and recipe ingredient quantities must be positive.
- **Rationale:** The roadmap requires canonical grams, millilitres, or count. The current `HouseholdMeasure` treats ml, piece, serving, katori, and unknown units as global gram equivalents.
- **Invariants:** Mass and volume do not convert without density or reviewed portion evidence. Count does not convert without food-specific evidence. Serving is never a universal numeric shortcut. Calculations retain internal precision and round only at display/export boundaries. Unknown conversion is visible and does not become zero.
- **Failure behavior:** Invalid or unlike-dimensional conversion returns a typed validation/unavailable result. A user may log a partial/unknown result only with explicit disclosure; the system never silently invents a quantity.
- **MVP cases:** Half a roti is count `0.5` and remains count-only unless a reviewed roti-specific mass/nutrient basis exists. One banana is count and may use a reviewed edible-mass range; no average is invented. One glass of milk can use a volume fact without density; a mass-only fact requires reviewed density. One katori of cooked rice requires food/preparation-specific volume-to-mass evidence or remains unavailable. A recipe serving uses the immutable version’s yield/serving definition. A manufacturer serving preserves the label basis and source. A food without density cannot use a mass-only fact from a volume input. An unknown conversion is displayed as unavailable/partial.
- **Required tests:** Finite/non-negative/zero rules; mass-volume/count rejection; count and liquid behavior; half roti, banana, glass of milk, katori rice, raw/cooked quantity, recipe serving, manufacturer serving, missing density, unknown conversion, precision and display rounding.
- **Affected tasks:** B03-01, B03-04, B03-05, B03-07, B03-08, B03-09, B03-10, B03-11A, B03-13.

### B03-D05 — Conversion ownership and bounds

- **Status:** Accepted.
- **Final rule:** `NutritionConversionRepository` owns reviewed catalogue conversions and user-scoped overrides; `NutritionQuantityService` owns pure arithmetic and validation. Every conversion records source/target dimensions and units, food/preparation context, method, factor or range, source/evidence, confidence, rule version, review state, and owner scope. A user override is additive, approximate, and distinguishable from reviewed data; it never overwrites the reviewed factor.
- **Rationale:** Density, portion, count, and yield are food-specific. A global fallback would create false precision and silently change nutrition.
- **Invariants:** No universal gram/ml/serving multiplier; no hidden unknown-unit serving; no reverse conversion unless a separate rule exists; bounds satisfy finite `0 ≤ lower ≤ point ≤ upper` when all are present.
- **Failure behavior:** Missing/unsupported conversion returns unavailable or a range-only result. A range-only result is not collapsed to a point. Invalid bounds or source versions fail validation before persistence/restore.
- **Required tests:** Reviewed/user precedence; source scope; range-only propagation; unsupported reverse direction; override retention; bad bounds/dimensions; backup round trip.
- **Affected tasks:** B03-01, B03-04, B03-05, B03-06A, B03-06B, B03-09, B03-10, B03-11A.

### B03-D06 — Recipe versions and MVP graph

- **Status:** Amended.
- **Final rule:** B03 supports recipes composed of direct canonical foods/preparations only. A draft is mutable; publishing creates an immutable version containing ordered ingredients, typed quantities, preparation context, yield, serving definition, source/provenance, user notes, and calculation-rule version. Editing, duplicating, substituting, or changing yield/serving count creates a new draft/version. Published/archived versions and versions referenced by snapshots are never hard-deleted. Nested recipe ingredients are rejected/deferred in B03; no nested graph or cycle algorithm ships in this batch.
- **Rationale:** Immutable versions are binding from B01-style history rules, while nested recipes materially increase cycle prevention, restore ordering, and calculation complexity without being required for the foundation MVP.
- **Invariants:** A saved recipe’s current version is an authoring pointer, not historical authority. Partial servings scale the selected version from unrounded ingredient results. Ingredient order and substitution provenance are retained. Imported recipe source is preserved.
- **Failure behavior:** Published mutation, orphan deletion, invalid serving/yield, nested-reference input, or cyclic payload fails without mutation. A deleted saved recipe is archived when ancestry exists; historical snapshots remain readable.
- **Required tests:** Draft/publish/edit/duplicate/archive/delete guard; ordered ingredients; partial servings; substitution lineage; yield/serving changes; imported provenance; nested-reference rejection; history after recipe edit.
- **Affected tasks:** B03-07, B03-08, B03-11A, B03-12, B03-17.

### B03-D07 — Historical snapshot authority

- **Status:** Amended.
- **Final rule:** New food, recipe, thali, and estimate logs use a hybrid contract: the snapshot retains ancestry references (food/preparation, recipe version, thali, estimate/correction) plus a complete immutable resolved input/result snapshot. Snapshot headers retain `logged_at_utc`, local civil date, IANA timezone, meal category/group, source, snapshot schema version, calculator version, and lineage. Snapshot items retain original display/source text, input quantity/context, resolved quantity if available, conversion ID/version/status/bounds, and stable references. Per-item nutrient rows retain nutrient ID, canonical unit, point/lower/upper, status, source type/ref, fact/version, basis, confidence, and assumptions. Meal/day totals are derived from these rows and are not a competing stored authority.
- **Rationale:** A recipe-version or fact reference alone can become unreadable after source retirement or catalogue edits. A result-only row cannot reproduce source provenance. The hybrid freezes both ancestry and what was actually used.
- **Invariants:** Current catalogue, recipe, conversion, estimate, constraint, or model changes never rewrite old snapshots. User edits create a deliberate replacement/correction lineage; the original remains queryable. Historical local date/timezone and meal grouping remain intact. Unsupported source/model metadata is not executed during history reads.
- **Failure behavior:** Snapshot creation is one transaction; a missing required source/value produces an incomplete/unknown result or an explicit error, never a fabricated zero. Deleting a recipe/food/calibration cannot orphan or erase history.
- **Required tests:** Catalogue/recipe/conversion edit stability; exact field/provenance replay; correction/supersession; cross-midnight/local-date behavior; partial/unknown nutrient result; duplicate retry; delete/archive history retention; backup round trip.
- **Affected tasks:** B03-06A, B03-06B, B03-07, B03-08, B03-09, B03-10, B03-11A, B03-11B, B03-12, B03-13, B03-14, B03-15, B03-16.

### B03-D08 — Raw/cooked transformations

- **Status:** Amended.
- **Final rule:** A transformation is directional and keyed by source food/preparation, target food/preparation, preparation method, direction, yield/water/edible-loss representation where supported, factor or lower/upper range, evidence/source, confidence, rule/data version, validity/review state, and owner scope. B03 uses only reviewed food/method-specific transformations or explicitly user-entered approximate overrides. Reverse conversion is a separate reviewed rule or unavailable. Target-state nutrient facts remain authoritative; a yield factor alone does not invent nutrient retention, oil uptake, or dry-matter behavior.
- **Rationale:** There is no current raw/cooked data; names such as “Raw” and “Cooked” cannot support migration. Water gain/loss and frying change density and sometimes composition.
- **Invariants:** No universal rice/dal/meat/vegetable/pasta factor; no name stripping; ranges remain ranges; existing logs are not retroactively transformed; user overrides retain provenance and assumptions.
- **Failure behavior:** Unsupported state/method/direction is unavailable and disclosed. A range-only transformation produces bounded output without an exact-looking point. Missing target facts leave nutrient completeness visible.
- **Required tests:** Rice, pulses, pasta/noodles, meat, vegetables, oil/frying, edible loss, water gain/loss, reviewed point+range, range-only, user override, unsupported reverse, unknown transformation, rule-version snapshot.
- **Affected tasks:** B03-01, B03-04, B03-05, B03-06A, B03-09, B03-11A, B03-17.

### B03-D09 — Household measures and vessel calibration

- **Status:** Amended.
- **Final rule:** Household measures are typed labels and display metadata. Generic katori, bowl, glass, ladle, cup, tablespoon, teaspoon, handful, piece, roti/chapati, plate, and thali values are never universal grams. A generic measure may expose a reviewed volume range; food-specific mass conversion remains a separate conversion record. B03 personal calibration is **vessel-to-volume only**: `nutrition_personal_vessels` owns a portable user-scoped vessel identity, while `nutrition_vessel_calibrations` owns immutable versioned volume records and same-vessel supersession ancestry. Food-specific mass calibration is deferred; it cannot be smuggled into a vessel row.
- **Rationale:** One vessel does not have one mass for water, rice, dal, or vegetables. Volume-only calibration is the least misleading portable MVP and avoids a second food-specific calibration authority.
- **Invariants:** Portable vessel IDs, not display names, are authoritative; duplicate names and renames are valid. Personal calibration overrides only generic volume in the user scope. Archive preserves the vessel and calibration ancestry; hard deletion is blocked once a calibration exists. At most one terminal/current calibration exists per vessel. Deletion/archive never rewrites snapshots. Approximate values are labelled approximate; unknown conversion is visible. Existing global `HouseholdMeasure` equivalents remain compatibility behavior, not B03 truth.
- **Failure behavior:** A measure without a compatible conversion remains unavailable/partial. Outlier or invalid calibration is rejected. Restore never invents a food-mass conversion from a vessel label.
- **Required tests:** Generic katori/glass/roti/plate semantics; volume-only calibration; milk/rice density cases; user precedence; edit/delete/history; approximate display; backup/restore and offline use.
- **Affected tasks:** B03-01, B03-04, B03-06A, B03-06B, B03-10, B03-11A, B03-13.

### B03-D10 — Nutrient facts, units, and missingness

- **Status:** Amended.
- **Final rule:** Use a normalized typed-row model: a stable nutrient registry plus versioned fact rows and per-snapshot nutrient rows. This is the authority; an optional macro/read projection may optimize reads but cannot be written independently. Facts record nutrient ID, canonical unit, basis quantity/unit (per-100-unit, per-serving, or explicit basis), point/lower/upper, status, source type/ref, confidence, fact version, and completeness. The initial registry covers energy, protein, carbohydrate, fat, fibre, sodium, added sugar, saturated fat, cholesterol, potassium, calcium, iron, vitamin B12, vitamin D, magnesium, zinc, folate, and leucine where evidence exists.
- **Rationale:** Wide columns make every nutrient addition a migration and encourage missing-to-zero behavior. Typed rows are maintainable, indexable by food/nutrient, backupable, and extensible even though they are larger than four macro columns.
- **Invariants:** `known`, `known_zero`, `missing`, `not_applicable`, and `estimated` are distinct. Missing is never numeric zero. Known components may aggregate while `completeness=partial/unknown` remains visible. Unit/basis mismatch fails. Rounding happens after aggregation. Bounds aggregate only when the contributing bound contract is valid. Manufacturer, provider, bundled, user, recipe, AI, heuristic, import, and legacy sources remain distinguishable.
- **Failure behavior:** Missing/invalid facts produce an incomplete result or validation error, not a guessed value. A partial daily total is labelled partial and never presented as complete coverage. `not_applicable` is not treated as a consumed zero.
- **Required tests:** Registry uniqueness/units; per-100 and per-serving scaling; known zero versus missing/not-applicable; mixed source aggregation; lower/upper propagation; rounding boundary; user/manufacturer/provider provenance; daily/history completeness; backup round trip.
- **Affected tasks:** B03-01, B03-04, B03-05, B03-06A, B03-06B, B03-08, B03-11A, B03-14, B03-15, B03-16.

### B03-D11 — Estimate uncertainty and correction

- **Status:** Amended.
- **Final rule:** Store an estimate header for source/provider/model/rule, creation time, input hash or privacy-safe request reference, assumptions, typed confidence, status, and correction/supersession lineage. Store point/lower/upper/status/unit/source per nutrient in child rows. A meal-level estimate is not a verified food identity. A point with no defensible bounds remains `estimated`/`approximate`; missing bounds do not create fake ranges. A user correction creates a new source record and snapshot lineage; it never overwrites the original.
- **Rationale:** The current backend returns untyped point macros and `is_fallback`; the screen persists only edited points and labels a match “Verified Dish.” That cannot support reproducibility or honest uncertainty.
- **Invariants:** Confidence is a typed enum, not uncontrolled text. Estimates, catalogue values, manufacturer labels, heuristics, imports, and user corrections remain distinct. An unsupported model is never rerun during restore. Images and full prompts are not stored by default.
- **Failure behavior:** Malformed/partial responses fail closed to manual/unknown; network failure never blocks an offline manual log. A supported-schema backup with unknown provider/model metadata is restored as opaque historical provenance and marked unsupported, but is never executed; structurally invalid payloads fail before mutation.
- **Required tests:** Strict JSON; absent/malformed bounds; per-nutrient status; confidence enum; provider/model/rule metadata; correction lineage; photo/text error; offline manual/unknown; temp-image deletion; privacy-safe backup; unsupported model no-execution/invalid-payload rollback.
- **Affected tasks:** B03-01, B03-05, B03-06B, B03-11A, B03-14, B03-17.

### B03-D12 — Shared thali engine

- **Status:** Amended.
- **Final rule:** B03 thalis use free-form ordered components with optional category labels; fixed named slots are not required. A component references a canonical food/preparation or immutable direct-food recipe version plus a typed quantity. Saving a thali mutates only reusable composition. Logging resolves it through the same quantity, nutrient, constraint, and snapshot services and freezes the selected components. Duplicate components remain separate positions; partial quantities and not-entered components are explicit; no thali-specific nutrient formulas exist.
- **Rationale:** Free-form composition is least restrictive without creating a second recipe system. A visual plate layout cannot be the data model or accessibility path.
- **Invariants:** Saved-thali edits cannot change old snapshots. Unknown nutrients and conflict states propagate. Offline create/save/log work with local data. Accessibility does not depend on plate geometry.
- **Failure behavior:** Invalid/unknown components remain visible and cannot be silently dropped or treated as zero. Constraint evaluation uses the shared engine and cautious result states.
- **Required tests:** Add/reorder/remove/duplicate/partial; save versus log; shared-calculator equivalence; unknown/range propagation; constraint states; deletion/history; backup; offline/accessibility semantics.
- **Affected tasks:** B03-06A, B03-06B, B03-08, B03-10, B03-11A, B03-13, B03-17.

### B03-D13 — Protein distribution and leucine

- **Status:** Amended.
- **Final rule:** Protein distribution is a descriptive read model over immutable snapshots. Prefer explicit `meal_group_id`; when absent, each logged snapshot is its own meal event with its stored meal category and local date/time. Do not infer a meal group from an arbitrary time window. Leucine is displayed only when measured/curated source data exists; missing remains unknown. A conservative, versioned heuristic may be added only with a reviewed source/rule fixture; no detailed threshold, pass/fail score, protein-quality claim, MPS outcome, or adaptive coaching ships in B03.
- **Rationale:** The app has no reliable meal-boundary or leucine source contract. Descriptive distribution satisfies the charter without turning a heuristic into a physiological guarantee.
- **Invariants:** Cross-midnight records use frozen local date/timezone; historical totals remain stable; measured and estimated sources are distinct; unknown is not zero; B04 coaching is not implemented.
- **Failure behavior:** Missing group/leucine data produces a descriptive partial/unknown result. If reviewed heuristic evidence is absent, the heuristic path is unavailable rather than invented.
- **Required tests:** Grouped and ungrouped snapshots; cross-midnight; category changes; measured/estimated/unknown leucine; no-threshold behavior; range/completeness; non-medical copy; no duplicate totals.
- **Affected tasks:** B03-01, B03-05, B03-11A, B03-14, B03-15, B03-17.

### B03-D14 — Restriction taxonomy and safety boundary

- **Status:** Amended.
- **Final rule:** Allergy, intolerance, religious restriction, ethical preference, dietary pattern, taste dislike, temporary avoidance, and regional preference are separate stable types. User constraints retain strictness, severity where applicable, cross-contact relevance, effective dates, source, notes, and user ownership. Food/ingredient evidence is typed, versioned, source-backed, and evaluated through exactly `confirmed_conflict`, `possible_conflict`, `no_known_conflict`, or `insufficient_information`. User aliases are identity-only; unrestricted user-created conflict rules are not allowed in B03. A user override may allow logging or record a personal decision, but it cannot downgrade evidence or claim safety.
- **Rationale:** Current storage is one free-form diet string and meal-plan text has no ingredient evidence. Allergy and observance semantics cannot be inferred from names.
- **Invariants:** “No known conflict” never means safe. Unknown composition is insufficient information for safety-sensitive constraints; known possible evidence is possible conflict. Cross-contact is reported only with evidence. Regional preference is not an allergen rule. User-declared composition remains visibly user-declared and cannot exceed the evidence contract.
- **Failure behavior:** Missing/ambiguous ingredient evidence returns insufficient or possible as defined by the rule, never no-conflict by default. Invalid evidence/constraint relationships fail validation before restore.
- **Required tests:** All eight types; severity/strictness/effective dates; confirmed/possible/no-known/insufficient truth table; unknown ingredients; cross-contact; dish-name negative cases; user override/provenance; backup/history; deterministic explanation.
- **Affected tasks:** B03-01, B03-03, B03-05, B03-06A, B03-06B, B03-11A, B03-13, B03-16, B03-17.

### B03-D15 — Schema v17 and Backup v8

- **Status:** Amended.
- **Final rule:** Use schema v17 and Backup v8 only after the contract fixtures and real v16/v7 harness pass. The v16→v17 migration is transactional, creates tables in parent-before-child order, preserves all legacy tables/columns/rows, creates no speculative food/recipe/snapshot backfill, and validates the checked-in manifest before any seed update. Backup v8 is transactional and prevalidated; v5/v6/v7 remain importable with B03 sections absent. New B03 IDs are portable; legacy local food IDs are not treated as portable identity. A restore with invalid relationships, unsupported future envelope, unavailable required manifest, invalid bounds/dimensions, or structurally invalid B03 payload performs zero mutation.
- **Rationale:** B01/B02 require transactional migrations, prevalidated FK graphs, rollback, old-backup import, and no name inference. Current v7 exports only custom foods and uses local-ID remapping.
- **Invariants:** Parent/child order and FK safety are explicit. Active drafts, unsynced/queued legacy food mutations, preferences, timestamps, meal groups, custom foods, templates, old AI-shaped logs, and unknown legacy values survive. Seeded catalogue is resolved by manifest/version, not local ID. Derived daily totals and images are excluded.
- **Failure behavior:** Any migration/restore failure rolls back database state; preference compensation remains intact. Unsupported model metadata is not executed. Legacy references that cannot be proven become null/unresolved while copied historical fields remain.
- **Required tests:** Real on-disk v16 upgrade, fresh v17 creation, direct accepted migration chain, table/FK/index order, failure injection/rollback, v5/v6/v7 import, v8 round trip, manifest mismatch, local-ID collision, invalid bounds/enums/orphans, active draft and unsynced-log preservation, unsupported future version zero mutation.
- **Affected tasks:** B03-01, B03-02, B03-06A, B03-06B, B03-17, B03-18.

### B03-D16 — Repository and provider ownership

- **Status:** Accepted.
- **Final rule:** `NutritionCatalogueRepository` owns food identity, aliases, preparations, source provenance, and nutrient facts. `NutritionIdentityResolver` is the sole resolver. `NutritionQuantityService` and `NutritionConversionRepository` own dimensions and conversions. `NutritionRecipeRepository` owns recipe lifecycle; `NutritionCalculationService` is the sole calculation path; `NutritionConsumptionRepository` owns new snapshots; `NutritionEstimateRepository` owns estimates/corrections; `NutritionThaliRepository` owns composition; `NutritionConstraintRepository` plus a pure evaluator owns constraints; `NutritionReadModelRepository` reads canonical snapshots and legacy adapters only. The existing `FoodRepository` remains a bounded legacy adapter until each replacement path is proven.
- **Rationale:** The roadmap and B01/B02 prohibit widgets, controllers, and broad repositories from becoming competing authorities.
- **Invariants:** No widget/ screen writes Drift. No screen-local nutrient math, global unit helper, second recipe calculator, second conflict evaluator, or text-based resolver. Cross-domain transactions live in a coordinator; repository dependencies are acyclic.
- **Failure behavior:** Dependency-construction/ownership violations fail review and tests. Legacy and canonical paths are not silently mixed.
- **Required tests:** Provider construction; no widget database imports; delegation tests; one-calculator equivalence; one-resolver ambiguity; repository dependency graph; legacy adapter isolation.
- **Affected tasks:** B03-01, B03-03, B03-04, B03-08, B03-11B, B03-12, B03-13, B03-16, B03-17.

### B03-D17 — Truthful states and accessibility

- **Status:** Accepted.
- **Final rule:** Every nutrition journey exposes loading, empty, invalid, unavailable, approximate, estimated, partial, offline, corrected, archived, and error states as applicable. Units, source, assumptions, bounds, and completeness are available to screen readers and are not conveyed by color alone. Users may log unknown/partial data with explicit confirmation.
- **Rationale:** The roadmap requires uncertainty, user control, offline operation, accessibility, and non-medical posture.
- **Invariants:** No approximate value is formatted as an exact measurement. No “verified dish” or “safe” label is inferred from model confidence/name absence. Unknown is not zero.
- **Failure behavior:** Error/retry/manual paths preserve user-entered data and do not create a partial hidden write.
- **Required tests:** Semantic labels with unit/status; 200% text/compact layout; non-color-only unknown/error states; offline restart; cancel/retry; range/partial display.
- **Affected tasks:** B03-01, B03-10, B03-13, B03-14, B03-16, B03-17, B03-18.

### B03-D18 — Reviewed food-identity manifest and regional variants

- **Status:** Accepted.
- **Final rule:** B03 requires a checked-in, reviewed, versioned manifest for bundled and regional food identities before seeded schema/backup work. The manifest owner is the nutrition catalogue/data owner, with Sol owning identity integrity review and Terra reviewing launch labels. Each entry has an explicit stable ID, kind, canonical display name, locale/region, preparation/variant keys, source/provenance, lifecycle, and explicit aliases. Alias entries are one-to-one in scope; ambiguous names are listed explicitly; deprecated entries retain IDs and point to replacements only when a reviewed equivalence exists. Version increments are monotonic and restore validates the manifest version. IDs are never generated from mutable names or insertion order.
- **Rationale:** The current 573-row asset and five regional packs have names, labels, and macros but no stable IDs, aliases, or structured preparation metadata. The exercise manifest is a useful precedent but is not a food manifest.
- **Invariants:** Asset rows must map exactly to a manifest entry; duplicate display names may coexist as variants; aliases cannot merge material preparation/composition differences; migration never fuzzy-matches regional rows.
- **Failure behavior:** Missing manifest entry, duplicate ID, alias collision, invalid variant relationship, or unsupported manifest version blocks seed/restore before mutation. Unresolved/ambiguous entries remain visible.
- **Required tests:** Manifest parse/version; asset coverage; stable IDs across reorder/rename; approved alias/ambiguous/unresolved fixtures; regional overlap; raw/cooked/restaurant/homemade variant distinction; deprecated-ID restore; golden backup identity tests.
- **Affected tasks:** B03-01, B03-03, B03-06A, B03-06B, B03-17, B03-18.

### B03-D19 — AI/photo privacy and offline boundary

- **Status:** Amended.
- **Final rule:** New photo/text estimate flows disclose cloud transmission accurately, minimize prompts and metadata, store only a privacy-safe input hash/request reference and typed result provenance, and delete temporary image files after success, cancellation, or error on a best-effort basis. Images are not persisted in the database or backup. The offline fallback is manual/unknown; existing fixed mock values are not B03 nutrition truth. A reviewed heuristic may be added only with explicit source, rule version, bounds/status, and tests.
- **Rationale:** The current photo copy says processing is local while bytes are uploaded; the backend accepts point-only untyped JSON and the screen does not retain correction/provenance or define image deletion.
- **Invariants:** No full prompt/image in logs or backups unless a future explicit privacy decision permits it. Allergy/religious notes remain user-owned. Provider/model metadata is retained only as needed for reproducibility. No medical or allergen guarantee is implied.
- **Failure behavior:** Privacy refusal and network failure leave the user on a local manual/unknown path. Malformed provider output fails closed. Temporary-file deletion failure is surfaced/logged without logging image contents.
- **Required tests:** Disclosure path; strict/offline refusal; manual fallback; image cleanup; no image in backup; redacted logs; provider/model/rule provenance; malformed output; provider failure; correction lineage.
- **Affected tasks:** B03-01, B03-06B, B03-14, B03-17, B03-18.

## Automatically accepted product defaults

The product owner’s authorization applies because each default preserves data,
user control, offline behavior, explicit unknownness, and the B03 boundary.

### B03-PD01 — Seed and regional catalogue scope

- **Status:** Accepted.
- **Final rule:** Keep the current bundled catalogue and all five regional packs as distinct source entries until reviewed; treat unverified nutrient rows as source-labelled estimates/curated data, not verified facts. No launch-critical subset is required to begin the foundation.
- **Rejected/deferred alternatives:** Merging by similar name or deleting regional overlaps was rejected because it can reinterpret history.
- **Invariants/tests/tasks:** Manifest coverage, variant distinction, source/completeness labels, and no fuzzy migration are covered by B03-01/B03-03.

### B03-PD02 — Portion vocabulary

- **Status:** Accepted.
- **Final rule:** Expose grams, millilitres, count, serving, katori, bowl, cup, glass, ladle, tablespoon, teaspoon, handful, piece, roti/chapati, plate, and thali as typed vocabulary where the data supports them. Unsupported labels remain visible but unavailable/approximate.
- **Rejected/deferred alternatives:** Reusing the current global gram equivalents was rejected.
- **Invariants/tests/tasks:** B03-D04/D09; B03-01/B03-04/B03-10/B03-13.

### B03-PD03 — Meal templates

- **Status:** Accepted.
- **Final rule:** Existing meal templates remain reusable legacy macro snapshots. New recipes are separate versioned objects. No automatic template-to-recipe conversion occurs; an explicit user action may create a recipe only from selected, proven ingredients.
- **Rejected/deferred alternatives:** Silent conversion was rejected because template rows have no identity/ingredient evidence.
- **Invariants/tests/tasks:** B03-D03/D06/D07; B03-02/B03-07/B03-11B/B03-12.

### B03-PD04 — Corrections, archive, and deletion

- **Status:** Accepted.
- **Final rule:** Corrections append provenance and supersede the prior fact/estimate; referenced foods, recipes, conversions, calibrations, constraints, and snapshots archive rather than hard-delete. Only unreferenced drafts/user objects may be hard-deleted. Historical snapshots remain readable.
- **Rejected/deferred alternatives:** In-place rewrite and cascade deletion were rejected.
- **Invariants/tests/tasks:** B03-D03/D07/D11; B03-06B/B03-11A/B03-14/B03-17.

### B03-PD05 — Meal boundaries

- **Status:** Accepted.
- **Final rule:** Use explicit `meal_group_id` when present. Otherwise treat each new snapshot as one meal event; preserve its meal category/local date/time and do not infer groups from a time window. Cross-midnight behavior follows the frozen local date/timezone.
- **Rejected/deferred alternatives:** Hidden time-window grouping was rejected because it would reinterpret history.
- **Invariants/tests/tasks:** B03-D07/D13; B03-11A/B03-15.

### B03-PD06 — Thali shape

- **Status:** Accepted.
- **Final rule:** Use free-form ordered components with optional categories, not fixed named slots. Saved composition and logged snapshot remain separate.
- **Rejected/deferred alternatives:** Fixed slots and a second thali calculator were rejected as unnecessarily restrictive/duplicative.
- **Invariants/tests/tasks:** B03-D12; B03-13.

### B03-PD07 — Vessel calibration

- **Status:** Accepted.
- **Final rule:** B03 supports vessel-to-volume calibration only. Food-specific mass overrides are separate, explicit conversions and are not silently derived from the vessel.
- **Rejected/deferred alternatives:** Both vessel-to-volume and vessel-to-food mass calibration was deferred because it creates misleading cross-food authority.
- **Invariants/tests/tasks:** B03-D09; B03-10/B03-11A.

### B03-PD08 — Offline estimates

- **Status:** Accepted.
- **Final rule:** Offline estimate entry offers manual values or unknown/partial logging. The existing fixed roti/chicken/egg mock values are not reused as exact or verified nutrition.
- **Rejected/deferred alternatives:** Automatic fixed point fallback was rejected for false precision.
- **Invariants/tests/tasks:** B03-D11/D19; B03-01/B03-14.

### B03-PD09 — Protein and leucine MVP

- **Status:** Accepted.
- **Final rule:** Implement descriptive meal-level protein distribution. Display measured/curated leucine where available; defer thresholds, quality scores, and heuristics until a reviewed source/rule exists.
- **Rejected/deferred alternatives:** Guaranteed muscle or threshold coaching was rejected/deferred to B04.
- **Invariants/tests/tasks:** B03-D13; B03-15.

### B03-PD10 — Constraint aliases and rules

- **Status:** Accepted.
- **Final rule:** Users may correct/search identity in a scoped auditable way, but B03 does not allow unrestricted user-created allergen/conflict rules. User-entered constraints and recipe composition retain provenance and cautious evaluation.
- **Rejected/deferred alternatives:** Free-form safety rules were rejected because they would be unreviewable and could imply safety.
- **Invariants/tests/tasks:** B03-D14; B03-03/B03-16.

## Accepted regression invariants

- Portable IDs, source/version metadata, and user-owned rows survive backup/restore.
- Display-name changes, translations, aliases, and catalogue refreshes do not alter identity or historical snapshots.
- Unknown and dimension-incompatible quantities never become hidden grams or numeric zero.
- Missing nutrients remain missing; only a sourced `known_zero` contributes zero.
- Recipe, conversion, estimate, constraint, and catalogue edits cannot rewrite a historical snapshot.
- AI/photo estimates retain source, status, confidence, bounds when supplied, and correction lineage.
- Constraint results remain evidence-backed and cautious; `no_known_conflict` is not “safe.”
- Recipes, thalis, and individual food logging use one calculation service and one snapshot authority.
- Existing v16 logs, templates, profile values, grouped meals, and v7-or-earlier backups remain readable according to their original semantics.
- B04 adaptive calorie changes, “what can I eat now?”, medical advice, MPS promises, detailed leucine thresholds, unrestricted safety rules, and nested recipes remain outside this B03 implementation contract.

## Exceptional confirmation

None. No accepted decision deletes or reinterprets existing user data, expands
medical/allergy guarantees, adds a new platform permission, or substantially
expands B03. A future request to add nested recipes, food-specific vessel-mass
calibration, detailed leucine thresholds/heuristics, unrestricted user safety
rules, or retained food images must reopen the relevant gate rather than
silently extending these decisions.

## Explicit B04 deferrals

- Adaptive calorie changes, remaining-target suggestions, “what can I eat now?”, festival/travel/eating-out/fasting coaching, and recommendation feedback.
- Detailed leucine thresholds, protein-quality scores, adaptive protein coaching, and any muscle-protein-synthesis or health-outcome claim.
- Nested recipe composition and cycle-capable recipe graphs.
- Food-specific vessel-to-mass calibration as a persistent calibration authority.
- Unreviewed universal raw/cooked factors, automatic reverse conversion, and unsupported nutrient-retention heuristics.
- Unrestricted user-created allergen/conflict rules and automatic safety classification from names.
- Persistent image storage, provider-side image retention, and full prompt/history retention.
