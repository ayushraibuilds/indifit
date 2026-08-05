# B03 — Dependency-Ordered Execution Tasks

Status: B03 implementation is merged; the current focused final review is
recorded below. Product-owner manual physical verification is recorded as
passed by attestation. Current disposition is **Passed with non-blocking
follow-up**. The historical r2 blocked register remains below for audit
history; it is superseded by the current integration evidence after the Wave 1
through Wave 3 remediations. `SOL-GATE REQUIRED` remains a routing label, but
no Sol or Terra instance was used for this final focused review.

## Ordering and ownership rules

- The accepted B02 base is required before B03-01. The planning baseline inspected for this gate is `c84aa97b8968dae8e4b112f9b0f3a2ab57266ae6`, descended from B02 final verification commit `330bda5`; the B02 integration merge is still a release prerequisite recorded in the tracker.
- Tasks run in dependency order. Parallelism is allowed only where the listed dependencies are complete and the same contract version is used.
- GPT Luna implements deterministic fixtures, serializers, pure value objects, bounded services after contract approval, migration mechanics, and mechanical CRUD/UI wiring. Terra High reviews user-visible language and flows. Sol High owns identity, history, units, uncertainty, migration/backup, privacy/safety, algorithms, and final verification.
- Every implementation task has an explicit review model. Sol review is mandatory for all tasks marked `SOL-GATE REQUIRED` and for the integration points named in the matrix.
- Existing `FoodItems`, `FoodLogs`, `MealTemplates`, profile/preferences, and current backup compatibility remain readable until a separately evidenced replacement path exists.
- Prohibited throughout B03: fuzzy identity migration, universal unit multipliers, fabricated nutrient/yield/allergen values, silent zero-filling, mutable canonical history, exact-looking AI estimates, medical/allergen guarantees, unrestricted user safety rules, nested recipes, and B04 adaptive coaching.
- Standard validation, when applicable: `flutter analyze && flutter test && dart format --output=none --set-exit-if-changed lib test`.

## Task matrix

| ID | Goal | Dependencies | Implementation / review | Risk | Size |
|---|---|---|---|---|---|
| B03-01 | Contract, fixture, and seed-manifest audit matrix | B02 accepted base, B03 audit | GPT Luna / Sol High **SOL-GATE REQUIRED** | Critical | M |
| B03-02 | Real v16 migration and v7 backup harness | B03-01 | GPT Luna / Sol High **SOL-GATE REQUIRED** | Critical | L |
| B03-03 | Reviewed food identity manifest, aliases, variants, legacy mappings | B03-01 | GPT Luna / Sol High **SOL-GATE REQUIRED** | Critical | L |
| B03-04 | Typed quantities and deterministic conversions | B03-01 | GPT Luna / Sol High **SOL-GATE REQUIRED** | Critical | L |
| B03-05 | Nutrient registry, facts, and completeness | B03-01, B03-04 | GPT Luna / Sol High **SOL-GATE REQUIRED** | Critical | L |
| B03-06A | Schema v17 tables, indexes, and v16→v17 migration | B03-02, B03-03, B03-04, B03-05 | GPT Luna / Sol High **SOL-GATE REQUIRED** | Critical | L |
| B03-06B | Backup v8 graph, codecs, restore, and v5/v6/v7 compatibility | B03-02, B03-05, B03-06A | GPT Luna / Sol High **SOL-GATE REQUIRED** | Critical | L |
| B03-07 | Direct-food recipe graph and immutable versions | B03-03, B03-05, B03-06A/B | GPT Luna / Terra High + Sol High **SOL-GATE REQUIRED** | High | L |
| B03-08 | One recipe calculation service and scaling | B03-04, B03-05, B03-07 | GPT Luna / Sol High + Terra High | Critical | L |
| B03-09 | Raw/cooked transformations and yield semantics | B03-04, B03-05, B03-06A | GPT Luna / Sol High **SOL-GATE REQUIRED** | Critical | L |
| B03-10 | Household measures and volume-only vessel calibration | B03-04, B03-06A/B | GPT Luna + Terra High / Sol High **SOL-GATE REQUIRED** | High | L |
| B03-11A | Immutable consumption snapshots and calculation lineage | B03-07, B03-08, B03-09, B03-10, B03-06A | GPT Luna / Sol High **SOL-GATE REQUIRED** | Critical | L |
| B03-11B | Legacy food-log/template adapter and read models | B03-02, B03-06B, B03-11A | GPT Luna / Sol High **SOL-GATE REQUIRED** | Critical | L |
| B03-12 | Saved recipe and existing food-log integration | B03-07, B03-08, B03-11A/B | GPT Luna / Terra High + Sol High **SOL-GATE REQUIRED** | High | L |
| B03-13 | Free-form thali composition and builder | B03-08, B03-10, B03-11A, B03-16 | GPT Luna / Terra High + Sol High | High | L |
| B03-14 | Estimate ranges, provenance, correction, and privacy path | B03-05, B03-06B, B03-11A | GPT Luna + Terra High / Sol High **SOL-GATE REQUIRED** | Critical | L |
| B03-15 | Descriptive protein distribution and measured leucine display | B03-05, B03-11A, B03-14 | GPT Luna / Sol High **SOL-GATE REQUIRED** | Critical | M |
| B03-16 | Dietary constraint taxonomy and deterministic evaluator | B03-03, B03-05, B03-06A/B, B03-11A | GPT Luna + Terra High / Sol High **SOL-GATE REQUIRED** | Critical | L |
| B03-17 | Integrated regression and narrowly scoped remediation | B03-06A/B, B03-07–B03-16 | GPT Luna / Terra High + Sol High | High | L |
| B03-18 | Final Sol High verification | B03-17 | Sol High / GPT Luna evidence | Critical | M |

