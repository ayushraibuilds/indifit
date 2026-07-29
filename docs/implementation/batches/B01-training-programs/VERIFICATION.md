# B01 Final Cross-Domain Verification

Baseline: commit `87a5294`

Verification date: 2026-07-29

Scope: B01-14 final architecture, data-integrity, portability, automated
regression, and release-build gates.

## Gate verdict

**Automated and release-build gates passed. Final B01 release sign-off is
blocked on the required Android and iOS manual interaction matrix.**

No product-owner decision remains open. B01-PD01, B01-PD02, and B01-PD03 are
recorded as accepted in `DECISIONS.md` and are covered by domain and widget
tests.

The repository is safe to continue through manual release validation. It must
not be marked fully released until the device checks in this document pass on
both Android and iOS.

## Blocking findings

| ID | Finding | Release effect | Required closure |
|---|---|---|---|
| B01-14-G01 | The required manual timezone, offline, accessibility, draft kill/relaunch, and backup-import journeys have not been executed on Android and iOS. | Blocks final B01 sign-off; does not block merging the verification implementation. | Execute and record every row in the manual platform matrix on both platforms. |
| B01-14-G02 | This verification host has no connected Android device or configured Android emulator. An iOS simulator and a wireless user-owned iPhone are visible, but no deployment to the user device was authorized. | Prevents completing G01 in this task. | Provide an Android device/emulator and run the checklist; use an iOS simulator or explicitly authorized test device for the iOS rows. |

## Release blockers found and resolved

| Finding | Resolution | Evidence |
|---|---|---|
| Repository-wide format gate failed under pinned Flutter 3.41.4. | Applied the pinned Dart formatter mechanically to `lib/` and `test/`; no behavior was changed. | `dart format --output=none --set-exit-if-changed lib test` passes with 195 files and zero changes. |
| Committed Drift generated output was stale under the pinned toolchain. | Regenerated and formatted `app_database.g.dart`; the B01 gate now verifies before/after content identity. | `dart run build_runner build --delete-conflicting-outputs` succeeds and a second gate run produces identical generated content. |
| `flutter_timezone` 1.0.8 used Flutter's removed Android `Registrar` API and blocked release compilation. | Updated to maintained `flutter_timezone` 5.1.0 and adapted the returned `TimezoneInfo.identifier`. | Android release APK and unsigned iOS release app both build; timezone regression tests and analysis pass. |
| Backup v5 file evidence covered object restore but not both raw and encrypted file envelopes. | Added a release regression that inspects and transactionally restores both forms. | `backup_restore_transaction_test.dart` passes and proves inactive legacy import semantics for both paths. |
| CI built Android release only. | Added an unsigned iOS release-build job on `macos-15` with the pinned Flutter version. | `.github/workflows/ci.yml` now gates both Android and iOS release compilation. |

## Automated validation evidence

| Gate | Result | Evidence |
|---|---|---|
| Formatting | Passed | 195 files checked; zero changes required after correction. |
| Static analysis | Passed | `flutter analyze`: no issues found. |
| Generated Drift output | Passed | Build runner succeeded; regenerated output is idempotent. |
| High-risk B01 suite | Passed | 113 tests covering identity, equipment, v14→v15, versioning, occurrences, travel, preferences, drafts, execution, legacy compatibility, v5, and v6. |
| Complete Flutter suite | Passed | 286 tests passed. |
| Android release build | Passed | `build/app/outputs/flutter-apk/app-release.apk`, 93.0 MB. |
| iOS release build | Passed | `build/ios/iphoneos/Runner.app`, 53.5 MB, release mode without code signing. |
| Whitespace errors | Passed | `git diff --check`. |

The reusable automated command is:

```bash
tool/verify_b01_release.sh
```

On macOS with production-equivalent signing configuration available, include
both platform builds with:

```bash
tool/verify_b01_release.sh --release-builds
```

## PLAN acceptance-criteria traceability

