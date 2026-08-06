# B05 — UI, Personalization and Education: Verification

## Working agreement

Each task runs focused tests, formatting, analysis and diff validation, then a
fresh review-and-resolve session. Merge only on Approved or Approved with
non-blocking follow-up. A new review is necessary only after a concrete
remediation; historical transcript gaps do not create speculative rework.

The approved rights/source/manifest record for the top-20 media, anatomy
diagram and playlist-provider formats is required evidence for B05-08 and the
final gate. Its absence leaves B05 incomplete rather than converting the
feature to optional polish.

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
| Backup v10 | v5–v9 imports; valid v10 export/import; invalid/duplicate module/content/pack/provider records; checksum/version/reference validation; dangling registry item; injected restore failure | Older payloads obtain safe empty B05 state; v10 retains valid metadata; invalid payload fails before mutation; restore is atomic and does not download/copy media. |
| Module preferences | Defaults; reorder; hide/reveal; collapse/expand; duplicate/unknown ID; malformed config; descriptor added/removed; restore | Deterministic order and visibility persist; collapse survives; no size/grid setting is required; unknown entries never render executable/arbitrary behavior. |
| Semantic design system | Light/dark/system; page/surface/text/status/focus/disabled/action/meal/media states; 8/10/12 radii; restrained surfaces | B05-owned surfaces consume semantic tokens, do not add direct AppColors use, and retain contrast/non-color distinction. |
| Responsive/a11y/motion | Narrow phone; 2× text; keyboard/focus order; semantics labels/values/hints; touch target; screen reader alternatives; reduced-motion flag | No clipped primary action or trapped focus; status/action/collapse is understandable; gesture has an alternate control; nonessential animation/autoplay is disabled with useful still/text path. |
| Today daily action surface | Four labelled questions; deterministic defaults; reorder/hide/collapse; past/today/future; B01/B02 empty states; B03 known/range/unknown; B04 ready/unavailable; next action | One descriptor registry composes Today. It answers what to do/eat/progress/next action without new nutrition/coaching/schedule calculation. |
| Workout swipe actions | Complete/skip swipe and button/menu equivalent; confirmation where needed; pending/double input; repository success/failure; undo/expiry; player resume | B01 command semantics remain authoritative; no list-local mutation; destructive/reversible changes have visible undo; failure reconciles accurately. |
| Food swipe actions | Edit/copy/delete swipe and button/menu equivalent; cancel; pending/double input; delete undo/expiry/failure; meal icon/accent mapping | B03 remains authoritative; no unsafe hidden delete/fabricated totals; accents come from registered semantics; strict-offline/retry remains usable. |
| Lessons, cues and checklists | Five exact topics; stable ID/version; complete/dismiss/revisit/revision; personal/catalogue cue overlay; contextual checklist | Lessons work offline; progress is versioned/portable; personal vs catalogue guidance is clear; content does not infer health/diet/coaching state. |
| Muscle labels and diagrams | Primary/secondary/stabilizing/unknown mapping; approved B02-ID-to-region registry; semantic diagram region; labelled text/list equivalent; reduced motion | Diagram and list agree with canonical mappings; unknown remains unknown; visual is never the only representation or a new taxonomy/calculation. |
| Top-20 media pack | Exact 20 stable exercise IDs; signed-off source/license/attribution; checksum; bundled/installed/unavailable/invalid/deleted/reconciled state; optional-download lifecycle; strict offline | All 20 approved items resolve offline after install/bundle; invalid/missing pack has honest still/text/checklist fallback; no unverified remote fetch or binary backup. |
| Playlist launcher | Provider allowlist; accepted reference formats; preference persistence/restore; valid launch; malformed reference; app missing; strict offline; launcher failure | Only safe provider/reference pairs launch; failure is editable/non-blocking; no token/account/catalog/playback data persists. |
| Adaptive onboarding | First run; each selected-goal mapping; draft interruption/resume; completed step skip/revisit; correction/back; invalid field; duplicate submission; profile/routine handoff; offline/deep route | Goal mapping is declarative; incomplete state resumes; completed work is not forced again; existing profile/routine path executes once; no inferred condition/coach state. |
| Privacy/offline/platform | Strict-offline flag/network interceptor; external media/URL attempt; photo/telemetry state; Health/notification denied/granted/unavailable; Android/iOS configuration | Core daily, education and onboarding flows remain locally useful; user sees truthful permission/launch/network state; raw photos/prompts/paths/binaries/tokens are not persisted or exported. |

## Media and licensing evidence packet

B05-08 cannot be marked complete until the following are available in the
implementation evidence:

- [ ] The approved list of exactly 20 stable exercise IDs.
- [ ] Per asset and diagram source, license, permitted distribution/derivative
  terms, attribution requirements and retention/deletion terms.
- [ ] A machine-readable manifest binding each item to its ID, content version,
  checksum, package location and reduced-motion/text fallback.
- [ ] A package-size/download policy and optional-download/delete behavior
  consistent with strict-offline mode.
