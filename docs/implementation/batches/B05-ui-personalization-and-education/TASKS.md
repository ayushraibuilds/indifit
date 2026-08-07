# B05 — UI, Personalization and Education: Task Contracts

## Task rules

Each implementation task has one fresh review-and-resolve session after its
focused verification. A task may merge with an Approved or Approved with
non-blocking follow-up verdict. An actual unresolved defect creates a scoped
remediation before continuing; a historical administrative gap does not.

The approved media/provider package is required for any later content
activation. Under the solo-development exception it is not a prerequisite for
B05-08 software infrastructure, and it may not be bypassed with unlicensed
remote assets.

## B05-01 — Durable personalization, content, media and playlist foundation

| Field | Definition |
|---|---|
| **Objective** | Introduce the single v19 migration and Backup v10 extension for dashboard preferences, education progress, portable media-pack preference/manifest identity and playlist preference. Define packaged module/content/media/muscle/provider registry contracts and the licensing/packaging acceptance template. |
| **Dependencies** | Accepted B04 baseline only. |
| **Existing authority** | AppDatabase migration graph; Backup v9 transactional adapter; B01 ExercisePreferenceRepository and portable personal cues; existing local-profile convention. |
| **Likely files** | lib/data/database/app_database.dart; table/DAO/repository files; lib/core/backup/backup_v9.dart and successor adapter/model files; generated Drift files; assets/data registry files; pubspec asset declarations; migration/backup/content tests; this batch documentation. |
| **Acceptance criteria** | Schema v19 stores only stable module ID/order/visible/collapsed state, versioned content progress, selected/requested pack identity, advisory last-known installed version, user download/deletion preference, acknowledgement and privacy-minimal playlist choice. Backup v10 validates before atomic restore; v5–v9 import safely with empty B05 state. It never stores/exports physical availability, verified-on-this-device state, local paths, bytes, progress or cache. Registries define known IDs only; provider entries define provider-specific parse/normalization rules. The media acceptance template defines the later 20-ID/license/attribution/distribution/package/checksum/fallback approval, but does not require final assets or licenses for this task. |
| **Focused tests** | Fresh v19; direct v18→v19; supported chained upgrade; migration failure/reopen; v5–v10 import/export; malformed/duplicate/unknown records; injected restore rollback; restored preference followed by local available/absent/invalid reconciliation; no binary/path/availability/token/raw-provider payload; registry and provider-parser schema validation. |
| **Model / reviewer** | Sol High / fresh Sol High. |
| **Parallelizable** | No. Sole writer of schema, backup, generated code and durable contracts. |
| **Exclusions** | UI customization, media download/playback, diagram rendering, playlist launch, final asset/license approval, new exercise preferences, user accounts and any B01–B04 algorithm. |

## B05-02 — Semantic design, accessibility and reduced-motion primitives

| Field | Definition |
|---|---|
| **Objective** | Add semantic light/dark presentation tokens and shared B05 primitives for status/focus/disabled/action/meal/media states, 8/10/12 px radii, type/spacing/icons, touch targets, responsive reflow and reduced motion. |
| **Dependencies** | B05-01 merged. |
| **Existing authority** | AppTheme, AppColorsExtension, ThemeModeNotifier and existing app shell/theme picker. |
| **Likely files** | lib/core/theme/app_theme.dart; app_colors_extension.dart or successor semantic extension; shared UI primitives; narrow app-shell wiring where required; focused widget/static-token tests. |
| **Acceptance criteria** | B05-owned surfaces can resolve semantic colors in both brightnesses. Shared contracts cover page/surface/text/border/focus/disabled/status/action/meal/media state, 8/10/12 radii, touch target and motion behavior. Platform reduced-motion disables nonessential transitions/autoplay and retains still/text alternatives. No new direct AppColors use lands in B05-owned production files. |
| **Focused tests** | Light/dark/system token resolution; contrast/state distinction; focus/disabled/selected semantics; compact width; 2× text; keyboard traversal; minimum-target probes; reduced-motion widget behavior; static guard over B05-owned paths. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-03 after B05-01. Shared app-shell edits are serialized by agreement. |
| **Exclusions** | Full repository theme sweep, broad navigation rewrite, feature data changes, module persistence, media assets and domain calculations. |