## Verified task status and review evidence

Product-owner authorization:

You are explicitly authorized to update only the B03 task status fields and
review-evidence fields in `TASKS.md` so they accurately reflect verified merged
implementation and independent review results.

Do not alter task goals, dependencies, acceptance criteria, architecture,
scope, or model routing.

These current statuses reflect the final focused review in `VERIFICATION.md`.
They do not manufacture a Sol or Terra verdict. Where the requested reviewer
instance was intentionally not used, the limitation is recorded as a
non-blocking follow-up rather than an implementation blocker.

| Task | Status | Review evidence |
|---|---|---|
| B03-01 | Implemented and merged; Focused review complete; Passed | Decision-specific fixture matrix and assertions pass in the current integration tree. |
| B03-02 | Implemented and merged; Focused review complete; Passed | Preference compensation preserves the pre-failure snapshot and retry succeeds. |
| B03-03 | Implemented and merged; Focused review complete; Passed with follow-up | Stable identity/ambiguity checks pass; 592 manual-review catalogue rows remain unresolved by design. |
| B03-04 | Implemented and merged; Focused review complete; Passed | Dimensional conversion and typed-failure tests pass. |
| B03-05 | Implemented and merged; Focused review complete; Passed | Nutrient state, range, provenance, and completeness tests pass. |
| B03-06A | Implemented and merged; Focused review complete; Passed | Schema boundary triggers and negative relationship tests pass. |
| B03-06B | Implemented and merged; Focused review complete; Passed | Known-zero, malformed-state, and reviewed-measure ownership tests pass. |
| B03-07 | Implemented and merged; Focused review complete; Passed with follow-up | Recipe graph/version tests pass; no separate Terra instance was used. |
| B03-08 | Implemented and merged; Focused review complete; Passed with follow-up | Calculation/scaling tests pass; no separate Terra instance was used. |
| B03-09 | Implemented and merged; Focused review complete; Passed | Provenance gating and range-only persistence tests pass. |
| B03-10 | Implemented and merged; Focused review complete; Passed with follow-up | Vessel/calibration tests pass; no separate Terra instance was used. |
| B03-11A | Implemented and merged; Focused review complete; Passed | Required IANA time context, DST, cross-midnight, and restore tests pass. |
| B03-11B | Implemented and merged; Focused review complete; Passed | Append-only correction, effective reads, totals, and ancestry tests pass. |
| B03-12 | Implemented and merged; Focused review complete; Passed with follow-up | Production saved-recipe path supplies canonical time context and stale/retry behavior passes. |
| B03-13 | Implemented and merged; Focused review complete; Passed with follow-up | Production thali path supplies canonical time context and transactional tests pass. |
| B03-14 | Implemented and merged; Focused review complete; Passed with follow-up | Parser, offline, cleanup, privacy, and correction evidence passes. |
| B03-15 | Implemented and merged; Focused review complete; Passed with follow-up | Descriptive protein/leucine boundaries pass; no recommendation logic added. |
| B03-16 | Implemented and merged; Focused review complete; Passed with follow-up | Deterministic dietary safety and uncertainty tests pass. |
| B03-17 | Implemented and merged; Focused review complete; Passed with follow-up | Full integration suite and user-attested physical matrix are recorded. |
| B03-18 | Implemented and merged; Focused review complete; Passed with follow-up | Final focused disposition recorded in the current verification section. |

## Task specifications

### B03-01 — Contract, fixture, and seed-manifest audit matrix — SOL-GATE REQUIRED

- **Goal:** Convert the audit and accepted decisions into executable invariants before production schema work.
- **Dependencies:** B02 accepted base, B03 charter/audit, and this decision register.
- **Implementation model:** GPT Luna creates deterministic fixtures and a read-only audit of the 573-row base asset plus five regional packs. The fixture set must model stable IDs, duplicate/ambiguous names, approved aliases, branded/imported/custom foods, preparation variants, dimensions, missing/known-zero nutrients, bounds, raw/cooked states, estimates, constraints, old logs/templates, preferences, backups, and manifest versioning. It must not invent catalogue facts.
- **Exact scope:** Contract fixtures, expected migration outcomes, manifest coverage/overlap report, and traceability from every high-risk decision to a test. No production schema, feature UI, seed rewrite, fuzzy resolver, or new nutrition value.
- **Acceptance criteria:** Every accepted decision has valid/invalid/unknown fixtures; manifest gaps and unresolved entries are explicit; fixtures distinguish text from identity, missing from zero, approximation from exact, and legacy from canonical; all fixtures are portable and deterministic.
- **Tests:** `test/b03_contract_fixture_test.dart`, `test/b03_food_manifest_fixture_test.dart`.
- **Review:** Sol High accepts semantic fixtures before B03-02/03/04 proceed.
- **Definition of done:** A traceability matrix links B03-D01–D19 and B03-PD01–PD10 to fixture IDs and downstream tasks.

