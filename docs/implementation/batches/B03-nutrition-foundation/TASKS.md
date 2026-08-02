# B03 — Dependency-Ordered Execution Tasks

Status: planning only. These tasks are implementation-ready, but no implementation branch should be created until B02 has merged and the applicable Sol High gates are approved. `SOL-GATE REQUIRED` marks a task whose contract cannot be implemented safely from repository evidence alone.

## Ordering and ownership rules

- Tasks run in dependency order. A task may be prototyped in isolation, but it may not land while an upstream contract is unresolved.
- GPT Luna owns deterministic fixtures, repository/service implementation, migration mechanics, and test automation. Terra High owns product semantics, copy, and user-flow review. Sol High owns safety, identity, historical integrity, uncertainty, migration, and release gates.
- Every implementation task must preserve legacy `FoodItems`, `FoodLogs`, and `MealTemplates` until an approved migration proves compatibility.
- Prohibited throughout B03: fuzzy identity migration, universal unit multipliers, invented nutrient/yield/allergen values, silent zero-filling, mutable historical logs, medical claims, B04 adaptive coaching, and unrelated UI redesign.
- Standard validation, when applicable: `flutter analyze && flutter test && dart format --output=none --set-exit-if-changed lib test`.

## Task matrix

| ID | Goal | Dependencies | Owner / review | Risk | Size |
|---|---|---|---|---|---|
| B03-01 | Contract and fixture matrix | B02 merge, B03 audit | GPT Luna / Sol High; **SOL-GATE REQUIRED** | Critical | M |
| B03-02 | Real v16 migration and backup harness | B03-01 | GPT Luna / Sol High; **SOL-GATE REQUIRED** | Critical | L |
| B03-03 | Canonical identity, aliases, legacy mappings | B03-01 | GPT Luna / Sol High; **SOL-GATE REQUIRED** | High | L |
| B03-04 | Typed quantities and deterministic conversions | B03-01 | GPT Luna / Sol High; **SOL-GATE REQUIRED** | Critical | L |
| B03-05 | Nutrient registry, facts, completeness | B03-01, B03-04 | GPT Luna / Sol High; **SOL-GATE REQUIRED** | Critical | L |
| B03-06 | Schema v17 and backup v8 | B03-02–05 | GPT Luna / Sol High; **SOL-GATE REQUIRED** | Critical | XL |
| B03-07 | Recipe graph and immutable versions | B03-03, B03-05, B03-06 | GPT Luna / Terra High | High | XL |
| B03-08 | Recipe calculation and scaling | B03-04, B03-05, B03-07 | GPT Luna / Sol High | High | L |
| B03-09 | Raw/cooked transformations | B03-04, B03-05, B03-06 | GPT Luna / Sol High; **SOL-GATE REQUIRED** | Critical | L |
| B03-10 | Household measures and vessel calibration | B03-04, B03-06 | GPT Luna + Terra High / Sol High; **SOL-GATE REQUIRED** | High | L |
| B03-11 | Consumption snapshots and legacy adapter | B03-05, B03-06, B03-07, B03-08 | GPT Luna / Sol High; **SOL-GATE REQUIRED** | Critical | XL |
| B03-12 | Saved recipe and food-log integration | B03-07, B03-08, B03-11 | GPT Luna / Terra High | High | L |
| B03-13 | Visual thali composition and builder | B03-08, B03-10, B03-11 | GPT Luna / Terra High + Sol High | High | L |
| B03-14 | Estimate ranges, provenance, correction | B03-05, B03-06, B03-11 | GPT Luna + Terra High / Sol High; **SOL-GATE REQUIRED** | Critical | L |
| B03-15 | Protein distribution and leucine guidance | B03-05, B03-11, B03-14 | GPT Luna / Sol High; **SOL-GATE REQUIRED** | Critical | M |
| B03-16 | Dietary constraint evaluation | B03-03, B03-05, B03-06, B03-11 | GPT Luna + Terra High / Sol High; **SOL-GATE REQUIRED** | Critical | L |
| B03-17 | Integrated regression and remediation | B03-07–16 | GPT Luna / Terra High + Sol High | High | L |
| B03-18 | Final Sol High verification | B03-17 | Sol High / GPT Luna evidence | Critical | M |