## B05-03 — Stable dashboard module registry and personalization repository

| Field | Definition |
|---|---|
| **Objective** | Build one known-module descriptor registry and B05 repository/controller for default order, user reordering, hide/show and collapse persistence. Provide an accessible customization model. |
| **Dependencies** | B05-01. |
| **Existing authority** | AppDatabase/Backup v10 B05 records; DashboardController/MainNavigationScaffold for eventual consumer wiring; B01–B04 providers for descriptor eligibility/read adapters. |
| **Likely files** | lib/features/dashboard/dashboard_controller.dart; new dashboard module descriptor/preference repository/controller files; customization sheet/widget; B05 DAO/provider files; registry/repository/widget tests. |
| **Acceptance criteria** | Every module has a stable ID, deterministic default, label and eligibility. Users reorder, hide, reveal and collapse known modules; drag has a keyboard/screen-reader equivalent. Normalization is exact: ignore unknown IDs; keep the first valid duplicate; sort by ordinal then stable ID; append new descriptors in registry-default order; apply missing visibility/collapse defaults; force non-collapsible modules open; persist only after explicit mutation or dedicated reconciliation. No size setting or arbitrary persisted widget/configuration is introduced. |
| **Focused tests** | Defaults; order mutation; hide/reveal; collapse/expand; persistence and v10 restore; unknown/duplicate ID; ordinal tie; descriptor addition/removal; missing field/non-collapsible normalization; no implicit persistence during passive read; focus/semantics/customization actions; controller no-domain-calculation guard. |
| **Model / reviewer** | Luna High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-02 after B05-01. It must not change shared theme primitives or compose Today modules. |
| **Exclusions** | Today visual redesign, B03/B04 fact calculation, dashboard-size grids, data/widget plugins and global settings migration. |

## B05-04 — Today daily action surface

| Field | Definition |
|---|---|
| **Objective** | Redesign Today as the primary daily action surface and explicitly answer what to do, what to eat, how progress is going and what next action to take. Consume the B05-03 personalization contract. |
| **Dependencies** | B05-02 and B05-03. |
| **Existing authority** | B01 calendar/execution reads and commands; B02 activity/progress reads; B03 NutritionReadModelRepository and constraint states; B04 briefing/current-food/review controllers; dashboard descriptors. |
| **Likely files** | lib/features/dashboard/dashboard_screen.dart; dashboard_controller.dart; MainNavigationScaffold scoped wiring; B04 card adapters; DashboardMealSection; dashboard module widgets and tests. |
| **Acceptance criteria** | Default visible composition clearly labels the four questions and puts an actionable next step on the daily surface. Reordered/hidden/collapsed modules obey preferences. Past/today/future date behavior is preserved. B03 known/range/unknown and B04 available/unavailable state are rendered faithfully, with direct legacy reads removed or isolated where they compete. No widget calculates nutrition/coaching/scheduling facts. |
| **Focused tests** | Four-question semantics/order; defaults/customization persistence; date navigation; B03 known/range/unknown; B04 ready/unavailable; B01/B02 empty/incomplete state; next-action deep link/command; compact/2× text/focus/reduced motion/light-dark. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-05 after Wave 1. It exclusively owns dashboard/controller/module composition files. |
| **Exclusions** | B04 recommendation ranking/policy, B03 arithmetic/constraints, B01 occurrence semantics, a full app-shell/router rewrite and non-Today screen redesign. |

## B05-05 — Workout contextual interactions and launcher surface

