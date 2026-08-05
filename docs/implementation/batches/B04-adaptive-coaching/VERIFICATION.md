# B04 — Verification Plan

Status: verification plan only. No B04 implementation or verification run has
started. This branch records the B04-D04 documentation gate from planning
commit `9102092fd1b18e38beff500e2654ece6a191f66`.

The concrete B04 integration baseline is
`741aa18972ebc1b61cd65c0bf12b442b10b50890`; its implementation parent is
`f976542e395a3e082f1ab5cdfdfd87e969910766`. The accepted B03 commit is
`d85e8a16566735e7f6b7fe15cd2a97edb5677178`, with timezone correction
`78a43f909bae58dc5e509da97af426ad960c9190` and merge commit
`f976542e395a3e082f1ab5cdfdfd87e969910766`. The current D04 documentation
commit under review is `750ef0999153a7cc41a2493cb6305d2a833b1f12`.

## Verification gate

B04 implementation may be released only from a branch whose parent contains
accepted B01, B02 and B03. The concrete implementation parent above is the
accepted B03 integration parent; B03 schema v17 and Backup v8 are present
there. The planning branch is schema v16/backup v7 and is not a verification
baseline. B04’s proposed durable change remains schema v18/Backup v9.

After independent Sol High approval of this remediation, B04-01 may begin.
Foundational work may then proceed only according to the accepted task DAG and
its dependencies. `HOLD-1` does not block contracts, fixtures, Schema v18 or
Backup v9 foundations, goals, consent, eligibility, readiness, safety, lineage,
feedback or deterministic unavailable states; it continues to block enabled
adaptive output.

Required reviewers:

- **Sol High:** target policy, readiness, recommendation determinism,
  historical lineage, schema/backup, safety, privacy/AI and final release.
- **Terra High:** production controllers/providers, navigation, UI ownership,
  copy, compact layouts, large text and accessibility.
- **Product Owner:** qualitative adaptive opt-in, age, consent, safety,
  wording and any N8 context decision; numerical cadence, evidence thresholds
  and calorie bounds remain held.

Any unresolved dependency, safety, privacy, historical-immutability,
unknown/range, offline or platform/accessibility failure is a release blocker.
Only reproducible CI/documentation follow-up may be non-blocking, with an
owner and explicit Sol acceptance.

For D04 specifically, `B04-D04-01` through `B04-D04-20` must each have an
authorized Product Owner qualitative selection or the documented numerical
`HOLD-1` disposition, plus an independent Sol High verdict. The qualitative
policy is authorized; `HOLD-1` remains for trend duration/count/cutoff,
completeness/range threshold, proposal frequency/cooldown and all adaptive
calorie/deficit/surplus bounds. `HOLD-1` blocks enabled adaptive calorie
proposals, readiness-driven target or training-change proposals, every
non-zero adaptive delta, adaptive deficit/surplus and floor/ceiling behavior.
Under the hold, adaptive output is `unavailable`, upward/downward/aggregate
deltas are exactly `0 kcal`, no proposal may be accepted, and user override or
AI cannot bypass the hold. This is a disabled-policy contract, not a numerical
approval.

## B04-D04 policy-gate verification

The following evidence is required before the hold can be replaced by an
enabled policy:

- A signed decision record for minimum age `18` inclusive on the local civil
  birthday, below-age behavior, opt-in/default,
  consent/copy, cadence/cooldown, trend window, minimum evidence,
  completeness, adjustment bounds, deficit/surplus boundaries, missing-data
  behavior, wording, medical exclusions, dietary hard blocks, possible/
  insufficient evidence, offline behavior, AI behavior, overrides and N8.
- For every numeric field: unit; exact inclusive/exclusive edge; effective
  period; missing-data behavior; policy/version ID; override rule; and
  deterministic boundary tests. No record may use “reasonable,” “moderate” or
  “periodic” as a substitute for a value.
- Independent Sol High review of the selected policy, B03 mapping, B02 health
  provenance/readiness boundary, copy catalog, offline/AI redaction and
  historical lineage. Product Owner approval alone cannot close the gate.