- [ ] A B02-ID-to-diagram-region mapping and accessible text/list equivalent.
- [ ] An approved provider allowlist and playlist-reference validators.
- [ ] Test output proving no binary media/local path/OAuth or raw provider
  payload is included in Backup v10.

## Integration checks

1. After B05-01, run the complete v19/v10 suite before a B05 record appears in
   feature UI.
2. After B05-02 and B05-03, run semantic/component and module repository tests
   before merging Today composition.
3. After B05-04, prove the four-question surface remains an adapter over B01–
   B04 and that preferences change only composition.
4. After B05-05 and B05-06, prove gesture, non-gesture, pending, failure and
   undo behavior against their actual B01/B03 commands.
5. After B05-07, verify all five named lessons, versioned progress, offline
   cues/checklists and muscle contribution labels.
6. Before B05-08, review the complete media/provider approval packet. After
   it, verify all 20 IDs, checksum/source/license state, diagram fallback,
   download lifecycle, reduced motion and launcher failure/offline handling.
7. After B05-09, run interruption/resume/skip/revisit onboarding and
   profile/routine handoff tests across each declared goal mapping.
8. Before B05-10, execute the full B05 matrix and B01–B04 nearby regressions
   on a clean integration head.
9. During B05-10, record Android/iOS build results, current physical-device
   availability, permission fixture, network state and result. A missing device
   is a follow-up unless it reveals a platform defect.
10. B05-11 reviews the clean integrated diff for production wiring, historical
    ownership, migration/backup, rights/packaging, privacy/offline,
    accessibility and regression defects. It does not block solely on stale
    historical ledger metadata.

## Launch-readiness coverage

| Release area | B05 coverage | Out of scope / external gate |
|---|---|---|
| Today and personalization | Four-question action surface; stable reorder/hide/collapse; preference restore/fallback | New dashboard product domains or arbitrary user widgets. |
| Food and workout actions | Repository-backed gestures, alternatives, undo/failure/strict-offline behavior | New B01/B03 mutation semantics or nutrition/workout algorithms. |
| Education and media | Versioned five-topic lessons; approved offline top-20 pack; accessible diagrams; optional verified download lifecycle | Content/media beyond 20; rights/procurement input not supplied by product owner. |
| Playlist launch | Persisted allowlisted provider/reference and external launch failure states | Provider account/auth/catalog/streaming or arbitrary URL support. |
| Onboarding | Goal-declared relevance, draft resume, completion skip/revisit, profile/routine handoff | Behavioral/medical/dietary/coaching inference or a second profile store. |
| Accessibility and compact layout | Shared semantics/focus/touch/motion contract plus scoped widget matrix | Fabricated physical-device acceptance; unscoped full-app restyle. |
| Migration/data portability | v19/v10, old backup compatibility, rollback and idempotency | Downgrade support for an older binary that cannot read v19/v10. |
| Privacy/platform builds | Offline/network/permission/launcher truthfulness; Android release and iOS no-code-sign attempts | Legal certification, secret provisioning and signing key custody. |

## Lightweight task ledger

Update only when implementation/merge information exists. This is a rollback
aid, not a compliance register.

| Task | Implementation commit | Final verdict | Merge commit | Known follow-ups |
|---|---|---|---|---|
| B05-01 | — | Planned | — | Media/provider approval packet required before B05-08. |
| B05-02 | — | Planned | — | — |
| B05-03 | — | Planned | — | — |
| B05-04 | — | Planned | — | — |
| B05-05 | — | Planned | — | — |
| B05-06 | — | Planned | — | — |
| B05-07 | — | Planned | — | — |
| B05-08 | — | Planned | — | Mandatory asset/license/provider gate. |
| B05-09 | — | Planned | — | — |
| B05-10 | — | Planned | — | Build credentials/device availability recorded honestly. |
| B05-11 | — | Planned | — | — |

## Final review checklist

- [ ] Clean integration HEAD; each required B05 task has a valid fresh verdict.
- [ ] No B01–B04 authority has been replaced, re-derived or silently mutated.
- [ ] v19 migration and Backup v10 direct/chained/rollback/idempotency tests
  pass; older backups produce safe empty B05 state.
- [ ] Portable records include module order/visibility/collapse, progress,
  media-manifest metadata and playlist preference only; no binary/path/token/
  raw provider payload exists.
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
- [ ] The approved, licensed top-20 asset manifest, checksums, attribution,
  offline availability, optional-download behavior, reduced-motion fallback
  and accessible diagram text equivalent are present.
- [ ] Playlist provider/reference is allowlisted, portable and safely
  launchable; offline/malformed/app-missing failure never blocks workout.
- [ ] Onboarding resumes incomplete state, skips completed content, follows
  selected-goal mapping and commits once through existing profile/routine owners.
- [ ] Strict offline, permission denied, network/media/launcher failure have
  honest recoverable UI.
- [ ] Full format, analysis, test, Android build and iOS no-code-sign build are
  recorded with limitations; no secrets appear in the diff.
- [ ] Fresh Sol final review returns Approved, Approved with non-blocking
  follow-up, or an evidence-backed Blocked verdict.
