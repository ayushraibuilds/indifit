# B05 — UI and Education: Task Authority

## Task workflow

For every task: implement on one task branch, run the focused checks, hold one
fresh review-and-resolve session, fix task-scoped findings in that session, and
merge on `Approved` or `Approved with non-blocking follow-up`. A further review
is required only for an unresolved concrete blocker. The task owner must start
from the approved integration baseline named for its execution wave.

| Task ID | Title | Dependencies | Model | Fresh reviewer | Parallelizable |
|---|---|---|---|---|---|
| B05-01 | M19 v19 / Backup v10 durable contract | — | Sol High | Sol High | No |
| B05-02 | Semantic tokens and responsive primitives | B05-01 | Terra High | Terra High | Yes, with B05-03 |
| B05-03 | Dashboard module preference repository | B05-01 | Luna | Terra High | Yes, with B05-02 |
| B05-04 | Module-driven Today and route integration | B05-02, B05-03 | Terra High | Terra High | Yes, with B05-05 |
| B05-05 | Training, exercise and progress presentation migration | B05-02 | Terra High | Terra High | Yes, with B05-04 |
| B05-06 | Nutrition, profile and settings presentation migration | B05-02 | Terra High | Terra High | Yes, with B05-07 |
| B05-07 | Offline education, checklists and muscle insight | B05-01, B05-02, B05-05 | Terra High | Terra High | Yes, with B05-06 |
| B05-08 | Explicit adaptive onboarding and education entry | B05-04, B05-07 | Terra High | Terra High | No |
| B05-09 | E8 release-assurance remediation and proof | B05-01 through B05-08 | Sol High | Sol High | No |
| B05-10 | Final integrated regression and Sol disposition | B05-09 | Sol High | Sol High | No |

## B05-01 — M19 durable presentation and content contract

| Field | Definition |
|---|---|
| **Objective** | Add the schema v19 / Backup v10 contract for typed dashboard preferences, versioned educational progress and verified optional-media manifests, with migration and restore safety. |
| **Dependencies** | None. This is the sole owner of B05 schema, generated Drift output and backup-version changes. |
| **Existing authority** | `AppDatabase`, v18 migration conventions, `BackupV9Data`/file adapter transaction model, B01 `ExercisePreferenceRepository` and its already-portable setup/cue rows. |
| **Likely files** | `lib/data/database/app_database.dart`; a B05 presentation/content table file; generated `app_database.g.dart`; a `backup_v10.dart` extension; `backup_file_adapter.dart`; backup schema/fixtures; migration and restore tests. |
| **Acceptance criteria** | `schemaVersion` is 19 and export version is 10 only after all new durable entities exist. v18→v19 creates empty B05 rows without rewriting B01–B04 history. Module IDs and progress/media records have owner, uniqueness, ordinal/state/checksum/size validation and indexes. Backup v10 round-trips all B05 records; v5–v9 restore with an empty B05 graph; malformed/duplicate/cross-owner/future payloads fail before mutation; media binaries, paths, prompts, source images and secrets are rejected. Existing exercise preferences retain their owner and v6+ backup representation. |
| **Focused tests** | Fresh v19 schema; direct v18→v19 and supported chained migration fixtures; migration failure injection/reopen/idempotency; v5–v10 import/export; v10 graph validation, restore transaction rollback and no-download restore; B01 preference regression. |
| **Model / reviewer** | Sol High / fresh Sol High. |
| **Parallelizable** | No. It changes `app_database.dart`, backup dispatch and generated artifacts. |
| **Exclusions** | Dashboard rendering, content authoring UI, media downloading, a new exercise-preference table, B01–B04 logic changes and any external asset acquisition. |

## B05-02 — Semantic presentation system and responsive primitives