| PLAN criterion | Status | Passing evidence |
|---|---|---|
| Fresh v15 database creates the required graph and indexes. | Passed | `b01_schema_v15_migration_test.dart`, `data_quality_gaps_test.dart` |
| Real v14 upgrade preserves legacy rows, creates deterministic inactive imports, leaves historical ancestry nullable, and rolls back failure. | Passed — SOL gate | `db_migration_test.dart`, `b01_schema_v15_migration_test.dart` |
| Legacy routines and selection remain compatible until explicit B01 activation. | Passed — SOL gate | `legacy_compatibility_adapter_test.dart`, `wave3_features_test.dart` |
| Draft versions are editable; published graphs are immutable; copies are source-linked. | Passed — SOL gate | `program_repository_test.dart` |
| Activation validates and atomically creates civil-date, zone-labelled occurrences with one active authority. | Passed — SOL gate | `occurrence_state_machine_test.dart` |
| Civil dates survive DST and stored IANA zones; device-zone behavior is correct. | Automated portion passed; manual pending | `local_schedule_date_service_test.dart`, `phase6_failure_retry_test.dart`; manual Android/iOS row B01-M02 remains open. |
| Reschedule records history without ordinal mutation and rejects invalid transitions. | Passed — SOL gate | `occurrence_state_machine_test.dart`, `calendar_controller_test.dart` |
| Skip is explicit; hold/advance and repeat follow accepted progression semantics. | Passed | `occurrence_state_machine_test.dart`, `calendar_controller_test.dart`, `b01_program_calendar_widget_test.dart` |
| Full/partial scheduled execution freezes ancestry; manual sessions remain nullable; same-day ordering is deterministic. | Passed — SOL gate | `execution_bridge_test.dart`, `calendar_controller_test.dart` |
| Travel overrides equipment without mutating date/order/deload and survives durable reload. | Passed | `travel_coordination_test.dart`, `b01_travel_widget_test.dart`, `execution_bridge_test.dart` |
| Equipment migration and compatibility preserve known, unknown, and unresolved values. | Passed — SOL gate | `equipment_fixture_test.dart`, `b01_schema_v15_migration_test.dart`, `equipment_preference_repository_test.dart` |
| Personal notes/setup/cues persist and freeze into execution context. | Passed | `equipment_preference_repository_test.dart`, `exercise_reminder_passive_cues_test.dart`, `b01_equipment_preferences_widget_test.dart`, `execution_bridge_test.dart` |
| Legacy draft arrays decode; new envelopes preserve all fields and lifecycle failure remains recoverable. | Passed — SOL gate | `workout_draft_codec_test.dart`, `workout_summary_lifecycle_test.dart`, `execution_bridge_test.dart` |
| Backup v5 imports into inactive compatibility data; v6 round-trips the graph and rejects invalid relationships before mutation. | Passed — SOL gate | `backup_restore_transaction_test.dart`, `b01_backup_v6_test.dart`, `backup_schema_test.dart` |
| B01 flows remain offline and require no AI/API. | Automated portion passed; manual pending | `privacy_policy_enforcement_test.dart`, `travel_coordination_test.dart`, `exercise_reminder_passive_cues_test.dart`; manual rows B01-M03 and B01-M05 remain open. |

## SOL-gate disposition

| Gate | Disposition |
|---|---|
| Stable exercise identity and equipment mappings | Passed |
| Transactional v14→v15 migration and representative fixtures | Passed |
| Program lifecycle and activation authority | Passed |
| Occurrence transition, progression, and idempotency rules | Passed |
| Execution ancestry, frozen snapshot, and finalization transaction | Passed |
| Backup v5/v6 compatibility and prevalidation | Passed |
| Final automated cross-domain verification | Passed |
| Final manual Android/iOS verification | Blocked pending B01-14-G01/G02 |

## Product-owner decisions

| Decision | Status | Evidence |
|---|---|---|
| B01-PD01 — explicit skip choice with no default | Accepted and implemented | Occurrence state-machine and calendar widget tests |
| B01-PD02 — travel preserves program structure and applies previewed equipment override | Accepted and implemented | Travel repository/controller/widget tests |
| B01-PD03 — passive exercise-context cues; no per-exercise notifications | Accepted and implemented | Preference, passive-cue, player, and backup tests |

No product-owner decision blocks B01.

## Manual Android/iOS platform matrix

Every row must pass independently on Android and iOS. Record device/OS, build
identifier, result, tester, and date. A release build passing compilation does
not satisfy these interaction checks.

| ID | Journey | Android | iOS | Required evidence |
|---|---|---|---|---|
| B01-M01 | Create, review, activate, edit-by-copy, and reopen a multi-block program with a deload week. | Pending | Pending | Screen recording or timestamped checklist; active version and old version remain distinct after relaunch. |
| B01-M02 | Activate in `Asia/Kolkata`, switch device timezone across a date boundary and DST zone, reschedule while travelling, then return home. | Pending | Pending | Original civil date/zone and ordinals remain stable; only explicit reschedule changes effective date/zone. |
| B01-M03 | Enable strict offline mode, relaunch, use calendar/skip/repeat/travel/equipment/preferences, and confirm no API dependency. | Pending | Pending | Network-disabled journey completes; durable state survives relaunch. |
| B01-M04 | Start a scheduled workout, record all supported set fields, kill the app before summary and during summary, relaunch, retry, and complete once. | Pending | Pending | Draft survives; one session and one completion result; no field loss or duplicate completion. |
| B01-M05 | Export v6 encrypted backup, import it after local mutations, then import representative raw and encrypted v5 files. | Pending | Pending | Preview succeeds, invalid password mutates nothing, v6 graph restores, v5 routines remain inactive and recoverable. |
| B01-M06 | Exercise calendar, action sheets, travel preview, equipment/profile editors, and player cue panel with screen reader and 200% text. | Pending | Pending | Controls have usable labels/order; no clipped critical action or inaccessible dialog. |
| B01-M07 | Cancel/close skip, reschedule, travel, deletion, and backup dialogs at every stage. | Pending | Pending | Closing causes no mutation; retry remains available after injected/user-visible failure paths. |

## Final sign-off rule

B01-14 is technically implemented and all automated/release-build gates pass.
The B01 batch remains in **Verifying** status until B01-M01 through B01-M07 are
recorded as passing on both Android and iOS. Any failure reopens the owning B01
task and blocks release; it must not be waived in this document.
