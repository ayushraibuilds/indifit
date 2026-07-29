# B01 Final Cross-Domain Verification

Baseline: integration commit `baff96e`

Verification date: 2026-07-30

Scope: B01-14 final architecture, data-integrity, portability, automated
regression, and release-build gates.

## Gate verdict

**Verified — Batch B01 is ready for pull request.**

No product-owner decision remains open. B01-PD01, B01-PD02, and B01-PD03 are
recorded as accepted in `DECISIONS.md` and are covered by domain and widget
tests.

All final Sol verification, approved platform checks, automated checks, and
release-build gates have passed. Remote CI and pull-request review remain the
only required checks before merging the integration branch.

## Final verification disposition

| ID | Disposition | Release effect |
|---|---|---|
| B01-14-F01 | Final Sol verification accepted the completed automated, migration, backup, offline, platform, accessibility, draft-recovery, and release-build evidence. | No unresolved B01 release blocker remains. |

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
| Civil dates survive DST and stored IANA zones; device-zone behavior is correct. | Passed — SOL gate | `local_schedule_date_service_test.dart`, `phase6_failure_retry_test.dart`, accepted platform verification |
| Reschedule records history without ordinal mutation and rejects invalid transitions. | Passed — SOL gate | `occurrence_state_machine_test.dart`, `calendar_controller_test.dart` |
| Skip is explicit; hold/advance and repeat follow accepted progression semantics. | Passed | `occurrence_state_machine_test.dart`, `calendar_controller_test.dart`, `b01_program_calendar_widget_test.dart` |
| Full/partial scheduled execution freezes ancestry; manual sessions remain nullable; same-day ordering is deterministic. | Passed — SOL gate | `execution_bridge_test.dart`, `calendar_controller_test.dart` |
| Travel overrides equipment without mutating date/order/deload and survives durable reload. | Passed | `travel_coordination_test.dart`, `b01_travel_widget_test.dart`, `execution_bridge_test.dart` |
| Equipment migration and compatibility preserve known, unknown, and unresolved values. | Passed — SOL gate | `equipment_fixture_test.dart`, `b01_schema_v15_migration_test.dart`, `equipment_preference_repository_test.dart` |
| Personal notes/setup/cues persist and freeze into execution context. | Passed | `equipment_preference_repository_test.dart`, `exercise_reminder_passive_cues_test.dart`, `b01_equipment_preferences_widget_test.dart`, `execution_bridge_test.dart` |
| Legacy draft arrays decode; new envelopes preserve all fields and lifecycle failure remains recoverable. | Passed — SOL gate | `workout_draft_codec_test.dart`, `workout_summary_lifecycle_test.dart`, `execution_bridge_test.dart` |
| Backup v5 imports into inactive compatibility data; v6 round-trips the graph and rejects invalid relationships before mutation. | Passed — SOL gate | `backup_restore_transaction_test.dart`, `b01_backup_v6_test.dart`, `backup_schema_test.dart` |
| B01 flows remain offline and require no AI/API. | Passed — SOL gate | `privacy_policy_enforcement_test.dart`, `travel_coordination_test.dart`, `exercise_reminder_passive_cues_test.dart`, accepted platform verification |

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
| Final manual Android/iOS verification | Passed |

## Product-owner decisions

| Decision | Status | Evidence |
|---|---|---|
| B01-PD01 — explicit skip choice with no default | Accepted and implemented | Occurrence state-machine and calendar widget tests |
| B01-PD02 — travel preserves program structure and applies previewed equipment override | Accepted and implemented | Travel repository/controller/widget tests |
| B01-PD03 — passive exercise-context cues; no per-exercise notifications | Accepted and implemented | Preference, passive-cue, player, and backup tests |

No product-owner decision blocks B01.

## Android/iOS platform matrix

The final Sol verification accepted the completed Android and iOS evidence for
each row. The matrix is retained as release traceability.

| ID | Journey | Android | iOS | Required evidence |
|---|---|---|---|---|
| B01-M01 | Create, review, activate, edit-by-copy, and reopen a multi-block program with a deload week. | Verified | Verified | Active and historical versions remain distinct after relaunch. |
| B01-M02 | Activate in `Asia/Kolkata`, switch device timezone across a date boundary and DST zone, reschedule while travelling, then return home. | Verified | Verified | Original civil date/zone and ordinals remain stable; only explicit reschedule changes effective date/zone. |
| B01-M03 | Enable strict offline mode, relaunch, use calendar/skip/repeat/travel/equipment/preferences, and confirm no API dependency. | Verified | Verified | Network-disabled journey completes; durable state survives relaunch. |
| B01-M04 | Start a scheduled workout, record all supported set fields, kill the app before summary and during summary, relaunch, retry, and complete once. | Verified | Verified | Draft survives; one session and one completion result; no field loss or duplicate completion. |
| B01-M05 | Export v6 encrypted backup, import it after local mutations, then import representative raw and encrypted v5 files. | Verified | Verified | Preview succeeds, invalid password mutates nothing, v6 graph restores, v5 routines remain inactive and recoverable. |
| B01-M06 | Exercise calendar, action sheets, travel preview, equipment/profile editors, and player cue panel with screen reader and 200% text. | Verified | Verified | Controls have usable labels/order; no clipped critical action or inaccessible dialog. |
| B01-M07 | Cancel/close skip, reschedule, travel, deletion, and backup dialogs at every stage. | Verified | Verified | Closing causes no mutation; retry remains available after failure paths. |

## Final sign-off rule

B01-14 is verified. Batch B01 is ready for the pull-request review and remote
CI stage. Any future regression reopens the owning B01 task and blocks release.
