import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/raw_cooked_transformations.dart';
import '../../core/typed_quantities.dart';
import '../database/app_database.dart';

/// Single durable owner for reviewed and user-scoped raw/cooked
/// transformations. It deliberately does not calculate nutrients or mutate
/// legacy food logs.
class NutritionTransformationRepository {
  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  NutritionTransformationRepository({
    required AppDatabase db,
    Uuid? uuid,
    DateTime Function()? nowUtc,
  }) : _db = db,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  Future<NutritionTransformation?> getById(String id) async {
    final row = await (_db.select(
      _db.nutritionQuantityConversions,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<NutritionTransformation>> findForSource({
    required String sourceFoodId,
    String? sourcePreparationId,
  }) async {
    final rows =
        await (_db.select(_db.nutritionQuantityConversions)
              ..where((table) => table.foodId.equals(sourceFoodId))
              ..orderBy([(table) => OrderingTerm(expression: table.id)]))
            .get();
    final result = <NutritionTransformation>[];
    for (final row in rows) {
      if (_isArchived(row)) continue;
      final transformation = _fromRow(row);
      if (transformation.sourcePreparationId != sourcePreparationId) {
        continue;
      }
      result.add(transformation);
    }
    return result;
  }

  Future<NutritionTransformation?> findExplicit({
    required String sourceFoodId,
    String? sourcePreparationId,
    required String targetFoodId,
    String? targetPreparationId,
    required QuantityUnit sourceUnit,
    required QuantityUnit targetUnit,
    String? ruleVersion,
  }) async {
    final candidates = await findForSource(
      sourceFoodId: sourceFoodId,
      sourcePreparationId: sourcePreparationId,
    );
    for (final candidate in candidates) {
      if (candidate.targetFoodId == targetFoodId &&
          candidate.targetPreparationId == targetPreparationId &&
          candidate.sourceUnit == sourceUnit &&
          candidate.targetUnit == targetUnit &&
          (ruleVersion == null || candidate.ruleVersion == ruleVersion)) {
        return candidate;
      }
    }
    return null;
  }

  Future<NutritionTransformation> saveReviewed(
    NutritionTransformation transformation,
  ) async {
    if (transformation.reviewState !=
            NutritionTransformationReviewState.reviewed ||
        transformation.isUserOwned) {
      throw const TransformationPersistenceError(
        'Only non-user-owned reviewed transformations may use saveReviewed.',
      );
    }
    return _insert(transformation, ownerScope: 'catalogue');
  }

  Future<NutritionTransformation> createUserOverride(
    NutritionTransformation transformation,
  ) async {
    if (!transformation.isUserOwned ||
        transformation.reviewState !=
            NutritionTransformationReviewState.userOverride) {
      throw const TransformationPersistenceError(
        'User overrides require user-owned user_override provenance.',
      );
    }
    return _insert(transformation, ownerScope: 'user');
  }

  Future<NutritionTransformation> versionUserOverride({
    required String supersedesId,
    required NutritionTransformation replacement,
  }) async {
    final previous = await getById(supersedesId);
    if (previous == null || !previous.isUserOwned) {
      throw const TransformationPersistenceError(
        'Only an existing user transformation can be versioned.',
      );
    }
    if (replacement.supersedesId != supersedesId) {
      throw const TransformationPersistenceError(
        'Replacement transformation must name its superseded version.',
      );
    }
    return createUserOverride(replacement);
  }

  Future<void> archiveUserOverride(String id) async {
    final existing = await getById(id);
    if (existing == null) {
      throw const TransformationPersistenceError(
        'Transformation to archive was not found.',
      );
    }
    if (!existing.isUserOwned) {
      throw const TransformationPersistenceError(
        'Reviewed catalogue transformations cannot be archived as user rows.',
      );
    }
    final archived = existing.copyWith(
      reviewState: NutritionTransformationReviewState.archived,
    );
    final changed =
        await (_db.update(
          _db.nutritionQuantityConversions,
        )..where((table) => table.id.equals(id))).write(
          NutritionQuantityConversionsCompanion(
            source: Value(archived.storageSource),
            updatedAt: Value(_nowUtc()),
          ),
        );
    if (changed != 1) {
      throw const TransformationPersistenceError(
        'Archiving the transformation did not update exactly one row.',
      );
    }
  }

  Future<NutritionTransformation> _insert(
    NutritionTransformation transformation, {
    required String ownerScope,
  }) async {
    await _validateIdentityReferences(transformation);
    final existing = await getById(transformation.id);
    if (existing != null) {
      throw const TransformationPersistenceError(
        'A transformation with this portable ID already exists.',
      );
    }
    try {
      // Schema-v17 predates nullable conversion factors. Keep a deterministic
      // positive storage anchor for SQLite's legacy NOT NULL column, while
      // the provenance envelope records that no point exists. The read path
      // restores the typed range-only state and never exposes the anchor as
      // an exact point estimate.
      final storageFactor =
          transformation.yieldRange.point?.asDouble ??
          transformation.yieldRange.lower?.asDouble ??
          transformation.yieldRange.upper!.asDouble;
      await _db
          .into(_db.nutritionQuantityConversions)
          .insert(
            NutritionQuantityConversionsCompanion.insert(
              id: transformation.id.isEmpty ? _uuid.v4() : transformation.id,
              foodId: transformation.sourceFoodId,
              preparationId: Value(transformation.sourcePreparationId),
              sourceUnit: QuantityUnitRegistry.definitionFor(
                transformation.sourceUnit,
              ).stableId,
              targetUnit: QuantityUnitRegistry.definitionFor(
                transformation.targetUnit,
              ).stableId,
              factor: storageFactor,
              lower: Value(transformation.yieldRange.lower?.asDouble),
              upper: Value(transformation.yieldRange.upper?.asDouble),
              method: transformation.method.stableId,
              source: transformation.storageSource,
              confidence: Value(transformation.confidence),
              ruleVersion: transformation.ruleVersion,
              ownerScope: ownerScope,
              createdAt: Value(_nowUtc()),
              updatedAt: Value(_nowUtc()),
            ),
          );
    } on Exception catch (error) {
      throw TransformationPersistenceError(
        'Transformation insert failed: $error',
      );
    }
    return (await getById(transformation.id))!;
  }

  Future<void> _validateIdentityReferences(
    NutritionTransformation transformation,
  ) async {
    Future<void> requireFood(String id, String label) async {
      final row = await (_db.select(
        _db.nutritionFoods,
      )..where((table) => table.id.equals(id))).getSingleOrNull();
      if (row == null) {
        throw TransformationPersistenceError(
          '$label food identity $id is not present.',
        );
      }
    }

    Future<void> requirePreparation(
      String id,
      String foodId,
      NutritionPreparationState expectedState,
      String label,
    ) async {
      final row = await (_db.select(
        _db.nutritionFoodPreparations,
      )..where((table) => table.id.equals(id))).getSingleOrNull();
      if (row == null || row.foodId != foodId) {
        throw TransformationPersistenceError(
          '$label preparation identity $id is not linked to $foodId.',
        );
      }
      final actualState = NutritionPreparationStateContract.fromStableId(
        row.state,
      );
      if (actualState != expectedState) {
        throw TransformationPersistenceError(
          '$label preparation identity $id has state ${row.state}, not ${expectedState.stableId}.',
        );
      }
    }

    await requireFood(transformation.sourceFoodId, 'Source');
    await requireFood(transformation.targetFoodId, 'Target');
    if (transformation.sourcePreparationId != null) {
      await requirePreparation(
        transformation.sourcePreparationId!,
        transformation.sourceFoodId,
        transformation.sourceState,
        'Source',
      );
    }
    if (transformation.targetPreparationId != null) {
      await requirePreparation(
        transformation.targetPreparationId!,
        transformation.targetFoodId,
        transformation.targetState,
        'Target',
      );
    }
  }

  NutritionTransformation _fromRow(NutritionQuantityConversion row) {
    try {
      final metadata = jsonDecode(row.source);
      if (metadata is! Map ||
          metadata['contract_version'] !=
              kNutritionTransformationContractVersion) {
        throw const TransformationPersistenceError(
          'Transformation provenance envelope is unsupported.',
        );
      }
      final sourcePreparationId = metadata['source_preparation_id'];
      final targetPreparationId = metadata['target_preparation_id'];
      if (sourcePreparationId is! String? && sourcePreparationId != null ||
          targetPreparationId is! String? && targetPreparationId != null) {
        throw const TransformationPersistenceError(
          'Transformation preparation identity is malformed.',
        );
      }
      final source = NutritionTransformationSourceContract.fromStableId(
        metadata['source'] as String,
      );
      final reviewState =
          NutritionTransformationReviewStateContract.fromStableId(
            metadata['review_state'] as String,
          );
      final transformation = NutritionTransformation(
        id: row.id,
        sourceFoodId: row.foodId,
        sourcePreparationId: sourcePreparationId as String?,
        sourceState: NutritionPreparationStateContract.fromStableId(
          metadata['source_state'] as String,
        ),
        targetFoodId: metadata['target_food_id'] as String,
        targetPreparationId: targetPreparationId as String?,
        targetState: NutritionPreparationStateContract.fromStableId(
          metadata['target_state'] as String,
        ),
        sourceUnit: QuantityUnitRegistry.fromStableId(row.sourceUnit).unit,
        targetUnit: QuantityUnitRegistry.fromStableId(row.targetUnit).unit,
        yieldRange: TransformationRange(
          lower: row.lower == null ? null : QuantityAmount.fromNum(row.lower!),
          point: metadata['point_available'] == false
              ? null
              : QuantityAmount.fromNum(row.factor),
          upper: row.upper == null ? null : QuantityAmount.fromNum(row.upper!),
        ),
        direction: nutritionTransformationDirectionFromStableId(
          metadata['direction'],
        ),
        method: NutritionPreparationMethodContract.fromStableId(row.method),
        source: source,
        reviewState: reviewState,
        evidence: metadata['evidence'] as String,
        ruleVersion: row.ruleVersion,
        confidence: row.confidence,
        densityContextId: metadata['density_context_id'] as String?,
        supersedesId: metadata['supersedes_id'] as String?,
      );
      if (row.ownerScope == 'user' && !transformation.isUserOwned) {
        throw const TransformationPersistenceError(
          'User-owned conversion row is missing user provenance.',
        );
      }
      if (row.ownerScope == 'catalogue' && transformation.isUserOwned) {
        throw const TransformationPersistenceError(
          'Catalogue conversion row cannot carry user provenance.',
        );
      }
      return transformation;
    } on NutritionTransformationError {
      rethrow;
    } on Object catch (error) {
      throw TransformationPersistenceError(
        'Transformation row ${row.id} is malformed: $error',
      );
    }
  }

  bool _isArchived(NutritionQuantityConversion row) {
    try {
      final metadata = jsonDecode(row.source);
      return metadata is Map && metadata['review_state'] == 'archived';
    } on Object {
      return false;
    }
  }
}
