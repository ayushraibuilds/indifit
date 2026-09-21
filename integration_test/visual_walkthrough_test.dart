// ignore_for_file: avoid_redundant_argument_values, avoid_print
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/catalog/food_catalog_models.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/privacy/dpdp_consent_dialog.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/services/achievement_service.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/indi_fit_bottom_sheet.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_goal_repository.dart';
import 'package:indifit/data/repositories/offline_starter_plan_catalog.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/calendar/occurrence_actions_sheet.dart';
import 'package:indifit/features/coaching/b04_production_surface_widgets.dart';
import 'package:indifit/features/dashboard/widgets/hydration_detail_sheet.dart';
import 'package:indifit/features/dashboard/widgets/log_weight_bottom_sheet.dart';
import 'package:indifit/features/exercise_library/exercise_details_sheet.dart';
import 'package:indifit/features/exercise_picker/exercise_picker.dart';
import 'package:indifit/features/food_log/custom_food_editor_screen.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:indifit/features/food_log/thali/thali_component_picker_sheet.dart';
import 'package:indifit/features/food_log/widgets/remote_food_review_sheet.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:indifit/features/progress/period_comparison/progress_period_comparison_controller.dart';
import 'package:indifit/features/progress/period_comparison/widgets/period_comparison_drilldown_sheet.dart';
import 'package:indifit/features/progress/widgets/achievement_detail_sheet.dart';
import 'package:indifit/features/settings/nutrition_targets_hub_screen.dart';
import 'package:indifit/features/training/plan_library_screen.dart';
import 'package:indifit/features/workout_player/quick_workout_screen.dart';
import 'package:indifit/features/workout_player/widgets/achievement_celebration_sheet.dart';
import 'package:indifit/features/workout_player/widgets/plate_calculator_sheet.dart';
import 'package:indifit/features/workout_player/widgets/rest_timer_bottom_sheet.dart';
import 'package:indifit/features/workout_player/workout_execution_route.dart';
import 'package:indifit/features/workout_player/workout_summary_screen.dart';
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

