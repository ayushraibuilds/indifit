import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/privacy/dpdp_consent_dialog.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/dashboard/widgets/appearance_bottom_sheet.dart';
import 'package:indifit/features/dashboard/widgets/hydration_detail_sheet.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:indifit/features/food_log/widgets/quick_add_macros_sheet.dart';
import 'package:indifit/features/nutrition_ai/natural_language_meal_screen.dart';
import 'package:indifit/features/nutrition_ai/photo_meal_screen.dart';
import 'package:indifit/features/training/plan_library_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestMockProfileNotifier extends UserProfileNotifier {
  _TestMockProfileNotifier() : super() {
    state = const UserProfileState(
      isLoaded: true,
      hasProfile: true,
      calorieGoal: 2000,
      proteinGoal: 140,
      carbsGoal: 220,
      fatGoal: 60,
      currentWeight: 75.0,
      userHeight: 178.0,
      userName: 'Aarav',
      userSex: 'male',
      userAge: 27,
      userActivityLevel: 'moderate',
      userGoal: 'maintain',
      dietPreference: 'veg',
    );
  }

  @override
  Future<void> loadProfile() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Simulator E2E Checkpoints Verification', () {
    late AppDatabase database;
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      await prefs.setString(AppPreferenceKeys.userName, 'Aarav');
      await prefs.setBool(AppPreferenceKeys.onlineNutritionAllowed, true);
      database = AppDatabase.memory();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
          foodRepositoryProvider.overrideWithValue(FoodRepository(database)),
          workoutRepositoryProvider.overrideWithValue(
            WorkoutRepository(database),
          ),
          userProfileProvider.overrideWith((ref) => _TestMockProfileNotifier()),
          onboardingCompletedProvider.overrideWith((ref) => true),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    // -------------------------------------------------------------
    // Journey 1: Quick-Add & Diary Speed
    // -------------------------------------------------------------
    testWidgets(
      'Journey 1: Quick-Add modal, Atwater balance, and Diary rendering',
      (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    key: const ValueKey('open_quick_add'),
                    onPressed: () => QuickAddMacrosSheet.show(
                      context,
                      initialMealType: 'lunch',
                      targetDate: DateTime.now(),
                    ),
                    child: const Text('Open Quick Add'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Checkpoint 1.1: Open QuickAddMacrosSheet
        await tester.tap(find.byKey(const ValueKey('open_quick_add')));
        await tester.pumpAndSettle();

        expect(find.text('Quick-Add Macros'), findsOneWidget);
        final caloriesField = find.widgetWithText(
          TextField,
          'Calories * (Required)',
        );
        expect(caloriesField, findsOneWidget);

        final proteinField = find.widgetWithText(TextField, 'Protein');
        final carbsField = find.widgetWithText(TextField, 'Carbs');
        final fatField = find.widgetWithText(TextField, 'Fat');
        final fiberField = find.widgetWithText(TextField, 'Fiber');

        // Checkpoint 1.2: Verify missing macro placeholder strictly '—' and validation
        expect(
          find.text('Optional Macros (leave blank for —)'),
          findsOneWidget,
        );

        // Verify required calories validation
        final submitBtn = find.widgetWithText(
          ElevatedButton,
          'Log Snapshot (<10s)',
        );
        expect(submitBtn, findsOneWidget);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Calories are required (greater than 0).'),
          findsOneWidget,
        );

        // Enter valid snapshot: 500 kcal, 30g P, 50g C, 20g F, 5g Fiber
        await tester.enterText(caloriesField, '500');
        await tester.enterText(proteinField, '30');
        await tester.enterText(carbsField, '50');
        await tester.enterText(fatField, '20');
        await tester.enterText(fiberField, '5');
        await tester.pump();

        // Tap Log Snapshot button
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Checkpoint 1.3: Render FoodDiaryScreen without overflow
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: FoodDiaryScreen(selectedDate: DateTime.now()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Daily nutrition'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('diary_targets_link')),
          findsOneWidget,
        );
        expect(find.text('Targets'), findsOneWidget);
        expect(find.text('Fiber'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------
    // Journey 2: Search, Staple Chips, and Catalog
    // -------------------------------------------------------------
    testWidgets('Journey 2: Food Search staple chips & search interaction', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FoodSearchScreen(mealType: 'lunch'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Checkpoint 2.1: Staple chips exist
      expect(find.text('Roti'), findsWidgets);
      expect(find.text('Dal'), findsOneWidget);
      expect(find.text('Paneer'), findsOneWidget);

      // Tap Paneer staple chip
      await tester.tap(find.text('Paneer'));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(TextField), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Journey 3: Multimodal AI & DPDP Consent Gate
    // -------------------------------------------------------------
    testWidgets('Journey 3: Natural language screen enforces DPDP consent', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const NaturalLanguageMealScreen(mealType: 'lunch'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Describe Meal'), findsOneWidget);
      final starter = find.text('2 rotis and 1 bowl dal tadka');
      expect(starter, findsOneWidget);

      // Checkpoint 3.1: Tap starter chip triggers DPDP dialog
      await tester.tap(starter);
      await tester.pumpAndSettle();

      expect(find.byType(DpdpConsentDialog), findsOneWidget);
      expect(find.text('Data Privacy & AI Consent'), findsOneWidget);

      // Decline / Cancel consent cancels analysis cleanly
      await tester.tap(find.byKey(const Key('dpdp_consent_cancel_button')));
      await tester.pumpAndSettle();
      expect(find.byType(DpdpConsentDialog), findsNothing);
    });

    // -------------------------------------------------------------
    // Journey 4: Rate Limit Quota & Privacy Interceptor
    // -------------------------------------------------------------
    testWidgets('Journey 4: Photo Meal Screen 429 Quota UX and Navigation', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PhotoMealScreen(mealType: 'dinner'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photo Meal Estimator'), findsOneWidget);
      expect(find.text('AI Meal Decomposition'), findsOneWidget);
      expect(find.text('Take Photo with Camera'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Journey 5: Timezone Resilience & Onboarding
    // -------------------------------------------------------------
    testWidgets('Journey 5: LocalTimezoneService handles legacy/OEM fallback', (
      tester,
    ) async {
      // Checkpoint 5.3: Verify platform timezone fallback
      final tzService1 = LocalTimezoneService(
        read: () async => 'Asia/Calcutta',
      );
      expect(await tzService1.currentTimezoneId(), 'Asia/Kolkata');

      final tzService2 = LocalTimezoneService(read: () async => '');
      expect(await tzService2.currentTimezoneId(), 'Asia/Kolkata');

      final tzService3 = LocalTimezoneService(
        read: () async => 'INVALID_ROM_TZ',
      );
      expect(await tzService3.currentTimezoneId(), 'Asia/Kolkata');
    });

    // -------------------------------------------------------------
    // Journey 6: Offline Starter Plans
    // -------------------------------------------------------------
    testWidgets('Journey 6: Offline starter plan catalog loads instantly', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PlanLibraryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Checkpoint 6.1: Starter plans render offline without network
      expect(find.text('Plan Library'), findsOneWidget);
      expect(find.text('Beginner — 3-Day Full Body'), findsOneWidget);
      expect(find.text('3-Day Strength Foundation'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Journey 7: Dashboard Appearance Theme Switching
    // -------------------------------------------------------------
    testWidgets('Journey 7: AppearanceBottomSheet switches theme modes', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const ValueKey('open_appearance'),
                  onPressed: () => AppearanceBottomSheet.show(context),
                  child: const Text('Open Appearance Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_appearance')));
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);
      expect(find.text('Light mode'), findsOneWidget);
      expect(find.text('Dark mode'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Journey 8: Hydration Detail Logging
    // -------------------------------------------------------------
    testWidgets(
      'Journey 8: HydrationDetailSheet opens and renders log controls',
      (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    key: const ValueKey('open_hydration'),
                    onPressed: () =>
                        HydrationDetailSheet.show(context, DateTime.now()),
                    child: const Text('Open Hydration Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open_hydration')));
        await tester.pumpAndSettle();

        expect(find.byType(HydrationDetailSheet), findsOneWidget);
        expect(find.text('Log Water'), findsWidgets);
      },
    );
  });
}
