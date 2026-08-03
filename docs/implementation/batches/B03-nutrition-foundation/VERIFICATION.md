# B03 Verification — Nutrition Foundation and Food Context

## Gate metadata

- **Gate date:** 2026-08-02
- **Planning commit inspected:** `c84aa97b8968dae8e4b112f9b0f3a2ab57266ae6` (`docs(b03): add nutrition architecture and task plan`)
- **B03 planning parent:** `4ec5c5c` (`docs(b03): audit nutrition architecture`)
- **B02 evidence baseline:** final verification commit `330bda5`; B02 verification is passed, while the implementation tracker still requires the B02 integration merge into the accepted base before B03 implementation branches.
- **Current schema/backup baseline:** v16 / v7
- **Scope:** Architecture and implementation-readiness gate only. Application code, schema, food assets, tests, branches, and task branches were not modified.

## Gate verdict

**Passed with automatically accepted defaults.**

B03 is safe to begin with the contract, fixture, manifest-audit, and legacy
harness tasks after the accepted B02 base is available. No B03 feature UI,
schema migration, backup format, or production nutrition path may begin until
the dependency-ordered Sol reviews in `TASKS.md` pass.

There is no exceptional product decision requiring confirmation. The product
owner authorization was applied only to ordinary choices that preserve
history, user control, offline behavior, explicit unknownness, and the B03
boundary. Nested recipes, detailed leucine thresholds/heuristics,
food-specific vessel-mass calibration, unrestricted safety rules, and
persistent images are explicit deferrals.

## Evidence inspected

### Binding planning and prior-batch documents

- `docs/roadmap/canonical-roadmap.md`
- `docs/implementation/MASTER_TRACKER.md`
- `docs/implementation/batches/B01-training-programs/DECISIONS.md`
- `docs/implementation/batches/B01-training-programs/VERIFICATION.md`
- `docs/implementation/batches/B02-workout-execution/DECISIONS.md`
- `docs/implementation/batches/B02-workout-execution/VERIFICATION.md`
- `docs/implementation/batches/B03-nutrition-foundation/CHARTER.md`
- `docs/implementation/batches/B03-nutrition-foundation/AUDIT.md`
- `docs/implementation/batches/B03-nutrition-foundation/PLAN.md`
- `docs/implementation/batches/B03-nutrition-foundation/TASKS.md`
- `docs/implementation/batches/B03-nutrition-foundation/DECISIONS.md`

### Relevant implementation, assets, backup, migration, and tests

- `lib/data/database/tables/food_tables.dart`: current auto-increment `FoodItems`, copied-value `FoodLogs`, and name-only `MealTemplateItems`.
- `lib/data/database/app_database.dart`: v16 schema, name-based seeded-food upsert, existing v14→v15/v15→v16 transaction patterns, and current indexes/triggers.
- `lib/data/repositories/food_repository.dart`: current logging/editing, fibre re-read, recent-food `GROUP BY name`, template replay, and destructive regional-pack replacement.
- `lib/core/utils/household_measures.dart`: global gram equivalents, unlike-dimension conversion, and unknown-unit serving fallback.
- `lib/core/utils/natural_meal_parser.dart`: text-only quantity parsing without identity/density resolution.
- `lib/data/repositories/food_api_service.dart`: Open Food Facts point values with missing fields coerced to zero and provider identity retained only in memory.
- `lib/core/backup/backup_schema.dart`: Backup v7 collections, current custom-food/local-ID remapping, prevalidation, FK restore order, transaction, and preference compensation.
- `lib/features/food_log/ai_meal_logger_screen.dart`: current point-only save/correction path and cloud-AI privacy/disclosure flow.
- `backend/main.py`: untyped meal-estimate JSON, model/provider omission, hard-coded prompt/mock heuristics, and photo upload path.
- `lib/core/di/user_profile_provider.dart`, onboarding/profile code, and `user_tables.dart`: legacy diet string mirrored between SharedPreferences and Drift.
- `lib/features/food_log/food_search_screen.dart`, `thali_builder_screen.dart`, and `custom_food_editor_screen.dart`: screen-local multiplier/logging and permissive custom-food quantity entry.
- `assets/data/indian_foods.json` and the five regional packs: flat names/macros/servings without stable food IDs, aliases, source revisions, or structured preparation metadata.
- `lib/core/fixtures/exercise_identity_fixtures.dart`: accepted precedent for a checked-in versioned stable-ID/alias/ambiguous manifest; no equivalent food manifest exists.
- `test/fixtures/v14_db_fixtures.dart`, `test/fixtures/v15_db_fixtures.dart`, `test/b01_schema_v15_migration_test.dart`, `test/b02_schema_v16_migration_test.dart`, `test/b02_backup_v7_test.dart`, and `test/backup_restore_transaction_test.dart`: real-file migration, typed graph, and rollback patterns.
- Existing nutrition tests were inventoried; no B03 contract, nutrition, recipe, raw/cooked, estimate, leucine, vessel, or constraint test suite exists yet. The named B03 tests in `TASKS.md` are required future evidence, not existing proof.

