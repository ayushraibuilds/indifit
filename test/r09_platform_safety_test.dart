import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R09-B platform safety contract', () {
    test(
      'Android requests SCHEDULE_EXACT_ALARM without prohibited USE_EXACT_ALARM and disables app backup',
      () {
        final manifest = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();

        expect(manifest, contains('SCHEDULE_EXACT_ALARM'));
        expect(manifest, isNot(contains('USE_EXACT_ALARM')));
        expect(manifest, contains('android:allowBackup="false"'));
        expect(manifest, contains('@xml/backup_rules'));
        expect(manifest, contains('@xml/data_extraction_rules'));
      },
    );

    test('Android extraction rules exclude every app-owned data domain', () {
      final legacyRules = File(
        'android/app/src/main/res/xml/backup_rules.xml',
      ).readAsStringSync();
      final modernRules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();

      for (final domain in const ['file', 'database', 'sharedpref', 'root']) {
        expect(legacyRules, contains('domain="$domain" path="."'));
        expect(modernRules, contains('domain="$domain" path="."'));
      }
      expect(modernRules, contains('<cloud-backup>'));
      expect(modernRules, contains('<device-transfer>'));
    });

    test(
      'iOS uses protected files, backup exclusion, and device-only Keychain',
      () {
        final entitlements = File(
          'ios/Runner/Runner.entitlements',
        ).readAsStringSync();
        final appDelegate = File(
          'ios/Runner/AppDelegate.swift',
        ).readAsStringSync();
        final secretStore = File(
          'lib/core/services/auto_backup_secret_store.dart',
        ).readAsStringSync();

        expect(
          entitlements,
          contains('NSFileProtectionCompleteUntilFirstUserAuthentication'),
        );
        expect(entitlements, contains('keychain-access-groups'));
        expect(appDelegate, contains('isExcludedFromBackup = true'));
        expect(appDelegate, contains('completeUntilFirstUserAuthentication'));
        expect(secretStore, contains('first_unlock_this_device'));
        expect(secretStore, contains('synchronizable: false'));
      },
    );
  });
}