CalendarOccurrenceReadItem _buildMockOccurrence() {
  final createdAt = DateTime.utc(2026, 8, 1);
  const templateId = 'template-preview';
  const versionId = 'version-preview';
  const weekId = 'week-preview';
  const blockId = 'block-preview';
  return CalendarOccurrenceReadItem(
    occurrence: ScheduledSessionOccurrence(
      id: 'occ_test_1',
      programVersionId: versionId,
      sessionTemplateId: templateId,
      programBlockOrdinal: 0,
      programWeekOrdinal: 0,
      sessionOrdinal: 0,
      repeatOrdinal: 0,
      originalLocalDate: '2026-08-21',
      originalTimezoneId: 'UTC',
      effectiveLocalDate: '2026-08-21',
      effectiveTimezoneId: 'UTC',
      status: 'planned',
      progressionDisposition: 'pending',
      createdAtUtc: createdAt,
    ),
    template: const SessionTemplate(
      id: templateId,
      programWeekId: weekId,
      ordinal: 0,
      name: 'Full Body A',
      plannedWeekday: DateTime.friday,
      activityType: 'strength',
    ),
    week: const ProgramWeek(
      id: weekId,
      programVersionId: versionId,
      programBlockId: blockId,
      ordinalInBlock: 0,
      programWeekOrdinal: 0,
      isDeload: false,
    ),
    block: const ProgramBlock(
      id: blockId,
      programVersionId: versionId,
      ordinal: 0,
      name: 'Base block',
    ),
    version: ProgramVersion(
      id: versionId,
      programId: 'program-preview',
      versionNumber: 1,
      status: 'published',
      origin: 'authoring',
      createdAtUtc: createdAt,
    ),
    program: Program(
      id: 'program-preview',
      name: 'Full Body Foundation',
      createdAtUtc: createdAt,
    ),
    prescriptions: const [],
    isOverdue: false,
    isDeload: false,
    isNextRequired: true,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Comprehensive App Coverage Pass across all surfaces, sheets, and dialogs',
    (tester) async {
      // -------------------------------------------------------------
      // SECTION 1: Onboarding 5 Steps
      // -------------------------------------------------------------
      final onbPrefs = await SharedPreferences.getInstance();
      await onbPrefs.clear();
      final onbDb = AppDatabase.memory();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(onbPrefs),
            databaseProvider.overrideWithValue(onbDb),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('01_onboarding_01_demographics');

      // Step 1 -> Step 2
      final malePill = find.text('Male');
      if (malePill.evaluate().isNotEmpty) {
        await tester.tap(malePill.first);
        await tester.pumpAndSettle();
      }
      var nextBtn = find.text('Next Step');
      if (nextBtn.evaluate().isNotEmpty) {
        await tester.tap(nextBtn.first);
        await tester.pumpAndSettle();
        await binding.takeScreenshot('01_onboarding_02_goal');

        // Step 2 -> Step 3
        nextBtn = find.text('Next Step');
        if (nextBtn.evaluate().isNotEmpty) {
          await tester.tap(nextBtn.first);
          await tester.pumpAndSettle();
          await binding.takeScreenshot('01_onboarding_03_activity');

          // Step 3 -> Step 4
          nextBtn = find.text('Next Step');
          if (nextBtn.evaluate().isNotEmpty) {
            await tester.tap(nextBtn.first);
            await tester.pumpAndSettle();
            await binding.takeScreenshot('01_onboarding_04_diet');

            // Step 4 -> Step 5 Payoff
            final reviewBtn = find.text('Review setup');
            if (reviewBtn.evaluate().isNotEmpty) {
              await tester.tap(reviewBtn.first);
              await tester.pumpAndSettle();
              await binding.takeScreenshot('01_onboarding_05_payoff');
            }
          }
        }
      }

      await onbDb.close();

      // -------------------------------------------------------------
      // SECTION 2: Production Seeding & Main App Mount
      // -------------------------------------------------------------
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

      final database = AppDatabase.memory();
      await database.into(database.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: const Value(1),
          name: const Value('Aarav'),
          age: const Value(28),
          height: const Value(175.0),
          weight: const Value(72.0),
          sex: const Value('male'),
          activityLevel: const Value('moderate'),
          goal: const Value('maintain'),
          dietPreference: const Value('veg'),
          calorieGoal: const Value(2200),
          proteinGoal: const Value(130.0),
          carbsGoal: const Value(250.0),
          fatGoal: const Value(65.0),
          equipmentAccess: const Value('full_gym'),
          injuriesLimitations: const Value(''),
        ),
      );

      final datesService = LocalScheduleDateService();
      final timezoneService = LocalTimezoneService();
      final timezoneId = await timezoneService.currentTimezoneId();
      final todayDate = datesService.todayIn(timezoneId);
      final goalRepo = NutritionGoalRepository(
        database: database,
        dates: datesService,
      );
      await goalRepo.ensureCompatibilityImport(
        userId: '1',
        legacyProfile: NutritionGoalCommand(
          userId: '1',
          goalType: NutritionGoalType.maintenance,
          calorieTargetKcal: 2200,
          proteinTargetG: 130.0,
          carbsTargetG: 250.0,
          fatTargetG: 65.0,
          effectiveFromLocalDate: todayDate,
          timezoneId: timezoneId,
        ),
      );

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

      await database.into(database.foodItems).insert(
        FoodItemsCompanion.insert(
          name: 'Paneer (Raw)',
          calories: 265,
          proteinG: 18.0,
          carbsG: 3.5,
          fatG: 20.0,
          servingSize: 100.0,
          servingUnit: 'g',
          category: 'dairy',
        ),
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

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
          foodRepositoryProvider.overrideWithValue(foodRepo),
          workoutRepositoryProvider.overrideWithValue(workoutRepo),
          userProfileProvider.overrideWith(
            (ref) => _WalkthroughProfileNotifier(),
          ),
          onboardingCompletedProvider.overrideWith((ref) => true),
        ],
      );

      await container.read(b05ExerciseVisualRegistryProvider.future);

      final router = container.read(appRouterProvider);

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

      BuildContext currentContext() => find.byType(Scaffold).evaluate().last;
      BuildContext rootScaffoldContext() =>
          tester.element(find.byType(Scaffold).first);

      Future<void> popTop({bool rootNavigator = false}) async {
        final scaffolds = find.byType(Scaffold).evaluate();
        if (scaffolds.isNotEmpty) {
          final nav =
              Navigator.of(scaffolds.last, rootNavigator: rootNavigator);
          if (nav.canPop()) {
            nav.pop();
            await tester.pumpAndSettle();
            return;
          }
        }
        final allRoots = find.byType(Navigator).evaluate();
        for (final r in allRoots.toList().reversed) {
          final nav = Navigator.of(r);
          if (nav.canPop()) {
            nav.pop();
            await tester.pumpAndSettle();
            return;
          }
        }
      }

      ScaffoldMessenger.of(currentContext()).clearSnackBars();
      await tester.pumpAndSettle();

      // -------------------------------------------------------------
      // SECTION 2: Today Dashboard & Overlays
      // -------------------------------------------------------------
      await binding.takeScreenshot('02_today_01_dashboard');

      // Personalization sheet
      final tuneIcon = find.byIcon(Icons.tune_rounded);
      if (tuneIcon.evaluate().isNotEmpty) {
        await tester.tap(tuneIcon.first);
        await tester.pumpAndSettle();
        await binding.takeScreenshot('02_today_02_personalization_sheet');
        if (find.byIcon(Icons.close_rounded).evaluate().isNotEmpty) {
          await tester.tap(find.byIcon(Icons.close_rounded).first);
          await tester.pumpAndSettle();
        } else {
          await popTop(rootNavigator: true);
        }
      }

      // Food guidance sheet
      unawaited(
        showIndiFitBottomSheet<void>(
          context: currentContext(),
          semanticLabel: 'Food guidance',
          builder: (sheetCtx) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'What can I eat?',
                        style: Theme.of(sheetCtx).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const B04CurrentFoodSummary(),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('02_today_03_guidance_sheet');
      await popTop(rootNavigator: true);

      // Hydration Detail Sheet
      unawaited(HydrationDetailSheet.show(rootScaffoldContext(), now));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(HydrationDetailSheet), findsOneWidget);
      await binding.takeScreenshot('02_today_04_hydration_detail_sheet');
      await popTop(rootNavigator: true);
      await tester.pumpAndSettle();
      expect(find.byType(HydrationDetailSheet), findsNothing);

      // Log Weight Bottom Sheet
      unawaited(
        LogWeightBottomSheet.show(rootScaffoldContext(), 72.0, (w) async {}),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(LogWeightBottomSheet), findsOneWidget);
      await binding.takeScreenshot('02_today_05_log_weight_sheet');
      await popTop(rootNavigator: true);
      await tester.pumpAndSettle();
      expect(find.byType(LogWeightBottomSheet), findsNothing);

      // -------------------------------------------------------------
      // SECTION 3: Food Diary, Search, Thali, Barcode, Recipes
      // -------------------------------------------------------------
      await tester.tap(find.text('Food').first);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('03_food_01_diary');

      // Food search landing
      final addFoodBtn = find.text('Add food');
      if (addFoodBtn.evaluate().isNotEmpty) {
        await tester.tap(addFoodBtn.first);
        await tester.pumpAndSettle();

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
          await binding.takeScreenshot('03_food_02_search_landing');

          // Search results
          final searchField = find.descendant(
            of: find.byType(FoodSearchBar),
            matching: find.byType(TextField),
          );
          if (searchField.evaluate().isNotEmpty) {
            await tester.tap(searchField);
            await tester.enterText(searchField, 'Paneer');
            await tester.pump(const Duration(milliseconds: 600));
            await tester.pumpAndSettle();
            await binding.takeScreenshot('03_food_03_search_results');

            // Portion sheet (IF-2)
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pumpAndSettle();
            final bhurjiFinder = find.text('Paneer Bhurji');
            final paneerTile = bhurjiFinder.evaluate().isNotEmpty
                ? bhurjiFinder
                : find.descendant(
                    of: find.byType(FoodSearchResultsList),
                    matching: find.byType(ListTile),
                  );
            if (paneerTile.evaluate().isNotEmpty) {
              await tester.tap(paneerTile.first);
              for (var i = 0; i < 30; i++) {
                await tester.pump(const Duration(milliseconds: 100));
                if (find.byType(FoodPortionBottomSheet).evaluate().isNotEmpty) {
                  break;
                }
              }
              await tester.pumpAndSettle();
              expect(find.byType(FoodPortionBottomSheet), findsOneWidget);
              await binding.takeScreenshot('03_food_04_portion_sheet');
              await popTop(rootNavigator: true);
              await tester.pumpAndSettle();
              expect(find.byType(FoodPortionBottomSheet), findsNothing);
            }
          }

          // Remote food review sheet
          unawaited(
            RemoteFoodReviewSheet.show(
              context: currentContext(),
              candidate: RemoteFoodCandidate(
                id: 'off_001',
                provider: FoodCatalogProvider.openFoodFacts,
                name: 'Greek Yogurt 0% Fat',
                brand: 'Chobani',
                category: 'Dairy',
                caloriesPer100g: 59.0,
                proteinPer100g: 10.3,
                carbsPer100g: 3.6,
                fatPer100g: 0.0,
                fiberPer100g: 0.0,
                servingOptions: const [
                  ServingOption(
                    unitName: '100g',
                    gramWeight: 100.0,
                    isDefault: true,
                  ),
                  ServingOption(
                    unitName: '1 pot (170g)',
                    gramWeight: 170.0,
                  ),
                ],
                provenance: FoodProvenance(
                  provider: FoodCatalogProvider.openFoodFacts,
                  attributionText: 'Open Food Facts contributors',
                  license: 'ODbL',
                  fetchedAtUtc: DateTime.utc(2026, 8, 1),
                ),
              ),
              mealType: 'lunch',
              selectedDate: now,
              onConfirm: ({
                required candidate,
                required quantity,
                required servingOption,
                required logImmediately,
              }) async {},
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          await binding.takeScreenshot('03_food_05_remote_review_sheet');
          await popTop(rootNavigator: true);

          // Pop FoodSearchScreen back to diary
          await popTop();
        }
      }

      // Thali Builder Screen (Circular plate, dual staples)
      unawaited(GoRouter.of(currentContext()).push('/food/thali?meal=lunch'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('03_food_06_thali_builder');

      // Thali Component Picker Sheet
      unawaited(
        ThaliComponentPickerSheet.show(
          currentContext(),
          controller: container.read(
            nutritionThaliControllerProvider('lunch').notifier,
          ),
          state: container.read(nutritionThaliControllerProvider('lunch')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('03_food_07_thali_component_picker');
      await popTop(rootNavigator: true);

      // Pop ThaliBuilderScreen
      await popTop();

      // Custom Food Editor Screen with Barcode Chip
      unawaited(
        Navigator.of(currentContext()).push(
          MaterialPageRoute(
            builder: (_) => const CustomFoodEditorScreen(
              initialBarcode: '8901030927341',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('03_food_08_custom_food_editor');
      await popTop();

      // Recipe Editor Screen
      unawaited(GoRouter.of(currentContext()).push('/food/recipes/edit'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('03_food_09_recipe_editor');
      await popTop();

      // -------------------------------------------------------------
      // SECTION 4: Training, Plans, Calendar & Exercises
      // -------------------------------------------------------------
      await tester.tap(find.text('Training').first);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_training_01_landing');

      // Plan Library
      unawaited(GoRouter.of(currentContext()).push('/plan-library'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_training_02_plan_library');

      // Plan Overview
      final starterPlan = OfflineStarterPlanCatalog.plans.first;
      unawaited(
        GoRouter.of(
          currentContext(),
        ).push('/plan-overview/${Uri.encodeComponent(starterPlan.sourceVersionId)}'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlanOverviewScreen), findsOneWidget);
      expect(find.text(starterPlan.name), findsOneWidget);
      await binding.takeScreenshot('04_training_03_plan_overview');
      await popTop();
      await popTop();

      // Routine Editor
      unawaited(GoRouter.of(currentContext()).push('/routine-editor'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_training_04_routine_editor');

      // Exercise Picker Sheet
      unawaited(showExercisePicker(context: currentContext()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_training_05_exercise_picker_sheet');
      await popTop();
      await popTop();

      // Program Calendar
      unawaited(GoRouter.of(currentContext()).push('/calendar'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_training_06_program_calendar');

      // Calendar Occurrence Actions Sheet
      unawaited(
        showIndiFitBottomSheet<void>(
          context: currentContext(),
          semanticLabel: 'Workout actions',
          builder: (_) =>
              OccurrenceActionsSheet(occurrenceItem: _buildMockOccurrence()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_training_07_occurrence_actions_sheet');
      await popTop();
      await popTop();

      // Exercise Library
      unawaited(GoRouter.of(currentContext()).push('/exercises'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_training_08_exercise_library');

      // Exercise Details Sheet
      unawaited(
        showModalBottomSheet<void>(
          context: currentContext(),
          isScrollControlled: true,
          builder: (_) => const ExerciseDetailsSheet(
            exercise: Exercise(
              id: 1,
              stableId: 'ex_bench_press',
              name: 'Flat Barbell Bench Press',
              muscleGroups: 'chest,triceps,front_delts',
              equipment: 'barbell',
              difficulty: 'intermediate',
              formCues:
                  'Retract scapulae, maintain arch, touch lower sternum.',
              commonMistakes:
                  'Flaring elbows 90 degrees, lifting hips off bench.',
              isCustom: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_training_09_exercise_details_sheet');
      await popTop();
      await popTop();

      // Workout History
      unawaited(GoRouter.of(currentContext()).push('/workout-history'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_training_10_workout_history');
      await popTop();

      // Quick Workout Builder
      unawaited(GoRouter.of(currentContext()).push('/quick-workout'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_training_11_quick_workout');
      await popTop();

      // -------------------------------------------------------------
      // SECTION 5: B02 Strength Workout Player
      // -------------------------------------------------------------
      final adapter = container.read(
        strengthExecutionCompatibilityAdapterProvider,
      );
      final initialDraft = await adapter.startUnscheduledDraft(
        routineName: 'Chest & Triceps Hypertrophy',
        executionSnapshotJson: quickWorkoutSnapshotJson(
          'Chest & Triceps Hypertrophy',
        ),
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
      unawaited(
        GoRouter.of(currentContext()).push(
          '/b02-strength-player',
          extra: WorkoutExecutionRouteData.fromLaunch(
            withBench.copyWith(state: preparedDraft.state),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('05_player_01_active_execution');

      // Plate Calculator Sheet
      unawaited(
        PlateCalculatorSheet.show(
          context: currentContext(),
          initialWeight: 60.0,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('05_player_02_plate_calculator_sheet');
      await popTop();

      // Rest Timer Bottom Sheet
      unawaited(RestTimerBottomSheet.show(currentContext(), 90));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('05_player_03_rest_timer_sheet');
      await popTop(rootNavigator: true);

      // Discard Workout Confirmation Dialog
      unawaited(
        showDialog<bool>(
          context: currentContext(),
          builder: (ctx) => AlertDialog(
            title: const Text('Discard workout?'),
            content: const Text(
              'This will end the workout and delete all recorded sets. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep workout'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('05_player_04_discard_dialog');
      final keepBtn = find.text('Keep workout');
      if (keepBtn.evaluate().isNotEmpty) {
        await tester.tap(keepBtn.first);
        await tester.pumpAndSettle();
      } else {
        await popTop();
      }

      // Workout Summary
      unawaited(
        Navigator.of(currentContext()).push(
          MaterialPageRoute(
            builder: (_) => const WorkoutSummaryScreen(
              routineName: 'Chest & Triceps Hypertrophy',
              elapsedSeconds: 2450,
              loggedSets: [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('05_player_05_workout_summary');
      await popTop();

      // Achievement celebration sheet
      unawaited(
        showAchievementCelebrationSheet(
          currentContext(),
          achievements: [
            Achievement(
              id: 'first_workout',
              title: 'First Workout Logged',
              description: 'Recorded your first workout in IndiFit',
              icon: Icons.fitness_center_rounded,
              color: const Color(0xFF6366F1),
              currentProgress: 1.0,
              maxProgress: 1.0,
              isUnlocked: true,
              evidence: '1 completed workout verified in local database',
              unlockedAt: now,
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('05_player_06_celebration_sheet');
      await popTop();

      // Pop B02 player back to Training
      await popTop();

      // -------------------------------------------------------------
      // SECTION 6: Progress, Volume & Insights
      // -------------------------------------------------------------
      await tester.tap(find.text('Progress').first);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('06_progress_01_overview');

      // Period Comparison Drilldown Sheet
      final periodSnapshot = await container.read(
        progressPeriodComparisonSnapshotProvider.future,
      );
      PeriodComparisonDrilldownSheet.show(
        currentContext(),
        snapshot: periodSnapshot,
        units: 'kg',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('06_progress_02_period_comparison_sheet');
      await popTop();

      // Achievements screen
      unawaited(GoRouter.of(currentContext()).push('/achievements'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('06_progress_03_achievements_screen');

      // Achievement Detail Sheet
      unawaited(
        showAchievementDetailSheet(
          currentContext(),
          achievement: Achievement(
            id: 'first_workout',
            title: 'First Workout Logged',
            description: 'Recorded your first workout in IndiFit',
            icon: Icons.fitness_center_rounded,
            color: const Color(0xFF6366F1),
            currentProgress: 1.0,
            maxProgress: 1.0,
            isUnlocked: true,
            evidence: '1 completed workout verified in local database',
            unlockedAt: now,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('06_progress_04_achievement_detail_sheet');
      await popTop();
      await popTop();

      // -------------------------------------------------------------
      // SECTION 7: Settings, Health Sync & Legal Compliance
      // -------------------------------------------------------------
      unawaited(GoRouter.of(currentContext()).push('/settings'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('07_settings_01_main_menu');

      // Profile screen
      unawaited(GoRouter.of(currentContext()).push('/profile'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('07_settings_02_profile_screen');
      await popTop();

      // Goals & Targets hub screen
      unawaited(
        Navigator.of(currentContext()).push(
          MaterialPageRoute(
            builder: (_) => const NutritionTargetsHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NutritionTargetsHubScreen), findsOneWidget);
      expect(find.text('Nutrition targets unavailable'), findsNothing);
      await binding.takeScreenshot('07_settings_03_goals_and_targets');
      await popTop();

      // Health Sync Hub
      unawaited(GoRouter.of(currentContext()).push('/health-hub'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('07_settings_04_health_sync_hub');
      await popTop();

      // DPDP Consent Dialog
      unawaited(DpdpConsentDialog.show(currentContext()));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('07_settings_05_dpdp_consent_dialog');
      final cancelConsent = find.text('Cancel');
      if (cancelConsent.evaluate().isNotEmpty) {
        await tester.tap(cancelConsent.first);
        await tester.pumpAndSettle();
      } else {
        await popTop();
      }

      // Data Management & Danger Zone Data Erasure Dialog
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

        final eraseAllButton = find.text('Erase all data');
        if (eraseAllButton.evaluate().isNotEmpty) {
          await tester.ensureVisible(eraseAllButton.first);
          await tester.pumpAndSettle();
          await tester.tap(eraseAllButton.first);
          await tester.pumpAndSettle();
          await binding.takeScreenshot('07_settings_06_danger_zone_erasure');

          // Dismiss dialog
          final cancelErasure = find.text('Cancel');
          if (cancelErasure.evaluate().isNotEmpty) {
            await tester.tap(cancelErasure.first);
            await tester.pumpAndSettle();
          }
        }
      }

      // Pop back to root scaffold
      while (find.byType(Scaffold).evaluate().length > 1) {
        await popTop();
      }

      // -------------------------------------------------------------
      // SECTION 8: Theme Mode Verification (Dark Theme)
      // -------------------------------------------------------------
      router.go('/');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.darkTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today').first);
      await tester.pumpAndSettle();
      expect(find.text('Nutrition'), findsOneWidget);
      await binding.takeScreenshot('08_theme_01_dark_mode_dashboard');

      expect(tester.takeException(), isNull);
    },
  );
}
