import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R09-D minimum credible verification contract', () {
    final runner = File('tool/verify_r09_release.sh').readAsStringSync();
    final inspector = File('tool/verify_r09_artifacts.sh').readAsStringSync();
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();
    final verification = File(
      'docs/release/R09-D_MINIMUM_CREDIBLE_VERIFICATION.md',
    ).readAsStringSync();

    test('critical lane covers seven named journeys with real test files', () {
      const journeyEvidence = <String, List<String>>{
        'onboarding': [
          'test/r07f_release_cleanup_test.dart',
          'test/r08e1_personalized_onboarding_test.dart',
        ],
        'food': [
          'test/r08d2_food_search_fast_logging_test.dart',
          'test/r08d4_direct_food_edit_test.dart',
          'test/ux_r07d_food_diary_logging_test.dart',
        ],
        'workout': [
          'test/b02_workout_preparation_integration_test.dart',
          'test/r08b6_rest_wakelock_test.dart',
          'test/r08b8_workout_review_completion_test.dart',
        ],
        'backup': [
          'test/b05_backup_v10_test.dart',
          'test/backup_restore_transaction_test.dart',
        ],
        'notification': [
          'test/phase5_notifications_test.dart',
          'test/r08g5_notifications_quiet_hours_test.dart',
        ],
        'health': ['test/r08g4_health_integration_test.dart'],
        'release': [
          'test/r09a_product_truth_test.dart',
          'test/r09_platform_safety_test.dart',
          'test/r09_release_identity_test.dart',
        ],
      };

      expect(journeyEvidence, hasLength(7));
      for (final entry in journeyEvidence.entries) {
        for (final path in entry.value) {
          expect(File(path).existsSync(), isTrue, reason: '$path is missing');
          expect(
            runner,
            contains(path),
            reason: '${entry.key} evidence is absent from the R09-D runner',
          );
        }
      }
    });

    test('production artifact runner builds the store artifact types', () {
      expect(runner, contains('flutter build appbundle --release'));
      expect(runner, contains('flutter build ipa --release'));
      expect(runner, contains('flutter build ios --release --no-codesign'));
      expect(runner, isNot(contains('INDIFIT_API_KEY')));
      expect(runner, contains('--android-aab'));
      expect(runner, contains('--ios-app'));
    });

    test('artifact inspector fails closed on identity and signing', () {
      expect(inspector, contains('com.indifit.indifit'));
      expect(inspector, contains('expected_version="1.0.0"'));
      expect(inspector, contains('expected_build="1"'));
      expect(inspector, contains('apksigner'));
      expect(inspector, contains('jarsigner -verify'));
      expect(inspector, contains('AAB is not signed'));
      expect(inspector, contains('APK and AAB use different signing certificates'));
      expect(inspector, contains('CN=Android Debug'));
      expect(inspector, contains('throwaway CI certificate'));
      expect(inspector, contains('codesign --verify --deep --strict'));
      expect(
        inspector,
        contains('com.apple.developer.default-data-protection'),
      );
      expect(inspector, contains('com.apple.developer.healthkit'));
      expect(inspector, contains('result=PASS'));
    });

    test('CI retains inspected Android and iOS compiler evidence', () {
      expect(workflow, contains('Build Release App Bundle'));
      expect(workflow, contains('Verify Android Release Artifacts'));
      expect(workflow, contains('Verify iOS Release Artifact'));
      expect(workflow, contains('actions/upload-artifact@v4'));
      expect(workflow, contains('app-release.aab'));
      expect(workflow, contains('android-ci.txt'));
      expect(workflow, contains('ios-unsigned.txt'));
      expect(workflow, contains('--allow-ci-signing'));
      expect(workflow, contains('--allow-unsigned-ios'));
    });

    test('manual matrix stays explicitly pending until human execution', () {
      for (var index = 1; index <= 9; index++) {
        final id = 'D${index.toString().padLeft(2, '0')}';
        expect(verification, contains('| $id |'));
      }
      expect(
        RegExp(
          r'\| D\d{2} \|.*\| Pending \| Pending \|',
        ).allMatches(verification),
        hasLength(9),
      );
      expect(verification, contains('automated tests do not change it'));
      expect(verification, contains('CI Android artifacts'));
      expect(verification, contains('unsigned CI iOS bundle'));
    });
  });
}
