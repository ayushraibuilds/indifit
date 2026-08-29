# IndiFit R08-0 Final Pre-Implementation Decision Review

**Status:** FINAL decision boundary for master-roadmap planning; not implementation authority

**Review date:** 2026-08-20

**Repository baseline inspected:** `fce4c36` plus the supplied uncommitted R08 audit inputs

**Primary inputs:** frozen product reference manual, `R08_0_EXTERNAL_ASSET_READINESS_AUDIT.md`, `R08_0_EXERCISE_MAPPING_SPIKE.csv`, current repository code, and canonical B01/B02/B05 decisions

## Executive decision

Proceed with R08-0 as a six-package asset/foundation wave, subject to the gates in this memo. The Flash audit is directionally useful but is not sufficient production authority.

The binding corrections are:

1. The 140 catalog entries remain 140 distinct canonical exercise identities. The 35 observed four-entry families are a reviewed visual-reuse relationship, not a new exercise identity layer.
2. R08-0 targets **34 candidate RepDB base-movement mappings for manual approval**, not 35–50 assets. The unmapped Decline Hammer Strength Press family uses the normal fallback chain. No extra RepDB variants are justified in R08-0.
3. The supplied CSV remains **CANDIDATE** evidence. No row becomes production authority until its illustrations and semantics are manually approved from a contact sheet against a pinned upstream snapshot.
4. Do not add a domain/database `baseMovementVisualKey`. Production should explicitly bind each canonical exercise UUID to a reusable visual asset-set ID in a checked-in media manifest. Multiple UUIDs may bind to the same asset set.
5. B02 taxonomy data does not change in R08-0. Fix Exercise Library browsing through one canonical display-muscle resolver; keep B02 reviewed allocation mappings authoritative for analytics.
6. Build the local muscle renderer as a standalone foundation. Do not replace Progress, Training, or workout-player surfaces in R08-0.
7. Define the wakelock lifecycle contract in R08-0 documentation/tests only if useful; implement session-wide wakelock ownership in R08B, where the execution lifecycle is redesigned.
8. Anatome was misclassified. It is Apache-2.0, self-hostable, and includes permissively licensed anatomy paths, but IndiFit does not need it at runtime. Keep it REFERENCE / QA ONLY.
9. RepDB size, decode-time, and frame-performance claims are not verified. Release decisions must use measurements from the exact vendored files and representative devices.
10. openGym remains concept-only. No AGPL source or assets enter IndiFit. Existing B01/B02 capability—not openGym feature breadth—controls scope.

## 1. Flash finding verification

