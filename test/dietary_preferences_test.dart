import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late NutritionConstraintRepository constraints;
  late NutrientRegistry registry;

  setUp(() async {
    db = AppDatabase.memory();
    constraints = NutritionConstraintRepository(
      database: db,
      nowUtc: () => DateTime.utc(2026, 8, 4, 10),
    );
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    await _insertFood(db, 'food-1', 'Same display name');
    await _insertFood(db, 'food-2', 'Same display name');
  });

  tearDown(() => db.close());

  test('creates, lists, archives, and evaluates an owned constraint', () async {
    final saved = await constraints.createUserConstraint(
      userId: 'user-1',
      type: NutritionConstraintType.allergy,
      target: NutritionConstraintTarget(
        type: NutritionConstraintTargetType.allergen,
        id: 'peanut',
      ),
      severity: 'high',
      crossContact: true,
    );
    expect(saved.id, isNotEmpty);
    expect(
      (await constraints.listActiveConstraints(userId: 'user-1')).single.id,
      saved.id,
    );

    await constraints.recordFoodEvidence(
      foodId: 'food-1',
      evidence: NutritionConstraintEvidence(
        id: 'food-1-peanut-v1',
        subjectId: 'food-1',
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'peanut',
        ),
        status: NutritionConstraintEvidenceStatus.confirmed,
        source: NutritionConstraintEvidenceSource.reviewedAllergenDeclaration,
      ),
    );
    final evaluation = await constraints.evaluateFood(
      userId: 'user-1',
      foodId: 'food-1',
    );
    expect(evaluation.outcome, NutritionConstraintOutcome.confirmedConflict);
    expect(evaluation.evaluations.single.type, NutritionConstraintType.allergy);

    final archived = await constraints.archiveConstraint(
      userId: 'user-1',
      constraintId: saved.id,
    );
    expect(archived.isActive, isFalse);
    expect(await constraints.listActiveConstraints(userId: 'user-1'), isEmpty);
    expect(
      (await constraints.listAllConstraints(userId: 'user-1')).single.id,
      saved.id,
    );
  });

  test(
    'duplicate active targets and duplicate portable IDs fail atomically',
    () async {
      final id = 'constraint-stable-id';
      final first = await constraints.createUserConstraint(
        userId: 'user-1',
        id: id,
        type: NutritionConstraintType.intolerance,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.ingredient,
          id: 'lactose',
        ),
      );
      expect(first.id, id);
      await expectLater(
        constraints.createUserConstraint(
          userId: 'user-1',
          type: NutritionConstraintType.intolerance,
          target: NutritionConstraintTarget(
            type: NutritionConstraintTargetType.ingredient,
            id: 'lactose',
          ),
        ),
        throwsA(
          isA<NutritionConstraintConflictError>().having(
            (error) => error.code,
            'code',
            'duplicate_active_constraint',
          ),
        ),
      );
      await expectLater(
        constraints.createUserConstraint(
          userId: 'user-1',
          id: id,
          type: NutritionConstraintType.intolerance,
          target: NutritionConstraintTarget(
            type: NutritionConstraintTargetType.ingredient,
            id: 'gluten',
          ),
        ),
        throwsA(isA<NutritionConstraintConflictError>()),
      );
      expect(
        (await constraints.listAllConstraints(userId: 'user-1')).length,
        1,
      );
    },
  );

  test(
    'duplicate display names retain separate food evidence and identity',
    () async {
      final constraint = await constraints.createUserConstraint(
        userId: 'user-1',
        type: NutritionConstraintType.allergy,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'milk',
        ),
      );
      await constraints.recordFoodEvidence(
        foodId: 'food-1',
        evidence: _evidence(
          id: 'evidence-food-1',
          foodId: 'food-1',
          status: NutritionConstraintEvidenceStatus.confirmed,
        ),
      );
      final first = await constraints.evaluateFood(
        userId: 'user-1',
        foodId: 'food-1',
      );
      final second = await constraints.evaluateFood(
        userId: 'user-1',
        foodId: 'food-2',
      );
      expect(first.outcome, NutritionConstraintOutcome.confirmedConflict);
      expect(
        second.outcome,
        NutritionConstraintOutcome.insufficientInformation,
      );
      expect(first.subjectId, isNot(second.subjectId));
      expect(constraint.target.id, 'milk');
    },
  );

  test(
    'recipe evaluation uses immutable ingredient evidence and rejects drafts',
    () async {
      await db
          .into(db.nutritionRecipes)
          .insert(
            NutritionRecipesCompanion.insert(
              id: 'recipe-1',
              userId: 'user-1',
              name: 'Display name is not evidence',
              lifecycle: 'active',
            ),
          );
      await db
          .into(db.nutritionRecipeVersions)
          .insert(
            NutritionRecipeVersionsCompanion.insert(
              id: 'recipe-v1',
              recipeId: 'recipe-1',
              versionNumber: 1,
              status: 'published',
              calcRuleVersion: 'b03-08-v1',
              source: '{}',
            ),
          );
      await db
          .into(db.nutritionRecipeIngredients)
          .insert(
            NutritionRecipeIngredientsCompanion.insert(
              id: 'line-1',
              recipeVersionId: 'recipe-v1',
              position: 0,
              foodId: 'food-1',
              quantityValue: 100,
              quantityDimension: 'mass',
              quantityUnit: 'gram',
            ),
          );
      await constraints.createUserConstraint(
        userId: 'user-1',
        type: NutritionConstraintType.dietaryPattern,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.foodFamily,
          id: 'vegan',
        ),
      );
      await constraints.recordFoodEvidence(
        foodId: 'food-1',
        evidence: NutritionConstraintEvidence(
          id: 'milk-animal-evidence',
          subjectId: 'food-1',
          target: NutritionConstraintTarget(
            type: NutritionConstraintTargetType.animalProduct,
            id: 'milk',
          ),
          status: NutritionConstraintEvidenceStatus.confirmed,
          source: NutritionConstraintEvidenceSource.recipeIngredientGraph,
          ingredientLineage: 'line-1',
        ),
      );
      final result = await constraints.evaluateRecipeVersion(
        userId: 'user-1',
        recipeVersionId: 'recipe-v1',
      );
      expect(result.outcome, NutritionConstraintOutcome.confirmedConflict);
      expect(result.evaluations.single.affectedComponentIds, ['line-1']);
      expect(result.evaluations.single.evidence.single.foodId, isNull);
      expect(
        result.evaluations.single.evidence.single.ingredientLineage,
        'line-1',
      );

      await db
          .into(db.nutritionRecipeVersions)
          .insert(
            NutritionRecipeVersionsCompanion.insert(
              id: 'recipe-draft',
              recipeId: 'recipe-1',
              versionNumber: 2,
              status: 'draft',
              calcRuleVersion: 'b03-08-v1',
              source: '{}',
            ),
          );
      await expectLater(
        constraints.evaluateRecipeVersion(
          userId: 'user-1',
          recipeVersionId: 'recipe-draft',
        ),
        throwsA(
          isA<NutritionConstraintValidationError>().having(
            (error) => error.code,
            'code',
            'draft_recipe_version',
          ),
        ),
      );
    },
  );

  test(
    'finalization persists evaluation lineage atomically and idempotently',
    () async {
      final constraint = await constraints.createUserConstraint(
        userId: 'user-1',
        type: NutritionConstraintType.allergy,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'peanut',
        ),
        crossContact: true,
      );
      await constraints.recordFoodEvidence(
        foodId: 'food-1',
        evidence: NutritionConstraintEvidence(
          id: 'peanut-evidence',
          subjectId: 'food-1',
          target: NutritionConstraintTarget(
            type: NutritionConstraintTargetType.allergen,
            id: 'peanut',
          ),
          status: NutritionConstraintEvidenceStatus.confirmed,
          source: NutritionConstraintEvidenceSource.reviewedAllergenDeclaration,
        ),
      );
      final evaluation = await constraints.evaluateFood(
        userId: 'user-1',
        foodId: 'food-1',
        acknowledgedConstraintIds: const ['not-the-id'],
      );
      // The acknowledgement list above is intentionally not used to fabricate
      // an ID; the finalization assertion below uses the actual saved identity.
      final cleanEvaluation = await constraints.evaluateFood(
        userId: 'user-1',
        foodId: 'food-1',
        acknowledgedConstraintIds: [constraint.id],
      );
      expect(evaluation.evaluations.single.acknowledged, isFalse);
      expect(cleanEvaluation.evaluations.single.acknowledged, isTrue);
      final acknowledgement = NutritionConstraintAcknowledgement(
        commandId: 'ack-command-1',
        userId: 'user-1',
        evaluationFingerprint: cleanEvaluation.fingerprint,
        constraintId: constraint.id,
        reason: 'I understand this is not a safety guarantee.',
        acknowledgedAtUtc: DateTime.utc(2026, 8, 4, 10),
      );
      expect(
        (await constraints.recordAcknowledgement(
          acknowledgement,
          evaluation: cleanEvaluation,
        )).commandId,
        acknowledgement.commandId,
      );
      expect(
        (await constraints.recordAcknowledgement(
          acknowledgement,
          evaluation: cleanEvaluation,
        )).commandId,
        acknowledgement.commandId,
      );
      final consumption = NutritionConsumptionRepository(
        db: db,
        registry: registry,
        nowUtc: () => DateTime.utc(2026, 8, 4, 10),
      );
      final request = _request(
        calculation: _calculation(registry),
        evaluation: cleanEvaluation,
        acknowledgement: acknowledgement,
      );
      final saved = await consumption.finalizeConsumption(request);
      expect(
        saved.constraintEvaluation!.fingerprint,
        cleanEvaluation.fingerprint,
      );
      expect(saved.constraintAcknowledgement!.commandId, 'ack-command-1');
      expect(
        (await db.select(db.nutritionSnapshotConstraintResults).get()).length,
        1,
      );
      expect(
        (await db.select(db.nutritionSnapshotConstraintResultEvidence).get())
            .map((row) => row.evidenceKind),
        contains('user_override'),
      );
      expect(
        (await db.select(db.nutritionSnapshotConstraintResultEvidence).get())
            .where((row) => row.evidenceKind == 'food')
            .length,
        1,
      );

      final retry = await consumption.finalizeConsumption(request);
      expect(retry.id, saved.id);
      expect(
        (await db.select(db.nutritionSnapshotConstraintResults).get()).length,
        1,
      );
      await (db.update(db.nutritionFoods)
            ..where((table) => table.id.equals('food-1')))
          .write(const NutritionFoodsCompanion(displayName: Value('Renamed')));
      final historical = await consumption.getSnapshot(
        userId: 'user-1',
        consumptionId: saved.id,
      );
      expect(
        historical!.constraintEvaluation!.outcome,
        NutritionConstraintOutcome.confirmedConflict,
      );
      expect(
        historical.constraintEvaluation!.fingerprint,
        cleanEvaluation.fingerprint,
      );
    },
  );

  test(
    'failed constraint graph insertion rolls back the whole snapshot',
    () async {
      final constraint = await constraints.createUserConstraint(
        userId: 'user-1',
        type: NutritionConstraintType.allergy,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'soy',
        ),
      );
      await constraints.recordFoodEvidence(
        foodId: 'food-1',
        evidence: _evidence(
          id: 'soy-evidence',
          foodId: 'food-1',
          status: NutritionConstraintEvidenceStatus.confirmed,
          targetId: 'soy',
        ),
      );
      final evaluation = await constraints.evaluateFood(
        userId: 'user-1',
        foodId: 'food-1',
      );
      final repository = NutritionConsumptionRepository(
        db: db,
        registry: registry,
        failureInjector: (stage) {
          if (stage == 'after_constraints') throw StateError('injected');
        },
      );
      await expectLater(
        repository.finalizeConsumption(
          _request(calculation: _calculation(registry), evaluation: evaluation),
        ),
        throwsA(isA<NutritionConsumptionPersistenceError>()),
      );
      expect(await db.select(db.nutritionConsumptionSnapshots).get(), isEmpty);
      expect(
        await db.select(db.nutritionSnapshotConstraintResults).get(),
        isEmpty,
      );
      expect(constraint.id, isNotEmpty);
    },
  );
}

