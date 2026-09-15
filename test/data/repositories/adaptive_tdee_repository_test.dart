import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_adaptive_target_models.dart';
import 'package:indifit/data/repositories/adaptive_tdee_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late LocalScheduleDateService dates;
  late AdaptiveTdeeRepository repository;

  setUp(() {
    database = AppDatabase.memory();
    dates = LocalScheduleDateService(
      nowUtc: () => DateTime.utc(2026, 3, 15, 12),
    );
    repository = AdaptiveTdeeRepository(
      database,
      dates: dates,
    );
  });

  tearDown(() => database.close());

  group('AdaptiveTdeeRepository - Data Precedence & Invariants', () {
    test('strictly selects canonical snapshot energy over foodLogs on the same civil day (no double-counting)', () async {
      final civilDate = '2026-03-10';
      final recordedAt = DateTime.utc(2026, 3, 10, 12);

      // Insert baseline profile: 70kg, 170cm, 25yo male, moderate activity
      await database.into(database.userProfiles).insert(
            UserProfilesCompanion.insert(
              age: const Value(25),
              height: const Value(170.0),
              weight: const Value(70.0),
              sex: const Value('male'),
              activityLevel: const Value('moderate'),
            ),
          );

      // 1. Insert food log with 1,500 kcal on 2026-03-10
      await database.into(database.foodLogs).insert(
            FoodLogsCompanion.insert(
              name: 'Lunch Roti & Dal',
              calories: 1500,
              proteinG: 45.0,
              carbsG: 180.0,
              fatG: 40.0,
              servingLogged: 1.0,
              servingUnit: 'serving',
              mealType: 'lunch',
              loggedAt: Value(recordedAt),
            ),
          );

      // 2. Insert canonical snapshot with 2,200 kcal on the SAME civil day
      await database.into(database.nutritionConsumptionSnapshots).insert(
            NutritionConsumptionSnapshotsCompanion.insert(
              id: 'snap-001',
              userId: 'local_user',
              loggedAt: recordedAt,
              mealCategory: 'lunch',
              sourceType: 'direct_food',
              calculatorVersion: 'v1',
              completeness: 'complete',
              estimateStatus: 'none',
              localDate: Value(civilDate),
              timezoneId: const Value('UTC'),
            ),
          );

      // Insert snapshot nutrients fact: 2,200 kcal energy (nutrientId is 'energy' in registry)
      await database.into(database.nutritionSnapshotNutrients).insert(
            NutritionSnapshotNutrientsCompanion.insert(
              id: 'nutrient-001',
              snapshotId: 'snap-001',
              nutrientId: 'energy',
              amount: const Value(2200.0),
              status: 'known',
              unit: 'energy_kilocalorie',
              sourceVersion: 'v1',
            ),
          );

      // Also insert a scale weight
      await database.into(database.bodyMeasurements).insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(70.0),
              recordedAt: Value(recordedAt),
            ),
          );

      final estimate = await repository.evaluate(
        nowUtc: DateTime.utc(2026, 3, 10, 18),
        timezoneId: 'UTC',
      );

      // Verify that the day input used the SNAPSHOT (2200 kcal), NOT 1500 + 2200 = 3700 kcal!
      final dayOutput = estimate.history.firstWhere((d) => d.localDate == civilDate);
      expect(dayOutput.hasObservedIntake, isTrue);
      // Raw expenditure on day 1 with weight 70 kg should be based on 2200 kcal
      expect(dayOutput.rawExpenditureKcal, closeTo(2200.0, 0.01));
    });

    test('multi-weigh-in on the same civil day resolves to median weight', () async {
      // Insert 3 weigh-ins on the same day: 75.0, 76.0, 74.0 kg -> median = 75.0 kg
      await database.into(database.bodyMeasurements).insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(75.0),
              recordedAt: Value(DateTime.utc(2026, 3, 12, 7)),
            ),
          );
      await database.into(database.bodyMeasurements).insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(76.0),
              recordedAt: Value(DateTime.utc(2026, 3, 12, 13)),
            ),
          );
      await database.into(database.bodyMeasurements).insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(74.0),
              recordedAt: Value(DateTime.utc(2026, 3, 12, 21)),
            ),
          );

      final estimate = await repository.evaluate(
        nowUtc: DateTime.utc(2026, 3, 12, 23),
        timezoneId: 'UTC',
      );

      expect(estimate.currentScaleWeightKg, 75.0);
      expect(estimate.trendWeightKg, 75.0);
    });

    test('read-only invariant: repository evaluation leaves NutritionGoalVersions untouched', () async {
      final initialGoals = await database.select(database.nutritionGoalVersions).get();
      expect(initialGoals, isEmpty);

      // Perform evaluation with some data
      await database.into(database.bodyMeasurements).insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(72.0),
              recordedAt: Value(DateTime.utc(2026, 3, 14, 8)),
            ),
          );

      await repository.evaluate(
        nowUtc: DateTime.utc(2026, 3, 14, 12),
        timezoneId: 'UTC',
      );

      final postEvaluationGoals = await database.select(database.nutritionGoalVersions).get();
      expect(postEvaluationGoals, isEmpty, reason: 'AdaptiveTdeeRepository must NEVER mutate target goals.');
    });

    test('toMaintenanceEvidence mapper sets exact B04 contract values', () async {
      // 1. Insert profile & data
      await database.into(database.userProfiles).insert(
            UserProfilesCompanion.insert(
              age: const Value(28),
              height: const Value(175.0),
              weight: const Value(72.0),
              sex: const Value('male'),
              activityLevel: const Value('very_active'),
            ),
          );

      await database.into(database.bodyMeasurements).insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(72.0),
              recordedAt: Value(DateTime.utc(2026, 3, 15, 8)),
            ),
          );

      final estimate = await repository.evaluate(
        nowUtc: DateTime.utc(2026, 3, 15, 12),
        timezoneId: 'UTC',
      );

      final evidence = estimate.toMaintenanceEvidence(
        userId: 'user-456',
        localDate: '2026-03-15',
        timezoneId: 'UTC',
        observedAtUtc: DateTime.utc(2026, 3, 15, 12),
      );

      // Assert B04 contract properties:
      expect(evidence.policyVersion, B04AdaptiveTargetPolicy.current.policyVersion);
      expect(evidence.sourceId, 'adaptive_tdee_engine');
      expect(evidence.sourceVersion, 'adaptive_tdee_v1');
      expect(evidence.historicalSnapshot, isTrue);
      expect(evidence.localDate, '2026-03-15');
      expect(evidence.timezoneId, 'UTC');
      expect(evidence.observedAtUtc, DateTime.utc(2026, 3, 15, 12));
      expect(evidence.energy.state, B04EvidenceState.known);
      expect(evidence.energy.unit, 'kcal/day');
      expect(evidence.energy.point, estimate.currentTdeeKcal.round().toString());
      expect(evidence.energy.lower, evidence.energy.point);
      expect(evidence.energy.upper, evidence.energy.point);
    });

    test('parses activity level strings to correct multipliers', () async {
      // Mifflin-St Jeor for 70kg, 170cm, 25yo male: 10*70 + 6.25*170 - 5*25 + 5 = 1642.5
      const expectedBmr = 1642.5;

      for (final pair in [
        ('sedentary', 1.2),
        ('light', 1.375),
        ('lightly_active', 1.375),
        ('moderate', 1.55),
        ('moderately_active', 1.55),
        ('very_active', 1.725),
        ('heavy', 1.725),
        ('extra_active', 1.9),
        ('athlete', 1.9),
        ('unknown_string', 1.55),
      ]) {
        await database.delete(database.userProfiles).go();
        await database.into(database.userProfiles).insert(
              UserProfilesCompanion.insert(
                age: const Value(25),
                height: const Value(170.0),
                weight: const Value(70.0),
                sex: const Value('male'),
                activityLevel: Value(pair.$1),
              ),
            );

        final estimate = await repository.evaluate(
          nowUtc: DateTime.utc(2026, 3, 15, 12),
          timezoneId: 'UTC',
        );

        final expectedTdee = expectedBmr * pair.$2;
        expect(estimate.baselineTdeeKcal, closeTo(expectedTdee, 0.5));
      }
    });
  });
}
