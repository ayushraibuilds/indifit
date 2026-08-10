# UX-R0 — IndiFit Product UX Reset Contract

Status: **canonical UX and presentation roadmap**

Scope: consumer information architecture, presentation, and interaction only

Implementation status: contract frozen; no application behavior changed by UX-R0

## 1. Purpose and authority

IndiFit keeps the accepted B01–B05 architecture and domain sophistication, but
resets the consumer experience around frequent actions, glanceable status, and
progressive disclosure. The target is:

> **Old IndiFit simplicity and visual engagement + current B01–B05 intelligence
> underneath.**

This document is authoritative for:

- navigation and feature placement;
- feature prominence and progressive disclosure;
- consumer information architecture and screen hierarchy;
- consumer presentation, visual direction, and interaction priorities; and
- accessibility presentation.

The B01–B05 documents remain authoritative for algorithms, domain semantics,
persistence, schema and backup, historical identity, safety, recommendation
eligibility, nutrition missingness, and workout execution. This contract must
consume those authorities; it must not replace, recalculate, weaken, or fork
them.

The existing [UX Stabilization Audit](UX_AUDIT.md) remains the evidence record
for observed defects and recurring presentation anti-patterns. Its findings
should be consulted during implementation instead of duplicated here. Its
former Wave 0–3 suggestions, and the completed historical Wave 1–6 UI program,
are superseded as active UX roadmaps by UX-R1–R7 in this contract.

## 2. Non-negotiable product principles

### P1 — Feature completeness does not imply feature prominence

A feature may remain fully implemented while being hidden under contextual or
Advanced UI. Navigation placement is not a statement about domain importance.

### P2 — Everyday actions dominate

The highest prominence belongs to calorie and macronutrient status, meal
logging, today's workout, workout execution, activity and recovery, weight, and
useful progress.

### P3 — Advanced functionality is progressively disclosed

Travel mode, equipment profiles, advanced scheduling, detailed provenance,
recommendation evidence, detailed readiness explanations, playlist
infrastructure, and transformation configuration must not dominate normal
navigation. They belong in relevant detail, More, or Advanced surfaces.

### P4 — AI is optional

Basic food logging must never depend on AI availability. Text and photo
estimation accelerate an ordinary logging path; they do not replace it.

### P5 — Domain sophistication stays underneath

Default consumer UI shows useful values, trends, decisions, status, actions,
and short explanations. It must not expose normal users to UUIDs, source IDs,
evidence IDs, raw reason codes, repository terminology, `canonical`,
`persisted`, `unresolved`, raw UTC strings, raw exceptions, or implementation
policy identifiers. Deliberate diagnostic/support surfaces may expose only the
minimum safe information required for their purpose.

### P6 — Visual communication beats explanatory paragraphs

Prefer a number, chart, ring, icon, progress indicator, control, or concise
status when it communicates the state more quickly than prose. Text explains
meaning or action; it does not restate a visual in paragraph form.

### P7 — Empty states are onboarding opportunities

Every no-data state communicates both what the state means and what the user
can do next. It must not present internal contract language or a dead end.

### P8 — Missing is not zero

All presentation preserves B03/B04 missingness semantics. Unknown,
unavailable, not connected, and not yet measured remain distinct from a
measured value of zero. Visualizations must not plot or total missing data as
zero.

### P9 — One obvious primary action

A screen or focused task state has one visually dominant action. Avoid multiple
equally prominent filled calls to action; secondary actions use quieter
hierarchy.

### P10 — Old UI is a visual reference, not an architectural reference

Historical screens may guide composition, density, personality, and visual
communication. They must never restore obsolete repositories, controllers,
state management, calculations, persistence, or stale domain semantics.

## 3. Historical visual reference contract

The primary historical references are:

- [Old dashboard — upper Today view](../../reference/ui/old-dashboard/IMG_1076.PNG)
- [Old dashboard — meals, workout, hydration, and weight](../../reference/ui/old-dashboard/IMG_1077.PNG)

The reference directory is `docs/reference/ui/old-dashboard/`. If an asset is
unavailable in a checkout, implementation must report the missing reference;
it must not fabricate a replacement and treat it as historical evidence.

The old dashboard is especially authoritative for the calorie-ring concept,
macro comparison, meal quick-add, visual engagement, semantic supporting
colors, compact information density, glanceability, and fitness personality.
Its old Today view demonstrates the desired combination of calorie status,
protein/carbs/fat/fiber comparison, visible meal rows, colored health metrics,
workout/recovery, hydration, and weight.

It is not authoritative for repositories, old state management, old nutrition
calculation paths, old workout persistence, obsolete controllers, or stale
domain semantics. All restored concepts must read current B01–B05 authorities.

## 4. Consumer navigation contract

The intended top-level consumer navigation is fixed as follows:

### Today

Daily overview and quickest actions.

### Training

Contains today's workout, training plan, workout calendar, workout history,
exercise library, program management, and advanced training features.

