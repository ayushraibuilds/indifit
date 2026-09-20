# IndiFit Post-V1 Incremental Cleanup Program

- Status: Active; V1 frozen, C0A, C0B, and C1A complete, C1B-01…C1B-11 complete (ENG-04A…04H); ENG-05 splits next
- Effective date: 2026-08-30
- Structural recount: `ce599dd` (integrated V1 RC)
- Portfolio plan: [`POST_V1_IMPLEMENTATION_PLAN.md`](POST_V1_IMPLEMENTATION_PLAN.md)
- Product roadmap: [`post-v1-roadmap.md`](../roadmap/post-v1-roadmap.md)

## 1. Position

IndiFit is a strong candidate for incremental cleanup, not a rewrite.

The existing domain integrity, migrations, backup compatibility, accessibility
primitives, offline behavior, stable identity, and regression coverage are
assets. The cleanup program exists to reduce change blast radius and coupling
while preserving those assets. Its targets are oversized files, ambiguous
ownership, retired surface, scattered persistence/platform access, global
composition bottlenecks, and a noisy test harness.

The program does not use reduced line count as its goal. Success means:

- deterministic tests and attributable failures;
- smaller behavior-preserving change sets;
- clearer feature and dependency ownership;
- fewer global/static dependencies;
- stable schema, preferences, backup, routing, and UI contracts;
- easier characterization and focused testing;
- measured—not assumed—performance improvement;
- faster and safer future feature work.

Splitting one 4,000-line file into twelve mutually tangled files is not a
successful cleanup.

## 2. Entry gate: close and freeze V1 first

No production cleanup begins until the current release candidate is closed.

The V1 Release Candidate was finalized with four real-device correctness fixes
(onboarding keyboard flow, offline starter plan library, food search ranking,
and transient feedback auto-dismissal) merged into the Post-V1 baseline at
`ce599dd`. Gate 0 is fully closed and verified.

Required entry sequence:

1. Run the final accepted automated suite on the post-review release HEAD.
2. Complete manual Android/iOS device acceptance.
3. Resolve or explicitly disposition every release blocker.
4. Record builds, schema, backup format, fixtures, goldens, and test results.
5. Create the approved release tag/baseline.
6. Start cleanup from that known-good commit on a dedicated cleanup branch.

V1.0.x correctness/reliability work stays separate. A cleanup commit must not
be used to finish the release candidate or opportunistically change product
behavior.

## 3. Audit snapshot and refresh rule

Structural values below were re-counted at `ce599dd`. Runtime/test outcomes are
from the supplied cleanup audit and must be rerun at the release tag. The
unreachable-surface inventory is a candidate set, not deletion authority.

| Area | Current evidence | C0 refresh requirement |
|---|---|---|
| Production Dart | 353 non-generated files, 185,347 lines | Recount with the same exclusions at the release tag |
| Generated Dart | 2 generated files, 91,844 lines, primarily Drift | Record generator/tool versions; never hand-edit generated output |
| Flutter tests | 264 files, 102,781 lines | Recount and freeze lane definitions |
| Static analysis | Cleanup audit reports zero issues | Rerun `flutter analyze` on release and cleanup baselines |
| Coverage | Existing LCOV report: 56.0% | Refresh after harness isolation; use risk coverage, not percentage alone |
| Flutter suite | Audit reports 2,086 passes plus one order-sensitive parallel failure that passes alone | Reproduce; make serial deterministic; support or explicitly reject parallel execution |
| Backend | Audit reports 12 tests and 15 subtests passing | Rerun and freeze endpoint contract coverage |
| Database | Drift schema v20; roughly 80 tables; extensive migrations/indexes | Freeze schema snapshot, migration fixtures, index inventory, and query behavior |
| Composition | 79 provider declarations in the central registry | Inventory identity, lifetime, overrides, and consumers before movement |
| Routing | 43 `GoRoute` declarations and 51 `MaterialPageRoute` references | Freeze paths, redirects, payloads, back behavior, callbacks, and deep links |
| Retired candidates | Audit identified 37 files/about 14.5k lines outside the `main.dart` import graph | Revalidate every candidate through the C1 evidence checklist |

Current presentation hotspots:

| File | Re-counted size | Cleanup concern |
|---|---:|---|
| `lib/features/food_log/food_search_screen.dart` | 4,034 | Search, results, selection, quantities, and command orchestration combined |
| `lib/features/progress/progress_screen.dart` | 2,880 | Many views/read states and chart interactions in one file |
| `lib/features/workout_player/b02_strength_player_screen.dart` | 2,553 | Execution cards, timer, actions, and transient interaction state combined |
| `lib/features/program_authoring/program_author_screen.dart` | 2,377 | Authoring panels, dialogs, validation, and commands combined |
| `lib/features/dashboard/today_daily_action_surface.dart` | 2,156 | Multiple daily modules and presentation states combined |
| `lib/core/di/providers.dart` | 1,110 | Central ownership and override bottleneck |
| `lib/data/database/app_database.dart` | 2,353 | Database lifecycle, migrations, indexes, and seeding combined |
| `lib/core/backup/backup_schema.dart` plus versioned codecs | More than 10k combined | Historical compatibility and validation have a large blast radius |
| `backend/main.py` | 654 | Configuration, security, provider client, schemas, routes, and fallbacks combined |

Counts describe risk concentration; they are not targets by themselves.

## 4. Non-negotiable invariants

Every cleanup package preserves:

- observable pixels, ordering, spacing, typography, colors, animations, copy,
  semantics, focus, text scaling, keys, callbacks, and interaction behavior;
- route paths, redirect rules, arguments/payload meaning, deep-link behavior,
  notification navigation, modal behavior, and back behavior;
- provider identity, lifetime, override behavior, invalidation, and disposal;
- preference key strings, defaults, migration/mirroring behavior, and backup
  participation;
- Drift schema version 20, table/column/index meaning, migration results, and
  transaction boundaries unless a separate approved feature changes them;
- backup v5–v10 accepted inputs, exported meaning, validation, failure
  atomicity, and restored database state;
- offline-first behavior, canonical authority, privacy boundaries, and
  accessibility;
- existing endpoint paths, request/response fields, status codes, error/fallback
  contracts, and rate-limiter semantics during backend extraction.

Do not combine file extraction with redesign, renaming, dependency upgrades,
schema changes, provider-lifetime changes, or feature work.

## 5. Ordered cleanup program

```text
V1 release tag
  ↓
C0A deterministic harness
C0B contracts and weak-flow characterization
  ↓
C1A retired-surface classification
C1B evidence-confirmed removal/relocation
  ↓
C2A Progress → C2B Today → C2C Workout → C2D Food → C2E Program Authoring
  ↓
C3A app/bootstrap → C3B providers → C3C preferences → C3D time → C3E routing
  ↓
C4A repository internals → C4B database internals → C4C backup consolidation
  ↓
C5 measured performance
  ↓
C6 backend modularization
  ↓
C7 dependency/platform upgrades
```

Only explicitly independent leaf packages may overlap. Shared hotspots have one
owner at a time.

## 6. C0 — Hard behavior and test gate

### C0A — Deterministic test harness

**Status:** Complete on 2026-09-01. Serial, whole-suite shuffled serial, and
default parallel lanes pass with attributable platform and database state.

This is the first cleanup implementation batch and a hard gate for C1 removal
or C2 extraction.

Implementation evidence and the remaining migration inventory are recorded in
[`post-v1/C0A_TEST_HARNESS_BASELINE.md`](post-v1/C0A_TEST_HARNESS_BASELINE.md).

Deliver:

- one documented test app/container builder;
- standard database construction, override, teardown, and leak detection;
- isolated `SharedPreferences` state per test;
- injected/fake civil date, clock, timezone, and lifecycle where relevant;
- standard fakes for notifications, Health, secure/platform storage, sharing,
  camera/file picker, connectivity/network, and other platform services;
- elimination or explicitly owned diagnosis of repeated multiple-`AppDatabase`
  warnings;
- repeat/shuffle evidence for historically order-sensitive groups;
- a reliable serial CI lane;
- a decision on the parallel lane: deterministic and supported, or documented
  as non-gating/unsupported with the reason and isolated known limitation.

Exit criteria:

- repeated clean-process serial runs pass;
- no test depends on state left by another test;
- failures identify the owning test/resource rather than only timing out;
- database, preference, clock, and platform state are closed/reset reliably;
- the reported parallel-only failure has a reproduced cause and disposition.

### C0B — Contract freeze and characterization

**Status:** Complete on 2026-09-01. Route, preference, schema v20, backup
v5-v10, fragile-flow, navigation, preference-ownership, and visual/state
contracts are recorded in
[`post-v1/C0B_CONTRACT_BASELINE.md`](post-v1/C0B_CONTRACT_BASELINE.md).
The consolidated contract/backup/fragile-flow suite passes 120/120 and the
focused visual/accessibility certification passes 37/37.

Capture machine-checkable inventories or tests for:

- route paths, redirect truth table, argument/payload meaning, notification/deep
  links, modal/local routes, and back behavior;