## Task specifications

### B03-01 — Contract and fixture matrix — SOL-GATE REQUIRED

- Goal: turn the audit’s observed behavior into executable B03 invariants before schema work.
- Dependencies: B02 merged; audit and charter accepted.
- Implementation model: GPT Luna creates deterministic fixtures for stable IDs, duplicate names, aliases, units, raw/cooked variants, missing nutrients, AI ranges, dietary evidence, old logs/templates, backups, and regional foods. Fixtures record expected semantics, not invented catalogue values.
- Exact scope: fixture data, contract tests, expected migration outcomes, and a traceability map from each B03 capability to a test.
- Prohibited changes: no production schema, no fuzzy matching, no nutrient/yield/allergen invention, no UI behavior changes.
- Acceptance criteria: every Sol-gated question has a fixture or an explicit unresolved marker; tests distinguish missing from zero and text from identity; all fixtures are portable and deterministic.
- Tests: `flutter test test/b03_contract_fixture_test.dart`.
- Validation command: standard validation command plus the fixture command.
- Definition of done: Sol High accepts the fixture semantics and unresolved cases are linked to decision IDs.

### B03-02 — Real v16 migration and backup harness — SOL-GATE REQUIRED

- Goal: establish a reversible harness before changing schema or backup versions.
- Dependencies: B03-01.
- Implementation model: GPT Luna checks in an on-disk schema v16 database fixture, a v7 backup fixture, seeded/custom/imported food rows, logs, templates, preferences, and invalid-reference cases. The harness runs migration and restore in transactions.
- Exact scope: fixture creation, migration runner tests, backup envelope validation tests, rollback assertions, and compatibility tests for v5/v6/v7 imports.
- Prohibited changes: no opportunistic cleanup of legacy rows, no destructive migration, no new B03 tables beyond a test harness.
- Acceptance criteria: failed migration/restore leaves the original database byte-for-byte equivalent at the logical row level; supported old backups import without B03 sections; future unsupported versions fail before mutation.
- Tests: `flutter test test/b03_schema_v17_migration_test.dart test/b03_backup_v8_test.dart test/backup_schema_test.dart test/backup_restore_transaction_test.dart`.
- Validation command: standard validation command plus the listed migration tests.
- Definition of done: Sol High signs off the harness and its fixtures are used by B03-06.

### B03-03 — Canonical identity, aliases, and legacy mappings — SOL-GATE REQUIRED

- Goal: remove display text from new identity relationships while preserving legacy text.
- Dependencies: B03-01.
- Implementation model: GPT Luna adds catalogue identity, alias resolution, explicit preparation identity, source/provider identifiers, and auditable legacy mappings. Exact normalized alias resolution returns resolved, unresolved, or ambiguous; it never guesses.
- Exact scope: repository APIs, stable seed manifest adapter, alias normalization, mapping status/evidence, duplicate-name handling, and tests for custom/barcode/import provenance.
- Prohibited changes: no mass merge of existing foods, no fuzzy/substring matching, no rewriting old `FoodLogs`, no name-based foreign keys.
- Acceptance criteria: IDs survive export/import; identical display names can coexist; legacy mappings require evidence; unresolved/ambiguous input is visible to callers.
- Tests: `flutter test test/b03_identity_test.dart test/food_repository_test.dart test/food_api_service_test.dart`.
- Validation command: standard validation command plus identity tests.
- Definition of done: Sol High approves the identity and mapping contract and no new production path groups by display name.

### B03-04 — Typed quantities and deterministic conversions — SOL-GATE REQUIRED