### Food

Contains meal logging, food search, recent foods, saved foods and meals,
recipes, barcode, AI text estimation, photo estimation, and relevant nutrition
tools.

### Progress

Contains overview, weight, consistency, strength trends, volume, and other
accepted progress views.

Exercise Library is no longer an equal top-level destination. Its target
location is under Training. Settings/profile may remain a header or account
destination rather than competing with the four primary destinations.

This is a route-placement contract for later implementation. UX-R0 does not
change the application router.

## 5. Today information architecture

The target order is frozen. The composition must not become four giant cards
literally titled “What should I do?”, “What should I eat?”, “How am I
progressing?”, and “What is my next action?”. Those remain conceptual checks,
not required headings.

### A. Header

- Greeting derived from the user's local time.
- Name when known; no fabricated identity when absent.
- Compact date selector with clear local-date semantics.
- Quiet access to settings and customization.

### B. Nutrition hero

This is the primary visual anchor. Restore a calorie ring, calorie target
comparison, and compact protein, carbs, fat, and fiber comparisons. Values must
come from canonical B03/B04 state. Known values, ranges, partial values, and
unknown values retain their authoritative meaning; unknown never renders as
zero or as falsely complete progress.

### C. Next workout / next useful action

Use a compact `Next up` treatment for the most relevant safe action. Do not
restore a giant, permanent Daily Focus motivational card. The element may show
a workout, recovery action, or another useful next step supported by existing
authority.

### D. Meals

Keep visible rows for Breakfast, Lunch, Dinner, and Snacks. Each row supports a
clear quick-add path and a compact truthful summary of logged content.

### E. Activity / recovery

Show compact, meaningful metrics only when real data exists. Distinguish no
permission, unavailable, missing, and measured zero. Avoid empty metric chrome
that implies a valid measurement.

### F. Progress

Show a compact useful summary, such as weight or consistency, appropriate to
available data. Detailed charts, filters, and analysis belong in Progress.
When data is insufficient, show meaning plus a useful next action rather than
an empty chart frame.

## 6. Food logging contract

The primary hierarchy is fixed:

```text
Add meal
→ Search
→ Recent
→ Saved
→ Recipes

Secondary:
→ Barcode
→ Describe with AI
→ Photo estimate
```

Search is the ordinary production path. It must remain usable when an AI
service is down, an estimation API fails, or the device is offline wherever
local data exists. Recent, saved, and recipe data should remain available
according to their existing local authorities.

AI estimation must preserve review-before-save and provide a direct fallback
to ordinary search. Where feasible, the fallback carries forward the user's
meal text, extracted search terms, selected meal slot, date, and other harmless
intent so the failure does not force re-entry. AI unavailability must not
produce duplicate error surfaces or block manual logging.

## 7. Onboarding contract

The target required flow is:

1. About you
2. Main goal
3. Training/activity
4. Nutrition preferences
5. Finish

`Skip for now` must be visible and understandable. Skipping permits entry into
the basic app, but it must not fabricate age, eligibility, profile facts, or
recommendation inputs. It must not activate adaptive numerical
recommendations. All B04 fail-closed eligibility and missing-input behavior
remains authoritative.

Later features may request missing information contextually when it becomes
relevant. Required onboarding must not contain mini-lessons. Education remains
optional, contextual, and available through dedicated Learn or Guide
experiences.

## 8. Feature prominence tiers

The tiers govern default navigation weight, visual prominence, and disclosure;
they do not remove or weaken implementation.

### Tier 1 — Daily

- calorie and macronutrient status;
- meal logging;
- today's workout and workout execution;
- activity and recovery;
- weight; and
- progress summary.

### Tier 2 — Occasional

- recipes;
- calendar;
- exercise library;
- plate calculator;
- dietary needs;
- health integration;
- education;
- weekly review.

### Tier 3 — Advanced / contextual

- travel mode;
- equipment profiles;
- detailed recommendation provenance;
- raw/cooked transformation configuration;
- readiness technical explanation;
- playlist infrastructure; and
- advanced scheduling controls.

Travel mode must not appear as a primary calendar or top-navigation affordance.
Its target location is `Training → More / Advanced → Travel mode`, preferably
shown contextually only when an active program exists. The feature is retained.

## 9. Visual direction

The product character is premium, athletic, modern, calm, consumer-facing,
Indian-aware, data-rich, visually engaging, and compact without feeling
cramped.

Keep the near-black/navy dark canvas and emerald primary brand accent. Restore
selective semantic supporting color where color helps users scan meaning:

| Role | Direction |
|---|---|
| Success and general progress | Emerald / teal |
| Protein | Green |
| Energy and carbohydrates | Amber / orange |
| Genuine warning or over-target | Red / warm coral |
| Hydration | Blue |
| Sleep and recovery | Indigo |
| Unavailable or missing | Muted neutral |