- every persisted preference key, default, writer, reader, mirror, restore, and
  delete/reset behavior;
- schema v20 table/column/constraint/index inventory and supported migrations;
- backup v5–v10 representative JSON, validation failures, exported semantics,
  and restored-state equivalence;
- important goldens, semantics, compact widths, large text, reduced motion,
  light/dark, loading, empty, error, retry, and offline states.

Add characterization where the audit found weak protection:

- Saved Meal editing;
- routine/plan editing;
- recipe editing;
- Data Management and destructive/recovery flows;
- dashboard/Today shell;
- notification settings and schedules.

Coverage percentage may rise, but C0B is complete when risky behavior is
characterized—not when an arbitrary global percentage is reached.

## 7. C1 — Retired-surface classification and removal

### C1A — Evidence inventory

**Status:** Complete on 2026-09-01. The current recount and all 38 candidate
classifications are recorded in
[`post-v1/C1A_RETIRED_SURFACE_INVENTORY.md`](post-v1/C1A_RETIRED_SURFACE_INVENTORY.md).
The inventory authorizes no deletion; C1B proceeds through its bounded,
evidence-gated packages.

Treat the 37 originally reported unreachable files—and the 38-file refreshed
set—as suspects. For each candidate record:

- production imports, exports, parts, generated references, and dynamic
  registries;
- GoRouter, `Navigator`, deep-link, notification callback, method-channel,
  background-entrypoint, string/key lookup, and platform build references;
- database migration, backup codec, restore compatibility, fixture, and
  developer-tool roles;
- tests that characterize current production behavior versus tests that exist
  solely to preserve the candidate;
- dependency/assets/plugins retained only by the candidate;
- classification, evidence, owner, action, and recovery implications.

Allowed classifications:

- production reachable;
- dormant and intentionally retained;
- compatibility required;
- test fixture to move under `test/`;
- developer tool to move under `tool/`;
- retired and removable.

Absence from the `main.dart` import graph is one signal, never sufficient proof.

Likely audit groups include retired AI screens, legacy dashboard cards, old
report/routine services, and fixture matrices. Revalidate rather than assuming
the group is dead.

### C1B — Small thematic removals and relocations

**Outcome (2026-09-04/05):** C1B-01…C1B-11 executed as separate commits —
31 retired production files removed, 5 fixtures/tools relocated, 3
dependencies pruned, candidate #39 (`remote_catalogue_capability`) retired;
2 compatibility files retained as ordered. Reachability re-pass recorded in
the C1A refresh section of
[`post-v1/C1A_RETIRED_SURFACE_INVENTORY.md`](post-v1/C1A_RETIRED_SURFACE_INVENTORY.md).

- Remove one coherent retired area per change set.
- Move fixtures/tools separately from deletion commits.
- Remove obsolete tests only after proving they cover no reachable contract.
- Re-audit dependencies with no production Dart imports, including
  `cupertino_icons`, `just_audio`, and `encrypt`; platform manifests, native
  registration, assets, build scripts, and release builds are part of the
  evidence.
- Refresh stale roadmap statements, generic package description, and Flutter
  template comments in documentation-only commits.

Every removal passes focused/full tests, route/callback/platform searches,
Android/iOS release builds where a dependency or platform surface changes, and
records exactly what became unrecoverable. Do not revive a retired surface as
part of deciding whether it is dead.

## 8. C2 — Mechanical presentation decomposition

Order:

1. **C2A Progress.** Extract chart/section widgets, immutable view data, and pure
   formatting/presentation helpers.
2. **C2B Today.** Extract daily modules and state renderers while preserving
   ordering, keys, skeletons, navigation, and animation/reduced-motion behavior.
3. **C2C Workout.** Extract player cards, timer presentation, set/group rows,
   and action sheets without moving execution authority or transient focus/edit
   state prematurely.
4. **C2D Food Search.** Extract landing, result list, filters/selection bar,
   quantity/review dialogs, and logging feedback/actions behind existing
   orchestration.
5. **C2E Program Authoring.** Extract panels, previews, validators' presentation,
   and dialogs while preserving version/mutation behavior.

First pass rules:

- extract private widgets, immutable presentation models, and pure helpers only;
- keep async commands, provider reads/listens, and lifecycle ownership in place;
- keep transient UI state—focus nodes, text controllers, touched chart points,
  expanded rows, scroll state—in the widget that owns the interaction;
- preserve widget keys, semantics, callback order, copy, layout, animation, and
  navigation exactly;
- use the C0 goldens/semantics/characterization suite as the acceptance oracle;
- settle extraction before separately proposing controller/orchestration moves.

Desired outcome is clearer ownership and bounded dependencies, not a target file
count or line count.

