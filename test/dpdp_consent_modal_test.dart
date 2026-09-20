import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/privacy/dpdp_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DPDP Consent Service & Dialog Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('First-time prompt renders DPDP consent modal with disclosures',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      expect(DpdpConsentService.hasConsent(prefs), isFalse);

      bool? consentResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  consentResult = await DpdpConsentService.ensureConsent(
                    context: context,
                    prefs: prefs,
                  );
                },
                child: const Text('Trigger Consent'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Consent'));
      await tester.pumpAndSettle();

      // Verify modal elements
      expect(find.byKey(const Key('dpdp_consent_sheet')), findsOneWidget);
      expect(find.text('Data Privacy & AI Consent'), findsOneWidget);
      expect(find.text('Ephemeral Processing'), findsOneWidget);
      expect(find.text('No AI Training'), findsOneWidget);
      expect(find.text('Local Control'), findsOneWidget);
      expect(find.byKey(const Key('dpdp_consent_cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('dpdp_consent_agree_button')), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.byKey(const Key('dpdp_consent_cancel_button')));
      await tester.pumpAndSettle();

      expect(consentResult, isFalse);
      expect(DpdpConsentService.hasConsent(prefs), isFalse);
      expect(prefs.getBool(AppPreferenceKeys.dpdpAiConsentAccepted), isNull);
    });

    testWidgets('Tapping Agree & Continue persists acceptance to SharedPreferences',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();

      bool? consentResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  consentResult = await DpdpConsentService.ensureConsent(
                    context: context,
                    prefs: prefs,
                  );
                },
                child: const Text('Trigger Consent'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Consent'));
      await tester.pumpAndSettle();

      // Tap Agree & Continue
      await tester.tap(find.byKey(const Key('dpdp_consent_agree_button')));
      await tester.pumpAndSettle();

      expect(consentResult, isTrue);
      expect(DpdpConsentService.hasConsent(prefs), isTrue);
      expect(prefs.getBool(AppPreferenceKeys.dpdpAiConsentAccepted), isTrue);
      expect(prefs.getString(AppPreferenceKeys.dpdpAiConsentAcceptedAt), isNotNull);

      // Verify second invocation proceeds immediately without modal
      bool? secondResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  secondResult = await DpdpConsentService.ensureConsent(
                    context: context,
                    prefs: prefs,
                  );
                },
                child: const Text('Trigger Consent 2'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Consent 2'));
      await tester.pump();

      expect(secondResult, isTrue);
      expect(find.byKey(const Key('dpdp_consent_sheet')), findsNothing);
    });
  });
}
