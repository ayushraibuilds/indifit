# C1A Retired-Surface Reachability and Ownership Inventory

- Status: Complete (refreshed after C1B-01…C1B-10 and the connected track; see Refresh below)
- Date: 2026-09-01 (re-baselined 2026-09-03 after V1 RC integration; refreshed 2026-09-04 at `4b41237`)
- Baseline commit: `ce599dd`
- Refresh baseline commit: `4b41237`
- Parent program: [`../POST_V1_CLEANUP_PROGRAM.md`](../POST_V1_CLEANUP_PROGRAM.md)
- C0B contract gate: [`C0B_CONTRACT_BASELINE.md`](C0B_CONTRACT_BASELINE.md)

## Result

The current tree contains 353 non-generated production Dart files. Resolving
static `import`, `export`, and `part` edges from `lib/main.dart` reaches 315;
38 files containing 14,642 lines are outside that graph.

The earlier audit reported 37 files/about 14.5k lines. The intermediate count
added the two-line `onboarding_wizard_screen.dart` compatibility re-export. The
integrated V1 RC merge (`ce599dd`) additionally introduced the reachable
`lib/data/repositories/offline_starter_plan_catalog.dart` (472 lines), bringing
total non-generated production Dart files from 352 to 353 and reachable files
from 314 to 315. The 38 evidence-confirmed retired files and their line counts
remain completely unchanged and outside the production graph.

| Classification | Files | Lines | C1B disposition |
|---|---:|---:|---|
| Test fixture/support to relocate | 4 | 3,629 | Move under `test/` and update test imports |
| Developer tool to relocate | 1 | 267 | Move under `tool/src/`; retain its tests |
| Compatibility-required/dormant | 2 | 888 | Retain until a dedicated compatibility decision |
| Evidence-confirmed retired | 31 | 9,858 | Remove only through bounded C1B batches |
| **Total** | **38** | **14,642** | No deletion is authorized by C1A itself |

No candidate is classified as production-reachable. That statement is limited
to the current baseline and the checks below; it is not a permanent guarantee.

## Evidence method

The audit:

1. excluded generated `*.g.dart` and `*.freezed.dart` files;
2. resolved relative and `package:indifit/` import, export, and part edges;
3. enumerated direct consumers under `lib/`, `test/`, `integration_test/`, and
   `tool/`;
4. checked GoRouter paths, local `MaterialPageRoute` construction,
   notification destinations, and the C0B navigation contract;
5. searched Android, iOS, macOS, Linux, Windows, web, workflow, asset, and
   package configuration for candidate file references;
6. checked database, migration, backup, restore, fixture, and developer-tool
   roles before assigning a disposition.

Static reachability cannot prove the absence of arbitrary string/reflection or
future consumers. The manual registry/platform checks close the known dynamic
entry points in this repository. Every C1B batch must rerun those checks.

## Classification ledger

“Test-only” means the listed production file is imported by tests but not by
the production graph. “Nested retired” means its only `lib/` consumer is also
in this ledger.

### Test fixture/support to relocate

| File | Lines | Direct evidence | Classification and action |
|---|---:|---|---|
| `lib/core/fixtures/b03_nutrition_fixture_matrix.dart` | 1,813 | Two B03 fixture tests; no production consumer | Test fixture. Move to `test/fixtures/` without changing fixture meaning. Its referenced food assets remain production-used independently. |
| `lib/core/fixtures/b04_current_food_fixture_matrix.dart` | 99 | One B04 guidance test only | Test fixture. Move to `test/fixtures/`. |
| `lib/core/fixtures/b04_policy_gate_fixture.dart` | 1,430 | Two B04 safety/policy tests only | Test fixture. Move to `test/fixtures/`; preserve policy assertions. |
| `lib/features/media/indifit_muscle_map_showcase.dart` | 287 | `indifit_muscle_map_test.dart` only | Test showcase. Move beside its test fixtures; production muscle-map components remain separate and reachable. |

### Developer tool to relocate

| File | Lines | Direct evidence | Classification and action |
|---|---:|---|---|
| `lib/features/media/r08_repdb_asset_pipeline.dart` | 267 | Imported by `tool/acquire_r08_repdb_assets.dart` and its focused test; no app consumer | Developer tooling. Move to `tool/src/` and update the tool/test imports. Keep generated RepDB assets and validation tools unchanged. |

### Compatibility-required or intentionally dormant

