# IndiFit Post-V1 Product and Engineering Roadmap

- Status: Canonical for post-V1 prioritization
- Effective date: 2026-08-30
- Planning baseline: frozen R08 product decisions and the V1 release-candidate completion pass
- Companion execution plan: [`POST_V1_IMPLEMENTATION_PLAN.md`](../implementation/POST_V1_IMPLEMENTATION_PLAN.md)
- Cleanup execution program: [`POST_V1_CLEANUP_PROGRAM.md`](../implementation/POST_V1_CLEANUP_PROGRAM.md)

## 1. Purpose and authority

This document defines what IndiFit may pursue after V1, in what broad order,
and under which product-truth gates. It is a portfolio roadmap, not a promise to
build every listed item.

For post-V1 eligibility and sequencing, this document supersedes the 2026-07-29
backlog and delivery sections in [`canonical-roadmap.md`](canonical-roadmap.md).
The older document remains useful architectural history. Frozen R08 domain,
identity, evidence, licensing, migration, and safety decisions remain binding.
Where an older audit or plan suggests synthetic e1RM, inferred PRs, homemade
calorie burn, numeric readiness, or strength standards, the later R08 decision
to remove or reject that behavior wins.

Authority order for new work:

1. Accepted V1 behavior and frozen R08 decisions.
2. This post-V1 roadmap.
3. The companion prioritized implementation plan.
4. Older plans and audits as historical evidence only.

## 2. Product strategy after V1

IndiFit should deepen the existing consumer loops—train, log food, understand
progress, and act on trustworthy coaching—without adding prominent surfaces
whose data authority is incomplete.

Offline-first means **the core fitness product never stops working**, not that
IndiFit refuses to benefit from the internet:

> **Offline is execution and personal truth. Online is enrichment,
> synchronization, fresh data, collaboration, and expensive intelligence.**

The local canonical layer owns immediate interaction and persisted personal
truth. A network service may suggest, fetch, explain, sync, share, discover, or
enrich. It must not be required to log, calculate, execute, or view existing
personal history.

### Offline core contract

The following capabilities must continue to work without connectivity and
without waiting on a server:

- app launch/navigation and Today from stored data;
- existing plans, calendar, Quick Workout, and planned workout execution;
- set logging/editing, rest timing, and workout completion;
- exercise-library basics and locally available instructions/media;
- food diary, local food search, Saved Meals, Recipes, and nutrition targets;
- weight logging, Progress from stored evidence, and achievements;
- reminder scheduling, settings, and previously downloaded content/plans.

If connectivity disappears during a workout or food log, the foreground
journey continues normally. Network state may affect only clearly connected
actions and background delivery state.

### Three-layer product boundary

```text
Connected services
AI · sync · coaches · social · remote catalogues · media · integrations
                         ↓ validated suggestions/imports/events
IndiFit canonical domain
plans · workouts · food · targets · Progress · coaching · history
                         ↓ durable local read/write authority
Local-first storage
Drift · preferences · cached media/content · downloads · pending outbox
```

Connected systems never write around the canonical domain. Imported or
generated data is validated, normalized, attributed, and—where it changes
personal truth—reviewed before it becomes a local canonical record.

The default pattern is **connected once, useful offline afterwards**: a found
food is cached, a downloaded plan becomes a local version, exercise media can
be retained for the gym, a generated plan is reviewed and saved, and imported
provider evidence remains available in local history.

The governing principles are:

- **Release stability first.** V1.0.x is for correctness, crash, data-loss,
  privacy, accessibility, and platform-reliability fixes.
- **Evidence before presentation.** A card, score, trend, badge, or suggestion
  must be backed by a canonical read authority with honest missing-data states.
- **AI is an accelerator, not an authority.** Generated suggestions are
  reviewable and user-approved; AI does not originate canonical targets,
  nutrition facts, health facts, history, PRs, or performance records.
- **Domain depth before prominence.** Existing schema compatibility or dormant
  code does not justify exposing a consumer feature.
- **Offline-first and device-owned.** Core logging, history, plans, and
  deterministic recommendations remain useful without a network connection;
  connected services are optional capabilities rather than hidden runtime
  dependencies.