- Goal: make quantity arithmetic dimension-safe and explicit.
- Dependencies: B03-01.
- Implementation model: GPT Luna introduces typed quantity values, finite/nonnegative validation, unit dimensions, food/preparation-specific conversion lookup, bounds, approximation metadata, and display-only rounding.
- Exact scope: mass, volume, count, serving, household measure, edible fraction, custom serving input, liquid handling, density lookup interfaces, and zero/negative behavior.
- Prohibited changes: no `ml = g`, no universal serving or household fallback, no silent count-to-mass conversion, no rounded persistence.
- Acceptance criteria: unlike dimensions reject or return unavailable; unknown conversion is explicit; calculations are deterministic and retain precision; user-entered approximate values remain marked approximate.
- Tests: `flutter test test/b03_quantity_test.dart test/household_measure_test.dart`.
- Validation command: standard validation command plus quantity tests.
- Definition of done: Sol High approves dimensional semantics and all existing `HouseholdMeasure` fallback behavior is isolated behind compatibility code.

### B03-05 — Nutrient registry, facts, and completeness — SOL-GATE REQUIRED

- Goal: replace untyped macro-only assumptions with versioned nutrient facts.
- Dependencies: B03-01, B03-04.
- Implementation model: GPT Luna adds nutrient definitions, typed facts, statuses, source/version/confidence, bounds, and aggregation metadata. Known zero is distinct from missing and not applicable.
- Exact scope: initial nutrient keys in the plan, food facts, estimated facts, macro/micro unit validation, partial totals, and historical fact-version capture.
- Prohibited changes: no invented nutrient values, no missing-to-zero coalesce, no claim that a partial total is complete.
- Acceptance criteria: a missing micronutrient remains missing through item, meal, daily, and history views; aggregation reports completeness and bounds; historical snapshots retain the fact/version.
- Tests: `flutter test test/b03_nutrient_test.dart test/nutrition_calculation_test.dart`.
- Validation command: standard validation command plus nutrient tests.
- Definition of done: Sol High approves status semantics and the registry is versioned for backup.

### B03-06 — Schema v17 and backup v8 — SOL-GATE REQUIRED

- Goal: implement the approved B03 persistence boundary without breaking v16/v7 users.
- Dependencies: B03-02, B03-03, B03-04, B03-05.
- Implementation model: GPT Luna adds the tables and indexes in `PLAN.md`, increments schema/backup versions only after contract approval, and implements transactional migration/restore ordering.
- Exact scope: all proposed tables, nullability and constraints, foreign keys, indices, envelope sections, old-backup compatibility, invalid-reference rollback, and stable-ID round trips.
- Prohibited changes: no dropping legacy tables, no automatic reinterpretation of old log quantities, no export of derived totals as facts, no implementation before Sol decisions D01–D05/D10–D15.
- Acceptance criteria: real v16 fixtures migrate; v7 and older backups restore; v8 round-trips B03 user data; invalid backups mutate nothing; new data has portable IDs.
- Tests: `flutter test test/b03_schema_v17_migration_test.dart test/b03_backup_v8_test.dart test/backup_restore_transaction_test.dart`.
- Validation command: standard validation command plus Android/iOS build smoke checks after schema integration.
- Definition of done: Sol High approves schema v17/backup v8 and evidence is attached to `VERIFICATION.md`.

### B03-07 — Recipe graph and immutable versions

- Goal: support saved reusable recipes without mutable-history drift.
- Dependencies: B03-03, B03-05, B03-06.
- Implementation model: GPT Luna implements recipe identity, draft/published lifecycle, immutable versions, ordered ingredients, nested version references, yield, and serving definitions. Terra High reviews terms and user-facing lifecycle.
- Exact scope: repositories, version creation/copy/edit, ingredient provenance, nested recipe validation, archive behavior, and template adapter boundaries.
- Prohibited changes: no mutation of a published version, no recipe totals stored as independent authority, no automatic conversion of every legacy meal template.
- Acceptance criteria: editing a published recipe creates a new version; nested references remain stable; old snapshots resolve the old version; templates remain readable.
- Tests: `flutter test test/b03_recipe_version_test.dart test/meal_template_compatibility_test.dart`.
- Validation command: standard validation command plus recipe tests.
- Definition of done: Terra High approves wording/flows and Sol High accepts historical semantics.

### B03-08 — Recipe calculation and scaling

