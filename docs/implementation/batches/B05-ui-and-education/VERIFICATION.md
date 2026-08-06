# B05 — UI and Education: Verification

## Working agreement

Each task runs focused tests, formatting, analysis and `git diff --check`, then
uses one fresh review-and-resolve session. Merge on `Approved` or `Approved
with non-blocking follow-up`. A new review is needed only when that session
leaves an actual blocker unresolved.

## Required commands

Per task: `dart format --output=none --set-exit-if-changed <changed Dart paths>`,
`flutter analyze`, `flutter test <focused test paths>`, and `git diff --check`.

Schema-generated tasks additionally run
`dart run build_runner build --delete-conflicting-outputs`, then re-run
formatting and analysis.

Per integration wave: `dart format --output=none --set-exit-if-changed lib test`,
`flutter analyze`, `flutter test <wave-specific regression paths>`, and
`git diff --check`.

Final B05 gate:

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- `git diff --check`
- `flutter build apk --release --dart-define=INDIFIT_API_KEY=<provided-secret>`
- `flutter build ios --release --no-codesign --dart-define=INDIFIT_API_KEY=<provided-secret>`

The Android build also requires the externally managed signing configuration
expected by `android/app/build.gradle.kts`. Never print, commit or replace the
release API key or signing material. If a configured platform/toolchain is not
available, record the attempted command and limitation honestly.

## Focused fixture matrix

| Area | Required fixtures and checks | Pass condition |
|---|---|---|
| M19 schema v19 | Fresh v19 database; direct populated v18→v19; supported v14–v18 upgrade paths; each migration failure boundary; reopen/idempotency | B01–B04 rows are unchanged, B05 tables start empty, indexes/constraints exist and failure leaves the pre-state intact. |
| Backup v10 | v5–v9 imports; valid v10 export/import; duplicate IDs; invalid owner/module/order/content/version/checksum/size; dangling/unknown registry item; injected restore failure | v5–v9 obtain empty B05 state, v10 retains B05 state, invalid payloads fail before mutation, restore is atomic and does not download media. |
| Module preferences | Defaults; order/visibility/size; duplicate/unknown ID; malformed config; added/removed descriptor; owner isolation | Defaults are deterministic, valid custom choices survive, unavailable modules cannot execute/render arbitrary behavior. |
| Semantic system | Light/dark/system; status/focus/disabled states; shared surface/input/action components | No fixed dark semantic value is used by scoped screens; contrast and state distinction derive from tokens. |
| Compact/accessibility | Narrow phone; large text; keyboard/focus; screen reader semantics; non-color-only status | No overflow/trapped focus; actions and unavailable/error state are understandable and operable. |
| Today composition | Visible/hidden/reordered modules; past/today/future local date; B03 known/range/unknown; B04 available/unavailable | One module registry composes the screen; B03/B04 read authorities retain their meaning and no dashboard calculation becomes authoritative. |
| Training/progress UI | B01 occurrence state; B02 activity modality, missing volume/muscle map and player resume | UI does not mutate/reinterpret schedule/activity history and presents unknown versus zero correctly. |
| Nutrition/settings UI | Canonical category accent; B03 range/constraint/estimate; B04 goal/policy unavailable; undo success/cancel/failure | No unsafe delete, fabricated nutrient value or safety claim; strict offline and retry states remain usable. |
| Education | Stable content ID/version; complete/dismiss/reopen; B01 personal cue overlay; B02 primary/secondary/unknown muscles; unavailable media | Bundled content works offline, progress is portable, personal/catalogue cues are distinguished and no second muscle taxonomy is created. |
| Onboarding | First run; resume; correction/back; invalid field; duplicate submit; profile/routine handoff; offline and deep route | Existing profile/routine paths run exactly once, no health/dietary/coaching inference occurs and incomplete state is recoverable. |
| Privacy/offline/media | Strict-offline flag; network interceptor; external media/URL attempt; photo/telemetry state; restore of media manifest | Core UI/content works locally, blocked remote calls have honest copy, and raw photos/prompts/paths/binaries are not persisted/exported. |
| Native/platform | Health and notification permission denied/granted/unavailable states; Android/iOS configuration; clean install/upgrade | The app names the actual permission/result state and does not claim a device result without evidence. |