### B03-02 — Real v16 migration and v7 backup harness — SOL-GATE REQUIRED

- **Goal:** Establish a reversible, representative legacy harness before v17/v8 implementation.
- **Dependencies:** B03-01.
- **Implementation model:** GPT Luna checks in an on-disk v16 database fixture and representative v7 backup fixture containing seeded/custom/imported foods, edited and unedited logs, AI-shaped legacy rows, grouped meals, meal templates, profile/preferences, timestamps, unsynced/queued state, and invalid references. The harness reuses B01/B02 transaction and compensation patterns.
- **Exact scope:** Fixture creation, migration runner, backup prevalidation/rollback harness, and v5/v6/v7 compatibility assertions. No B03 production tables or feature behavior.
- **Prohibited changes:** No name-based mapping, raw/cooked inference, allergen inference, nutrient fabrication, legacy cleanup, or destructive restore.
- **Acceptance criteria:** A failed migration/restore leaves the logical database and managed preferences unchanged; supported old backups import with B03 sections absent; unsupported future versions fail before mutation; legacy local food IDs are never used as portable identity.
- **Tests:** `test/b03_schema_v17_migration_test.dart`, `test/b03_backup_v8_test.dart`, `test/backup_schema_test.dart`, `test/backup_restore_transaction_test.dart`.
- **Review:** Sol High signs the harness and fixture semantics; B03-06A/B must use the same real fixtures.
- **Definition of done:** Logical row snapshots, relationship checks, and rollback injection are reproducible on a real on-disk file.

### B03-03 — Reviewed food identity manifest, aliases, variants, and legacy mappings — SOL-GATE REQUIRED

- **Goal:** Establish the single portable identity contract before any seeded nutrition relationship exists.
- **Dependencies:** B03-01.
- **Implementation model:** GPT Luna adds the checked-in, versioned manifest at `assets/data/nutrition_food_identity_manifest.json` and a deterministic resolver in the same pattern as the reviewed exercise manifest. Sol High reviews IDs, aliases, ambiguous entries, provider identity, and migration boundaries; Terra reviews labels only.
- **Exact scope:** Manifest ownership/version, explicit stable IDs, food/preparation/brand/import/custom kinds, source/provider identifiers, exact normalization, one-to-one aliases, ambiguous/unresolved entries, deprecation, regional/preparation variant distinctions, and legacy mapping status/evidence.
- **Prohibited changes:** No identity derived from display names/insertion order, mass merge, fuzzy/substring matching, punctuation/technique stripping, legacy-log rewrite, or user alias used as safety evidence.
- **Acceptance criteria:** Every seed/region row maps to exactly one manifest entry or an explicit unresolved record; IDs survive reorder/rename/export/import; duplicate display names can coexist; provider namespace+external ID is retained; deprecated identities remain resolvable; old local IDs map only with evidence.
- **Tests:** `test/b03_identity_test.dart`, `test/b03_food_manifest_fixture_test.dart`, `test/food_repository_test.dart`, `test/food_api_service_test.dart`.
- **Review:** Sol High approves the manifest and resolver before B03-06A or any canonical food write.
- **Definition of done:** Golden stable-ID, alias, ambiguity, regional-variant, custom/import, deprecation, and no-fuzzy-migration tests pass.

### B03-04 — Typed quantities and deterministic conversions — SOL-GATE REQUIRED

- **Goal:** Make quantity arithmetic dimension-safe and explicit.
- **Dependencies:** B03-01.
- **Implementation model:** GPT Luna introduces pure typed quantity values for mass (`g`), volume (`ml`), and count, plus contextual serving/household input, bounded edible fraction, finite/non-negative validation, conversion lookup, provenance, and display-only rounding. The old `HouseholdMeasure` remains compatibility-only.
- **Exact scope:** Half roti, banana, milk glass, katori rice, recipe/manufacturer serving, count/liquid behavior, missing density, raw/cooked input state, unknown conversion, zero/negative/finite values, precision, and user override metadata.
- **Prohibited changes:** No `ml=g`, global serving/household fallback, silent count-to-mass conversion, hidden 100 g serving, or rounded persistence.
- **Acceptance criteria:** Unlike dimensions reject or return typed unavailable; supported conversions are deterministic; range-only results remain ranges; explicit user approximations retain source/scope; user log/recipe quantities reject negative and invalid zero cases.
- **Tests:** `test/b03_quantity_test.dart`, `test/household_measure_test.dart`, `test/b03_household_measure_test.dart`.
- **Review:** Sol High approves canonical dimensions and conversion semantics.
- **Definition of done:** The quantity contract can reproduce every D04 case offline without global defaults.

