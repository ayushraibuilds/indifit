import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/coaching/b04_production_surface_controller.dart';
import 'package:indifit/features/dashboard/widgets/today_header_widgets.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:indifit/features/profile/profile_screen.dart';
import 'package:indifit/features/settings/nutrition_targets_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// What a user sees after "Skip for now" (12 Oct skip review).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppPreferenceKeys.onboardingCompleted: true,
      AppPreferenceKeys.onboardingSkipped: true,
    });
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget app(Widget home, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), ...overrides],
        child: MaterialApp(theme: AppTheme.darkTheme, home: home),
      );

  group('setup reopened from the app', () {
    testWidgets('closes instead of skipping and drops the welcome line', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OnboardingScreen(openedFromApp: true),
                  ),
                ),
                child: const Text('Open setup'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open setup'));
      await settle(tester);

      expect(find.text('1 of 5'), findsOneWidget);
      expect(find.text('Skip for now'), findsNothing);
      expect(find.textContaining('Welcome to IndiFit'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('onboarding_close')));
      await settle(tester);
      expect(find.text('Open setup'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('first launch keeps Skip and the welcome line', (tester) async {
      await tester.pumpWidget(app(const OnboardingScreen()));
      await settle(tester);

      expect(find.text('Skip for now'), findsOneWidget);
      expect(find.textContaining('Welcome to IndiFit'), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding_close')), findsNothing);
    });

    testWidgets('resumes at the step the user skipped from', (tester) async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.onboardingCompleted: true,
        AppPreferenceKeys.onboardingSkipped: true,
        'onboarding_draft_flow_version': 3,
        'onboarding_draft_page': 2,
        'onboarding_draft_goal': 'lose',
        'onboarding_draft_sex': 'female',
      });
      await tester.pumpWidget(app(const OnboardingScreen(openedFromApp: true)));
      await settle(tester);

      expect(find.text('3 of 5'), findsOneWidget);
      expect(find.text('How do you move most days?'), findsOneWidget);
    });
  });

  testWidgets('finishing setup opened over Today closes it and lands on '
      'Today', (tester) async {
    SharedPreferences.setMockInitialValues({
      AppPreferenceKeys.onboardingCompleted: true,
      AppPreferenceKeys.onboardingSkipped: true,
      'onboarding_draft_flow_version': 3,
      'onboarding_draft_page': 3,
      'onboarding_draft_sex': 'female',
    });
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OnboardingScreen(openedFromApp: true),
                  ),
                ),
                child: const Text('Today shell'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          workoutRepositoryProvider.overrideWithValue(
            _NoMeasurementWorkoutRepository(db),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Today shell'));
    await settle(tester);
    await tester.tap(find.text('Review setup'));
    await settle(tester);

    await tester.tap(find.text('Finish setup'));
    await tester.pump();
    for (var attempt = 0; attempt < 80; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(OnboardingScreen).evaluate().isEmpty) break;
    }
    await settle(tester);

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Today shell'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppPreferenceKeys.onboardingSkipped), isNull);
  });

  group('Goal & targets without a profile', () {
    testWidgets('offers setup instead of an error', (tester) async {
      await tester.pumpWidget(
        app(
          const NutritionTargetsHubScreen(),
          overrides: [
            b04ProductionUserContextProvider.overrideWith(
              (ref) async => throw const B04ProductionSurfaceError(
                'profile_unavailable',
                'Your profile is not ready yet.',
              ),
            ),
          ],
        ),
      );
      await settle(tester);

      expect(find.text('Set up your targets'), findsOneWidget);
      expect(find.text('Nutrition targets unavailable'), findsNothing);

      await tester.tap(find.text('Start setup'));
      await settle(tester);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Skip for now'), findsNothing);
    });

    testWidgets('other failures still read as unavailable', (tester) async {
      await tester.pumpWidget(
        app(
          const NutritionTargetsHubScreen(),
          overrides: [
            b04ProductionUserContextProvider.overrideWith(
              (ref) async => throw StateError('database closed'),
            ),
          ],
        ),
      );
      await settle(tester);

      expect(find.text('Nutrition targets unavailable'), findsOneWidget);
      expect(find.text('Set up your targets'), findsNothing);
    });
  });

  group('Today finish-setup card', () {
    Widget card() => app(
      Scaffold(
        body: Builder(
          builder: (context) => TodayFinishSetupBanner(
            onFinishSetup: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('opened'))),
          ),
        ),
      ),
    );

    testWidgets('shows after a skip and opens setup', (tester) async {
      await tester.pumpWidget(card());
      await settle(tester);

      expect(find.text('Finish setup for daily targets'), findsOneWidget);
      await tester.tap(find.text('Finish'));
      await settle(tester);
      expect(find.text('opened'), findsOneWidget);
    });

    testWidgets('"Not now" hides it and remembers', (tester) async {
      await tester.pumpWidget(card());
      await settle(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester);
      expect(find.text('Finish setup for daily targets'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppPreferenceKeys.todayFinishSetupDismissed), true);
    });

    testWidgets('stays hidden for a user who finished setup', (tester) async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.onboardingCompleted: true,
      });
      await tester.pumpWidget(card());
      await settle(tester);
      expect(find.text('Finish setup for daily targets'), findsNothing);
    });
  });

  testWidgets('Profile prompt keeps the 16 pt side margin', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        const ProfileScreen(),
        overrides: [
          userProfileProvider.overrideWith((ref) => UserProfileNotifier()),
        ],
      ),
    );
    await settle(tester);

    final title = find.text('Complete your profile when you’re ready');
    expect(title, findsOneWidget);
    final surface = tester.getRect(
      find.ancestor(of: title, matching: find.byType(GestureDetector)).first,
    );
    expect(surface.left, 16);
    expect(surface.right, 402 - 16);
  });
}

class _NoMeasurementWorkoutRepository extends WorkoutRepository {
  _NoMeasurementWorkoutRepository(super.database);

  @override
  Future<int> logBodyMeasurement({
    double? weight,
    double? waist,
    double? chest,
    double? arms,
  }) async => 1;
}
