# IndiFit R08 Master Implementation Roadmap

**Status:** FINAL planning baseline for R08 implementation  
**Prepared:** 2026-08-20  
**Decision baseline:** frozen product audit + Flash R08-0 readiness audit + Sol R08-0 final decision review  
**Purpose:** Convert the frozen manual product audit into an executable, multi-agent, dependency-ordered release program without reopening settled product/domain decisions.

---

## 1. Source-of-truth hierarchy

Use these in order when an implementation decision conflicts:

1. Canonical B01–B05 domain decisions and persisted authority.
2. Frozen Product Audit & Redesign Reference Manual.
3. R08-0 Final Pre-Implementation Decision Review.
4. This R08 Master Implementation Roadmap.
5. Wave/task implementation notes.

The frozen audit remains historical product evidence. During R08, implementation/review state belongs in the companion `R08_AUDIT_TRACEABILITY.csv` rather than by rewriting frozen observations.

### Binding product rules

- Feature completeness does not imply feature prominence.
- Complexity belongs underneath the interface, not inside it.
- Results first; explanation second.
- One obvious primary action per screen.
- AI is an accelerator, never a dependency.
- Advanced capability uses progressive disclosure.
- Internal B01/B02/B03/B04/B05 terminology never appears in consumer UI.
- Unknown is not zero.
- No unsupported workout calorie estimates.
- No unsupported e1RM or synthetic PR authority.
- No numeric readiness/recovery score.
- External datasets never override IndiFit canonical identity, taxonomy, training, nutrition, or history.
- Exercise visuals fail closed. Wrong artwork is worse than no artwork.
- Physical-device acceptance is manual after agent work; agents do not use device testing as a completion requirement.

---

## 2. Fixed macro sequence

```text
R08-0  External Asset & Visual Foundation
  ↓
R08A   Correctness & Shared Defects
  ↓
R08B   Workout Execution 2.0
  ↓
R08C   Training 2.0
  ↓
R08D   Food 2.0
  ↓
R08E   Today + Onboarding + Nutrition Targets
  ↓
R08F   Progress 2.0
  ↓
R08G   Settings + Advanced 2.0
  ↓
R08H   Cross-App Product Polish
  ↓
R08RC  Release Candidate Acceptance
```

Why: R08-0 creates shared visual/legal primitives; R08A fixes bad state before redesign; R08B normalizes evidence production; R08C builds planning around the final execution contract; R08D stabilizes nutrition logging; R08E summarizes stable Training/Food; R08F interprets trustworthy evidence; R08G reflects the final consumer model; R08H does cross-cutting finish; R08RC proves the frozen audit.

---

## 3. Release classes

- **BLOCKER** — correctness, data authority, data loss, licensing, or readability defect. RC cannot pass without it.
- **CORE** — required for the frozen redesign to be considered implemented.
- **POLISH** — high-value P2/P3 work; implement unless it threatens BLOCKER/CORE stability.
- **POST-V1** — intentionally deferred or requires a new domain/safety/product decision.

---

## 4. Multi-model operating model

| Work profile | Primary implementer | Typical fresh reviewer |
|---|---|---|
| Broad deterministic audit/mapping/repetitive refactor/tests | Gemini Flash 3.7 High | Sol High or Terra Max |
| Medium bounded Flutter/UI | GLM 5.3 High | Terra Max |
| Large multi-file stateful architecture | GLM 5.3 Max | Sol High |
| Deep existing-repo Flutter integration | Luna Max | Terra Max / Sol High |
| Product/visual acceptance | Terra Max | Human final acceptance |
| Canonical/domain/lifecycle/persistence | Sol High | Human for unresolved product/legal decisions |

Per package:

```text
read spec/context
→ implement
→ targeted tests
→ ONE fresh focused review-and-resolve
→ merge task
→ wave integration tests
→ ONE wave-level review-and-resolve
→ merge wave
```

Do not run repeated generic review loops. One owner controls shared hotspots at a time: B05 media contracts, exercise identity/fixtures, workout execution state, nutrition target authority/history, `pubspec.yaml`, navigation shell, and Progress aggregation.

Recommended branch convention: `r08-0/<task>`, `r08a/<task>`, `r08b/<task>`, etc. Task branches merge into a wave integration branch; the wave merges to main only after its gate.

