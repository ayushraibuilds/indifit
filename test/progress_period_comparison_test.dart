import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/progress_period_comparison_models.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/progress_period_comparison_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late LocalScheduleDateService dates;
  late NutrientRegistry registry;
  late NutritionConsumptionRepository consumptionRepo;
  late NutritionReadModelRepository nutritionRepo;
  late ProgressPeriodComparisonRepository comparisonRepo;

  setUp(() async {
    database = AppDatabase.memory();
    dates = LocalScheduleDateService();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    consumptionRepo = NutritionConsumptionRepository(
      db: database,
      registry: registry,
    );
    nutritionRepo = NutritionReadModelRepository(
      db: database,
      registry: registry,
      canonicalRepository: consumptionRepo,
      legacyUserId: kLocalNutritionUserScopeId,
    );
    comparisonRepo = ProgressPeriodComparisonRepository(
      database: database,
      dates: dates,
      nutrition: nutritionRepo,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('PV1-PROG-01: Bounded Window Resolution', () {
    test('resolves Monday-to-Sunday civil bounds for weekly range', () async {
      // 2026-09-16 is a Wednesday (weekday 3)
      final wednesdayUtc = DateTime.utc(2026, 9, 16, 10, 0);
      final snapshot = await comparisonRepo.comparePeriods(
        range: PeriodComparisonRange.week,
        nowUtc: wednesdayUtc,
        timezoneId: 'UTC',
      );

      // Current week: Mon 2026-09-14 through Sun 2026-09-20
      expect(snapshot.currentWindow.startLocalDate, '2026-09-14');
      expect(snapshot.currentWindow.endLocalDate, '2026-09-20');
      expect(snapshot.currentWindow.daysCount, 7);
      expect(snapshot.currentWindow.status, PeriodCompletenessStatus.inProgress);
      expect(snapshot.currentWindow.inProgressDayIndex, 3);

      // Previous week: Mon 2026-09-07 through Sun 2026-09-13
      expect(snapshot.previousWindow.startLocalDate, '2026-09-07');
      expect(snapshot.previousWindow.endLocalDate, '2026-09-13');
      expect(snapshot.previousWindow.daysCount, 7);
      expect(snapshot.previousWindow.status, PeriodCompletenessStatus.complete);
    });

    test('resolves 28-day bounded window for four-week range', () async {
      final nowUtc = DateTime.utc(2026, 9, 16, 12, 0);
      final snapshot = await comparisonRepo.comparePeriods(
        range: PeriodComparisonRange.fourWeeks,
        nowUtc: nowUtc,
        timezoneId: 'UTC',
      );

      expect(snapshot.currentWindow.daysCount, 28);
      expect(snapshot.currentWindow.endLocalDate, '2026-09-16');
      expect(snapshot.currentWindow.startLocalDate, '2026-08-20');

      expect(snapshot.previousWindow.daysCount, 28);
      expect(snapshot.previousWindow.endLocalDate, '2026-08-19');
      expect(snapshot.previousWindow.startLocalDate, '2026-07-23');
    });
  });

  group('PV1-PROG-01: Training Period Comparisons', () {
    test('compares workout sessions, days, sets, and volume across weeks', () async {
      await _insertExercise(
        database,
        stableId: 'bench-press',
        name: 'Bench Press',
      );

      // Previous week: 2026-09-07 to 2026-09-13
      // Insert 2 workouts in previous week
      final prev1 = await _insertSession(
        database,
        name: 'Upper Body A',
        completedAt: DateTime.utc(2026, 9, 8, 10, 0),
        durationSeconds: 3600,
        activityType: 'strength',
      );
      await _insertSession(
        database,
        name: 'Lower Body A',
        completedAt: DateTime.utc(2026, 9, 10, 10, 0),
        durationSeconds: 3000,
        activityType: 'strength',
      );

      // Add working set to prev1
      final pe1 = await database.into(database.performedExercises).insertReturning(
        PerformedExercisesCompanion.insert(
          id: 'pe-prev-1',
          sessionId: prev1,
          actualExerciseId: 'bench-press',
          actualExerciseNameSnapshot: 'Bench Press',
          status: const Value('completed'),
          ordinal: 0,
        ),
      );
      await database.into(database.performedSets).insert(
        PerformedSetsCompanion.insert(
          id: 'ps-prev-1',
          performedExerciseId: pe1.id,
          role: B02SetRole.working.dbValue,
          ordinal: 0,
          actualLoadKg: const Value(80.0),
          actualReps: const Value(8),
          actualLoadBasis: const Value('totalExternal'),
        ),
      );

      // Current week: 2026-09-14 to 2026-09-20
      // Insert 3 workouts in current week
      final cur1 = await _insertSession(
        database,
        name: 'Upper Body B',
        completedAt: DateTime.utc(2026, 9, 14, 10, 0),
        durationSeconds: 4000,
        activityType: 'strength',
      );
      await _insertSession(
        database,
        name: 'Lower Body B',
        completedAt: DateTime.utc(2026, 9, 15, 10, 0),
        durationSeconds: 3200,
        activityType: 'strength',
      );
      await _insertSession(
        database,
        name: 'Conditioning',
        completedAt: DateTime.utc(2026, 9, 16, 9, 0),
        durationSeconds: 1800,
        activityType: 'running',
      );

      // Add working set to cur1
      final peCur = await database.into(database.performedExercises).insertReturning(
        PerformedExercisesCompanion.insert(
          id: 'pe-cur-1',
          sessionId: cur1,
          actualExerciseId: 'bench-press',
          actualExerciseNameSnapshot: 'Bench Press',
          status: const Value('completed'),
          ordinal: 0,
        ),
      );
      await database.into(database.performedSets).insert(
        PerformedSetsCompanion.insert(
          id: 'ps-cur-1',
          performedExerciseId: peCur.id,
          role: B02SetRole.working.dbValue,
          ordinal: 0,
          actualLoadKg: const Value(85.0),
          actualReps: const Value(8),
          actualLoadBasis: const Value('totalExternal'),
        ),
      );

      // Compare as of Wednesday 2026-09-16
      final snapshot = await comparisonRepo.comparePeriods(
        range: PeriodComparisonRange.week,
        nowUtc: DateTime.utc(2026, 9, 16, 12, 0),
        timezoneId: 'UTC',
      );

      final train = snapshot.trainingComparison;
      expect(train.hasAnyActivity, isTrue);

      // Session counts: 3 current vs 2 previous (delta: +1)
      expect(train.current.sessionCount, 3);
      expect(train.previous.sessionCount, 2);
      expect(train.sessionCountMetric.delta, 1.0);
      expect(train.sessionCountMetric.percentChange, 50.0);

      // Training days: 3 vs 2
      expect(train.current.trainingDayCount, 3);
      expect(train.previous.trainingDayCount, 2);

      // Volume comparison: 85 * 8 = 680 vs 80 * 8 = 640 (delta: +40)
      expect(train.current.totalVolumeKg, 680.0);
      expect(train.previous.totalVolumeKg, 640.0);
      expect(train.volumeMetric.delta, 40.0);

      // Exercise comparison for bench-press
      expect(snapshot.strengthComparisons, isNotEmpty);
      final bench = snapshot.strengthComparisons.firstWhere(
        (ex) => ex.exerciseId == 'bench-press',
      );
      expect(bench.currentHeaviestLoadKg, 85.0);
      expect(bench.previousHeaviestLoadKg, 80.0);
      expect(bench.volumeDeltaKg, 40.0);
    });
  });

  group('PV1-PROG-01: Nutrition Completeness & Logged-Day Denominators', () {
    test('averages calories strictly over logged days, not total calendar days', () async {
      // In current week: log on 2 days only (2026-09-14 and 2026-09-15)
      // Day 1: 2000 kcal, 140g protein
      await database.into(database.foodLogs).insert(
        FoodLogsCompanion.insert(
          name: 'Chicken Rice Bowl',
          calories: 2000,
          proteinG: 140.0,
          carbsG: 200.0,
          fatG: 50.0,
          servingLogged: 1.0,
          servingUnit: 'bowl',
          mealType: 'lunch',
          loggedAt: Value(DateTime.utc(2026, 9, 14, 12, 0)),
        ),
      );

      // Day 2: 2200 kcal, 160g protein
      await database.into(database.foodLogs).insert(
        FoodLogsCompanion.insert(
          name: 'Egg Curry with Rice',
          calories: 2200,
          proteinG: 160.0,
          carbsG: 210.0,
          fatG: 55.0,
          servingLogged: 1.0,
          servingUnit: 'bowl',
          mealType: 'dinner',
          loggedAt: Value(DateTime.utc(2026, 9, 15, 19, 0)),
        ),
      );

      final snapshot = await comparisonRepo.comparePeriods(
        range: PeriodComparisonRange.week,
        nowUtc: DateTime.utc(2026, 9, 16, 12, 0),
        timezoneId: 'UTC',
      );

      final nut = snapshot.nutritionComparison;
      expect(nut, isNotNull);
      expect(nut!.current.loggedDaysCount, 2);
      expect(nut.current.daysInPeriod, 7);

      // Total kcal = 4200 / 2 logged days = 2100 kcal!
      // MUST NOT be 4200 / 7 = 600 kcal!
      expect(nut.current.averageCaloriesKcal, 2100.0);

      // Total protein = 300 / 2 logged days = 150g!
      // MUST NOT be 300 / 7 = 42.8g!
      expect(nut.current.averageProteinG, 150.0);

      // Evidence description proves honest denominator
      expect(
        nut.caloriesMetric.evidenceDescription,
        contains('2/7 days logged'),
      );
    });
  });

  group('PV1-PROG-01: Weight Period Comparisons', () {
    test('computes weight delta and weekly rate of change truthfully', () async {
      // Previous week: single observation 80.0 kg on 2026-09-10
      await database.into(database.bodyMeasurements).insert(
        BodyMeasurementsCompanion.insert(
          weight: const Value(80.0),
          recordedAt: Value(DateTime.utc(2026, 9, 10, 8, 0)),
        ),
      );

      // Current week: observation 79.2 kg on 2026-09-15
      await database.into(database.bodyMeasurements).insert(
        BodyMeasurementsCompanion.insert(
          weight: const Value(79.2),
          recordedAt: Value(DateTime.utc(2026, 9, 15, 8, 0)),
        ),
      );

      final snapshot = await comparisonRepo.comparePeriods(
        range: PeriodComparisonRange.week,
        nowUtc: DateTime.utc(2026, 9, 16, 12, 0),
        timezoneId: 'UTC',
      );

      final weight = snapshot.weightComparison;
      expect(weight, isNotNull);
      expect(weight!.current.latestWeightKg, 79.2);
      expect(weight.previous.latestWeightKg, 80.0);

      // Delta: 79.2 - 80.0 = -0.8 kg
      expect(weight.weightDeltaBetweenPeriodsKg, closeTo(-0.8, 0.001));
      expect(weight.ratePerWeekKg, closeTo(-0.8, 0.001));
    });

    test('suppresses rate of change when period has only 1 point observation', () async {
      await database.into(database.bodyMeasurements).insert(
        BodyMeasurementsCompanion.insert(
          weight: const Value(75.0),
          recordedAt: Value(DateTime.utc(2026, 9, 15, 8, 0)),
        ),
      );

      final snapshot = await comparisonRepo.comparePeriods(
        range: PeriodComparisonRange.week,
        nowUtc: DateTime.utc(2026, 9, 16, 12, 0),
        timezoneId: 'UTC',
      );

      final weight = snapshot.weightComparison;
      expect(weight, isNotNull);
      expect(weight!.current.observationCount, 1);
      // Intra-period delta is null because only 1 measurement was logged
      expect(weight.current.hasMeaningfulDelta, isFalse);
      expect(weight.current.deltaKg, isNull);
    });
  });

  group('PV1-PROG-01: Zero-Data & Non-Synthetic Invariants', () {
    test('handles completely empty database without errors', () async {
      final snapshot = await comparisonRepo.comparePeriods(
        range: PeriodComparisonRange.week,
        nowUtc: DateTime.utc(2026, 9, 16, 12, 0),
        timezoneId: 'UTC',
      );

      expect(snapshot.hasAnyData, isFalse);
      expect(snapshot.trainingComparison.hasAnyActivity, isFalse);
      expect(snapshot.nutritionComparison, isNull);
      expect(snapshot.weightComparison, isNull);
      expect(snapshot.strengthComparisons, isEmpty);
    });
  });
}

Future<int> _insertSession(
  AppDatabase database, {
  required String name,
  required DateTime completedAt,
  int durationSeconds = 600,
  String activityType = 'strength',
  String completionKind = 'full',
}) =>
    database.into(database.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            name: name,
            totalVolume: 0,
            durationSeconds: durationSeconds,
            estimatedCalories: 0,
            completedAt: Value(completedAt),
            activityType: Value(activityType),
            completionKind: Value(completionKind),
            activitySchemaVersion: const Value(1),
          ),
        );

Future<void> _insertExercise(
  AppDatabase database, {
  required String stableId,
  required String name,
}) =>
    database.into(database.exercises).insert(
          ExercisesCompanion.insert(
            stableId: Value(stableId),
            name: name,
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );

