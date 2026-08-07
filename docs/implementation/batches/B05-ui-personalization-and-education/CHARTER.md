# B05 — UI, Personalization and Education

Status: planned, documentation-only

Planning branch: `batch/b05-planning`

Planning baseline: `bc4dfa31ac9392f24ae6a702b02c76303e3ae8dc` (`merge(B04-F01)`)

Inherited durable baseline: schema v18 / Backup v9
Platforms: Android and iOS

## Purpose

B05 turns the established B01–B04 domains into a calm, accessible daily
product experience. It makes Today the primary daily action surface, gives
people control of its layout, adds focused high-frequency interaction polish,
and ships goal-relevant education without creating a second source of truth
for training, nutrition, activity, or recommendations.

The batch is deliberately selective: it modernizes the shared presentation
foundation and the daily journeys that need it, rather than redesigning every
screen for visual consistency alone.

## Scope mapping

| Requested feature group | B05 outcome |
|---|---|
| Today-page redesign | A module-driven Today page answers, in order, “What should I do?”, “What should I eat?”, “How am I progressing?”, and “What is my next action?” while consuming B01–B04 read authorities. |
| Dashboard personalization | Stable module IDs support deterministic default order, user reordering, hiding, collapsing, and portable persistence. |
| Design-system modernization | Semantic light/dark tokens, an 8/10/12 px radius scale, reduced direct `AppColors` use in B05-owned surfaces, restrained hierarchy, consistent typography/spacing/icons, and meal-specific accents. |
| Responsive and accessible UI | Compact-width and large-text layouts, labelled semantics, focus order, touch-target rules, reduced-motion behavior, and Android/iOS-consistent interactions on B05-owned surfaces. |
| Swipe interactions | Contextual edit/copy/delete food actions and complete/skip workout actions, each routed through an existing domain command with visible undo only when that owner exposes a valid inverse/restore. |
| Exercise education | Fail-closed bundled-media and diagram infrastructure with accessible contribution labels, checklists, contextual cues and fallbacks. Approved top-20 media and graphical diagram content may be activated later when the external packet is supplied; remote downloadable-pack lifecycle is deferred. |
| Mini lessons | Versioned offline lessons for RPE, progressive overload, protein, energy balance, and recovery, with portable progress. |
| Adaptive onboarding | A goal-declared lesson path that saves and resumes progress, preserves completed sections, and commits through existing profile/routine authorities. |
| Playlist launcher | A persisted allowlisted provider/playlist preference and safe external launcher on relevant workout surfaces, with no provider account, streaming, or token integration. Enabled provider defaults may be deferred until their approved configuration exists. |
| Required foundations | Stable module registry, semantic tokens, exercise/muscle metadata, versioned content, media licensing/packaging contract, and accessibility/reduced-motion contract land before dependent feature work. |

## Required outcomes

1. Today is an action-first surface with explicit, accessible answers to the
   four daily questions. It composes existing B01–B04 outputs and never
   calculates nutrition, coaching, scheduling, or activity facts in widgets.
2. People can reorder, hide, and collapse known dashboard modules. Preferences
   persist locally, export through Backup v10, restore atomically, and fall
   back safely when descriptors change.
3. B05-owned interfaces resolve color, state, typography, spacing, icons, and
   radii through semantic presentation primitives in light and dark modes.
   Their layout remains usable on compact screens and at large text scales.
4. Food and workout swipe actions invoke only existing B03/B01 commands,
   expose a clear undo window only for owner-supported reversible destructive
   state changes, and preserve error, offline, and accessibility behavior.
5. The five named mini lessons, contextual cues, form checklists, primary /
   secondary / stabilizing muscle labels, and B05-08 media/diagram fallbacks
   work offline. A labelled text fallback remains available when visual media
   is unavailable; missing media never removes lessons, checklists, cues or
   muscle labels and never blocks a workout.
6. B05-08 media, diagram and playlist infrastructure fails closed for missing,
   malformed or unapproved content. Any content activated later uses approved,
   traceable licensing and packaging; B05 may complete with that external
   content honestly unavailable and recorded as a non-blocking follow-up.
7. Onboarding adapts only from an explicitly selected goal and saved content
   progress. It resumes incomplete work, skips completed sections, and does
   not infer health, dietary, safety, or coaching conditions.
8. When a supported provider is configured, users can choose and persist its
   playlist reference, then launch it from a workout surface without storing
   provider credentials or requiring network for the rest of the workout.
   Missing enabled defaults remain an honest unavailable, non-blocking state.
9. v19/Backup v10 migration, restore, strict-offline, privacy, accessibility,
   and Android/iOS release evidence pass on the integrated B05 head.

## Classification