## 9. C3 — App composition in isolated subphases

Do not combine these subphases.

### C3A — App/bootstrap composition

- Introduce `lib/app/` for app construction, bootstrap sequencing, root shell,
  and composition only.
- Preserve pre-frame/post-frame behavior, error hooks, provider container,
  notification setup, backup scheduling, and lifecycle callbacks.
- Move the notification navigation callback out of `build()` only as a separate
  characterized lifecycle fix, not as incidental file movement.

### C3B — Feature-owned providers

**Status:** Complete. Decomposed `lib/core/di/providers.dart` (1,110 → 14 lines)
into 6 domain modules (`core_providers.dart`, `nutrition_providers.dart`,
`training_providers.dart`, `workout_player_providers.dart`,
`coaching_providers.dart`, `hydration_providers.dart`) while preserving
provider identities, lifetimes, and re-exporting through `providers.dart`.
Import-direction rule strictly enforced (zero domain imports of `providers.dart`).
Verified with 0 analyzer issues and all test suites passing.

- Inventory all 79 central providers with type, identity, lifetime, overrides,
  dependencies, invalidation, and consumers.
- Move the same provider objects into feature-owned modules; do not recreate
  them under new identities or alter auto-dispose/lifetime behavior.
- Compose exports/registries at the app boundary and migrate consumers in small
  feature batches.

### C3C — Preferences boundary and constants

- Inject one `SharedPreferences` access boundary.
- Centralize key constants and defaults without renaming stored key strings.
- Preserve DB/preference mirror, compensation, backup/restore, reset/delete,
  onboarding, notification, and compatibility semantics.

### C3D — Civil date and clock injection

- Inventory direct `DateTime.now()` and timezone assumptions in domain logic.
- Route domain time through the existing civil-date/clock services.
- Leave framework-required timestamps or purely transient animation time local
  when appropriate and document the boundary.
- Test midnight, timezone change, daylight-saving behavior where supported,
  historical dates, resume, and deterministic “now.”

### C3E — Routing cleanup and typed payloads

- Classify the 43 declared GoRouter routes and 51 `MaterialPageRoute` references
  as app destinations, local child tasks, dialogs/sheets, or legacy paths.
- Compose feature route lists in one root router.
- Keep true local/modal tasks local.
- Migrate actual destinations and dynamic payloads in small route families,
  preserving paths, redirects, restoration/back behavior, deep links,
  notification callbacks, and consumer failure states.
- Typed payloads are late because call-site ripple is large; do not use them as
  an excuse to rename paths or redesign navigation.

## 10. C4 — Persistence modularization with frozen schema

Schema version 20 remains unchanged throughout cleanup.

### C4A — Repository internals, one domain at a time

Preserve public repository façades and move internal query, mapping, validation,
and command collaborators in this order unless risk evidence changes it:

1. consumption/nutrition;
2. strength execution;
3. recipes;
4. calendar;
5. programs.

Add bounded feature read models gradually so presentation stops consuming raw
generated Drift rows. Do not change query meaning, transaction boundaries,
stream invalidation, ordering, null/unknown semantics, or error contracts.

### C4B — Database internals

- Extract connection/lifecycle setup, migration helpers, seeders, and index
  declarations from `AppDatabase` behind the same database API.
- Freeze generated schema artifacts and migration fixtures before movement.
- Prove fresh creation and every supported injected/on-disk migration boundary.
- Do not edit generated Drift files manually.

### C4C — Backup consolidation

- Keep every historical decoder immutable.
- Consolidate shared table specifications and validation primitives in small
  version-bounded changes.
- Compare exported JSON meaning and complete restored database state before and
  after each refactor, including malformed/newer input rejection and failure
  atomicity.

Hard commit boundary: repository decomposition, database/migration plumbing,
and backup/schema work never share a commit. Backup consolidation has its own
blast radius and review gate.

## 11. C5 — Evidence-based performance

Capture a reproducible profile/release benchmark baseline before optimization:

- cold launch and time to useful first frame;
- Today scrolling/rebuilds;
- food search and fast logging;
- workout set entry, timer, background/foreground transition, and completion;
- Progress query/chart/render behavior;
- backup export, encryption/file work, and restore.

Record device/OS, app mode/build, data fixture, warm/cold cache, run count,
measurement tool, and variability. Performance work needs a before/after result,
not an adjective.

Candidate changes require evidence:

- move notification navigation callback ownership only after lifecycle tests;
- inspect the hydration 15-second polling path for actual production reachability;
  if it belongs to retired hydration infrastructure, remove/retire it in C1
  rather than optimizing it;