| Claim | Verdict | Evidence | Roadmap impact |
|---|---|---|---|
| 140 entries / 35 physical base-movement families / four variants each | **VERIFIED WITH CORRECTION** | `assets/data/exercises.json` contains 140 rows. Removing only the explicit `Pause `, `Slow Eccentric `, and ` (Standard)` qualifiers yields 35 groups of exactly four. B01-D01 nevertheless requires catalog variants to remain distinct records. | Reuse visuals across reviewed equivalent-execution variants; never collapse exercise identity or history. |
| Stable UUID identity | **VERIFIED** | `ExerciseCatalogManifest.goldenCatalogUuids` contains 140 unique fixed UUIDs. B01-D01 makes stable IDs portable identity and prohibits technique-stripping/fuzzy identity matching. Custom exercises receive persistent UUIDs. | Visual lookup is keyed from canonical UUID. Names and fuzzy matches are never production lookup authority. |
| 34/35 RepDB coverage | **PARTIALLY SUPPORTED** | The CSV contains 34 candidate IDs and one `NO_MATCH`, but it does not identify an upstream commit or include the source images/checksums. Metadata and filenames do not prove visual equivalence. RepDB also documents that holds/stretches can have one `main` image rather than start/peak, which makes the blanket pose-pair claim unsafe until inspected. | Treat 34 as the approval target, not achieved production coverage. Generate and manually approve the contact sheet. |
| B05 media infrastructure is ready | **VERIFIED WITH CORRECTION** | B05 already provides manifest parsing, exact approved-ID validation, SHA-256 probing, fail-closed defaults, text fallback, rights fields, and a muscle-region registry. However, `B05MediaAcceptanceTemplate.requiredExerciseCount` and its validator are fixed to 20, the production manifest source is null, the probe defaults absent, and the asset contract currently models one asset ID per exercise rather than an explicit start/peak set. | Extend/evolve B05 contracts; do not create a parallel media subsystem. Migration must retain fail-closed behavior and tests. |
| Exercise Library primary/secondary categorization bug | **VERIFIED** | `ExerciseLibraryScreen._loadExercises()` uses case-insensitive substring containment on the full comma-separated `muscleGroups`, both for counts and filtering. | R08-0 fixes this with one resolver and tests. No B02 taxonomy expansion is needed. |
| `fl_chart` is sufficient | **VERIFIED WITH CORRECTION** | `fl_chart ^0.67.0` is present and already renders weight charts/sparklines. Flutter painters/widgets cover other proposed visuals. “Sufficient for every future visualization” is broader than static inspection proves. | Add no chart dependency in R08-0. Reassess only when a concrete downstream design cannot meet acceptance criteria. |
| `wakelock_plus` is used only by rest timer | **VERIFIED** | Repository search finds `WakelockPlus.enable/disable` only in `rest_timer_bottom_sheet.dart`. | Runtime ownership moves to R08B; R08-0 records the lifecycle contract and dependency readiness. |
| MuscleMap-to-Flutter renderer is feasible | **VERIFIED WITH CORRECTION** | The upstream MIT repository supplies male/female, front/back SVG path geometry and heatmap concepts. Flutter `CustomPainter`/`Path` can render equivalent local geometry. Feasibility does not prove port accuracy, accessibility, path provenance, or performance. | R08-0 may implement the isolated renderer, adapter, showcase, golden/semantic tests, and provenance. No product-surface redesign. |
| RepDB license/use boundary | **VERIFIED WITH CORRECTION** | RepDB Free Tier License v1.0 permits personal/commercial in-app use with visible attribution; forbids redistribution as a dataset; permits resize/crop/recolor; forbids generative-AI derivation; and excludes premium preview animations from production. | Vendor only approved free-tier WebPs into the application. Preserve license text, attribution, snapshot pin, and asset checksums. Do not publish a reusable derived dataset or feed images to generative tools. |
| openGym license boundary | **VERIFIED** | Upstream identifies the project as AGPL-3.0. | Concepts may inform requirements; zero code/assets copied. Maintain a clean-room note recording concept-only review. |
| Anatome is proprietary/hosted-only | **WRONG** | Upstream is Apache-2.0, explicitly self-hostable, and states its anatomy SVG paths originate from MIT `react-native-body-highlighter`. Its exercise metadata is Unlicense, while its proxied exercise imagery is explicitly not cleared for redistribution. | Correct the source matrix. Keep Anatome REFERENCE / QA ONLY because IndiFit's local renderer already meets the runtime need; never import its unverified exercise imagery. |
| Average WebP ~20 KB | **UNSUPPORTED** | No pinned asset set, byte inventory, or measurement output accompanies the audit. | Measure exact file sizes after approval/vendoring. |
| Total bundle impact ~1.4 MB | **ESTIMATE** | This is arithmetic based on the unsupported 20 KB average and 70 assumed images; the intended approved set may include single-pose assets. | Report raw bytes and compressed APK/IPA delta from actual release builds. Do not use 1.4 MB as an acceptance fact. |
| WebP decodes in <5 ms | **UNSUPPORTED** | No device, build mode, codec trace, cold/warm cache distinction, or sample results are provided. | Benchmark exact widgets/assets on representative low/mid/high devices. |
| The asset count will not cause frame drops | **UNSUPPORTED** | Asset count alone does not establish image-cache pressure, decode/upload cost, widget reuse, or scroll performance. | Add timeline/profile-mode scroll and memory acceptance gates. |

### Upstream sources checked

- RepDB repository and schema: <https://github.com/RepDB/exercise-dataset>
- RepDB Free Tier License v1.0: <https://github.com/RepDB/exercise-dataset/blob/main/LICENSE-DATA.md>
- MuscleMap source: <https://github.com/melihcolpan/MuscleMap>
- Anatome source and notice: <https://github.com/Rippy1911/anatome>
- openGym source: <https://github.com/DuarteSantos8/openGym>

These URLs identify upstreams but are not reproducibility pins. Implementation must record immutable commits/tags.

## 2. Canonical exercise visual identity model

### Decision

Do **not** add `baseMovementVisualKey` to the exercise domain, Drift schema, catalog fixture, or backup format.

Use the existing canonical exercise UUID as the only exercise identity. Add a presentation-only, checked-in visual manifest with two concepts:

- `visual_asset_set`: a reusable pair/singleton of approved local illustration files plus provenance;
- `exercise_binding`: an explicit canonical exercise UUID → visual asset-set ID association.

The asset-set ID identifies artwork, not an exercise or movement. It may be named from the pinned source and external ID (for example `repdb:<snapshot>:barbell-bench-press`) or use an opaque locally stable ID. Four distinct canonical UUIDs may explicitly bind to the same asset set.

```text
canonical exercise UUID A ─┐
canonical exercise UUID B ─┼──> approved visual asset set ──> local start/peak (or main) files
canonical exercise UUID C ─┤                                  + pinned RepDB provenance
canonical exercise UUID D ─┘
```

This is intentionally not:

```text
exercise UUID -> fuzzy/derived base movement -> closest external exercise
```

### Why explicit bindings are safer than derivation

The current four-entry grouping can be observed from names, but B01-D01 explicitly prohibits technique stripping for identity. A runtime derivation rule based on prefixes/suffixes would silently merge future exercises that share text but differ in equipment, stance, grip, range, assistance, or unilateral mechanics. Repeating 136 small binding records is cheaper and safer than creating a second movement identity system.

Candidate tooling may derive proposed families from the frozen catalog to reduce review work. Its output remains candidate-only until an approver confirms every member. Production performs exact UUID lookup only.

### Variant semantics

The binding carries or inherits this required disclosure:

