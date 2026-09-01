# C0A Deterministic Test Harness Baseline

- Status: Complete; C0A exit criteria satisfied
- Date: 2026-09-01
- Branch: `codex/post-v1-c0a-test-harness`
- Frozen V1 starting branch: `ux/r07f-product-feel`
- Structural baseline: `aaa8032`
- Parent program: [`../POST_V1_CLEANUP_PROGRAM.md`](../POST_V1_CLEANUP_PROGRAM.md)

## Purpose

C0A makes failures attributable before retired-code removal or presentation
extraction begins. It standardizes ownership of test databases and process-local
preferences without globally hiding Drift warnings or changing production data
contracts.

The first slice was intentionally small. Subsequent focused migrations now
cover versioned backups, repository fixtures, binding initialization,
high-volume widget fixtures, and retained food-flow command boundaries.

## Reproduced baseline

The pre-change default parallel suite passed from a clean process:

- 2,113 tests passed in about 6 minutes 11 seconds;
- the previously reported order-sensitive failure did not reproduce;
- the run emitted repeated Drift multiple-`AppDatabase`, uninitialized binding,
  missing-plugin, and expected platform-fallback output;
- two files had obvious suite-lifetime database ownership with no matching
  close: `r08c10_remove_travel_mode_test.dart` and
  `ux_r04_training_test.dart`.

The release repository already had a serial CI lane:
`flutter test -j 1 --coverage`. C0A retains that as the gating lane while the
parallel-noise inventory is migrated and classified.

## Foundation implemented

`test/support/indifit_test_harness.dart` now provides:

- idempotent Flutter test-binding initialization;
- replacement—not merging—of mock `SharedPreferences` values;
- `TestDatabaseScope`, which owns and closes all in-memory databases created by
  one test;
- narrowly scoped suppression of Drift's multiple-instance warning only when a
  single test explicitly opens its second or later independent executor;
- automatic per-test scope registration through `addTearDown`.

The warning remains enabled for a first database opened while another scope is
still live. Leaks therefore remain visible instead of being hidden globally.

## First migrated slice

- `b02_execution_compatibility_read_repository_test.dart` uses the registered
  per-test database scope.
- `b05_backup_v10_test.dart` explicitly owns source/target database pairs in one
  scope; its legitimate dual-database cases no longer emit Drift noise.
- `ux_r04_training_test.dart` creates databases only for its two consumers and
  closes them after their widget trees unmount.
- `r08c10_remove_travel_mode_test.dart` no longer shares databases across the
  suite. Presentation-only coverage uses a fake action gateway, route-only
  coverage avoids booting unrelated data consumers, and database-backed widget
  coverage unmounts before closing its scope.
- `appRouterProvider` now disposes its `GoRouter` with the owning Riverpod
  container. Tests that read that provider follow the same single-owner rule.

No schema, backup format, preference key, route path, redirect, copy, or visual
contract changed.

## Versioned backup migration slice

The next C0A batch migrated Backup v6–v9 and the nutrition-constraint backup
fixture to the same ownership rules:

- legitimate source/target pairs are created in one explicit scope;
- historical-schema database factories are opened and owned through
  `TestDatabaseScope.open`;
- stage-aware rollback tests own every target executor created in their loop;
- migrated preference fixtures use replacement seeding through the shared
  helper;
- historical codecs, fixture payloads, restore stages, transaction failures,
  and semantic-equality assertions remain unchanged.

The focused backup slice passed in declared and shuffled order without a Drift
warning.

## Repository and binding isolation slice

A third focused batch migrated four repository/integration suites:

- `r08a2_today_training_invalidation_test.dart` now initializes database
  seeders through the shared scope, eliminating the ServicesBinding failures
  attributed to that suite;
- `b04_goal_coaching_preference_test.dart` explicitly owns its closed,
  file-backed restart, and restore databases;
- `b03_legacy_nutrition_adapter_test.dart` owns its legacy restore target in the
  same test scope;
- `r08b234_execution_integration_test.dart` no longer constructs an unrelated
  production database from its player widgets. Exercise-context presentation
  is isolated through the corresponding provider, and the widget tree unmounts
  before its test database closes.

The four-suite slice passed 37 tests in declared and shuffled order without a
Drift or ServicesBinding warning.

## High-volume widget-fixture slice

A fourth batch traced the four suites with the highest remaining warning
volume instead of suppressing their output:

- Quick Workout presentation tests now override the unrelated exercise-context
  read boundary and await their owned database shutdown;