## Integration checks

1. After B05-01, run all migration/backup suites before B05 records are shown
   in any UI.
2. After B05-02/03, run semantic/component and module-repository tests before
   merging Today composition.
3. After every UI wave, run the changed feature widgets plus B01–B04 nearby
   regressions for the repositories/controllers they consume.
4. Before B05-09, execute the complete v19/v10 suite, presentation/education
   fixture matrix, privacy/offline checks and a full app test suite.
5. During B05-09, record Android/iOS build results, current device availability,
   permissions fixture, network state and result. A missing physical device is
   a follow-up unless it exposes a platform defect.
6. B05-10 reviews the current clean integrated diff for production wiring,
   historical ownership, migration/backup, privacy, offline and regression
   defects. It does not block merely on missing historical transcript metadata.

## Launch-readiness coverage

| Release area | B05 coverage | Out of scope / external gate |
|---|---|---|
| Onboarding and first use | B05-04/08 module empty states, resumable explicit onboarding, profile/routine handoff | Product research or copy localization beyond bundled B05 content. |
| Error, retry and offline | B05-04/06/07 scoped production states; B05-09 strict-offline proof | New online service or availability guarantee. |
| Permissions and privacy | Existing health/notification/photo/telemetry boundaries exercised with truthful copy; B05-09 checks manifests/configuration | Legal certification, consent service, secret provisioning. |
| Accessibility and compact layouts | Shared token components plus scoped widget/semantics matrix | A physical-device observation is evidence when available, not fabricated acceptance. |
| Migration and data portability | v19/v10, old backup compatibility, rollback and idempotency | Downgrade support for an older app binary that cannot understand v19/v10. |
| Native builds | Android release and iOS no-code-sign build attempt, current config review | Android signing key and release API key must be provided externally. |
| Media | Offline text/checklist fallback and verified-manifest seam | Licensing, artwork/media procurement, download pricing and playlist-provider decision. |

## Lightweight task ledger

Update only when implementation/merge information exists. This is a rollback
aid, not a compliance register.

| Task | Implementation commit | Final verdict | Merge commit | Known follow-ups |
|---|---|---|---|---|
| B05-01 | — | Planned | — | — |
| B05-02 | — | Planned | — | — |
| B05-03 | — | Planned | — | — |
| B05-04 | — | Planned | — | — |
| B05-05 | — | Planned | — | — |
| B05-06 | — | Planned | — | — |
| B05-07 | — | Planned | — | Conditional media/diagram asset authority remains external. |
| B05-08 | — | Planned | — | — |
| B05-09 | — | Planned | — | Build credentials/device availability recorded honestly. |
| B05-10 | — | Planned | — | — |

## Final review checklist

- [ ] Clean integration `HEAD`; all B05 task merges have a valid fresh verdict.
- [ ] No B01–B04 authority has been replaced, re-derived or silently mutated.
- [ ] v19 migration and Backup v10 direct/chained/rollback/idempotency tests pass.
- [ ] Older backup imports produce safe empty B05 state; v10 has no media
  binary/path/prompt/raw provider payload.
- [ ] Semantic scan and visual/widget tests cover light/dark, compact, large
  text, focus and semantics across B05-owned journeys.
- [ ] Today consumes B03/B04 output rather than independently calculating
  nutrition or recommendations.
- [ ] Content, checklist and onboarding flows work offline and do not infer
  health/dietary/medical/coaching conditions.
- [ ] Strict offline, permission denied, network failure and unavailable media
  have honest, recoverable UI.
- [ ] Full format, analysis, test, Android build and iOS no-code-sign build are
  recorded with limitations; no secrets are in the diff.
- [ ] Fresh Sol final review returns `Approved`, `Approved with non-blocking
  follow-up`, or an evidence-backed `Blocked` verdict.