---

# PART I — R08-0: External Asset & Visual Foundation

**Goal:** legally reproducible, offline-first visual foundation; no product-surface redesign.  
**Overall size:** Medium.  
**Release role:** foundation CORE + licensing BLOCKER.

### R08-0.1 — Source pinning, provenance, attribution, one manifest authority
- **Class:** BLOCKER | **Size:** M
- **Implement:** Sol High | **Review:** Terra Max; human for unresolved legal interpretation
- Pin immutable RepDB and MuscleMap commits/tags, acquisition date, license/version, attribution, prohibited uses.
- Create/maintain `docs/legal/THIRD_PARTY_ASSETS.md`, `LICENSES/`, and one B05-compatible checked-in manifest.
- Validators: unknown UUID, duplicate key/path, missing/unexpected file, checksum mismatch, missing approval.
- Record openGym clean-room/reference-only boundary.
- No unapproved assets, runtime license engine, or screen redesign.

### R08-0.2 — RepDB mapping finalization + contact-sheet approval
- **Class:** BLOCKER for any RepDB mapping | **Size:** M
- **Implement:** Flash High | **Review:** Terra Max blinded visual review | **Final approval:** human
- **Depends on:** 0.1
- Re-run mapping against pinned snapshot.
- Target **34 candidate physical-movement mappings**; Decline Hammer Strength Press family is explicit fallback.
- Generate 35-card gallery with IndiFit UUID/name/equipment/primary muscle, all variant UUIDs proposed to reuse art, RepDB ID/name, actual START/PEAK or MAIN images, conflicts, notes, confidence, approval/rejection.
- Current CSV remains CANDIDATE only.
- No extra RepDB variants in R08-0.

### R08-0.3 — B05 visual registry + local RepDB pipeline + reusable exercise visual widget
- **Class:** CORE | **Size:** M–L
- **Implement:** GLM 5.3 Max | **Review:** Sol High
- **Depends on:** 0.1 + approved 0.2; uses 0.5/0.6 fallbacks
- Evolve existing B05 contracts; do not create a parallel media system.
- Preserve 140 canonical UUID identities. No `baseMovementVisualKey` in domain/database/backup.
- Manifest supports reusable `visual_asset_set` and explicit `exercise_binding: canonical UUID → asset set`.
- Fixed fallback: approved local art → canonical muscle visual → equipment/movement semantic icon → neutral.
- No fuzzy runtime mapping or external metadata authority.
- Measure real raw bytes, package delta, image timing/cache/memory and dense-list scroll behavior; Flash estimates are not release facts.

### R08-0.4 — Canonical primary/secondary display resolver + Exercise Library correctness
- **Class:** BLOCKER/CORE | **Size:** S–M
- **Implement:** GLM 5.3 High | **Review:** Sol High
- First valid ordered display muscle = primary; remaining = secondary.
- Counts and browsing share this resolver.
- Secondary remains detail/search information where deliberately supported.
- B02 `ExerciseMuscleMappings` remains muscle-allocation arithmetic authority.
- No B02 taxonomy expansion, DB migration, weight reseeding, or external taxonomy import.

### R08-0.5 — `IndiFitMuscleMap` foundation
- **Class:** CORE | **Size:** L
- **Implement:** GLM 5.3 Max | **Review:** Terra Max visual/a11y + Sol High taxonomy boundary
- **Depends on:** provenance 0.1; semantics may use 0.4
- Use pinned MuscleMap MIT geometry as primary geometry source.
- Local renderer: male/female, front/back/both, primary/secondary mode, caller-provided heat/intensity mode, no-data state, explicit IndiFit taxonomy adapter, light/dark, accessibility, static/reduced-motion-safe behavior, goldens/semantics/path tests.
- No Progress/Training/player product integration in this wave.

### R08-0.6 — Minimal `IndiFitIcons` facade
- **Class:** CORE | **Size:** S
- **Implement:** Luna Max | **Review:** Terra Max
- Prefer Material; add Phosphor only for a concrete semantic gap and pin/license it.
- Forward-only for new R08 components; no app-wide migration.

### R08-0 wave gate
- Reproducible provenance/approval state.
- Candidate CSV cannot ship directly.
- B02 taxonomy unchanged.
- Primary-muscle browsing fixed.
- Muscle renderer remains foundation-only.
- Visual widget fails closed.
- No AGPL code/assets or unverified exercise imagery enters production.
- Wakelock contract is documented; runtime ownership remains for R08B.

---

# PART II — R08A: Correctness & Shared Defects

### R08A.1 — One date-scoped nutrition target authority
- **Class:** BLOCKER | **Size:** L
- **Implement:** GLM 5.3 Max | **Review:** Sol High
- Today, Food and Progress use the same per-date target authority.
- Preserve historical semantics, manual/recalculated source, restart persistence, unknown-as-unknown and invalidation when profile/goal/manual target changes.

### R08A.2 — Training/Today invalidation + Next Up correctness
- **Class:** BLOCKER | **Size:** L
- **Implement:** Luna Max | **Review:** Sol High
- Plan activation, completion, partial, draft/resume, skip/cancel, finish/leave and reschedule propagate immediately without relaunch.
- Fix canonical B01/B02 read/invalidation path; no Today-local guesses.

### R08A.3 — Workout timer/resume/completion idempotency
- **Class:** BLOCKER | **Size:** L
- **Implement:** GLM 5.3 Max | **Review:** Sol High
- Continuous timer repaint; authoritative resume time; lifecycle-safe elapsed state; failed completion preserves draft; Retry idempotent; exactly one completed history record.

### R08A.4 — Shared high-frequency UI defects
- **Class:** BLOCKER/CORE | **Size:** M
- **Implement:** Flash High | **Review:** Terra Max
- Food success Snackbar finite/theme-correct/Undo readable.
- Edit feedback says Updated, not Added.
- Quantity sheet no flicker.
- Recipe header light mode fixed.
- Progress Log Weight heading/label fixed.
- Shared dark/light feedback treatment.

### R08A.5 — Guard ordering + error-language correctness
- **Class:** CORE | **Size:** M
- **Implement:** GLM 5.3 High | **Review:** Sol High
- Active-workout blocker before out-of-date confirmation; known reasons do not collapse into generic unavailable; destructive semantics and human draft language.

### R08A gate
Targeted correctness tests + full serial suite. No redesign may hide unresolved authority/lifecycle defects.

---

# PART III — R08B: Workout Execution 2.0

### R08B.1 — Shared Quick/Planned execution shell
- **Class:** CORE | **Size:** XL
- **Implement:** GLM 5.3 Max or Luna Max as single integration owner
- **Review:** Sol High state + Terra Max UX
- Quick/Planned differ mainly in initialization; logging/rest/edit/replace/review converge.

### R08B.2 — Compact editable set table
- **Class:** CORE | **Size:** L
- **Implement:** GLM High/Max | **Review:** Terra Max
- Planned rows visible together; current obvious; edit/delete logged sets; add/remove extra sets; prescribed vs extra distinction; totals update after correction.
- Target row: `Set | Type | Previous/Target | Weight | Reps/Duration | Effort | Status`.

### R08B.3 — Evidence-backed defaults
- **Class:** CORE | **Size:** L
- **Implement:** GLM Max | **Review:** Sol High
- Priority: plan prescription → exact comparable previous performance → accepted adaptive evidence. Never invent load.

### R08B.4 — Replace exercise + shared picker
- **Class:** CORE | **Size:** L
- **Implement:** Luna Max | **Review:** Sol High + Terra Max
- Search + primary muscle + equipment-compatible context.
- Before logs: normal replacement. After logs: preserve logged evidence; replacement governs remaining work.
- Render actual performed exercise UUID after substitution.

### R08B.5 — B02 advanced semantics consumer reconciliation
- **Class:** CORE | **Size:** L
- **Implement:** Sol High / GLM Max
- Warm-up vs Working; supported set techniques; Superset/Circuit/Giant Set as exercise grouping; RPE optional/plain-language; no RIR without canonical decision; timed work only where existing authority supports it; bodyweight/perImplement/perSide preserved exactly.

### R08B.6 — Rest + stable layout + session-wide wakelock
- **Class:** CORE | **Size:** M–L
- **Implement:** GLM High/Max | **Review:** Sol High lifecycle + Terra Max visual
- Preserve −15/+15/Skip; add stable circular progress; no title/set jumps.
- One active-session `wakelock_plus` owner. Rest modal cannot disable a session-owned lock. Plugin errors never block workout persistence.

### R08B.7 — Exercise context, real cues and visuals
- **Class:** CORE/POLISH | **Size:** M
- **Implement:** Flash High | **Review:** Terra Max
- Logging action stays above fold; Last time/setup/cues lower; real cues or hide; exact approved illustration only; muscle visual only if uncluttered.

### R08B.8 — Workout progress, review and completion evidence
- **Class:** CORE | **Size:** L
- **Implement:** Luna Max | **Review:** Sol High + Terra Max
- Truthful duration, exercises, working/warm-up sets, reps/duration, actual loads, compatible volume, substitutions, grouped/special distinctions, best factual set where meaningful.
- No e1RM, synthetic PR or workout calorie estimate.

### R08B gate
Automated scenarios: planned 4-set, Quick, edit/delete, extra set, replacement before/after logs, rest, pause/resume, failed save/retry, grouped work, bodyweight/per-side/timed supported cases, light/dark, 320–430 widths, large text.

---

# PART IV — R08C: Training 2.0

### R08C.1 — Training Home: one dominant current action
- **CORE | M–L | Luna Max → Terra Max**
- Active draft appears once as dominant Resume; remove duplicate current-plan/Today/workout cards; interactive week can sit beneath.

### R08C.2 — Workout Preview + per-day customization
- **CORE | L | GLM Max → Sol + Terra**
- Future tap = preview/edit/schedule, not immediate execution.
- Replace/add/remove exercises, edit sets/reps, rest-day/reschedule; deliberate apply-to-future path never rewrites history.

### R08C.3 — Plan Library / Change Plan
- **CORE | M | GLM High → Terra**
- `Change Plan` opens chooser/library with clear custom-plan path.

### R08C.4 — Custom Plan Builder consumer shell
- **CORE | XL | GLM Max → Sol + Terra**
- Keep B01 versioning underneath; consumer concepts only: name, days, workouts, exercises, sets/reps, save/use. No draft-version/activation jargon.

### R08C.5 — Calendar Day/Week/Month + occurrence semantics
- **CORE | L | GLM High/Max → Terra + Sol**
- True month grid, meaningful Week, Today/This week/This month, historical missed/partial vs active draft, no duplicate Start/Resume overflow.

### R08C.6 — Equipment Profiles + substitutions
- **CORE | M | Flash/GLM High → Terra**
- First-use setup, presets, explain purpose, increments only where meaningful.

### R08C.7 — Manual completed workout + Other Activity decision
- **CORE | L | Luna Max → Terra**
- Manual workout uses shared picker/multi-select/compact rows.
- Other Activity becomes explicit retrospective `Log other activity` or is hidden. Remove from Manage Plan.

### R08C.8 — Exercise Library/Detail + approved visuals + Plate Calculator consolidation
- **CORE/POLISH | L | GLM High → Terra**
- Primary-muscle browsing, base-before-variant hierarchy, denser discovery, approved illustration/muscle visual, performance entry, one Plate Calculator, compact empty Performance.

### R08C.9 — Plan overview + workout history
- **CORE | M | Flash High → Terra**
- Real plan progression/schedule/next workout; history shows exercises/sets/duration/valid volume, not lifecycle audit noise.

### R08C.10 — Remove Travel Mode from normal UI
- **CORE removal | S | Flash High → Terra**
- Underlying code may remain if safer; normal entry point disappears.

---

# PART V — R08D: Food 2.0

### R08D.1 — Diary hierarchy/date/compact target summary
- **CORE | M | GLM High → Terra**
- Shared compact date control; compact daily budget/macros; meals dominant; food rows directly visible/manageable; no duplicate giant Today hero.

### R08D.2 — Search relevance + dense results
- **CORE | L | GLM Max → Sol + Terra**
- Regression queries: poha, dosa, rice. Canonical/local/common before weak remote/brand noise. Clean metadata and scan-friendly rows.

### R08D.3 — Recent/Frequent + quantity/unit repeat flow
- **CORE | M | Flash High → Terra**
- Bound Recent; show repeated quantity; unsafe/ambiguous repeat opens quantity; relevant unit defaults; supported conversions only; never invent household grams.

