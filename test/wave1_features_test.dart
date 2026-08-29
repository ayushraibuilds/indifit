import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/dashboard/dashboard_controller.dart';
import 'package:indifit/features/workout_player/workout_player_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FoodRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = FoodRepository(db);
    SharedPreferences.setMockInitialValues({
      'streak_freezes_count': 1,
      'current_weight': 70.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('Wave 1 FoodRepository Recent Foods Tests', () {
    test('getRecentFoods returns most logged foods sorted by count', () async {
      // Log some items
      await repo.logFoodEntry(
        name: 'Apple',
        calories: 95,
        proteinG: 0.5,
        carbsG: 25.0,
        fatG: 0.3,
        servingLogged: 1.0,
        servingUnit: 'piece',
        mealType: 'snack',
      );
      await repo.logFoodEntry(
        name: 'Banana',
        calories: 105,
        proteinG: 1.3,
        carbsG: 27.0,
        fatG: 0.3,
        servingLogged: 1.0,
        servingUnit: 'piece',
        mealType: 'snack',
      );
      await repo.logFoodEntry(
        name: 'Apple',
        calories: 95,
        proteinG: 0.5,
        carbsG: 25.0,
        fatG: 0.3,
        servingLogged: 2.0,
        servingUnit: 'piece',
        mealType: 'snack',
      );

      final recents = await repo.getRecentFoods(10);
      expect(recents.length, 2);
      expect(recents.first.name, 'Apple'); // Apple is logged twice
      expect(recents[1].name, 'Banana'); // Banana is logged once
    });
  });

  group('Wave 1 WorkoutPlayerController Set Type Tests', () {
    test('Selected Set Type updates correctly and maps isWarmUp', () async {
      final mockExercise = RoutineExercise(
        id: 1,
        dayId: 1,
        exerciseName: 'Pushups',
        sets: 3,
        repsRange: '10',
        orderIndex: 1,
      );

      final controllerProvider =
          StateNotifierProvider<WorkoutPlayerController, WorkoutPlayerState>((
            ref,
          ) {
            return WorkoutPlayerController(
              ref,
              routineName: 'Test Routine',
              initialExercises: [mockExercise],
            );
          });

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          workoutRepositoryProvider.overrideWithValue(WorkoutRepository(db)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(controllerProvider.notifier);
      await controller.prefillInputs();

      expect(container.read(controllerProvider).selectedSetType, 'working');
      expect(container.read(controllerProvider).isWarmUp, isFalse);

      controller.setSelectedSetType('warmup');
      expect(container.read(controllerProvider).selectedSetType, 'warmup');
      expect(container.read(controllerProvider).isWarmUp, isTrue);

      controller.setSelectedSetType('dropset');
      expect(container.read(controllerProvider).selectedSetType, 'dropset');
      expect(container.read(controllerProvider).isWarmUp, isFalse);

      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('legacy logging does not manufacture personal-record truth', () async {
      final controllerProvider =
          StateNotifierProvider<WorkoutPlayerController, WorkoutPlayerState>((
            ref,
          ) {
            return WorkoutPlayerController(
              ref,
              routineName: 'Legacy compatibility workout',
              initialExercises: const [
                RoutineExercise(
                  id: 1,
                  dayId: 1,
                  exerciseName: 'Bench Press',
                  sets: 1,
                  repsRange: '8',
                  orderIndex: 1,
                ),
              ],
            );
          });

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          workoutRepositoryProvider.overrideWithValue(WorkoutRepository(db)),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(controllerProvider.notifier)
          .recordSet(weight: 100, reps: 8);
      final loggedSet = container.read(controllerProvider).loggedSets.single;

      expect(loggedSet.isPr.value, isFalse);
    });
  });

  group('Wave 1 Streak Freeze Shield Tests', () {
    test('purchaseStreakFreeze increments count in state and prefs', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          foodRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(dashboardControllerProvider.notifier);
      await controller.loadStateData();
      await controller.computeStreak();

      expect(container.read(dashboardControllerProvider).streakFreezesCount, 1);

      await controller.purchaseStreakFreeze();
      expect(container.read(dashboardControllerProvider).streakFreezesCount, 2);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('streak_freezes_count'), 2);

      await Future.delayed(const Duration(milliseconds: 50));
    });
  });
}
