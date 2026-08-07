# B05 — UI, Personalization and Education: Verification

## Working agreement

Each task runs focused tests, formatting, analysis and diff validation, then a
fresh review-and-resolve session. Merge only on Approved or Approved with
non-blocking follow-up. A new review is necessary only after a concrete
remediation; historical transcript gaps do not create speculative rework.

The approved rights/source/manifest record for the top-20 media, anatomy
diagram and playlist-provider formats is required before any corresponding
content activation. B05-08 infrastructure is verified independently through
its fail-closed, unavailable, fallback, reduced-motion, offline and privacy
matrix. B05-01 needs only the contract/template that will validate the record;
the external packet may remain a non-blocking follow-up when no activation is
claimed.

## Required commands

Per task:

~~~text
dart format --output=none --set-exit-if-changed <changed Dart paths>
flutter analyze
flutter test <focused test paths>
git diff --check
~~~

Schema-generated work additionally runs:

~~~text
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed <changed Dart paths>
flutter analyze
~~~

Per integration wave:

~~~text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test <wave-specific regression paths>
git diff --check
~~~

Final B05 gate:

~~~text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
flutter build apk --release --dart-define=INDIFIT_API_KEY=<provided-secret>
flutter build ios --release --no-codesign --dart-define=INDIFIT_API_KEY=<provided-secret>
~~~

The Android build requires the externally managed signing configuration expected
by android/app/build.gradle.kts. Never print, replace or commit release API
keys/signing material. If a configured device, credential or toolchain is not
available, record the attempted command and limitation honestly.

## Focused fixture matrix

| Area | Required fixtures and checks | Pass condition |
|---|---|---|
| B05 durable schema v19 | Fresh v19; populated direct v18→v19; supported v14–v18 chain; each migration failure boundary; reopen/idempotency | B01–B04 rows are unchanged; B05 tables initialize safely; constraints/indexes hold; a failed migration leaves pre-state intact. |
| Backup v10 | v5–v9 imports; valid v10 export/import; invalid/duplicate module/content/pack/provider records; manifest/reference validation; dangling registry item; injected restore failure | Older payloads obtain safe empty B05 state; v10 retains only valid portable metadata; invalid payload fails before mutation; restore is atomic and does not copy media or assert local presence. |
| Module preferences | Defaults; reorder; hide/reveal; collapse/expand; duplicate/unknown ID; ordinal tie; malformed/missing state; descriptor added/removed; passive read versus reconciliation; restore | Normalization follows the declared ignore/first-duplicate/ordinal-then-ID/append-default/default-field/non-collapsible algorithm; no size/grid setting is required; unknown entries never render executable/arbitrary behavior. |
| Semantic design system | Light/dark/system; page/surface/text/status/focus/disabled/action/meal/media states; 8/10/12 radii; restrained surfaces | B05-owned surfaces consume semantic tokens, do not add direct AppColors use, and retain contrast/non-color distinction. |
| Responsive/a11y/motion | Narrow phone; 2× text; keyboard/focus order; semantics labels/values/hints; touch target; screen reader alternatives; reduced-motion flag | No clipped primary action or trapped focus; status/action/collapse is understandable; gesture has an alternate control; nonessential animation/autoplay is disabled with useful still/text path. |
| Today daily action surface | Four labelled questions; deterministic defaults; reorder/hide/collapse; past/today/future; B01/B02 empty states; B03 known/range/unknown; B04 ready/unavailable; next action | One descriptor registry composes Today. It answers what to do/eat/progress/next action without new nutrition/coaching/schedule calculation. |
| Workout swipe actions | Complete/skip swipe and button/menu equivalent; confirmation where needed; pending/double input; repository success/failure; valid undo/expiry; invalid-after-downstream-event path; player resume | B01 command semantics remain authoritative; no list-local mutation; undo appears only where B01 exposes a valid inverse; failure reconciles accurately. |
| Food swipe actions | Edit/copy/delete swipe and button/menu equivalent; cancel; pending/double input; delete restore/correction undo/expiry/failure; unsupported-undo confirmation; meal icon/accent mapping | B03 remains authoritative; deletion undo uses a supported restore or append-only correction, never list-local rollback; no fabricated totals; accents come from registered semantics; strict-offline/retry remains usable. |
| Lessons, cues and checklists | Five exact topics; stable ID/version; complete/dismiss/revisit/revision; personal/catalogue cue overlay; contextual checklist | Lessons work offline; progress is versioned/portable; personal vs catalogue guidance is clear; content does not infer health/diet/coaching state. |
| Muscle labels and diagrams | Primary/secondary/stabilizing/unknown mapping; approved B02-ID-to-region registry; semantic diagram region; labelled text/list equivalent; reduced motion | Diagram and list agree with canonical mappings; unknown remains unknown; visual is never the only representation or a new taxonomy/calculation. |
| Top-20 media bundle | Fail-closed exact-20 manifest/validator boundary; bundled/local available/absent/invalid reconciliation after restore; strict offline; reduced-motion and text/checklist fallback | Missing, malformed or unapproved content remains truthfully unavailable; cues/checklists/text education remain usable; restored metadata never asserts physical availability; no unverified remote fetch or binary backup. When the external packet is supplied, a separate activation check proves all 20 approved IDs, source/license/attribution, checksums and package budget. |
| Playlist launcher | Provider allowlist; scheme/host/path/identifier/length/query contract; typed-reference normalization; preference persistence/restore; valid launch; malformed reference; app missing; strict offline; launcher failure | Only normalized, reconstructed provider URIs launch; failure is editable/non-blocking; no token/account/catalog/playback data persists. |
| Adaptive onboarding | First run; each selected-goal mapping; draft interruption/resume; completed step skip/revisit; correction/back; invalid field; duplicate submission; profile/routine handoff; offline/deep route | Goal mapping is declarative; incomplete state resumes; completed work is not forced again; existing profile/routine path executes once; no inferred condition/coach state. |
| Privacy/offline/platform | Strict-offline flag/network interceptor; external media/URL attempt; photo/telemetry state; Health/notification denied/granted/unavailable; Android/iOS configuration | Core daily, education and onboarding flows remain locally useful; user sees truthful permission/launch/network state; raw photos/prompts/paths/binaries/tokens are not persisted or exported. |

