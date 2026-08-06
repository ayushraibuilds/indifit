# B05 — UI, Personalization and Education: Targeted Audit

## Audit questions

1. Which requested B05 outcomes already have an owner or partial surface in the
   accepted B04 baseline, and what is genuinely absent?
2. Which repositories/controllers remain authoritative for Today, food,
   workouts, progress, education, onboarding, settings, and navigation?
3. Which durable records are needed for module layout, education progress,
   media-pack state, and playlist choice, and do they justify a schema /
   backup version?
4. What code and product evidence is required to make offline top-20 exercise
   media, interactive diagrams, and an external playlist launcher safe?
5. Which UI files are appropriate for focused modernization, and where would a
   broad consistency rewrite violate scope?
6. What must be verified for compact layouts, large text, semantics, focus,
   touch targets, reduced motion, offline/privacy, and Android/iOS behavior?

## Baseline and scope finding

`bc4dfa31ac9392f24ae6a702b02c76303e3ae8dc` is the accepted B04 integration
head (`merge(B04-F01): integrate production orchestration remediation`) and
is the B05 planning parent. It contains the B04-F01 production-orchestrator
correction; B05 consumes that repaired authority rather than rewriting it.

The canonical roadmap names the earlier batch **B05 — UI and Education** and
maps it to E6/F5, M19, the release-ready E7/F6 content path, and final E8
assurance. The explicit product specification expands that name to **B05 — UI,
Personalization and Education** and makes media, adaptive onboarding, swipe
actions, and playlist launch concrete required outcomes. This document treats
the explicit specification as the controlling B05 scope where it is more
specific than the canonical roadmap.

`doc/launch_readiness_plan.md` and related historical launch documents were
consulted only for context. Their baseline predates accepted B04 work and
conflicts with current source in places; they are not scope authority.

## Requested-feature cross-reference

| Requested feature | Existing evidence | Plan task(s) | Audit consequence |
|---|---|---|---|
| Action-first Today, four questions | `DashboardScreen`, `DashboardController`, `MainNavigationScaffold`, B04 briefing/current-food cards | B05-03, B05-04 | Convert fixed composition into a descriptor-driven surface; use B01–B04 reads and make “next action” explicit. |
| Reorder/hide/collapse modules | No stable module preference entity found | B05-01, B05-03 | Add stable IDs plus portable ordinal/visibility/collapsed state; remove prior plan’s unsupported size setting. |
| Semantic design modernization | `AppTheme`, `AppColorsExtension`, `ThemeModeNotifier`; 73 Dart files / 972 `AppColors.` references | B05-02, B05-04–09 | Themes already exist; build a semantic layer and migrate only B05 journeys, not all 73 files. |
| Responsive/accessibility/reduced motion | 145 tests, 63 widget tests; no integration-test/golden suite identified | B05-02, B05-04–10 | Add an explicit contract and focused widget/semantics matrix for compact, 2× text, focus order, touch targets, reduced motion and platforms. |
| Food and workout swipes/undo | Existing food and calendar/execution repositories own mutation; UI action coverage is partial | B05-05, B05-06 | Bind gestures to authoritative commands only; prove undo/error/idempotence rather than inventing widget-local mutation. |
| Top-20 media and muscle diagrams | `assets/data/exercises.json`, exercise cues/mistakes, B02 mappings; no media assets or diagram registry | B05-01, B05-07, B05-08 | B05-01 defines the contract/template only. Actual selection, rights/source and package approval gate B05-08, not B05-02 through B05-07. Text/list fallback is accessible behavior, not a substitute for the required approved pack. |
| Versioned lessons | No `lesson`, `MediaAsset`, or `ContentProgress` model found | B05-01, B05-07 | Bundle registry and portable progress for RPE, progressive overload, protein, energy balance and recovery. |
| Goal-aware resumable onboarding | `OnboardingScreen`, `RoutineWizardScreen`, `UserProfileNotifier`; SharedPreferences draft | B05-01, B05-09 | Reuse bounded draft state and versioned completion records; static mapping from declared goal only, no inferred health/coaching state. |
| Provider/playlist launcher | `url_launcher` exists; no launcher preference or provider integration found | B05-01, B05-08 | Persist only allowlisted provider/reference metadata; no OAuth, streaming catalog, token, or remote dependency. |

## Relevant evidence and findings