> This start/finish illustration represents the underlying movement and equipment. It is not an exact demonstration of pause duration, tempo, or other technique prescription. Follow the IndiFit cues and set prescription for technique details.

The standard, pause, and slow-eccentric variants may share artwork only when the actual movement, equipment, setup, range, and direction are the same. A technique qualifier alone is not permission to reuse. Review is explicit per canonical UUID.

### Custom, legacy, deleted, and unknown exercises

- **Custom exercises:** retain their persistent UUIDs. They have no Tier-1 external illustration unless a separate user-media/product specification is approved. Use reviewed muscle data if it exists; otherwise equipment icon; otherwise neutral fallback.
- **Deleted catalog rows with known stable UUIDs:** a historical screen may render an existing exact manifest binding while the asset remains shipped. No name-based remap is attempted.
- **Legacy name-only rows:** use no exercise illustration. B01/B02 unresolved status remains unresolved; fall back without fuzzy matching.
- **Unknown UUIDs:** exact lookup misses and falls through. No network lookup, closest-neighbor lookup, or runtime candidate generation.
- **Substitutions:** render the actual performed exercise UUID, consistent with B02-D03; never the planned exercise's visual after substitution.

### Production location

The relationship belongs in a checked-in asset/media manifest consumed by the existing B05 boundary. It does not belong in fixtures that define exercise identity and does not require a database migration or backup field. Build/test tooling may generate Dart indices from the manifest, but the JSON manifest remains the reviewable authority.

## 3. RepDB approval pipeline

### Required state machine

```text
pinned external snapshot
  -> deterministic candidate matcher
  -> candidate mapping CSV
  -> contact sheet/gallery
  -> independent visual review
  -> named human approval
  -> approved mapping artifact
  -> local asset vendoring
  -> checksum/provenance validation
  -> production media manifest/registry
```

### Authority levels

| Level | Meaning | May ship? |
|---|---|---|
| **CANDIDATE** | A script or reviewer proposes an external ID based on name/equipment/muscle metadata. The current CSV is here. | No |
| **APPROVED** | A reviewer has inspected the actual pinned START/PEAK or MAIN illustration, confirmed equipment/setup/movement equivalence and variant-reuse semantics, and recorded a decision. | Not yet; assets/provenance may still be missing |
| **PRODUCTION** | Approved mapping, exact local files, required attribution/license, SHA-256 values, and manifest validation all pass in the application build. | Yes |

### Contact-sheet gate

R08-0.2 must produce a human-reviewable gallery for every candidate mapping. Each card must show:

- IndiFit canonical base UUID and name;
- all canonical variant UUIDs proposed to reuse it;
- IndiFit equipment and authoritative primary display muscle;
- RepDB ID and name;
- the actual START and PEAK images, or the actual single MAIN image;
- candidate confidence and reason;
- taxonomy/equipment/range/setup conflicts;
- the movement-illustration disclosure;
- reviewer decision, reviewer identity, date, and notes.

Approval must explicitly catch at least: wrong grip, stance, angle, apparatus, laterality, assistance, body orientation, range of motion, chest-versus-triceps dip emphasis, and single-pose/isometric behavior.

**Terra Max is an appropriate fresh independent visual reviewer** because this gate is primarily visual and semantic. It must receive the pinned images and frozen IndiFit facts without the Flash recommendation as an answer key. Terra Max is not the final legal/canonical approver: a named human must approve the gallery before the production manifest is generated. A separate Sol High review is appropriate for manifest invariants and B01/B02 identity boundaries.

### V1 target scope

- Approval target: 34 candidate base movements.
- Explicit fallback target: Decline Hammer Strength Press and its three variants.
- Production target: only the subset of those 34 that passes the contact-sheet gate.
- Additional RepDB variants: **none in R08-0**. Equivalent pause/tempo variants reuse approved movement illustrations; non-equivalent variants fail closed until a later reviewed mapping.

## 4. Third-party provenance model

### Source-controlled artifacts

Use static artifacts; do not build a runtime license engine.

```text
docs/legal/THIRD_PARTY_ASSETS.md
LICENSES/
  RepDB-LICENSE-DATA-v1.0.md
  MuscleMap-MIT.txt
  Phosphor-MIT.txt                 # only if the dependency/assets are added
  wakelock_plus-BSD-3-Clause.txt   # if not already covered by generated notices
assets/third_party/
  asset_manifest.json
assets/exercises/repdb/
  <approved local WebP files>
```

`asset_manifest.json` should either evolve the B05 media contract or be deterministically transformed into it. Do not maintain two independently editable production manifests.

### Required snapshot fields

At source level:

- source name and canonical repository URL;
- immutable commit hash and optional tag/release;
- acquisition date in UTC;
- license name/version and vendored license file;
- exact attribution string/link;
- distribution constraints and prohibited uses;
- local manifest schema version.

For each file/path set:

- source exercise/asset ID;
- source-relative path;
- local destination;
- SHA-256 of the exact local file;
- media role (`start`, `peak`, or `main`);
- any modification (`none`, resize, crop, recolor) with deterministic parameters;
- approval status and approval record ID;
- canonical exercise UUID bindings.

### Reproducibility rule

