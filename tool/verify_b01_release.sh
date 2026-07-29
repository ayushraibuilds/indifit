#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

run_release_builds=false
if [[ "${1:-}" == "--release-builds" ]]; then
  run_release_builds=true
elif [[ -n "${1:-}" ]]; then
  echo "Usage: tool/verify_b01_release.sh [--release-builds]" >&2
  exit 64
fi

echo "B01 gate: formatting"
dart format --output=none --set-exit-if-changed lib test

echo "B01 gate: static analysis"
flutter analyze

echo "B01 gate: generated database sources"
generated_before="$(
  shasum -a 256 lib/data/database/app_database.g.dart | awk '{print $1}'
)"
dart run build_runner build --delete-conflicting-outputs
dart format lib/data/database/app_database.g.dart
generated_after="$(
  shasum -a 256 lib/data/database/app_database.g.dart | awk '{print $1}'
)"
if [[ "$generated_before" != "$generated_after" ]]; then
  echo "Generated database sources were stale. Commit the regenerated file and rerun." >&2
  exit 1
fi

echo "B01 gate: high-risk cross-domain tests"
flutter test \
  test/exercise_identity_fixture_test.dart \
  test/equipment_fixture_test.dart \
  test/db_migration_test.dart \
  test/b01_schema_v15_migration_test.dart \
  test/program_repository_test.dart \
  test/occurrence_state_machine_test.dart \
  test/local_schedule_date_service_test.dart \
  test/calendar_controller_test.dart \
  test/travel_coordination_test.dart \
  test/equipment_preference_repository_test.dart \
  test/exercise_reminder_passive_cues_test.dart \
  test/workout_draft_codec_test.dart \
  test/workout_summary_lifecycle_test.dart \
  test/execution_bridge_test.dart \
  test/legacy_compatibility_adapter_test.dart \
  test/backup_restore_transaction_test.dart \
  test/b01_backup_v6_test.dart

echo "B01 gate: complete Flutter suite"
flutter test

if [[ "$run_release_builds" == true ]]; then
  echo "B01 gate: Android release build"
  flutter build apk \
    --release \
    --dart-define=INDIFIT_API_KEY=b01_release_gate_test_key

  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "The iOS release gate requires macOS." >&2
    exit 1
  fi

  echo "B01 gate: iOS release build (unsigned)"
  flutter build ios \
    --release \
    --no-codesign \
    --dart-define=INDIFIT_API_KEY=b01_release_gate_test_key
fi

echo "B01 automated release gates passed."