| File | Lines | Direct evidence | Classification and action |
|---|---:|---|---|
| `lib/core/legacy_quantity_adapter.dart` | 177 | Versioned no-write adapter; quantity contract test only | Compatibility-required pending a legacy-quantity decision. It preserves unresolved values rather than fabricating conversions. Do not delete or move until its historical contract is either adopted by a production migrator or explicitly retired. |
| `lib/features/workout_player/routine_display_screen.dart` | 711 | Three legacy-player/visual tests and the V1 product-truth source check | Intentionally retained legacy-player surface. The R07F decision explicitly deferred its sunset. Keep dormant until a dedicated route/usage/restore audit approves retirement. |

### Evidence-confirmed retired

| File | Lines | Direct evidence | C1B action |
|---|---:|---|---|
| `lib/core/utils/household_measures.dart` | 117 | One legacy data-quality test only; replaced by reachable typed household-measure authority | Remove with its obsolete test assertions. Do not touch the canonical nutrition household-measure domain. |
| `lib/core/utils/natural_meal_parser.dart` | 48 | Parser test only; no current Food entry point | Remove. Future text-to-meal work must use the reviewed connected candidate pipeline, not revive this heuristic. |
| `lib/core/widgets/confetti_overlay.dart` | 162 | Two retired delight tests only | Remove with retired-only tests. Achievements and future celebration work require their own approved surface. |
| `lib/core/widgets/failure_state_widget.dart` | 107 | One retired failure widget test only | Remove; current reachable surfaces own their failure presentation. |
| `lib/data/repositories/ai_routine_service.dart` | 482 | Nested retired Routine Wizard plus one privacy test | Remove with the retired routine-generation batch; preserve the offline/AI privacy invariant in product-truth tests. |
| `lib/data/repositories/meal_plan_service.dart` | 707 | Nested retired AI Meal Planner plus service/privacy tests | Remove with retired meal-planner code; keep the `/meal-planner` redirect contract. |
| `lib/data/repositories/weekly_report_service.dart` | 206 | Nested retired report screen plus report/privacy/hydration tests | Remove with retired weekly-report code; retain factual Progress redirect and hydration authority guards. |
| `lib/features/dashboard/widgets/adherence_card.dart` | 72 | One legacy dashboard widget test only | Remove in the legacy dashboard batch. |
| `lib/features/dashboard/widgets/calorie_ring_card.dart` | 254 | One legacy product-feel test only | Remove in the legacy dashboard batch. |
| `lib/features/dashboard/widgets/dashboard_header.dart` | 88 | Two legacy dashboard/AI-cleanup tests only | Remove in the legacy dashboard batch. |
| `lib/features/dashboard/widgets/dashboard_meal_section.dart` | 981 | Tests only; sole `lib/` consumer of the retired Thali and save-helper surfaces | Remove as the root of the legacy dashboard-food subtree after transferring any still-valid product assertions. |
| `lib/features/dashboard/widgets/quick_log_bottom_sheet.dart` | 91 | One legacy responsive test only | Remove in the legacy dashboard batch. |
| `lib/features/dashboard/widgets/streak_freeze_card.dart` | 116 | No consumers | Remove as a zero-consumer leaf. |
| `lib/features/dashboard/widgets/today_workout_card.dart` | 168 | One legacy responsive test only | Remove; Today’s reachable action surface owns current workout presentation. |
| `lib/features/dashboard/widgets/todays_activity_card.dart` | 176 | No consumers | Remove as a zero-consumer leaf. |
| `lib/features/dashboard/widgets/water_tracker_card.dart` | 168 | No consumers; hydration remains hidden without canonical authority | Remove rather than optimize or reconnect. |
| `lib/features/dashboard/widgets/weight_sparkline_card.dart` | 173 | One legacy responsive test only | Remove; current Today/Progress presentation is authoritative. |
| `lib/features/food_log/ai_meal_logger_screen.dart` | 1,077 | Four legacy UX/certification tests only; `/food/ai` redirects to `/food` | Remove with retired-only screen tests; retain the redirect and product-truth contract. |
| `lib/features/food_log/ai_meal_planner_screen.dart` | 647 | No direct consumer; imports retired meal-plan service | Remove with the meal-plan service; retain `/meal-planner` redirect. |
| `lib/features/food_log/save_logged_meal_as_reusable_meal_helper.dart` | 215 | Nested retired dashboard meal section plus one legacy Saved Meals test | Remove with the dashboard-food subtree after preserving current Saved Meals outcomes in canonical tests. |
| `lib/features/food_log/thali_builder_screen.dart` | 829 | Nested retired dashboard meal section plus one B03 screen test | Remove the unreachable screen only; do not remove canonical thali tables/controllers or backup compatibility. |
| `lib/features/nutrition/protein_distribution_screen.dart` | 405 | One B03 widget test only | Remove the unreachable presentation; retain any reachable factual nutrition read models. |
| `lib/features/onboarding/onboarding_wizard_screen.dart` | 2 | No consumers; re-exports retired Routine Wizard | Remove with the routine-wizard batch. |
| `lib/features/onboarding/routine_wizard_screen.dart` | 938 | Nested only through the unused re-export; `/routine-wizard` redirects to Plan Library | Remove with AI routine service; retain redirect compatibility. |
| `lib/features/progress/b02_progress_controller.dart` | 166 | Nested retired B02 widgets plus controller test | Remove old presentation controller; reachable repositories/read models remain shared authorities and are out of scope. |
| `lib/features/progress/b02_progress_widgets.dart` | 548 | One widget test only; imports retired B02 controller | Remove old B02 presentation bundle; current `progress_screen.dart` remains canonical. |
| `lib/features/progress/widgets/progress_bmi_health_card.dart` | 110 | No consumers | Remove as a zero-consumer presentation leaf. |
| `lib/features/reports/weekly_report_screen.dart` | 569 | One hydration-authority test only; `/weekly-report` redirects to Progress | Remove with weekly report service; preserve the redirect and factual Progress destination. |
| `lib/features/settings/nutrition_goals_sub_screen.dart` | 16 | No consumers; deprecated wrapper around reachable targets hub | Remove the unused wrapper only; retain `NutritionTargetsHubScreen`. |
| `lib/features/settings/water_settings_sub_screen.dart` | 21 | One legacy settings visual test; imports retired water section | Remove with hydration settings presentation. |
| `lib/features/settings/widgets/water_settings_section.dart` | 199 | Nested retired water settings screen only | Remove; hydration remains hidden until a separately approved canonical authority exists. |