- the AI-to-manual-food-search fallback test no longer creates a database it
  does not exercise, using empty food-search read boundaries instead;
- the R07D fast-add test now sends both taps before the busy-state rebuild, so
  the second tap genuinely exercises duplicate-command protection instead of
  landing on the underlying row and starting a hidden quantity flow;
- R07D and R08D.3 diary/recent-food widget fixtures were classified as retained
  lifecycle work for a dedicated follow-up. Their warnings remained visible in
  this batch rather than being hidden with a timeout or global Drift setting.

The four-suite slice passed 42 tests in declared and shuffled order. It reduced
that slice from 20 Drift warning blocks to 9; the remaining 9 belong to the two
classified subscription-lifecycle cases above.

## Remaining binding-initialization slice

The fifth batch traced all 20 uninitialized-binding matches in the current full
serial log to three suites:

- `health_service_test.dart` now replaces preferences through the shared
  harness, so disabled Health writes fail closed without reaching a platform
  channel;
- `food_repository_test.dart` and `b02_warmup_rest_services_test.dart` initialize
  the Flutter services binding before asset-backed database setup;
- FoodRepository search assertions identify the exact custom row inserted by
  the test instead of depending on asset seeding having failed and returned a
  one-row catalogue.

The three-suite slice passed 19 tests in declared and shuffled order with no
binding, missing-plugin/channel-error, or Drift warning match.

## Golden-state determinism

The final serial gate exposed that the golden named `calendar loading dark`
was racing a live calendar database stream. Depending on host timing, it could
capture loading, loaded, or failure presentation. The golden now overrides the
calendar controller with a fixed loading-state notifier, and only that
mislabeled baseline image was refreshed. No production widget, copy, route, or
theme value changed. The pinned render was byte-stable across repeated runs,
and the complete UX-W06 certification file passed afterward.

## Food-flow lifecycle and command-boundary slice

The sixth batch removed the remaining nine warnings in R07D and R08D.3 without
changing production behavior or suppressing Drift diagnostics:

- presentation fixtures materialize canonical food options and diary read
  models before mounting, then close the database they no longer exercise;
- command-focused widget tests use recording coordinators and assert exact
  quantity, meal, date, and single-finalize behavior, while canonical
  repository tests continue to own persistence verification;
- quantity dialogs use a no-transformation coordinator so a closed database is
  never consulted for unrelated raw/cooked suggestions;
- the large-text diary golden now pins its intended loading read explicitly,
  preserving the existing image instead of depending on incidental database
  timing;
- fixture shutdown is idempotent, and every widget tree is still unmounted at
  teardown.

The combined slice passed all 17 tests in declared and shuffled order with no
Drift, binding, missing-plugin, or channel-error match.

## Canonical B03 source/restore ownership slice

The seventh batch migrated the intentional source/restore pairs in the
consumption-snapshot and raw/cooked-transformation suites:

- each test owns its primary database through `TestDatabaseScope`;
- restore and validation targets are opened by that same scope;
- manual target `try/finally` and separate teardown ownership were removed;
- snapshot graphs, transformation provenance, rollback checks, and Backup v8
  semantic assertions remain unchanged.

The two files passed all 34 tests in declared and shuffled order with no Drift,
binding, missing-plugin, or channel-error match, removing four focused warning
blocks.

The same scoped source/restore ownership was then extended to six further B03
suites covering estimate provenance, legacy corrections, recipe versions,
vessel calibration, history reproducibility, and canonical time context. Their
43 tests passed in declared and shuffled order with no harness-noise match,
removing six more focused warning blocks without changing Backup v8 payload or
restore semantics. The following full serial gate confirmed the two B03 slices
removed all ten expected repository-wide warning blocks.

## Remaining database-ownership and provider-boundary slice

The ninth batch addressed every source in the 18-warning full-suite baseline:

- five intentional secondary executors now share their test's scoped ownership;
- the Phase 1 restore target is no longer manually owned outside its fixture;
- constraint, hydration, Today, recipe, and workout presentation tests override
  the exact provider boundary they consume instead of constructing production
  databases;
- notification presentation tests no longer create a database they never use;
- R08D.5 awaits fixture shutdown after widget unmount, while its pure meal
  presentation test no longer creates a database;
- hydration preference fallback is tested explicitly without a canonical
  database, and database-backed hydration remains covered separately;
- recipe ingredient labels are supplied by immediate catalog fakes after their
  canonical options are materialized, so async widget reads cannot open an
  unrelated production catalogue;
- Riverpod containers and workout player trees are explicitly disposed or
  unmounted before their fixture databases close.