## Verified current risks and gate disposition

| Finding from the read-only audit | Evidence | Gate disposition |
|---|---|---|
| Seeded food identity is name/local-ID based; no food manifest exists | `food_tables.dart`; `app_database.dart`; `assets/data/*`; exercise-manifest precedent | Amended by D01/D02/D18. B03-01/03 precede schema and seeded writes. |
| Backup v7 exports custom foods but not seeded catalogue identity; restore remaps local IDs | `backup_schema.dart:151-156, 3276-3335` | Amended by D03/D15. New snapshots use portable IDs; legacy local references never attach by destination integer/name. |
| Legacy logs copy macros but lack source/fact/version/typed completeness; fibre can be re-read as zero | `food_tables.dart:21-37`; `food_repository.dart:178-218` | Amended by D03/D07/D10. Legacy rows stay legacy; new snapshots freeze full source/result context. |
| Current household conversion treats ml, piece, serving, katori, and unknown units as gram equivalents | `household_measures.dart:1-116` | Amended by D04/D09. Canonical dimensions are mass/volume/count; vessel calibration is volume-only. |
| Current parser/API do not resolve identity or density and provider nutrient absence becomes zero | `natural_meal_parser.dart`; `food_api_service.dart` | Amended by D01/D04/D05/D10. Missing conversion/value remains visible. |
| Recipes do not exist; templates are named macro bundles | `food_tables.dart:39-57`; `food_repository.dart:263-384` | Amended by D03/D06. Direct-food immutable recipe versions only; templates remain legacy. |
| No raw/cooked state/yield contract exists | `AUDIT.md`; current assets and tables | Amended by D08. Reviewed food/method rules only; unknown is unavailable. |
| AI/photo output is point-only, untyped, unversioned, and not durably linked to correction provenance | `backend/main.py:245-320, 523-558`; AI logger | Amended by D11/D19. New flow is strict, per-nutrient, source-bearing, privacy-minimized, manual/unknown offline. |
| Current photo copy claims local processing while the image is uploaded | roadmap Phase 0; AI logger/backend | Amended by D19 and B03-14 scope. No new flow may reuse the inaccurate disclosure. |
| Dietary storage is a three-value preference string with no ingredient evidence | profile provider, `user_tables.dart`, meal-plan service/assets | Amended by D14. Typed constraints/evidence only; no safety guarantee. |
| Screens/thali/meal-plan paths calculate outside a central nutrition service | food search, thali builder, meal-plan service, progress repository | Amended by D12/D16 and B03-08/B03-13. One calculation service is required. |
| Proposed snapshot schema did not freeze enough source/fact context and used duplicate/unchecked relationship fields | B03 `PLAN.md` schema table | Amended by D07/D10/D15. Snapshot rows are the historical authority; typed evidence relations and validation are required. |
| Nested recipes and vessel-to-food mass calibration materially expand graph/restore complexity | B03 `PLAN.md`/`TASKS.md` | Deferred by D06/D09 and product defaults; not a B03 MVP blocker once downstream scope is bounded. |

## Gate inventory result

### Explicit `SOL-GATE REQUIRED` items

The exact task list after amendment is: B03-01, B03-02, B03-03, B03-04,
B03-05, B03-06A, B03-06B, B03-07, B03-09, B03-10, B03-11A, B03-11B,
B03-12, B03-14, B03-15, B03-16, and B03-18. B03-08, B03-13, and B03-17
have mandatory Sol integration review even though their primary implementation
is bounded by already accepted contracts.

