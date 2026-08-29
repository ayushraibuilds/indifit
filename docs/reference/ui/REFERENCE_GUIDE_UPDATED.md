# IndiFit UI Reference Guide

This directory contains screenshot evidence and visual/product references for IndiFit UX work.

Screenshots do **not** override IndiFit's canonical domain architecture, persistence rules, safety requirements, business logic, or established implementation authorities.

The screenshot library contains material from different generations and for different purposes. Agents must identify what a screenshot represents before using it.

---

# 1. Authority and evidence model

Do **not** use one global "screenshot priority" order for every decision.

Different sources answer different questions.

## 1.1 Product/domain behavior

When behavior, persistence, calculations, lifecycle, scheduling, identity, or other domain semantics conflict, use this order:

1. **Canonical B01-B05 documentation**
2. **Frozen R08 product decisions**
   - `docs/implementation/r08/R08_FROZEN_PRODUCT_AUDIT.md`
   - `docs/implementation/r08/R08_0_FINAL_PRE_IMPLEMENTATION_DECISION_REVIEW.md`
3. **R08 implementation roadmap**
   - `docs/implementation/r08/R08_MASTER_IMPLEMENTATION_ROADMAP.md`
4. **Frozen/integrated R08 implementation authorities**
5. **Current implementation where no higher authority exists**

Screenshots and competitor products never create IndiFit domain authority.

Do not infer behavior solely because it appears in a screenshot.

## 1.2 Current product state

The current product state is the **integrated repository implementation**, supported by:

- current routes/widgets
- repositories/providers/controllers
- tests
- generated renders/goldens
- current integrated branch behavior

There is no requirement for a `docs/reference/ui/current/` screenshot folder.

When evaluating what IndiFit looks or behaves like **now**, inspect the current implementation and render the relevant states.

## 1.3 Pre-R08 manual-audit evidence

Path:

`docs/reference/ui/R08_baseline/`

These screenshots were captured during manual testing immediately before R08.

They are the visual evidence from which the R08 audit and roadmap were derived.

They may contain:

- bugs
- confusing UX
- good or acceptable UI
- useful interaction patterns
- weak information hierarchy
- visual inconsistencies
- missing functionality
- stale or incorrect states
- loading/error/empty-state problems

Therefore:

> **R08 baseline screenshots are evidence, not desired final designs.**

Do not preserve or reproduce a pattern merely because it appears in `R08_baseline/`.

Use the frozen R08 audit and roadmap to understand what conclusion was drawn from the evidence.

## 1.4 Curated regression evidence

Path:

`docs/reference/ui/current-regressions/`

This is a curated set of specifically identified regressions.

It is **not** a complete inventory of every pre-R08 problem.

Use it to understand concrete regression cases, but do not assume that all undesirable UI lives in this folder.

## 1.5 Pre-R07 legacy evidence

Path:

`docs/reference/ui/legacy/`

These screenshots predate R07.

They may contain successful consumer-facing interaction or visual patterns worth reconsidering, but they are not architectural or behavioral authority.

Never restore obsolete:

- state management
- persistence paths
- navigation
- data models
- technical limitations
- behavior that conflicts with B01-B05 or frozen R08 decisions

## 1.6 Competitor references

Path:

`docs/reference/ui/competitors/`

Competitor screenshots are inspiration and comparative evidence only.

Use them for:

- hierarchy
- density
- discoverability
- interaction flow
- information presentation
- visual emphasis
- execution ergonomics
- consumer wording patterns

Do not:

- copy branding
- copy exact layouts pixel-for-pixel
- copy proprietary data
- infer IndiFit domain behavior
- add a feature solely because a competitor has it
- fabricate metrics to imitate a populated screenshot

---

# 2. R08 baseline

Path:

`docs/reference/ui/R08_baseline/`

The R08 baseline is the primary screenshot evidence set for the R08 program.

Product-area folders include:

- `food/`
- `progress/`
- `settings/`
- `today/`
- `training/`
- `workout-player/`

## Purpose

Use these screenshots to reconstruct the **actual pre-R08 user experience** behind an audit finding.

They are particularly useful for:

- seeing the exact layout that caused a hierarchy problem
- identifying repeated/competing actions
- understanding density and scrolling problems
- seeing theme/accessibility inconsistencies
- locating stale/incorrect state
- understanding which flows were manually tested
- confirming what functionality already existed before R08
- distinguishing missing UX from missing backend capability

## Important rule

The screenshot and the audit finding must be interpreted together.

For example:

`R08_baseline/progress/...`
+
frozen Progress audit finding
+
current integrated implementation
=
evidence for an R08F decision.

Never treat an isolated baseline screenshot as a specification.

---

# 3. Current regressions

Path:

`docs/reference/ui/current-regressions/`

This folder is a focused regression-evidence collection.

Use it when:

- a frozen audit finding references a known regression
- a package prompt explicitly asks to compare a regression state
- validating that a previously identified problem has actually disappeared

Do not use it as:

- the complete R08 screenshot set
- the desired visual target
- a replacement for `R08_baseline/`
- a source of domain semantics

A regression screenshot shows a problem state; the frozen audit/decision documents define what should happen instead.

---

# 4. Legacy IndiFit — pre-R07

Path:

`docs/reference/ui/legacy/`

Legacy screenshots are not an architectural reference.

Use them selectively for successful consumer-facing ideas that may have been lost during later rewrites.

## Particularly valuable legacy patterns

### Nutrition dashboard

Preserve/reconsider where still useful:

- prominent calorie progress
- consumed vs target comparison
- clear remaining-calorie state
- visually distinct macro comparison
- semantic nutrient colours
- high information density without excessive text

### Meal logging

Preserve/reconsider:

- Breakfast / Lunch / Dinner / Snacks as obvious daily anchors
- one-tap entry from each meal
- understandable per-meal totals
- direct dashboard -> food search -> portion -> save flow
- logged meals remaining visible and easy to inspect

### Visual personality

Preserve/reconsider:

- stronger semantic colour
- visually distinct sections
- engaging progress feedback
- less monochromatic presentation

## Do not restore

- obsolete architecture
- obsolete navigation
- legacy data models
- old technical limitations
- behavior that conflicts with B01-B05
- behavior superseded by frozen R08 decisions

---

# 5. Gymverse

Path:

`docs/reference/ui/competitors/gymverse/`

Gymverse is the primary external workout UX reference.

Use it heavily when evaluating:

- Training landing
- plan overview
- planned workout presentation
- Quick Workout
- exercise navigation
- workout execution
- set logging
- weight and rep entry
- previous performance
- exercise substitution
- exercise guidance
- rest experience
- workout progress
- completion
- performance history

## Particularly useful patterns

### Workout player

Execution should make it easy to understand:

- current exercise
- current set
- load/reps
- previous factual performance
- planned/target context where canonical
- one obvious primary logging/completion action

Avoid forcing the user to mentally parse advanced domain configuration while training.

### Exercise guidance

Useful separation:

- Guidance
- Performance/history

Exercise media, technique, muscles worked and instructions can be available without overwhelming the main execution screen.

### Plan overview

Useful concepts:

- visible progression through weeks/days
- current position in a program
- clear workout identity
- visual state for completed/current/future sessions

### Previous-performance context

A lifter should quickly answer:

> What did I do last time?

IndiFit may also show planned/target facts where canonical, but historical evidence must not become an invented recommendation.

## Do not copy

- Gymverse branding
- colours
- typography
- exact layouts
- paywall design
- fabricated/sample metrics
- behavior incompatible with IndiFit's canonical B01/B02 execution model

IndiFit should use Gymverse as an interaction benchmark, not become a clone.

---

# 6. Healthify

Path:

`docs/reference/ui/competitors/healthify/`

Healthify is the primary external nutrition and daily-tracking reference.

Use it when evaluating:

- food logging
- food search
- recent/frequent foods
- meal-based logging
- calorie progress
- nutrition summaries
- weight tracking
- daily trackers

Hydration screenshots may still be studied as interaction inspiration, but hydration must remain hidden in IndiFit unless a complete canonical hydration authority exists.

## Particularly useful patterns

### Food logging speed

The important sequence is approximately:

1. choose meal
2. search
3. see useful foods immediately
4. select/log
5. optionally select multiple foods
6. save

Logging should feel closer to adding items to a checklist than filling out an administrative form.

### Frequent foods

Frequently logged foods can deserve prominence when derived factually from canonical history.

Do not convert frequency into recommendation or nutritional quality scoring.

### Meal structure

Breakfast, snacks, lunch and dinner provide useful anchors without requiring users to understand the underlying nutrition model.

### Hydration

Healthify demonstrates a highly visual and interactive hydration pattern.

For IndiFit this is **reference only**.

Do not recreate hydration targets, recommendations or progress until IndiFit has canonical persisted hydration authority.

## Do not copy

- monetisation
- coaching upsells
- premium banners
- exact visual design
- proprietary food data
- AI claims
- unsupported health/nutrition behavior