- Goal: calculate recipe and nested-recipe nutrients from typed ingredients through one engine.
- Dependencies: B03-04, B03-05, B03-07.
- Implementation model: GPT Luna uses ingredient quantities, preparation context, yield, serving definition, nutrient statuses, and bounds to produce a calculation result with calculator version.
- Exact scope: ingredient scaling, output yield, servings, nested recipes, partial data, substitutions with provenance, and rounding boundaries.
- Prohibited changes: no scaling of rounded totals, no zero-filling, no second controller-specific calculator.
- Acceptance criteria: the same inputs produce the same result offline; changing a draft does not alter a published version; bounds propagate; substitution is visible.
- Tests: `flutter test test/b03_recipe_calculation_test.dart test/b03_scaling_test.dart`.
- Validation command: standard validation command plus calculation tests.
- Definition of done: Sol High verifies formulas/units and Terra High verifies the serving experience.

### B03-09 — Raw/cooked transformations — SOL-GATE REQUIRED

- Goal: support explicit raw/cooked preparation without false precision.
- Dependencies: B03-04, B03-05, B03-06.
- Implementation model: GPT Luna implements directional transformation records with source/target preparation, method, factor/range, evidence, and rule version. Unknown transformations stay unavailable.
- Exact scope: raw/cooked selection, reviewed factors, user estimates, water gain/loss, dry-matter loss, reverse-direction handling, and provenance in snapshots.
- Prohibited changes: no invented yield factors; no universal rice/dal/meat/vegetable rule; no stripping `(Raw)` or `(Cooked)` from names as migration.
- Acceptance criteria: factor and range are retained; unsupported reverse conversion is clearly unavailable; history keeps the applied rule version.
- Tests: `flutter test test/b03_raw_cooked_test.dart test/b03_recipe_calculation_test.dart`.
- Validation command: standard validation command plus raw/cooked tests.
- Definition of done: Sol High approves the evidence policy and reviewed fixtures.

### B03-10 — Household measures and vessel calibration — SOL-GATE REQUIRED

- Goal: support Indian household measures and personal vessels without asserting universal mass.
- Dependencies: B03-04, B03-06.
- Implementation model: GPT Luna adds measure vocabulary, food/preparation-specific mappings, user calibration, range/confidence display, and offline persistence. Terra High reviews labels and calibration journey.
- Exact scope: katori, bowl, ladle, glass, cup, spoon, roti/chapati, piece, thali, custom serving sizes, and calibrated volume versus food mass.
- Prohibited changes: no reuse of current global `HouseholdMeasure` defaults as B03 truth; no claim that one vessel has one mass for all foods.
- Acceptance criteria: calibration is user-scoped; approximate values show uncertainty; unknown density does not silently become grams; counts remain count-only without evidence.
- Tests: `flutter test test/b03_household_measure_test.dart test/b03_vessel_calibration_test.dart`.
- Validation command: standard validation command plus measure tests.
- Definition of done: Terra High approves usability and Sol High approves false-precision safeguards.

### B03-11 — Consumption snapshots and legacy adapter — SOL-GATE REQUIRED

- Goal: make historical nutrition stable while preserving old logs.
- Dependencies: B03-05, B03-06, B03-07, B03-08.
- Implementation model: GPT Luna creates immutable snapshot header/item/nutrient rows and read adapters. New logging writes a snapshot in one transaction; old `FoodLogs` remain readable through their copied values.
- Exact scope: food/recipe/thali logging, edit semantics, meal grouping, item/order retention, snapshot nutrient status/bounds, calculator/fact version, and daily/history read models.
- Prohibited changes: no recalculation of old logs from the current food catalogue; no duplicated daily total as source of truth; no destructive backfill.
- Acceptance criteria: catalogue edits do not change old snapshot/history results; a log edit creates a deliberate replacement/version or preserves the old audit trail; repeated writes are idempotent.
- Tests: `flutter test test/b03_consumption_snapshot_test.dart test/food_log_editing_test.dart test/daily_totals_test.dart`.
- Validation command: standard validation command plus snapshot/history tests.
- Definition of done: Sol High verifies historical invariants and existing screens still render old logs.

### B03-12 — Saved recipe and food-log integration

