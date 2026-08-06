# B05 — UI and Education

Status: planned, documentation-only
Planning branch: `batch/b05-planning`
Planning baseline: `bc4dfa31ac9392f24ae6a702b02c76303e3ae8dc` (`merge(B04-F01)`)
Inherited durable baseline: schema v18 / Backup v9
Platforms: Android and iOS

## Scope

`B05 — UI and Education` is the title assigned by the canonical implementation
tracker. It completes the planned feature work for roadmap **E6 — Today and
Visual System** and the release-ready portion of **E7 — Education and Media**.
It also executes the final roadmap **E8 — Platform and Release Assurance**
gate; E8 is release work, not a new product domain.

| Roadmap IDs | B05 outcome |
|---|---|
| F5; U1–U8; E6 | Semantic light/dark presentation, restrained shared surfaces, responsive and accessible shipped flows, a module-driven Today surface, dashboard customization, nutrition accents, and safe swipe/undo where a reversible command exists. |
| M19 | Portable dashboard module preferences and educational-content progress; reuse the already-portable B01 exercise setup/personal-cue aggregate. A v19/v10 media-manifest seam records verified optional packs without backing up media binaries. |
| F6; E3–E5; E7 | Bundled versioned text/cues, exercise checklists, lesson progress, an accessible muscle-insight surface over B02 taxonomy, and explicit adaptive-onboarding/content entry rules. |
| E1, E2, E6; E7 | A release-safe asset/URL boundary and honest unavailable states. Shipping licensed animation packs, a commissioned anatomy diagram asset, or provider playlist content requires the roadmap product-owner decisions first. |
| E8 | Native-permission, privacy/offline, migration/backup, accessibility, performance and supported-platform build verification on the integrated B05 head. |

## Required outcomes

1. Shipped feature surfaces resolve colors, typography, spacing, radii and
   state treatment from a semantic presentation authority, and remain usable
   in light/dark, compact and large-text modes.
2. Today is composed from stable module IDs and persisted user preferences;
   it consumes B01–B04 read authorities without creating a new schedule,
   nutrition or recommendation calculation path.
3. B05 durable presentation/content records migrate and restore safely:
   dashboard module preferences, content progress and verified optional-media
   manifests. Existing B01 exercise setup preferences remain their owner.
4. Education is usable offline through bundled checklists, cues and lessons;
   user progress is versioned and portable. B02 muscle taxonomy and B01
   personal setup/cues are displayed rather than copied or re-derived.
5. Onboarding is explicit, recoverable and accessible. It may select an
   already-defined route or bundled lesson from declared user answers and
   existing state, but may not infer a health, dietary, safety or coaching
   condition.
6. The final integrated build honestly handles empty, unavailable, error,
   retry, permission-denied, strict-offline and privacy states and passes the
   E8 release checks that are available in this solo-development environment.

## Remaining-roadmap classification

| Classification | Items | B05 disposition |
|---|---|---|
| Required for B05 | E6/F5: U1–U8; M19; E7/F6: offline cues/checklists, versioned lessons/progress and explicit onboarding adaptation | Mandatory B05 DAG. |
| Required for launch, not a feature | E8 migration/backup recovery, native-health/permission validation, privacy/offline, accessibility, performance and supported-platform build gates | B05-09 and B05-10. |
| Optional polish within the UI work | Extra transitions, haptics, non-essential module variants and swipe actions lacking a proven undo command | Do not block B05 on them; include only when they fit an existing task and have focused proof. |
| Post-launch follow-up | E1 licensed animation packs, E2 graphical anatomy asset, E6 playlist-provider workflow; N8 context modes; P3 strength standards, P4 unified PR timeline, P6 muscle-balance analysis, any expanded body-trend product work, cloud/account sync | Separate product/architecture decision and task DAG; not silently folded into B05. |
| Explicitly excluded | Medical or nutrition-prescription features, AI safety/target authority, web/desktop release work, marketing/legal certification, infrastructure scaling and B01–B04 algorithm rewrites | Outside B05. |

## Explicit exclusions

- New training, nutrition, health, target, readiness, recommendation or AI
  algorithms; B05 renders their existing authorities only.
- Rebuilding B01 scheduling/programs, B02 activity/load/muscle calculation,
  B03 nutrition/constraint calculation, or B04 recommendation/goal logic.
- Cloud accounts, synchronization, marketing, legal-certification work,
  telemetry expansion, or infrastructure scaling.
- Unlicensed or unreviewed animation, anatomy, video or playlist assets;
  remote media may not become a core-path requirement or bypass strict offline
  mode.
- A blanket conversion of every local `Navigator.pop`/sheet to GoRouter.
  GoRouter owns durable cross-feature destinations; transient modal dismissal
  remains local.
- Speculative dashboard modules, an alternate weekly-report narrative, or an
  inference-driven onboarding/coaching engine.

## Inherited authorities

| Area | Existing authority | B05 may read | B05 may change | Forbidden duplication |
|---|---|---|---|---|
| Schedule and execution | B01 `CalendarRepository` / `CalendarReadRepository`; B02 execution repositories | Occurrence state, immutable execution, stable exercise IDs, personal setup/cues | Presentation adapters and route entry only | Program progression, occurrence mutation rules, execution snapshots |
| Activity, health and muscle data | B02 `ActivitySessionRepository`, `B02ProgressReadRepository`, `B02MuscleVolumeRepository`, `HealthService` | Typed modality history, provenance, volume/mapping states, permission/result states | UI presentation and launch validation only | Reclassification, health fabrication, muscle taxonomy or volume calculation |
| Nutrition and safety | B03 `NutritionReadModelRepository`, consumption/recipe/thali repositories, `NutritionConstraintEvaluator` | Canonical daily totals, immutable snapshots, ranges, candidates and safety status | Remove competing dashboard reads; render status | Macro/nutrient total calculation, safety filtering, allergy claims |
| Goals and coaching | B04 production orchestrator/controllers, goal/preferences and recommendation repositories | Daily briefing, current-food and weekly-review read models, reason/evidence states | Module composition, semantic copy rendering and deep links | Ranking, policy calculation, target mutation or AI authority |
| Exercise preferences | B01 `ExercisePreferenceRepository` and v6+ backup records | Personal setup values and cues keyed by stable exercise identity | Presentation and editing through the existing repository | A second setup-preference table or raw-name owner |
| Navigation and settings | GoRouter `appRouter`; `ThemeModeNotifier`; privacy/settings controllers | Durable destinations, theme/offline/telemetry state | Cross-feature route contract and visual settings presentation | Router-local data authority or duplicated settings store |
| Durable contracts | `AppDatabase`, Backup v9 adapters and transactional restore | v14–v18 fixtures, v5–v9 payloads | One v19 migration and Backup v10 extension | Partial restore, media-binary backup, a second backup pipeline |

## Completion definition

B05 is complete when all required tasks have an `Approved` or `Approved with
non-blocking follow-up` review-and-resolve verdict, B05 data passes v19/v10
migration/restore verification, production surfaces use their inherited
authorities, and the final fresh Sol review of a clean integration head finds
no launch-critical defect. Licensed media/diagram/playlist work remains outside
the mandatory DAG unless the product owner supplies the missing decisions and
source authority.