- **Local commit first.** Core mutations update the local authority and UI
  immediately. Synchronization uses a durable queue with retry/idempotency; a
  server round trip never gates a set, meal, weight, or plan interaction.
- **Explicit connected state.** Download, import, sync, and backup surfaces show
  provenance, last-success state, pending work, errors, and recovery without
  turning routine offline operation into an alarming error.
- **Measured engineering.** Refactors preserve behavior first; performance and
  dependency work follows evidence rather than intuition.

## 3. Release horizons

| Horizon | Outcome | Included focus | Explicit boundary |
|---|---|---|---|
| **V1 release** | Ship the frozen release candidate | Manual real-device acceptance and release sign-off | No post-V1 feature work |
| **V1.0.x** | Protect trust in production | Bugs, crashes, data integrity, privacy, accessibility, and platform reliability | No roadmap expansion disguised as a fix |
| **V1.1 engineering** | Create a safe change surface | Deterministic tests, characterization coverage, retired-code classification, mechanical God-file splits | No behavior or schema redesign inside structural refactors |
| **V1.1 product** | Improve the workout/progress payoff | Workout recap and factual share card, approved exercise media improvements, small achievements/progress improvements | No synthetic PR, e1RM, calorie burn, or readiness score |
| **V1.1 connected foundation** | Protect data without weakening offline execution | Optional account decision, encrypted automatic cloud backup, consented diagnostics foundation | Local/manual backup remains available; cloud failure never blocks core use |
| **V1.2 connected** | Broaden the daily product and devices | Multi-device sync, online/branded food search, barcode lookup, streamed/downloaded exercise media, signed catalogue updates | Local commit first; imports/cache fail closed with provenance |
| **V1.2 product** | Deepen planning and authoritative health context | Plan analytics/history, plan customization, sleep/steps/active-energy improvements, integrated plate-calculator presentation | Health data only from legitimate platform/provider authority |
| **V1.x/V2** | Add missing domains and intelligence deliberately | Canonical hydration, reviewable AI food/plan assistance, contextual coaching, direct provider imports, complete erasure boundary | Each item requires its own prerequisite gate |
| **V2-level options** | Consider larger collaborative systems after evidence | Coach/trainer sharing, friends/challenges, public plan marketplace, deeper cardio/social, canonical PR events | Separate product decision; not automatic backlog |

Horizons are sequencing containers, not calendar commitments. A later item may
move forward only when its dependencies and acceptance evidence exist; it must
not bypass the V1 release or engineering-foundation gates.

## 4. Committed roadmap themes

### 4.1 Reliability and maintainability

This is the first post-release investment because every later feature depends
on being able to distinguish a regression from test pollution. IndiFit should
be cleaned incrementally, not rewritten; the accepted domains, migrations,
backup compatibility, accessibility, and regression evidence are assets. The
detailed C0–C7 gates live in the
[`POST_V1_CLEANUP_PROGRAM.md`](../implementation/POST_V1_CLEANUP_PROGRAM.md).

- Make Flutter tests deterministic with standard database overrides,
  isolated `SharedPreferences`, consistent platform-service fakes, and a
  reliable serial CI lane.
- Eliminate order-sensitive failures and repeated multiple-`AppDatabase`
  warnings at their ownership boundary.
- Strengthen characterization tests around weaker or historically fragile
  flows before structural changes.
- Classify dormant code as retired product, test fixture, developer tooling,
  or intentionally retained compatibility code.
- Delete only evidence-confirmed retired code; move fixtures under `test/` and
  developer tooling under `tool/` where appropriate.
- Mechanically split the largest screens/controllers while preserving pixels,
  semantics, keys, callbacks, navigation, and behavior.

### 4.2 Workout completion and training experience

- Improve the workout completion recap with factual session statistics,
  previous-session context, and clearer history navigation.
- Add a shareable workout card/image containing only logged, attributable
  workout facts.
- Improve exercise illustrations for priority exercises and consider motion
  demonstrations only after licensing, provenance, package-size, memory, and
  accessibility review.