## Deferred media and licensing activation packet

The following packet is required before externally supplied media, graphical
diagram content or enabled provider defaults are activated. Its absence does
not block B05-08 software completion when the fail-closed and fallback matrix
passes:

- [ ] The approved list of exactly 20 stable exercise IDs.
- [ ] Per asset and diagram source, license, permitted distribution/derivative
  terms, attribution requirements and retention/deletion terms.
- [ ] A machine-readable manifest binding each item to its ID, content version,
  checksum, package location and reduced-motion/text fallback.
- [ ] A package-size policy and forward-compatible download/deletion preference
  semantics consistent with strict-offline mode, without requiring a B05
  download lifecycle.
- [ ] A B02-ID-to-diagram-region mapping and accessible text/list equivalent.
- [ ] An approved provider allowlist and playlist-reference validators.
- [ ] Test output proving no binary media/local path/OAuth or raw provider
  payload is included in Backup v10.

## Integration checks

1. After B05-01, run the complete v19/v10 suite before a B05 record appears in
   feature UI. Its acceptance needs the media-contract/template only, not final
   media assets/licenses.
2. After B05-02 and B05-03, run semantic/component and module repository tests
   before merging Today composition.
3. After B05-04, prove the four-question surface remains an adapter over B01–
   B04 and that preferences change only composition.
4. After B05-05 and B05-06, prove gesture, non-gesture, pending, failure and
   undo behavior against their actual B01/B03 commands.
5. After B05-07, verify all five named lessons, versioned progress, offline
   cues/checklists and muscle contribution labels.
6. Before any B05-08 content activation, review the complete media/provider
   approval packet. Independently verify the infrastructure's missing/invalid
   states, device-local reconciliation after restore, diagram fallback,
   reduced motion and launcher failure/offline handling. When the packet is
   supplied, verify all 20 IDs and checksum/source/license state before
   activation. Managed remote downloads are not a B05 test obligation.
7. B05-09 may implement after B05-01 and B05-07. After B05-04 merges, run its
   final interruption/resume/skip/revisit and profile/routine handoff tests
   across each declared goal mapping; deferred B05-08 content does not block
   this verification.
8. B05-10 owns the full B05 matrix, B01–B04 nearby regressions, build attempts
   and actual integration-defect remediation on a clean integration head.
9. During B05-10, record Android/iOS build results, current physical-device
   availability, permission fixture, network state and result. A missing device
   is a follow-up unless it reveals a platform defect.
10. B05-11 read-only reviews the clean release candidate for production wiring,
    historical ownership, migration/backup, rights/packaging, privacy/offline,
    accessibility and regression defects. A blocker creates a separate scoped
    remediation, affected-check rerun and fresh B05-11 review; it does not
    modify application code or block solely on stale historical ledger metadata.

## Launch-readiness coverage

| Release area | B05 coverage | Out of scope / external gate |
|---|---|---|
| Today and personalization | Four-question action surface; stable reorder/hide/collapse; preference restore/fallback | New dashboard product domains or arbitrary user widgets. |
| Food and workout actions | Repository-backed gestures, alternatives, undo/failure/strict-offline behavior | New B01/B03 mutation semantics or nutrition/workout algorithms. |
| Education and media | Versioned five-topic lessons; fail-closed bundled-media/diagram infrastructure; accessible text/list/still fallbacks; local reconciliation that never trusts restored availability | External top-20 assets, graphical diagram content, provider defaults and rights/procurement packet are deferred until activation; remote download lifecycle and content/media beyond 20 remain out of scope. |
| Playlist launch | Persisted allowlisted provider/reference and external launch failure states | Provider account/auth/catalog/streaming or arbitrary URL support. |
| Onboarding | Goal-declared relevance, draft resume, completion skip/revisit, profile/routine handoff | Behavioral/medical/dietary/coaching inference or a second profile store. |
| Accessibility and compact layout | Shared semantics/focus/touch/motion contract plus scoped widget matrix | Fabricated physical-device acceptance; unscoped full-app restyle. |
| Migration/data portability | v19/v10, old backup compatibility, rollback and idempotency | Downgrade support for an older binary that cannot read v19/v10. |
| Privacy/platform builds | Offline/network/permission/launcher truthfulness; Android release and iOS no-code-sign attempts | Legal certification, secret provisioning and signing key custody. |

## B05-10 release-assurance evidence

B05-10 began from the clean integration head `1b89e05` on
`b05/t10-e8-release-assurance`, with the same baseline selected by
`batch/b05-ui-personalization-education`. The initial E8 matrix did not
demonstrate an application defect. A fresh Luna Max review then reproduced a
stale restored playlist-provider state: the settings dropdown could receive an
unapproved provider ID, and the workout launcher could still expose an active
launch path for that invalid preference. The targeted remediation in
`ec9af90` validates the complete saved reference against the current approved
registry, keeps stale preferences editable through settings, and adds a
production-boundary regression test.

The required automated checks passed:

```sh
flutter test \
  test/b05_adaptive_onboarding_test.dart \
  test/b05_backup_v10_test.dart \
  test/b05_dashboard_module_customization_panel_test.dart \
  test/b05_dashboard_personalization_repository_test.dart \
  test/b05_education_content_test.dart \
  test/b05_food_contextual_actions_test.dart \
  test/b05_foundation_registry_test.dart \
  test/b05_media_playlist_test.dart \
  test/b05_schema_v19_migration_test.dart \
  test/b05_semantic_accessibility_primitives_test.dart \
  test/b05_today_daily_action_surface_test.dart \
  test/b05_workout_contextual_actions_test.dart \
  --reporter compact
# 77 passed at the initial E8 candidate

# The same 12-file B05 command was rerun after the playlist remediation.
# 78 passed

flutter test test/b05_media_playlist_test.dart --reporter compact
# 11 passed after remediation

flutter test --reporter compact
# 1,053 passed after remediation

flutter test test/privacy_policy_enforcement_test.dart test/crash_reporting_test.dart test/health_state_controller_test.dart test/phase5_notifications_test.dart test/app_config_test.dart --reporter compact
# 26 passed

flutter test test/b01_program_calendar_widget_test.dart test/b01_equipment_preferences_widget_test.dart test/b02_progress_widget_test.dart test/b02_player_activity_widget_test.dart test/b03_constraint_review_test.dart test/b04_production_ui_test.dart --reporter compact
# 28 passed

flutter test test/b05_schema_v19_migration_test.dart test/b05_backup_v10_test.dart test/b05_education_content_test.dart test/b05_media_playlist_test.dart test/b05_adaptive_onboarding_test.dart test/b05_semantic_accessibility_primitives_test.dart --reporter compact
# 48 passed

/usr/bin/time -p flutter test test/b05_media_playlist_test.dart test/b05_adaptive_onboarding_test.dart test/b05_semantic_accessibility_primitives_test.dart --reporter compact
# 30 passed; real 6.89s

dart format --output=none --set-exit-if-changed lib test
# passed; 425 files, 0 changed
flutter analyze
# passed; no issues found
git diff --check
# passed
```

Privacy/offline tests confirmed that strict-offline network attempts are
blocked by policy, and permission-denied, unavailable and retry states remain
typed. The B05-08 approval packet is still absent; media, graphical diagram
and provider activation therefore remain fail-closed and truthfully
unavailable. No remote or unlicensed substitute was added.

Platform/toolchain evidence:

```text
xcodebuild -version — Xcode 26.6, Build version 17F113
flutter doctor -v — Flutter 3.41.4; Xcode available; Android SDK 36.0.0
```

The Android toolchain is incomplete because `cmdline-tools` is missing and
Android license status is unknown. `INDIFIT_API_KEY` was not supplied;
`android/key.properties` exists, is ignored by `android/.gitignore`, and was
not read. Consequently these release commands were not run with invented
inputs:

```text
flutter build apk --release --dart-define=INDIFIT_API_KEY=<provided-secret>
flutter build ios --release --no-codesign --dart-define=INDIFIT_API_KEY=<provided-secret>
```

