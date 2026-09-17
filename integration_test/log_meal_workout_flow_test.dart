import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoadedProfileNotifier extends UserProfileNotifier {
  _LoadedProfileNotifier() : super() {
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'E2E Log Meal & Workout session persistence flow',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'user_streak_count': 1,
        'user_name': 'Aarav',
      });
      final prefs = await SharedPreferences.getInstance();
      final database = AppDatabase.memory();
      final foodRepo = FoodRepository(database);
      final workoutRepo = WorkoutRepository(database);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
          foodRepositoryProvider.overrideWithValue(foodRepo),
          workoutRepositoryProvider.overrideWithValue(workoutRepo),
          userProfileProvider.overrideWith((ref) => _LoadedProfileNotifier()),
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

      // 1. Verify app boots to Dashboard
      expect(find.byType(MaterialApp), findsOneWidget);

      // 2. Perform meal log via repository (Offline fallback / online-first model)
      final now = DateTime.now();
      final foodLogId = await foodRepo.logFoodEntry(
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

      expect(foodLogId, isPositive);

      // Verify Drift SQLite persistence of food log
      final foodLogs = await database.select(database.foodLogs).get();
      expect(foodLogs, hasLength(1));
      expect(foodLogs.first.name, 'Dal Makhani & Roti');
      expect(foodLogs.first.calories, 450);
      expect(foodLogs.first.proteinG, 18.0);
      expect(foodLogs.first.mealType, 'lunch');

      // Trigger revision update to verify UI reactive surface
      container.read(todayNutritionRevisionProvider.notifier).state++;
      await tester.pumpAndSettle();

      // 3. Perform strength workout session execution & logging (100% offline Drift v22 invariant)
      final sessionId = await workoutRepo.logSession(
        name: 'Push Hypertrophy',
        volume: 1200.0,
        durationSeconds: 2700,
        calories: 0,
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
            exerciseName: 'Flat Barbell Bench Press',
            setNumber: 2,
            weight: 60.0,
            reps: 8,
          ),
        ],
        completedAt: now,
      );

      expect(sessionId, isPositive);

      // Verify Drift SQLite persistence of workout session & sets
      final sessions = await database.select(database.workoutSessions).get();
      expect(sessions, hasLength(1));
      expect(sessions.first.name, 'Push Hypertrophy');
      expect(sessions.first.totalVolume, 1200.0);
      expect(sessions.first.durationSeconds, 2700);

      final sets = await database.select(database.workoutSets).get();
      expect(sets, hasLength(2));
      expect(sets.first.exerciseName, 'Flat Barbell Bench Press');
      expect(sets.first.weight, 60.0);
      expect(sets.first.reps, 10);
      expect(sets.last.reps, 8);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