- Add background rest-timer visibility through Android's supported ongoing
  notification model and iOS Live Activity when lifecycle behavior is proven.
- Consolidate plate-calculator placement into the workout/exercise journey
  without creating another calculation authority.

### 4.3 Progress and motivation

- Expand achievements modestly with stable definitions, deterministic unlock
  identity, honest progress states, and a better collection experience.
- Improve milestones and streak concepts only when they reward sustainable
  training rather than encouraging unsafe or low-quality sessions.
- Add richer drill-downs and comparisons only where the logged evidence is
  sufficiently complete.
- Compare actual workout or plan periods without manufacturing unsupported
  performance metrics.

### 4.4 Plans and personalization

- Add plan completion summaries, plan history, phase/week progress, and useful
  adherence views.
- Support richer per-day and per-exercise customization without exposing
  program-authoring machinery as ordinary consumer UI.
- Revisit equipment-profile presentation as part of plan customization rather
  than adding a disconnected dashboard surface.
- Consider a quicker light/dark/system theme control after higher-value core
  work.

### 4.5 Nutrition and food assistance

- Consider optional snack slots and configurable diary structure after the V1
  diary is stable.
- Improve nutrition explanations and recommendations only from logged facts,
  known conversions, and explicit uncertainty.
- Prioritize nutrition-label OCR and natural-language meal candidates because
  their extracted structure is reviewable against canonical food records.
- Keep generic Food Photo Estimate later; reintroduce it only when results have
  source/uncertainty handling and an explicit user confirmation step.
- Build “What can I eat?” from deterministic remaining targets, constraints,
  and available canonical foods; AI may explain or rank safe candidates but
  cannot invent their nutrition.

### 4.6 Coaching and health context

- Treat festival-aware, travel-aware, eating-out, and intermittent-fasting
  coaching as separate contextual capabilities, not one generic mode switch.
- Preserve deterministic numeric authorities and user overrides; generated
  language may explain a recommendation but does not change targets silently.
- Use sleep, steps, and active-energy data only when HealthKit, Health Connect,
  or another approved provider supplies authoritative provenance.
- Prefer descriptive recovery context over an invented numeric readiness score.

### 4.7 Data protection and multi-device continuity

- Add automatic encrypted cloud backup before attempting bidirectional sync.
  Keep manual local export/restore and make backup status/recovery legible.
- Add optional account-backed multi-device sync with local-first writes, a
  durable outbox, idempotent remote operations, tombstones, conflict policy,
  schema/content-version compatibility, and observable last-sync state.
- Sync only approved user-owned domains. Preserve source/event identity and do
  not collapse incompatible records because their display text matches.
- Treat authentication, encryption/key recovery, account deletion, remote data
  retention, export, and device revocation as product requirements rather than
  backend details.

### 4.8 Connected food, plans, and media acquisition

- Extend local food search with clearly separated online/branded results. Once
  the user confirms a normalized record, cache it for offline reuse.
- Add barcode lookup through local cache first, then an online provider, with
  source/serving/nutrient review before logging.
- Prefer nutrition-label OCR with user review over generic meal-photo estimates
  when prioritizing trustworthy image assistance.
- Import recipes from URLs into the canonical ingredient/quantity model and
  require review of unresolved ingredients or conversions.
- Stream licensed exercise videos and allow explicit downloads or plan-scoped
  media packs; offline stills/instructions remain the fallback.
- Offer online plan discovery and optional plan revisions. Downloaded plans are
  local versioned plans, and an active plan is never silently mutated.

### 4.9 Versioned content and connected intelligence

- Deliver exercise/food catalogue changes as signed, versioned, rollback-safe
  content packs with provenance and compatibility metadata.
- Use remote configuration for safe rollout, content placement, and banners,
  never to redefine canonical nutrition/workout rules outside versioned app
  logic.
- Translate natural-language meals into candidate canonical foods and AI plan
  requests into validated proposals using existing exercise IDs.
- Let AI select/explain deterministic “What can I eat?” candidates and coaching
  recommendations; IndiFit computes values and owns the decision record.
- Normalize direct Garmin/Fitbit/Strava/WHOOP/Oura/Polar imports into local
  evidence so imported history remains useful offline.

