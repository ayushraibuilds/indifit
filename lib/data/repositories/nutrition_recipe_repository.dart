import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/typed_quantities.dart';
import '../database/app_database.dart';

const int kNutritionRecipeContractVersion = 1;

enum NutritionRecipeLifecycle { active, archived, deleted }

extension NutritionRecipeLifecycleValue on NutritionRecipeLifecycle {
  String get stableId => switch (this) {
    NutritionRecipeLifecycle.active => 'active',
    NutritionRecipeLifecycle.archived => 'archived',
    NutritionRecipeLifecycle.deleted => 'deleted',
  };
}

enum NutritionRecipeVersionStatus { draft, published, archived }

extension NutritionRecipeVersionStatusValue on NutritionRecipeVersionStatus {
  String get stableId => switch (this) {
    NutritionRecipeVersionStatus.draft => 'draft',
    NutritionRecipeVersionStatus.published => 'published',
    NutritionRecipeVersionStatus.archived => 'archived',
  };
}

enum NutritionRecipeSourceKind {
  userAuthored,
  duplicated,
  substituted,
  imported,
  unknown,
}

extension NutritionRecipeSourceKindValue on NutritionRecipeSourceKind {
  String get stableId => switch (this) {
    NutritionRecipeSourceKind.userAuthored => 'user_authored',
    NutritionRecipeSourceKind.duplicated => 'duplicated',
    NutritionRecipeSourceKind.substituted => 'substituted',
    NutritionRecipeSourceKind.imported => 'imported',
    NutritionRecipeSourceKind.unknown => 'unknown',
  };

  static NutritionRecipeSourceKind fromStableId(String value) =>
      switch (value) {
        'user_authored' => NutritionRecipeSourceKind.userAuthored,
        'duplicated' => NutritionRecipeSourceKind.duplicated,
        'substituted' => NutritionRecipeSourceKind.substituted,
        'imported' => NutritionRecipeSourceKind.imported,
        'unknown' => NutritionRecipeSourceKind.unknown,
        _ => throw NutritionRecipeValidationError(
          'unsupported_recipe_source',
          'Unsupported recipe source kind: $value.',
        ),
      };
}

/// Portable provenance for an immutable recipe version.
///
/// v17 has one source/provenance column rather than a separate ancestry table.
/// The repository stores this versioned JSON contract in that column. The
/// parent version is therefore durable, portable, and included by Backup v8;
/// it is never inferred from a display name or local row ID.
class NutritionRecipeSource {
  final NutritionRecipeSourceKind kind;
  final String? parentVersionId;
  final String? externalReference;
  final String? servingDefinitionId;
  final String? servingDefinitionRevision;
  final String? note;

  const NutritionRecipeSource({
    this.kind = NutritionRecipeSourceKind.userAuthored,
    this.parentVersionId,
    this.externalReference,
    this.servingDefinitionId,
    this.servingDefinitionRevision,
    this.note,
  });

  NutritionRecipeSource copyWith({
    NutritionRecipeSourceKind? kind,
    String? parentVersionId,
    String? externalReference,
    String? servingDefinitionId,
    String? servingDefinitionRevision,
    String? note,
  }) => NutritionRecipeSource(
    kind: kind ?? this.kind,
    parentVersionId: parentVersionId ?? this.parentVersionId,
    externalReference: externalReference ?? this.externalReference,
    servingDefinitionId: servingDefinitionId ?? this.servingDefinitionId,
    servingDefinitionRevision:
        servingDefinitionRevision ?? this.servingDefinitionRevision,
    note: note ?? this.note,
  );

  String encode() => jsonEncode({
    'contract_version': kNutritionRecipeContractVersion,
    'kind': kind.stableId,
    if (parentVersionId != null) 'parent_version_id': parentVersionId,
    if (externalReference != null) 'external_reference': externalReference,
    if (servingDefinitionId != null)
      'serving_definition_id': servingDefinitionId,
    if (servingDefinitionRevision != null)
      'serving_definition_revision': servingDefinitionRevision,
    if (note != null) 'note': note,
  });

  factory NutritionRecipeSource.decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _opaque(raw);
      final map = Map<String, dynamic>.from(decoded);
      if (map['contract_version'] != kNutritionRecipeContractVersion) {
        return _opaque(raw);
      }
      final kind = map['kind'];
      final parent = map['parent_version_id'];
      final external = map['external_reference'];
      final servingId = map['serving_definition_id'];
      final servingRevision = map['serving_definition_revision'];
      final note = map['note'];
      if (kind is! String ||
          parent is! String? && parent != null ||
          external is! String? && external != null ||
          servingId is! String? && servingId != null ||
          servingRevision is! String? && servingRevision != null ||
          note is! String? && note != null) {
        throw const NutritionRecipeValidationError(
          'malformed_recipe_source',
          'Recipe version source metadata is malformed.',
        );
      }
      return NutritionRecipeSource(
        kind: NutritionRecipeSourceKindValue.fromStableId(kind),
        parentVersionId: parent as String?,
        externalReference: external as String?,
        servingDefinitionId: servingId as String?,
        servingDefinitionRevision: servingRevision as String?,
        note: note as String?,
      );
    } on NutritionRecipeException {
      rethrow;
    } catch (_) {
      return _opaque(raw);
    }
  }

  static NutritionRecipeSource _opaque(String raw) => NutritionRecipeSource(
    kind: NutritionRecipeSourceKind.unknown,
    externalReference: raw,
  );
}

class NutritionRecipeServingDefinition {
  final String id;
  final String revision;
  final QuantityAmount count;
  final String? source;

  const NutritionRecipeServingDefinition({
    required this.id,
    required this.revision,
    required this.count,
    this.source,
  });

  void validate() {
    if (id.trim().isEmpty || revision.trim().isEmpty || count.isZero) {
      throw const NutritionRecipeValidationError(
        'invalid_serving_definition',
        'A recipe serving definition requires a positive count, ID, and revision.',
      );
    }
  }
}

class NutritionRecipeException implements Exception {
  final String code;
  final String message;

  const NutritionRecipeException(this.code, this.message);

  @override
  String toString() => 'NutritionRecipeException($code): $message';
}

class NutritionRecipeValidationError extends NutritionRecipeException {
  const NutritionRecipeValidationError(super.code, super.message);
}

class NutritionRecipeNotFoundError extends NutritionRecipeException {
  const NutritionRecipeNotFoundError(String message)
    : super('recipe_not_found', message);
}

class NutritionRecipeVersionNotFoundError extends NutritionRecipeException {
  const NutritionRecipeVersionNotFoundError(String message)
    : super('recipe_version_not_found', message);
}

class NutritionRecipeImmutableError extends NutritionRecipeException {
  const NutritionRecipeImmutableError(String message)
    : super('immutable_version', message);
}

class NutritionRecipeConflictError extends NutritionRecipeException {
  const NutritionRecipeConflictError(String message)
    : super('recipe_conflict', message);
}

class NutritionRecipeNestedReferenceError extends NutritionRecipeException {
  const NutritionRecipeNestedReferenceError(String message)
    : super('nested_recipe_unsupported', message);
}

enum NutritionRecipePublicationStage {
  validation,
  versionStatusMutation,
  beforeHeadUpdate,
}