- Goal: expose recipes in existing search, logging, recent-food, meal-template, and edit flows.
- Dependencies: B03-07, B03-08, B03-11.
- Implementation model: GPT Luna adds repository adapters and controller state transitions; Terra High reviews the user journey, copy, and correction behavior.
- Exact scope: search by identity/alias, saved recipe list, log recipe, edit current entry, recent items, and compatibility with existing meal grouping.
- Prohibited changes: no new text-based grouping, no controller-level nutrition math, no automatic deletion of existing templates.
- Acceptance criteria: recipes can be saved/reused offline; logged recipe snapshots remain stable; ambiguous matches require user choice; existing food logging remains functional.
- Tests: `flutter test test/b03_recipe_log_integration_test.dart test/food_log_screen_test.dart test/meal_grouping_test.dart`.
- Validation command: standard validation command plus targeted widget/repository tests.
- Definition of done: Terra High accepts the flow and regression fixtures cover old/new logging.

### B03-13 — Visual thali composition and builder

- Goal: build and log ordered thalis using the shared calculation and constraint engines.
- Dependencies: B03-08, B03-10, B03-11.
- Implementation model: GPT Luna implements an offline composition model and screen state; Terra High reviews regional household vocabulary and accessibility; Sol High reviews warnings.
- Exact scope: add/reorder/remove components, choose food/recipe/measure, save thali, log snapshot, partial/unknown component state, nutrient summary, and constraint result presentation.
- Prohibited changes: no separate thali nutrient formulas, no inferred allergen safety from visual labels, no required network call.
- Acceptance criteria: saved thali and logged thali are distinct; incomplete items are visible; the same composition gives the same result as individual logging; warnings are bounded.
- Tests: `flutter test test/b03_thali_test.dart test/b03_thali_screen_test.dart test/offline_logging_test.dart`.
- Validation command: standard validation command plus thali/widget tests.
- Definition of done: Terra High approves composition UX and Sol High approves uncertainty/warning behavior.

### B03-14 — Estimate ranges, provenance, and correction — SOL-GATE REQUIRED

- Goal: make AI/photo estimates honest, recoverable, and useful offline.
- Dependencies: B03-05, B03-06, B03-11.
- Implementation model: GPT Luna validates backend JSON into estimate headers/per-nutrient rows, retains provider/model/rule/assumptions and ranges, and supports user correction/supersession. Terra High reviews copy and recovery flow.
- Exact scope: text/photo prompt/response adapter, strict JSON parsing, point-versus-range validation, confidence/status mapping, model metadata, retry/manual fallback, image deletion/non-persistence, and correction audit.
- Prohibited changes: no exact-value persistence from a range-only response; no fabricated confidence; no storing image bytes by default; no medical interpretation.
- Acceptance criteria: malformed/partial JSON fails safely; estimates show bounds/source; correction creates provenance; offline use offers manual entry; uploaded image lifecycle is explicit.
- Tests: `flutter test test/b03_estimate_parsing_test.dart test/ai_food_analysis_test.dart test/offline_estimate_fallback_test.dart`.
- Validation command: standard validation command plus estimate tests.
- Definition of done: Sol High approves uncertainty and privacy behavior; Terra High approves user correction copy.

### B03-15 — Protein distribution and leucine guidance — SOL-GATE REQUIRED

- Goal: provide bounded, source-aware protein distribution and leucine information.
- Dependencies: B03-05, B03-11, B03-14.
- Implementation model: GPT Luna builds a read model from snapshot facts and meal boundaries, with measured/estimated/unknown leucine and versioned heuristic metadata. Sol High reviews wording and safety limits.
- Exact scope: meal grouping, daily distribution, leucine display/status/bounds, source classification, missing-data behavior, and non-medical educational copy.
- Prohibited changes: no MPS or outcome guarantee, no hidden serving assumptions, no persisted duplicate totals, no filling unknown leucine with zero.
- Acceptance criteria: historical snapshots drive results; unknown values remain unknown; estimates carry ranges; copy is bounded and non-prescriptive.
- Tests: `flutter test test/b03_protein_distribution_test.dart test/b03_leucine_test.dart`.
- Validation command: standard validation command plus protein tests.
- Definition of done: Sol High signs off the calculation evidence and wording.