### 4.10 Sharing, collaboration, operations, and business

- Start sharing with an on-device factual workout card, then consider optional
  web links without requiring an account for local image sharing.
- Add coach review or plan changes only through explicit user consent, scoped
  data sharing, audit history, and review-before-apply behavior.
- Prefer verified trainer content over open community advice. Friends and group
  challenges should reward sustainable consistency, not maximum load, calorie
  burn, or daily training at any cost.
- Use opt-in crash/performance diagnostics and minimal product events that do
  not upload fitness records unnecessarily.
- Account-backed premium entitlement may fund connected services, but basic
  offline workout, food logging, stored history, and core Progress remain part
  of the product identity.

## 5. Connected feature priority

This ordering applies within the connected portfolio. It begins after the V1
release and deterministic engineering gate; it does not move connected work in
front of production reliability.

| Rank | Connected initiative | Why it comes here |
|---:|---|---|
| 1 | Automatic encrypted cloud backup | High trust/value with a bounded one-way model; proves cloud security and restore |
| 2 | Optional account and multi-device sync | Major continuity benefit; deliberately follows backup and conflict design |
| 3 | Online/branded food search with local cache | Extends a daily core job while preserving the local search path |
| 4 | Barcode lookup | Fast acquisition using the same food normalization/provenance boundary |
| 5 | Exercise video streaming and downloads | High training value without inflating the base install |
| 6 | Signed exercise/food catalogue updates | Makes content extensible between app releases and supports ranks 3–5 |
| 7 | Natural-language meal candidates | High-value AI translation into reviewable canonical foods |
| 8 | AI plan drafts from canonical exercise IDs | Differentiating acquisition tool whose accepted result is fully local |
| 9 | Direct fitness-provider integrations | Broadens authoritative evidence and keeps normalized imports offline |
| 10 | Workout share cards, then optional links | Engagement/acquisition with a safe factual local starting point |
| 11 | Contextual connected coaching | Richer explanations and live context over deterministic recommendations |
| 12 | Coach/trainer sharing | Strong potential value and monetization; requires granular consent/audit |
| 13 | Friends and sensible group challenges | Retention layer after identity/sync and anti-incentive rules exist |
| 14 | Generic food-photo estimation | Useful but hardest to make truthful; nutrition-label OCR should precede it |

Recipe URL import, online plan discovery/versioning, nutrition-label OCR, and
downloadable media packs are adjacent acquisition capabilities. They should be
scheduled with the shared catalogue/review/download foundations rather than
forced into a separate rank solely for marketing visibility.

Lower-priority connected options include cardio route/weather enrichment,
supported music providers, verified trainer plan marketplaces, moderated
community tips, and broader social feeds. Observability, privacy controls,
remote-content safety, account deletion, and entitlement infrastructure are
enablers—not reasons to make the offline core contingent on an account.

## 6. Prerequisite-gated initiatives

These initiatives are valid candidates, but they are not ready to implement by
unhiding legacy widgets or wiring dormant code.

