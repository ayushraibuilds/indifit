import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/privacy/dpdp_consent_dialog.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/dashboard/widgets/hydration_detail_sheet.dart';
import 'package:indifit/features/dashboard/widgets/log_weight_bottom_sheet.dart';
import 'package:indifit/features/food_log/custom_food_editor_screen.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:indifit/features/workout_player/quick_workout_screen.dart';
import 'package:indifit/features/workout_player/widgets/rest_timer_bottom_sheet.dart';
import 'package:indifit/features/workout_player/workout_execution_route.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class _WalkthroughProfileNotifier extends UserProfileNotifier {
  _WalkthroughProfileNotifier() : super() {
    state = const UserProfileState(
      isLoaded: true,
      hasProfile: true,
      calorieGoal: 2200,
      proteinGoal: 130,
      carbsGoal: 250,
      fatGoal: 65,
      currentWeight: 72,
      userHeight: 175,
      userName: 'Aarav',
      userSex: 'male',
      userAge: 28,
      userActivityLevel: 'moderate',
      userGoal: 'maintain',
      dietPreference: 'veg',
    );
  }

  @override
  Future<void> loadProfile() async {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'E2E Visual Walkthrough across all 5 major surfaces with screenshots',
    (tester) async {
      // 1. SharedPreferences seeded state
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setBool('onboarding_completed', true);
      await prefs.setString('user_name', 'Aarav');
      await prefs.setInt('user_age', 28);
      await prefs.setDouble('user_height', 175.0);
      await prefs.setDouble('user_weight', 72.0);
      await prefs.setDouble('current_weight', 72.0);
      await prefs.setDouble('user_target_weight', 70.0);
      await prefs.setString('user_sex', 'male');
      await prefs.setString('user_activity_level', 'moderate');
      await prefs.setString('user_goal', 'maintain');
      await prefs.setString('user_diet_preference', 'veg');
      await prefs.setInt('calorie_goal', 2200);
      await prefs.setDouble('protein_goal', 130.0);
      await prefs.setDouble('carbs_goal', 250.0);
      await prefs.setDouble('fat_goal', 65.0);
      await prefs.setInt('user_streak_count', 5);
      await prefs.setInt('water_intake_today_ml', 1750);
      await prefs.setInt('water_goal_ml', 2500);

      // 2. Database setup & seeding
      final database = AppDatabase.memory();
      final foodRepo = FoodRepository(database);
      final workoutRepo = WorkoutRepository(database);

      final now = DateTime.now();
      await foodRepo.logFoodEntry(
        name: 'Dal Makhani & Roti',
        calories: 450,
        proteinG: 18.0,
        carbsG: 62.0,
        fatG: 12.0,
        servingLogged: 1.0,
        servingUnit: 'serving',
        mealType: 'lunch',
        loggedAt: now,
      );
      await foodRepo.logFoodEntry(
        name: 'Paneer Bhurji',
        calories: 320,
        proteinG: 22.0,
        carbsG: 8.0,
        fatG: 20.0,
        servingLogged: 1.0,
        servingUnit: 'bowl',
        mealType: 'breakfast',
        loggedAt: now,
      );

      await workoutRepo.logSession(
        name: 'Push Hypertrophy',
        volume: 2400.0,
        durationSeconds: 2700,
        calories: 220,
        sets: [
          WorkoutSetsCompanion.insert(
            sessionId: 1,
            exerciseName: 'Flat Barbell Bench Press',
            setNumber: 1,
            weight: 60.0,
            reps: 10,
          ),
          WorkoutSetsCompanion.insert(
            sessionId: 1,
            exerciseName: 'Overhead Shoulder Press',
            setNumber: 2,
            weight: 40.0,
            reps: 8,
          ),
        ],
        completedAt: now,
      );

      await workoutRepo.logBodyMeasurement(
        weight: 72.0,
        waist: 32.0,
        chest: 39.0,
        arms: 14.5,
      );

      // 3. Mount Application
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
          foodRepositoryProvider.overrideWithValue(foodRepo),
          workoutRepositoryProvider.overrideWithValue(workoutRepo),
          userProfileProvider.overrideWith((ref) => _WalkthroughProfileNotifier()),
          onboardingCompletedProvider.overrideWith((ref) => true),
        ],
      );

      final router = container.read(appRouterProvider);

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
        await database.close();
      });

      // ==========================================
      // SURFACE 0: Onboarding Step 1 (Horizontal Male/Female, full weight visibility)
      // ==========================================
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(database),
            workoutRepositoryProvider.overrideWithValue(workoutRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('02_onboarding_or_home');


      // ==========================================
      // Mount Main Application
      // ==========================================
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

      BuildContext currentContext() =>
          tester.element(find.byType(Scaffold).last);

      // Clear any transient achievement or status SnackBar so surface is completely clean
      ScaffoldMessenger.of(currentContext()).clearSnackBars();
      await tester.pumpAndSettle();

      // ==========================================
      // SURFACE 1: Tab 0 (Today / Dashboard)
      // ==========================================
      expect(find.byType(MaterialApp), findsOneWidget);
      await binding.takeScreenshot('03_tab0_dashboard');

      // Hydration Detail Sheet
      unawaited(HydrationDetailSheet.show(currentContext(), now));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('03b_hydration_detail_sheet');
      if (find.byType(HydrationDetailSheet).evaluate().isNotEmpty) {
        Navigator.of(
          tester.element(find.byType(HydrationDetailSheet)),
          rootNavigator: true,
        ).pop();
        await tester.pumpAndSettle();
      }

      // Log Weight Bottom Sheet
      unawaited(LogWeightBottomSheet.show(currentContext(), 72.0, (w) async {}));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('03c_log_weight_sheet');
      if (find.byType(LogWeightBottomSheet).evaluate().isNotEmpty) {
        Navigator.of(
          tester.element(find.byType(LogWeightBottomSheet)),
          rootNavigator: true,
        ).pop();
        await tester.pumpAndSettle();
      }

      // ==========================================
      // SURFACE 2: Tab 1 (Training)
      // ==========================================
      await tester.tap(find.text('Training').first);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_tab1_training');

      // Rest Timer Bottom Sheet
      unawaited(RestTimerBottomSheet.show(currentContext(), 90));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('05_training_rest_timer');

      // Deterministically dismiss rest timer
      if (find.byType(RestTimerBottomSheet).evaluate().isNotEmpty) {
        Navigator.of(
          tester.element(find.byType(RestTimerBottomSheet)),
          rootNavigator: true,
        ).pop();
        await tester.pumpAndSettle();
      }

      // B02 Strength Player surface
      final adapter = container.read(strengthExecutionCompatibilityAdapterProvider);
      final initialDraft = await adapter.startUnscheduledDraft(
        routineName: 'Chest & Triceps Hypertrophy',
        executionSnapshotJson: quickWorkoutSnapshotJson('Chest & Triceps Hypertrophy'),
        snapshotId: const Uuid().v4(),
      );
      final withBench = await adapter.addUnscheduledExercise(
        launch: initialDraft,
        exerciseId: 'ex_bench_press',
        exerciseName: 'Flat Barbell Bench Press',
        plannedSets: 3,
        repsRange: '8-12',
      );
      final preparedDraft = await adapter.prepareExecution(withBench);
      unawaited(GoRouter.of(currentContext()).push(
        '/b02-strength-player',
        extra: WorkoutExecutionRouteData.fromLaunch(
          withBench.copyWith(state: preparedDraft.state),
        ),
      ));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('05b_b02_strength_player');

      // Pop back from B02 player safely
      if (Navigator.of(tester.element(find.byType(Scaffold).last)).canPop()) {
        Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
        await tester.pumpAndSettle();
      }

      // ==========================================
      // SURFACE 3: Tab 2 (Food / Nutrition)
      // ==========================================
      await tester.tap(find.text('Food').first);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('06_tab2_food_diary');

      // Tap "Add food" to open Meal choice sheet
      final addFoodBtn = find.text('Add food');
      if (addFoodBtn.evaluate().isNotEmpty) {
        await tester.tap(addFoodBtn.first);
        await tester.pumpAndSettle();

          // Tap "Lunch" to open FoodSearchScreen (target the meal tile,
          // not the bare text, so the tap lands on a hittable widget)
          final lunchTiles = find.ancestor(
            of: find.text('Lunch'),
            matching: find.byType(ListTile),
          );
          final lunchOption = lunchTiles.evaluate().isNotEmpty
              ? lunchTiles
              : find.text('Lunch');
          if (lunchOption.evaluate().isNotEmpty) {
            await tester.tap(lunchOption.first, warnIfMissed: false);
            await tester.pumpAndSettle();
          await binding.takeScreenshot('06_tab2_food_search');

          // Search for Indian food item to show live results & portion sheet
          final searchField = find.descendant(
            of: find.byType(FoodSearchBar),
            matching: find.byType(TextField),
          );
          if (searchField.evaluate().isNotEmpty) {
            await tester.tap(searchField);
            await tester.enterText(searchField, 'Paneer');
            await tester.pump(const Duration(milliseconds: 600));
            await tester.pumpAndSettle();
            await binding.takeScreenshot('07_food_search_results');

            // Tap the first search result tile in the list (not the search bar) to trigger FoodPortionBottomSheet
            final searchResultsList = find.byType(ListView);
            final paneerTile = find.descendant(
              of: searchResultsList,
              matching: find.textContaining('Paneer'),
            );
            if (paneerTile.evaluate().isNotEmpty) {
              await tester.tap(paneerTile.first);
              // Wait for async coordinator queries and sheet presentation
              for (var i = 0; i < 25; i++) {
                await tester.pump(const Duration(milliseconds: 100));
                if (find.byType(FoodPortionBottomSheet).evaluate().isNotEmpty) {
                  break;
                }
              }
              await tester.pumpAndSettle();
              await binding.takeScreenshot('08_food_portion_sheet');

              // Deterministically dismiss portion sheet
              if (find.byType(FoodPortionBottomSheet).evaluate().isNotEmpty) {
                Navigator.of(
                  tester.element(find.byType(FoodPortionBottomSheet)),
                ).pop();
                await tester.pumpAndSettle();
              }
            }
          }

          // Pop pushed FoodSearchScreen route cleanly back to diary
          if (Navigator.of(tester.element(find.byType(Scaffold).last)).canPop()) {
            Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
            await tester.pumpAndSettle();
          }
        }
      }

      // Thali Builder Screen (Circular plate, dual staples, nutrition summary)
      unawaited(GoRouter.of(currentContext()).push('/food/thali?meal=lunch'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('08b_thali_builder_screen');
      if (Navigator.of(tester.element(find.byType(Scaffold).last)).canPop()) {
        Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
        await tester.pumpAndSettle();
      }

      // Custom Food Editor Screen with Barcode Chip
      unawaited(Navigator.of(currentContext()).push(
        MaterialPageRoute(
          builder: (_) => const CustomFoodEditorScreen(
            initialBarcode: '8901030927341',
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('08c_custom_food_editor');
      if (Navigator.of(tester.element(find.byType(Scaffold).last)).canPop()) {
        Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
        await tester.pumpAndSettle();
      }

      // DPDP Consent Dialog
      unawaited(DpdpConsentDialog.show(currentContext()));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('09_dpdp_consent_dialog');

      // Dismiss DPDP dialog
      if (find.text('Cancel').evaluate().isNotEmpty) {
        await tester.tap(find.text('Cancel').first);
        await tester.pumpAndSettle();
      } else if (Navigator.of(tester.element(find.byType(Scaffold).last)).canPop()) {
        Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
        await tester.pumpAndSettle();
      }

      // Ensure all modal barriers and routes are settled at MainNavigationScaffold
      while (Navigator.of(tester.element(find.byType(Scaffold).last)).canPop()) {
        Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
        await tester.pumpAndSettle();
      }

      // ==========================================
      // SURFACE 4: Tab 3 (Progress)
      // ==========================================
      await tester.tap(find.text('Progress').first);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('10_tab3_progress');

      // Achievements
      unawaited(GoRouter.of(currentContext()).push('/achievements'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('11_progress_achievements');

      // Pop achievements back
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();

      // ==========================================
      // SURFACE 5: Settings (/settings)
      // ==========================================
      unawaited(GoRouter.of(currentContext()).push('/settings'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('12_settings_screen');

      // Scroll settings down to reveal Data & Privacy -> Manage your data
      final settingsList = find.byType(ListView);
      if (settingsList.evaluate().isNotEmpty) {
        await tester.drag(settingsList.first, const Offset(0, -700));
        await tester.pumpAndSettle();
      }

      final manageDataRow = find.text('Manage your data');
      if (manageDataRow.evaluate().isNotEmpty) {
        await tester.ensureVisible(manageDataRow.first);
        await tester.pumpAndSettle();
        await tester.tap(manageDataRow.first);
        await tester.pumpAndSettle();

        // Scroll DataManagementSubScreen down to reveal Erase all data
        final eraseAllButton = find.text('Erase all data');
        if (eraseAllButton.evaluate().isNotEmpty) {
          await tester.ensureVisible(eraseAllButton.first);
          await tester.pumpAndSettle();
        } else {
          final subScroll = find.byType(SingleChildScrollView);
          if (subScroll.evaluate().isNotEmpty) {
            await tester.drag(subScroll.first, const Offset(0, -600));
            await tester.pumpAndSettle();
          }
        }
        await binding.takeScreenshot('13_settings_data_erasure');
      }

      // Pop all pushed screens (DataManagementSubScreen, SettingsScreen) safely
      // stopping when only the root MainNavigationScaffold remains.
      while (find.byType(Scaffold).evaluate().length > 1) {
        Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    },
  );
}
