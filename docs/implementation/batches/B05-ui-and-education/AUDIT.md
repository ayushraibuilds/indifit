# B05 — UI and Education: Targeted Audit

## Planning questions

The audit was intentionally limited to these questions:

1. Which canonical E6, E7, M19 and E8 outcomes are still absent from the
   accepted B04 baseline, and which were delivered by B01–B04?
2. Which production screens, routes, controllers, repositories and shared
   widgets own Today, visual tokens, dashboard preferences, content/cue
   rendering, onboarding, media links and swipe actions?
3. Which durable user-owned records are genuinely needed for dashboard
   preferences, education progress and media manifests; do they require a
   schema or backup version after B04?
4. Which release-critical gaps are supported by the roadmap and current
   repository evidence for permissions, privacy, offline behavior,
   accessibility, migration/backup recovery and platform builds?
5. Which legacy UI paths, direct theme tokens, raw navigation paths, hard-coded
   cues, preference keys or test/debug entry points must be retired or isolated
   to prevent competing authorities?
6. Which tasks share schema/backup, theme, navigation, dashboard/controller or
   shared-component files and must be serialized; which can be parallel?

## Baseline and scope finding

`bc4dfa31ac9392f24ae6a702b02c76303e3ae8dc` is the current B04 integration
head and records `merge(B04-F01): integrate production orchestration
remediation`. It contains the accepted B04 production-orchestrator corrective
merge and is the exact B05 planning parent. It is an ancestor of B05 `HEAD`.

The canonical tracker supplies the exact title **B05 — UI and Education**.
The canonical roadmap maps it to E6/F5, the release-ready portion of E7/F6 and
M19. Because the roadmap has a separate Phase 8/E8, B05 is both the final
planned feature batch and the final launch-readiness batch, with E8 treated as
a verification/remediation gate rather than a new domain.

`doc/launch_readiness_plan.md` and its gap analysis were consulted only as
historical context, not as scope authority: their stated baseline predates the
accepted B04 tree and several claims conflict with current code (for example,
the current `pubspec.yaml` has `health` and `sentry_flutter`, and native Health
permissions are present). The canonical roadmap and current source control the
plan.

## Relevant findings

| Question | Relevant evidence | Finding and B05 consequence |
|---|---|---|
| What remains for E6? | `AppTheme`, `AppColorsExtension`, `ThemeModeNotifier`, 73 Dart files / 972 `AppColors.` references | Light/dark themes and a settings picker already exist, but feature screens still embed the dark palette. B05 needs one semantic-token/primitives task followed by ownership-separated screen migrations, not a second theme store. |
| What remains for Today/U1/U5? | `DashboardScreen`, `DashboardController`, `MainNavigationScaffold`; B04 daily briefing/current-food cards | Today has date navigation and B04 cards but fixed composition. It directly reaches legacy food reads/fallbacks while B03 read models exist. B05 must add stable module preference/read-model ownership, remove competing authoritative calculations, and preserve B04 cards as consumers. |
| Are M19 records already present? | `ExerciseUserPreferences`, `ExerciseSetupValues`, `ExercisePersonalCues`; `ExercisePreferenceRepository`; Backup v9 legacy payload | B01 already owns and backs up setup values/personal cues. No `DashboardModulePreference`, `ContentProgress`, `EducationContent`, or downloaded-media manifest exists. New B05 durable records are required; duplicate exercise preference records are forbidden. |
| Is a new schema/backup justified? | `AppDatabase.schemaVersion == 18`; `BackupV9Data.currentVersion == 9`; v18→v9 graph is transactional | Yes. Dashboard customizations and content-progress records are portable user-owned state, and the M19 media-manifest seam must preserve verified-pack state without binary data. B05 needs schema v19 and Backup v10. |
| What education is usable now? | `assets/data/exercises.json`; `Exercise.formCues` / `commonMistakes`; `ExerciseDetailsSheet`; `PlayerSetupCuesPanel` | Seeded cues and B01 personal cues exist but are separated and display-oriented. There are no lessons, progress records, checklists, media assets or content manifest. B05 should bundle versioned text/checklists and reuse existing IDs/cues. |
| Can B05 ship animation/diagram/playlist assets? | No media assets under `assets/`; no media manifest; all exercise `youtube_id` values are empty; roadmap decisions 5–6 remain unanswered | No licensed asset or distribution authority exists. The mandatory path has accessible text/checklist/muscle-insight fallback and a verified-pack seam. Actual animations, commissioned anatomy art and playlist content are conditional/post-launch. |
| What owns muscle information? | B02 `Muscles`, `ExerciseMuscleMappings`, `B02MuscleVolumeRepository` | B05 may render canonical muscle contribution and unknown states. It must not derive a second muscle taxonomy or volume algorithm. |
| What owns onboarding and navigation? | `OnboardingScreen`, `RoutineWizardScreen`, `UserProfileNotifier`, GoRouter `appRouter` | Onboarding is a resumable SharedPreferences draft and commits profile data through the existing profile/goal path. B05 may make the flow explicit/accessibly routed and attach education prompts, but cannot introduce behavior/health inference or bypass the profile authority. |
| Is raw navigation a blanket migration? | 167 `Navigator.` references; GoRouter top-level routes; most hits are dialogs/sheets | No. B05 standardizes durable cross-feature destinations, while modal closing remains local. This avoids a risky, non-product-wide rewrite. |
| What launch evidence is missing? | 145 test files, 63 `testWidgets`, zero `integration_test` files and zero golden references | Compact/large-text and platform journeys need a focused matrix. B05 adds only release-critical golden/widget/integration-style coverage, not an unrelated test-framework rewrite. |
| Are privacy/offline/platform foundations present? | `PrivacyPolicy`, network interceptor, photo cleanup, crash filter, `HealthService`, Android manifest, iOS plist | Core guards and declared permissions exist. B05 must verify truthful permission/disclosure states, strict-offline behavior and real-device/simulator paths; it must not claim a successful platform test without evidence. |
| What release configuration is external? | `AppConfig` requires `INDIFIT_API_KEY` in release; Android release requires `key.properties`; iOS can use `--no-codesign` | B05 can validate configured builds but may not create/commit secrets or signing material. Missing credentials are an external release gate, not an implementation branch task. |

