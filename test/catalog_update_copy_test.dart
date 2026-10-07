import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Food database updates are disclosed where people read about the network
/// (packs plan § 7, CAT-7).
void main() {
  test('the privacy policy discloses food database updates', () {
    final policy = File('doc/privacy_policy.md').readAsStringSync();
    final section2 = policy.substring(
      policy.indexOf('## 2. Optional network features'),
      policy.indexOf('## 3.'),
    );
    expect(section2, contains('**Food database updates:**'));
    expect(
      section2,
      contains('These downloads send no information about you or your meals.'),
    );
    expect(
      section2,
      contains(
        'Turning on Offline Mode blocks app-initiated online food lookups, '
        'food database updates,',
      ),
    );
  });

  test('the store listing names food database updates', () {
    final listing = File('doc/store_listing_copy.md').readAsStringSync();
    final internet = listing
        .split('\n')
        .singleWhere((line) => line.startsWith('| **Internet** |'));
    expect(internet, contains('food database updates'));
    expect(
      listing,
      contains(
        'Offline Mode blocks app-initiated online food lookup, food database '
        'updates,',
      ),
    );
  });
}