### B03-16 — Dietary constraint evaluation — SOL-GATE REQUIRED

- Goal: separate allergy, intolerance, religious, ethical, pattern, dislike, temporary, and regional constraints.
- Dependencies: B03-03, B03-05, B03-06, B03-11.
- Implementation model: GPT Luna implements definitions, user constraints, ingredient-level evidence, effective dates, conflict evaluation, and explainable results. Terra High reviews onboarding/settings and conflict copy; Sol High reviews safety boundaries.
- Exact scope: vegetarian/vegan compatibility, Jain/halal/religious choices, allergies, intolerances, dislikes, exclusions, cross-contact, unknown evidence, and snapshot result persistence.
- Prohibited changes: no collapsing all restrictions into one string; no allergen classification from food names; no “safe” guarantee; no inference from a user’s regional preference.
- Acceptance criteria: each constraint type stores independently; results are one of the four approved states; evidence is inspectable; unknown produces insufficient information.
- Tests: `flutter test test/b03_constraints_test.dart test/dietary_preferences_test.dart`.
- Validation command: standard validation command plus constraint tests.
- Definition of done: Sol High approves safety semantics and Terra High approves the user journey.

### B03-17 — Integrated regression and remediation

- Goal: prove B03 works across catalogue, calculation, logging, history, backup, AI, constraints, and offline screens.
- Dependencies: B03-07 through B03-16.
- Implementation model: GPT Luna runs the complete fixture suite, repairs integration defects, and adds only narrowly scoped regression fixes. Terra High performs scripted UX review; Sol High reviews any changed contract.
- Exact scope: cross-feature flows, seeded/regional assets, custom/barcode/imported provenance, existing food screens, backup/restore, offline/network recovery, migration telemetry/logging, accessibility smoke tests.
- Prohibited changes: no new capability outside B03, no contract relaxation to make tests pass, no deleting failing fixtures.
- Acceptance criteria: all required capability rows are supported or explicitly deferred; legacy behavior is covered; no app-code diff expands into B04.
- Tests: `flutter analyze && flutter test && dart format --output=none --set-exit-if-changed lib test`.
- Validation command: `flutter build apk --release` and `flutter build ios --release --no-codesign` in addition to the standard command.
- Definition of done: Terra High and Sol High review the complete evidence set and all blockers are resolved or recorded.

### B03-18 — Final Sol High verification — SOL-GATE REQUIRED

- Goal: independently verify that B03 is safe to release and migration-ready.
- Dependencies: B03-17.
- Implementation model: Sol High reviews the decision register, schema/backup diffs, fixture evidence, historical invariants, uncertainty behavior, privacy path, and build/test output. GPT Luna supplies reproducible commands and artifacts.
- Exact scope: final gate only; no new feature scope.
- Prohibited changes: no waiver by informal comment, no approval based only on fresh-database tests, no release while unresolved identity, unit, snapshot, estimate, or dietary safety gates remain.
- Acceptance criteria: every `SOL-GATE REQUIRED` decision is accepted or explicitly deferred; migration/restore rollback evidence passes; legacy logs are stable; all required commands pass.
- Tests: rerun the full B03 matrix and standard validation command.
- Validation command: `flutter analyze && flutter test && flutter build apk --release && flutter build ios --release --no-codesign`.
- Definition of done: Sol High signs `VERIFICATION.md` and the B03 definition of done in `PLAN.md` is met.

## Recommended execution sequence

Run B03-01 and B03-02 first, because no schema proposal is safe without real legacy fixtures. Resolve identity and quantity (B03-03/04), then nutrient semantics (B03-05), before the v17/v8 boundary (B03-06). Build recipes and their calculator (B03-07/08), then raw/cooked and measures (B03-09/10), then snapshot authority and existing-flow integration (B03-11/12). Add thali, estimates, protein/leucine, and constraints (B03-13–16). Finish with integrated remediation and independent Sol verification (B03-17/18).

The release blocker is not the number of screens. It is whether every new persisted nutrition result has stable identity, dimension-safe quantity semantics, explicit uncertainty, and an immutable historical boundary.