No floating `main`, live URL, package `latest`, or unversioned download may feed production. Acquisition tooling checks out/downloads the recorded commit, copies only the approved free-tier files, computes hashes, and fails if any source ID/path or license file differs. CI verifies every local file and rejects unmanifested files, missing files, duplicate local destinations, and bindings to unknown UUIDs.

RepDB's no-redistribution term means the repository/application distribution must be reviewed against the license's “in-app use” grant. If the IndiFit source repository is public, do not assume that committing the asset directory is permitted merely because packaging it in the app is permitted; obtain explicit licensor/legal confirmation or use an approved private acquisition/build path. This memo does not make a legal determination.

## 5. Muscle renderer architecture

### Source decision

Use a pinned commit of `melihcolpan/MuscleMap` as the **primary source of actual vector geometry**, subject to a file-level license/provenance review before import. It supplies male/female, front/back geometry under MIT and has the closest fit to the desired local renderer.

Use `react-native-body-highlighter` and Anatome only as independent geometry/taxonomy QA references. Do not blend paths from multiple projects unless each path's origin and license are recorded; mixed geometry would make provenance and visual correction harder.

### Boundary

```text
B02/catalog canonical facts
  -> IndiFit taxonomy adapter
  -> presentation highlight model
  -> local geometry registry
  -> CustomPainter + semantic text equivalent
```

External muscle names never flow backward into B02 or `Exercises.muscleGroups`.

### Required component behavior

- **Views:** male/female and front/back/both. If product later chooses a single neutral default, retain the complete tested geometry without promoting gender selection unnecessarily.
- **Exercise mode:** resolved primary and secondary highlights use distinct semantic roles. Stabilizers may be omitted in V1 or shown only when canonically provided.
- **Heat mode:** accepts normalized/intensity values from a caller; the renderer does not invent, normalize unknown data to zero, or label values as physiological readiness.
- **No data:** neutral silhouette plus concise text equivalent/empty message; never an all-zero heatmap implying measured inactivity.
- **Taxonomy adapter:** explicit checked-in mapping from canonical IndiFit IDs/display semantics to one or more geometry regions; unknown IDs remain unknown. B02's current reviewed four-muscle catalog is not expanded to fill the diagram.
- **Theme:** semantic colors with verified contrast in light/dark themes; inactive geometry remains distinguishable without looking highlighted.
- **Accessibility:** a meaningful overall label, ordered textual list of highlighted canonical muscles/roles or values, no dependence on color alone, and adequate target semantics if regions become interactive.
- **Motion:** the foundation should be static by default. Any later transition respects reduced motion; no animation is required for comprehension.
- **Ownership:** reusable media/visual foundation module, integrated through existing B05 muscle registry semantics rather than a parallel taxonomy.

### Integration sequencing

R08-0 implements geometry, adapter, theme/accessibility behavior, showcase, golden tests, semantics tests, and deterministic path validation. It does **not** replace Progress text cells or redesign Exercise Detail/Workout Player.

Product integration belongs to:

- R08B: workout player only if the redesigned player demonstrates a useful, uncluttered placement;
- R08C: Exercise Detail/Training;
- R08F: Progress heatmaps, including range, metric, coverage, unknown-data, and sparse-state rules.

This sequencing avoids letting a component implementation pre-decide three product layouts.

## 6. R08-0 final work packages

### R08-0.1 — Source pinning, legal/provenance manifest, attribution framework

**Exact scope**

- Pin exact upstream URLs/commits/tags and acquisition date.
- Preserve source licenses/notices and RepDB attribution/constraints.
- Define one checked-in static asset manifest compatible with/evolved from B05.
- Add CI/static validators for known UUIDs, exact files, checksums, license fields, status, and unmanifested assets.
- Provide the About/Credits attribution contract; UI integration may be minimal if Settings is later redesigned.

**Explicit non-scope:** acquiring unapproved assets; legal opinion; runtime license decision engine; public redistribution decision; product-surface redesign.

**Dependencies:** none. Must precede asset vendoring.

**Risk / complexity:** High consequence, medium implementation; **M**.

**Parallelization:** Safe in parallel with R08-0.4 resolver design and renderer prototype if no third-party geometry is committed until this package freezes provenance schema. Coordinate shared B05 contract files with R08-0.3/0.5.

**Likely files/modules:** `docs/legal/THIRD_PARTY_ASSETS.md`, `LICENSES/`, `assets/third_party/asset_manifest.json`, `lib/core/fixtures/b05_foundation_registry.dart`, `test/b05_media_playlist_test.dart`, new manifest-validation tooling/tests.

**Preferred implementation model:** **Sol High**.

**Required fresh review model:** **Terra Max** for independent license/source-record completeness review; escalate unresolved legal interpretation to a human.

**Acceptance criteria**

- Every source and file has immutable provenance and license fields.
- CI detects mutation, absence, unknown UUID, duplicate file/key, and unapproved status.
- RepDB visible attribution string/link is specified exactly.
- Premium preview animations and generative derivation are explicitly prohibited.
- No duplicate runtime manifest authority exists.

**Rollback:** remove the new static artifacts/validator without touching exercise/domain data. No migration or user data is involved.

