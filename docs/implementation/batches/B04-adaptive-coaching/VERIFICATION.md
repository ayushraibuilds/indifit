# B04 — Verification Plan

Status: verification plan only. No B04 implementation or verification run has
started. This branch records the B04-D04 documentation gate and the proposed
`B04-D04-ENABLED-1` numerical policy; no activation is authorized here.

The concrete B04 integration baseline is
`741aa18972ebc1b61cd65c0bf12b442b10b50890`; its implementation parent is
`f976542e395a3e082f1ab5cdfdfd87e969910766`. The accepted B03 commit is
`d85e8a16566735e7f6b7fe15cd2a97edb5677178`, with timezone correction
`78a43f909bae58dc5e509da97af426ad960c9190` and merge commit
`f976542e395a3e082f1ab5cdfdfd87e969910766`. The prior D04 qualitative
documentation commit is `750ef0999153a7cc41a2493cb6305d2a833b1f12`. The current
numerical-policy authoring baseline is
`e19ae5d512bea0d46143ca5bda842425a46df0a8`, recorded as
`B04_D04_FINAL_COMMIT`.

The focused independent Sol High numerical-precision review is **Approved** at
`B04_D04_FINAL_COMMIT` for range-width arithmetic, Theil–Sen medians and ties,
exact decision precision, kcal normalization, directional floor/ceiling
rounding, exact ±100 kcal proposal behavior and deterministic edge fixtures.
This approval does not activate `ENABLED-1`; it remains inactive until the D04
branch is merged and an explicit release/feature-policy selection records a
future effective date, timezone and scope.

## Verification gate

B04 implementation may be released only from a branch whose parent contains
accepted B01, B02 and B03. The concrete implementation parent above is the
accepted B03 integration parent; B03 schema v17 and Backup v8 are present
there. The planning branch is schema v16/backup v7 and is not a verification
baseline. B04’s proposed durable change remains schema v18/Backup v9.

This branch does not begin B04-01. Foundational work remains subject to the
accepted task DAG and its own gates. `HOLD-1` remains the current/default
policy for historical replay and installations/users not selecting
`ENABLED-1`; it does not block contracts, fixtures, Schema v18 or Backup v9
foundations, goals, consent, eligibility, readiness, safety, lineage, feedback
or deterministic unavailable states. `ENABLED-1` is not active until Product
Owner approval, a fresh independent Sol High verdict, branch merge and
explicit release/feature-policy selection are all recorded.

Required reviewers:

- **Sol High:** target policy, readiness, recommendation determinism,
  historical lineage, schema/backup, safety, privacy/AI and final release.
- **Terra High:** production controllers/providers, navigation, UI ownership,
  copy, compact layouts, large text and accessibility.
- **Product Owner:** qualitative adaptive opt-in, age, consent, safety,
  wording, N8 boundary and the proposed `ENABLED-1` numerical selection.
  Product Owner approval does not replace the fresh independent Sol verdict or
  activation/merge gate. `READINESS-HOLD-1` remains selected for all readiness
  numerical effects.

Any unresolved dependency, safety, privacy, historical-immutability,
unknown/range, offline or platform/accessibility failure is a release blocker.
Only reproducible CI/documentation follow-up may be non-blocking, with an
owner and explicit Sol acceptance.

For D04 specifically, `B04-D04-01` through `B04-D04-20` must each have an
authorized Product Owner qualitative selection, and the versioned
`B04-D04-ENABLED-1` record must contain the explicit numerical selection and
all boundary metadata, plus a fresh independent Sol High verdict. `HOLD-1`
remains retained for replay/non-selection; under it adaptive output is
`unavailable`, all adaptive deltas are exactly `0 kcal`, no proposal may be
accepted and user override or AI cannot bypass the hold. `READINESS-HOLD-1`
requires exact zero calorie and training numerical effects. `ENABLED-1` can be
reviewed as a proposed policy but cannot become active until merge and explicit
release/feature-policy selection.

## B04-D04 policy-gate verification