typedef NutritionRecipePublicationFailureInjector =
    Future<void> Function(NutritionRecipePublicationStage stage);

class NutritionRecipeIngredientInput {
  final String id;
  final String? foodId;
  final String? nestedRecipeVersionId;
  final int? position;
  final Quantity quantity;
  final String? preparationId;
  final String? measureId;
  final QuantityAmount? lower;
  final QuantityAmount? upper;
  final String? notes;
  final String? substitutedFromFoodId;
  final String? provenanceSource;

  const NutritionRecipeIngredientInput._({
    required this.id,
    required this.foodId,
    required this.nestedRecipeVersionId,
    required this.position,
    required this.quantity,
    required this.preparationId,
    required this.measureId,
    required this.lower,
    required this.upper,
    required this.notes,
    required this.substitutedFromFoodId,
    required this.provenanceSource,
  });

  factory NutritionRecipeIngredientInput.directFood({
    required String id,
    required String foodId,
    required Quantity quantity,
    int? position,
    String? preparationId,
    String? measureId,
    QuantityAmount? lower,
    QuantityAmount? upper,
    String? notes,
    String? substitutedFromFoodId,
    String? provenanceSource,
  }) => NutritionRecipeIngredientInput._(
    id: id,
    foodId: foodId,
    nestedRecipeVersionId: null,
    position: position,
    quantity: quantity,
    preparationId: preparationId,
    measureId: measureId,
    lower: lower,
    upper: upper,
    notes: notes,
    substitutedFromFoodId: substitutedFromFoodId,
    provenanceSource: provenanceSource,
  );

  factory NutritionRecipeIngredientInput.nestedRecipe({
    required String id,
    required String recipeVersionId,
    required Quantity quantity,
    int? position,
    String? notes,
  }) => NutritionRecipeIngredientInput._(
    id: id,
    foodId: null,
    nestedRecipeVersionId: recipeVersionId,
    position: position,
    quantity: quantity,
    preparationId: null,
    measureId: null,
    lower: null,
    upper: null,
    notes: notes,
    substitutedFromFoodId: null,
    provenanceSource: null,
  );
}

class NutritionRecipeModel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final NutritionRecipeLifecycle lifecycle;
  final String? currentVersionId;

  const NutritionRecipeModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.lifecycle,
    required this.currentVersionId,
  });
}

class NutritionRecipeIngredientModel {
  final String id;
  final String recipeVersionId;
  final int position;
  final String foodId;
  final String? preparationId;
  final Quantity quantity;
  final String? measureId;
  final QuantityAmount? lower;
  final QuantityAmount? upper;
  final String? notes;
  final String? substitutedFromFoodId;

  const NutritionRecipeIngredientModel({
    required this.id,
    required this.recipeVersionId,
    required this.position,
    required this.foodId,
    required this.preparationId,
    required this.quantity,
    required this.measureId,
    required this.lower,
    required this.upper,
    required this.notes,
    required this.substitutedFromFoodId,
  });
}

class NutritionRecipeVersionModel {
  final String id;
  final String recipeId;
  final int versionNumber;
  final NutritionRecipeVersionStatus status;
  final Quantity? yieldQuantity;
  final NutritionRecipeServingDefinition? servingDefinition;
  final String calculationRuleVersion;
  final NutritionRecipeSource source;
  final String? parentVersionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NutritionRecipeIngredientModel> ingredients;

  const NutritionRecipeVersionModel({
    required this.id,
    required this.recipeId,
    required this.versionNumber,
    required this.status,
    required this.yieldQuantity,
    required this.servingDefinition,
    required this.calculationRuleVersion,
    required this.source,
    required this.parentVersionId,
    required this.createdAt,
    required this.updatedAt,
    required this.ingredients,
  });

  bool get isImmutable =>
      status == NutritionRecipeVersionStatus.published ||
      status == NutritionRecipeVersionStatus.archived;
}

class NutritionRecipeDraftModel {
  final NutritionRecipeModel recipe;
  final NutritionRecipeVersionModel version;

  const NutritionRecipeDraftModel({
    required this.recipe,
    required this.version,
  });
}

/// Sole durable owner of direct-food recipe lifecycle and immutable versions.
///
/// This repository intentionally does not calculate nutrition, resolve names,
/// write legacy meal-template rows, or create nested recipe edges.
class NutritionRecipeRepository {
  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;
  final NutritionRecipePublicationFailureInjector? _failureInjector;

  NutritionRecipeRepository({
    required AppDatabase db,
    Uuid? uuid,
    DateTime Function()? nowUtc,
    NutritionRecipePublicationFailureInjector? failureInjector,
  }) : _db = db,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _failureInjector = failureInjector;

  Future<NutritionRecipeDraftModel> createRecipe({
    required String userId,
    required String name,
    String? description,
    String? recipeId,
    String? versionId,
    Iterable<NutritionRecipeIngredientInput> ingredients = const [],
    Quantity? yieldQuantity,
    NutritionRecipeServingDefinition? servingDefinition,
    String calculationRuleVersion = 'recipe-graph-v1',
    NutritionRecipeSource source = const NutritionRecipeSource(),
    DateTime? nowUtc,
  }) => createDraft(
    userId: userId,
    name: name,
    description: description,
    recipeId: recipeId,
    versionId: versionId,
    ingredients: ingredients,
    yieldQuantity: yieldQuantity,
    servingDefinition: servingDefinition,
    calculationRuleVersion: calculationRuleVersion,
    source: source,
    nowUtc: nowUtc,
  );

  Future<NutritionRecipeDraftModel> createDraft({
    required String userId,
    required String name,
    String? description,
    String? recipeId,
    String? versionId,
    Iterable<NutritionRecipeIngredientInput> ingredients = const [],
    Quantity? yieldQuantity,
    NutritionRecipeServingDefinition? servingDefinition,
    String calculationRuleVersion = 'recipe-graph-v1',
    NutritionRecipeSource source = const NutritionRecipeSource(),
    DateTime? nowUtc,
  }) async {
    _requireText(userId, 'userId');
    _requireText(name, 'name');
    _requireText(calculationRuleVersion, 'calculationRuleVersion');
    final id = _portableId(recipeId, 'recipe');
    final draftId = _portableId(versionId, 'recipe version');
    final rows = ingredients.toList(growable: false);
    final now = (nowUtc ?? _nowUtc()).toUtc();
    _validateVersionInputs(
      yieldQuantity: yieldQuantity,
      servingDefinition: servingDefinition,
      calculationRuleVersion: calculationRuleVersion,
      source: source,
    );

    await _db.transaction(() async {
      if (await _recipeById(id) != null) {
        throw NutritionRecipeValidationError(
          'duplicate_recipe_id',
          'Recipe portable ID $id already exists.',
        );
      }
      if (await _versionById(draftId) != null) {
        throw NutritionRecipeValidationError(
          'duplicate_version_id',
          'Recipe version portable ID $draftId already exists.',
        );
      }
      await _db
          .into(_db.nutritionRecipes)
          .insert(
            NutritionRecipesCompanion.insert(
              id: id,
              userId: userId.trim(),
              name: name.trim(),
              description: Value(description),
              lifecycle: NutritionRecipeLifecycle.active.stableId,
            ),
          );
      await _insertVersion(
        recipeId: id,
        versionId: draftId,
        versionNumber: 1,
        status: NutritionRecipeVersionStatus.draft,
        yieldQuantity: yieldQuantity,
        servingDefinition: servingDefinition,
        calculationRuleVersion: calculationRuleVersion,
        source: source,
        now: now,
      );
      await _replaceIngredients(
        recipeVersionId: draftId,
        inputs: rows,
        versionSource: source,
        userId: userId.trim(),
      );
    });
    return (await getDraft(draftId))!;
  }