These are semantic roles, not a mandate to color every module. Do not introduce
arbitrary rainbow decoration. Color cannot be the only carrier of meaning, and
warning colors must not be used for ordinary decoration.

## 10. Interaction and accessibility philosophy

The product should feel stateful and responsive rather than document-like.
Future implementation should support, where appropriate:

- **Today:** calorie-ring transitions, meal-row interaction, quick add, date
  navigation or swipe, macro detail, and module collapse.
- **Food:** quick recent selection, quantity changes, and immediate saved-state
  feedback.
- **Workout:** set completion, rest timer, haptics, target override, and
  previous-performance context.
- **Progress:** chart inspection, time-period controls, and useful metric
  switches.

Accessibility is part of the presentation contract:

- respect reduced-motion settings and provide meaningful non-animated state
  changes;
- maintain readable contrast in light and dark themes;
- never use color alone for status, over-target, completion, or missingness;
- preserve logical screen-reader and keyboard focus order;
- give controls clear labels, states, and adequate touch targets;
- support large text without clipping, hidden actions, or forced horizontal
  scrolling; and
- provide concise accessible equivalents for charts, rings, icons, and
  progress indicators.

Animations and haptics reinforce state changes; they must not delay core
actions or become required to understand success or failure.

## 11. Explicit simplifications

### Daily Focus

Remove the giant permanent card. The concept may survive as a compact `Next up`
element within the frozen Today hierarchy.

### Travel

Hide it under contextual or Advanced Training UX. Do not delete the feature or
change its domain behavior.

### Exercise education

Exercise detail must not concatenate cues, mistakes, a checklist, written
guidance, lessons, and unavailable media into one giant scrolling page. Show a
concise actionable summary and link to a dedicated Guide for deeper education.

### Optional unavailable media

Do not render a large “Muscle diagram unavailable” state when the available
text already communicates the useful information. Render the available
experience cleanly; disclose optional media only when its absence requires an
action.

### Progress

Do not render empty chart frames when data is insufficient. Begin with a clear
zero-data state, introduce compact partial-data summaries, and progressively
increase chart complexity as sufficient data becomes available.

## 12. Implementation roadmap

Each wave is presentation work unless its scope explicitly invokes an existing
domain authority. Any conflict with B01–B05 domain semantics must be resolved in
favor of the existing authority or through a separately approved domain change.

### UX-R1 — Core usability recovery

- Restore non-AI food logging as the dominant reliable path.
- Add AI failure fallback without losing intent where feasible.
- Remove duplicate failure UI and prevent raw technical failure output.
- Correct the greeting using local time.
- Add onboarding `Skip for now` without weakening fail-closed behavior.
- Remove required lessons from onboarding.
- De-emphasize Travel.
- Hide optional unavailable features and dead-end entries.

### UX-R2 — Today / Home

- Restore the calorie ring and macro comparisons.
- Apply semantic color with non-color status equivalents.
- Restore visible meal rows and quick add.
- Present next workout/useful action compactly.
- Add meaningful activity and compact progress summaries.

### UX-R3 — Food

- Establish Search, Recent, Saved, and Recipes as primary paths.
- Place Barcode, AI, and Photo as optional secondary accelerators.
- Preserve local/offline behavior and review-before-save.

### UX-R4 — Training

- Create the Training landing hierarchy.
- Place calendar, workout execution, exercise detail, library, and program
  management coherently.
- Move advanced training features to More / Advanced or contextual entry.

### UX-R5 — Progress

- Define zero-, partial-, and full-data states.
- Add useful charts only when data supports them.
- Support inspection, time periods, and useful metric switching.

### UX-R6 — Onboarding and secondary UX

- Deliver the five-stage simplified onboarding flow.
- Make education optional and contextual.
- Simplify dietary needs, measures, profile, and settings.
- Render media according to actual availability.

### UX-R7 — Visual, interactions, and accessibility

- Consolidate the design system and semantic colors.
- Refine density, typography, interaction, and light/dark presentation.
- Complete accessibility and reduced-motion verification.
- Certify the result on physical devices.

## 13. Supersession and non-goals

This document explicitly retires the earlier UX implementation roadmap as the
active plan. Historical Wave 0–3 audit recommendations and the completed Wave
1–6 UI implementation remain useful evidence and history; they must not be
deleted or mistaken for the current product target. All future consumer UX
planning uses UX-R1–R7.

UX-R0 does not rebuild Today, modify navigation, change meal logging, alter
onboarding, move Travel in code, adjust runtime colors, modify widgets, change
domain behavior, remove features, or revert commits. It freezes the target
before implementation.

## 14. UX-R0 completion gate

UX-R0 is complete when:

- this document is the single active consumer UX roadmap;
- the existing audit is linked as supporting evidence and marked superseded as
  a roadmap;
- the old-dashboard references are recorded without claiming architectural
  authority;
- no Dart or other runtime application files are changed; and
- `git diff --check` passes for the documentation change.