The following evidence is required before `B04-D04-ENABLED-1` can become
active; Product Owner selection alone is not activation:

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
- The proposed `ENABLED-1` record includes the exact supported rates, 21-day
  window, weight/nutrition/maintenance-energy thresholds, versioned Theil–Sen
  formula, deadbands, exact `100 kcal/day` event, 21-day cadence, seven-day
  expiry, 42-day aggregate boundary, deficit/surplus limits, floor/ceiling,
  rapid-change states and future-only activation rule.
- A separate `READINESS-HOLD-1` fixture proves readiness contributes exactly
  `0 kcal/day`, `0%` load, `0%` intensity and `0` schedule-duration change;
  descriptive readiness remains possible and missing readiness remains
  unknown/unavailable.
- Activation evidence names the merged policy branch and the release or
  feature-policy selection, including policy version, effective local date,
  timezone and user/installation scope. No activation date is implied by this
  documentation commit.

The numerical fixtures use the following canonical arithmetic contract:

- Every numeric input is finite, unit-correct and within domain. NaN,
  infinities, wrong-unit, out-of-domain, zero-denominator and other invalid
  inputs return typed unavailable/invalid-evidence results and never become
  zero.
- For bounds `L` and `U`, `width = U − L`, `midpoint = (L + U) ÷ 2`, and
  `relative_width_percent = ((U − L) ÷ midpoint) × 100`. Require finite,
  same-unit bounds with `L >= 0`, `U >= L` and `midpoint > 0`. Compare the
  unrounded value to inclusive `20%` nutrition and `15%` maintenance limits.
- Weights normalize to integer grams. Odd medians use the middle value; even
  medians use the exact mean of the two middle values. Theil–Sen creates every
  pairwise slope, then uses the odd middle or even mean-of-two-middle slope.
  Weekly rate is `slope_grams_per_day × 7 × 100 ÷ median_window_weight_grams`.
- Policy percentages use exact basis points and exact rational/decimal
  comparisons. Displayed weight-trend percentages use nearest two-decimal
  rounding with halfway ties away from zero; canonical history remains
  unrounded.
- Maintenance point evidence is normalized once to whole-integer `M` kcal/day
  using nearest rounding with halfway ties away from zero. Deficit and surplus
  caps use `floor`; the percentage floor uses `ceil`; all targets and deltas
  are whole integer kcal/day values.
- Every enabled proposal is exactly `+100` or `−100 kcal/day`. A complete step
  that crosses a boundary emits no proposal, returns
  `policy_boundary_reached`, and leaves the active target unchanged. No smaller
  boundary clamp is permitted.

## `B04-D04-ENABLED-1` direct numerical edge tests

These are required deterministic policy tests, not an implementation claim.
Each fixture records policy version, unit, local-civil-day period, timezone,
missing-data result, override behavior and historical evidence references.