| Field | Definition |
|---|---|
| **Objective** | Add responsive, accessible workout-item swipe actions for complete and skip, with explicit non-swipe equivalents, undo/reconciliation where supported, and a reserved action location for B05-08 playlist launch. |
| **Dependencies** | B05-02. B05-08 consumes its workout action surface. |
| **Existing authority** | B01 CalendarRepository/CalendarReadRepository and execution commands; B02 execution/activity presentation; existing player/calendar routes and sheets. |
| **Likely files** | Scoped lib/features/calendar and lib/features/workout_player widgets/controllers; action/undo adapters; relevant activity/progress widgets where workout status appears; widget/controller tests. |
| **Acceptance criteria** | Complete and skip actions are contextual, labelled and accessible without a swipe. They call existing B01 command paths, suppress duplicate pending input, reconcile failures and distinguish unavailable states. Offer undo only when B01 exposes an inverse/restore operation that remains valid after downstream execution events; otherwise confirm or omit the destructive gesture. The surface stays compact/large-text/reduced-motion usable and does not alter occurrence/program logic. |
| **Focused tests** | Complete/skip gesture and button/menu equivalent; confirmation if needed; pending/double input; success/failure; valid undo/expiry; invalid-after-downstream-event no-undo path; B01 occurrence immutability regression; player resume; screen-reader/focus/compact/2× text/reduced motion. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-04. It must not edit dashboard, shared theme, router or education files. |
| **Exclusions** | New workout modalities, schedule/program/progression logic, exercise catalogue changes, playlist persistence/URL validation, media/diagram implementation and B02 volume calculation. |

## B05-06 — Food contextual interactions and meal presentation

| Field | Definition |
|---|---|
| **Objective** | Modernize high-frequency food-log/Today meal presentation with meal-specific icons/subtle semantic accents and add edit, copy and delete swipe actions plus visible undo for destructive deletion. |
| **Dependencies** | B05-02. |
| **Existing authority** | B03 food/consumption/recipe/thali repositories, NutritionReadModelRepository, NutritionConstraintEvaluator and existing mutation/restore contracts. |
| **Likely files** | Scoped lib/features/food_log and nutrition widgets/controllers; meal accent/icon mapping; safe action/undo adapters; focused tests. DashboardMealSection remains B05-04-owned except for a jointly agreed shared primitive. |
| **Acceptance criteria** | Meal type/category accents are registered semantic mappings rather than display-name guesses. Edit/copy/delete gestures have button/menu equivalents, use B03 commands, never fabricate totals and surface pending/error/strict-offline state. Delete undo is offered only through a B03-supported restore or append-only correction; no widget-local list rollback is allowed. Layout is light/dark, compact, large-text, focus and reduced-motion compliant. |
| **Focused tests** | Accent/icon mapping; edit/copy/delete actions; cancel; pending/double gesture; successful repository restore/correction undo, expired undo/failure, unsupported-undo confirmation; B03 range/unknown/constraint presentation; strict-offline/retry; semantics/focus/compact/2× text. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-07 after B05-02. It does not edit shared themes, database, backup, dashboard controller or router. |
| **Exclusions** | Nutrient arithmetic, safety filtering, photo/AI changes, profile schema, backup format, full nutrition screen redesign and media downloads. |

## B05-07 — Versioned mini lessons, cues, checklists and muscle labels

| Field | Definition |
|---|---|
| **Objective** | Implement offline versioned content for RPE, progressive overload, protein, energy balance and recovery, then surface exercise form checklists, catalogue/personal cues and primary/secondary/stabilizing muscle labels. |
| **Dependencies** | B05-01 and B05-02. |
| **Existing authority** | Exercise stable IDs and seeded cues; B01 ExercisePreferenceRepository/personal cues; B02 Muscles, ExerciseMuscleMappings and volume read model; B05 content-progress repository. |
| **Likely files** | Assets/data education manifest; new education registry/repository/controller/widgets; lib/features/exercise_library; player_setup_cues_panel.dart; content progress provider; manifest/model/widget tests. |
| **Acceptance criteria** | All five named lessons are bundled, versioned, offline and have explicit completion/dismiss/revisit semantics. Exercise surfaces distinguish catalogue from personal cues, provide contextual checklists and render canonical B02 contribution labels including unknown state. The content progress survives Backup v10. B05-07 is independently shippable: text/list education remains useful when a media pack is missing/invalid and never blocks a workout. |
| **Focused tests** | Manifest validation; stable ID/version update behavior; complete/dismiss/reopen/revision state; personal-cue overlay; primary/secondary/stabilizing/unknown mapping; offline behavior; v10 restore; light/dark/large-text/semantics/reduced motion. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-06 after its prerequisites. It owns education/exercise detail files and does not touch food/dashboard/router paths. |
| **Exclusions** | Binary media packages, graphical diagram asset implementation, playlist launch, muscle taxonomy/calculation, health/coaching inference and B01 preference duplication. |

