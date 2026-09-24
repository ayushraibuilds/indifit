import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/adaptive_tdee_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  group('QuickAddMacros & TDEE Down-weighting Invariants', () {
    late AppDatabase db;
    late NutrientRegistry registry;
    late NutritionConsumptionRepository repository;
    final dates = LocalScheduleDateService();
    const timezoneId = 'Asia/Kolkata';

    NutrientFact knownFact(String nutrientId, double amount, NutrientUnit unit, [String ref = 'quick_add']) {
      return NutrientFact.known(
        nutrientId: nutrientId,
        point: NutrientAmount(
          value: QuantityAmount.fromString(amount.toStringAsFixed(1)),
          unit: unit,
        ),
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: NutrientSourceType.userEntered,
        sourceReference: ref,
        factVersion: '1',
      );
    }

    NutrientFact missingFact(String nutrientId, NutrientUnit unit, [String ref = 'quick_add']) {
      return NutrientFact.missing(
        nutrientId: nutrientId,
        unit: unit,
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: NutrientSourceType.userEntered,
        sourceReference: ref,
        factVersion: '1',
      );
    }

    setUp(() async {
      final scope = registerTestDatabaseScope();
      db = scope.create();
      registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      repository = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );
    });

    Future<void> insertFood(String id, String label) async {
      await db.into(db.nutritionFoods).insert(
            NutritionFoodsCompanion.insert(
              id: id,
              kind: 'userCreated',
              displayName: label,
              locale: 'en-IN',
              sourceType: 'user',
              lifecycle: 'active',
            ),
            mode: InsertMode.insertOrReplace,
          );
    }

    test('quick-add snapshot preserves unentered macros as missing (—), never 0.0', () async {
      final now = DateTime.utc(2026, 8, 4, 12, 0);
      final localDate = dates.localDateFor(now, timezoneId);

      // User enters only 520 kcal and 30g protein. Carbs, fat, fiber are omitted.
      final facts = <String, NutrientFact>{};
      facts['energy'] = knownFact('energy', 520.0, NutrientUnit.kilocalorie);
      facts['protein'] = knownFact('protein', 30.0, NutrientUnit.gram);
      facts['carbohydrate'] = missingFact('carbohydrate', NutrientUnit.gram);
      facts['fat'] = missingFact('fat', NutrientUnit.gram);
      facts['fibre'] = missingFact('fibre', NutrientUnit.gram);

      for (final def in registry.definitions) {
        if (!facts.containsKey(def.id)) {
          facts[def.id] = missingFact(def.id, def.unit);
        }
      }

      final calcSnapshot = NutritionConsumptionCalculationSnapshot.fromFacts(
        facts: facts,
        registry: registry,
        requestedNutrientIds: const ['energy', 'protein', 'carbohydrate', 'fat', 'fibre'],
        calculatorVersion: 'quick_add_v1',
        calculationFingerprint: 'quick_add_test_fp',
      );

      const foodId = 'food::quick_add::1';
      await insertFood(foodId, 'Quick Lunch');

      final item = NutritionConsumptionItemInput(
        id: 'test-qa-consumption::item::0',
        position: 0,
        sourceType: 'quick_add',
        foodId: foodId,
        displayLabel: 'Quick Lunch',
        quantity: Quantity.fromDecimal(amount: '1', unit: QuantityUnit.piece),
        calculation: calcSnapshot,
      );

      final snapshot = await repository.finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: kLocalNutritionUserScopeId,
          consumptionId: 'test-qa-consumption-1',
          commandId: 'cmd-qa-1',
          loggedAtUtc: now,
          localDate: localDate,
          timezoneId: timezoneId,
          mealCategory: 'lunch',
          sourceType: 'quick_add',
          calculatorVersion: 'quick_add_v1',
          items: [item],
          evidence: {'quick_add': true},
        ),
      );

      expect(snapshot.sourceType, 'quick_add');
      expect(snapshot.totals.facts['energy']?.point?.value.asDouble, 520.0);
      expect(snapshot.totals.facts['protein']?.point?.value.asDouble, 30.0);

      // Invariant Check: Omitted macros MUST have status == missing, NOT knownZero (0.0)
      final carbsFact = snapshot.totals.facts['carbohydrate'];
      expect(carbsFact?.status, NutrientFactStatus.missing);
      expect(carbsFact?.point, isNull);
      expect(carbsFact?.isAvailable, isFalse);

      final fatFact = snapshot.totals.facts['fat'];
      expect(fatFact?.status, NutrientFactStatus.missing);
      expect(fatFact?.point, isNull);
      expect(fatFact?.isAvailable, isFalse);
    });

    test('days with >40% quick-add calories are down-weighted (intakeWeight = 0.5) in AdaptiveTdeeRepository', () async {
      final now = DateTime.utc(2026, 8, 4, 12, 0);
      final localDate = dates.localDateFor(now, timezoneId);

      // 1. Log a verified direct food of 400 kcal
      final directFacts = <String, NutrientFact>{};
      for (final def in registry.definitions) {
        if (def.id == 'energy') {
          directFacts[def.id] = knownFact('energy', 400.0, NutrientUnit.kilocalorie, 'direct_food');
        } else {
          directFacts[def.id] = missingFact(def.id, def.unit, 'direct_food');
        }
      }
      final directCalc = NutritionConsumptionCalculationSnapshot.fromFacts(
        facts: directFacts,
        registry: registry,
        requestedNutrientIds: const ['energy'],
        calculatorVersion: 'test_v1',
        calculationFingerprint: 'direct_fp',
      );
      const directFoodId = 'food::direct::1';
      await insertFood(directFoodId, 'Oatmeal');

      await repository.finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: kLocalNutritionUserScopeId,
          consumptionId: 'direct-c-1',
          commandId: 'cmd-direct-1',
          loggedAtUtc: now,
          localDate: localDate,
          timezoneId: timezoneId,
          mealCategory: 'breakfast',
          sourceType: 'direct_food',
          calculatorVersion: 'test_v1',
          items: [
            NutritionConsumptionItemInput(
              id: 'direct-c-1::item::0',
              position: 0,
              sourceType: 'direct_food',
              foodId: directFoodId,
              displayLabel: 'Oatmeal',
              quantity: Quantity.fromDecimal(amount: '1', unit: QuantityUnit.piece),
              calculation: directCalc,
            ),
          ],
        ),
      );

      // 2. Log a quick-add of 600 kcal (>40% of the 1000 kcal daily total, exactly 60%)
      final qaFacts = <String, NutrientFact>{};
      for (final def in registry.definitions) {
        if (def.id == 'energy') {
          qaFacts[def.id] = knownFact('energy', 600.0, NutrientUnit.kilocalorie, 'quick_add');
        } else {
          qaFacts[def.id] = missingFact(def.id, def.unit, 'quick_add');
        }
      }
      final qaCalc = NutritionConsumptionCalculationSnapshot.fromFacts(
        facts: qaFacts,
        registry: registry,
        requestedNutrientIds: const ['energy'],
        calculatorVersion: 'quick_add_v1',
        calculationFingerprint: 'qa_fp_2',
      );
      const qaFoodId = 'food::qa::2';
      await insertFood(qaFoodId, 'Restaurant Biryani');

      await repository.finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: kLocalNutritionUserScopeId,
          consumptionId: 'qa-c-2',
          commandId: 'cmd-qa-2',
          loggedAtUtc: now,
          localDate: localDate,
          timezoneId: timezoneId,
          mealCategory: 'lunch',
          sourceType: 'quick_add',
          calculatorVersion: 'quick_add_v1',
          items: [
            NutritionConsumptionItemInput(
              id: 'qa-c-2::item::0',
              position: 0,
              sourceType: 'quick_add',
              foodId: qaFoodId,
              displayLabel: 'Restaurant Biryani',
              quantity: Quantity.fromDecimal(amount: '1', unit: QuantityUnit.piece),
              calculation: qaCalc,
            ),
          ],
        ),
      );

      // Add a scale weight so dynamic balance can run
      await db.into(db.bodyMeasurements).insert(
        BodyMeasurementsCompanion.insert(
          recordedAt: Value(now),
          weight: const Value(75.0),
        ),
      );

      // Evaluate TDEE
      final tdeeRepo = AdaptiveTdeeRepository(
        db,
        dates: dates,
      );

      final estimate = await tdeeRepo.evaluate(
        nowUtc: now,
        timezoneId: timezoneId,
      );

      expect(estimate.history, isNotEmpty);
      final todayOutput = estimate.history.singleWhere((d) => d.localDate == localDate);
      expect(todayOutput.hasObservedIntake, isTrue);
      expect(todayOutput.isPartial, isTrue);
      expect(todayOutput.intakeWeight, 0.5);
    });
  });
}