### B03-05 — Nutrient registry, facts, and completeness — SOL-GATE REQUIRED

- **Goal:** Replace four untyped macro assumptions with typed, versioned facts and truthful partial totals.
- **Dependencies:** B03-01, B03-04.
- **Implementation model:** GPT Luna adds a stable nutrient registry, normalized fact rows, typed basis/unit, statuses, source/version/confidence, optional bounds, and deterministic aggregation. A read projection may optimize macros but cannot become an authority.
- **Exact scope:** Energy, macros, fibre, sodium, added sugar, saturated fat, cholesterol, potassium, calcium, iron, B12, D, magnesium, zinc, folate, and leucine where evidence exists; per-100/per-serving basis; known zero/missing/not-applicable/estimated; source distinctions; lower/upper aggregation; historical fact-version capture.
- **Prohibited changes:** No invented values, missing-to-zero coalesce, per-ingredient display rounding, unit mismatch coercion, or complete-total label for partial coverage.
- **Acceptance criteria:** Known zero remains zero; missing remains missing through item/meal/daily/history; available subtotal and incomplete coverage coexist; valid bounds propagate; user/manufacturer/provider/seed values retain provenance.
- **Tests:** `test/b03_nutrient_test.dart`, `test/nutrition_calculation_test.dart`, `test/b03_nutrient_completeness_test.dart`.
- **Review:** Sol High approves status, basis, units, and aggregation before repository writes.
- **Definition of done:** The registry/version contract is included in migration and backup fixtures.

### B03-06A — Schema v17 tables, indexes, and v16→v17 migration — SOL-GATE REQUIRED

- **Goal:** Implement only the approved v17 persistence boundary without changing legacy meaning.
- **Dependencies:** B03-02, B03-03, B03-04, B03-05.
- **Implementation model:** GPT Luna adds the approved table graph, indexes, constraints/triggers, and v16→v17 migration. Create parents before children; avoid recipe-pointer FK cycles; validate the manifest before any canonical seed operation.
- **Exact scope:** The 24 proposal tables plus the D15 amendments and the required `nutrition_snapshot_constraint_result_evidence` child relation (26 physical tables after the pre-release vessel-graph remediation): no recipe kind in `nutrition_foods`, sole legacy mapping bridge, direct-food recipe ingredient contract, separate portable `nutrition_personal_vessels` identity, versioned volume-only `nutrition_vessel_calibrations` ancestry, typed constraint evidence relation, complete snapshot columns/rows, and no nested recipe implementation.
- **Prohibited changes:** No dropped legacy tables/columns, speculative legacy snapshot backfill, name-based seed update, current-catalogue fibre repair, raw/cooked inference, or backup implementation in this task.
- **Acceptance criteria:** Fresh v17 and real v16→v17 databases have valid FKs/indexes; pre-release v17 calibration rows convert deterministically into one portable vessel plus its initial calibration; duplicate vessel display names remain valid; failure injection rolls back DDL/data; legacy logical rows and active drafts/unsynced markers survive; no B03 table can be populated with an invalid dimension/status/relationship.
- **Tests:** `test/b03_schema_v17_migration_test.dart`, `test/b03_schema_relationship_test.dart`, `test/db_migration_test.dart`.
- **Review:** Sol High approves schema/FK/order/migration evidence before downstream durable data flows.
- **Definition of done:** The schema diff and real-file migration evidence are attached to `VERIFICATION.md` by the implementation task.

### B03-06B — Backup v8 graph, codecs, restore, and old-version compatibility — SOL-GATE REQUIRED

- **Goal:** Make every new user-owned B03 row portable and transactionally restorable.
- **Dependencies:** B03-02, B03-05, B03-06A.
- **Implementation model:** GPT Luna extends the existing typed backup adapter with v8 sections, prevalidation, parent-first insert/child-first delete, stable-ID handling, and preference compensation. It must not export seeds as user data or temporary images.
- **Exact scope:** User/imported foods, aliases/overrides, preparations, conversions, personal vessels and retained calibration ancestry, nutrient overrides, recipes/versions/ingredients, estimates/corrections, thalis/items, typed constraints/evidence/overrides, snapshot results plus `nutrition_snapshot_constraint_result_evidence` rows, snapshots/items/nutrients/lineage, manifest version, old v5/v6/v7 imports, and unsupported future versions.
- **Prohibited changes:** No legacy local-ID attachment by destination integer/name, derived daily-total export, image/prompt export, invented manifest alias/fact/yield/allergen relationship, or partial mutation on validation failure.
- **Acceptance criteria:** v8 round trips all user-owned B03 rows and provenance, including duplicate vessel names, archive state, calibration versions, current-terminal resolution, and supersession ancestry; v5/v6/v7 imports remain accepted; invalid references/dimensions/bounds/versions fail before mutation; unsupported future versions mutate nothing; unknown model metadata is opaque/no-execution; rollback preserves database and preferences.
- **Tests:** `test/b03_backup_v8_test.dart`, `test/backup_restore_transaction_test.dart`, `test/backup_schema_test.dart`.
- **Review:** Sol High signs restore order, graph validation, privacy, manifest, and logical-row evidence.
- **Definition of done:** Every user-owned table has an export/import fixture and a documented restore order.

