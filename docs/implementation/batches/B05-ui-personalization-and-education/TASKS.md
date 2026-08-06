# B05 — UI, Personalization and Education: Task Contracts

## Task rules

Each implementation task has one fresh review-and-resolve session after its
focused verification. A task may merge with an Approved or Approved with
non-blocking follow-up verdict. An actual unresolved defect creates a scoped
remediation before continuing; a historical administrative gap does not.

The approved media/provider package gate is an input to B05-08. It is not
optional and may not be bypassed with unlicensed remote assets.

## B05-01 — Durable personalization, content, media and playlist foundation

| Field | Definition |
|---|---|
| **Objective** | Introduce the single v19 migration and Backup v10 extension for dashboard preferences, education progress, downloaded-media manifest metadata and playlist preference. Define packaged module/content/media/muscle/provider registry contracts and the licensing/packaging acceptance record. |
| **Dependencies** | Accepted B04 baseline only. |
| **Existing authority** | AppDatabase migration graph; Backup v9 transactional adapter; B01 ExercisePreferenceRepository and portable personal cues; existing local-profile convention. |
| **Likely files** | lib/data/database/app_database.dart; table/DAO/repository files; lib/core/backup/backup_v9.dart and successor adapter/model files; generated Drift files; assets/data registry files; pubspec asset declarations; migration/backup/content tests; this batch documentation. |
| **Acceptance criteria** | Schema v19 stores only stable module ID/order/visible/collapsed state, versioned content progress, pack checksum/availability metadata and privacy-minimal playlist choice. Backup v10 validates before atomic restore; v5–v9 import safely with empty B05 state. Registries define known IDs only. The approved-media input template names exact 20 IDs, source/license/attribution, distribution, package budget/checksum, fallback and provider allowlist requirements. |
| **Focused tests** | Fresh v19; direct v18→v19; supported chained upgrade; migration failure/reopen; v5–v10 import/export; malformed/duplicate/unknown records; injected restore rollback; no binary/path/token/raw-provider payload; registry schema validation. |
| **Model / reviewer** | Sol High / fresh Sol High. |
| **Parallelizable** | No. Sole writer of schema, backup, generated code and durable contracts. |
| **Exclusions** | UI customization, media download/playback, diagram rendering, playlist launch, new exercise preferences, user accounts and any B01–B04 algorithm. |

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
| **Acceptance criteria** | Every module has a stable ID, deterministic default, label and eligibility. Users reorder, hide, reveal and collapse known modules; drag has a keyboard/screen-reader equivalent. Duplicate/unknown/malformed preferences normalize safely. Added/removed descriptors preserve deterministic behavior. No size setting or arbitrary persisted widget/configuration is introduced. |
| **Focused tests** | Defaults; order mutation; hide/reveal; collapse/expand; persistence and v10 restore; unknown/duplicate ID; descriptor addition/removal; focus/semantics/customization actions; controller no-domain-calculation guard. |
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
| **Acceptance criteria** | Complete and skip actions are contextual, labelled and accessible without a swipe. They call existing B01 command paths, suppress duplicate pending input, reconcile failures, distinguish unavailable states and provide an undo/restore affordance whenever the underlying state change is destructive/reversible. The surface stays compact/large-text/reduced-motion usable and does not alter occurrence/program logic. |
| **Focused tests** | Complete/skip gesture and button/menu equivalent; confirmation if needed; pending/double input; success/failure; undo/expiry; B01 occurrence immutability regression; player resume; screen-reader/focus/compact/2× text/reduced motion. |
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
| **Acceptance criteria** | Meal type/category accents are registered semantic mappings rather than display-name guesses. Edit/copy/delete gestures have button/menu equivalents, use B03 commands, never fabricate totals, surface pending/error/strict-offline state and offer a visible repository-backed undo for deletion. Layout is light/dark, compact, large-text, focus and reduced-motion compliant. |
| **Focused tests** | Accent/icon mapping; edit/copy/delete actions; cancel; pending/double gesture; successful undo/expired undo/failure; B03 range/unknown/constraint presentation; strict-offline/retry; semantics/focus/compact/2× text. |
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
| **Acceptance criteria** | All five named lessons are bundled, versioned, offline and have explicit completion/dismiss/revisit semantics. Exercise surfaces distinguish catalogue from personal cues, provide contextual checklists and render canonical B02 contribution labels including unknown state. The content progress survives Backup v10. Text/list education remains useful without media. |
| **Focused tests** | Manifest validation; stable ID/version update behavior; complete/dismiss/reopen/revision state; personal-cue overlay; primary/secondary/stabilizing/unknown mapping; offline behavior; v10 restore; light/dark/large-text/semantics/reduced motion. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-06 after its prerequisites. It owns education/exercise detail files and does not touch food/dashboard/router paths. |
| **Exclusions** | Binary media packages, graphical diagram asset implementation, playlist launch, muscle taxonomy/calculation, health/coaching inference and B01 preference duplication. |

## B05-08 — Licensed top-20 media, interactive diagrams and playlist launcher