  Future<NutritionRecipeDraftModel> createSuccessorDraft({
    required String recipeId,
    String? versionId,
    NutritionRecipeSourceKind sourceKind =
        NutritionRecipeSourceKind.userAuthored,
    String? note,
    DateTime? nowUtc,
  }) async {
    final now = (nowUtc ?? _nowUtc()).toUtc();
    return _db.transaction(() async {
      final recipe = await _requireRecipe(recipeId);
      final currentId = recipe.currentVersionId;
      if (currentId == null) {
        throw const NutritionRecipeConflictError(
          'A successor draft requires a published current version.',
        );
      }
      final current = await _requireVersion(currentId);
      if (current.recipeId != recipeId ||
          current.status != NutritionRecipeVersionStatus.published.stableId) {
        throw const NutritionRecipeValidationError(
          'invalid_current_version',
          'The recipe current version is not a published version owned by it.',
        );
      }
      if (await _draftForRecipe(recipeId) != null) {
        throw const NutritionRecipeConflictError(
          'A recipe already has an editable draft.',
        );
      }
      final newId = _portableId(versionId, 'recipe version');
      if (await _versionById(newId) != null) {
        throw NutritionRecipeValidationError(
          'duplicate_version_id',
          'Recipe version portable ID $newId already exists.',
        );
      }
      final source = NutritionRecipeSource(
        kind: sourceKind,
        parentVersionId: current.id,
        note: note,
      );
      final currentSource = NutritionRecipeSource.decode(current.source);
      final serving = current.servingQuantity == null
          ? null
          : NutritionRecipeServingDefinition(
              id:
                  currentSource.servingDefinitionId ??
                  'recipe-serving-${current.id}',
              revision:
                  currentSource.servingDefinitionRevision ??
                  current.calcRuleVersion,
              count: QuantityAmount.fromNum(current.servingQuantity!),
              source: currentSource.externalReference,
            );
      final yieldQuantity = _quantityFromStored(
        current.yieldQuantity,
        current.yieldUnit,
      );
      await _insertVersion(
        recipeId: recipeId,
        versionId: newId,
        versionNumber: await _nextVersionNumber(recipeId),
        status: NutritionRecipeVersionStatus.draft,
        yieldQuantity: yieldQuantity,
        servingDefinition: serving,
        calculationRuleVersion: current.calcRuleVersion,
        source: source,
        now: now,
      );
      final oldIngredients =
          await (_db.select(_db.nutritionRecipeIngredients)
                ..where((row) => row.recipeVersionId.equals(current.id))
                ..orderBy([(row) => OrderingTerm(expression: row.position)]))
              .get();
      final corrections = await _substitutionCorrections(
        oldIngredients.map((row) => row.id),
      );
      final inputs = [
        for (final row in oldIngredients)
          NutritionRecipeIngredientInput.directFood(
            id: _uuid.v4(),
            foodId: row.foodId,
            quantity: _quantityFromStored(
              row.quantityValue,
              row.quantityUnit,
              recipeVersionId: current.id,
              calculationRuleVersion: current.calcRuleVersion,
              measureId: row.measureId,
            )!,
            position: row.position,
            preparationId: row.preparationId,
            measureId: row.measureId,
            lower: row.lower == null
                ? null
                : QuantityAmount.fromNum(row.lower!),
            upper: row.upper == null
                ? null
                : QuantityAmount.fromNum(row.upper!),
            notes: row.notes,
            substitutedFromFoodId: corrections[row.id],
            provenanceSource: source.kind.stableId,
          ),
      ];
      await _replaceIngredients(
        recipeVersionId: newId,
        inputs: inputs,
        versionSource: source,
        userId: recipe.userId,
      );
      return (await getDraft(newId))!;
    });
  }

  Future<NutritionRecipeDraftModel> duplicatePublishedVersion({
    required String sourceVersionId,
    required String userId,
    String? recipeId,
    String? versionId,
    String? name,
    String? description,
    DateTime? nowUtc,
  }) async {
    final sourceVersion = await _requireVersion(sourceVersionId);
    if (sourceVersion.status !=
        NutritionRecipeVersionStatus.published.stableId) {
      throw const NutritionRecipeConflictError(
        'Only a published version can be duplicated.',
      );
    }
    final sourceRecipe = await _requireRecipe(sourceVersion.recipeId);
    final rows = await _ingredientsAsInputs(sourceVersion);
    final source = NutritionRecipeSource(
      kind: NutritionRecipeSourceKind.duplicated,
      parentVersionId: sourceVersion.id,
    );
    final currentSource = NutritionRecipeSource.decode(sourceVersion.source);
    final serving = sourceVersion.servingQuantity == null
        ? null
        : NutritionRecipeServingDefinition(
            id:
                currentSource.servingDefinitionId ??
                'recipe-serving-${sourceVersion.id}',
            revision:
                currentSource.servingDefinitionRevision ??
                sourceVersion.calcRuleVersion,
            count: QuantityAmount.fromNum(sourceVersion.servingQuantity!),
          );
    return createDraft(
      userId: userId,
      name: name ?? sourceRecipe.name,
      description: description ?? sourceRecipe.description,
      recipeId: recipeId,
      versionId: versionId,
      ingredients: rows,
      yieldQuantity: _quantityFromStored(
        sourceVersion.yieldQuantity,
        sourceVersion.yieldUnit,
      ),
      servingDefinition: serving,
      calculationRuleVersion: sourceVersion.calcRuleVersion,
      source: source,
      nowUtc: nowUtc,
    );
  }

  Future<NutritionRecipeDraftModel> replaceDraftIngredients({
    required String recipeId,
    required String draftVersionId,
    required Iterable<NutritionRecipeIngredientInput> ingredients,
  }) async {
    return _db.transaction(() async {
      final recipe = await _requireRecipe(recipeId);
      final version = await _requireVersion(draftVersionId);
      _assertOwnedDraft(recipe, version);
      final source = NutritionRecipeSource.decode(version.source);
      await _replaceIngredients(
        recipeVersionId: version.id,
        inputs: ingredients.toList(growable: false),
        versionSource: source,
        userId: recipe.userId,
      );
      return (await getDraft(draftVersionId))!;
    });
  }