## B05-08 — Bundled top-20 media, interactive diagrams and playlist launcher

| Field | Definition |
|---|---|
| **Objective** | Implement fail-closed bundled top-20 media, interactive-diagram and playlist-launch infrastructure from relevant workout surfaces. Activation of externally supplied media, graphical diagram assets and provider defaults is deferred until its approval packet exists; remote download lifecycle is explicitly deferred. |
| **Dependencies** | B05-01, B05-02, B05-05 and B05-07. The product-owner media/diagram/provider approval record is required before later content activation, not before the software boundary can complete. |
| **Existing authority** | B05 registries/media-manifest and playlist-preference repositories; B02 muscle IDs/mappings; B01 exercise IDs; existing external URL launcher; strict-offline/privacy settings. |
| **Likely files** | Media manifest/validator and attribution contract; optional approved bundled asset declarations; device-local media resolver; exercise detail/player media widgets; diagram renderer and text equivalent; playlist preference settings and workout action wiring; tests. |
| **Acceptance criteria** | Registries and validators reject invalid or unapproved content; missing content produces truthful unavailable states; exercise cues/checklists/text education remain usable; reduced motion uses still/non-animated alternatives; diagram regions map only to B02 IDs and retain semantic text/list equivalents; workouts do not depend on media; users persist only allowlisted provider references parsed and normalized by provider-specific scheme/host/path/length/query rules; arbitrary URLs/providers cannot launch; strict-offline, app-missing and launch-failure states remain editable and non-blocking. When supplied later, the exact approved 20 stable IDs, checksums, source/license/attribution, package budget, graphical assets and provider defaults must pass the same contracts before activation. |
| **Focused tests** | Missing/invalid/unapproved manifest and provider content fails closed; local available/absent/invalid reconciliation after restore; strict-offline; reduced-motion fallback; diagram region and text labels; unknown mapping; provider-specific scheme/host/path/length/query validator and normalization; external-launch success/failure/app-missing/offline; v10 playlist/pack-preference restore. When the external packet is supplied, add exact-20 ID, checksum/license/attribution and package-budget activation evidence. |
| **Model / reviewer** | Sol High / fresh Sol High. |
| **Parallelizable** | Yes, with B05-09 only when its settings/exercise/workout files are disjoint from onboarding/router files. Deferred external content activation is not a B05-09 dependency. |
| **Exclusions** | Remote download lifecycle, interrupted/background downloads, partial-pack recovery, storage cleanup, retry orchestration, media beyond the approved 20, arbitrary remote embeds, third-party playback/catalog/auth/account integration, user-uploaded media, full-catalogue rollout, diagram-derived muscle calculations and social/community features. |

## B05-09 — Goal-aware, resumable adaptive onboarding

| Field | Definition |
|---|---|
| **Objective** | Make onboarding choose only goal-relevant educational concepts, save/resume incomplete progress, skip completed sections, and hand off once through existing profile/routine authorities. |
| **Dependencies** | B05-01 and B05-07. Final handoff verification waits for B05-04. Deferred B05-08 content activation does not block this task. |
| **Existing authority** | OnboardingScreen, RoutineWizardScreen, UserProfileNotifier, existing local onboarding-draft convention, GoRouter and B05 content progress. |
| **Likely files** | lib/features/onboarding/onboarding_screen.dart; routine_wizard_screen.dart; onboarding draft/progress adapter; scoped app_router.dart changes; profile/provider adapters; onboarding/router tests. |
| **Acceptance criteria** | A declarative selected-goal mapping chooses relevant lesson IDs. Draft answers and current step resume after interruption; prior completed content is skipped but revisitable. Back/forward correction and validation are accessible, offline and idempotent. Profile/routine writes occur exactly once through current owners. The flow never infers medical, dietary, readiness or coaching state. Its final completion handoff is tested after B05-04 merges, but the onboarding implementation does not wait for the Today redesign. |
| **Focused tests** | First run; each goal mapping; interrupted/resume; completed skip/revisit; correction/back/forward; invalid/missing input; duplicate submit; offline; profile/routine handoff once; deep route/redirect; 2× text/semantics/focus/reduced motion. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, with B05-08 only when onboarding/router files are disjoint from settings/exercise/workout files. Complete final handoff testing after B05-04. |
| **Exclusions** | New profile identity data, automatic behavioral adaptation, medical/calorie/coaching calculation, a second onboarding persistence store, media acquisition and new program semantics. |