### B03-07 — Direct-food recipe graph and immutable versions — SOL-GATE REQUIRED

- **Goal:** Support reusable recipes without mutable-history drift.
- **Dependencies:** B03-03, B03-05, B03-06A, B03-06B.
- **Implementation model:** GPT Luna implements draft/published/archived recipe identity, immutable direct-food versions, ordered ingredients, preparation/yield/serving definitions, source/provenance, copy/substitute flows, and template boundary. Terra reviews terms; Sol reviews history/FK behavior.
- **Exact scope:** Draft edit, publish, duplicate, archive, delete guard, partial serving, ingredient ordering, substitution provenance, imported recipe source, saved current-version pointer, and nested-reference rejection.
- **Prohibited changes:** No mutation of published versions, independent recipe totals, automatic legacy-template conversion, nested recipes, cycle-capable graph, or hard-delete of referenced ancestry.
- **Acceptance criteria:** Published edits create a new version; snapshots retain selected version and resolved context; recipe changes never alter old snapshots; invalid nested/cyclic references fail; saved recipe remains offline and backupable.
- **Tests:** `test/b03_recipe_version_test.dart`, `test/meal_template_compatibility_test.dart`, `test/b03_recipe_graph_integrity_test.dart`.
- **Review:** Terra High reviews lifecycle/copy; Sol High accepts immutable ancestry and deletion behavior.
- **Definition of done:** Direct-food recipe graph is independent of legacy meal-template authority.

### B03-08 — One recipe calculation service and scaling

- **Goal:** Calculate food/recipe totals through one deterministic, unit-safe path.
- **Dependencies:** B03-04, B03-05, B03-07.
- **Implementation model:** GPT Luna implements `NutritionCalculationService` over typed ingredients, preparation/conversion results, yield, serving definition, nutrient statuses/bounds, and calculator version. Controllers, widgets, thalis, and repositories call it rather than calculating.
- **Exact scope:** Ingredient normalization, unrounded scaling, direct-food recipe totals, partial servings, mixed known/missing/estimated inputs, ranges, substitutions, user-entered final correction lineage, and deterministic serialization.
- **Prohibited changes:** No scaling rounded totals, zero-filling, second thali/screen calculator, or adaptive coaching.
- **Acceptance criteria:** Same input/version produces same offline result; known zero and missing behave distinctly; bounds and completeness propagate; user adjustment is separate from definition edits; all consumers use one service.
- **Tests:** `test/b03_recipe_calculation_test.dart`, `test/b03_scaling_test.dart`, `test/nutrition_calculation_test.dart`.
- **Review:** Sol High verifies formulas/units/rounding; Terra High reviews serving presentation.
- **Definition of done:** Calculation service contract is the only durable producer of new nutrient results.

### B03-09 — Raw/cooked transformations and yield semantics — SOL-GATE REQUIRED

- **Goal:** Support explicit preparation state without false precision.
- **Dependencies:** B03-04, B03-05, B03-06A.
- **Implementation model:** GPT Luna implements directional transformation records, reviewed point/range factors, target facts, user-scoped approximate overrides, water/edible/dry-matter fields where evidence supports them, and rule-version provenance.
- **Exact scope:** Rice, pulses, pasta/noodles, meat, vegetables, oil/frying, raw/cooked selection, reviewed and user ranges, unsupported reverse direction, and snapshot assumptions.
- **Prohibited changes:** No universal factor, name stripping, automatic nutrient retention/oil uptake inference, exact reverse conversion, or retroactive legacy transformation.
- **Acceptance criteria:** Reviewed/user source and bounds survive; range-only output is not collapsed; unsupported conversion is visible/unavailable; target nutrient facts remain authoritative; history retains the applied rule.
- **Tests:** `test/b03_raw_cooked_test.dart`, `test/b03_recipe_calculation_test.dart`, `test/b03_transformation_provenance_test.dart`.
- **Review:** Sol High approves evidence policy and reviewed fixtures before user exposure.
- **Definition of done:** A failed/unknown transformation never produces a hidden quantity or nutrient value.

### B03-10 — Household measures and volume-only vessel calibration — SOL-GATE REQUIRED

- **Goal:** Support Indian household vocabulary and personal vessels without universal mass claims.
- **Dependencies:** B03-04, B03-06A, B03-06B.
- **Implementation model:** GPT Luna implements typed measure metadata, food/preparation conversions, volume-only user calibration, ranges/confidence, archive/delete, backup, and offline persistence. Terra reviews labels/accessibility; Sol reviews false-precision safeguards.
- **Exact scope:** Katori, bowl, ladle, glass, cup, tablespoon, teaspoon, handful, piece, roti/chapati, plate, thali, custom serving labels, generic volume ranges, and food mass/density boundaries.
- **Prohibited changes:** No current global `HouseholdMeasure` defaults as B03 truth; no vessel-to-all-food mass; no hidden density; no deletion rewrite.
- **Acceptance criteria:** A vessel stores only calibrated volume in B03; food-specific mass conversion is separate and source-bearing; approximate/unknown states are explicit; snapshot retains effective conversion.
- **Tests:** `test/b03_household_measure_test.dart`, `test/b03_vessel_calibration_test.dart`, `test/b03_quantity_test.dart`.
- **Review:** Sol High approves dimensional behavior; Terra High approves the calibration journey.
- **Definition of done:** All D04/D09 household examples behave offline and accessibly.