### R08D.4 — Direct edit + duplicate consolidation + hide batch abstraction
- **CORE | L | Luna Max → Sol + Terra**
- Direct logged-food correction; Updated feedback; compatible same-canonical-food rows may consolidate; no name-based merge; atomic batch persistence remains invisible; rows independently manageable.

### R08D.5 — Explicit multi-select + meal visual identity
- **CORE/POLISH | M | Flash High → Terra**
- Default one obvious Add interaction; checkboxes only in explicit multi-select; distinct Breakfast/Lunch/Dinner/Snacks visuals.
- Optional extra snack slots are an R08D product decision; do not expand defaults automatically.

### R08D.6 — Saved Meals consumer rewrite
- **CORE | M–L | GLM High → Terra**
- Search-first builder; Recent/Frequent/categories may assist; unknown nutrition stays unknown without repeated consent friction.

### R08D.7 — Recipes consumer rewrite
- **CORE | M | Flash/GLM High → Terra**
- Cooking language, compact builder, light/dark correctness.

### R08D.8 — Hide unavailable AI paths + danger/copy cleanup
- **CORE | S–M | Flash High → Terra**
- Hide Describe with AI/Photo Estimate while unavailable; preserve distinct flows and truthful disclosure when enabled; danger styling for destructive actions.

---

# PART VI — R08E: Today + Onboarding + Nutrition Targets

### R08E.1 — Personalized onboarding payoff
- **CORE | M | Flash/GLM High → Terra**
- Keep onboarding short; add actual configured facts + Adjust actions. No-name flow never shows bare `Hi`.

### R08E.2 — Nutrition Targets hub
- **CORE | L | GLM Max → Sol + Terra | depends A.1**
- Calorie ring opens current calories/macros, grams, synchronized percentages/calorie contribution, manual values, reset/recommended only if canonical, useful source context without formula internals.

### R08E.3 — Today header/date/density
- **CORE | M | Luna Max → Terra**
- Full greeting fallback; compact historical navigation; light hierarchy as reference; ~25–35% shorter common states as visual target, not hard metric.

### R08E.4 — Conditional Next Up / Activity / Progress evidence
- **CORE | L | GLM High → Sol + Terra | depends A.2**
- Next Up only when genuinely actionable; no duplicate Food/Workout CTA; Activity/Progress show compact real evidence or hide; no fabricated steps/calories.

### R08E.5 — Nutrition hero cleanup + Meal ideas gating
- **CORE/POLISH | M | Flash High → Terra**
- Better semantic color differentiation; one concise incomplete-data note; Meal ideas hidden/de-emphasized until genuinely useful.

### R08E.6 — Customize Today consumer rewrite
- **CORE | M | GLM High → Terra**
- Reorder, show/hide, reset default. No position/admin language.

### R08E.7 — Hydration V1 gate
- **Decision / optional CORE**
- Human + Sol support. Ship only with real persisted daily authority. If approved: compact Today quick log, Settings owns goal/serving config, general-estimate wording. Otherwise no dead module.

---

# PART VII — R08F: Progress 2.0

### R08F.1 — Compact dynamic highlights shell
- **CORE | M | Luna Max → Terra**
- Replace duplicated giant Overview with 3–4 useful current facts; hide unavailable evidence.

### R08F.2 — Training consistency semantics + drill-down
- **CORE | L | GLM Max/Sol → Sol + Terra**
- Distinguish sessions, distinct training days, and plan adherence only where known; inspectable history.

### R08F.3 — Strength actual-performance trends
- **CORE | L | GLM Max → Sol + Terra | depends R08B evidence**
- Actual load/reps/set history, latest vs previous, best factual set and useful session comparison. No e1RM/invented PR badge.

### R08F.4 — Body weight trend + quick logging
- **CORE | M | Flash High → Terra**
- Trend only with enough measurements; goal line/progress where valid; sparse one-entry state; preserve quick +/-; date/backfill only if current authority supports it.

### R08F.5 — Nutrition adherence
- **CORE | M–L | GLM High → Sol + Terra | depends A.1**
- Fully logged/complete days, avg calories, avg protein, protein-goal days. Incomplete days excluded, not treated as low intake.

### R08F.6 — Training volume trend boundaries
- **CORE/POLISH | M | GLM High → Sol**
- Compatible actual volume only; unknown/unweighted/bodyweight evidence never coerced to zero.