- narrow broad database invalidation streams only after measuring query/rebuild
  behavior and preserving dependent tables;
- use Riverpod `select`/smaller consumers only where rebuild profiles justify it;
- bound/paginate history/search only with explicit ordering, empty, refresh,
  offline, and compatibility behavior;
- add indexes only with `EXPLAIN QUERY PLAN` or repeatable timing evidence and
  migration/write-cost review.

Do not reimplement already-fixed startup work. Reminder/backup work is post-frame
and onboarding redirects are synchronous; characterize them and preserve the
accepted behavior.

## 12. C6 — Backend modularization

**Status:** Complete. Decomposed `backend/main.py` (1,057 → 76 lines) into modular
packages (`backend/core/`, `backend/schemas/`, `backend/services/`, and
`backend/routers/`) with an application factory (`create_app()`), CORS
middleware, and full test backward-compatibility re-exports.
Rebinding tripwire enforced (state dicts mutated in-place only).
Verified with all 30 backend pytest tests passing in 0.88s.

Refactor `backend/main.py` while preserving every endpoint, request/response
field, status code, error, fallback, auth, privacy, and rate-limit contract.

Target bounded modules:

- configuration;
- Pydantic request/response/provider schemas;
- authentication and rate-limiter interface;
- Gemini/provider client;
- feature routers;
- fallback data/logic;
- application factory and lifespan resources.

Delivery order:

1. Freeze endpoint contract tests and import/launch behavior.
2. Add an application factory for isolated tests.
3. Extract typed schemas and validate provider responses before returning them.
4. Add a lifespan-managed reusable `httpx.AsyncClient`.
5. Extract auth/rate limiting without changing policy.
6. Extract provider client, routers, and fallback data in endpoint families.
7. Remove unused response-cache constants; implement real caching only as a
   separate behavior/performance project.

Distributed rate limiting is a deployment/design project, not cleanup.

## 13. C7 — Dependency and platform maintenance

Begin only after structural cleanup stabilizes. Never combine major Flutter,
Riverpod, Drift, GoRouter, or platform-plugin upgrades with C2–C6 refactors.

Use one dependency family per batch and require:

- dependency-resolution diff and changelog/migration review;
- format/analyzer and deterministic full Flutter suite;
- generated Drift diff review and code-generation idempotency;
- backend tests where relevant;
- Android release build and iOS no-codesign release build;
- focused notification, Health, camera, backup, storage, permissions, lifecycle,
  and navigation checks for affected plugins;
- manual device checks for platform behavior.

## 14. Acceptance policy

### Every cleanup change

- No intentional product/UI/semantics/navigation/interaction change.
- No schema/version or persisted-key change.
- No backup-format meaning change; representative output/restore remains
  equivalent.
- Format and `git diff --check` pass.
- `flutter analyze` remains clean.
- Focused tests pass, then the deterministic full serial suite.
- Relevant goldens/semantics remain unchanged.
- Backend tests pass when the backend or shared contract is affected.
- Generated files are produced only through the pinned generator and reviewed.
- The change contains no dependency upgrade, unrelated rename, or feature work.

### Major phase or platform milestone

- Android release build.
- iOS no-codesign release build.
- Manual light/dark, compact width, large text, and relevant real-device checks.
- Updated route/preference/schema/backup inventories when their owning phase
  moves structure.
- Before/after benchmark evidence for C5 claims.
- Fresh focused review of the phase's highest-risk boundary.

## 15. Branch, commit, and review discipline

- Branch from the accepted V1 tag using the repository's `codex/` branch prefix
  unless the product owner chooses another cleanup convention.
- One owner at a time for provider identity, router, database/migrations, backup,
  workout execution, nutrition authority, and app bootstrap.
- Keep classification, relocation, deletion, mechanical extraction, controller
  movement, persistence plumbing, behavior fixes, and dependency upgrades in
  separate commits.
- A discovered behavior bug becomes a separately scoped fix with its own tests;
  do not hide it inside a mechanical cleanup diff.
- Record baseline failures separately from new regressions and never normalize a
  flaky failure as expected without an owner and disposition.

## 16. Recommended first batch

The first implementation batch is:

1. **C0A:** deterministic database/preferences/platform test harness and serial
   CI evidence.
2. **C0B:** route/preference/schema/index/backup/UI contract freeze plus the six
   weak-flow characterization groups.
3. **C1A:** classification ledger for the refreshed 38 retired-surface
   suspects.

C1B deletion and C2 extraction do not start until the C0 hard gate passes. This
batch offers the highest risk reduction and makes every later cleanup package
safer without intentionally changing reachable behavior.