### B03-11A — Immutable consumption snapshots and calculation lineage — SOL-GATE REQUIRED

- **Goal:** Make new nutrition history reproducible and immutable.
- **Dependencies:** B03-07, B03-08, B03-09, B03-10, B03-06A.
- **Implementation model:** GPT Luna implements snapshot header/item/nutrient rows and one transaction for food/recipe/thali/estimate logging. It stores full input/result/source/fact/conversion/calculator context, local date/timezone, meal grouping, correction lineage, and idempotency keys.
- **Exact scope:** Food/recipe/thali/estimate logging, partial/unknown results, meal categories/group IDs, cross-midnight records, item ordering/duplicates, snapshot replacement/correction, and derived daily/history read inputs.
- **Prohibited changes:** No current-catalogue recalculation, duplicate meal totals as authority, in-place canonical history edit, or destructive legacy backfill.
- **Acceptance criteria:** Catalogue/recipe/conversion/estimate edits do not change old snapshots; logged version/source facts replay; range/missingness remains; retry is idempotent; deleting a source does not orphan history; user correction preserves original.
- **Tests:** `test/b03_consumption_snapshot_test.dart`, `test/food_log_editing_test.dart`, `test/daily_totals_test.dart`, `test/b03_history_reproducibility_test.dart`.
- **Review:** Sol High verifies historical invariants and snapshot schema before integration.
- **Definition of done:** New history reads only snapshots; legacy reads are delegated to B03-11B.

### B03-11B — Legacy food-log/template adapter and read models — SOL-GATE REQUIRED

- **Goal:** Preserve old food journeys while exposing canonical history without mixed authority.
- **Dependencies:** B03-02, B03-06B, B03-11A.
- **Implementation model:** GPT Luna implements a bounded adapter for existing `FoodRepository` reads/templates/legacy logs, plus completeness-aware read models that can show legacy and canonical records distinctly. Legacy macros remain copied values; legacy missing fibre remains unknown.
- **Exact scope:** Legacy `FoodItems`/`FoodLogs`/`MealTemplates`, recent-food grouping compatibility, meal groups/timestamps, old AI-shaped rows, explicit legacy correction boundary, offline restart, and adapter ownership.
- **Prohibited changes:** No fuzzy grouping, current-fact fibre lookup as history authority, automatic template recipe conversion, destructive legacy rewrite, or duplicate canonical/legacy total.
- **Acceptance criteria:** Old records render unchanged in their legacy semantics; canonical edits do not affect them; explicit user correction is auditable; legacy unresolved names remain unresolved; read models disclose legacy/partial status.
- **Tests:** `test/b03_legacy_adapter_test.dart`, `test/meal_template_compatibility_test.dart`, `test/food_repository_test.dart`, `test/daily_totals_test.dart`.
- **Review:** Sol High accepts the authority split and compatibility behavior.
- **Definition of done:** Existing screens can consume the adapter without direct Drift access or competing math.

### B03-12 — Saved recipe and existing food-log integration — SOL-GATE REQUIRED

- **Goal:** Connect recipes and canonical logging to existing search/recent/template/edit journeys.
- **Dependencies:** B03-07, B03-08, B03-11A, B03-11B.
- **Implementation model:** GPT Luna adds repository/controller adapters and offline state transitions. Terra reviews user flow/copy; Sol reviews historical mutation and source selection.
- **Exact scope:** Identity/alias search, ambiguous selection, saved recipe list, log recipe, selected quantity, correction path, recent items, meal grouping, and legacy template compatibility.
- **Prohibited changes:** No text grouping, controller-level nutrition math, automatic deletion/conversion of templates, or in-place snapshot mutation.
- **Acceptance criteria:** Recipes save/reuse offline; ambiguous matches require selection; logged recipe snapshot remains stable; old food logging and meal grouping remain functional; corrections retain original provenance.
- **Tests:** `test/b03_recipe_log_integration_test.dart`, `test/food_log_screen_test.dart`, `test/meal_grouping_test.dart`, `test/b03_history_reproducibility_test.dart`.
- **Review:** Terra High and Sol High must both sign the integration point.
- **Definition of done:** New and legacy flows have one visible authority each.

### B03-13 — Free-form thali composition and builder