| Field | Definition |
|---|---|
| **Objective** | Make the theme/extension and shared primitives the semantic authority for shipped light/dark presentation, typography, spacing, restrained surfaces, focus and status treatment. |
| **Dependencies** | B05-01 is merged so later UI contracts use the same approved baseline. |
| **Existing authority** | `AppTheme`, `AppColorsExtension`, `ThemeModeNotifier`, Material `ColorScheme`, existing shared failure/skeleton widgets. |
| **Likely files** | `lib/core/theme/app_theme.dart`, `app_colors_extension.dart`, `colors.dart`; new/updated shared widgets under `lib/core/widgets` or `lib/shared/widgets`; theme/widget tests. |
| **Acceptance criteria** | A documented semantic token API resolves correctly in light, dark and system mode. Shared surface/input/action/failure/loading primitives use it; the scan baseline rejects new fixed-dark semantic values and supplies per-owner migration gates for B05-04 through B05-08. The component rules support dynamic text, keyboard/focus visibility, non-color-only status and compact layouts without imposing a screen-specific layout. |
| **Focused tests** | Light/dark token resolution; component widget tests at normal and 2× text scale; compact width and focus/semantics tests; static guard for forbidden screen-level fixed semantic tokens, excluding palette/theme definitions. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-03. Do not concurrently change shared primitives or theme files. |
| **Exclusions** | Individual feature-screen migration, dashboard ordering, data/schema changes, a new settings persistence owner and visual asset creation. |

## B05-03 — Typed dashboard module preferences and read model

| Field | Definition |
|---|---|
| **Objective** | Establish one B05 repository and descriptor registry for stable Today module IDs, default order, visibility, size and typed configuration. |
| **Dependencies** | B05-01. |
| **Existing authority** | B05-01 persistence graph; B02/B03/B04 read models; `DashboardController` remains the existing data-loading owner until B05-04 composes modules. |
| **Likely files** | New B05 module model/descriptor and repository under `lib/data`; provider registration in `lib/core/di/providers.dart`; focused repository fixtures/tests. |
| **Acceptance criteria** | Valid defaults include the existing workout, nutrition and B04 coaching modules by stable ID. Reorder/hide/resize commands are deterministic, reject duplicate/unknown/invalid configuration, preserve valid user choices when a default is introduced, and never mutate a domain record. A module whose descriptor is unavailable is retained safely but cannot render arbitrary content. |
| **Focused tests** | Default projection; reorder/visibility/size boundary cases; invalid module/configuration failures; current/new descriptor merge; owner isolation; v10 round trip and older-backup default behavior. |
| **Model / reviewer** | Luna / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-02. It must not touch dashboard UI/controllers, app routing or theme primitives. |
| **Exclusions** | Dashboard widgets, recommendation ranking, nutrition totals, B04 feedback logic, arbitrary JSON/module plug-ins and global navigation changes. |

## B05-04 — Module-driven Today and durable route integration

| Field | Definition |
|---|---|
| **Objective** | Replace fixed Today composition with the B05 module registry/preferences while preserving explicit date behavior and inherited B01–B04 read authorities. |
| **Dependencies** | B05-02 and B05-03. |
| **Existing authority** | `DashboardScreen`/`DashboardController`, `MainNavigationScaffold`, GoRouter, B03 `NutritionReadModelRepository`, B04 production recommendation controllers, B01/B02 workout entries. |
| **Likely files** | `lib/features/dashboard/dashboard_screen.dart`, `dashboard_controller.dart`, dashboard widgets including the meal module, B04 production-surface widgets, `main_navigation_scaffold.dart`, scoped `app_router.dart` routes and dashboard widget/controller tests. |
| **Acceptance criteria** | Users can choose valid module visibility/order/size and receive a deterministic default Today. Daily briefing/current-food cards remain B04 consumers; workouts use B01/B02 entries; canonical nutrition totals/history come from B03 read models rather than a competing dashboard calculation. Empty, error, unknown/range and unavailable states are explicit, accessible and preserve selected local date. Durable cross-feature destinations use the declared router contract; local sheets stay local. |
| **Focused tests** | Module order/hidden/new-module widget cases; selected-date and refresh behavior; B03 canonical versus legacy-compatibility read cases; B04 unavailable/evidence rendering; large-text/compact/semantics navigation; route restoration for Today destinations. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-05 after both start from the same Wave 2 baseline. It exclusively owns dashboard/navigation files. |
| **Exclusions** | B04 policy/engine changes, B03 nutrient/constraint calculation, B01 occurrence mutation, a dashboard-wide algorithm or a global Navigator rewrite. |

## B05-05 — Training, execution and progress presentation migration

