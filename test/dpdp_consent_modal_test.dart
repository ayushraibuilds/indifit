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

    testWidgets(
      'First-time prompt renders DPDP consent modal with disclosures',
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
        expect(find.text('Use AI to read your meals?'), findsOneWidget);
        // Guideline 5.1.2(i): the third-party AI must be named.
        expect(find.textContaining('Google\'s Gemini AI'), findsOneWidget);
        expect(find.text('What is sent'), findsOneWidget);
        expect(find.text('What IndiFit keeps'), findsOneWidget);
        expect(find.text('You stay in control'), findsOneWidget);
        expect(
          find.byKey(const Key('dpdp_consent_cancel_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('dpdp_consent_agree_button')),
          findsOneWidget,
        );

        // Tap Cancel
        await tester.tap(find.byKey(const Key('dpdp_consent_cancel_button')));
        await tester.pumpAndSettle();

        expect(consentResult, isFalse);
        expect(DpdpConsentService.hasConsent(prefs), isFalse);
        expect(prefs.getBool(AppPreferenceKeys.dpdpAiConsentAccepted), isNull);
      },
    );

    testWidgets('Allowing AI persists acceptance of the current version', (
      tester,
    ) async {
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

      await tester.tap(find.byKey(const Key('dpdp_consent_agree_button')));
      await tester.pumpAndSettle();

      expect(consentResult, isTrue);
      expect(DpdpConsentService.hasConsent(prefs), isTrue);
      expect(prefs.getBool(AppPreferenceKeys.dpdpAiConsentAccepted), isTrue);
      expect(
        prefs.getInt(AppPreferenceKeys.dpdpAiConsentVersion),
        DpdpConsentService.currentVersion,
      );
      expect(
        prefs.getString(AppPreferenceKeys.dpdpAiConsentAcceptedAt),
        isNotNull,
      );

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
    test('consent to an older disclosure no longer counts', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.dpdpAiConsentAccepted: true,
        AppPreferenceKeys.dpdpAiConsentAcceptedAt: '2026-09-01T00:00:00Z',
      });
      final prefs = await SharedPreferences.getInstance();

      // v1 stored no version; it covered photos only and named no provider.
      expect(DpdpConsentService.hasConsent(prefs), isFalse);
    });

    test('withdrawing clears consent so the next AI use asks again', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.dpdpAiConsentAccepted: true,
        AppPreferenceKeys.dpdpAiConsentVersion:
            DpdpConsentService.currentVersion,
        AppPreferenceKeys.dpdpAiConsentAcceptedAt: '2026-10-01T00:00:00Z',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(DpdpConsentService.hasConsent(prefs), isTrue);

      await DpdpConsentService.withdraw(prefs);

      expect(DpdpConsentService.hasConsent(prefs), isFalse);
      expect(prefs.getBool(AppPreferenceKeys.dpdpAiConsentAccepted), isNull);
      expect(
        prefs.getString(AppPreferenceKeys.dpdpAiConsentAcceptedAt),
        isNull,
      );
    });
  });
}
