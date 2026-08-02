# B03 — Nutrition Foundation and Food Context: Decision Register

Status: proposed for Terra High and Sol High review. These are planning decisions, not implementation authorization. B03 must not change application code or create implementation branches until B02 is merged and the applicable gates below are accepted.

## Decision summary

| ID | Proposed decision | Authority | Status |
|---|---|---|---|
| B03-D01 | New nutrition relationships use portable canonical IDs; display text is presentation only | Sol High | SOL-GATE REQUIRED |
| B03-D02 | Alias resolution is exact-after-normalization and may return unresolved/ambiguous | Sol High | SOL-GATE REQUIRED |
| B03-D03 | Legacy food/log rows remain readable; no speculative name backfill | Sol High | SOL-GATE REQUIRED |
| B03-D04 | Quantities are dimension-typed with no universal gram/ml/serving fallback | Sol High | SOL-GATE REQUIRED |
| B03-D05 | Reviewed and user-entered conversions are explicit, scoped, and bounded | Sol High | SOL-GATE REQUIRED |
| B03-D06 | Published recipes are immutable versions; edits create new versions | Terra High + Sol High | Proposed |
| B03-D07 | Consumption snapshots are the historical nutrition authority | Sol High | SOL-GATE REQUIRED |
| B03-D08 | Raw/cooked transformations are directional, evidenced, and may be unknown | Sol High | SOL-GATE REQUIRED |
| B03-D09 | Household measures describe context; personal vessels require calibration | Terra High + Sol High | SOL-GATE REQUIRED |
| B03-D10 | Nutrient facts are typed/versioned; missing is not zero | Sol High | SOL-GATE REQUIRED |
| B03-D11 | AI/photo estimates retain ranges, provenance, and corrections | Sol High | SOL-GATE REQUIRED |
| B03-D12 | Thali composition uses the same calculator and snapshots as food/recipes | Terra High + Sol High | Proposed |
| B03-D13 | Protein/leucine guidance is derived, bounded, and non-medical | Sol High | SOL-GATE REQUIRED |
| B03-D14 | Restrictions are a taxonomy with evidence and four-state evaluation | Terra High + Sol High | SOL-GATE REQUIRED |
| B03-D15 | B03 proposes schema v17 and backup v8 with transactional compatibility | Sol High | SOL-GATE REQUIRED |
| B03-D16 | Domain ownership is repository/service based; controllers do not calculate or persist facts | Sol High | Proposed |
| B03-D17 | Uncertainty and offline/error states are first-class UX requirements | Terra High + Sol High | Proposed |

## Proposed rules

### B03-D01 — Portable identity

Seeded foods receive stable manifest IDs independent of SQLite insertion order. User-created, imported, prepared, recipe, and estimate entities use UUIDs. Provider/manufacturer identifiers are source fields. A name, alias, brand label, or localized display string is never a foreign key. This directly addresses the current exact-name seed upsert, recent-food grouping, template item names, and AI entries with nullable `foodItemId`.

### B03-D02 — Alias resolution

Normalization is deliberately narrow: case folding and Unicode whitespace normalization. Resolution is exact after normalization. Zero candidates is unresolved; one candidate is resolved; multiple candidates are ambiguous and require user selection. No fuzzy matching, substring matching, punctuation stripping, or removal of preparation/size terms is permitted in migration. A user correction creates an auditable overlay and does not silently merge the catalogue.

### B03-D03 — Legacy preservation

The existing `FoodItems`, `FoodLogs`, `MealTemplates`, and related profile/preference rows remain readable and exportable. Existing `FoodLogs` already copy display/nutrient values; those values are preserved as the old log’s historical representation. A legacy row maps to a new canonical food only with explicit manifest or provenance evidence. Otherwise it remains legacy, with no reinterpretation of quantity, raw/cooked state, or nutrient value.

### B03-D04 — Typed quantities

Every new quantity carries a dimension and unit. Mass, volume, count, labelled serving, household measure, and edible fraction are distinct. Inputs are finite and non-negative. Dimension mismatch returns a validation error or an unavailable result. Rounding is display/export behavior only. Existing `HouseholdMeasure` global equivalents are compatibility behavior, not the B03 truth, because the audit found silent unlike-dimension conversions and an unknown-key serving fallback.