### R08-0.2 — Base-movement candidate finalization and contact-sheet approval

**Exact scope**

- Re-run candidate matching against the pinned RepDB snapshot.
- Reconcile the existing 35-row CSV with actual source records.
- Generate the required 35-card contact sheet/gallery (34 candidates plus the explicit no-match/fallback card).
- Independently review every illustration and every proposed variant reuse.
- Record named human approvals/rejections and freeze the approved mapping artifact.

**Explicit non-scope:** production registry generation, asset widget implementation, additional RepDB variants, fuzzy runtime lookup, taxonomy mutation.

**Dependencies:** R08-0.1 snapshot/provenance schema.

**Risk / complexity:** Highest content-correctness risk; **M**.

**Parallelization:** Candidate tooling and gallery layout can run in parallel. Final mapping freeze must be serial after all visual reviews and provenance pinning. Avoid simultaneous manual edits to the CSV/approval artifact.

**Likely files/modules:** current spike CSV (preserved or superseded explicitly), new approved mapping data under `docs/implementation/r08/`, generated review gallery under review artifacts, mapping validator/tool.

**Preferred implementation model:** **Gemini Flash 3.7 High** for deterministic breadth/candidate regeneration.

**Required fresh review model:** **Terra Max** for blinded visual/semantic review, followed by named human approval.

**Acceptance criteria**

- Every mapping shows actual pinned pose assets and all required metadata.
- No `EXACT` label bypasses manual review.
- Single-pose versus pair assets are recorded truthfully.
- All variant-reuse bindings are explicit and equipment/mechanics-equivalent.
- Rejected/unmapped movements have tested fallback expectations.

**Rollback:** approval artifacts can be reverted without affecting production because candidate/approved data is not runtime authority.

### R08-0.3 — Exercise visual registry, local RepDB pipeline, reusable visual widget

**Exact scope**

- Evolve existing B05 media contracts from fixed top-20/single-asset assumptions to approved reusable asset sets with `start`/`peak` or `main` roles.
- Vendor only approved files and verify hashes.
- Add explicit UUID bindings for all approved canonical variants.
- Implement one reusable offline widget with the four-tier fallback and truthful technique disclosure/alt text.
- Keep all defaults fail-closed.

**Explicit non-scope:** Exercise Library/Detail/player redesign; remote media; animation loops unless later product design explicitly asks; fuzzy mapping; RepDB metadata as exercise authority.

**Dependencies:** completed R08-0.1 and approved output from R08-0.2; uses R08-0.5 renderer and R08-0.6 icons only for lower fallback tiers.

**Risk / complexity:** B05 contract mismatch, wrong fallback, bundle/performance; **M–L**.

**Parallelization:** Pipeline/validator work can proceed before the final asset set using fixtures. Final manifest/assets wait for approvals. Shared B05 files require a single owner.

**Likely files/modules:** `lib/core/fixtures/b05_foundation_registry.dart`, `lib/features/media/b05_media_bundle.dart`, new reusable exercise-visual widget, `assets/exercises/repdb/`, `assets/third_party/asset_manifest.json`, `pubspec.yaml`, media tests.

**Preferred implementation model:** **GLM 5.3 Max**.

**Required fresh review model:** **Sol High** for identity/fail-closed/B05 compatibility.

**Acceptance criteria**

- Exact UUID lookup only; 136 is a maximum expected binding count for 34 fully approved four-entry families, not a required count if any mapping is rejected.
- All packaged files match SHA-256 and the pinned license record.
- Missing/corrupt/unapproved assets never render.
- Fallback order is exact local illustration → canonical muscle visual → equipment/movement semantic icon → neutral fallback.
- No visually similar unverified illustration is ever selected.
- Profile-mode measurements record raw/packaged size, decode/frame behavior, and memory on the agreed device matrix.

**Rollback:** disable the manifest provider/feature flag to restore B05 text fallback, then remove assets in a later cleanup. No exercise/database rollback.

### R08-0.4 — Canonical primary/secondary display resolver and Library correctness

**Exact scope**

- Introduce one reusable resolver for the catalog's ordered `muscleGroups` display field: first valid token = primary; remaining valid tokens = secondary.
- Use it for Exercise Library category counts/filtering.
- Keep secondary values available for details and deliberate search indexing.
- Document that B02 `ExerciseMuscleMappings` remains the only source for muscle-allocation arithmetic.

**Explicit non-scope:** changes to `B02CanonicalMuscleCatalog`, seeding new allocation weights, database migration, external taxonomy imports, changing IndiFit primary assignments.

**Dependencies:** none; canonical B01/B02 decisions.

**Risk / complexity:** Low-medium code risk, high semantic importance; **S–M**.

**Parallelization:** Safe except for shared Exercise Library files with R08C. Land before R08C starts.

**Likely files/modules:** a small resolver near exercise catalog/domain fixtures, `lib/features/exercise_library/exercise_library_screen.dart`, resolver/library tests.

**Preferred implementation model:** **GLM 5.3 High**.

**Required fresh review model:** **Sol High**.

**Acceptance criteria**

