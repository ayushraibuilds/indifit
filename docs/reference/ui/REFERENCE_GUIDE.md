# IndiFit UI Reference Guide

This directory contains visual references for IndiFit UX/product work.

Screenshots are **design and interaction references only**. They do not override IndiFit's canonical domain architecture, persistence rules, safety requirements, business logic, or implementation documents under `docs/implementation/`.

---

# 1. Reference priority

When screenshots disagree, use this order:

1. **Current IndiFit screenshots**

   * `docs/reference/ui/current/`
   * Authoritative representation of the app's current production UI and UX state.

2. **Canonical UX/product implementation documents**

   * Especially:

     * `docs/implementation/ux/UX_AUDIT.md`
     * current R07C implementation/remediation documents
   * These define intended direction and accepted constraints.

3. **Legacy IndiFit screenshots**

   * `docs/reference/ui/legacy/`
   * Used selectively to identify previous interaction or visual patterns worth restoring.

4. **Competitor screenshots**

   * `docs/reference/ui/competitors/`
   * Used for inspiration and comparative analysis only.

Never infer desired product behavior solely because it appears in a competitor or legacy screenshot.

---

# 2. Current IndiFit

Path:

`docs/reference/ui/current/`

## Purpose

These screenshots show where IndiFit stands **now**.

Use them to:

* identify current hierarchy and information density
* find confusing or inefficient flows
* identify duplicated UI or excessive explanation
* inspect loading, empty, error and completed states
* understand navigation and discoverability
* compare current IndiFit against competitor interaction patterns
* verify that redesigns preserve useful existing capabilities

## Important rule

Current screenshots describe **existing behavior**, not necessarily desired behavior.

If something in the current UI is clearly poor, redundant, broken or inconsistent, do not preserve it merely because it exists.

---

# 3. Legacy IndiFit

Path:

`docs/reference/ui/legacy/`

Legacy screenshots are **not an architectural reference**.

Do not restore old state management, data paths, obsolete screens, or business logic.

Use them only for successful consumer-facing ideas.

## Particularly valuable legacy patterns

### Nutrition dashboard

Preserve/reconsider:

* prominent calorie progress ring
* calorie consumed vs target comparison
* clear remaining-calorie state
* visually distinct macro comparison
* semantic nutrient colours
* high information density without excessive text

### Meal logging

Preserve/reconsider:

* Breakfast / Lunch / Dinner / Snacks as obvious daily anchors
* one-tap `+` entry from each meal
* easy-to-understand per-meal totals
* direct movement from dashboard → food search → portion → save
* logged meals remaining visible and easy to inspect

### Visual personality

Preserve/reconsider:

* stronger semantic colour
* visually distinct sections
* more engaging progress feedback
* less monochromatic presentation

## Do not restore

* obsolete architecture
* obsolete navigation
* legacy data models
* old technical limitations
* functionality that conflicts with B01–B05 canonical behavior

---

# 4. Gymverse

Path:

`docs/reference/ui/competitors/gymverse/`

Gymverse is the **primary workout UX reference**.

Use it heavily when evaluating:

* Training landing
* plan overview
* planned workout presentation
* Quick Workout
* exercise navigation
* workout execution
* set logging
* weight and rep entry
* previous performance
* suggested load/reps
* exercise substitution
* exercise guidance
* rest experience
* workout progress
* completion
* performance history

## Particularly useful patterns

### Workout player

Notice how execution focuses on:

* current exercise
* current set
* load/reps
* previous performance
* recommended target
* one obvious completion action

Avoid forcing the user to mentally parse domain configuration while training.

### Exercise guidance

Useful separation:

* Guidance
* Performance/history

Exercise media, technique, muscles worked and instructions are available without overwhelming the main execution screen.

### Plan overview

Useful concepts:

* visible progression through weeks/days
* current position in a program
* clear workout identity
* visual state for completed/current/future sessions

### Previous-performance context

A lifter should quickly answer:

> What did I do last time and what should I attempt now?

This is more useful during a workout than generic explanatory text.

## Do not copy

* Gymverse branding
* colours
* typography
* exact layouts
* paywall design
* sample/fabricated metrics
* behavior incompatible with IndiFit's canonical B01/B02 execution model

IndiFit should use Gymverse as an **interaction benchmark**, not become a clone.

---

# 5. Healthify

Path:

`docs/reference/ui/competitors/healthify/`

Healthify is the **primary nutrition and daily tracking reference**.

Use it when evaluating:

* food logging
* food search
* recent/frequent foods
* meal-based logging
* calorie progress
* nutrition summaries
* hydration
* weight tracking
* daily trackers

## Particularly useful patterns

### Food logging speed

The important sequence is:

1. choose meal
2. search
3. see useful foods immediately
4. tap `+`
5. optionally select multiple foods
6. save

Logging should feel closer to adding items to a checklist than filling out a form.

### Frequent foods

Frequently logged foods deserve high prominence.

Returning users should increasingly need fewer searches.

### Meal structure

Breakfast, snacks, lunch and dinner provide useful anchors without making the user understand the underlying nutrition model.

### Hydration

The water tracker is:

* highly visual
* immediately interactive
* responsive to each tap
* motivational without requiring explanation

## Do not copy

* Healthify monetisation
* coaching upsells
* premium banners
* exact visual design
* proprietary food data
* AI claims

