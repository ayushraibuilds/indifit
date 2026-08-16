import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/settings/widgets/privacy_disclosure_card.dart';
import 'package:indifit/features/workout_player/workout_summary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// R07F-0 — Trust, terminology, offline typography, startup, and router-gate
/// regression coverage for the release-cleanup wave.
void main() {
  group('Workout metric truthfulness', () {
    testWidgets('summary shows volume and duration but no calorie estimate', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSummaryScreen(
            routineName: 'Push A',
            elapsedSeconds: 1800,
            loggedSets: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total volume'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Active burn'), findsNothing);
      expect(find.textContaining('kcal'), findsNothing);
      expect(find.textContaining('Burned'), findsNothing);
    });
  });

  group('Photo-AI disclosure truthfulness', () {
    testWidgets('privacy card states photos are sent, not processed locally', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PrivacyDisclosureCard())),
      );
      expect(find.textContaining('send text or photo queries'), findsOneWidget);
      expect(
        find.textContaining('processed only on this device'),
        findsNothing,
      );
    });
  });

  group('Consumer terminology residue', () {
    // Strings that must never render in consumer UI again. Scanned against
    // production sources; internal identifiers (keys, cache namespaces) are
    // excluded by matching the exact consumer phrasing.
    final forbidden = <String>[
      'Canonical workout',
      'Occurrence cancelled',
      'Occurrence history',
      'The online food provider is unavailable',
      'could not reach the provider',
      'paste a legacy JSON backup',
      'Pasting a legacy backup',
      'imported provider',
      'legacy record',
      'provider secrets',
      'B02 strength draft is unavailable',
      'No B02 strength draft is loaded',
      'The typed activity draft is unavailable or legacy-shaped',
      'The current group is missing from the frozen draft',
      'Active burn',
      'approx 6.5 kcal',
    ];

    test('no forbidden consumer strings remain in production sources', () {
      final offenders = <String>[];
      for (final entry in Directory('lib').listSync(recursive: true)) {
        if (entry is! File || !entry.path.endsWith('.dart')) continue;
        // Scan string literals only: strip comments so internal code
        // documentation never trips the consumer-copy check.
        final source = entry
            .readAsStringSync()
            .replaceAll(RegExp(r'///[^\n]*'), '')
            .replaceAll(RegExp(r'//[^\n]*'), '')
            .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
        for (final term in forbidden) {
          if (source.contains(term)) {
            offenders.add('${entry.path}: "$term"');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('Offline typography', () {
    test('Outfit font asset is bundled and declared', () {
      final fontFile = File('assets/fonts/Outfit-Variable.ttf');
      expect(
        fontFile.existsSync(),
        isTrue,
        reason: 'Bundled Outfit variable font is missing.',
      );

      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('assets/fonts/Outfit-Variable.ttf'), isTrue);
      // The runtime-fetching package must not be a dependency anymore.
      expect(pubspec.contains('google_fonts:'), isFalse);
    });

    test('theme resolves text without any network font package', () {
      final source = File('lib/core/theme/app_theme.dart').readAsStringSync();
      expect(source.contains('GoogleFonts'), isFalse);
      expect(source.contains("fontFamily: 'Outfit'"), isTrue);
    });
  });

  group('Startup first-frame classification', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    test('reminder scheduling and auto-backup do not block runApp', () {
      // They must be invoked from the post-frame bootstrap, not awaited in
      // main() before runApp.
      expect(
        mainSource.contains('await NotificationService.scheduleAllReminders'),
        isFalse,
      );
      expect(
        mainSource.contains('AutoBackupService.performBackup'),
        isTrue,
        reason: 'post-frame bootstrap should run the auto-backup check',
      );
      expect(
        mainSource.contains('addPostFrameCallback'),
        isTrue,
        reason: 'a post-frame bootstrap must exist',
      );
    });

    test('Sentry keeps wrapping runApp (documented correct integration)', () {
      final runAppIndex = mainSource.indexOf('runApp(');
      final sentryIndex = mainSource.indexOf(
        'CrashReportingService.initialize',
      );
      expect(sentryIndex, greaterThanOrEqualTo(0));
      expect(runAppIndex, greaterThan(sentryIndex));
    });
  });

  group('Router onboarding gate', () {
    test('first launch: any app location redirects to onboarding', () {
      expect(
        onboardingGateRedirect(onboardingCompleted: false, location: '/'),
        '/onboarding',
      );
      expect(
        onboardingGateRedirect(onboardingCompleted: false, location: '/food'),
        '/onboarding',
      );
      expect(
        onboardingGateRedirect(
          onboardingCompleted: false,
          location: '/training',
        ),
        '/onboarding',
      );
    });

    test('incomplete onboarding: onboarding and wizard stay reachable', () {
      expect(
        onboardingGateRedirect(
          onboardingCompleted: false,
          location: '/onboarding',
        ),
        isNull,
      );
      expect(
        onboardingGateRedirect(
          onboardingCompleted: false,
          location: '/routine-wizard',
        ),
        isNull,
      );
    });

    test('completed onboarding: onboarding route bounces to root', () {
      expect(
        onboardingGateRedirect(onboardingCompleted: true, location: '/'),
        isNull,
      );
      expect(
        onboardingGateRedirect(
          onboardingCompleted: true,
          location: '/onboarding',
        ),
        '/',
      );
    });

    test(
      'runtime gate flip mirrors completion without preference re-reads',
      () {
        // Before completion: gated. After the in-memory flip (what
        // onboarding_screen.dart performs alongside the persisted write), the
        // identical navigation passes with no SharedPreferences I/O.
        var completed = false;
        expect(
          onboardingGateRedirect(
            onboardingCompleted: completed,
            location: '/food',
          ),
          '/onboarding',
        );
        completed = true;
        expect(
          onboardingGateRedirect(
            onboardingCompleted: completed,
            location: '/food',
          ),
          isNull,
        );
      },
    );

    testWidgets('integration: first launch lands the router on onboarding', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': false});
      final prefs = await SharedPreferences.getInstance();
      final database = AppDatabase.memory();

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          privacyPolicyProvider.overrideWith(
            (ref) => PrivacyPolicyNotifier(prefs),
          ),
          onboardingCompletedProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/onboarding',
      );
    });
  });
}