- Bench press does not appear in Triceps primary browsing merely because Triceps is secondary.
- Counts and result filtering use the same resolver.
- Empty/malformed/custom strings fail safely without substring guesses.
- Secondary detail/search behavior is explicitly tested.
- B02 taxonomy/mappings are byte-for-byte unchanged by this package.

**Rollback:** revert resolver call sites; no stored-data changes.

### R08-0.5 — Local `IndiFitMuscleMap` renderer foundation

**Exact scope**

- Pin and provenance-review MuscleMap geometry.
- Port required vector paths to local Flutter geometry.
- Implement explicit IndiFit taxonomy adapter, primary/secondary and intensity modes, male/female front/back, theme, no-data, semantics, and reduced-motion-safe behavior.
- Add component showcase, goldens, semantics, mapping, and path-integrity tests.

**Explicit non-scope:** expanding B02 taxonomy; physiological interpretation; readiness/recovery score; replacing Progress cells; integrating Training/player/product layouts.

**Dependencies:** R08-0.1 before geometry is committed; R08-0.4 semantics can inform exercise-mode adapter but must remain separate from B02 analytics.

**Risk / complexity:** Geometry correctness, attribution, taxonomy drift, accessibility; **L**.

**Parallelization:** Geometry/painter, adapter, and accessibility tests can be split if one owner controls region IDs and generated path data. Avoid parallel edits to B05 registry contracts.

**Likely files/modules:** new reusable renderer under media/core widgets, geometry data, adapter, B05 muscle diagram bridge, showcase route/test harness, golden/semantic tests, license/provenance files.

**Preferred implementation model:** **GLM 5.3 Max**.

**Required fresh review model:** **Terra Max** for visual/a11y states; Sol High remains appropriate for taxonomy-boundary code review.

**Acceptance criteria**

- All four body views render without clipping/path corruption at supported sizes.
- Only explicit adapter mappings highlight; unknown inputs remain unknown.
- Primary/secondary and intensity modes are visually and semantically distinguishable.
- Light/dark, text scaling, color-contrast, no-data, and reduced-motion tests pass.
- No Progress/Training/player production surface changes.

**Rollback:** unregister the renderer so the existing B05 text equivalent remains; remove geometry in later cleanup. No domain/data changes.

### R08-0.6 — Minimal `IndiFitIcons` semantic facade

**Exact scope**

- Define a small semantic icon API only for R08 foundation components and already-approved shared concepts.
- Prefer existing Material icons; add Phosphor only if a concrete missing semantic glyph justifies the dependency and its license/font assets are pinned.
- Add semantic labels/tests where icons convey information.

**Explicit non-scope:** app-wide replacement, navigation redesign, macro/meal icon campaign, per-screen aesthetic changes.

**Dependencies:** R08-0.1 if Phosphor is added; otherwise none.

**Risk / complexity:** Low; risk is uncontrolled migration/scope creep; **S**.

**Parallelization:** Safe if the API file has one owner. Screen migrations remain with R08B–R08G and leftovers with R08H.

**Likely files/modules:** `lib/core/theme/indifit_icons.dart`, focused tests, optional `pubspec.yaml`/license record.

**Preferred implementation model:** **Luna Max**.

**Required fresh review model:** **Terra Max**.

**Acceptance criteria**

- Only enumerated semantic concepts are exposed.
- Existing screens are unchanged except where required to showcase/test the facade.
- No dependency is added without a used, reviewed glyph and provenance.
- Icons are not the sole accessible label.

**Rollback:** replace new facade calls in new R08 components with existing Material icons; no data impact.

### Wakelock disposition

**R08-0:** record the required contract and verify dependency/current call sites:

- ownership is the single active workout execution session, not a modal;
- acquire on start/resume only when policy allows;
- reconcile foreground/background behavior;
- release on successful completion, explicit discard, and every terminal/abandon path;
- modal rest timer must not independently disable a session-owned lock;
- plugin errors fail safely and never block workout persistence.

**R08B:** implement the final controller against the redesigned shared Quick/Planned lifecycle, draft recovery, resume, completion/discard, route ownership, and app lifecycle. Implementing it now would likely be rewritten and risks two owners.

## 7. Downstream R08 dependency impact

The proposed macro order remains valid:

```text
R08-0 -> R08A -> R08B -> R08C -> R08D -> R08E -> R08F -> R08G -> R08H -> R08RC
```

No real dependency requires reordering the program.