- A negative `HOLD-1` fixture proving that the current policy emits no adaptive
  calorie or readiness-driven training proposal, applies exactly `0 kcal` per
  adaptation event and per affected local-civil-day period, preserves a valid
  user-set target, and records the unavailable reason and policy version.
- The authoritative dietary rule: for eat-now, adaptive target, daily/weekly
  coaching, ranked meal candidates and any output represented as suitable under
  active constraints, possible conflict, unknown conflict state, insufficient
  evidence, missing ingredient evidence, possible cross-contact and
  structurally invalid evidence return `unavailable`. Warning plus
  acknowledgement is limited to a separately defined low-risk logging action;
  it preserves the original evaluator result and warning, never enters
  recommendation output or changes ranking, and cannot bypass a hard block.
- Durable-owner evidence for append-only `coaching_consent_events` and
  `coaching_eligibility_evaluations`, including portable IDs, user ownership,
  required fields, indexes/foreign keys, restore validation and future-only
  correction behavior. Current projections are derived and are not historical
  authority.
- Historical-boundary evidence for consent enabled/disabled/withdrawn, AI
  consent changes, eligibility changes, corrected age evidence, policy-version
  changes, accepted goal/target versions, manual overrides, safety/availability
  changes, dietary evidence changes and rule-version changes. Each event is
  append-only or creates a new effective-dated target version, affects future
  decisions only and never rewrites a historical recommendation.