## Non-Dart dependency and asset findings

- No candidate filename is referenced by Android, iOS, macOS, Linux, Windows,
  web, workflow, or package configuration.
- The only non-test Dart consumer outside `lib/` is the RepDB acquisition tool.
- `assets/generated/repdb/` remains referenced by production media registries,
  validation tools, tests, and `pubspec.yaml`; moving its acquisition runner
  does not authorize deleting the assets or manifest entry.
- B03 fixture files read food identity/catalogue assets that are independently
  used by the database and current catalogue code; fixture relocation does not
  authorize asset removal.
- `cupertino_icons`, `just_audio`, and `encrypt` have no Dart imports anywhere
  in the current tree. They are dependency-removal candidates, but C1A does not
  remove them. C1B must prove Android/iOS builds before changing `pubspec.yaml`.

## Ordered C1B packages

Each package is a separate commit and reruns static/dynamic reachability,
focused tests, the deterministic serial suite, analysis, and diff checks.

1. **C1B-01 — Test-support relocation:** move the four classified test
   fixtures/showcases and update imports without changing behavior.
2. **C1B-02 — RepDB tool relocation:** move the acquisition pipeline under
   `tool/src/`; keep its focused tests and asset contracts.
3. **C1B-03 — Zero-consumer leaves/wrappers:** remove streak freeze, today
   activity, water tracker, BMI card, and the nutrition-goals wrapper in one
   small evidence-confirmed batch.
4. **C1B-04 — Legacy generic presentation:** remove unused confetti and failure
   widgets and retire only their implementation-specific tests.
5. **C1B-05 — Legacy dashboard-food subtree:** remove old dashboard widgets,
   Thali screen, and save helper while preserving current Today, Food, Saved
   Meals, canonical thali, and backup tests.
6. **C1B-06 — Retired Food AI:** remove heuristic parser, AI logger/planner,
   and meal-plan service; retain redirect and offline/privacy contracts.
7. **C1B-07 — Retired routine AI:** remove routine wizard/export and AI routine
   service; retain Plan Library redirect and product-truth coverage.
8. **C1B-08 — Retired weekly report:** remove report screen/service while
   retaining factual Progress navigation and hydration guards.
9. **C1B-09 — Old Progress/nutrition presentation:** remove B02 presentation
   controller/widgets, protein distribution, and the obsolete household
   utility without touching reachable repositories or typed authorities.
10. **C1B-10 — Hydration presentation:** remove water settings screen/section
    and affected retired-only goldens while preserving the hidden-authority
    product decision.