The combined 15-file audit passed 141 tests in shuffled order with no Drift,
binding, missing-plugin/channel-error, or closed-database match. The following
full serial gate confirmed that all 18 remaining Drift warning blocks were
removed repository-wide.

## Profile lifetime and goal-history regression follow-up

The first zero-Drift full gate exposed four asynchronous profile loads that
outlived their fixture databases. The Phase 1 notifier now awaits its initial
load, and Phase 3 creates a database-backed notifier only in the test that
actually exercises it. The deliberate failed-write test completes its initial
load before closing the injected database, leaving only the expected write
failure in its log.

That focused audit also revealed a production reload defect:
`ensureCompatibilityImport` required exactly one existing goal-history row,
although a valid user can have multiple versioned goals. The repository now
reads the original version deterministically and never appends another
compatibility version. A regression assertion covers the multi-version retry.

The shuffled 17-test follow-up passed with seed `20260911`, with zero Drift,
fixture-lifetime, or duplicate-goal errors. The final full serial gate passed
all 2,115 tests with the same zero-warning ownership result.

## Progress presentation platform-boundary slice

The platform-noise inventory attributed 42 of 56 raw matches to two Progress
presentation suites. Preview-backed `ProgressScreen` fixtures were implicitly
constructing the production profile provider, which in turn attempted to open
the file-backed application database through `path_provider`.

Both suites now override only `userProfileProvider` with its database-free
notifier. The production snapshot refresh test retains its real in-memory
database and repository wiring. The combined 42-test suite passed in shuffled
order with seed `20260912`, with zero platform, Drift, or test-error matches.
## Final platform and global-state isolation

The remaining platform output was removed at its owning boundaries:

- workout fixtures use a shared recording/no-op wake-lock driver instead of
  falling through to `wakelock_plus`;
- notification timezone tests inject a deterministic IANA timezone reader
  through initialization and rescheduling;
- dashboard controller unit tests disable unrelated eager production loading;
- Progress and nutrition-target presentation fixtures override the unrelated
  profile provider rather than opening a file-backed application database.

The completion shuffle also found and fixed three order dependencies: a
runtime Material splash shader in an interaction-only test, an uninitialized
SharedPreferences mock in nutrition targets, and semantics/lazy-scroll
assumptions in Settings. A final `ux_w04` database leak was migrated to the
shared database scope with widget unmount ordered before shutdown.

Direct `SharedPreferences.setMockInitialValues` calls that remain are explicit
per-test or `setUp` replacements; none relies on inherited state. The full
shuffle is the repository-wide proof of that classification.

## Lane decision

Both serial and default parallel execution are supported. The serial lane
remains the conservative release gate; the parallel lane is a supported fast
diagnostic lane. The formerly reported parallel-only failure did not reproduce
after ownership cleanup, and the final parallel run passed with zero Drift,
binding, platform-channel, or test-error matches.

## Verification

| Check | Result |
|---|---|
| Focused migrated slice | 32 passed |
| Focused shuffled slice | 32 passed with seed `20260830` |
| Router/product-wiring regression slice | 9 passed |
| Full serial Flutter suite | 2,115 passed in about 8 minutes 16 seconds |
| Backup v6–v9 focused slice | 35 passed |
| Backup v6–v9 shuffled slice | 35 passed with seed `20260831` |
| Full serial suite after backup migration | 2,115 passed in about 9 minutes 23 seconds |
| Repository/binding focused slice | 37 passed |
| Repository/binding shuffled slice | 37 passed with seed `20260901` |
| High-volume widget-fixture slice | 42 passed |
| High-volume shuffled slice | 42 passed with seed `20260902` |
| Pre-binding-slice full deterministic serial suite | 2,115 passed in 10 minutes 33 seconds |
| Binding-initialization focused slice | 19 passed |
| Binding-initialization shuffled slice | 19 passed with seed `20260903` |
| UX-W06 visual certification file | Passed after pinning calendar loading state |
| Pre-food-flow full deterministic serial suite | 2,115 passed in 27 minutes 29 seconds |
| Food-flow lifecycle slice | 17 passed |
| Food-flow lifecycle shuffled slice | 17 passed with seed `20260904` |
| Post-food-flow full deterministic serial suite | 2,115 passed in 12 minutes 4 seconds |
| Canonical B03 source/restore slice | 34 passed |
| Canonical B03 source/restore shuffled slice | 34 passed with seed `20260905` |
| Extended B03 round-trip slice | 43 passed |
| Extended B03 round-trip shuffled slice | 43 passed with seed `20260906` |
| Pre-final-warning full deterministic serial suite | 2,115 passed in 12 minutes 16 seconds |
| Secondary-executor ownership slice | 43 passed |
| Secondary-executor shuffled slice | 43 passed with seed `20260907` |
| Constraint/hydration provider-boundary slice | 19 passed |
| Constraint/hydration shuffled slice | 19 passed with seed `20260908` |
| UI database-boundary shuffled slice | 29 passed with seed `20260909` |
| Combined remaining-warning shuffled audit | 141 passed with seed `20260910` |
| First zero-Drift full deterministic serial suite | 2,115 passed in 8 minutes 12 seconds |
| Profile lifetime/goal-history shuffled follow-up | 17 passed with seed `20260911` |
| Final current full deterministic serial suite | 2,115 passed in 8 minutes 3 seconds |
| Progress provider-boundary shuffled slice | 42 passed with seed `20260912` |
| Wake-lock provider-boundary shuffled slice | 68 passed with seed `20260913` |
| Timezone injection shuffled slice | 12 passed with seed `20260914` |
| Dashboard controller shuffled slice | 4 passed with seed `20260915` |
| Final clean-process serial suite | 2,116 passed in 7 minutes 15 seconds |
| Final whole-suite shuffled serial gate | 2,116 passed in 8 minutes 17 seconds with seed `20260916` |
| Final default parallel lane | 2,116 passed in 3 minutes 32 seconds |
| Backend suite | 12 passed, 15 subtests passed |
| Static analysis | Zero issues |
| Formatting/diff whitespace | Clean |