| Wave | R08-0 input | Boundary |
|---|---|---|
| **R08A Correctness & Shared Defects** | Primary-muscle resolver and tests can land here only if R08-0.4 is not already complete; provenance/visual work does not block unrelated correctness. | Do not use R08A to expand taxonomy or integrate visuals. |
| **R08B Workout Execution** | Reusable visual widget/fallbacks, minimal icons, optional muscle renderer, and the wakelock lifecycle contract. | R08B owns actual session-wide wakelock and player placement. Preserve B02 draft/finalization authority. |
| **R08C Training** | Approved exercise visuals, explicit variant disclosure, correct primary browsing, and muscle renderer foundation. | R08C decides Exercise Library/Detail/plan UI prominence; R08-0 does not pre-layout it. |
| **R08D Food** | Minimal semantic icon facade only, if useful. | Exercise assets/taxonomy are not a Food dependency; do not force visual-system churn. |
| **R08E Today + Onboarding + Targets** | Shared icon facade and established asset/licensing pattern. | No exercise-media dependency should block Today/onboarding correctness. |
| **R08F Progress** | Local muscle renderer, B02 taxonomy adapter, and measured chart/painter capability. | R08F owns heatmap placement, ranges, sparse states, coverage, metric labels, and evidence semantics. |
| **R08G Settings** | Static third-party records and exact attribution copy/link. | Settings redesign decides presentation; it must not become a runtime licensing engine. |
| **R08H Global Product Polish** | Remaining per-screen icon migrations and cross-surface visual consistency; final image-cache/loading polish. | No app-wide icon replacement earlier. |
| **R08RC Release Acceptance** | Hash/provenance validation, visual approval record, fallback tests, performance measurements, accessibility evidence, and no-AGPL audit. | Reject release on unknown/mismatched assets or unsupported performance claims. |

## 8. Risk register

| Risk | Likelihood | Impact | Mitigation | Responsible wave |
|---|---:|---:|---|---|
| RepDB license/redistribution breach | Medium | Critical | Pin v1.0; vendor license; visible attribution; record prohibited uses; resolve public-repo distribution with licensor/legal review. | R08-0.1, R08RC |
| Wrong exercise illustration | Medium | High | Mandatory pinned-image contact sheet, independent visual review, named human approval, exact UUID binding, fail closed. | R08-0.2, R08RC |
| Taxonomy drift from external source | Medium | High | One-way explicit adapters; B02/exercise catalog remain authority; no metadata import. | R08-0.4/0.5, R08F |
| Duplicate exercise identity system | Medium | High | No domain `baseMovementVisualKey`; explicit UUID → visual asset-set binding in presentation manifest only. | R08-0.3 |
| Bundle bloat | Low–Medium | Medium | Vendor only approved assets; record raw and release-package deltas; no 35–50 expansion. | R08-0.3, R08RC |
| Image memory/scroll jank | Medium | High | Profile-mode device matrix; correct `cacheWidth`/layout sizing; measure decode, memory, build/raster frame percentiles, cold/warm scroll. | R08-0.3, R08C/B, R08RC |
| B05 media-contract mismatch | High | High | Evolve existing contract with compatibility tests; one manifest authority; retain null/absent/invalid fallbacks. | R08-0.3 |
| Muscle-map accessibility failure | Medium | High | Text equivalent, non-color cues, semantics order, contrast/text-scale/golden tests, reduced-motion-safe static state. | R08-0.5, R08F, R08RC |
| Custom exercise shows misleading media | Medium | High | No Tier-1 asset by default; exact custom UUID handling; reviewed muscle/equipment/neutral fallbacks only. | R08-0.3/0.4 |
| Variant artwork implies exact pause/tempo demo | High | Medium | Required disclosure, explicit per-UUID reuse approval, cues/prescriptions remain technique authority. | R08-0.2/0.3, R08C/B |
| AGPL contamination from openGym | Low–Medium | Critical | Concept-only record; no source/assets copied; independent IndiFit implementation from canonical requirements; final diff/license audit. | All R08, R08RC |
| External dataset changes | High | High | Immutable commit/tag, acquisition date, exact IDs/paths, local hashes; no floating main/latest. | R08-0.1 |
| Agent scope creep | Medium | High | Package non-scopes, model/reviewer assignment, acceptance gates, human approvals, no taxonomy/domain expansion. | Every wave |
| Parallel branch conflicts | Medium | Medium | Single owners for B05 registry, manifest, `pubspec.yaml`, and renderer region IDs; fixture-first parallel work; staged integration order. | R08-0 lead |
| Anatome imagery mistakenly treated as licensed | Medium | High | Record Apache code/MIT anatomy separately from unverified proxied exercise imagery; reference/QA only. | R08-0.1/0.5 |
| Wakelock leak or competing owners | Medium | High | One session-owned controller in R08B; modal cannot disable it; terminal/lifecycle matrix tests. | R08B, R08RC |

### Required performance measurements

R08-0.3/R08RC must replace Flash estimates with:

1. exact count and byte size of every approved file, total raw bytes, and per-file min/median/p95/max;
2. release APK/AAB and iOS archive/IPA size delta with and without the assets;
3. cold and warm decode/raster-upload timing for representative `start`, `peak`, and `main` assets in profile mode;
4. peak/steady image-cache and process memory while scrolling the densest Exercise Library grid/list and while toggling poses;
5. build/raster frame p50/p95/p99, missed-frame count, and 60/120 Hz behavior on an agreed low/mid/high device matrix;
6. first-display latency, placeholder/fallback behavior, and cache-eviction behavior;
7. muscle-map paint/layout cost at expected sizes and on theme/data changes.

The mathematical uncompressed payload of a 512×512 32-bit raster is about 1 MiB, but actual Flutter/GPU/cache memory must still be measured; that arithmetic is not a memory-performance verdict.

## 9. openGym concept boundary

### Adopt as R08 product requirements where already canonical