- **Goal:** Compose and log ordered thalis through shared quantity, nutrient, constraint, and snapshot services.
- **Dependencies:** B03-08, B03-10, B03-11A, B03-16.
- **Implementation model:** GPT Luna implements offline composition state and screen wiring; Terra reviews regional vocabulary/accessibility; Sol reviews warning/uncertainty behavior.
- **Exact scope:** Add/reorder/remove/duplicate components, optional category labels, food/recipe references, household measures, partial/not-entered state, save versus log, snapshot, nutrient summary, and four-state constraint presentation.
- **Prohibited changes:** No fixed-slot-only schema, separate thali formulas, visual-name allergen inference, required network, or inaccessible plate-only controls.
- **Acceptance criteria:** Same composition equals individual logging; saved thali edits do not alter history; unknown/ranges/conflicts propagate; duplicates are deterministic; screen-reader labels expose units/status; offline log works.
- **Tests:** `test/b03_thali_test.dart`, `test/b03_thali_screen_test.dart`, `test/offline_logging_test.dart`, `test/b03_constraints_test.dart`.
- **Review:** Terra High reviews journey; Sol High reviews shared engine/constraint integration as part of B03-17.
- **Definition of done:** Thali is a composition consumer, not a second recipe/calculation system.

### B03-14 — Estimate ranges, provenance, correction, and privacy path — SOL-GATE REQUIRED

- **Goal:** Make AI/photo estimates honest, recoverable, privacy-minimized, and offline-capable.
- **Dependencies:** B03-05, B03-06B, B03-11A.
- **Implementation model:** GPT Luna validates backend JSON into typed estimate headers/per-nutrient rows and snapshot lineage; Terra reviews copy/recovery; Sol reviews uncertainty/privacy. The new path must disclose cloud transmission accurately.
- **Exact scope:** Strict text/photo response parsing, typed confidence/status, point-versus-range rules, provider/model/rule metadata, assumptions/input hash, correction/supersession, manual/unknown fallback, temporary image deletion, redacted logging, and no image backup.
- **Prohibited changes:** No “verified dish” from a name/match flag, exact persistence from range-only output, fabricated confidence/bounds, full prompt/image storage, or medical interpretation. Existing fixed mock values are not B03 truth.
- **Acceptance criteria:** Malformed/partial JSON fails closed; no network offers manual/unknown logging; correction preserves original; unknown model metadata is opaque/no-execution; image lifecycle is explicit; sensitive data is not unnecessarily logged/exported.
- **Tests:** `test/b03_estimate_parsing_test.dart`, `test/ai_food_analysis_test.dart`, `test/offline_estimate_fallback_test.dart`, `test/b03_estimate_privacy_test.dart`.
- **Review:** Sol High must approve uncertainty/privacy before the flow is exposed.
- **Definition of done:** Estimate values and uncertainty remain distinguishable through backup and history.

### B03-15 — Descriptive protein distribution and measured leucine display — SOL-GATE REQUIRED

- **Goal:** Provide source-aware descriptive protein distribution without adaptive or medical coaching.
- **Dependencies:** B03-05, B03-11A, B03-14.
- **Implementation model:** GPT Luna derives a read model from snapshot protein rows and explicit meal boundaries. Measured/curated leucine is displayed with source; no threshold or heuristic is added without a reviewed fixture.
- **Exact scope:** Grouped/ungrouped meal events, daily distribution, cross-midnight local date, measured/estimated/unknown leucine, bounds/completeness, source classification, and bounded educational copy.
- **Prohibited changes:** No MPS/outcome guarantee, hidden time-window grouping, threshold pass/fail, adaptive target, persisted duplicate totals, or unknown-to-zero.
- **Acceptance criteria:** History drives results; missing values remain unknown; measured and estimated data are distinct; no detailed heuristic/threshold path is enabled without a new Sol-reviewed rule.
- **Tests:** `test/b03_protein_distribution_test.dart`, `test/b03_leucine_test.dart`, `test/b03_history_reproducibility_test.dart`.
- **Review:** Sol High signs off calculation boundary and wording.
- **Definition of done:** B04 can consume a documented read model without B03 making a coaching decision.

### B03-16 — Dietary constraint taxonomy and deterministic evaluator — SOL-GATE REQUIRED

- **Goal:** Separate dietary concepts and expose explainable, cautious conflict states.
- **Dependencies:** B03-03, B03-05, B03-06A, B03-06B, B03-11A.
- **Implementation model:** GPT Luna implements typed definitions, user constraints, reviewed food/ingredient evidence, effective dates, cross-contact fields, deterministic evaluation, provenance, and snapshot result lineage. Terra reviews settings/copy; Sol reviews safety boundary.
- **Exact scope:** Vegetarian/vegan pattern, Jain/halal/religious choices, allergies, intolerances, ethical preferences, dislikes, temporary avoidance, regional preference, unknown composition, user override, and evidence relation backup.
- **Prohibited changes:** No collapsed string, dish-name classification, cross-contact inference without evidence, unrestricted user rules, or “safe” guarantee.
- **Acceptance criteria:** Each type stores independently; results are exactly confirmed/possible/no-known/insufficient; unknown safety-sensitive composition is insufficient/possible as defined; evidence is inspectable; user override cannot downgrade the evaluator.
- **Tests:** `test/b03_constraints_test.dart`, `test/dietary_preferences_test.dart`, `test/b03_constraint_backup_test.dart`, `test/b03_thali_test.dart`.
- **Review:** Sol High approves taxonomy/evidence; Terra High approves user journey.
- **Definition of done:** Thali and future food screens call this evaluator rather than implement local filters.

