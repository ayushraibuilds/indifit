// N14-02 / N14-04: the privacy policy and store listing must describe the
// backup behaviour the native code actually has. If one side changes, this
// fails until the other is updated.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/features/settings/widgets/your_data_card.dart';

const _domains = [
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
  'device_root',
  'device_file',
  'device_database',
  'device_sharedpref',
];

const _exclusionSentence =
    'Your logs, history, measurements and recovery copies are excluded from '
    'iCloud and Google backups and from phone-to-phone transfer.';

String _read(String path) => File(path).readAsStringSync();

void _expectExcludesEverything(String xml, String section) {
  final match = RegExp(
    '<$section>(.*?)</$section>',
    dotAll: true,
  ).firstMatch(xml);
  expect(match, isNotNull, reason: '<$section> is missing');
  for (final domain in _domains) {
    expect(
      match!.group(1),
      contains('<exclude domain="$domain" path="." />'),
      reason: '<$section> must exclude $domain',
    );
  }
}

void main() {
  final policy = _read('doc/privacy_policy.md');

  group('iOS', () {
    test('protected paths are excluded from backup', () {
      expect(
        _read('ios/Runner/AppDelegate.swift'),
        contains('values.isExcludedFromBackup = true'),
      );
      // The database and the recovery copies both go through that channel.
      expect(
        _read('lib/data/database/connection/database_connection.dart'),
        contains('PlatformStorageProtection.protectSensitivePath'),
      );
      expect(
        _read('lib/core/services/auto_backup_service.dart'),
        contains('PlatformStorageProtection.protectSensitivePath'),
      );
    });
  });

  group('Android', () {
    test('backup is off and every domain is excluded', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );

      final rules = _read(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      );
      _expectExcludesEverything(rules, 'cloud-backup');
      // Decision N14-02 (v1): device-to-device transfer stays off too.
      _expectExcludesEverything(rules, 'device-transfer');
      _expectExcludesEverything(
        _read('android/app/src/main/res/xml/backup_rules.xml'),
        'full-backup-content',
      );
    });
  });

  group('privacy policy', () {
    test('states the exclusion and the new-phone consequence', () {
      expect(policy, contains(_exclusionSentence));
      expect(policy, contains(kNewPhoneStartsEmpty));
    });

    test('describes recovery copies as encrypted with an on-phone key', () {
      expect(policy, contains('encrypted with a key kept on the phone'));
    });

    test('no longer carries the two wrong claims', () {
      expect(policy, isNot(contains('may be included in a device backup')));
      expect(policy, isNot(contains('not password-protected')));
    });
  });

  test('store listing repeats the new-phone sentence', () {
    expect(_read('doc/store_listing_copy.md'), contains(kNewPhoneStartsEmpty));
  });
}