| ID | Edge fixture | Required result |
|---|---|---|
| E01 | Product Owner selection without Sol verdict, merge or explicit release selection | `ENABLED-1` remains inactive; `HOLD-1` remains current/default; no proposal is emitted. |
| E02 | Exact local civil date of the 18th birthday | Eligible when every other requirement passes; birthday boundary inclusive. |
| E03 | Underage, unknown, withheld, missing, invalid or conflicting age | Typed age-unavailable result; no adaptive calorie proposal; logging/history/user-set targets remain available. |
| E04 | Self-declared pregnancy and breastfeeding | Unsupported adaptive path; no enabled adaptive calorie proposal; no clinical inference or validation. |
| E05 | BMI exactly `18.5 kg/m²` versus one unit below | Exactly `18.5` passes this loss screening boundary; below it returns unavailable; BMI is not a diagnosis. |
| E06 | `20` versus `21` completed local evaluation days | 20 is insufficient; exactly 21 is required; current incomplete day is excluded. |
| E07 | `9` versus `10` valid weight-measurement days | 9 fails; exactly 10 passes this count gate if all other gates pass. |
| E08 | Weight measurements spanning `13` versus `14` local civil days | 13 fails; exactly 14 passes this span gate. |
| E09 | Fewer than `3` valid days in first or final seven-day block versus exactly 3 | Any block failure returns unavailable; exactly 3 in each block satisfies the distribution gate. |
| E10 | Latest valid weight at `4` versus `5` completed local days old | Exactly 4 is fresh enough; 5 is stale and returns unavailable. |
| E11 | `13` versus `14` nutrition-valid days out of 21 | 13 fails; exactly 14 passes if each day is valid. |
| E12 | Daily completeness `79.99%`, `80%` and above | 79.99% fails; exactly 80% and higher pass the completeness gate. |
| E13 | Nutrition ranges `1800–2200` and `1799–2201` | Width/midpoint are `400/2000` and `402/2000`; exact 20% passes and exact 20.1% fails. |
| E14 | Lower and upper nutrition bounds produce different actions | Return `unavailable_uncertain_range`; never choose one bound or exactify it. |
| E15 | Maintenance estimate age exactly `30` versus `31` completed local days | Exactly 30 is fresh enough; 31 is stale and returns unavailable. |
| E16 | Maintenance ranges `1850–2150` and `1849–2151` | Width/midpoint are `300/2000` and `302/2000`; exact 15% passes and exact 15.1% fails. |
| E17 | Loss rate at `−0.65%`, `−0.35%` and just outside the `−0.50% ± 0.15` band | Both exact edges are `on_track`; outside the inclusive band selects the specified direction. |
| E18 | Gain rate at `+0.10%`, `+0.40%` and just outside the `+0.25% ± 0.15` band | Both exact edges are `on_track`; outside the inclusive band selects the specified direction. |
| E19 | Maintenance at `−0.25%`, `+0.25%` and just outside | Exact edges are `on_track`; below permits `+100 kcal/day`, above permits `−100 kcal/day`. |
| E20 | Normal proposal delta | Every emitted normal proposal is exactly `100 kcal/day`; 50, 150 and 200 are rejected. |
| E21 | Proposal cadence at 20 versus 21 completed local civil days | 20 fails cooldown; exactly 21 permits at most one proposal if all gates pass. |
| E22 | Proposal expiry before, at exactly, and after 7 completed local civil days | Proposal is available only before expiry; exactly seven completed days reaches the expiry boundary; expired proposal cannot be accepted. |
| E23 | Rolling aggregate at `+200`/`−200` versus one unit beyond within 42 days | Exact inclusive bounds are allowed; one unit beyond returns `policy_boundary_reached` and leaves target unchanged. |
| E24 | Loss deficit exactly `500 kcal/day` versus one unit beyond, with the 20% limit non-limiting | Exactly 500 is allowed by this bound; one unit beyond is blocked; when 20% is smaller, the smaller limit governs. |
| E25 | Loss deficit exactly `20%` of maintenance versus one unit beyond, with the 500-kcal limit non-limiting | Exactly 20% is allowed by this bound; one unit beyond is blocked; when 500 kcal is smaller, the smaller limit governs. |
| E26 | Loss floor at exact `1200 kcal/day` and exact dynamic `80%` maintenance boundary | A complete 100-kcal crossing step emits no proposal, returns `policy_boundary_reached`, and leaves the target unchanged; no smaller clamp is emitted. |
| E27 | Gain surplus exactly `300 kcal/day` versus one unit beyond, with the 15% limit non-limiting | Exactly 300 is allowed by this bound; one unit beyond is blocked; when 15% is smaller, the smaller limit governs. |
| E28 | Gain surplus exactly `15%` of maintenance versus one unit beyond, with the 300-kcal limit non-limiting | Exactly 15% is allowed by this bound; one unit beyond is blocked; when 300 kcal is smaller, the smaller limit governs. |
| E29 | Loss trend exactly `−1.00%` versus faster than `−1.00%` | Exactly −1.00% does not trigger rapid review; faster triggers `rapid_change_review` with no proposal. |
| E30 | Gain trend exactly `+0.50%` versus faster than `+0.50%` | Exactly +0.50% does not trigger rapid review; faster triggers `rapid_change_review` with no proposal. |
| E31 | Current target below floor or above ceiling | Preserve/display as user-set; return `user_target_outside_supported_policy`; do not silently clamp or propose. |
| E32 | Complete, missing, denied, stale and conflicting readiness | Readiness contributes exactly zero to calories, load, intensity and schedule duration; missing remains unknown/unavailable. |
| E33 | AI suggests a different eligibility, rate, trend, delta, bound, safety state or confidence | Deterministic result remains authoritative; conflicting/malformed AI output is discarded. |
| E34 | Timezone change, DST transition, local midnight and current-day incompleteness | Historical observations retain their recorded local date/timezone; no reinterpretation or current-day inclusion. |
| E35 | Corrected weight, nutrition or maintenance evidence | Correction appends evidence/snapshot and creates future evaluation only; old result and lineage remain immutable. |
| E36 | Duplicate acceptance command, including retry after restart | One effective-dated target version is created; duplicate command is idempotent and current target is not duplicated. |
| E37 | Replay a `HOLD-1` evaluation after `ENABLED-1` is proposed/activated, and replay an `ENABLED-1` evaluation under `HOLD-1` | Each history replays under its stored policy version; no cross-version recomputation or retroactive rewrite. |
| E38 | Offline with complete local evidence, missing evidence, stale evidence and AI unavailable | Deterministic local result or explicit unavailable state; no invented evidence, queued authoritative change or cached-AI authority. |
| E39 | Supported goal-rate selection, default and faster-than-supported request | Only listed loss/maintenance/gain rates are accepted; defaults are explicit; unsupported faster rates are unavailable. |
| E40 | Accepted target change, manual target change, goal-rate change and maintenance-policy version change | Evidence window resets; 21 new completed local civil days are required; pre-change observations are excluded. |
| E41 | Exact ranges `2000–2000`, `0–0`, negative bounds, reversed bounds and non-finite values | Positive-midpoint exact range is valid; zero midpoint returns `unavailable_invalid_midpoint`; other invalid inputs return typed invalid/unavailable results. |
| E42 | Maintenance normalization for `M = 2000`, `2001` and `1801` kcal/day | `2000` yields deficit cap `400`, floor `1600`, surplus cap `300`, ceiling `2300`; `2001` yields cap `400`, floor `1601`, surplus cap `300`, ceiling `2301`; `1801` yields cap `360`, floor `1441`, surplus cap `270`, ceiling `2071`. |
| E43 | Odd/even daily medians and odd/even pairwise-slope counts | Middle values or exact mean of two middle values are retained as exact rationals; no pre-slope rounding occurs. |
| E44 | Equal slopes, tied weights and fractional rational slopes | The exact rational Theil–Sen result is stable and replayable; equal/tied values do not depend on insertion order. |
| E45 | Exact deadband/rapid-change boundaries and one rational unit inside/outside | Inclusive/exclusive rules are applied to the unrounded exact weekly rate. |
| E46 | Display values `0.125%` and `−0.125%` | Display as `0.13%` and `−0.13%`; stored policy result remains unrounded. |
| E47 | Prospective aggregate with positive/negative engine deltas and manual target changes | Only accepted engine-authored whole-kcal deltas in the rolling 42-day window count; manual changes are excluded; prospective delta is checked before version creation. |

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
| ENABLED-1 activation gate | Product Owner selection, fresh independent Sol verdict, merged branch and explicit release/feature-policy selection | Policy is inactive until all four conditions are recorded; activation has a future effective local date/timezone and never rewrites HOLD-1 history. |
| ENABLED-1 numerical contract | Exact eligibility, goal rates, 21-day window, evidence thresholds, Theil–Sen algorithm, deadbands, 100-kcal step, cadence, expiry, aggregate, deficit/surplus, floor/ceiling and rapid-change rules | Same frozen inputs/policy version produce the specified proposal, unavailable reason or boundary state; no legacy constant is authoritative. |
| ENABLED-1 arithmetic precision | Finite/unit/domain validation, exact range width/midpoint, invalid midpoint/range, rational medians/slopes, basis points, display rounding, normalized `M`, floor/ceil derivation and no-clamp boundary crossing | Policy decisions use unrounded exact arithmetic; stored history is replayable; display rounding cannot alter a decision; invalid numeric evidence is unavailable. |
| READINESS-HOLD-1 numerical guard | Complete, missing, denied, stale and conflicting readiness under the proposed enabled calorie policy | Calories change exactly `0 kcal/day`; load/intensity change exactly `0%`; schedule duration change exactly `0`; descriptive readiness may remain. |
| Goal history | User-set, calculated proposal, accepted adaptive proposal, override and reset | Each accepted change is a new version with correct effective date; old reads do not change. |
| Readiness completeness | Complete, missing, denied, stale and conflicting observations | Completeness/status is explicit; missing is never zero; adaptation is suppressed when required. |
| D04 decision completeness | `B04-D04-01` through `B04-D04-20`, exact qualitative approval, `ENABLED-1` selection/metadata, retained HOLD-1 and READINESS-HOLD-1, durable-owner contract, direct task-test trace and fresh Sol verdict | No unresolved policy record is hidden; missing Sol/merge/explicit activation keeps ENABLED-1 inactive and HOLD-1 behavior current. |
| Age eligibility | Verified `18 completed years`, inclusive birthday, below-age user, unknown/invalid/conflicting/withheld age, correction and no inference | `coaching_eligibility_evaluations` is append-only; below-18 returns `coaching_unavailable_age`; unknown/invalid/conflicting/withheld age returns typed unavailable; logging/history/user-set targets remain available; historical evaluations are retained. |
| Opt-in and consent | Default off, explicit disclosure/action, append-only enable/disable/withdrawal events, separate AI consent, effective date, copy/version/timestamp and withdrawal | `coaching_consent_events` is the historical authority; no implicit consent; disablement stops new coaching; historical recommendations, accepted targets and feedback remain readable. |
| Target acceptance | Read-only proposal, explicit accept/reject/dismiss, duplicate acceptance and effective-dated target version | No silent replacement; acceptance is idempotent; rejection/dismissal does not mutate the current target. |
| Cadence/evidence gate | No background activation, explicit initiation, one-observation negative, exact 21-day window, valid-day counts, completeness/range/freshness thresholds, cooldown, expiry, stale and contradictory evidence | HOLD-1 suppresses current output; after explicit ENABLED-1 activation, only the exact cadence/evidence contract can emit one unresolved proposal. |
| Adjustment safety guard | HOLD-1 zero upward/downward/aggregate delta; ENABLED-1 exact 100-kcal event, 42-day ±200 aggregate, deficit/surplus, floor/ceiling and override semantics | Current HOLD-1 is zero; future enabled behavior passes every signed bound and cannot be bypassed by user or AI. |
| Target determinism | Fixed fixtures for profile, trends, workload, readiness and policy versions | Same inputs/rule version produce the same result and evidence. |
| Target bounds | ENABLED-1 loss/gain deficit, surplus, floor, ceiling, unsupported user target and missing maintenance evidence | Exact inclusive edges pass; one unit beyond returns the specified boundary/unavailable state; no medical-safety claim or silent clamp. |
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