| Question | Relevant evidence | Finding and B05 consequence |
|---|---|---|
| What remains for Today? | `DashboardScreen`, `DashboardController`, `MainNavigationScaffold`; existing B04 daily briefing/current-food cards | Today already has date navigation and B04 cards, but fixed composition and some legacy food reads remain. B05 must introduce one module registry and consume B03/B04 state as presentation inputs, not construct another dashboard data authority. |
| Are durable B05 records present? | B01 `ExerciseUserPreferences`, `ExerciseSetupValues`, `ExercisePersonalCues`; Backup v9 | B01 setup/personal cues already have a portable owner. No module preference, content progress, media manifest, or playlist preference exists. B05 needs v19 and Backup v10, not a duplicate exercise-preference model. |
| Is schema/backup change justified? | `AppDatabase.schemaVersion == 18`; `BackupV9Data.currentVersion == 9`; transactional restore path | Yes. Layout, content completion, portable pack preference/identity, and a playlist choice are user-owned state. Media binaries, local paths, actual availability, verified-on-this-device state, provider credentials, and raw provider payloads must not be backed up. |
| What education is available now? | `assets/data/exercises.json`; `Exercise.formCues` / `commonMistakes`; `ExerciseDetailsSheet`; `PlayerSetupCuesPanel` | Seeded and personal cues exist, but no versioned mini-lesson registry, checklist contract, media assets, content progress or diagram resource exists. Reuse stable exercise IDs and canonical mapping, do not copy data into a B05 taxonomy. |
| What owns muscles? | B02 `Muscles`, `ExerciseMuscleMappings`, `B02MuscleVolumeRepository` | B05 can show primary, secondary and stabilizing contributions and unknown states. It may not derive mappings or volume itself. Diagrams must be a visual rendering of canonical IDs, with a text equivalent. |
| Can top-20 media ship today? | No media under `assets`; no media manifest; exercise `youtube_id` values empty; prior roadmap license decisions unresolved | No. The product requirement makes this a delivery gate, not a reason to silently defer. B05-01 establishes only the source/rights/pack contract and may proceed now; B05-08 starts once the approved 20-ID manifest and assets are available. B05-02 through B05-07 do not wait for them. |
| What owns onboarding? | `OnboardingScreen`, `RoutineWizardScreen`, `UserProfileNotifier`, GoRouter; local resume draft | Existing flow can retain uncommitted answers locally and commits profile/routine data through current owners. B05 should persist completion/progress via its content contract and resume draft state without a second profile owner. |
| What does navigation evidence permit? | GoRouter top-level routes and roughly 167 `Navigator.` usages, mostly sheets/dialogs | Do not force a global router rewrite. Durable feature destinations use GoRouter; local sheet/dialog dismissal stays local. |
| What privacy/platform foundations exist? | `health`, `sentry_flutter`, Android Health permissions, iOS usage descriptions, privacy network blocker/offline mode, temporary-photo cleanup | Foundational guards exist. B05 must prove truthful permission/offline/external-launch states and both platform builds; it must not invent device results or commit credentials. |
| What release configuration is external? | `AppConfig` requires `INDIFIT_API_KEY` for release; Android release requires `key.properties`; iOS supports `--no-codesign` | Build credentials/signing remain external gates. B05 can attempt documented builds with supplied inputs and record limits honestly. |

## Durable-record recommendation

One B05 migration and one Backup v10 adapter extension should introduce only
the portable metadata below:

| Record | Key fields | Why it is durable | Prohibited payload |
|---|---|---|---|
| `dashboard_module_preferences` | stable `module_id`, ordinal, visible, collapsed, updated-at | Restores the user’s Today layout | Arbitrary widget type/configuration, module data, raw calculations |
| `education_content_progress` | stable content ID, content version, state, updated-at | Preserves completed/dismissed/resumable educational steps across restore | Lesson bodies, free-text health inference, duplicate profile data |
| `media_pack_preferences` | selected/requested pack ID, manifest identity, advisory last-known installed version, download preference, deletion choice, content acknowledgement, updated-at | Restores intent and identity only; a device-local reconciler determines availability after restore | Binary clips, local path, actual availability, verified-on-this-device state, progress/cache status, tokens, analytics/telemetry payload |
| `workout_playlist_preferences` | allowlisted provider ID, validated playlist reference, optional user label, updated-at | Persists a user-selected launcher choice | OAuth secrets, session/token data, playlist catalog/cache |

Bundled content and asset registry metadata remain version-controlled package
data. The database holds user state and pack preference/identity only; physical
availability is derived locally.

## Risks and non-negotiable boundaries

1. **Rights and packaging are a narrow product input.** B05-01 needs the
   registry/acceptance-template contract only. The exact top-20 stable IDs,
   rights, attribution, approved sources, distribution constraints, package
   budget, diagrams and provider allowlist must be approved before B05-08.
   Missing approval keeps B05 incomplete, but does not stop unrelated B05 work
   or authorize remote scraping/placeholder copyright material.
2. **Today is the collision point.** Its registry/order UX depends on B05-03;
   its data must remain adapters over B01–B04. Any direct legacy food total
   that competes with B03 must be removed or isolated.
3. **Gesture safety is domain safety.** Food deletion, copy and editing and
   workout complete/skip must use repository commands, handle failed calls,
   support assistive equivalents, and expose undo for a destructive change.
4. **Visual modernization must be bounded.** Shared primitives plus Today,
   food, workout/player, exercise education, onboarding and relevant settings
   are in scope. A full sweep of every screen is not.
5. **Motion is optional enhancement.** Platform reduced-motion preference must
   disable auto-playing/transitional effects and leave a still/text/action
   path. Media must never be necessary to understand exercise safety cues.
6. **Content adaptation is explicit, not diagnostic.** A static configuration
   maps the selected goal to relevant lessons. B05 may not infer conditions,
   diet, readiness or coaching needs from profile or behavior.
7. **Prior-batch carryover remains owned by its batch.** B03’s 592
   `manualReview` rows, guarded archive/delete regression, cross-contact
   truth table, disposable build-runner/format CI and reviewer-process
   evidence remain B03 follow-ups. B04 policy/safety activation boundaries
   remain B04-owned. B05 presents their state faithfully and does not absorb
   their remediation.

## Planning consequences

- B05-01 is the sole schema/backup/content/asset-contract writer and must land
  before any B05 persisted state is shown. It does not wait for final assets or
  licenses; it records their required acceptance shape.
- B05-02 and B05-03 establish the semantic and module foundations before
  Today composition.
- B05-04 through B05-09 use declared file ownership and at most two
  non-overlapping workstreams at once; schema/backup, shared theme,
  central dashboard controller, router, and global settings files are
  serialized.
- B05-08 is mandatory but narrowly license-gated. Its absence is a visible B05
  blocker, not a post-launch reclassification; it does not block B05-02
  through B05-07 from progressing.
- B05-10 owns the integrated automated/build matrix and actual defect
  remediation on a clean release candidate. B05-11 is an independent read-only
  disposition; an evidenced blocker creates a separate scoped remediation and
  fresh review. Both distinguish real defects from unavailable
  credentials/devices or historical administrative gaps.
