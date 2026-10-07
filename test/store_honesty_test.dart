// PR-B (store honesty): what the app and its iOS config claim must be true.
// Audit findings S-02, S-04, SC-05, SC-08 and the CAT-10 attributions.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_links.dart';
import 'package:indifit/core/privacy/dpdp_consent_dialog.dart';
import 'package:indifit/features/nutrition_ai/photo_meal_screen.dart';
import 'package:indifit/features/settings/about_credits_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Meal photo screen (SC-05)', () {
    testWidgets('is labelled Beta and makes no accuracy claim', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PhotoMealScreen())),
      );
      await tester.pump();

      expect(find.text('Meal photo (Beta)'), findsOneWidget);
      expect(find.textContaining('±30'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('Photo Meal Estimator'), findsNothing);
      expect(find.textContaining('contract'), findsNothing);
      expect(
        find.textContaining('Nothing is added to your diary until you check'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AI consent sheet (S-04)', () {
    testWidgets('links to the privacy policy', (tester) async {
      final opened = <Uri>[];
      final previousLauncher = AppLinks.launcher;
      AppLinks.launcher = (uri) async {
        opened.add(uri);
        return true;
      };
      addTearDown(() => AppLinks.launcher = previousLauncher);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DpdpConsentDialog())),
      );
      final link = find.byKey(const Key('dpdp_consent_privacy_policy_link'));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pump();

      expect(opened, [Uri.parse('https://indifit.app/privacy')]);
      expect(
        find.textContaining('Settings → Manage your data → AI meal assistance'),
        findsOneWidget,
      );
    });

    test(
      'a launcher that throws reports failure instead of crashing',
      () async {
        final previousLauncher = AppLinks.launcher;
        AppLinks.launcher = (uri) async => throw StateError('no browser');
        addTearDown(() => AppLinks.launcher = previousLauncher);

        expect(await AppLinks.open(AppLinks.privacyPolicy), isFalse);
      },
    );

    test('support email carries the app version, spaces not as +', () {
      final uri = AppLinks.supportEmailUri(appVersion: '1.0.0 (7)');

      expect(uri.toString(), startsWith('mailto:support@indifit.app?'));
      expect(uri.toString(), isNot(contains('+')));
      expect(
        Uri.decodeComponent(uri.query),
        contains('App version: 1.0.0 (7)'),
      );
      expect(
        Uri.decodeComponent(AppLinks.supportEmailUri().query),
        contains('App version: unknown'),
      );
    });
  });

  group('iOS privacy manifest (S-02)', () {
    final manifest = File(
      'ios/Runner/PrivacyInfo.xcprivacy',
    ).readAsStringSync();
    final collected = _collectedDataTypes(manifest);

    test('declares what Firebase App Check, Remote Config and Installations '
        'collect, alongside the existing types', () {
      expect(
        collected.keys,
        containsAll(<String>[
          'NSPrivacyCollectedDataTypeCrashData',
          'NSPrivacyCollectedDataTypeOtherUserContent',
          'NSPrivacyCollectedDataTypePhotosorVideos',
          'NSPrivacyCollectedDataTypeDeviceID',
          'NSPrivacyCollectedDataTypeProductInteraction',
          'NSPrivacyCollectedDataTypeOtherDiagnosticData',
        ]),
      );
    });

    test('nothing is linked to identity, used for tracking, or used beyond '
        'app functionality', () {
      expect(manifest, contains('<key>NSPrivacyTracking</key><false/>'));
      for (final entry in collected.entries) {
        final body = entry.value;
        expect(
          body,
          contains('<key>NSPrivacyCollectedDataTypeLinked</key><false/>'),
          reason: entry.key,
        );
        expect(
          body,
          contains('<key>NSPrivacyCollectedDataTypeTracking</key><false/>'),
          reason: entry.key,
        );
        final purposes = RegExp(
          r'<string>(NSPrivacyCollectedDataTypePurpose\w+)</string>',
        ).allMatches(body).map((m) => m.group(1)).toSet();
        expect(purposes, {
          'NSPrivacyCollectedDataTypePurposeAppFunctionality',
        }, reason: entry.key);
      }
    });
  });

  group('Live Activity (SC-08)', () {
    test('v1 does not declare Live Activities: no widget extension ships', () {
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(infoPlist, isNot(contains('NSSupportsLiveActivities')));
    });
  });

  group('Data sources (CAT-10)', () {
    testWidgets('credits name the Open Food Facts licence and say the '
        'catalogue values are IndiFit estimates', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: AboutCreditsScreen()));

      expect(find.textContaining('Open Database License (ODbL)'), findsOne);
      expect(find.textContaining('are IndiFit estimates'), findsOneWidget);
    });
  });
}

/// Maps each `NSPrivacyCollectedDataType` to its `<dict>` body.
Map<String, String> _collectedDataTypes(String manifest) {
  final section = RegExp(
    r'<key>NSPrivacyCollectedDataTypes</key>\s*<array>(.*)</array>',
    dotAll: true,
  ).firstMatch(manifest)!.group(1)!;
  final result = <String, String>{};
  for (final dict in RegExp(
    r'<dict>(.*?)</dict>',
    dotAll: true,
  ).allMatches(section)) {
    final body = dict.group(1)!;
    final type = RegExp(
      r'<key>NSPrivacyCollectedDataType</key><string>(\w+)</string>',
    ).firstMatch(body)!.group(1)!;
    result[type] = body;
  }
  return result;
}