| Field | Definition |
|---|---|
| **Objective** | Migrate the scoped training, activity, calendar, equipment, workout-player and progress surfaces to B05 semantic/responsive/accessibility rules without changing their domain contracts. |
| **Dependencies** | B05-02. |
| **Existing authority** | B01 programs/calendar/equipment and setup preferences; B02 execution/activity/volume read models; existing GoRouter routes and transient player sheets. |
| **Likely files** | Scoped files under `lib/features/activity`, `calendar`, `equipment`, `program_authoring`, `workout_player`, `progress`, `reports` and `travel`; their widget tests. `player_setup_cues_panel.dart` is reserved for B05-07. |
| **Acceptance criteria** | Scoped screens have no fixed-dark semantic-token violations; use shared visual states; support compact width, large text, keyboard/focus traversal and non-color-only completion/unknown/error states. Cross-feature actions use existing durable routes where applicable, while sheets retain local results. Activity/schedule/execution/volume values and missingness are presented exactly as read. |
| **Focused tests** | Scoped static token guard; representative player/activity/calendar/progress widgets in both themes; 2× text scale, focus/semantics and compact width; B01 occurrence/B02 activity/volume unavailable-state regressions. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-04. It must not edit dashboard, router, theme primitives or the B05 education panel. |
| **Exclusions** | New workout modalities, scheduling semantics, load/volume algorithms, exercise-catalogue data edits, B05 content progress or education/media assets. |

## B05-06 — Nutrition, profile and settings presentation and safe interactions

| Field | Definition |
|---|---|
| **Objective** | Apply the semantic system to nutrition, food-log, profile and settings journeys, adding canonical category accents and only reversible swipe/undo actions. |
| **Dependencies** | B05-02. |
| **Existing authority** | B03 nutrition/constraint/estimate repositories, B04 goal/coaching settings, `UserProfileNotifier`, privacy/settings controllers and existing backup/restore flow. |
| **Likely files** | Scoped files under `lib/features/food_log`, `nutrition`, `profile` and `settings`, plus their widgets/tests. `DashboardMealSection` remains B05-04-owned. |
| **Acceptance criteria** | Scoped screens resolve semantic tokens in both brightnesses; food accents come from canonical/registered category semantics rather than display-name guesses; compact/large text and failure/retry/strict-offline states are usable. A swipe action is added only where the underlying repository supports a tested reversible command and visible undo; irreversible, safety-sensitive and pending data are never silently dismissed. |
| **Focused tests** | Theme/static token guard per owned path; category accent mapping; Dismissible/undo success, cancel, double-action and failure cases; nutrition unknown/range/constraint and B04 policy-unavailable presentation; settings privacy/offline/backup error widget tests. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-07. It must not change shared theme, dashboard, app router, database or backup files. |
| **Exclusions** | Nutrition arithmetic/safety changes, new photo/AI behavior, profile schema redesign, backup-format changes, dashboard module layout and media download implementation. |

## B05-07 — Offline education, checklists and muscle insight

| Field | Definition |
|---|---|
| **Objective** | Introduce a bundled, versioned education registry and accessible checklist/lesson/muscle-insight surfaces that reuse canonical cues, personal setup and muscle mappings. |
| **Dependencies** | B05-01, B05-02 and B05-05. |
| **Existing authority** | `Exercise` stable IDs and seeded cues; B01 `ExercisePreferenceRepository`; B02 `Muscles`/`ExerciseMuscleMappings` and volume read model; B05-01 content-progress/media-manifest repository. |
| **Likely files** | Bundled education manifest under `assets/data`; `lib/features/exercise_library`, `player_setup_cues_panel.dart`, a B05 education repository/controller/screen and provider; manifest/model/widget tests. |
| **Acceptance criteria** | Core cues/checklists/lessons are available offline by stable content/exercise ID and content version. Personal cues are clearly distinguished from catalogue cues; B02 muscle data and unknown states are rendered without a second taxonomy. Progress changes are explicit, versioned and portable. Missing or unverified media has a text/checklist fallback and never fetches implicitly. An accessible labelled muscle-insight list is mandatory; a graphical anatomy map is enabled only with an approved, mapped asset. |
| **Focused tests** | Manifest validation; stable-ID/version/content-progress transitions; personal-cue overlay; B02 primary/secondary/unknown mapping presentation; offline/missing-media fallback; light/dark, large-text and semantics widget tests; v10 progress/manifest restore regression. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | Yes, only with B05-06 after B05-05 has merged. It owns the named education/exercise-detail files. |
| **Exclusions** | Unlicensed animations, commissioned diagram art, media binary download/storage, playlist provider integration, exercise/muscle schema changes, health/coaching inference and B01 preference duplication. |

## B05-08 — Explicit adaptive onboarding and education entry