### B03-D05 — Conversion ownership

Reviewed catalogue conversions and user calibrations are stored with scope, method, bounds, source, confidence, and rule version. A conversion may be food/preparation-specific. Density is not assumed. A countable food can remain count-only. Unknown conversion is shown as unknown or approximate; it never becomes a hidden `50 g`, `100 g`, `150 g`, `200 g`, `240 g`, or `400 g` default.

### B03-D06 — Recipe versions

A recipe has a stable identity and drafts. Publishing creates an immutable version containing ordered ingredients, preparation context, yield, serving definition, and calculation-rule version. Editing a published recipe creates a new version. Nested recipes reference a specific version. A saved recipe may point to its current version, but a consumption snapshot points to the exact version used.

### B03-D07 — Snapshot authority

New food, recipe, and thali logs create immutable consumption snapshots. Snapshot items retain selected quantity, preparation, source, nutrient facts, bounds, statuses, and calculator/fact versions. History and daily read models derive from snapshots. A catalogue or recipe edit cannot change an old snapshot. An edit to a logged entry must preserve a deliberate audit boundary, either by replacement snapshot or an explicitly versioned edit path.

### B03-D08 — Raw/cooked transformations

Raw/cooked is a preparation relationship, not a naming heuristic. A transformation is directional and includes source/target food and preparation, method, yield/water/loss information, evidence, uncertainty, and rule version. Reverse conversion requires a separate reviewed relationship. The system may return unavailable when no evidence exists. No raw/cooked values or yield factors are invented during migration.

### B03-D09 — Household measures and calibration

Katori, bowl, ladle, glass, cup, spoon, roti/chapati, piece, and thali are user-facing measure vocabulary, not universal masses. A personal vessel calibration is user-owned and stores measured volume, method, range, confidence, and optional food/preparation context. A volume calibration cannot imply the mass of every food. Food-specific weighed calibration is required for mass-based conversion. Approximate display is mandatory when evidence is approximate.

### B03-D10 — Nutrient facts and missingness

The nutrient registry defines typed units and active/versioned keys. Facts carry source, confidence, fact version, status, and optional bounds. `known_zero`, `missing`, `not_applicable`, and `estimated` remain distinct. Aggregation reports completeness and does not turn absent micronutrients into zero. Historical snapshots freeze the result and source version. Expanded nutrients are not considered complete merely because the row exists.

### B03-D11 — Estimate uncertainty

AI and photo analysis are estimate sources. A header records provider, model, rule, input/assumption metadata, timestamp, confidence, status, and supersession; child rows record each nutrient’s point/range/status/unit. A point estimate without defensible bounds is still labelled estimated and approximate. User correction creates a new provenance record. Images are not stored by default, and network failure provides a manual/unknown fallback.

### B03-D12 — Shared thali engine

A visual thali is an ordered composition of canonical foods and immutable recipe versions. It uses the same quantity, nutrient, constraint, and snapshot services as individual food and recipe logging. A saved thali is reusable composition; a logged thali is an immutable consumption snapshot. Missing or uncertain components remain visible. The builder works offline and does not infer dietary safety from a visual name.

### B03-D13 — Protein and leucine

Protein distribution is a derived read model from snapshots and explicit meal boundaries. Existing `mealGroupId` is preferred; fallback meal boundary rules require product approval. Leucine is measured, estimated, or unknown with source and heuristic version. Results preserve ranges and unknowns. Guidance is educational and bounded; it cannot promise muscle-protein-synthesis, performance, or health outcomes.

### B03-D14 — Restriction taxonomy

Allergy, intolerance, religious restriction, ethical preference, dietary pattern, taste dislike, temporary avoidance, and regional preference are independent types. A constraint may include strictness, severity, cross-contact sensitivity, effective dates, source, and notes. Food evidence is ingredient-level where possible and may be confirmed, possible, not indicated, or unknown. Evaluation returns exactly `confirmed_conflict`, `possible_conflict`, `no_known_conflict`, or `insufficient_information`. Insufficient evidence cannot be presented as safe.