  /// Updates only an editable draft. Published rows are never rewritten.
  /// Ingredient replacement and draft metadata share one transaction so a
  /// failed edit cannot leave a half-updated draft graph.
  Future<NutritionRecipeDraftModel> updateDraft({
    required String recipeId,
    required String draftVersionId,
    String? name,
    String? description,
    Quantity? yieldQuantity,
    NutritionRecipeServingDefinition? servingDefinition,
    String? calculationRuleVersion,
    Iterable<NutritionRecipeIngredientInput>? ingredients,
  }) async {
    return _db.transaction(() async {
      final recipe = await _requireRecipe(recipeId);
      final version = await _requireVersion(draftVersionId);
      _assertOwnedDraft(recipe, version);
      final source = NutritionRecipeSource.decode(version.source);
      final nextYield =
          yieldQuantity ??
          _quantityFromStored(version.yieldQuantity, version.yieldUnit);
      final currentServing = version.servingQuantity == null
          ? null
          : NutritionRecipeServingDefinition(
              id: source.servingDefinitionId ?? 'recipe-serving-${version.id}',
              revision:
                  source.servingDefinitionRevision ?? version.calcRuleVersion,
              count: QuantityAmount.fromNum(version.servingQuantity!),
            );
      final nextServing = servingDefinition ?? currentServing;
      final nextRule = calculationRuleVersion ?? version.calcRuleVersion;
      final nextSource = source.copyWith(
        servingDefinitionId: nextServing?.id,
        servingDefinitionRevision: nextServing?.revision,
      );
      _validateVersionInputs(
        yieldQuantity: nextYield,
        servingDefinition: nextServing,
        calculationRuleVersion: nextRule,
        source: nextSource,
      );
      if (name != null) _requireText(name, 'name');
      if (name != null || description != null) {
        await (_db.update(
          _db.nutritionRecipes,
        )..where((row) => row.id.equals(recipeId))).write(
          NutritionRecipesCompanion(
            name: name == null ? const Value.absent() : Value(name.trim()),
            description: Value(description),
            updatedAt: Value(_nowUtc().toUtc()),
          ),
        );
      }
      final storedSource = nextServing == null
          ? nextSource
          : nextSource.copyWith(
              servingDefinitionId: nextServing.id,
              servingDefinitionRevision: nextServing.revision,
            );
      await (_db.update(
        _db.nutritionRecipeVersions,
      )..where((row) => row.id.equals(version.id))).write(
        NutritionRecipeVersionsCompanion(
          yieldQuantity: Value(nextYield?.amount.asDouble),
          yieldUnit: Value(
            nextYield == null ? null : _databaseUnitId(nextYield.unit),
          ),
          servingQuantity: Value(nextServing?.count.asDouble),
          calcRuleVersion: Value(nextRule),
          source: Value(storedSource.encode()),
          updatedAt: Value(_nowUtc().toUtc()),
        ),
      );
      if (ingredients != null) {
        await _replaceIngredients(
          recipeVersionId: version.id,
          inputs: ingredients.toList(growable: false),
          versionSource: storedSource,
          userId: recipe.userId,
        );
      }
      return (await getDraft(draftVersionId))!;
    });
  }

  Future<NutritionRecipeVersionModel> publishDraft({
    required String recipeId,
    required String draftVersionId,
  }) async {
    await _failureInjector?.call(NutritionRecipePublicationStage.validation);
    return _db.transaction(() async {
      final recipe = await _requireRecipe(recipeId);
      final version = await _requireVersion(draftVersionId);
      _assertOwnedDraft(recipe, version, allowPublished: true);
      if (version.status == NutritionRecipeVersionStatus.published.stableId) {
        return (await getVersion(draftVersionId))!;
      }
      if (version.status != NutritionRecipeVersionStatus.draft.stableId) {
        throw const NutritionRecipeImmutableError(
          'Only an editable draft can be published.',
        );
      }
      if (recipe.lifecycle != NutritionRecipeLifecycle.active.stableId) {
        throw const NutritionRecipeConflictError(
          'An archived or deleted recipe cannot be published.',
        );
      }
      final source = NutritionRecipeSource.decode(version.source);
      if (source.parentVersionId != null &&
          source.parentVersionId != recipe.currentVersionId) {
        throw const NutritionRecipeConflictError(
          'The draft was created from a stale recipe head.',
        );
      }
      final ingredients =
          await (_db.select(_db.nutritionRecipeIngredients)
                ..where((row) => row.recipeVersionId.equals(version.id))
                ..orderBy([(row) => OrderingTerm(expression: row.position)]))
              .get();
      if (ingredients.isEmpty) {
        throw const NutritionRecipeValidationError(
          'empty_published_recipe',
          'A published direct-food recipe must contain at least one ingredient.',
        );
      }
      await _validateStoredIngredients(version.id, ingredients);
      await (_db.update(
        _db.nutritionRecipeVersions,
      )..where((row) => row.id.equals(version.id))).write(
        NutritionRecipeVersionsCompanion(
          status: const Value('published'),
          updatedAt: Value(_nowUtc().toUtc()),
        ),
      );
      await _failureInjector?.call(
        NutritionRecipePublicationStage.versionStatusMutation,
      );
      await _failureInjector?.call(
        NutritionRecipePublicationStage.beforeHeadUpdate,
      );
      await (_db.update(
        _db.nutritionRecipes,
      )..where((row) => row.id.equals(recipe.id))).write(
        NutritionRecipesCompanion(
          currentVersionId: Value(version.id),
          updatedAt: Value(_nowUtc().toUtc()),
        ),
      );
      return (await getVersion(draftVersionId))!;
    });
  }

  Future<NutritionRecipeModel?> getRecipe(String recipeId) async {
    final row = await _recipeById(recipeId);
    if (row == null) return null;
    await _validateRecipeGraph(row);
    return _recipeModel(row);
  }

  Future<NutritionRecipeDraftModel?> getDraft(String versionId) async {
    final version = await _versionById(versionId);
    if (version == null || version.status != 'draft') return null;
    final recipe = await _requireRecipe(version.recipeId);
    final graph = await _loadVersionGraph(recipe, version);
    return NutritionRecipeDraftModel(
      recipe: _recipeModel(recipe),
      version: graph,
    );
  }

  Future<NutritionRecipeVersionModel?> getVersion(String versionId) async {
    final version = await _versionById(versionId);
    if (version == null) return null;
    final recipe = await _requireRecipe(version.recipeId);
    return _loadVersionGraph(recipe, version);
  }

  Future<NutritionRecipeVersionModel?> getCurrentPublishedVersion(
    String recipeId,
  ) async {
    final recipe = await _recipeById(recipeId);
    if (recipe == null || recipe.currentVersionId == null) return null;
    final version = await getVersion(recipe.currentVersionId!);
    if (version?.status != NutritionRecipeVersionStatus.published) {
      throw const NutritionRecipeValidationError(
        'invalid_current_version',
        'Recipe current head does not resolve to a published version.',
      );
    }
    return version;
  }

  /// Renaming the mutable recipe head never rewrites an immutable version or
  /// its ingredient graph. Version history has no display-name authority.
  Future<NutritionRecipeModel> renameRecipe({
    required String recipeId,
    required String name,
    String? description,
  }) async {
    _requireText(name, 'name');
    await _requireRecipe(recipeId);
    await (_db.update(
      _db.nutritionRecipes,
    )..where((row) => row.id.equals(recipeId))).write(
      NutritionRecipesCompanion(
        name: Value(name.trim()),
        description: Value(description),
        updatedAt: Value(_nowUtc().toUtc()),
      ),
    );
    return (await getRecipe(recipeId))!;
  }