NutritionConstraintEvidence _evidence({
  required String id,
  required String foodId,
  NutritionConstraintEvidenceStatus status =
      NutritionConstraintEvidenceStatus.confirmed,
  String targetId = 'milk',
}) => NutritionConstraintEvidence(
  id: id,
  subjectId: foodId,
  target: NutritionConstraintTarget(
    type: NutritionConstraintTargetType.allergen,
    id: targetId,
  ),
  status: status,
  source: NutritionConstraintEvidenceSource.userEntered,
);

NutritionConsumptionFinalizeRequest _request({
  required NutritionConsumptionCalculationSnapshot calculation,
  NutritionConstraintEvaluationResult? evaluation,
  NutritionConstraintAcknowledgement? acknowledgement,
}) => NutritionConsumptionFinalizeRequest(
  userId: 'user-1',
  consumptionId: 'constraint-consumption-1',
  commandId: 'constraint-command-1',
  loggedAtUtc: DateTime.utc(2026, 8, 4, 10),
  mealCategory: 'lunch',
  sourceType: 'direct_food',
  localDate: '2026-08-04',
  timezoneId: 'Asia/Kolkata',
  calculatorVersion: 'b03-08-v1',
  items: [
    NutritionConsumptionItemInput(
      id: 'constraint-item-1',
      position: 0,
      sourceType: 'direct_food',
      foodId: 'food-1',
      displayLabel: 'Snapshot label',
      quantity: Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram),
      calculation: calculation,
    ),
  ],
  constraintEvaluation: evaluation,
  constraintAcknowledgement: acknowledgement,
);

NutritionConsumptionCalculationSnapshot _calculation(
  NutrientRegistry registry,
) => NutritionConsumptionCalculationSnapshot.fromFacts(
  facts: {
    'protein': NutrientFact.known(
      nutrientId: 'protein',
      point: NutrientAmount(
        value: QuantityAmount.fromString('10'),
        unit: NutrientUnit.gram,
      ),
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: NutrientSourceType.reviewedCatalogue,
      factVersion: 'food-v1',
    ),
  },
  registry: registry,
  requestedNutrientIds: const ['protein'],
  calculatorVersion: 'b03-08-v1',
  calculationFingerprint: 'calculation-fingerprint-1',
);

Future<void> _insertFood(AppDatabase db, String id, String label) => db
    .into(db.nutritionFoods)
    .insert(
      NutritionFoodsCompanion.insert(
        id: id,
        kind: 'userCreated',
        displayName: label,
        locale: 'en-IN',
        sourceType: 'user',
        lifecycle: 'active',
      ),
    );
