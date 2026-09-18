import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestProfileNotifier extends UserProfileNotifier {
  _TestProfileNotifier() : super();

  @override
  Future<void> loadProfile() async {}
}

class _TestWorkoutRepository extends WorkoutRepository {
  _TestWorkoutRepository(super.database);

  @override
  Future<int> logBodyMeasurement({
    double? weight,
    double? waist,
    double? chest,
    double? arms,
  }) async => 1;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'E2E Onboarding flow: user completes multi-step profile and transitions to home',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final database = AppDatabase.memory();

      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Dashboard Root'))),
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
          userProfileProvider.overrideWith((ref) => _TestProfileNotifier()),
          workoutRepositoryProvider.overrideWithValue(
            _TestWorkoutRepository(database),
          ),
          onboardingCompletedProvider.overrideWith((ref) => false),
        ],
      );

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
        await database.close();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);

      // Step 1: Basics (Sex, Name, Age, Height, Weight)
      final maleButton = find.text('Male');
      await tester.ensureVisible(maleButton);
      await tester.tap(maleButton);
      await tester.pumpAndSettle();

      final nameField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Name (optional)',
      );
      await tester.ensureVisible(nameField);
      await tester.tap(nameField);
      await tester.enterText(nameField, 'Aarav');
      await tester.pumpAndSettle();

      final ageField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Age',
      );
      await tester.ensureVisible(ageField);
      await tester.tap(ageField);
      await tester.enterText(ageField, '28');
      await tester.pumpAndSettle();

      final heightField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Height',
      );
      await tester.ensureVisible(heightField);
      await tester.tap(heightField);
      await tester.enterText(heightField, '175');
      await tester.pumpAndSettle();

      final weightField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Current weight',
      );
      await tester.ensureVisible(weightField);
      await tester.tap(weightField);
      await tester.enterText(weightField, '70');
      await tester.pumpAndSettle();

      final next1 = find.text('Next Step');
      await tester.ensureVisible(next1);
      await tester.tap(next1);
      await tester.pumpAndSettle();

      // Step 3: Fitness goal
      final maintainButton = find.text('Maintain');
      await tester.ensureVisible(maintainButton);
      await tester.tap(maintainButton);
      await tester.pumpAndSettle();

      final next2 = find.text('Next Step');
      await tester.ensureVisible(next2);
      await tester.tap(next2);
      await tester.pumpAndSettle();

      // Step 4: Activity level
      final moderateButton = find.text('Moderately Active');
      await tester.ensureVisible(moderateButton);
      await tester.tap(moderateButton);
      await tester.pumpAndSettle();

      final next3 = find.text('Next Step');
      await tester.ensureVisible(next3);
      await tester.tap(next3);
      await tester.pumpAndSettle();

      // Step 5: Dietary preference & Review
      final vegButton = find.text('Vegetarian');
      await tester.ensureVisible(vegButton);
      await tester.tap(vegButton);
      await tester.pumpAndSettle();

      final reviewButton = find.text('Review setup');
      await tester.ensureVisible(reviewButton);
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      // Verify Review screen
      expect(find.text('Finish setup'), findsOneWidget);

      // Finish setup
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      // Should transition to root
      expect(find.text('Dashboard Root'), findsOneWidget);

      final finalPrefs = await SharedPreferences.getInstance();
      expect(finalPrefs.getBool('onboarding_completed'), isTrue);
      expect(finalPrefs.getString('user_name'), 'Aarav');
      expect(finalPrefs.getInt('user_age'), 28);
    },
  );
}