11. **C1B-11 — Dependency proof:** evaluate the three no-import direct
    dependencies in a separate change with Android/iOS release builds.
12. **Deferred compatibility review:** do not delete the legacy quantity
    adapter or routine display until their dedicated decisions and evidence
    gates are complete.

The packages are intentionally narrower than the classification groups. A
failed or ambiguous batch stops without weakening the classifications or
expanding deletion scope.

## Verification

- Ledger validation — 38 unique existing files, 14,642 lines, no stale paths
  or line-count mismatches.
- Platform/configuration search — no candidate file references; RepDB tool is
  the only non-test consumer outside `lib/`.
- Full deterministic serial Flutter suite — 2,127/2,127 passed.
- `flutter analyze` — no issues found.
- `git diff --check` — clean.

## Refresh at `4b41237` (post C1B-01…C1B-10 + connected track)

Re-ran the §Evidence method steps 1–7 against the current tree (BFS over
static `import`/`export`/`part` edges from `lib/main.dart`, generated files
excluded, consumers enumerated under `lib/` and `test/` — there is no
`integration_test/` directory — plus router, notification, platform-config,
and database/backup/fixture role checks).

### Refresh result

The current tree contains **352** non-generated production Dart files.
Reachability from `lib/main.dart` covers **335**; **17** files are outside
that graph.

Disposition of the prior 38 ledger entries at this baseline:

| Prior classification | Files | Outcome |
|---|---:|---|
| Test fixture/support to relocate (4) | 4 | Relocated to `test/fixtures/` in C1B-01 (`1cb7caf`); imports rewired |
| Developer tool to relocate (1) | 1 | Relocated to `tool/src/` in C1B-02 (`8a7f28c`); tool + tests intact |
| Evidence-confirmed retired (31) | 31 | All removed across C1B-03…C1B-10 (`cd507fb`…`4b41237`); 7 retired-only test files deleted, 3 trimmed in place, 3 goldens removed |
| Compatibility-required/dormant (2) | 2 | Retained as ordered (see carried rows below) |
| **Remaining from prior ledger** | **2** | No further action authorized by this refresh |