The harness now has three characterization tests. Together with the earlier
two additions, this accounts for the increase from 2,113 to 2,116 full-suite
tests.

## Remaining noise inventory

The initial full serial log intentionally exposed unmigrated harness noise:

- 77 Drift multiple-database warning blocks;
- 34 log matches for the uninitialized-binding message;
- 56 log matches for missing-plugin/channel-error messages.

After the versioned backup migration, the same counts were:

- 55 Drift multiple-database warning blocks, down by 22;
- 34 uninitialized-binding log matches, unchanged;
- 56 missing-plugin/channel-error matches, unchanged.

The full serial milestone before the fifth focused slice measured:

- 37 Drift multiple-database warning blocks, down 40 from the initial 77 and
  down 18 from the previous full milestone;
- 20 uninitialized-binding log matches, down 14 from 34;
- 56 missing-plugin/channel-error matches, unchanged.

The full serial gate before the food-flow lifecycle slice measured:

- 37 Drift multiple-database warning blocks;
- 0 uninitialized-binding matches;
- 56 missing-plugin/channel-error matches.

This confirms the fifth slice eliminated the final 20 binding matches without
moving them into platform-channel noise.

The post-food-flow full serial gate measured:

- 28 Drift multiple-database warning blocks, down 9 from 37;
- 0 uninitialized-binding matches;
- 56 missing-plugin/channel-error matches.

This confirms the focused food-flow follow-up eliminated all 9 Drift blocks
previously attributed to R07D and R08D.3 without moving them into another noise
category.

The full serial gate before the ninth migration slice measured:

- 18 Drift multiple-database warning blocks, down 10 from 28 and 59 from the
  initial 77;
- 0 uninitialized-binding matches;
- 56 missing-plugin/channel-error matches.

This confirms the canonical B03 source/restore slices removed their ten
intentional multi-database warning blocks without changing the other classified
noise categories.

The pre-platform-cleanup full serial gate measured:

- 0 Drift multiple-database warning blocks, down 18 from the prior milestone
  and all 77 from the initial baseline;
- 0 uninitialized-binding matches;
- 56 missing-plugin/channel-error matches, unchanged;
- 0 unexpected closed-database matches. The two raw phrase matches are the
  warning and detail lines from one deliberate failed-write assertion;
- 0 duplicate-goal-history errors.

The final serial, shuffled-serial, and parallel gates each measured:

- 0 Drift multiple-database warning blocks;
- 0 uninitialized-binding matches;
- 0 missing-plugin/channel-error matches;
- 0 unexpected closed-database failures;
- 0 test errors.

The suite retains deliberate failure-injection diagnostics, including a closed
database write and wake-lock driver failures. Those messages are owned by tests
that assert fail-closed behavior and are not harness leaks.

## Next gate

C0A is complete. Proceed to C0B contract freeze and fragile-flow
characterization. C1 removal and C2 presentation extraction remain blocked
until C0B satisfies its own exit criteria.