### B03-D15 — Schema and backup boundary

B03 proposes schema v17 and backup v8 because canonical identity, facts, conversions, versions, snapshots, uncertainty, and constraints are durable state. Migration is transactional and keeps v16 legacy tables. Backup restore validates all references and versions before mutation, supports older envelopes without B03 sections, and rolls back invalid input. Derived daily totals are not exported as authoritative data.

### B03-D16 — Ownership

`NutritionCatalogueRepository` owns identity and facts; `NutritionQuantityService` and conversion repository own dimensions; recipe, calculation, consumption, estimate, thali, and constraint repositories each own their domain. A read-model repository projects daily/history/analytics data. Controllers do not write Drift directly, calculate nutrition independently, or maintain duplicate totals. The backup adapter owns compatibility, not business rules.

### B03-D17 — UX truthfulness

Every nutrition flow must distinguish loading, empty, invalid, unavailable, approximate, estimated, partial, offline, and error states. The UI must expose the source and assumptions that materially change the result. Accessibility labels must include quantity unit and uncertainty. “High confidence” is not a substitute for provenance or a range. The product must permit a user to log an unknown/partial result rather than force false precision.

## Decisions requiring Sol High

Sol High approval is required before implementation for:

1. The stable-ID manifest, alias ambiguity policy, and all legacy mapping rules.
2. Dimension-safe quantity semantics, conversion bounds, count/liquid behavior, and rounding boundary.
3. Immutable consumption snapshots and the treatment of edits to existing logs.
4. Raw/cooked transformation direction, yield/loss evidence, and unknown behavior.
5. Nutrient registry units, fact versions, status semantics, missing-data aggregation, and historical stability.
6. AI/photo estimate bounds, exact-value prohibition, model/provider metadata, correction history, and image retention/deletion.
7. Protein distribution and leucine computation, meal boundary fallback, and bounded non-medical wording.
8. Allergy/intolerance/religious/ethical taxonomy, ingredient evidence, cross-contact language, and insufficient-information behavior.
9. Schema v17/backup v8, old-envelope compatibility, transaction rollback, and whether any legacy mapping may be opt-in.
10. The final B03 verification evidence and any explicitly deferred capability.

## Decisions requiring Terra High

Terra High must decide the user-facing product contract for:

- Recipe draft, publish, version, archive, copy, and edit language.
- Meal categories, group boundaries, and the presentation of protein distribution.
- Indian measure vocabulary, regional labels, roti/chapati size choices, and whether a custom measure is named by the user.
- Thali composition, component ordering, partial thali behavior, and visual accessibility.
- AI/photo correction flow, confidence/range copy, retry/manual fallback, and image deletion messaging.
- Onboarding and settings separation for pattern, allergy, intolerance, religious, ethical, dislike, temporary, and regional preferences.
- Which regional and preparation variants are launch-critical; no decision should merge catalogue rows solely for convenience.

## Accepted invariants after approval

Once the gates are accepted, these become regression invariants:

- Same stable IDs and source/version metadata survive backup/restore and device migration.
- Display-name changes do not change identity, and identical names may coexist.
- Unknown or dimension-incompatible quantities never become hidden grams or zero nutrients.
- A catalogue, recipe, conversion, or model change cannot rewrite a historical snapshot.
- Missing nutrients remain missing; known zero is the only path to zero without a measured/declared zero fact.
- AI/photo estimates retain uncertainty and provenance through correction and logging.
- Constraints remain typed and evidence-backed; insufficient evidence remains insufficient.
- Recipe and thali calculations use the same engine and calculator version.
- Existing v16 food logs, templates, and v7-or-earlier backups remain readable according to their original semantics.
- B04 adaptive coaching, medical advice, and automatic dietary safety claims remain outside B03.

## Open blockers

Implementation is blocked until B02 is merged and the Sol High gates are recorded. The most consequential unresolved choices are the raw/cooked evidence policy, exact nutrient completeness semantics, and the restriction taxonomy/cross-contact language. Until those are accepted, the proposed schema and task ordering are a controlled plan rather than an implementation contract.