The original plan’s explicit gates (raw/cooked, protein/leucine,
constraints) are retained. The previously unmarked high-risk items are now
covered: immutable recipe versions and calculation, thali shared authority,
legacy adapter/history, identity manifest, and saved-recipe integration.

### Proposed schema and backup boundary

The inspected proposal is schema v17 / Backup v8 with the 24 proposal tables
enumerated in `DECISIONS.md`. The gate amends that proposal with the validated
25th relation `nutrition_snapshot_constraint_result_evidence`, which replaces
serialized `evidence_ids` references and links each snapshot result to typed
food/ingredient evidence. The accepted schema boundary additionally requires:

- no recipe kind in `nutrition_foods`;
- a sole auditable legacy mapping bridge;
- direct-food recipe ingredients only in B03;
- volume-only vessel calibration;
- typed/validated constraint evidence relationships;
- complete snapshot item/nutrient source, basis, fact, conversion, calculation, local-date/timezone, and lineage fields;
- the checked-in manifest artifact `assets/data/nutrition_food_identity_manifest.json` with stable IDs, aliases, variants, and version validation;
- parent-before-child creation and no recipe-pointer FK cycle.

Backup v8 must include every user-owned row in the new graph, preserve old
v5/v6/v7 import behavior, validate manifest/source/bounds/relationships before
mutation, retain transaction and preference compensation, and exclude derived
daily totals and temporary images.

### Algorithms and heuristics reviewed

1. Exact normalized identity and one-to-one alias resolution.
2. Typed quantity validation and food/preparation-specific conversion.
3. Directional raw/cooked/yield transformation with point/range/unknown output.
4. Nutrient scaling, completeness, source status, and bound aggregation.
5. Recipe version and direct-food calculation lifecycle.
6. Estimate parsing, confidence/status, correction/supersession, and offline fallback.
7. Descriptive protein distribution with explicit meal events and measured leucine only.
8. Deterministic four-state dietary conflict evaluation with evidence.
9. Thali composition through the shared calculation/constraint/snapshot services.
10. Transactional migration and prevalidated backup/restore graph handling.

No universal cooked factor, global unit multiplier, exact-looking AI fallback,
fuzzy identity, hidden time-window meal grouping, or automatic allergen rule is
accepted.

## Accepted and amended decisions

Full decision records, invariants, failure behavior, required tests, and
affected tasks are in `DECISIONS.md`:

- **Accepted/amended:** B03-D01 through B03-D19.
- **Automatically accepted product defaults:** B03-PD01 through B03-PD10.
- **Most consequential amendments:** food/preparation identity is separated from recipes; a checked-in food manifest is mandatory; canonical quantity is mass/volume/count; snapshot authority is a hybrid full source/result freeze; direct-food recipes and free-form thalis are the MVP; vessel calibration is volume-only; leucine thresholds/heuristics are deferred; offline AI is manual/unknown; and v17/v8 restore never maps legacy local IDs by name/integer.

## Blocking findings

There is no exceptional architecture blocker to starting B03-01. The following
are hard downstream gates and must block their listed consumers if they are not
complete:

1. **B02 accepted-base dependency:** B03 implementation remains blocked until the B02 integration merge required by `MASTER_TRACKER.md` is complete. B02’s final Sol verification is passed at `330bda5`; this is a release/dependency condition, not a new B03 design question.
2. **Food identity manifest:** No schema/seed/canonical food write before B03-03 and its Sol sign-off.
3. **Legacy fixture harness:** No migration or Backup v8 implementation before B03-02 real-file evidence.
4. **Quantity/nutrient contracts:** No recipe, raw/cooked, vessel, thali, or snapshot consumer before B03-04/B03-05 are accepted.
5. **Snapshot completeness:** No new history integration before B03-11A proves immutable source/result snapshots.
6. **Constraint evidence:** No constraint/thali warning UI before B03-16 proves the four-state evaluator.
7. **Estimate privacy/uncertainty:** No AI/photo exposure before B03-14 proves strict parsing, disclosure, correction lineage, and image cleanup.

These findings are represented as dependencies and acceptance criteria, not
waived. If a required Sol review fails, the affected task is blocked and the
verdict must be revisited.

## Automatically accepted product defaults