---

# 7. Muscle Booster

Path:

`docs/reference/ui/competitors/muscle-booster/`

Use primarily as an onboarding and personalization reference.

Useful patterns include:

- one meaningful question per screen
- obvious selection states
- strong visual hierarchy
- interactive body/goal choices
- sliders/selectors rather than large forms
- visible onboarding progress
- concise explanation for why information is requested
- personalized summary/result screens

## Important IndiFit difference

Do not reproduce extremely long onboarding.

IndiFit onboarding should remain short and optional where appropriate.

Advanced information should be gathered contextually when a feature actually requires it.

Do not place large educational lessons inside onboarding.

Do not promise personalization behavior that IndiFit does not actually implement.

---

# 8. Fitness & Bodybuilding Pro / VGFIT

Path:

`docs/reference/ui/competitors/vgfit/`

Use selectively for:

- exercise imagery
- muscle highlighting
- simple exercise libraries
- exercise instruction presentation
- workout-program browsing
- performance-history concepts

The visual design is not a primary reference.

Do not reproduce:

- large instruction walls
- dated navigation patterns
- paywall-heavy presentation
- exact exercise media
- behavior that conflicts with IndiFit's canonical exercise identity/media rules

---

# 9. IndiFit product principles

All R08 UX work should follow these principles.

## Feature completeness does not imply feature prominence

IndiFit can support many capabilities without placing every capability on the primary interface.

Everyday screens should optimize for everyday actions.

## Five high-frequency actions come first

The normal user should be able to quickly:

1. See today's nutrition status.
2. Log food.
3. See/start/resume today's workout or Quick Workout.
4. Log workout sets.
5. See meaningful progress.

Everything else is secondary.

## Complexity underneath the interface

Advanced domain capability should not make ordinary screens look complicated.

Use progressive disclosure.

Examples:

- equipment belongs in setup/settings
- household measures belong in portion selection
- exercise education belongs in exercise context/detail
- advanced set techniques belong behind disclosure
- adaptive-coaching details should not dominate ordinary screens

## Data first, explanation second

Prefer:

`72 / 140 g protein`

over:

`Your protein goal is currently configured to...`

Prefer:

`Last time: 80 kg x 8`

over a paragraph explaining progressive overload.

## Results/actions first

If a result, chart, concise number or direct action communicates faster than prose, prefer it.

## One obvious primary action

At any important state, one action should visually dominate.

Examples:

- Resume workout
- Start workout
- Log set
- Complete workout
- Add food
- Save
- Done

Secondary controls should remain visibly secondary.

## AI is an accelerator, not authority

AI can help users interact with existing canonical facts.

It must not become the sole source of:

- nutrition truth
- workout prescriptions
- exercise identity
- readiness
- historical facts
- target calculations

## Recommendations are defaults, not commands

Where recommendations exist canonically, present them as editable/default guidance rather than absolute instructions.

## Avoid administrative UI

The app should not feel like configuration software.

Avoid unnecessary consumer-facing terms such as:

- canonical
- evidence
- persisted
- frozen
- occurrence ancestry
- provider
- target ID
- provenance
- unresolved
- migration
- repository
- controller

These concepts may exist internally but should not normally reach users.

---

# 10. Visual direction

IndiFit should feel:

- premium
- athletic
- modern
- energetic
- calm during workout execution
- information-rich without being cluttered

The green identity may remain a primary brand colour, but the product should not feel monochromatic.

Use semantic colour intentionally.

Examples:

- Protein — green/teal
- Carbohydrates — amber/yellow
- Fat — red/coral
- Fibre — blue
- Workout/progress — appropriate accent
- Success — green
- Warning — amber
- Destructive — red

Hydration colour guidance is irrelevant while hydration is not an authorized release surface.

Semantic colour should improve recognition rather than decorate every surface.

Do not rely on colour alone to convey state.

---

# 11. Screenshot interpretation workflow for AI agents

Before modifying a visual/product surface:

1. **Read the package's frozen R08 audit/roadmap findings first.**
2. **Inspect all relevant screenshots under `R08_baseline/<area>/`.**
3. Identify the exact manually observed problems and useful existing capabilities.
4. Inspect relevant screenshots under `current-regressions/` if the package touches a documented regression.
5. Inspect the current integrated route/widgets and data authorities in the repository.
6. Render or inspect current integrated UI states/goldens where useful.
7. Compare against the appropriate competitor reference.
8. Compare against pre-R07 `legacy/` only when a useful older pattern is relevant.
9. Preserve canonical domain/persistence behavior.
10. Improve presentation and interaction without inventing data, policy or unsupported features.