  Future<List<NutritionRecipeModel>> listRecipes({
    String? userId,
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.nutritionRecipes)
      ..orderBy([(row) => OrderingTerm(expression: row.id)]);
    if (userId != null) query.where((row) => row.userId.equals(userId));
    final rows = await query.get();
    final filtered = rows.where(
      (row) =>
          includeArchived ||
          row.lifecycle == NutritionRecipeLifecycle.active.stableId,
    );
    for (final row in filtered) {
      await _validateRecipeGraph(row);
    }
    return filtered.map(_recipeModel).toList(growable: false);
  }

  Future<void> archiveRecipe(String recipeId) async {
    await _setLifecycle(recipeId, NutritionRecipeLifecycle.archived);
  }

  Future<void> restoreRecipe(String recipeId) async {
    await _setLifecycle(recipeId, NutritionRecipeLifecycle.active);
  }

  /// Archives recipes with any ancestry or external reference. Only a recipe
  /// containing an unreferenced draft can be physically deleted.
  Future<void> deleteRecipe(String recipeId) async {
    await _db.transaction(() async {
      await _requireRecipe(recipeId);
      final versions = await (_db.select(
        _db.nutritionRecipeVersions,
      )..where((row) => row.recipeId.equals(recipeId))).get();
      final versionIds = versions.map((row) => row.id).toList(growable: false);
      final referenced =
          versionIds.isNotEmpty && (await _countReferences(versionIds)) > 0;
      final hasHistory = versions.any(
        (row) => row.status != NutritionRecipeVersionStatus.draft.stableId,
      );
      if (referenced || hasHistory) {
        await (_db.update(
          _db.nutritionRecipes,
        )..where((row) => row.id.equals(recipeId))).write(
          NutritionRecipesCompanion(
            lifecycle: const Value('archived'),
            updatedAt: Value(_nowUtc().toUtc()),
          ),
        );
        return;
      }
      final ids = versionIds.map((id) => "'${_sqlQuote(id)}'").join(', ');
      await _db.customStatement(
        "DELETE FROM nutrition_user_corrections WHERE target_type = 'recipe_ingredient' AND target_id IN (SELECT id FROM nutrition_recipe_ingredients WHERE recipe_version_id IN ($ids))",
      );
      await _db.customStatement(
        'DELETE FROM nutrition_recipe_ingredients WHERE recipe_version_id IN ($ids)',
      );
      await (_db.delete(
        _db.nutritionRecipeVersions,
      )..where((row) => row.recipeId.equals(recipeId))).go();
      await (_db.delete(
        _db.nutritionRecipes,
      )..where((row) => row.id.equals(recipeId))).go();
    });
  }

  Future<void> _setLifecycle(
    String recipeId,
    NutritionRecipeLifecycle lifecycle,
  ) async {
    final existing = await _recipeById(recipeId);
    if (existing == null) throw NutritionRecipeNotFoundError(recipeId);
    await (_db.update(
      _db.nutritionRecipes,
    )..where((row) => row.id.equals(recipeId))).write(
      NutritionRecipesCompanion(
        lifecycle: Value(lifecycle.stableId),
        updatedAt: Value(_nowUtc().toUtc()),
      ),
    );
  }