---

# 6. Muscle Booster

Path:

`docs/reference/ui/competitors/muscle-booster/`

Use primarily as an **onboarding and personalization reference**.

Useful patterns include:

* one meaningful question per screen
* very obvious selection states
* strong visual hierarchy
* interactive body/goal choices
* sliders/selectors rather than large forms
* progress through onboarding
* explanations for why information is requested
* personalized summary/result screens

## Important IndiFit difference

Do **not** reproduce its extremely long onboarding.

IndiFit onboarding should remain short, optional where possible, and allow:

`Skip for now`

Advanced information should be gathered contextually when a feature actually requires it.

Do not place educational lessons inside onboarding.

---

# 7. Fitness & Bodybuilding Pro / VGFIT

Path:

`docs/reference/ui/competitors/vgfit/`

Use selectively for:

* exercise imagery
* muscle highlighting
* simple exercise libraries
* exercise instruction presentation
* workout-program browsing
* performance history concepts

The visual design is not a primary reference.

Do not reproduce:

* large blocks of exercise instruction
* dated navigation patterns
* paywall-heavy presentation
* exact exercise media

---

# 8. IndiFit product principles

All redesign work should follow these principles.

## Feature completeness does not imply feature prominence

IndiFit can support many capabilities without putting every capability on the primary interface.

Everyday screens should optimize for everyday actions.

---

## Five high-frequency actions come first

The normal user should be able to quickly:

1. See today's nutrition status.
2. Log food.
3. See/start today's workout or Quick Workout.
4. Log workout sets.
5. See meaningful progress.

Everything else is secondary.

---

## Progressive disclosure

Advanced capabilities should appear when relevant.

Examples:

* travel training belongs in advanced plan management
* equipment profiles belong in setup/settings
* household measures should appear when choosing portions
* plate calculator should be attached to relevant barbell exercises
* exercise education should be available from exercise details
* adaptive-coaching details should not dominate normal screens

---

## Data first, explanation second

Prefer:

`72 / 140 g protein`

over:

`Your protein goal is currently configured to...`

Prefer:

`Last time: 80 kg × 8`

over a paragraph explaining progressive overload.

---

## Avoid administrative UI

The app should not feel like configuration software.

Avoid unnecessary terms such as:

* canonical
* evidence
* persisted
* frozen
* occurrence ancestry
* provider
* target ID
* provenance
* unresolved
* legacy
* migration

These concepts may exist internally but should not normally reach users.

---

# 9. Visual direction

IndiFit should feel:

* premium
* athletic
* modern
* energetic
* calm during execution
* information-rich without being cluttered

The current green identity may remain a primary brand colour, but the UI should not be monochromatic.

Use semantic colour intentionally.

Examples:

* Protein — green/teal
* Carbohydrates — amber/yellow
* Fat — red/coral
* Fibre — blue
* Hydration — blue/cyan
* Workout/progress — appropriate accent colour
* Success — green
* Warning — amber
* Destructive — red

Semantic colour should improve recognition rather than decorate every surface.

---

# 10. Screenshot interpretation rules for AI agents

Before modifying UI:

1. Inspect the relevant screenshots under `current/`.
2. Identify the current production route/widgets in the repository.
3. Compare against the appropriate competitor reference.
4. Compare against legacy IndiFit only where useful.
5. Read the canonical implementation/UX documentation.
6. Preserve canonical domain and persistence behavior.
7. Improve presentation and interaction without inventing fake data.

Never:

* implement a feature solely because a competitor has it
* remove canonical behavior merely to simplify a screenshot
* fabricate metrics to make an empty state look populated
* expose internal domain terminology
* assume an unavailable competitor feature belongs in IndiFit
* copy competitor branding or layouts pixel-for-pixel

---

# 11. Competitor responsibility map

Use this as the default reference map:

| Area              | Primary reference          | Secondary reference             |
| ----------------- | -------------------------- | ------------------------------- |
| Today/Home        | Legacy IndiFit + Healthify | Current IndiFit                 |
| Nutrition summary | Legacy IndiFit             | Healthify                       |
| Food logging      | Healthify                  | Legacy IndiFit                  |
| Food search       | Healthify                  | Current IndiFit                 |
| Hydration         | Healthify                  | Current IndiFit                 |
| Training landing  | Gymverse                   | Current IndiFit                 |
| Workout planning  | Gymverse                   | Current IndiFit                 |
| Workout execution | Gymverse                   | Current IndiFit                 |
| Exercise details  | Gymverse                   | VGFIT                           |
| Exercise history  | Gymverse                   | Legacy IndiFit                  |
| Progress          | Gymverse + Healthify       | Current IndiFit                 |
| Onboarding        | Muscle Booster             | Current IndiFit                 |
| Settings          | Current IndiFit            | Healthify                       |
| Visual identity   | IndiFit itself             | Competitors only for principles |

---

# 12. Desired outcome

The goal is **not**:

> combine every feature shown by every competitor.

The goal is:

> retain IndiFit's B01–B05 intelligence and depth while making the product feel as simple, immediate, engaging and polished as the strongest focused experiences in the reference library.

The target experience is:

**old IndiFit's accessibility and visual engagement

* Healthify's nutrition usability
* Gymverse's workout usability
* Muscle Booster's onboarding clarity
* IndiFit's deeper intelligence underneath.**
