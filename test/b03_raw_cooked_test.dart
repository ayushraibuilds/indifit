import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v8.dart';
import 'package:indifit/core/raw_cooked_transformations.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B03-09 raw/cooked transformation contract', () {
    test('stable states and methods reject unsupported values', () {
      expect(
        NutritionPreparationStateContract.fromStableId('raw'),
        NutritionPreparationState.raw,
      );
      expect(
        NutritionPreparationMethodContract.fromStableId('pressure_cooked'),
        NutritionPreparationMethod.pressureCooked,
      );
      expect(
        () => NutritionPreparationStateContract.fromStableId('sautéed'),
        throwsA(isA<UnsupportedPreparationStateError>()),
      );
      expect(
        () => NutritionPreparationMethodContract.fromStableId('guess'),
        throwsA(isA<UnsupportedPreparationStateError>()),
      );
    });

    test('reviewed transformation is directional and rename-stable', () {
      final transformation = _transformation();
      final roundTrip = NutritionTransformation.fromJson(
        jsonDecode(jsonEncode(transformation.toJson())),
      );

      expect(roundTrip.id, 'transform-rice-v1');
      expect(roundTrip.sourceFoodId, 'food-rice-raw');
      expect(roundTrip.targetFoodId, 'food-rice-cooked');
      expect(roundTrip.sourceState, NutritionPreparationState.raw);
      expect(roundTrip.targetState, NutritionPreparationState.cooked);
      expect(roundTrip.method, NutritionPreparationMethod.boiled);
      expect(
        jsonEncode(roundTrip.toJson()),
        jsonEncode(transformation.toJson()),
      );
      // The portable ID is an explicit reviewed value; it is not regenerated
      // from a display label during serialization or maintenance.
      expect(roundTrip.id, transformation.id);
    });

    test(
      'yield uses output divided by input and supports factors below one',
      () {
        final shrinking = _transformation(
          id: 'transform-meat-v1',
          yieldRange: _range(point: '0.72'),
        );
        final growing = _transformation(
          id: 'transform-rice-v1',
          yieldRange: _range(point: '2.5'),
        );

        final shrinkResult =
            NutritionTransformationService.apply(
                  transformation: shrinking,
                  sourceFoodId: shrinking.sourceFoodId,
                  sourcePreparationId: shrinking.sourcePreparationId,
                  input: Quantity.fromDecimal(
                    amount: '100',
                    unit: QuantityUnit.gram,
                  ),
                )
                as NutritionTransformationApplied;
        final growResult =
            NutritionTransformationService.apply(
                  transformation: growing,
                  sourceFoodId: growing.sourceFoodId,
                  sourcePreparationId: growing.sourcePreparationId,
                  input: Quantity.fromDecimal(
                    amount: '100',
                    unit: QuantityUnit.gram,
                  ),
                )
                as NutritionTransformationApplied;

        expect(shrinkResult.point!.amount.toString(), '72');
        expect(growResult.point!.amount.toString(), '250');
        expect(
          shrinkResult.lineage.direction,
          NutritionTransformationDirection.forward,
        );
      },
    );

    test('range-only transformations remain ranges and are not collapsed', () {
      final transformation = _transformation(
        id: 'transform-pulse-range-v1',
        yieldRange: _range(lower: '2.1', upper: '2.9'),
      );

      final result =
          NutritionTransformationService.apply(
                transformation: transformation,
                sourceFoodId: transformation.sourceFoodId,
                sourcePreparationId: transformation.sourcePreparationId,
                input: Quantity.fromDecimal(
                  amount: '100',
                  unit: QuantityUnit.gram,
                ),
              )
              as NutritionTransformationApplied;

      expect(result.isRangeOnly, isTrue);
      expect(result.point, isNull);
      expect(result.lower!.amount.toString(), '210');
      expect(result.upper!.amount.toString(), '290');
    });

    test('invalid yields and bounds fail without clamping', () {
      expect(
        () => _transformation(yieldRange: _range(point: '0')),
        throwsA(isA<InvalidTransformationError>()),
      );
      expect(
        () => _transformation(
          yieldRange: _range(point: '1', upper: '0.9'),
        ),
        throwsA(isA<InvalidTransformationError>()),
      );
      expect(
        () => _transformation(
          yieldRange: TransformationRange(
            lower: QuantityAmount.fromString('2'),
            upper: QuantityAmount.fromString('1'),
          ),
        ),
        throwsA(isA<InvalidTransformationError>()),
      );
      expect(
        () => _transformation(
          yieldRange: TransformationRange(
            point: QuantityAmount.fromNum(double.infinity),
          ),
        ),
        throwsA(isA<QuantityError>()),
      );
    });

    test('cross-dimension transformations require explicit context', () {
      final unresolved = _transformation(targetUnit: QuantityUnit.millilitre);
      final missing =
          NutritionTransformationService.apply(
                transformation: unresolved,
                sourceFoodId: unresolved.sourceFoodId,
                sourcePreparationId: unresolved.sourcePreparationId,
                input: Quantity.fromDecimal(
                  amount: '100',
                  unit: QuantityUnit.gram,
                ),
              )
              as NutritionTransformationUnresolved;
      expect(missing.code, 'missing_density_context');

      final explicit = _transformation(
        targetUnit: QuantityUnit.millilitre,
        densityContextId: 'reviewed-density-rice-v1',
      );
      final converted =
          NutritionTransformationService.apply(
                transformation: explicit,
                sourceFoodId: explicit.sourceFoodId,
                sourcePreparationId: explicit.sourcePreparationId,
                input: Quantity.fromDecimal(
                  amount: '100',
                  unit: QuantityUnit.gram,
                ),
              )
              as NutritionTransformationApplied;
      expect(converted.point!.unit, QuantityUnit.millilitre);
      expect(converted.point!.amount.toString(), '250');
    });

    test('identity is explicit and names never determine applicability', () {
      final transformation = _transformation();
      expect(
        () => NutritionTransformationService.apply(
          transformation: transformation,
          sourceFoodId: 'same-looking-rice-name',
          sourcePreparationId: transformation.sourcePreparationId,
          input: Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram),
        ),
        throwsA(isA<TransformationIdentityMismatchError>()),
      );
      expect(
        () => NutritionTransformationService.apply(
          transformation: transformation,
          sourceFoodId: transformation.sourceFoodId,
          sourcePreparationId: transformation.sourcePreparationId,
          input: Quantity.fromDecimal(
            amount: '100',
            unit: QuantityUnit.millilitre,
          ),
        ),
        throwsA(isA<IncompatibleQuantityDimensionError>()),
      );
    });

    test(
      'zero input is rejected and unresolved transformations stay visible',
      () {
        final transformation = _transformation();
        expect(
          () => NutritionTransformationService.apply(
            transformation: transformation,
            sourceFoodId: transformation.sourceFoodId,
            sourcePreparationId: transformation.sourcePreparationId,
            input: Quantity.fromDecimal(amount: '0', unit: QuantityUnit.gram),
          ),
          throwsA(isA<InvalidTransformationInputError>()),
        );

        final unresolved = _transformation(
          sourceState: NutritionPreparationState.unknown,
          reviewState: NutritionTransformationReviewState.unresolved,
          source: NutritionTransformationSource.unknown,
        );
        final result =
            NutritionTransformationService.apply(
                  transformation: unresolved,
                  sourceFoodId: unresolved.sourceFoodId,
                  sourcePreparationId: unresolved.sourcePreparationId,
                  input: Quantity.fromDecimal(
                    amount: '100',
                    unit: QuantityUnit.gram,
                  ),
                )
                as NutritionTransformationUnresolved;
        expect(result.code, 'unresolved_transformation');
      },
    );

    test('inverse conversion requires an explicit inverse record', () {
      final forward = _transformation();
      expect(
        () => NutritionTransformationService.apply(
          transformation: forward,
          sourceFoodId: forward.sourceFoodId,
          sourcePreparationId: forward.sourcePreparationId,
          input: Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram),
          direction: NutritionTransformationDirection.inverse,
        ),
        throwsA(isA<UnsupportedInverseTransformationError>()),
      );

      final inverse = _transformation(
        id: 'transform-rice-v1-inverse',
        sourceFoodId: 'food-rice-cooked',
        sourcePreparationId: 'prep-cooked',
        sourceState: NutritionPreparationState.cooked,
        targetFoodId: 'food-rice-raw',
        targetPreparationId: 'prep-raw',
        targetState: NutritionPreparationState.raw,
        yieldRange: _range(point: '0.4'),
        direction: NutritionTransformationDirection.inverse,
      );
      final result =
          NutritionTransformationService.apply(
                transformation: inverse,
                sourceFoodId: 'food-rice-cooked',
                sourcePreparationId: 'prep-cooked',
                input: Quantity.fromDecimal(
                  amount: '250',
                  unit: QuantityUnit.gram,
                ),
                direction: NutritionTransformationDirection.inverse,
              )
              as NutritionTransformationApplied;

      expect(result.point!.amount.toString(), '100');
      expect(
        result.lineage.direction,
        NutritionTransformationDirection.inverse,
      );
    });

    test('unknown inverse is not synthesized by the service', () {
      expect(
        () => _transformation(
          id: 'invalid-unknown',
          sourceState: NutritionPreparationState.unknown,
          reviewState: NutritionTransformationReviewState.reviewed,
        ),
        throwsA(isA<InvalidTransformationError>()),
      );
    });
  });

  group('B03-09 transformation repository', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.memory();
      await _insertUserFood(db, 'user-rice');
      await db
          .into(db.nutritionFoodPreparations)
          .insert(
            NutritionFoodPreparationsCompanion.insert(
              id: 'user-rice-raw',
              foodId: 'user-rice',
              state: 'raw',
              source: 'user',
              version: '1',
            ),
          );
      await db
          .into(db.nutritionFoodPreparations)
          .insert(
            NutritionFoodPreparationsCompanion.insert(
              id: 'user-rice-cooked',
              foodId: 'user-rice',
              state: 'cooked',
              source: 'user',
              version: '1',
            ),
          );
    });

    tearDown(() => db.close());

    test('user overrides are versioned, separate, and archiveable', () async {
      final repository = NutritionTransformationRepository(
        db: db,
        nowUtc: () => DateTime.utc(2026, 1, 1),
      );
      final first = _transformation(
        id: 'user-transform-v1',
        sourceFoodId: 'user-rice',
        sourcePreparationId: 'user-rice-raw',
        targetFoodId: 'user-rice',
        targetPreparationId: 'user-rice-cooked',
        source: NutritionTransformationSource.userMeasured,
        reviewState: NutritionTransformationReviewState.userOverride,
      );
      await repository.createUserOverride(first);
      expect(await repository.getById(first.id), isNotNull);

      final replacement = first.copyWith(
        id: 'user-transform-v2',
        ruleVersion: 'user-rule-v2',
        supersedesId: first.id,
        yieldRange: _range(point: '2.6'),
      );
      await repository.versionUserOverride(
        supersedesId: first.id,
        replacement: replacement,
      );
      await repository.archiveUserOverride(first.id);

      expect((await repository.getById(first.id))!.isArchived, isTrue);
      expect(
        await repository.findExplicit(
          sourceFoodId: 'user-rice',
          sourcePreparationId: 'user-rice-raw',
          targetFoodId: 'user-rice',
          targetPreparationId: 'user-rice-cooked',
          sourceUnit: QuantityUnit.gram,
          targetUnit: QuantityUnit.gram,
          ruleVersion: 'user-rule-v2',
        ),
        isNotNull,
      );
    });

    test(
      'preparation identity and state are validated on persistence',
      () async {
        final repository = NutritionTransformationRepository(db: db);
        final invalid = _transformation(
          id: 'invalid-preparation-state',
          sourceFoodId: 'user-rice',
          sourcePreparationId: 'user-rice-cooked',
          targetFoodId: 'user-rice',
          targetPreparationId: 'user-rice-raw',
          source: NutritionTransformationSource.userMeasured,
          reviewState: NutritionTransformationReviewState.userOverride,
        );

        expect(
          () => repository.createUserOverride(invalid),
          throwsA(isA<TransformationPersistenceError>()),
        );
      },
    );

    test(
      'Backup-v8 preserves user-owned transformation identity and provenance',
      () async {
        final repository = NutritionTransformationRepository(db: db);
        final transformation = _transformation(
          id: 'backup-transform-v1',
          sourceFoodId: 'user-rice',
          sourcePreparationId: 'user-rice-raw',
          targetFoodId: 'user-rice',
          targetPreparationId: 'user-rice-cooked',
          source: NutritionTransformationSource.userEstimated,
          reviewState: NutritionTransformationReviewState.userOverride,
          yieldRange: _range(lower: '2.1', point: '2.5', upper: '2.9'),
        );
        await repository.createUserOverride(transformation);

        final sourceBackup = await BackupV8Data.createFromDatabase(db);
        final encoded = jsonEncode(sourceBackup.toJson());
        final decoded = BackupV8Data.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );
        final target = AppDatabase.memory();
        try {
          await decoded.restoreToDatabase(target);
          final restored = await NutritionTransformationRepository(
            db: target,
          ).getById(transformation.id);
          expect(restored, isNotNull);
          expect(restored!.direction, transformation.direction);
          expect(
            jsonEncode(restored.toJson()),
            jsonEncode(transformation.toJson()),
          );
        } finally {
          await target.close();
        }
      },
    );

    test('pure conversion does not mutate food-log storage', () async {
      final before = await db.select(db.foodLogs).get();
      final transformation = _transformation();
      NutritionTransformationService.apply(
        transformation: transformation,
        sourceFoodId: transformation.sourceFoodId,
        sourcePreparationId: transformation.sourcePreparationId,
        input: Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram),
      );
      expect(await db.select(db.foodLogs).get(), before);
    });
  });
}