  Future<int> _countReferences(List<String> versionIds) async {
    if (versionIds.isEmpty) return 0;
    final quoted = versionIds.map((id) => "'${_sqlQuote(id)}'").join(', ');
    final rows = await _db.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM nutrition_consumption_snapshots WHERE recipe_version_id IN ($quoted)) +
        (SELECT COUNT(*) FROM nutrition_snapshot_items WHERE recipe_version_id IN ($quoted)) +
        (SELECT COUNT(*) FROM nutrition_thali_items WHERE recipe_version_id IN ($quoted)) AS total
    ''').get();
    return (rows.single.data['total'] as num).toInt();
  }

  Future<void> _insertVersion({
    required String recipeId,
    required String versionId,
    required int versionNumber,
    required NutritionRecipeVersionStatus status,
    required Quantity? yieldQuantity,
    required NutritionRecipeServingDefinition? servingDefinition,
    required String calculationRuleVersion,
    required NutritionRecipeSource source,
    required DateTime now,
  }) async {
    if (versionNumber < 1) {
      throw const NutritionRecipeValidationError(
        'invalid_version_number',
        'Recipe version number must be positive.',
      );
    }
    servingDefinition?.validate();
    final storedSource = servingDefinition == null
        ? source
        : source.copyWith(
            servingDefinitionId: servingDefinition.id,
            servingDefinitionRevision: servingDefinition.revision,
          );
    await _db
        .into(_db.nutritionRecipeVersions)
        .insert(
          NutritionRecipeVersionsCompanion.insert(
            id: versionId,
            recipeId: recipeId,
            versionNumber: versionNumber,
            status: status.stableId,
            yieldQuantity: Value(yieldQuantity?.amount.asDouble),
            yieldUnit: Value(
              yieldQuantity == null
                  ? null
                  : _databaseUnitId(yieldQuantity.unit),
            ),
            servingQuantity: Value(servingDefinition?.count.asDouble),
            calcRuleVersion: calculationRuleVersion,
            source: storedSource.encode(),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> _replaceIngredients({
    required String recipeVersionId,
    required List<NutritionRecipeIngredientInput> inputs,
    required NutritionRecipeSource versionSource,
    required String userId,
  }) async {
    final version = await _requireVersion(recipeVersionId);
    if (version.status != NutritionRecipeVersionStatus.draft.stableId) {
      throw const NutritionRecipeImmutableError(
        'Published recipe ingredients cannot be replaced.',
      );
    }
    final rows = await _validateIngredientInputs(
      recipeVersionId: recipeVersionId,
      inputs: inputs,
    );
    final old = await (_db.select(
      _db.nutritionRecipeIngredients,
    )..where((row) => row.recipeVersionId.equals(recipeVersionId))).get();
    await _deleteIngredientCorrections(old.map((row) => row.id));
    await (_db.delete(
      _db.nutritionRecipeIngredients,
    )..where((row) => row.recipeVersionId.equals(recipeVersionId))).go();
    await _db.batch((batch) {
      batch.insertAll(_db.nutritionRecipeIngredients, [
        for (final row in rows)
          NutritionRecipeIngredientsCompanion.insert(
            id: row.id,
            recipeVersionId: recipeVersionId,
            position: row.position!,
            foodId: row.foodId!,
            preparationId: Value(row.preparationId),
            quantityValue: row.quantity.amount.asDouble,
            quantityDimension: row.quantity.dimension.name,
            quantityUnit: _databaseUnitId(row.quantity.unit),
            measureId: Value(row.measureId),
            lower: Value(row.lower?.asDouble),
            upper: Value(row.upper?.asDouble),
            notes: Value(row.notes),
          ),
      ]);
    });
    for (final row in rows) {
      if (row.substitutedFromFoodId == null) continue;
      await _db
          .into(_db.nutritionUserCorrections)
          .insert(
            NutritionUserCorrectionsCompanion.insert(
              id: 'recipe-ingredient-substitution:${row.id}',
              userId: userId,
              targetType: 'recipe_ingredient',
              targetId: row.id,
              field: 'substituted_from_food',
              oldValue: Value(row.substitutedFromFoodId),
              newValue: Value(row.foodId),
              reason: row.provenanceSource ?? 'recipe_substitution',
              source: versionSource.kind.stableId,
            ),
          );
    }
  }

  Future<List<NutritionRecipeIngredientInput>> _validateIngredientInputs({
    required String recipeVersionId,
    required List<NutritionRecipeIngredientInput> inputs,
  }) async {
    final positions = <int>{};
    final ids = <String>{};
    final result = <NutritionRecipeIngredientInput>[];
    for (var index = 0; index < inputs.length; index++) {
      final input = inputs[index];
      if (input.id.trim().isEmpty || !ids.add(input.id)) {
        throw const NutritionRecipeValidationError(
          'duplicate_ingredient_id',
          'Ingredient line IDs must be unique and non-empty.',
        );
      }
      if (input.nestedRecipeVersionId != null) {
        throw const NutritionRecipeNestedReferenceError(
          'Nested recipe ingredients are deferred from B03-07.',
        );
      }
      final position = input.position ?? index;
      if (position < 0 || !positions.add(position)) {
        throw const NutritionRecipeValidationError(
          'invalid_ingredient_order',
          'Ingredient positions must be unique non-negative values.',
        );
      }
      NutritionQuantityService.validatePositiveRecipeIngredientQuantity(
        input.quantity,
      );
      _validatePersistableQuantity(input.quantity, input.measureId);
      if (input.lower != null &&
              input.lower!.compareTo(input.quantity.amount) > 0 ||
          input.upper != null &&
              input.upper!.compareTo(input.quantity.amount) < 0 ||
          input.lower != null &&
              input.upper != null &&
              input.lower!.compareTo(input.upper!) > 0) {
        throw const NutritionRecipeValidationError(
          'invalid_ingredient_range',
          'Ingredient quantity bounds must contain the quantity.',
        );
      }
      final foodId = input.foodId;
      if (foodId == null || foodId.trim().isEmpty) {
        throw const NutritionRecipeValidationError(
          'missing_food_identity',
          'Every direct ingredient requires an explicit portable food identity.',
        );
      }
      final food = await (_db.select(
        _db.nutritionFoods,
      )..where((row) => row.id.equals(foodId))).getSingleOrNull();
      if (food == null) {
        throw NutritionRecipeValidationError(
          'missing_food_identity',
          'Ingredient references unknown food identity $foodId.',
        );
      }
      if (input.preparationId != null) {
        final preparation =
            await (_db.select(_db.nutritionFoodPreparations)
                  ..where((row) => row.id.equals(input.preparationId!)))
                .getSingleOrNull();
        if (preparation == null || preparation.foodId != food.id) {
          throw const NutritionRecipeValidationError(
            'invalid_preparation_reference',
            'Ingredient preparation must belong to its food identity.',
          );
        }
      }
      if (input.measureId != null) {
        final measure = await (_db.select(
          _db.nutritionHouseholdMeasures,
        )..where((row) => row.id.equals(input.measureId!))).getSingleOrNull();
        if (measure == null ||
            input.quantity.dimension != QuantityDimension.householdReference) {
          throw const NutritionRecipeValidationError(
            'invalid_quantity_context',
            'A measure reference is valid only for a known household quantity.',
          );
        }
      }
      if (input.quantity.dimension == QuantityDimension.householdReference &&
          input.measureId == null) {
        throw const NutritionRecipeValidationError(
          'missing_quantity_context',
          'Household recipe quantities require an explicit measure reference.',
        );
      }
      if (input.substitutedFromFoodId != null) {
        if (input.substitutedFromFoodId == food.id) {
          throw const NutritionRecipeValidationError(
            'invalid_substitution',
            'A substitution must identify a different prior food.',
          );
        }
        final prior =
            await (_db.select(_db.nutritionFoods)
                  ..where((row) => row.id.equals(input.substitutedFromFoodId!)))
                .getSingleOrNull();
        if (prior == null) {
          throw NutritionRecipeValidationError(
            'missing_substitution_identity',
            'Substitution provenance references unknown food ${input.substitutedFromFoodId}.',
          );
        }
      }
      result.add(
        NutritionRecipeIngredientInput.directFood(
          id: input.id.trim(),
          foodId: food.id,
          quantity: input.quantity,
          position: position,
          preparationId: input.preparationId,
          measureId: input.measureId,
          lower: input.lower,
          upper: input.upper,
          notes: input.notes,
          substitutedFromFoodId: input.substitutedFromFoodId,
          provenanceSource: input.provenanceSource,
        ),
      );
    }
    final expected = List<int>.generate(
      inputs.length,
      (index) => index,
    ).toSet();
    if (!positions.containsAll(expected) ||
        positions.length != expected.length) {
      throw const NutritionRecipeValidationError(
        'invalid_ingredient_order',
        'Ingredient positions must form a contiguous ordered sequence.',
      );
    }
    result.sort((a, b) => a.position!.compareTo(b.position!));
    return result;
  }

  Future<void> _validateStoredIngredients(
    String recipeVersionId,
    List<NutritionRecipeIngredient> rows,
  ) async {
    final positions = rows.map((row) => row.position).toSet();
    final expected = List<int>.generate(rows.length, (index) => index).toSet();
    if (positions.length != rows.length ||
        !positions.containsAll(expected) ||
        rows.any(
          (row) =>
              row.recipeVersionId != recipeVersionId ||
              row.quantityValue <= 0 ||
              row.foodId.trim().isEmpty,
        )) {
      throw const NutritionRecipeValidationError(
        'invalid_ingredient_graph',
        'Stored ingredient graph is malformed.',
      );
    }
    for (final row in rows) {
      final food = await (_db.select(
        _db.nutritionFoods,
      )..where((food) => food.id.equals(row.foodId))).getSingleOrNull();
      if (food == null) {
        throw const NutritionRecipeValidationError(
          'missing_food_identity',
          'Stored ingredient graph references a missing food.',
        );
      }
    }
  }

  void _validatePersistableQuantity(Quantity quantity, String? measureId) {
    if (quantity.unit == QuantityUnit.unknown ||
        quantity.unit == QuantityUnit.legacy ||
        quantity.dimension == QuantityDimension.unknown ||
        quantity.dimension == QuantityDimension.legacy) {
      throw const NutritionRecipeValidationError(
        'unsupported_quantity',
        'Legacy and unknown quantities cannot be recipe ingredients.',
      );
    }
    if (quantity.dimension == QuantityDimension.serving &&
        quantity.context.servingDefinition == null) {
      throw const NutritionRecipeValidationError(
        'missing_quantity_context',
        'Serving recipe quantities require a serving definition.',
      );
    }
    if (quantity.dimension == QuantityDimension.householdReference &&
        quantity.context.householdMeasure == null &&
        measureId == null) {
      throw const NutritionRecipeValidationError(
        'missing_quantity_context',
        'Household recipe quantities require a typed measure context.',
      );
    }
  }

  void _validateVersionInputs({
    required Quantity? yieldQuantity,
    required NutritionRecipeServingDefinition? servingDefinition,
    required String calculationRuleVersion,
    required NutritionRecipeSource source,
  }) {
    if (yieldQuantity != null) {
      NutritionQuantityService.validatePositiveUserEnteredPortion(
        yieldQuantity,
      );
      if ({
        QuantityDimension.serving,
        QuantityDimension.householdReference,
        QuantityDimension.unknown,
        QuantityDimension.legacy,
      }.contains(yieldQuantity.dimension)) {
        throw const NutritionRecipeValidationError(
          'invalid_yield_quantity',
          'Recipe yield requires a canonical mass, volume, or count quantity.',
        );
      }
    }
    servingDefinition?.validate();
    _requireText(calculationRuleVersion, 'calculationRuleVersion');
    if (source.parentVersionId != null &&
        source.parentVersionId!.trim().isEmpty) {
      throw const NutritionRecipeValidationError(
        'invalid_version_ancestry',
        'A recipe version parent ID cannot be empty.',
      );
    }
  }

  Future<List<NutritionRecipeIngredientInput>> _ingredientsAsInputs(
    NutritionRecipeVersion sourceVersion,
  ) async {
    final rows =
        await (_db.select(_db.nutritionRecipeIngredients)
              ..where((row) => row.recipeVersionId.equals(sourceVersion.id))
              ..orderBy([(row) => OrderingTerm(expression: row.position)]))
            .get();
    final corrections = await _substitutionCorrections(
      rows.map((row) => row.id),
    );
    return [
      for (final row in rows)
        NutritionRecipeIngredientInput.directFood(
          id: _uuid.v4(),
          foodId: row.foodId,
          quantity: _quantityFromStored(
            row.quantityValue,
            row.quantityUnit,
            recipeVersionId: sourceVersion.id,
            calculationRuleVersion: sourceVersion.calcRuleVersion,
            measureId: row.measureId,
          )!,
          position: row.position,
          preparationId: row.preparationId,
          measureId: row.measureId,
          lower: row.lower == null ? null : QuantityAmount.fromNum(row.lower!),
          upper: row.upper == null ? null : QuantityAmount.fromNum(row.upper!),
          notes: row.notes,
          substitutedFromFoodId: corrections[row.id],
        ),
    ];
  }

  Quantity? _quantityFromStored(
    double? value,
    String? stableUnit, {
    String? recipeVersionId,
    String? calculationRuleVersion,
    String? measureId,
  }) {
    if (value == null || stableUnit == null) return null;
    final unit = _quantityUnitFromDatabase(stableUnit);
    if (unit == QuantityUnit.serving) {
      return Quantity.serving(
        amount: value.toString(),
        definition: ServingDefinitionReference(
          id: recipeVersionId ?? 'recipe-serving',
          revision: calculationRuleVersion ?? 'recipe-graph-v1',
        ),
      );
    }
    if (unit == QuantityUnit.householdReference) {
      return Quantity.householdReference(
        count: value.toString(),
        reference: HouseholdMeasureReference(
          measureType: measureId ?? 'unresolved',
          calibrationId: measureId,
        ),
      );
    }
    return Quantity.fromNum(amount: value, unit: unit);
  }

  String _databaseUnitId(QuantityUnit unit) => switch (unit) {
    QuantityUnit.milligram => 'milligram',
    QuantityUnit.gram => 'gram',
    QuantityUnit.kilogram => 'kilogram',
    QuantityUnit.millilitre => 'millilitre',
    QuantityUnit.litre => 'litre',
    QuantityUnit.piece => 'piece',
    QuantityUnit.serving => 'serving',
    QuantityUnit.householdReference => 'household_reference',
    QuantityUnit.unknown ||
    QuantityUnit.legacy => throw const NutritionRecipeValidationError(
      'unsupported_quantity',
      'Unknown and legacy units cannot be persisted in a recipe.',
    ),
  };

  QuantityUnit _quantityUnitFromDatabase(String value) => switch (value) {
    'milligram' || 'mass_milligram' => QuantityUnit.milligram,
    'gram' || 'mass_gram' => QuantityUnit.gram,
    'kilogram' || 'mass_kilogram' => QuantityUnit.kilogram,
    'millilitre' || 'volume_millilitre' => QuantityUnit.millilitre,
    'litre' || 'volume_litre' => QuantityUnit.litre,
    'piece' || 'count_piece' => QuantityUnit.piece,
    'serving' => QuantityUnit.serving,
    'household_reference' => QuantityUnit.householdReference,
    _ => throw NutritionRecipeValidationError(
      'unsupported_quantity_unit',
      'Unsupported persisted recipe quantity unit: $value.',
    ),
  };

  Future<NutritionRecipeVersionModel> _loadVersionGraph(
    NutritionRecipe recipe,
    NutritionRecipeVersion version,
  ) async {
    final allVersions =
        await (_db.select(_db.nutritionRecipeVersions)
              ..where((row) => row.recipeId.equals(recipe.id))
              ..orderBy([(row) => OrderingTerm(expression: row.versionNumber)]))
            .get();
    _validateVersionAncestry(recipe, allVersions);
    final rows =
        await (_db.select(_db.nutritionRecipeIngredients)
              ..where((row) => row.recipeVersionId.equals(version.id))
              ..orderBy([(row) => OrderingTerm(expression: row.position)]))
            .get();
    await _validateStoredIngredients(version.id, rows);
    final corrections = await _substitutionCorrections(
      rows.map((row) => row.id),
    );
    final source = NutritionRecipeSource.decode(version.source);
    final serving = version.servingQuantity == null
        ? null
        : NutritionRecipeServingDefinition(
            id: source.servingDefinitionId ?? 'recipe-serving-${version.id}',
            revision:
                source.servingDefinitionRevision ?? version.calcRuleVersion,
            count: QuantityAmount.fromNum(version.servingQuantity!),
            source: source.externalReference,
          );
    return NutritionRecipeVersionModel(
      id: version.id,
      recipeId: version.recipeId,
      versionNumber: version.versionNumber,
      status: _versionStatus(version.status),
      yieldQuantity: _quantityFromStored(
        version.yieldQuantity,
        version.yieldUnit,
      ),
      servingDefinition: serving,
      calculationRuleVersion: version.calcRuleVersion,
      source: source,
      parentVersionId: source.parentVersionId,
      createdAt: version.createdAt,
      updatedAt: version.updatedAt,
      ingredients: [
        for (final row in rows)
          NutritionRecipeIngredientModel(
            id: row.id,
            recipeVersionId: row.recipeVersionId,
            position: row.position,
            foodId: row.foodId,
            preparationId: row.preparationId,
            quantity: _quantityFromStored(
              row.quantityValue,
              row.quantityUnit,
              recipeVersionId: version.id,
              calculationRuleVersion: version.calcRuleVersion,
              measureId: row.measureId,
            )!,
            measureId: row.measureId,
            lower: row.lower == null
                ? null
                : QuantityAmount.fromNum(row.lower!),
            upper: row.upper == null
                ? null
                : QuantityAmount.fromNum(row.upper!),
            notes: row.notes,
            substitutedFromFoodId: corrections[row.id],
          ),
      ],
    );
  }

  Future<Map<String, String>> _substitutionCorrections(
    Iterable<String> ingredientIds,
  ) async {
    final ids = ingredientIds.toSet();
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.nutritionUserCorrections)..where(
              (row) =>
                  row.targetType.equals('recipe_ingredient') &
                  row.field.equals('substituted_from_food'),
            ))
            .get();
    return {
      for (final row in rows)
        if (ids.contains(row.targetId) && row.oldValue != null)
          row.targetId: row.oldValue!,
    };
  }

  Future<void> _deleteIngredientCorrections(
    Iterable<String> ingredientIds,
  ) async {
    final ids = ingredientIds.toSet();
    if (ids.isEmpty) return;
    final rows =
        await (_db.select(_db.nutritionUserCorrections)..where(
              (row) =>
                  row.targetType.equals('recipe_ingredient') &
                  row.field.equals('substituted_from_food'),
            ))
            .get();
    for (final row in rows.where((row) => ids.contains(row.targetId))) {
      await (_db.delete(
        _db.nutritionUserCorrections,
      )..where((item) => item.id.equals(row.id))).go();
    }
  }

  Future<NutritionRecipe?> _recipeById(String recipeId) => (_db.select(
    _db.nutritionRecipes,
  )..where((row) => row.id.equals(recipeId))).getSingleOrNull();

  Future<NutritionRecipe> _requireRecipe(String recipeId) async =>
      (await _recipeById(recipeId)) ??
      (throw NutritionRecipeNotFoundError(recipeId));

  Future<NutritionRecipeVersion?> _versionById(String versionId) => (_db.select(
    _db.nutritionRecipeVersions,
  )..where((row) => row.id.equals(versionId))).getSingleOrNull();

  Future<NutritionRecipeVersion> _requireVersion(String versionId) async =>
      (await _versionById(versionId)) ??
      (throw NutritionRecipeVersionNotFoundError(versionId));

  Future<NutritionRecipeVersion?> _draftForRecipe(String recipeId) =>
      (_db.select(_db.nutritionRecipeVersions)
            ..where(
              (row) =>
                  row.recipeId.equals(recipeId) & row.status.equals('draft'),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<int> _nextVersionNumber(String recipeId) async {
    final rows = await (_db.select(
      _db.nutritionRecipeVersions,
    )..where((row) => row.recipeId.equals(recipeId))).get();
    return rows.isEmpty
        ? 1
        : rows.map((row) => row.versionNumber).reduce((a, b) => a > b ? a : b) +
              1;
  }

  NutritionRecipeModel _recipeModel(NutritionRecipe row) =>
      NutritionRecipeModel(
        id: row.id,
        userId: row.userId,
        name: row.name,
        description: row.description,
        lifecycle: _lifecycle(row.lifecycle),
        currentVersionId: row.currentVersionId,
      );

  void _assertOwnedDraft(
    NutritionRecipe recipe,
    NutritionRecipeVersion version, {
    bool allowPublished = false,
  }) {
    if (version.recipeId != recipe.id) {
      throw const NutritionRecipeValidationError(
        'cross_recipe_version_reference',
        'Recipe version belongs to another recipe.',
      );
    }
    if (!allowPublished && version.status != 'draft') {
      throw const NutritionRecipeImmutableError(
        'Published recipe versions cannot be edited.',
      );
    }
  }

  Future<void> _validateRecipeGraph(NutritionRecipe recipe) async {
    final versions = await (_db.select(
      _db.nutritionRecipeVersions,
    )..where((row) => row.recipeId.equals(recipe.id))).get();
    _validateVersionAncestry(recipe, versions);
    if (recipe.currentVersionId != null) {
      final current = versions
          .where((row) => row.id == recipe.currentVersionId)
          .toList();
      if (current.length != 1 || current.single.status != 'published') {
        throw const NutritionRecipeValidationError(
          'invalid_current_version',
          'Recipe current head must reference one of its published versions.',
        );
      }
    }
    final drafts = versions.where((row) => row.status == 'draft');
    if (drafts.length > 1) {
      throw const NutritionRecipeValidationError(
        'multiple_drafts',
        'A recipe cannot have multiple editable drafts.',
      );
    }
    for (final version in versions) {
      final ingredients = await (_db.select(
        _db.nutritionRecipeIngredients,
      )..where((row) => row.recipeVersionId.equals(version.id))).get();
      await _validateStoredIngredients(version.id, ingredients);
      if (version.status != 'draft' && ingredients.isEmpty) {
        throw const NutritionRecipeValidationError(
          'empty_immutable_recipe',
          'Published or archived versions must retain their ingredient graph.',
        );
      }
    }
  }

  void _validateVersionAncestry(
    NutritionRecipe recipe,
    List<NutritionRecipeVersion> versions,
  ) {
    final byId = {for (final version in versions) version.id: version};
    for (final version in versions) {
      final source = NutritionRecipeSource.decode(version.source);
      final parentId = source.parentVersionId;
      if (parentId == null) continue;
      final parent = byId[parentId];
      if (parent == null ||
          parent.recipeId != recipe.id ||
          parent.versionNumber >= version.versionNumber) {
        throw const NutritionRecipeValidationError(
          'invalid_version_ancestry',
          'Recipe version ancestry must point to an earlier version of the same recipe.',
        );
      }
      final seen = <String>{version.id};
      var cursor = parent;
      while (true) {
        if (!seen.add(cursor.id)) {
          throw const NutritionRecipeValidationError(
            'version_ancestry_cycle',
            'Recipe version ancestry contains a cycle.',
          );
        }
        final nextId = NutritionRecipeSource.decode(
          cursor.source,
        ).parentVersionId;
        if (nextId == null) break;
        final next = byId[nextId];
        if (next == null || next.recipeId != recipe.id) {
          throw const NutritionRecipeValidationError(
            'invalid_version_ancestry',
            'Recipe version ancestry references a missing parent.',
          );
        }
        cursor = next;
      }
    }
  }

  NutritionRecipeLifecycle _lifecycle(String value) => switch (value) {
    'active' => NutritionRecipeLifecycle.active,
    'archived' => NutritionRecipeLifecycle.archived,
    'deleted' => NutritionRecipeLifecycle.deleted,
    _ => throw NutritionRecipeValidationError(
      'invalid_recipe_lifecycle',
      'Unsupported recipe lifecycle: $value.',
    ),
  };

  NutritionRecipeVersionStatus _versionStatus(String value) => switch (value) {
    'draft' => NutritionRecipeVersionStatus.draft,
    'published' => NutritionRecipeVersionStatus.published,
    'archived' => NutritionRecipeVersionStatus.archived,
    _ => throw NutritionRecipeValidationError(
      'invalid_recipe_version_status',
      'Unsupported recipe version status: $value.',
    ),
  };

  String _portableId(String? candidate, String label) {
    final value = candidate?.trim();
    if (value != null && value.isNotEmpty) return value;
    return _uuid.v4();
  }

  void _requireText(String value, String label) {
    if (value.trim().isEmpty) {
      throw NutritionRecipeValidationError(
        'invalid_$label',
        '$label must not be empty.',
      );
    }
  }

  String _sqlQuote(String value) => value.replaceAll("'", "''");
}
