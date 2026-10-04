import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/streak_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/indifit_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutrientRegistry registry;
  late NutritionConsumptionRepository consumption;
  // Local noon on 2026-10-03: "today" for every test.
  final now = DateTime(2026, 10, 3, 12);

  setUp(() async {
    db = registerTestDatabaseScope().create();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    consumption = NutritionConsumptionRepository(db: db, registry: registry);
    SharedPreferences.setMockInitialValues({});
    await db
        .into(db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: 'food-1',
            kind: 'userCreated',
            displayName: 'Dal',
            locale: 'en-IN',
            sourceType: 'user',
            lifecycle: 'active',
          ),
        );
  });

  StreakRepository streaks({DateTime? at}) => StreakRepository(
    nutrition: () async =>
        NutritionReadModelRepository(db: db, registry: registry),
    workouts: WorkoutRepository(db),
    preferences: SharedPreferences.getInstance,
    now: () => at ?? now,
  );

  Future<NutritionConsumptionSnapshot> logCanonical(
    String localDate,
    String id,
  ) => consumption.finalizeConsumption(
    NutritionConsumptionFinalizeRequest(
      userId: kLocalNutritionUserScopeId,
      consumptionId: id,
      commandId: '$id-command',
      loggedAtUtc: DateTime.parse('${localDate}T06:30:00Z'),
      mealCategory: 'lunch',
      sourceType: 'direct_food',
      localDate: localDate,
      timezoneId: 'Asia/Kolkata',
      calculatorVersion: 'streak-test-v1',
      items: [
        NutritionConsumptionItemInput(
          id: '$id-item',
          position: 0,
          sourceType: 'direct_food',
          foodId: 'food-1',
          displayLabel: 'Dal',
          quantity: Quantity.fromDecimal(
            amount: '100',
            unit: QuantityUnit.gram,
          ),
          calculation: NutritionConsumptionCalculationSnapshot.fromFacts(
            facts: {
              'energy': NutrientFact.known(
                nutrientId: 'energy',
                point: NutrientAmount(
                  value: QuantityAmount.fromString('120'),
                  unit: NutrientUnit.kilocalorie,
                ),
                basis: NutrientBasis(NutrientBasisKind.absolute),
                source: NutrientSourceType.reviewedCatalogue,
                factVersion: '1',
              ),
            },
            registry: registry,
            requestedNutrientIds: const ['energy'],
            calculatorVersion: 'streak-test-v1',
            calculationFingerprint: 'streak-$id',
          ),
        ),
      ],
    ),
  );

  Future<void> logWorkout(DateTime completedAt) => db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: 'Push',
          totalVolume: 1000,
          durationSeconds: 1800,
          estimatedCalories: 200,
          completedAt: Value(completedAt),
        ),
      );

  test('new-style food logs count toward the streak', () async {
    await logCanonical('2026-10-02', 'yesterday');
    await logCanonical('2026-10-03', 'today');

    expect(await streaks().currentStreak(), 2);
    // The old streak read only this legacy table, which new logging skips.
    expect(await FoodRepository(db).getAllLogDates(), isEmpty);
  });

  test('food, legacy logs and workouts combine into one run', () async {
    await logCanonical('2026-10-03', 'today');
    await logWorkout(DateTime(2026, 10, 2, 19));
    await FoodRepository(db).logFoodEntry(
      name: 'Poha',
      calories: 250,
      proteinG: 5,
      carbsG: 45,
      fatG: 6,
      servingLogged: 1,
      servingUnit: 'plate',
      mealType: 'breakfast',
      loggedAt: DateTime(2026, 10, 1, 8),
    );

    expect(await streaks().currentStreak(), 3);
  });

  test('a deleted food log no longer counts', () async {
    await logCanonical('2026-10-02', 'yesterday');
    final today = await logCanonical('2026-10-03', 'today');
    await consumption.retractConsumption(
      userId: kLocalNutritionUserScopeId,
      snapshotId: today.id,
      expectedLocalDate: '2026-10-03',
      expectedMealCategory: 'lunch',
      commandId: 'delete-today',
    );

    // Today is empty again, so the run ends yesterday.
    expect(await streaks().currentStreak(), 1);
  });

  test('a single day with the default freeze is a streak of 1', () async {
    await logCanonical('2026-10-03', 'today');

    expect(await streaks().freezeCount(), StreakRepository.defaultFreezes);
    expect(await streaks().currentStreak(), 1);
  });

  test('just after local midnight counts as the new day', () async {
    await logCanonical('2026-10-02', 'yesterday');

    // 00:30 on the 3rd: nothing logged today yet, the run is still alive.
    expect(await streaks(at: DateTime(2026, 10, 3, 0, 30)).currentStreak(), 1);
  });
}