| Initiative | Required prerequisite | Release gate |
|---|---|---|
| **Automatic cloud backup** | Provider/account decision, encryption and key-recovery threat model, immutable snapshot format, retention policy, background scheduling, remote deletion, restore verification | Local/manual backup remains available; upload loss or outage cannot block or corrupt local data |
| **Multi-device sync** | Stable global identity, change/outbox model, tombstones, conflict semantics per domain, auth/device revocation, remote schema compatibility, reconciliation and observability | Core writes commit locally first; retry/replay is idempotent; convergence and data-loss tests pass |
| **Online food/barcode lookup** | Approved providers, typed normalization, provenance, serving/nutrient validation, caching and correction policy | Remote result remains distinct until reviewed; cached record works offline |
| **Nutrition-label OCR** | Image consent/transmission boundary, field-level OCR confidence, canonical serving/unit mapping, editable review | Nothing is saved or logged until the user confirms extracted fields |
| **Recipe URL import** | Safe fetch/parser boundary, canonical ingredient matching, unit/conversion review, source attribution | Unresolved ingredients are explicit and editable before recipe creation |
| **Online/downloaded exercise media** | Approved streaming/distribution licenses, exact exercise binding, download storage/eviction, integrity and offline fallback | Failed/expired download never removes local instruction/still fallback |
| **Signed content/catalogue updates** | Signing keys, manifest/version compatibility, atomic activation/rollback, provenance and local override policy | Invalid/incompatible packs are rejected; active personal history remains readable |
| **Online plan catalogue/versioning** | Signed source/version model, canonical plan import validation, diff/review semantics | Download produces a local plan; updates never silently mutate active plans |
| **Hydration** | Canonical daily log, target, history, date/time, unit, edit/delete, backup/restore, and cross-surface read authorities | Today, Progress, quick logging, and reminders use the same domain and treat unknown as unknown |
| **Richer packaged exercise stills** | Approved source/license, exact canonical exercise binding, human review, attribution, offline fallback, package/performance evidence | Unapproved or unmatched media always fails closed |
| **Playlist/music integration** | Supported provider/product decision, lifecycle and privacy behavior, and useful failure states | No placeholder URL or empty-provider setting becomes visible |
| **Complete “Delete all data”** | Inventory and tested erasure of DB, preferences, backups, caches/imports, secrets, and relevant integration state | The product can verify the promise it presents |
| **Food Photo / Describe with AI** | Typed review contract, uncertainty/source handling, consent/privacy boundary, correction flow, offline failure behavior | Nothing persists as canonical until the user reviews and confirms it |
| **“What can I eat?”** | Deterministic candidate and constraint engine over canonical food data and remaining targets | Suggestions disclose missing inputs and never invent conversions or nutrients |
| **AI plan drafts** | Typed proposal schema over canonical exercise IDs, catalogue/rule validation, constraint handling, diff/review flow | User approval creates a local versioned plan; provider output never writes plan tables directly |
| **Contextual coaching** | Canonical context inputs, bounded rules, evidence, opt-in/override behavior, and non-medical review | AI wording cannot become the numeric decision engine |
| **Direct provider integrations** | Provider-specific consent/tokens, stable external identity, deduplication, provenance, revocation/deletion and normalization | Imported evidence remains attributable and locally readable offline |
| **Coach/social features** | Account/sync maturity, scoped sharing/consent, moderation/safety, audit/revoke/delete behavior | Remote suggestions require review; challenges cannot reward unsafe or fabricated metrics |
| **Canonical PR events** | New event identity and evidence architecture based on actual logged performance | No reuse of the removed inferred-PR implementation |

## 7. Explicitly removed or superseded—not backlog

The following items were rejected for product-truth or architecture reasons.
They must not appear in a feature sprint unless a new product decision defines
a different canonical system.

- The old Epley/synthetic e1RM path.
- Inferred PR badges, synthetic PR events, unsupported PR celebrations, and PR
  CSV output derived from that inference.
- Beginner/intermediate/etc. strength standards without a credible authority.
- Homemade workout calorie formulas, including duration-times-constant models.
- Numeric readiness or recovery scores invented from incomplete inputs.
- The old explicit Travel Mode UI; contextual travel-aware coaching is a
  separate possible feature.
- The superseded dashboard architecture and its dormant widgets.

Workout energy may be shown later only when an approved health or wearable
authority provides it. A future PR product must be a newly specified canonical
event system; the removed inference code is not its foundation.

## 8. Engineering evolution after V1.1

These tracks support product work but should remain separate from behavior
changes and from one another.

### App composition and time authorities

- Split the provider registry into feature-owned modules and simplify app/root
  router composition.
- Inject `SharedPreferences`, civil-date, clock, and timezone services.
- Centralize preference keys without renaming persisted keys.
- Reduce direct `DateTime.now()` use at domain and test boundaries.

### Routing

- Classify true app destinations versus local/modal routes.
- Move toward consistent GoRouter composition and typed payloads.
- Sunset legacy workout/player routes only after usage and compatibility
  evidence confirms they are retired.

### Persistence

- Extract migration helpers, seeders, indexes, and connection/lifecycle code
  from `AppDatabase` without changing migration behavior.