- Current and regional food rows remain distinct until explicit manifest review; no launch subset or merge is required to start.
- The requested Indian portion vocabulary is supported as typed labels, with unavailable/approximate behavior when conversion evidence is absent.
- Existing meal templates remain legacy macro snapshots; recipes are separate.
- Corrections append provenance; referenced objects archive; history is never cascade-deleted.
- Explicit meal groups are honored; absent groups do not receive hidden time-window inference.
- Thali is free-form ordered composition with optional categories, not fixed slots.
- Vessel calibration is volume-only; food mass requires separate evidence.
- Offline estimate fallback is manual/unknown, not the current fixed mock point values.
- Protein distribution is descriptive; measured/curated leucine is display-only and thresholds/heuristics are deferred.
- User identity aliases are allowed only as scoped corrections; unrestricted user-created allergen/conflict rules are not allowed.

### Pre-release dependency-contract remediation

B03-10 was initially blocked because the first merged v17/v8 definitions stored
only a calibration row and could not represent portable vessel identity,
duplicate display names, rename-safe ownership, or retained calibration
supersession. Because schema v17 and Backup v8 have not shipped to users, the
contract is amended in place rather than version-bumped. Schema v17 now owns a
separate `nutrition_personal_vessels` table and versioned, same-vessel
`nutrition_vessel_calibrations` ancestry. Backup v8 exports and restores both
graphs transactionally. Existing pre-release calibration rows are converted
one-for-one using `vessel:<calibration-id>` as their deterministic portable
vessel ID; no labels are merged and food-specific calibration context is
rejected rather than inferred.

### Ordinary product questions resolved by the gate

| Question | Automatically accepted B03 default | Consequence |
|---|---|---|
| Which seed and regional rows are authoritative? | The reviewed manifest and its version are authoritative; current/regional rows stay distinct until reviewed. | No name-based merge or silent seed rewrite. |
| Which portions and labels launch? | The requested Indian vocabulary is typed and shown; unsupported conversions are unavailable/approximate. | No universal grams for katori, glass, roti, piece, or thali. |
| How do meal templates relate to recipes? | Existing templates remain legacy copied-value snapshots; recipes are separate and require explicit user action. | No automatic template-to-recipe conversion. |
| Which regional packs/variants are required? | All five packs are audited for coverage; no pack is silently treated as equivalent or launch-authoritative before manifest review. | Duplicate names may remain distinct by region/preparation/source. |
| What happens on correction, edit, archive, or delete? | Corrections append lineage; published/referenced objects archive; only unreferenced drafts may hard-delete. | Historical snapshots remain readable and unchanged. |
| What protein/leucine guidance is acceptable? | Protein distribution is descriptive; measured/curated leucine may display with source; thresholds and heuristics are deferred. | No pass/fail, MPS, quality, or adaptive coaching claim. |
| How are approximate, unknown, and conflicting values shown? | Preserve status, bounds, source, and assumptions; unknown is not zero; constraints use four cautious states. | Offline/manual/unknown is valid; no exact-looking mock or safety guarantee. |

## Exceptional decisions still requiring explicit confirmation

**None.** Future additions listed in the B04 deferrals section of
`DECISIONS.md` require a new gate and explicit confirmation if they would alter
the accepted data/safety boundary.

## Task disposition and reviewers

| Task | Disposition | Implementation model | Mandatory reviewer/integration point |
|---|---|---|---|
| B03-01 | Safe immediately after B02 accepted base | GPT Luna | Sol: fixture/manifest semantics |
| B03-02 | Safe after B03-01 | GPT Luna | Sol: real-file migration/restore harness |
| B03-03 | Safe after B03-01 | GPT Luna | Sol: food IDs, aliases, variants, provenance |
| B03-04 | Safe after B03-01 | GPT Luna | Sol: dimensions/conversions/rounding |
| B03-05 | Safe after B03-01 + B03-04 | GPT Luna | Sol: nutrient status/basis/bounds |
| B03-06A | Safe after B03-02/03/04/05 | GPT Luna | Sol: schema/FK/order/migration rollback |
| B03-06B | Safe after B03-02/05/06A | GPT Luna | Sol: v8 graph/prevalidation/restore/privacy |
| B03-07 | Safe after B03-03/05/06A/B | GPT Luna | Terra: lifecycle copy; Sol: immutable ancestry |
| B03-08 | Safe after B03-04/05/07 | GPT Luna | Sol: formula/unit review; Terra: serving UX |
| B03-09 | Safe after B03-04/05/06A | GPT Luna | Sol: transformation evidence/ranges |
| B03-10 | Safe after B03-04/06A/B | GPT Luna | Sol: false precision; Terra: labels/calibration |
| B03-11A | Safe after B03-06A/07/08/09/10 | GPT Luna | Sol: snapshot authority/history |
| B03-11B | Safe after B03-02/06B/11A | GPT Luna | Sol: legacy authority split |
| B03-12 | Safe after B03-07/08/11A/B | GPT Luna | Terra + Sol: integration/history |
| B03-14 | Safe after B03-05/06B/11A | GPT Luna | Sol: uncertainty/privacy; Terra: copy |
| B03-15 | Safe after B03-05/11A/14 | GPT Luna | Sol: descriptive/non-medical boundary |
| B03-16 | Safe after B03-03/05/06A/B/11A | GPT Luna | Sol: safety/evidence; Terra: journey |
| B03-13 | Safe after B03-08/10/11A/16 | GPT Luna | Terra + Sol integration: thali/shared engine |
| B03-17 | Safe after B03-06A/B and B03-07–16 | GPT Luna | Terra + Sol: complete evidence/remediation |
| B03-18 | Safe after B03-17 | Sol High | Final independent gate |