### R08F.7 — Interactive charts + muscle heatmaps
- **CORE/POLISH | L | GLM Max → Terra + Sol | depends 0.5**
- Existing `fl_chart`/painters first; period controls only with enough data; touch exact values; no giant empty charts; muscle-map metric/range/unknown semantics explicit.

### R08F.8 — Achievement feedback + restrained tiering
- **POLISH | M–L | GLM High → Sol + Terra**
- Existing unlocks become visible only after safe save and never interrupt live workout.
- Tiers only for stable measurable thresholds and idempotent unlocks.
- Broad new badge catalog remains POST-V1 unless separately approved.

---

# PART VIII — R08G: Settings + Advanced 2.0

### R08G.1 — Destination ownership + top-level summaries
- **CORE | M | Luna Max → Terra**
- Preserve strong shell; one canonical destination per concept; summaries explain why each setting matters.

### R08G.2 — Fitness Goal → Nutrition Targets → optional Coaching
- **CORE | L | GLM Max → Sol + Terra**
- Goal=outcome, Targets=current numbers, Coaching=optional suggestions; Keep current vs Recalculate; no silent overwrite; truthful missing-DOB copy; compact opt-in; meaningful history only.

### R08G.3 — Dietary needs + household measures + regional food preferences
- **CORE | L | GLM High → Sol + Terra**
- Dietary entry asks food/constraint, reason, strictness; advanced cross-contact only when relevant.
- Household groups known volumes/common serving labels/user-calibrated containers; preserve volume ≠ weight.
- Move regional foods out of Data/Backup and present as Food/Nutrition preference.

### R08G.4 — Health integration
- **CORE | L | GLM Max/Luna → Sol + Terra**
- Platform-aware provider, one connection route, clear state, granular permissions after connection; imported data never silently changes targets/adherence/achievements.

### R08G.5 — Notifications + Quiet Hours
- **CORE | M | Flash High → Terra**
- Editable schedules; clarify Evening Log Nudge; unavailable AI report/reminder controls hidden/gated.

### R08G.6 — Backup/export/privacy/danger
- **CORE | L | Luna Max → Sol + Terra**
- Structure: Backup / Export / Privacy / Danger. Remove backend/SQLite/telemetry/schema jargon. Reset onboarding distinct from delete-all-data. Include third-party credits/attribution under About/Settings.

### R08G.7 — Deep-settings density/theme/accessibility
- **CORE/POLISH | M | Flash High → Terra**
- Denser grouped rows; 320–430 widths; large text/keyboard; clear loading states; light/dark parity; no clipped labels.

---

# PART IX — R08H: Cross-App Product Polish

### R08H.1 — Theme/surface/feedback consistency
**CORE/POLISH | Flash High → Terra** — dialogs, sheets, snackbars, errors, danger semantics, dark surfaces, loaders.

### R08H.2 — Responsive/accessibility pass
**CORE | Flash High → Terra** — 320–430 pt widths, target large-text states, keyboard-open, semantics, touch targets, reduced motion, contrast.

### R08H.3 — Controlled icon migration
**POLISH | Flash High → Terra** — redesigned surfaces through `IndiFitIcons`; remove obvious inconsistent leftovers; no churn for its own sake.

### R08H.4 — Density, empty states, copy, micro-interactions
**POLISH | GLM High → Terra** — no giant empty cards, no technical jargon, one primary action, consumer grammar, consistent haptics/motion.

### R08H.5 — Asset/image-cache/chart performance polish
**CORE | GLM High/Max → Sol** — tune only from measurements; no speculative optimization.

---

# PART X — R08RC: Release Candidate Acceptance

### R08RC.1 — Automated/code gate
**Owner:** Flash High for breadth; integration owner resolves.
- `flutter analyze`
- full serial tests
- relevant goldens/semantics
- release builds
- no unexplained regression beyond explicitly documented baseline

### R08RC.2 — Canonical/domain gate
**Owner:** Sol High.
Audit B01–B05 authority, exact exercise identity, target history, workout idempotency, unknown ≠ zero, actual substitutions, fail-closed AI, no silent target mutation, and no e1RM/calorie/readiness resurrection.