1. **Evidence-backed adaptive day:** future `ENABLED-1` fixture only, after
   policy activation evidence exists. Set a supported goal rate, satisfy the
   exact 21-day/weight/nutrition/maintenance-energy gates, log a B03 snapshot
   with an estimate range whose bounds produce the same action, and verify the
   exact 100-kcal proposal, explicit acceptance and preserved old target
   version. Under current `HOLD-1`, the same journey must return unavailable
   and cannot accept a target; readiness must have no numerical effect.
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
- independent fresh Sol High verdict covering the authorized policy,
  `ENABLED-1` numerical contract, `READINESS-HOLD-1`, inherited B01–B03
  boundaries, v18/v9 ownership, safety, privacy, wording and HOLD-1 behavior;
- safety, unknown/range, medical-wording and AI privacy results;
- Android/iOS physical-device and accessibility records;
- manual journey results, known follow-ups, owners and due dates.

Sol High records one of: **Passed**, **Passed with explicitly accepted
non-blocking follow-up**, or **Blocked**. A blocked dependency must never be
reported as accepted. A passing fresh verdict does not itself activate
`ENABLED-1`: the policy branch must also be merged and the release or
feature-policy activation must explicitly select the version with a future
effective local date/timezone and user/installation scope. This branch still
does not begin B04-01 or implementation. Until those activation conditions
pass, HOLD-1 remains current and all adaptive deltas are zero. Even after
ENABLED-1 activation, readiness-driven numerical target/training changes,
medical/youth/clinical adaptation and AI numerical authority remain blocked by
`READINESS-HOLD-1` and the qualitative policy. B04 release still requires all
hard gates above and explicit Terra evidence for production surfaces.