- Previous-performance prefill: implement in R08B using exact actual stable exercise identity, compatible load basis, authoritative plan/history, and existing B02 recommendation rules. Never copy openGym logic.
- Compact set logger: R08B, preserving B02 role/effort/tempo/segment and draft/finalization semantics.
- Circular rest progress: R08B visual treatment around existing B02 selected/recommended/actual rest authority.
- Active-session wakelock: R08B lifecycle owner as decided above.

### Reconcile against existing B01/B02; do not expand the domain

- Timed work: B02 already has duration-based activity modalities and set/draft fields; define the exact strength-exercise need before adding UI/schema.
- Supersets/grouped sets: already canonical under B02-D05 (`superset`, `circuit`, `giantSet`). Expose existing semantics rather than inventing a new grouping model.
- Effort/RPE/RIR: B02 already models RPE and effort modes; keep optional/progressively disclosed. Do not add RIR without a canonical conversion/storage decision.
- Bodyweight and per-side: B02 already has `bodyweight`, `perImplement`, and `perSide` load bases. UI must preserve them rather than infer/double values.
- Unilateral representation: equipment/load basis exists, but left/right execution identity is not permission to add a new modality without a B02 defect/specification.
- Flexible rescheduling: B01 owns occurrence/reschedule semantics. No openGym scheduling state enters IndiFit.

### Reject or defer

- synthetic e1RM: reject until separately specified by canonical B02 authority;
- formula workout calories: reject;
- unsupported/synthetic PR events and celebration: reject until a canonical PR-event owner exists;
- automatic progression outside accepted B02 rules: reject;
- Strong/Hevy/FitNotes import: defer beyond V1;
- all openGym code/assets: prohibited from IndiFit under this clean-room decision.

## FINAL DECISIONS FOR R08 MASTER ROADMAP

1. **Keep the macro sequence unchanged:** R08-0, R08A, R08B, R08C, R08D, R08E, R08F, R08G, R08H, R08RC.
2. **R08-0 contains exactly six work packages:** provenance/pinning; mapping/contact-sheet approval; production visual pipeline/widget; primary-muscle resolver/library fix; standalone muscle renderer; minimal semantic icon facade.
3. **Canonical exercise identity remains the 140 stable UUIDs.** No IDs are merged and no `baseMovementVisualKey` enters the domain/database/backup.
4. **Visual reuse is explicit in the checked-in production media manifest:** multiple exact canonical UUIDs may bind to one approved visual asset set.
5. **RepDB V1 scope is 34 approval candidates plus one explicit fallback**, with zero extra variants in R08-0. Actual production coverage may be lower if visual review rejects candidates.
6. **The current CSV is CANDIDATE only.** A pinned-image contact sheet, fresh Terra Max review, and named human approval are mandatory before production mapping.
7. **Static start/finish or main art is a movement illustration, not an exact pause/tempo demonstration.** IndiFit cues and prescriptions remain technique authority.
8. **The four-tier fallback is approved:** exact approved local illustration → canonical muscle visual → equipment/movement semantic icon → neutral fallback. No similar-image or fuzzy runtime fallback is allowed.
9. **Every external asset is pinned and reproducible:** URL, immutable commit/tag, acquisition date, license/version, exact external ID/path, local path, SHA-256, attribution, modification, and approval state in source control.
10. **RepDB is permitted only within its recorded in-app license boundary.** Preserve visible attribution, no-dataset-redistribution, no-generative-derivation, and no-premium-preview rules; resolve public-repository asset distribution before vendoring.
11. **R08-0 changes no B02 taxonomy data.** Exercise Library uses one canonical ordered-display-muscle resolver; B02 reviewed mappings remain the sole muscle-allocation arithmetic authority.
12. **MuscleMap is the primary geometry candidate**, pinned under MIT and ported locally through an explicit IndiFit taxonomy adapter. Anatome and react-native-body-highlighter are QA references only.
13. **Anatome is corrected to Apache-2.0/self-hostable but remains REFERENCE / QA ONLY.** Its unverified proxied exercise imagery is prohibited.
14. **The muscle renderer lands as a foundation only.** R08C owns Training/Exercise Detail integration, R08B optionally owns player integration, and R08F owns Progress heatmaps.
15. **Wakelock runtime integration belongs to R08B.** R08-0 records the contract and verifies readiness; R08B implements a single session-wide owner.
16. **`IndiFitIcons` is minimal and forward-only.** R08B–R08G migrate per screen; R08H handles leftovers. No app-wide R08-0 icon rewrite.
17. **No new chart library is approved.** `fl_chart` and Flutter painters remain the default until a concrete downstream acceptance criterion proves a gap.
18. **Flash performance numbers are not release facts.** Exact vendored bytes, release package delta, decode/paint timing, memory, and scroll frame metrics are mandatory before R08RC.
19. **openGym is concept-only.** Existing B01/B02 authority governs prefill, compact logging, rest, groups, effort, modalities, and scheduling; e1RM/calorie/PR/import scope remains rejected or deferred.
20. **Rollback remains data-safe:** all R08-0 runtime additions must be removable/disableable back to current B05 text/neutral fallbacks without schema rollback or canonical exercise mutation.