| Field | Definition |
|---|---|
| **Objective** | Make onboarding, routine-wizard handoff and entry into appropriate bundled education explicit, recoverable, accessible and routed through the merged B05 contracts. |
| **Dependencies** | B05-04 and B05-07. |
| **Existing authority** | `OnboardingScreen`, `RoutineWizardScreen`, `UserProfileNotifier`, nutrition-goal compatibility path, GoRouter and B05 content-progress registry. |
| **Likely files** | `lib/features/onboarding/onboarding_screen.dart`, `routine_wizard_screen.dart`, onboarding widgets, scoped `app_router.dart` changes, profile/provider adapters and onboarding/router widget tests. |
| **Acceptance criteria** | Users can resume/correct explicit onboarding answers, receive validation and reach the existing profile/routine authority exactly once. Education prompts are selected from declared answers, current progress or an explicit B04 link; no age/health/dietary/medical inference and no B04 policy activation occurs. The flow works with no network, announces errors, supports keyboard/screen reader/large text and preserves a truthful incomplete state. |
| **Focused tests** | First use, resume, back/forward correction, invalid/missing input, duplicate submission, offline, profile/routine handoff and route redirect tests; dynamic text, semantics/focus and lesson-progress prompt cases. |
| **Model / reviewer** | Terra High / fresh Terra High. |
| **Parallelizable** | No. It shares the router and consumes merged Today/content contracts. |
| **Exclusions** | New profile identity data, medical/calorie/coaching calculation, automatic behavioral adaptation, a second onboarding persistence store, new training program semantics and media acquisition. |

## B05-09 — E8 release-assurance remediation and proof

| Field | Definition |
|---|---|
| **Objective** | Verify and remediate only actual B05 launch-critical defects across migrations/backups, privacy/offline, permissions, accessibility, performance and supported builds. |
| **Dependencies** | B05-01 through B05-08, merged into a clean integration head. |
| **Existing authority** | Existing privacy/network guard, crash-reporting opt-in filter, health service/permission state, notification service, build configuration, migration/backup harnesses and B01–B04 regression suites. |
| **Likely files** | B05 verification fixtures/tests and, only for confirmed defects, the smallest relevant application/native/configuration file under `lib`, `android`, `ios` or CI. |
| **Acceptance criteria** | The integrated app has truthful empty/error/retry/permission-denied/strict-offline states; no core B05 journey requires network or unverified media. v19/v10 direct/chained migration, old-backup compatibility and restore rollback pass. Android release and iOS no-code-sign builds are attempted with supplied credentials/defines; actual device checks are recorded honestly. No secrets/signing material are committed. A confirmed issue is fixed with focused regression coverage or is an explicit external blocker. |
| **Focused tests** | B05 widget/semantics/compact tests; v19/v10 migration/backup suite; B01–B04 owner regressions; privacy/offline/network-interceptor checks; health/notification permission state tests; startup/config tests; build commands and targeted performance smoke measurements. |
| **Model / reviewer** | Sol High / fresh Sol High. |
| **Parallelizable** | No. It observes the integrated product and shared native/configuration files. |
| **Exclusions** | New features, store submission, production-secret provisioning, legal certification, infrastructure deployment and remediation unrelated to a demonstrated B05 release defect. |

## B05-10 — Final integrated regression and Sol disposition

| Field | Definition |
|---|---|
| **Objective** | Review the current clean B05 integration head for actual launch-critical defects and record the final disposition. |
| **Dependencies** | B05-09. |
| **Existing authority** | The accepted B05 task contracts, current integrated code, verification matrix and B01–B04 historical ownership boundaries. |
| **Likely files** | `VERIFICATION.md` task ledger/final evidence; no application file unless a new scoped remediation task is created for a concrete blocker. |
| **Acceptance criteria** | Fresh Sol review covers production wiring, schema/backup safety, historical ownership, privacy/offline, native builds, accessibility and regressions. Full formatting, analysis, tests and B05-focused suites are recorded. Verdict is `Approved`, `Approved with non-blocking follow-up` or `Blocked`; only an actual unresolved defect blocks. |
| **Focused tests** | Full command matrix in `VERIFICATION.md`, B05-focused tests, migration/backup suites, Android release and iOS no-code-sign build when credentials/tooling permit, plus the final diff review. |
| **Model / reviewer** | Sol High / fresh Sol High. |
| **Parallelizable** | No. It must see one clean integration head. |
| **Exclusions** | Feature additions, speculative refactors, re-reviewing already resolved tasks for process compliance, invented device evidence and acceptance based solely on ledger completeness. |