### B03-17 — Integrated regression and narrowly scoped remediation

- **Goal:** Prove cross-domain history, backup, uncertainty, safety, offline, and accessibility behavior.
- **Dependencies:** B03-06A, B03-06B, B03-07 through B03-16, including B03-11A/B.
- **Implementation model:** GPT Luna runs the complete matrix and makes only narrow integration fixes. Terra performs scripted UX review; Sol reviews every changed contract and the complete evidence set.
- **Exact scope:** Seeded/regional/custom/barcode/imported provenance, legacy screens/templates, recipes, quantities, transformations, snapshots, thali, estimates/privacy, protein read model, constraints, migration/restore, offline/restart, accessibility, and platform smoke tests.
- **Prohibited changes:** No contract relaxation to make tests pass, fixture deletion, new B04 capability, or unrelated UI redesign.
- **Acceptance criteria:** Every capability is supported or explicitly deferred; no legacy log is reinterpreted; no duplicate authority remains; all integration review points are recorded.
- **Tests:** `flutter analyze && flutter test && dart format --output=none --set-exit-if-changed lib test`; B03 matrix; generated-code/idempotence; migration/backup rollback; Android release and unsigned iOS release smoke checks.
- **Review:** Terra High and Sol High review the complete evidence set; critical failure blocks B03-18.
- **Definition of done:** No unresolved identity, quantity, snapshot, uncertainty, privacy, constraint, migration, or backup risk remains.

### B03-18 — Final Sol High verification — SOL-GATE REQUIRED

- **Goal:** Independently verify that B03 is safe to release and migration-ready.
- **Dependencies:** B03-17.
- **Implementation model:** Sol High reviews this register, schema/backup diffs, manifest, real fixtures, historical invariants, uncertainty/privacy path, ownership map, platform/accessibility evidence, and build/test output. GPT Luna supplies reproducible commands and artifacts.
- **Exact scope:** Final gate only; no new feature scope.
- **Prohibited changes:** No informal waiver, fresh-database-only approval, or release with unresolved identity, unit, snapshot, estimate/privacy, constraint, migration, or backup gates.
- **Acceptance criteria:** Every `SOL-GATE REQUIRED` item is accepted or explicitly deferred; migration/restore rollback passes; legacy logs/templates remain stable; all required checks pass; B04 deferrals are recorded.
- **Tests:** Full B03 matrix plus `flutter analyze && flutter test && flutter build apk --release && flutter build ios --release --no-codesign`.
- **Review:** Sol High signs `VERIFICATION.md` with evidence and residual-risk disposition.
- **Definition of done:** B03 definition of done is met without adding B04 behavior.

## Safe-start classification

### Safe to start immediately

- **B03-01:** Contract/fixture/manifest audit matrix, after the accepted B02 base is available. It has no unresolved product or architecture dependency after the gate.

### Safe after prerequisite tasks

- **B03-02:** after B03-01.
- **B03-03:** after B03-01.
- **B03-04:** after B03-01.
- **B03-05:** after B03-01 and B03-04.
- **B03-06A:** after B03-02, B03-03, B03-04, and B03-05.
- **B03-06B:** after B03-02, B03-05, and B03-06A.
- **B03-07:** after B03-03, B03-05, B03-06A, and B03-06B.
- **B03-08:** after B03-04, B03-05, and B03-07.
- **B03-09:** after B03-04, B03-05, and B03-06A.
- **B03-10:** after B03-04, B03-06A, and B03-06B.
- **B03-11A:** after B03-06A, B03-07, B03-08, B03-09, and B03-10.
- **B03-11B:** after B03-02, B03-06B, and B03-11A.
- **B03-12:** after B03-07, B03-08, B03-11A, and B03-11B.
- **B03-14:** after B03-05, B03-06B, and B03-11A.
- **B03-15:** after B03-05, B03-11A, and B03-14.
- **B03-16:** after B03-03, B03-05, B03-06A, B03-06B, and B03-11A.
- **B03-13:** after B03-08, B03-10, B03-11A, and B03-16.
- **B03-17:** after B03-06A/B and B03-07 through B03-16.
- **B03-18:** after B03-17.

### Blocked by exceptional product decision

None. The product owner’s authorization covers the ordinary defaults recorded
in `DECISIONS.md`. Any future expansion into nested recipes, detailed leucine
thresholds/heuristics, food-specific vessel-mass calibration, unrestricted
user safety rules, or persistent images requires a new explicit gate.

## Exact dependency-ordered sequence

The only permitted implementation sequence is:

`B03-01 → (B03-02 ∥ B03-03 ∥ B03-04) → B03-05 → B03-06A → B03-06B → B03-07 → B03-08 → (B03-09 ∥ B03-10) → B03-11A → B03-11B → B03-12 → B03-14 → B03-15 → B03-16 → B03-13 → B03-17 → B03-18`

The parallel groups still require their own Sol review. B03-09 and B03-10
must finish before B03-11A; B03-16 must finish before B03-13 so thali
warnings use the shared evaluator.