- Direct D04 acceptance tests are recorded in the owning task entries for
  `B04-03`, `B04-04`, `B04-05`, `B04-07`, `B04-08` and `B04-13`; they are not
  deferred to this final matrix.

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
| HOLD-1 disabled-policy guard | Attempt adaptive calorie/readiness proposals, user acceptance, manual override and AI bypass | Adaptive result is `unavailable`; no proposal is accepted; upward/downward/aggregate deltas are exactly `0 kcal`; no hidden calculation is active. |
| Goal history | User-set, calculated proposal, accepted adaptive proposal, override and reset | Each accepted change is a new version with correct effective date; old reads do not change. |
| Readiness completeness | Complete, missing, denied, stale and conflicting observations | Completeness/status is explicit; missing is never zero; adaptation is suppressed when required. |
| D04 decision completeness | `B04-D04-01` through `B04-D04-20`, exact Product Owner approval evidence, numerical `HOLD-1` register, durable-owner contract, direct task-test trace and Sol verdict | No unresolved policy record is hidden; missing Sol approval blocks implementation and missing numerical approval keeps `HOLD-1` active. |
| Age eligibility | Verified `18 completed years`, inclusive birthday, below-age user, unknown/invalid/conflicting/withheld age, correction and no inference | `coaching_eligibility_evaluations` is append-only; below-18 returns `coaching_unavailable_age`; unknown/invalid/conflicting/withheld age returns typed unavailable; logging/history/user-set targets remain available; historical evaluations are retained. |
| Opt-in and consent | Default off, explicit disclosure/action, append-only enable/disable/withdrawal events, separate AI consent, effective date, copy/version/timestamp and withdrawal | `coaching_consent_events` is the historical authority; no implicit consent; disablement stops new coaching; historical recommendations, accepted targets and feedback remain readable. |
| Target acceptance | Read-only proposal, explicit accept/reject/dismiss, duplicate acceptance and effective-dated target version | No silent replacement; acceptance is idempotent; rejection/dismissal does not mutate the current target. |
| Cadence/evidence gate | No background activation, explicit user/scheduled-review initiation, one-observation negative, window edges, valid-day count, completeness threshold, cooldown, stale and contradictory evidence | No proposal becomes active automatically; `HOLD-1` suppresses proposals until numerical evidence/cadence policy is approved. |
| Adjustment safety guard | `HOLD-1` zero upward, downward and aggregate delta plus approved per-event/period bounds when available | Current maximum upward, downward and aggregate adjustments are exactly `0 kcal`; future policy cannot omit unit, period, inclusivity, missing-data, version or override semantics. |
| Target determinism | Fixed fixtures for profile, trends, workload, readiness and policy versions | Same inputs/rule version produce the same result and evidence. |
| Target bounds | Lower/upper policy edges and missing metrics | No unsafe value or silent legacy default; policy-unavailable is explicit when gate is open. |
| Unknown propagation | Unknown nutrient, ingredient, recovery and meal availability | Unknown remains unknown through context, filter, engine, UI and history. |
| Range propagation | Point/lower/upper estimates crossing target or safety boundaries | Range remains a range; safety-sensitive output is unavailable when evidence cannot support the approved decision; no exactification or fabricated confidence. |
| Body-metric missingness | Missing, stale, conflicting, invalid and withheld weight/height/body metrics | No fallback or inference; adaptive output unavailable; valid user-set target remains displayable; corrections append evidence. |
| Nutrition completeness | Known zero, unknown, not-applicable, estimated, partial, stale and historical catalogue changes | B03 read models remain authoritative; no zero backfill or current-catalogue rewrite; insufficient/stale history is unavailable. |
| Recovery/readiness missingness | Missing, denied, stale, conflicting, incomplete, permission and provenance states | Readiness remains unknown/unavailable; no schedule/activity inference; readiness-driven proposals are suppressed. |
| Dietary safety | Allergy, intolerance, religious, ethical, possible, unknown, insufficient, missing ingredient, possible cross-contact and structurally invalid evidence | Confirmed strict conflicts hard-block; every listed possible/unknown/insufficient/missing/invalid state is unavailable for safety-sensitive guidance; no-known-conflict is not claimed safe; low-risk logging acknowledgement preserves the evaluator result and never enters recommendations. |
| Medical wording | User-entered medical restriction and aggressive goal fixtures | No diagnosis/guarantee; professional-advice or unavailable wording is used as approved. |
| Professional wording catalog | Wellness, non-medical coaching, missing evidence, aggressive request, medical restriction, consultation and emergency exclusions | Exact approved state-to-copy mapping; no diagnosis, prescription, guarantee or replacement-of-care claim. |
| Recommendation determinism | Daily/weekly/training/nutrition same-context replay | One engine, stable priority/tie-break, same explanation/evidence. |
| Recommendation lineage | Rule/model/provider versions, source IDs, context fingerprint, supersession | Historical recommendation remains explainable after goal/data changes. |
| Feedback | Acknowledge, dismiss, accept, override, snooze, repeat action | Events append once, affect projections as specified, never rewrite issued output. |
| Daily boundaries | Local civil-date boundary, UTC offset, DST, cross-midnight log | Daily result follows recorded local date/timezone, not current device timezone. |
| Weekly boundaries | Explicit seven-civil-day period, week rollover, timezone change | Weekly review uses its stored period and evidence, not an implicit rolling window. |
| Offline behavior | Airplane mode, no AI, no health permission, provider timeout | Deterministic local guidance or honest unavailable state; no invented data. |
| AI privacy | Separate consent, redaction, malformed/conflicting output, provider failure and forbidden fields | No raw prompts/responses/images/health/allergy payloads or secrets persisted/sent; AI cannot alter target, delta, safety, identity, ranking, evidence, ranges, completeness, availability or confidence. |
| Override/acknowledgement | Confirmed hard block, safety-sensitive unavailable state, separately scoped low-risk logging warning, accept, dismiss, override, snooze and retry | Feedback is append-only; acknowledgement cannot create safety or recommendation output; hard blocks remain; accepted targets create new versions. |
| N8 conditional seam | No context, inferred holiday/location/clock/food/travel/fasting, explicit future trigger | Required B04 remains independent of N8; no inference or current v18/v9 N8 persistence. |
| Legacy authorities | Old TDEE, FoodLogs, meal-plan and weekly-report paths | No duplicate writes/reads remain authoritative; legacy adapters are isolated. |
| Accessibility | Semantics, focus order, announcements, dynamic text, contrast | Unknown/conflict/estimate/unavailable states are distinguishable and usable. |
| Platform builds | Android release build and iOS release build/no-code-sign path as CI permits | Both build from the clean implementation branch with no platform-specific errors. |