## First tasks safe to implement

The first permitted task is B03-01. Once it passes, the next three bounded
tasks may proceed in parallel:

1. **B03-01 — Contract, fixture, and seed-manifest audit matrix** — GPT Luna implementation; Sol High semantic review.
2. **B03-02 — Real v16 migration and v7 backup harness** — GPT Luna implementation after B03-01; Sol High migration/restore review.
3. **B03-03 — Reviewed food identity manifest and resolver** — GPT Luna implementation after B03-01; Sol High identity review.
4. **B03-04 — Typed quantities and conversions** — GPT Luna implementation after B03-01; Sol High dimensional review.

B03-02/03/04 are not safe before B03-01 because their fixtures must share the
same accepted ambiguity, missingness, and source semantics.

## Exact dependency-ordered task sequence

`B03-01 → (B03-02 ∥ B03-03 ∥ B03-04) → B03-05 → B03-06A → B03-06B → B03-07 → B03-08 → (B03-09 ∥ B03-10) → B03-11A → B03-11B → B03-12 → B03-14 → B03-15 → B03-16 → B03-13 → B03-17 → B03-18`

B03-09 and B03-10 may run in parallel after their prerequisites but both must
finish before snapshots. B03-16 must finish before thali UI/warnings. The
sequence is intentionally conservative around history and safety boundaries.

## Required integration-review points

- B03-01: decision-to-fixture traceability and seed/region manifest audit.
- B03-02: real v16/v7 fixture, rollback, old backup import, and no reinterpretation.
- B03-03: stable IDs, alias collisions, ambiguous variants, custom/imported provenance.
- B03-04: dimensional safety, quantity cases, unknown conversion, and precision.
- B03-05: missing/known-zero/status/basis/range aggregation.
- B03-06A: v17 table/FK/index order, fresh DB, real migration, failure rollback.
- B03-06B: v8 ownership, restore validation/order, stable IDs, old versions, privacy.
- B03-07/B03-08: immutable recipe ancestry and single calculation path.
- B03-09/B03-10: reviewed transformations and volume-only calibration.
- B03-11A/B: frozen source/result snapshots and legacy authority separation.
- B03-12/B03-13: existing-flow integration, shared calculator, shared constraints, accessibility/offline.
- B03-14/B03-15/B03-16: estimate privacy/uncertainty, descriptive protein/leucine, and cautious conflict states.
- B03-17/B03-18: complete regression, release evidence, residual risk, and final Sol sign-off.

## Deferred to B04 or later

- Adaptive calorie changes, remaining-target suggestions, “what can I eat now?”, festival/travel/eating-out/fasting coaching, and recommendation feedback.
- Detailed leucine thresholds, protein-quality scoring, adaptive protein coaching, and any MPS/health-outcome claim.
- Nested recipes and cycle-capable recipe graphs.
- Persistent food-specific vessel-to-mass calibration.
- Universal or unreviewed raw/cooked factors, automatic reverse conversion, and unsupported nutrient-retention heuristics.
- Unrestricted user-created allergen/conflict rules and automatic safety classification from names.
- Persistent images, provider-side image retention, and full prompt history.
