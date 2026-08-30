#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

build_artifacts=false
signed_ios=false
run_analysis=true
run_full_suite=false

usage() {
  cat <<'EOF'
Usage: tool/verify_r09_release.sh [options]

  --tests-only       Run the default critical-journey gate (default behavior).
  --artifacts        Also build and inspect release artifacts.
  --signed-ios       With --artifacts, require a signed iOS archive/IPA build.
  --skip-analysis    Skip flutter analyze when it already ran in the same CI job.
  --full-suite       Also run the complete Flutter test suite serially.
EOF
}

while (($# > 0)); do
  case "$1" in
    --tests-only)
      shift
      ;;
    --artifacts)
      build_artifacts=true
      shift
      ;;
    --signed-ios)
      build_artifacts=true
      signed_ios=true
      shift
      ;;
    --skip-analysis)
      run_analysis=false
      shift
      ;;
    --full-suite)
      run_full_suite=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

critical_journey_tests=(
  test/r07f_release_cleanup_test.dart
  test/r08e1_personalized_onboarding_test.dart
  test/r08d2_food_search_fast_logging_test.dart
  test/r08d4_direct_food_edit_test.dart
  test/ux_r07d_food_diary_logging_test.dart
  test/b02_workout_preparation_integration_test.dart
  test/r08b6_rest_wakelock_test.dart
  test/r08b8_workout_review_completion_test.dart
  test/ux_r07e_progress_insights_test.dart
  test/b05_backup_v10_test.dart
  test/backup_restore_transaction_test.dart
  test/phase5_notifications_test.dart
  test/r08g5_notifications_quiet_hours_test.dart
  test/r08g4_health_integration_test.dart
  test/r09a_product_truth_test.dart
  test/r09_platform_safety_test.dart
  test/r09_release_identity_test.dart
  test/r09_minimum_verification_test.dart
)

if [[ "$run_analysis" == true ]]; then
  echo "R09-D gate: static analysis"
  flutter analyze
fi

echo "R09-D gate: seven critical launch journeys"
flutter test -j 1 --reporter compact "${critical_journey_tests[@]}"

if [[ "$run_full_suite" == true ]]; then
  echo "R09-D gate: complete Flutter suite"
  flutter test -j 1 --reporter compact
fi

if [[ "$build_artifacts" != true ]]; then
  echo "R09-D minimum credible automated gate passed."
  exit 0
fi

if [[ ! -f android/key.properties ]]; then
  echo "android/key.properties is required for a signed release artifact." >&2
  exit 1
fi

echo "R09-D gate: signed Android release APK and App Bundle"
flutter build apk --release
flutter build appbundle --release
bash tool/verify_r09_artifacts.sh \
  --android-apk build/app/outputs/flutter-apk/app-release.apk \
  --android-aab build/app/outputs/bundle/release/app-release.aab \
  --evidence build/release-evidence/android-production.txt

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Android production artifact gate passed. iOS artifact verification requires macOS."
  exit 0
fi

if [[ "$signed_ios" == true ]]; then
  echo "R09-D gate: signed iOS archive and IPA"
  flutter build ipa --release
  ios_app_path="build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"
  bash tool/verify_r09_artifacts.sh \
    --ios-app "$ios_app_path" \
    --evidence build/release-evidence/ios-production.txt
else
  echo "R09-D gate: unsigned iOS release compiler proof"
  flutter build ios --release --no-codesign
  bash tool/verify_r09_artifacts.sh \
    --ios-app build/ios/iphoneos/Runner.app \
    --allow-unsigned-ios \
    --evidence build/release-evidence/ios-unsigned.txt
fi

echo "R09-D artifact gate passed. Physical-device acceptance remains a human gate."