### R08RC.3 — Asset/license/performance gate
**Owner:** Sol High + human where required.
- pinned sources/licenses/attribution/checksums
- approved contact-sheet record
- no AGPL code/assets
- no prohibited/unverified exercise media
- real package-size/performance evidence
- fallback behavior

### R08RC.4 — Manual real-device acceptance
**Owner:** human.
Run frozen checklists in light/dark, populated/sparse, historical dates, active/resumed workout, error/retry, small phone widths and practical large-text states. Agents do not claim this gate passed.

### R08RC.5 — Traceability + signoff
Every frozen P0/P1/P2 finding becomes IMPLEMENTED+verified, INTENTIONALLY DEFERRED with explicit reason, REMOVED with reason, or NOT APPLICABLE with evidence. Complete implementation/review commits and manual acceptance in `R08_AUDIT_TRACEABILITY.csv`.

---

# PART XI — Explicit POST-V1 / out-of-scope register

Do not pull these into R08 core without a new explicit decision:

- exercise video/GIF media beyond approved static visuals;
- Gym Visual media;
- openGym source/assets;
- synthetic e1RM;
- unsupported PR event system;
- workout calorie formula;
- numeric readiness/recovery score;
- Strong/Hevy/FitNotes imports;
- playlist/YouTube;
- background iOS Live Activity / Android ongoing notification;
- expanded streak-freeze/gamification system;
- broad new achievement catalog;
- festival/travel/eating-out/intermittent-fasting coaching;
- sleep tracker until source authority is specified;
- medication tracker without separate safety specification;
- broad router migration;
- MealTemplates retirement campaign;
- god-file split campaign;
- repo-wide design-token rewrite;
- Travel Mode normal UI;
- unlicensed/unverified exercise images.

---

# PART XII — Dependency map

```text
R08-0.1 → 0.2 → 0.3
    │            ↑
    ├──────→ 0.5┘
    └──────→ 0.6

0.4 ─────────→ R08C Exercise Library
0.5 ─────────→ R08C Exercise Detail
0.5 ─────────→ R08F Heatmaps
0.3 ─────────→ R08B/R08C visuals

R08A.1 → R08E.2
       └→ R08F.5
R08A.2 → R08E.4
R08A.3 → R08B.1

R08B picker/replacement → R08C preview/manual log
R08B normalized evidence → R08F strength trends
R08D stable nutrition → R08E Today → R08F nutrition adherence

R08B–G → R08H → R08RC
```

---

# PART XIII — Parallel execution batches

### Batch 0A
Parallel:
- R08-0.1 Sol High
- R08-0.4 GLM High
- R08-0.6 Luna Max (Material-only facade first)
- R08-0.5 renderer prototype without committing third-party geometry

Then:
- R08-0.2 Flash → Terra → human
- R08-0.3 GLM Max
- R08-0.5 finalized GLM Max

### Batch A
Parallel where files do not collide:
- A.1 GLM Max
- A.2 Luna Max
- A.4 Flash
- A.5 GLM High

A.3 remains single-owner around workout state.

### Batch B
Freeze B.1 execution interface first. Then leaf work may parallelize: set-table widgets, picker UI, rest visual, context/visuals. One integration owner controls execution state.

### Batch C
After B merge, Plan Library, Equipment Profiles and visual Exercise Library leaves may parallelize. C.2/C.4/C.5 use separate owners because they overlap B01 lifecycle/planning.

Later waves parallelize only after shared authority contracts are frozen.

---

# PART XIV — Definition of done per task

A task is done only when:
1. scope/non-scope respected;
2. canonical authority unchanged unless explicitly approved;
3. targeted tests pass;
4. known baseline failures are separated from new failures;
5. affected light/dark states are covered;
6. no internal terminology leaks to consumer UI;
7. error/empty/loading states are intentional;
8. fresh focused review is resolved;
9. branch merges cleanly;
10. traceability row(s) are updated.

---

# PART XV — Immediate next action

**Start R08-0.1 and R08-0.4 in parallel.**

- R08-0.1 freezes provenance/manifest rules before external assets are committed.
- R08-0.4 is independent and fixes a verified Exercise Library correctness defect without changing B02 taxonomy.
- Once 0.1 pins RepDB, start 0.2 candidate regeneration/contact-sheet generation.
- Do **not** start 0.3 production asset integration until the contact sheet passes Terra review and named human approval.

This is where research ends and implementation begins.