(The 09-04 cleanup summary's "23 production files deleted" is an arithmetic
slip: its own per-package rows sum to 5+2+9+4+3+2+4+2 = **31**, which matches
`git diff --name-status` output. Likewise its C1B-04 "2 retired test files
removed" row actually describes surgical trims that preserved live coverage.)

### Currently unreachable (17 files)

| Classification | Files | Lines | Disposition |
|---|---:|---:|---|
| Intentionally dormant connected-track implementation | 15 | 3,113 | **Do not delete.** Gated behind `Disabled*` capability defaults and unmet product gates (per-mutation envelopes, v22 identity); covered by PV1 contract tests. Re-review only when a product gate clears |
| Compatibility-required/dormant (carried) | 2 | 888 | Retained until a dedicated compatibility decision (unchanged) |
| Evidence-confirmed retired | 0 | 0 | Nothing left from the prior ledger |
| **Total** | **17** | **4,001** | No deletion is authorized by this refresh |

### Intentionally dormant connected-track ledger

“Test-only” below means imported by PV1 contract tests but by nothing in the
reachable production graph. The services are constructed exclusively in tests;
production resolves the `Disabled*` drivers, which is the correct fail-closed
staging until each track's security/product gate passes — wiring them up
earlier (notably the plaintext sync relay) would be a privacy regression, not
progress.

| File | Lines | Direct evidence | Classification and action |
|---|---:|---|---|
| `lib/core/outbox/outbox_operation.dart` | 203 | PV1-NET-01/CLOUD/SYNC tests; no `lib/` consumer outside this ledger | Dormant domain contract. Do not delete; it is the outbox lifecycle authority exercised by `DriftOutboxRepository` and all dispatch paths. |
| `lib/core/outbox/outbox_repository.dart` | 209 | PV1-NET-01 tests; implemented by `DriftOutboxRepository` in-ledger | Dormant repository contract. Do not delete. |
| `lib/core/outbox/outbox_retry_policy.dart` | 113 | PV1-NET-01 tests | Dormant retry/backoff policy. Do not delete. |
| `lib/core/outbox/outbox.dart` | 26 | PV1 tests via barrel; provider default is the Drift implementation | Dormant composition root (`outboxRepositoryProvider`). Do not delete; future prod call sites consume this provider. |
| `lib/core/outbox/drift_outbox_repository.dart` | 253 | `test/pv1_v21_persistence_test.dart`; referenced only by `outbox.dart` in-ledger | Dormant durable spool (schema v21 `outbox_entries`). Do not delete. |
| `lib/core/sync/sync_mutation.dart` | — (reachable via `sync_capability`) | — | Not in this ledger; listed only to record that `HlcTimestamp`/`SyncMutation`/`SyncDomain` are shared kernel types, so capability→`core/sync` imports are core→core, not a layering inversion. |
| `lib/core/sync/sync_api_client.dart` | 179 | PV1-SYNC tests | Dormant relay client (in-memory fake for tests). Do not delete. |
| `lib/core/sync/sync_conflict_resolver.dart` | 139 | PV1-SYNC-01A tests; used by `SyncService` in-ledger | Dormant LWW/tombstone engine. Do not delete. |
| `lib/core/sync/sync_service.dart` | 515 | PV1-SYNC-01B tests only | Dormant sync engine behind `DisabledSyncCapability`. Do not delete or wire into production until the encryption decision and v22 identity land. |
| `lib/core/sync/sync_tombstone_store.dart` | 103 | `test/pv1_v21_persistence_test.dart`; used by `SyncService` in-ledger | Dormant tombstone journal (schema v21 `tombstone_entries`). Do not delete. |
| `lib/core/backup/cloud_backup_api_contract.dart` | 163 | PV1-CLOUD tests; used by service/client in-ledger | Dormant API contract. Do not delete. |
| `lib/core/backup/cloud_backup_api_client.dart` | 151 | PV1-CLOUD tests | Dormant relay client (in-memory fake for tests). Do not delete. |
| `lib/core/backup/cloud_backup_envelope_manager.dart` | 193 | PV1-CLOUD-01A tests | Dormant HKDF/AES-GCM envelope authority. Do not delete. |
| `lib/core/backup/cloud_backup_service.dart` | 389 | PV1-CLOUD-01B/01C tests only | Dormant backup engine behind `DisabledCloudBackupCapability`. Do not delete or wire into production until the KMS/account product gate passes. |
| `lib/core/catalog/food_catalog_service.dart` | 369 | PV1-CATALOG/V21 tests only | Dormant catalog engine behind `DisabledFoodCatalogCapability`. Do not delete. |
| `lib/core/catalog/remote_food_cache_store.dart` | 108 | `test/pv1_v21_persistence_test.dart`; used by `FoodCatalogService` in-ledger | Dormant Tier-1 cache journal (schema v21 `cached_remote_foods`, 14-day TTL). Do not delete. |

New retirement candidate found by this refresh (not in the prior ledger):

| File | Lines | Direct evidence | Classification and action |
|---|---:|---|---|
| `lib/core/capabilities/remote_catalogue_capability.dart` | 80 | Zero live callers; superseded by `FoodCatalogCapability` | **Removed** (`a3b050e`+); deleted file and deprecated `remoteCatalogueCapabilityProvider`; migrated `test/pv1_net01_offline_capability_test.dart` to canonical `DisabledFoodCatalogCapability`. |

Reachable-by-design notes (not ledger entries, recorded to prevent
re-auditing): `lib/data/database/tables/sync_tables.dart` is reachable via
`AppDatabase`; the v21 tables are device-local and excluded from backup
specs by allowlist. `lib/core/capabilities/analytics_capability.dart` is
reachable via the capabilities registry.

### Refresh verification

- Ledger validation — 17 unique existing files; per-file line counts above
  match the tree; prior-ledger outcomes (31 removed, 5 relocated, 2 retained)
  confirmed by `git diff --name-status`.
- Static reachability — BFS from `lib/main.dart` over import/export/part
  edges; zero reachable-`lib/` importers for any ledger file.
- Router/notification destinations — ledger files expose no routes,
  deep links, or notification payloads; the compatibility redirect table is
  untouched.
- Platform/configuration search — no `outbox_entries`/`tombstone_entries`/
  `cached_remote_foods` references outside Dart; no `integration_test/`
  directory exists.
- Full deterministic serial Flutter suite — 2,179 passed, 3 failed, all 3
  pre-existing on the clean base (`ux_r08g6_data_privacy_test` ×2,
  `r08g7_settings_danger_zone_deep_screen_test` ×1; the latter exercises the
  Data Management screen now hosting `CloudBackupCard`, so confirm its failure
  mode is unchanged when settings/backup is next touched).
- `flutter analyze` — no issues found.
- `git diff --check` — clean (docs-only change).