| Field | Definition |
|---|---|
| **Objective** | Deliver the approved top-20 offline animation/clip pack, optional verified downloads where approved, an accessible interactive muscle diagram, and persisted provider/playlist launch from relevant workout surfaces. |
| **Dependencies** | B05-01, B05-02, B05-05 and B05-07; accepted product-owner media/diagram/provider approval record. |
| **Existing authority** | B05 registries/media-manifest and playlist-preference repositories; B02 muscle IDs/mappings; B01 exercise IDs; existing external URL launcher; strict-offline/privacy settings. |
| **Likely files** | Approved asset files and attribution manifest; pubspec asset declarations; media package/reconciler/download lifecycle code; exercise detail/player media widgets; diagram renderer and text equivalent; playlist preference settings and workout action wiring; tests. |
| **Acceptance criteria** | Exactly the approved 20 stable exercise IDs resolve to assets with verified checksum/source/license/attribution. Bundled/installed content works offline; optional download is opt-in, validated, deletable and never required for cues. Diagram regions map only to B02 IDs, have semantic labels and a text/list equivalent. Reduced motion uses still/non-animated alternatives. Users persist an allowlisted provider/reference, launch it safely from workout surfaces and receive honest invalid/app-missing/offline/failure states. |
| **Focused tests** | 20-ID manifest completeness; checksum/license/attribution validation; absent/invalid/downloaded/deleted/reconciled pack; strict-offline; reduced-motion fallback; diagram region and text labels; unknown mapping; provider allowlist/reference validator; external-launch success/failure/app-missing/offline; v10 playlist/manifest restore. |
| **Model / reviewer** | Sol High / fresh Sol High. |
| **Parallelizable** | Normally no; run before B05-09. It owns settings/playlist/exercise-media integration and depends on a product input. |
| **Exclusions** | Media beyond the approved 20, arbitrary remote embeds, third-party playback/catalog/auth/account integration, user-uploaded media, full-catalogue rollout, diagram-derived muscle calculations and social/community features. |

## B05-09 — Goal-aware, resumable adaptive onboarding

| Field | Definition |
|---|---|
| **Objective** | Make onboarding choose only goal-relevant educational concepts, save/resume incomplete progress, skip completed sections, and hand off once through existing profile/routine authorities. |
| **Dependencies** | B05-01, B05-04 and B05-07. |
| **Existing authority** | OnboardingScreen, RoutineWizardScreen, UserProfileNotifier, existing local onboarding-draft convention, GoRouter and B05 content progress. |
| **Likely files** | lib/features/onboarding/onboarding_screen.dart; routine_wizard_screen.dart; onboarding draft/progress adapter; scoped app_router.dart changes; profile/provider adapters; onboarding/router tests. |
| **Acceptance criteria** | A declarative selected-goal mapping chooses relevant lesson IDs. Draft answers and current step resume after interruption; prior completed content is skipped but revisitable. Back/forward correction and validation are accessible, offline and idempotent. Profile/routine writes occur exactly once through current owners. The flow never infers medical, dietary, readiness or coaching state. |
| **Focused tests** | First run; each goal mapping; interrupted/resume; completed skip/revisit; correction/back/forward; invalid/missing input; duplicate submit; offline; profile/routine handoff once; deep route/redirect; 2× text/semantics/focus/reduced motion. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | No by default. It owns onboarding/router integration after the content and Today contracts have stabilized. |
| **Exclusions** | New profile identity data, automatic behavioral adaptation, medical/calorie/coaching calculation, a second onboarding persistence store, media acquisition and new program semantics. |

## B05-10 — E8 release assurance and targeted remediation

| Field | Definition |
|---|---|
| **Objective** | Validate the integrated B05 product and remedy only demonstrated launch-critical defects across migration/backup, privacy/offline, accessibility, platform build, media/launcher failure and nearby B01–B04 regressions. |
| **Dependencies** | B05-01 through B05-09 merged on one clean integration head. |
| **Existing authority** | Existing privacy/network guard, crash-reporting opt-in filter, health/notification permission state, build configuration, migration/backup harnesses and B01–B04 regression suites. |
| **Likely files** | B05 verification fixtures/tests and, only for a demonstrated defect, the smallest relevant lib/android/ios/configuration file. |
| **Acceptance criteria** | Integrated flows have truthful empty/error/retry/permission-denied/strict-offline/app-missing states. v19/v10 migration/restore pass. Top-20 pack, diagram, playlist and onboarding contracts meet their matrix. Android release and iOS no-code-sign builds are attempted with supplied inputs; device evidence is recorded honestly. No secret/signing material enters source. |
| **Focused tests** | Complete B05 matrix; v19/v10 suite; B01–B04 nearby regression suites; privacy/offline/network interceptor checks; permissions; media/launcher failure tests; startup/config tests; build commands; targeted performance smoke measurement. |
| **Model / reviewer** | Sol High / fresh Sol High. |
| **Parallelizable** | No. It observes shared integration/native/configuration state. |
| **Exclusions** | New product features, store submission, secret provisioning, legal certification, infrastructure deployment and fixes unrelated to an evidenced B05 release defect. |

## B05-11 — Final integrated Sol review and disposition

| Field | Definition |
|---|---|
| **Objective** | Review the clean B05 integration head, resolve concrete launch-critical findings, and record the final evidence-backed disposition. |
| **Dependencies** | B05-10. |
| **Existing authority** | Accepted task contracts, integrated source, verification matrix, media/license approval record and B01–B04 ownership boundaries. |
| **Likely files** | VERIFICATION.md task ledger/final evidence; a new narrowly scoped remediation task only if a real blocker is found. |
| **Acceptance criteria** | Fresh review covers production wiring, four-question Today semantics, personalization persistence, v19/v10 safety, top-20 rights/manifest, external launcher/privacy, onboarding resume, accessibility/reduced motion, platform builds and regressions. Verdict is Approved, Approved with non-blocking follow-up, or evidence-backed Blocked. |
| **Focused tests** | Full command matrix in VERIFICATION.md, B05-focused suites, migration/backup suite, format/analyze/full test, Android release and iOS no-code-sign build when inputs permit, final diff review. |
| **Model / reviewer** | Sol High / fresh Sol High. |
| **Parallelizable** | No. It must examine one clean integration head. |
| **Exclusions** | Feature additions, speculative refactors, invented device evidence, re-opening accepted task scope without a demonstrated defect, and acceptance based solely on ledger completeness. |