- Preserve repository façades while adding focused internal query, mapping,
  and validation collaborators.
- Gradually replace presentation dependence on raw generated Drift rows with
  bounded read models.

### Backup architecture

- Consolidate table specifications and validation primitives while keeping
  historical decoders immutable.
- Prove byte/semantic export compatibility and restored database equivalence
  before and after each refactor.
- Keep backup refactors isolated from ordinary persistence cleanup.

### Performance

Profile cold startup, Today scrolling, food search, fast logging, workout set
entry, rest timing, Progress, and backup/restore before optimizing. Changes
such as narrower database invalidation, Riverpod `select`, bounded history,
pagination, or indexes require measurements and, for indexes, query-plan
evidence. Truly unreachable polling or callback code should be retired rather
than optimized.

### Backend and dependencies

- Modularize backend config, schemas, auth/rate limiting, provider clients,
  routers, fallback data, application factory, HTTP lifecycle, and response
  validation in bounded steps.
- Treat distributed rate limiting as a separate design decision.
- Upgrade Flutter, Riverpod, Drift, GoRouter, and platform plugins in small
  dependency-family batches after architecture work, never as one combined
  refactor/upgrade release.

### Connected platform foundations

- Define capability boundaries so the core app has no dependency on account,
  connectivity, sync, remote config, analytics, or entitlement providers.
- Add durable background-job/outbox primitives with idempotency, exponential
  backoff, bounded retention, user-visible recovery, and deterministic tests.
- Centralize typed network clients, authentication/token storage, request
  correlation, redaction, retry policy, and server/content compatibility.
- Separate immutable backup snapshots from bidirectional sync operations; they
  solve different problems and have different conflict/recovery semantics.
- Define cache ownership, freshness, eviction, integrity, provenance, and local
  override behavior for food, media, plans, and signed catalogue packs.
- Establish privacy-minimized observability before connected rollout; fitness
  payloads are excluded from ordinary analytics and crash breadcrumbs.

## 9. Portfolio decision rules

Use the following order when choosing the next item:

1. Production trust and data integrity.
2. Work that makes tests deterministic or removes a blocker for multiple later
   initiatives.
3. Small improvements to an existing, healthy consumer loop.
4. Data protection that strengthens offline ownership.
5. Additive features backed by an existing canonical authority.
6. Connected acquisition whose accepted output becomes useful offline.
7. New domains, external providers, collaboration, and AI features after their prerequisite
   specifications are approved.

Defer an item when its data source is unclear, its missing-data semantics are
undefined, it would create a second authority, its licensing is unresolved, or
its value depends on inventing precision.

## 10. Roadmap success measures

The roadmap is succeeding when:

- the serial test lane is repeatable and failures are attributable;
- production reliability fixes remain isolated from feature development;
- structural refactors preserve observable behavior and reduce file/ownership
  concentration;
- cleanup reduces change blast radius, global dependencies, and ambiguous
  ownership; reduced line count by itself is not success;
- completion, progress, and planning surfaces expose more useful real evidence;
- every new provider or AI surface fails closed and remains user-reviewable;
- core journeys pass an explicit no-network acceptance matrix and never wait on
  account/sync/analytics services;
- automatic backup and sync report pending/last-success/error state while local
  writes remain immediate and replay-safe;
- confirmed online foods, downloaded plans/media, content packs, and imported
  provider evidence remain useful offline;
- remote config or entitlement loss cannot disable or redefine the offline core;
- no removed synthetic metric reappears through legacy code;
- hydration or complete erasure ships only after its full domain promise is
  demonstrably true.

## 11. Already completed—do not recreate

Older plans may still list the following as future work, but the R08 completion
pass delivered them:

- onboarding payoff and first-session Today handoff;
- manual nutrition target editing and history;
- compact Today date navigation;
- editable notification schedules;
- exercise base/variant hierarchy and search-first exercise picker;
- richer workout set logging and coaching progressive disclosure;
- Health connect-first hierarchy and Progress sparse-state redesign;
- distinct meal picker identity and common-food search improvements.

Before opening any roadmap item, verify current production behavior and record
whether the source plan is current, stale, superseded, or already implemented.