## Incremental per-task evidence ledger

This ledger is part of the live verification record. Update the row for a task
immediately after that task is approved and merged, including focused test
evidence and any remediation/re-review. `B04-17` may verify ledger completeness
but must not reconstruct prior reviews from memory or from a final matrix.

| Task | Implementation commit | Primary reviewer | Verdict | Terra review | Remediation | Re-review | Merge commit | Focused tests | Status |
|---|---|---|---|---|---|---|---|---|---|
| `B04-01` | — | — | — | — | — | — | — | — | Not started |
| `B04-02` | — | — | — | — | — | — | — | — | Not started |
| `B04-03` | — | — | — | — | — | — | — | — | Not started |
| `B04-04` | — | — | — | — | — | — | — | — | Not started |
| `B04-05` | — | — | — | — | — | — | — | — | Not started |
| `B04-06` | — | — | — | — | — | — | — | — | Not started |
| `B04-07` | — | — | — | — | — | — | — | — | Not started |
| `B04-08` | — | — | — | — | — | — | — | — | Not started |
| `B04-09` | — | — | — | — | — | — | — | — | Not started |
| `B04-10` | — | — | — | — | — | — | — | — | Not started |
| `B04-11` | — | — | — | — | — | — | — | — | Not started |
| `B04-12` | — | — | — | — | — | — | — | — | Not started |
| `B04-13` | — | — | — | — | — | — | — | — | Not started |
| `B04-14` (optional) | — | — | — | — | — | — | — | — | Not started |
| `B04-15` | — | — | — | — | — | — | — | — | Not started |
| `B04-16` | — | — | — | — | — | — | — | — | Not started |
| `B04-17` | — | — | — | — | — | — | — | — | Not started |
| `B04-18` (conditional) | — | — | — | — | — | — | — | — | Not started |

## Required physical-device checks

These checks are required before the final gate, not deferred to a post-release
manual pass. Record device model, OS, app build, timezone, network state,
permissions, input fixture and result.

| ID | Journey | Android and iOS evidence |
|---|---|---|
| M01 | Create a user-set target; keep adaptive opt-in off; attempt enablement under `HOLD-1`; verify no adaptive proposal or acceptance is available; record the future enabled-policy fixture separately. | User-set target, consent state, unavailable reason and history are identical in meaning on both platforms; no target changes under `HOLD-1`. |
| M02 | Open daily briefing and “what can I eat now?” offline with known, estimated and unknown nutrition. | Local candidates, ranges, missing evidence and unavailable states are truthful; no network spinner blocks the core. |
| M03 | Deny or revoke health permission; provide incomplete and stale recovery inputs. | Readiness shows incomplete/unknown and no adaptive change is presented. |
| M04 | Cross local midnight, DST, timezone change and week rollover with a goal change. | Daily/weekly periods and historical recommendation evidence retain their recorded timezone/effective date. |
| M05 | Exercise allergy, intolerance, religious/ethical conflict, possible conflict, unknown ingredient, missing ingredient evidence and possible cross-contact. | Confirmed strict conflicts hard-block; possible/unknown/insufficient/missing/invalid safety evidence is unavailable for safety-sensitive output; only separately scoped low-risk logging may retain a warning/acknowledgement; user override does not create a safety claim. |
| M06 | Dismiss, acknowledge, accept and override a recommendation; kill/relaunch; export and restore. | Feedback and historical lineage survive restart/restore without duplicate events. |
| M07 | AI consent off/on, offline provider failure, malformed provider response and redaction inspection in test harness. | Deterministic result remains authoritative; no disallowed data is sent or persisted. |
| M08 | Compact phone layout, large text, screen reader (TalkBack/VoiceOver), focus traversal and error announcement. | Evidence, confidence, unknown, conflict and action controls remain understandable and operable. |
| M09 | Install/relaunch on representative Android and iOS devices, including a clean install and upgrade install. | Schema migration, backup access, navigation and state restoration succeed. |
| M10 | Verify the conditional N8 seam remains unavailable unless an explicit approved context is supplied. | Festival/eating-out/fasting/travel is never inferred from time, location, food or history. |
| M11 | Exercise below-18, unknown-age, invalid-age, disabled-coaching, consent-withdrawal and policy-hold states. | `coaching_unavailable_age` or the typed unavailable state is shown without punitive wording; descriptive logging/history/user-set targets remain usable; timestamps and feedback are truthful on both platforms. |