## B05-10 — E8 release assurance and targeted remediation

| Field | Definition |
|---|---|
| **Objective** | Own release-candidate preparation: validate the integrated B05 product and remedy only demonstrated launch-critical defects across migration/backup, privacy/offline, accessibility, platform build, media/launcher failure and nearby B01–B04 regressions. |
| **Dependencies** | B05-01 through B05-09 merged on one clean integration head. |
| **Existing authority** | Existing privacy/network guard, crash-reporting opt-in filter, health/notification permission state, build configuration, migration/backup harnesses and B01–B04 regression suites. |
| **Likely files** | B05 verification fixtures/tests and, only for a demonstrated defect, the smallest relevant lib/android/ios/configuration file. |
| **Acceptance criteria** | Integrated flows have truthful empty/error/retry/permission-denied/strict-offline/app-missing states. v19/v10 migration/restore pass. B05-08 infrastructure, its unavailable/fallback behavior, diagram/list contract, playlist validation and onboarding contracts meet their matrix; supplied media/provider content is checked against the retained packet before activation. The absence of that packet is non-blocking unless it causes an actual runtime defect. All actual integration defects are fixed with focused regressions before the clean release candidate is handed to B05-11. Android release and iOS no-code-sign builds are attempted with supplied inputs; device evidence is recorded honestly. No secret/signing material enters source. |
| **Focused tests** | Complete B05 matrix; v19/v10 suite; B01–B04 nearby regression suites; privacy/offline/network interceptor checks; permissions; media/launcher failure tests; startup/config tests; build commands; targeted performance smoke measurement. |
| **Model / reviewer** | Sol High / fresh Sol High. |
| **Parallelizable** | No. It observes shared integration/native/configuration state. |
| **Exclusions** | New product features, store submission, secret provisioning, legal certification, infrastructure deployment and fixes unrelated to an evidenced B05 release defect. |

## B05-11 — Final integrated Sol review and disposition

| Field | Definition |
|---|---|
| **Objective** | Independently review the clean B05 release candidate and record an evidence-backed final disposition. Do not modify application code. |
| **Dependencies** | B05-10. |
| **Existing authority** | Accepted task contracts, integrated source, verification matrix, media/license approval record when activation is claimed, the B05-08 fail-closed contract and B01–B04 ownership boundaries. |
| **Likely files** | VERIFICATION.md task ledger/final evidence only. A real blocker creates a separate narrowly scoped remediation task/branch; B05-11 itself changes no application code. |
| **Acceptance criteria** | Fresh review covers production wiring, four-question Today semantics, personalization persistence, v19/v10 safety, B05-08 fail-closed infrastructure and unavailable/fallback behavior, top-20 rights/manifest when activation is claimed, external launcher/privacy, onboarding resume, accessibility/reduced motion, platform builds and regressions. Deferred external content is recorded as a non-blocking follow-up unless a runtime defect is evidenced. Verdict is Approved, Approved with non-blocking follow-up, or evidence-backed Blocked. A blocker triggers one scoped remediation, affected-check rerun and a fresh B05-11 disposition rather than reviewer-authored implementation. |
| **Focused tests** | Full command matrix in VERIFICATION.md, B05-focused suites, migration/backup suite, format/analyze/full test, Android release and iOS no-code-sign build when inputs permit, final diff review. |
| **Model / reviewer** | Sol High / fresh Sol High. |
| **Parallelizable** | No. It must examine one clean integration head. |
| **Exclusions** | All application-code changes, feature additions, speculative refactors, invented device evidence, re-opening accepted task scope without a demonstrated defect, and acceptance based solely on ledger completeness. |