The intended comparison is:

`pre-R08 evidence`
+
`frozen R08 decision`
+
`current integrated implementation`
+
`relevant competitor benchmark`
=
`R08 implementation decision`

## Never

- implement a feature solely because a competitor has it
- preserve bad UI solely because it exists in `R08_baseline/`
- remove canonical behavior merely to simplify a screenshot
- fabricate metrics to make an empty state look populated
- expose internal domain terminology
- assume an unavailable competitor feature belongs in IndiFit
- copy competitor branding/layouts pixel-for-pixel
- infer food/exercise identity visually
- infer household conversions
- weaken fail-closed behavior for prettier UI
- claim device-visible behavior without rendering/testing it

## Baseline screenshot interpretation

When a baseline screenshot looks poor, do not immediately "fix what you see."

First find the corresponding frozen audit finding.

The audit may have decided to:

- fix it now
- hide the feature
- preserve it
- simplify it
- supersede it
- defer it
- remove it

The frozen decision controls.

---

# 12. Reference responsibility map

Use this as the default reference map.

| Area | Pre-R08 evidence | Primary external reference | Secondary reference |
| --- | --- | --- | --- |
| Today/Home | `R08_baseline/today/` | Healthify | useful pre-R07 legacy patterns |
| Nutrition summary | `R08_baseline/today/` + `food/` | Healthify | pre-R07 nutrition patterns |
| Food diary/logging | `R08_baseline/food/` | Healthify | useful legacy meal logging |
| Food search | `R08_baseline/food/` | Healthify | current integrated R08D implementation |
| Saved Meals / Recipes | `R08_baseline/food/` | Healthify selectively | current integrated R08D |
| Training landing | `R08_baseline/training/` | Gymverse | current integrated R08C |
| Workout planning | `R08_baseline/training/` | Gymverse | current integrated R08C |
| Workout execution | `R08_baseline/workout-player/` | Gymverse | current integrated R08B |
| Exercise details | `R08_baseline/training/` / `workout-player/` | Gymverse | VGFIT |
| Exercise history | `R08_baseline/workout-player/` | Gymverse | current integrated R08B |
| Progress | `R08_baseline/progress/` | Gymverse + Healthify | useful legacy Progress patterns |
| Onboarding | applicable baseline state | Muscle Booster | current integrated R08E |
| Nutrition Targets | `R08_baseline/settings/` / `today/` | Healthify selectively | current integrated R08E |
| Settings | `R08_baseline/settings/` | Healthify selectively | current integrated implementation |
| Visual identity | baseline + current integrated renders | IndiFit itself | competitors for principles only |

"Current integrated implementation" means the actual post-R08 code/rendered state, not a screenshot folder.

---

# 13. R08 wave usage

## For completed/frozen waves

R08A-R08E correctness/domain behavior remains frozen unless a concrete regression is discovered.

Pre-R08 screenshots may still be used to verify that an original manually observed issue was actually resolved.

Do not reopen a frozen wave merely because the current UI no longer resembles the baseline screenshot.

## For upcoming waves

Every visual/product package should explicitly inspect the applicable baseline folder.

Examples:

### R08F — Progress

Use:

- `R08_baseline/progress/`
- frozen Progress audit findings
- current integrated Progress implementation
- Gymverse/Healthify Progress references

### R08G — Settings / advanced preferences

Use:

- `R08_baseline/settings/`
- frozen Settings audit findings
- current integrated Settings implementation
- applicable Healthify reference patterns

### R08H — Cross-app polish

Use all applicable baseline areas to reconcile:

- hierarchy
- density
- duplicate actions
- inconsistent visual treatment
- theme
- accessibility
- navigation
- stale/dead UI
- terminology

R08H is not permission to override frozen domain authorities.

---

# 14. Desired outcome

The goal is **not**:

> combine every feature shown by every competitor.

The goal is:

> retain IndiFit's B01-B05 intelligence and depth while making the product feel as simple, immediate, engaging and polished as the strongest focused experiences in the reference library.

The target experience combines:

- useful visual engagement from earlier IndiFit
- Healthify's nutrition usability
- Gymverse's workout usability
- Muscle Booster's onboarding clarity
- IndiFit's deeper intelligence underneath

The pre-R08 baseline exists to show where the R08 journey started.

The frozen audit defines what was learned from that evidence.

The current integrated implementation defines where IndiFit is now.

Competitor and legacy references help improve how that canonical product is presented.