No physical iPhone was available for evidence (Flutter reported the discovered
iPhone as unavailable with connection code `-27`), and no device result was
fabricated. Supplying the release API key, completing Android command-line
tools/licenses, and obtaining a usable iOS device remain external follow-ups;
they are not application defects.

## Lightweight task ledger

Update only when implementation/merge information exists. This is a rollback
aid, not a compliance register.

| Task | Implementation commit | Final verdict | Merge commit | Known follow-ups |
|---|---|---|---|---|
| B05-01 | 794bfd5, 5f436c1 | Approved with remediation | 1c82e0c | External media/provider content activation remains deferred; managed remote downloads are deferred. |
| B05-02 | 1762c5c, e33cada | Approved with remediation | 5048884 | None; semantic primitives are the contract consumed by later B05 presentation tasks. |
| B05-03 | 179a505, cc6e244 | Approved with remediation | 3cc2691 | None; Today composition consumes the stable registry/repository contract in B05-04. |
| B05-04 | fe5529e, d36d16a | Approved with remediation | edcf4a4 | None; Today read failures render typed unavailable/retry states without replacing B01–B04 authorities. |
| B05-05 | c88a1a3 | Approved | 67a1371 | None; playlist launch remains a reserved B05-08 slot and no playlist preference is persisted here. |
| B05-06 | 676a2ac, 7b99f52 | Approved with remediation | a252686 | None; B03 exposes no valid deletion inverse, so production delete remains confirmation-only while supported adapters can offer timed undo. |
| B05-07 | 601fb24, 48c3985, 00f4995, 3e03438 | Approved with remediation | 9c4a537 | None; mixed reviewed mappings preserve known B02 labels alongside an explicit unknown state; text education remains independent of media. |
| B05-08 | 1692370, 2cf2fb4 | Approved with non-blocking follow-up | 1b89e05 | Software infrastructure is complete with fail-closed unavailable/fallback behavior; external media, graphical diagram and enabled provider content activation is deferred until the approval packet is supplied. |
| B05-09 | 1692370, 2cf2fb4 | Approved with non-blocking follow-up | 1b89e05 | Not blocked by deferred B05-08 content; release-assurance review found no additional onboarding defect. |
| B05-10 | 7504692, 8b98a68, ec9af90 | Approved with non-blocking follow-up | 1362621 | Initial E8 matrix passed; fresh review found and fixed stale restored playlist-provider handling. Android/iOS build attempts remain pending supplied API key and Android toolchain; no physical-device evidence. External B05-08 content activation remains deferred. |
| B05-11 | — | Planned | — | — |

## Final review checklist

- [ ] Clean integration HEAD; each required B05 task has a valid fresh verdict.
- [ ] No B01–B04 authority has been replaced, re-derived or silently mutated.
- [ ] v19 migration and Backup v10 direct/chained/rollback/idempotency tests
  pass; older backups produce safe empty B05 state.
- [ ] Portable records include module order/visibility/collapse, progress,
  media-pack preference/identity and playlist preference only; no binary/path/
  actual availability/verified state/progress/cache/token/raw provider payload
  exists.
- [ ] Today answers all four questions, has a meaningful next action, and
  consumes B03/B04 output rather than calculating nutrition/coaching.
- [ ] Users can reorder/hide/collapse modules and safely recover defaults.
- [ ] Food edit/copy/delete and workout complete/skip have semantic
  alternatives, pending/failure handling and repository-backed undo where
  destructive/reversible.
- [ ] Semantic B05 surfaces meet light/dark, compact, large-text, focus,
  touch-target, screen-reader and reduced-motion checks.
- [ ] All five named mini lessons are versioned/offline; cues/checklists and
  primary/secondary/stabilizing labels preserve B01/B02 authority.
- [ ] B05-08 software infrastructure fails closed, preserves device-local
  availability truth, and provides reduced-motion and accessible text/list/
  still fallbacks. If content activation is claimed, the approved, licensed
  top-20 manifest, checksums, attribution and diagram/provider packet are also
  present; otherwise the activation packet is recorded as a non-blocking
  follow-up.
- [ ] Playlist provider/reference is allowlisted, portable and safely
  launchable when configured; missing defaults render unavailable, and
  offline/malformed/app-missing failure never blocks workout.
- [ ] Onboarding resumes incomplete state, skips completed content, follows
  selected-goal mapping and commits once through existing profile/routine owners.
- [ ] Strict offline, permission denied, network/media/launcher failure have
  honest recoverable UI.
- [ ] Full format, analysis, test, Android build and iOS no-code-sign build are
  recorded with limitations; no secrets appear in the diff.
- [ ] Fresh Sol final review changes no application code and returns Approved,
  Approved with non-blocking follow-up, or an evidence-backed Blocked verdict.