NutritionTransformation _transformation({
  String id = 'transform-rice-v1',
  String sourceFoodId = 'food-rice-raw',
  String? sourcePreparationId = 'prep-raw',
  NutritionPreparationState sourceState = NutritionPreparationState.raw,
  String targetFoodId = 'food-rice-cooked',
  String? targetPreparationId = 'prep-cooked',
  NutritionPreparationState targetState = NutritionPreparationState.cooked,
  QuantityUnit sourceUnit = QuantityUnit.gram,
  QuantityUnit targetUnit = QuantityUnit.gram,
  TransformationRange? yieldRange,
  NutritionTransformationDirection direction =
      NutritionTransformationDirection.forward,
  NutritionPreparationMethod method = NutritionPreparationMethod.boiled,
  NutritionTransformationSource source =
      NutritionTransformationSource.reviewedCatalogue,
  NutritionTransformationReviewState reviewState =
      NutritionTransformationReviewState.reviewed,
  String? densityContextId,
}) {
  return NutritionTransformation(
    id: id,
    sourceFoodId: sourceFoodId,
    sourcePreparationId: sourcePreparationId,
    sourceState: sourceState,
    targetFoodId: targetFoodId,
    targetPreparationId: targetPreparationId,
    targetState: targetState,
    sourceUnit: sourceUnit,
    targetUnit: targetUnit,
    yieldRange: yieldRange ?? _range(point: '2.5'),
    direction: direction,
    method: method,
    source: source,
    reviewState: reviewState,
    evidence: 'reviewed fixture evidence',
    ruleVersion: 'rule-v1',
    confidence: 0.9,
    densityContextId: densityContextId,
  );
}

TransformationRange _range({String? lower, String? point, String? upper}) {
  return TransformationRange(
    lower: lower == null ? null : QuantityAmount.fromString(lower),
    point: point == null ? null : QuantityAmount.fromString(point),
    upper: upper == null ? null : QuantityAmount.fromString(upper),
  );
}

Future<void> _insertUserFood(AppDatabase db, String id) async {
  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: id,
          kind: 'userCreated',
          displayName: 'User food $id',
          locale: 'en-IN',
          sourceType: 'user',
          lifecycle: 'active',
        ),
      );
}