## Existing owners B05 must retain

| Owner | Read by B05 | Required boundary |
|---|---|---|
| B01 calendar/program and exercise preference repositories | Today workout entry, stable exercise identity, setup values and personal cues | Render/use commands through existing repositories; do not mutate program/occurrence rules or add a preference copy. |
| B02 activity/progress/muscle repositories and Health service | Activity cards, muscle insight, health permission/result presentation | Do not recalculate volume, fabricate health values, or reinterpret modality history. |
| B03 nutrition read model and constraint evaluator | Today totals, meal module, status/range/unknown presentation | Retire dashboard totals as an authority; never fall back from unknown to a fabricated exact value. |
| B04 production orchestrator and controllers | Daily briefing, current-food, weekly-review card states | Preserve one recommendation authority, evidence wording and policy/AI guards. |
| GoRouter plus settings/privacy/theme state owners | Cross-feature routes, mode selections, strict offline policy | No screen-owned router/store or persistence fork. |
| `AppDatabase` and Backup v9 transaction model | v19 tables and v10 extension | One migration and one atomic restore graph; no media binary/path/prompt/raw provider payload. |

## Confirmed gaps and risks

1. The semantic migration is broad, but its risk is presentation correctness,
   not a reason to rewrite every screen together. Shared token work must land
   before three bounded production-surface migrations.
2. Today is the central collision point: its module/order UI must wait for the
   persistent module contract, and its B03/B04 reads must be adapters rather
   than direct calculations.
3. Schema/backup must be first and alone. v19/v10 needs direct v18 upgrade,
   supported chained upgrade and v5–v10 restore fixtures, including rollback.
4. Current exercise education has no asset rights, no verified manifest and no
   bundled media. A missing asset must render an honest text/checklist fallback
   instead of a remote dependency or fabricated visual.
5. The release gate must distinguish a test/build result from an actual
   physical-device result. Android/iOS device checks are recommended and become
   blockers only if they reveal a defect, consistent with the accepted solo
   workflow.
6. B03 r3 non-blocking follow-ups remain B03-owned: 592 explicitly
   `manualReview` catalogue rows, a guarded-delete/archive regression,
   cross-contact truth-table coverage, disposable CI build-runner/format
   idempotence and historical reviewer-process evidence. B05 may present
   unknown/unavailable states but must not silently absorb or "fix" them.
7. B04-F01 repaired production recommendation orchestration. No outstanding
   B04 implementation defect is recorded at the accepted parent; retained B04
   non-blocking evidence includes truthful physical-device coverage and its
   safety/activation boundaries. B05 cannot activate `ENABLED-1`, loosen
   `READINESS-HOLD-1`, or alter B04 policy history.

## Accepted review carryover

| Source | Finding | B05 treatment |
|---|---|---|
| B04-F01 commit trail | Production recommendation orchestration needed remediation after its review; `bbb01d2` resolved it and `bc4dfa3` integrated it. | Treat the repaired orchestrator as B04 authority. Regress it through Today; do not rewrite its recommendation logic. |
| B04 verification workflow | The historical task ledger is incomplete/stale and physical-device coverage is recommended rather than automatically blocking. | Administrative history is a non-blocking follow-up. B05 records fresh current results and blocks only on a demonstrated runtime/safety/privacy/migration defect. |
| B03 r3 final disposition | 592 manual-review catalogue rows, guarded-delete/archive coverage, cross-contact truth-table coverage, disposable CI generation/format idempotence and reviewer-process evidence remain follow-ups. | Do not absorb B03 remediation. Render uncertainty/unavailable accurately and include only the nearby regressions necessary to prove B05 does not bypass B03. |

## Planning consequences

- Start with B05-01 (schema v19/Backup v10) and merge it before any task reads
  or writes B05 state.
- Merge the semantic system and module repository before Today composition.
- Never run more than two tasks concurrently. The allowed pairs are defined in
  `PLAN.md`; no pair shares schema/backup, a central controller, navigation or
  the same feature-owner files.
- Treat media licensing/distribution, anatomy artwork and playlist-provider
  choices as a conditional product gate, not an excuse to block the main UI,
  education-text and release-readiness path.
