# B04 — Verification Plan

Status: verification plan only. No B04 implementation or verification run has
started from `batch/b04-planning`.

## Verification gate

B04 implementation may be released only from a branch whose parent contains
accepted B01, B02 and B03. The planning branch is schema v16/backup v7 and is
not a verification baseline. The expected implementation baseline after B03
integration is schema v17/backup v8; B04’s proposed durable change is v18/v9.

Required reviewers:

- **Sol High:** target policy, readiness, recommendation determinism,
  historical lineage, schema/backup, safety, privacy/AI and final release.
- **Terra High:** production controllers/providers, navigation, UI ownership,
  copy, compact layouts, large text and accessibility.
- **Product Owner:** adaptive opt-in, age, trend/cadence, bounds and any N8
  context decision.

Any unresolved dependency, safety, privacy, historical-immutability,
unknown/range, offline or platform/accessibility failure is a release blocker.
Only reproducible CI/documentation follow-up may be non-blocking, with an
owner and explicit Sol acceptance.

## Automated verification matrix

| Gate | Required evidence | Pass condition |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test`; `git diff --check` | No formatting drift or whitespace errors. |
| Static analysis | `flutter analyze` | No new analyzer errors, warnings or ownership violations. |
| Focused tests | B04 contract, policy, migration, backup, engine, safety, lineage and UI tests | All focused tests pass with deterministic fixtures. |
| Full tests | `flutter test` and relevant backend test command if an adapter remains | Full suite passes; no B01–B03 regression. |
| Generated sources | Project-approved `build_runner`/code generation command where applicable | Generated artifacts are reproducible and clean. |
| Fresh schema | Create a new database at v18 | All tables, indexes, foreign keys and default states are correct. |
| Direct migration | Upgrade v17→v18 on a populated B03 database | Data and immutable B03 history are unchanged; B04 rows start empty. |
| Chained migration | Upgrade supported older versions through v18 | Every supported path is deterministic and preserves ownership/lineage. |
| Migration failure | Inject failure at each migration step | Transaction rolls back with byte/row-level pre-state preserved. |
| Schema idempotency | Open/migrate the same database repeatedly | No duplicate columns, indexes, rows or version drift. |
| Backup v9 round-trip | Export/import all B04 durable entities and graph edges | IDs, timestamps, effective dates, ranges, provenance and supersession match. |
| Backup compatibility | Import v5, v6, v7 and v8 fixtures | Legacy data restores; missing B04 graph is treated as empty. |
| Backup invalid graph | Duplicate IDs, dangling evidence, invalid supersession, unknown future records | Restore fails closed and leaves the destination unchanged. |
| Backup idempotency | Repeat restore/export and compare canonical payloads | No duplicated durable entities or feedback events. |
| Goal history | User-set, calculated proposal, accepted adaptive proposal, override and reset | Each accepted change is a new version with correct effective date; old reads do not change. |
| Readiness completeness | Complete, missing, denied, stale and conflicting observations | Completeness/status is explicit; missing is never zero; adaptation is suppressed when required. |
| Target determinism | Fixed fixtures for profile, trends, workload, readiness and policy versions | Same inputs/rule version produce the same result and evidence. |
| Target bounds | Lower/upper policy edges and missing metrics | No unsafe value or silent legacy default; policy-unavailable is explicit when gate is open. |
| Unknown propagation | Unknown nutrient, ingredient, recovery and meal availability | Unknown remains unknown through context, filter, engine, UI and history. |
| Range propagation | Point/lower/upper estimates crossing target or safety boundaries | Range is shown; result becomes cautious, confirmatory or unavailable per policy. |
| Dietary safety | Allergy, intolerance, religious, ethical, possible and insufficient evidence | Confirmed conflicts hard-block; no-known-conflict is not claimed safe; no inference occurs. |
| Medical wording | User-entered medical restriction and aggressive goal fixtures | No diagnosis/guarantee; professional-advice or unavailable wording is used as approved. |
| Recommendation determinism | Daily/weekly/training/nutrition same-context replay | One engine, stable priority/tie-break, same explanation/evidence. |
| Recommendation lineage | Rule/model/provider versions, source IDs, context fingerprint, supersession | Historical recommendation remains explainable after goal/data changes. |
| Feedback | Acknowledge, dismiss, accept, override, snooze, repeat action | Events append once, affect projections as specified, never rewrite issued output. |
| Daily boundaries | Local civil-date boundary, UTC offset, DST, cross-midnight log | Daily result follows recorded local date/timezone, not current device timezone. |
| Weekly boundaries | Explicit seven-civil-day period, week rollover, timezone change | Weekly review uses its stored period and evidence, not an implicit rolling window. |
| Offline behavior | Airplane mode, no AI, no health permission, provider timeout | Deterministic local guidance or honest unavailable state; no invented data. |
| AI privacy | Consent off/on, redaction, malformed output, provider failure | No raw prompts/images/health/allergy payload persisted or sent without approved consent; AI cannot author safety/targets. |
| Legacy authorities | Old TDEE, FoodLogs, meal-plan and weekly-report paths | No duplicate writes/reads remain authoritative; legacy adapters are isolated. |
| Accessibility | Semantics, focus order, announcements, dynamic text, contrast | Unknown/conflict/estimate/unavailable states are distinguishable and usable. |
| Platform builds | Android release build and iOS release build/no-code-sign path as CI permits | Both build from the clean implementation branch with no platform-specific errors. |

## Required physical-device checks

These checks are required before the final gate, not deferred to a post-release
manual pass. Record device model, OS, app build, timezone, network state,
permissions, input fixture and result.

| ID | Journey | Android and iOS evidence |
|---|---|---|
| M01 | Create a user-set target; view a calculated proposal; keep adaptive opt-in off; enable it and accept a bounded proposal; override it. | Active target, consent, explanation and history are identical in meaning on both platforms. |
| M02 | Open daily briefing and “what can I eat now?” offline with known, estimated and unknown nutrition. | Local candidates, ranges, missing evidence and unavailable states are truthful; no network spinner blocks the core. |
| M03 | Deny or revoke health permission; provide incomplete and stale recovery inputs. | Readiness shows incomplete/unknown and no adaptive change is presented. |
| M04 | Cross local midnight, DST, timezone change and week rollover with a goal change. | Daily/weekly periods and historical recommendation evidence retain their recorded timezone/effective date. |
| M05 | Exercise allergy, intolerance, religious/ethical conflict, possible conflict and unknown ingredient. | Hard blocks, warnings, confirmations and “no known conflict” wording are distinct; user override does not create a safety claim. |
| M06 | Dismiss, acknowledge, accept and override a recommendation; kill/relaunch; export and restore. | Feedback and historical lineage survive restart/restore without duplicate events. |
| M07 | AI consent off/on, offline provider failure, malformed provider response and redaction inspection in test harness. | Deterministic result remains authoritative; no disallowed data is sent or persisted. |
| M08 | Compact phone layout, large text, screen reader (TalkBack/VoiceOver), focus traversal and error announcement. | Evidence, confidence, unknown, conflict and action controls remain understandable and operable. |
| M09 | Install/relaunch on representative Android and iOS devices, including a clean install and upgrade install. | Schema migration, backup access, navigation and state restoration succeed. |
| M10 | Verify the conditional N8 seam remains unavailable unless an explicit approved context is supplied. | Festival/eating-out/fasting/travel is never inferred from time, location, food or history. |

## Manual end-to-end journeys

1. **Evidence-backed adaptive day:** set a goal, log a B03 snapshot with an
   estimate range, complete a B02 activity, provide complete recovery, accept
   a policy-approved proposal, and verify the daily explanation cites every
   input and preserves the old goal version.
2. **Insufficient evidence:** remove recent logs and deny health permission;
   verify the app does not adapt, does not use zeros, and offers a useful
   user-set or unavailable state without pretending confidence.
3. **Safe local food choice:** choose a local recipe/thali candidate, apply
   constraints, inspect remaining targets, and verify unknown/range/conflict
   wording before acknowledgement.
4. **Historical change:** change goals across a local-date boundary, rebuild
   the weekly review, and confirm past recommendations still show their old
   goal/readiness/evidence lineage.
5. **Offline/privacy boundary:** disable network and AI consent, exercise a
   provider timeout, and verify deterministic fallback, no raw prompt/image
   persistence and no health/allergy leakage.
6. **Restore failure:** import a malformed backup with a dangling evidence
   reference and verify the destination is unchanged; then restore a valid
   v9 backup and verify all graph edges and feedback events.

## Evidence package and release disposition

The final verification package must include:

- branch and commit, dependency-parent commit, schema/backup versions;
- formatter, analyzer, focused/full test and build logs;
- fresh/direct/chained migration and rollback evidence;
- backup v5–v9 compatibility, graph validation and idempotency evidence;
- deterministic target/recommendation fixture outputs;
- safety, unknown/range, medical-wording and AI privacy results;
- Android/iOS physical-device and accessibility records;
- manual journey results, known follow-ups, owners and due dates.

Sol High records one of: **Passed**, **Passed with explicitly accepted
non-blocking follow-up**, or **Blocked**. A blocked dependency must never be
reported as accepted. B04 implementation may begin only after the dependency
parent and `B04-D04` policy gate are closed; B04 release requires all hard
gates above and explicit Terra evidence for production surfaces.