## Manual end-to-end journeys

1. **Evidence-backed adaptive day:** future enabled-policy fixture only. Set a
   goal, log a B03 snapshot with an estimate range, complete a B02 activity,
   provide complete recovery, accept a separately approved proposal, and verify
   the daily explanation cites every input and preserves the old goal version.
   Under current `HOLD-1`, the same journey must return unavailable and cannot
   accept a target.
2. **Insufficient evidence:** remove recent logs and deny health permission;
   verify the app does not adapt, does not use zeros, and offers a useful
   user-set or unavailable state without pretending confidence.
3. **Safe local food choice:** choose a local recipe/thali candidate, apply
   constraints, inspect remaining targets, and verify that possible, unknown,
   insufficient, missing or cross-contact evidence is unavailable for
   safety-sensitive output. Test warning acknowledgement only through the
   separately defined low-risk logging action.
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

- branch and remediation/current commit, concrete integration baseline
  `741aa18972ebc1b61cd65c0bf12b442b10b50890`, implementation parent
  `f976542e395a3e082f1ab5cdfdfd87e969910766`, planning commit
  `9102092fd1b18e38beff500e2654ece6a191f66`, accepted B03 commit
  `d85e8a16566735e7f6b7fe15cd2a97edb5677178`, timezone correction
  `78a43f909bae58dc5e509da97af426ad960c9190`, B03 merge commit
  `f976542e395a3e082f1ab5cdfdfd87e969910766`, and schema/backup versions;
- formatter, analyzer, focused/full test and build logs;
- fresh/direct/chained migration and rollback evidence;
- backup v5–v9 compatibility, graph validation and idempotency evidence;
- deterministic target/recommendation fixture outputs;
- Product Owner authorization for qualitative D04 policy and the exact
  `HOLD-1` numerical guard fixture. The approval evidence is: “I approve the
  qualitative B04-D04 policy decisions recorded at the approved D04 commit,
  including the 18+ eligibility rule for adaptive calorie and readiness-driven
  proposals.

  Numerical adaptation cadence, evidence thresholds, calorie adjustment bounds,
  deficit/surplus limits, and calorie floors or ceilings remain under
  B04-D04-HOLD-1 and are not approved for enabled adaptation.” Source: Product
  Owner; date `2026-08-05`; approved commit `750ef0999153a7cc41a2493cb6305d2a833b1f12`;
  scope: qualitative decisions only; numerical scope remains held; independent
  Sol review required;
- append-only consent-event and eligibility-evaluation owner evidence,
  restore-order/rollback evidence and the incrementally maintained task ledger;
- independent Sol High verdict covering the authorized policy, inherited
  B01–B03 boundaries, v18/v9 ownership, safety, privacy, wording and hold
  behavior;
- safety, unknown/range, medical-wording and AI privacy results;
- Android/iOS physical-device and accessibility records;
- manual journey results, known follow-ups, owners and due dates.

Sol High records one of: **Passed**, **Passed with explicitly accepted
non-blocking follow-up**, or **Blocked**. A blocked dependency must never be
reported as accepted. If the independent Sol verdict for this remediation is
Approved/Passed, B04-01 is authorized to begin from the concrete accepted
parent; later tasks remain constrained by the DAG and their own dependencies.
Foundational Schema v18/Backup v9 work, persistence, goals, consent,
eligibility, readiness, safety, lineage, feedback and unavailable-state
behavior are authorized only within those gates. Enabled adaptive calorie
proposals, non-zero target adjustment, adaptive deficit/surplus, calorie floor
or ceiling, readiness-driven target/training adjustment and any unresolved
numerical-threshold behavior remain blocked until a superseding numerical
policy is approved. B04 release still requires all hard gates above and
explicit Terra evidence for production surfaces.