| Classification | Items | B05 disposition |
|---|---|---|
| Required B05 product work | All nine requested feature groups; M19 portable preferences/content state; E6/F5; E7/F6 educational experience | Mandatory in the B05 task DAG. |
| Required B05 delivery gate | B05-08 fail-closed media/diagram/provider infrastructure; v19/v10 migration/restore; E8 platform, privacy/offline, accessibility, performance and build checks | B05 may complete with externally supplied content unavailable when the infrastructure and release evidence pass. The rights/source packet remains required before any content activation. |
| Optional within B05 | Extra module variants, additional non-core animations, haptics, and secondary screen polish | May ship only after required work; never substitutes for a required outcome. |
| Post-launch | Remote downloadable-media lifecycle (including resumable/background download, partial packs, cleanup and retry orchestration), media beyond the selected top 20, social/community/gamification, provider account or streaming integration, cloud sync, a full exercise-catalogue media rollout, N8/P3/P4/P6 roadmap work | Separate product decision and task DAG. |
| Explicitly excluded | B01–B04 domain rebuilds, a second dashboard authority, widget-side nutrition/coaching calculation, indiscriminate screen redesign, unlicensed media, web/desktop release, legal certification, marketing and infrastructure scaling | Not admitted through B05 polish work. |

## Media and provider gate

The top-20 offline media pack and interactive diagrams remain required product
outcomes, but the solo-development exception separates their software boundary
from external content activation. B05-01 requires only the contract, registry
shape and acceptance template below and must not hold up B05-02 through
B05-07. B05-08 infrastructure may be implemented and released with truthful
unavailable/fallback states before the product owner supplies the activation
packet. Before any content is activated, the product owner must approve:

- the exact 20 stable exercise IDs;
- a source, license, attribution/retention rules, and permitted distribution
  method for every clip, animation, and anatomy diagram;
- the package budget, checksum/signing approach, offline fallback, and
  forward-compatible download/deletion preference semantics; and
- the supported provider allowlist and playlist-reference formats for the
  launcher.

The implementation must use that approved manifest whenever content is
activated. If approval or assets are unavailable, the software must remain
truthfully unavailable and the content activation is a non-blocking follow-up;
it must not silently replace the required media with copyrighted remote content
or declare arbitrary content approved.

## Inherited authorities

| Area | Existing authority | B05 may do | B05 must not do |
|---|---|---|---|
| Schedule and workout execution | B01 `CalendarRepository` / `CalendarReadRepository`, execution repositories, exercise preferences | Render occurrence state; dispatch existing complete/skip commands; display setup/personal cues | Change program progression, occurrence rules, execution snapshots, or add duplicate exercise preferences |
| Activity, health and muscles | B02 activity/progress/muscle repositories and `HealthService` | Render typed activity, canonical mappings and primary/secondary/stabilizing labels | Reclassify activity, fabricate health values, create a second muscle taxonomy, or calculate volume |
| Nutrition and safety | B03 `NutritionReadModelRepository`, food/recipe repositories, `NutritionConstraintEvaluator` | Render totals/status; invoke existing food edit/copy/delete commands | Recalculate nutrients, replace safety filtering, or infer exact values from unknown/range states |
| Goals and coaching | B04 production orchestrator/controllers and goal/preferences repositories | Render briefing/current-food/review results, action links, and policy states | Rank recommendations, mutate targets, or create a coaching authority |
| Dashboard and content state | New B05 v19 repositories, central module/content registries | Persist declared module preferences, lesson progress, media-pack preference/manifest identity, playlist preferences | Dynamically construct arbitrary modules, persist media binaries/paths, trust restored physical availability, or store raw provider data/tokens |
| Navigation and settings | GoRouter, theme/privacy/settings controllers | Add durable destinations and present settings through existing owners | Build a screen-local router or a second settings store |
| Durable contracts | `AppDatabase` and transactional backup/restore graph | Make one v19 migration and Backup v10 extension | Add a parallel restore pipeline or partial restore semantics |

## Completion definition

B05 is complete only when:

- every required task has a fresh `Approved` or `Approved with non-blocking
  follow-up` review-and-resolve verdict;
- dashboard, education, media-pack preference/identity, and playlist
  preferences pass v19 /
  Backup v10 direct, chained, and rollback-safe verification;
- B05-08 software infrastructure validates and fails closed for media,
  diagrams and playlist providers, with usable text/list/still fallbacks;
  supplied content may be activated only after the external packet is
  validated against the retained contract; and
- Today, swipe actions, mini lessons, onboarding, playlist launch, reduced
  motion, compact/large-text, semantics/focus, strict-offline and Android/iOS
  checks meet the verification matrix; and
- a fresh read-only Sol review of the clean integration head finds no
  unresolved launch-critical defect.
