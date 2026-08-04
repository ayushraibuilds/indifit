import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'nutrients.dart';
import 'nutrition_calculation_service.dart';
import 'nutrition_constraints.dart';
import 'nutrition_consumption_snapshots.dart';
import 'typed_quantities.dart';

const int kNutritionThaliContractVersion = 1;
const String kNutritionThaliCalculationVersion = 'b03-13-v1';

enum NutritionThaliItemSource { food, recipe }

extension NutritionThaliItemSourceContract on NutritionThaliItemSource {
  String get stableId => switch (this) {
    NutritionThaliItemSource.food => 'food',
    NutritionThaliItemSource.recipe => 'recipe',
  };

  static NutritionThaliItemSource fromStableId(String value) => switch (value) {
    'food' => NutritionThaliItemSource.food,
    'recipe' => NutritionThaliItemSource.recipe,
    _ => throw NutritionThaliValidationError(
      'unsupported_item_source',
      'Unsupported thali item source: $value.',
    ),
  };
}

class NutritionThaliError implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const NutritionThaliError(this.code, this.message, {this.cause});

  @override
  String toString() => 'NutritionThaliError($code): $message';
}

class NutritionThaliValidationError extends NutritionThaliError {
  const NutritionThaliValidationError(super.code, super.message, {super.cause});
}

class NutritionThaliNotFoundError extends NutritionThaliError {
  const NutritionThaliNotFoundError(super.code, super.message);
}

class NutritionThaliConflictError extends NutritionThaliError {
  const NutritionThaliConflictError(super.code, super.message);
}

class NutritionThaliPersistenceError extends NutritionThaliError {
  const NutritionThaliPersistenceError(
    super.code,
    super.message, {
    super.cause,
  });
}

/// A free-form ordered component. The item identity is independent of the
/// food/recipe display label, so duplicates remain distinct positions.
class NutritionThaliItem {
  final String id;
  final int position;
  final NutritionThaliItemSource source;
  final String? foodId;
  final String? recipeVersionId;
  final Quantity quantity;
  final String? measureId;
  final bool optional;
  final String? notes;
  final String? displayLabel;

  NutritionThaliItem({
    required String id,
    required this.position,
    required this.source,
    required this.foodId,
    required this.recipeVersionId,
    required this.quantity,
    this.measureId,
    this.optional = false,
    this.notes,
    this.displayLabel,
  }) : id = id.trim() {
    if (this.id.isEmpty) {
      throw const NutritionThaliValidationError(
        'missing_item_id',
        'A thali item requires a portable draft identity.',
      );
    }
    if (position < 0) {
      throw const NutritionThaliValidationError(
        'invalid_item_position',
        'A thali item position cannot be negative.',
      );
    }
    final hasFood = foodId != null && foodId!.trim().isNotEmpty;
    final hasRecipe =
        recipeVersionId != null && recipeVersionId!.trim().isNotEmpty;
    if (hasFood == hasRecipe) {
      throw const NutritionThaliValidationError(
        'invalid_item_identity',
        'A thali item must identify exactly one food or recipe version.',
      );
    }
    if ((source == NutritionThaliItemSource.food) != hasFood) {
      throw const NutritionThaliValidationError(
        'item_source_identity_mismatch',
        'The item source does not match its portable identity.',
      );
    }
  }

  NutritionThaliItem copyWith({
    int? position,
    NutritionThaliItemSource? source,
    String? foodId,
    String? recipeVersionId,
    Quantity? quantity,
    String? measureId,
    bool? optional,
    String? notes,
    String? displayLabel,
  }) => NutritionThaliItem(
    id: id,
    position: position ?? this.position,
    source: source ?? this.source,
    foodId: foodId ?? this.foodId,
    recipeVersionId: recipeVersionId ?? this.recipeVersionId,
    quantity: quantity ?? this.quantity,
    measureId: measureId ?? this.measureId,
    optional: optional ?? this.optional,
    notes: notes ?? this.notes,
    displayLabel: displayLabel ?? this.displayLabel,
  );

  Map<String, dynamic> toJson({bool includeLabel = true}) => {
    'contract_version': kNutritionThaliContractVersion,
    'id': id,
    'position': position,
    'source': source.stableId,
    if (foodId != null) 'food_id': foodId,
    if (recipeVersionId != null) 'recipe_version_id': recipeVersionId,
    'quantity': quantity.toJson(),
    if (measureId != null) 'measure_id': measureId,
    'optional': optional,
    if (notes != null) 'notes': notes,
    if (includeLabel && displayLabel != null) 'display_label': displayLabel,
  };
}

class NutritionThaliDraft {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String lifecycle;
  final int currentVersion;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final List<NutritionThaliItem> items;

  NutritionThaliDraft({
    required String id,
    required String userId,
    required String name,
    required this.description,
    required this.lifecycle,
    required this.currentVersion,
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    required Iterable<NutritionThaliItem> items,
  }) : id = id.trim(),
       userId = userId.trim(),
       name = name.trim(),
       createdAtUtc = createdAtUtc.toUtc(),
       updatedAtUtc = updatedAtUtc.toUtc(),
       items = List.unmodifiable(
         items.toList()..sort((a, b) {
           final position = a.position.compareTo(b.position);
           return position == 0 ? a.id.compareTo(b.id) : position;
         }),
       ) {
    if (this.id.isEmpty || this.userId.isEmpty || this.name.isEmpty) {
      throw const NutritionThaliValidationError(
        'invalid_thali_identity',
        'A thali requires user, portable ID, and name.',
      );
    }
    if (currentVersion < 1) {
      throw const NutritionThaliValidationError(
        'invalid_thali_version',
        'A thali version must be positive.',
      );
    }
    if (!const {'active', 'archived', 'deleted'}.contains(lifecycle)) {
      throw const NutritionThaliValidationError(
        'unsupported_thali_lifecycle',
        'A thali lifecycle is unsupported.',
      );
    }
    final ids = <String>{};
    final positions = <int>{};
    for (final item in this.items) {
      if (!ids.add(item.id)) {
        throw const NutritionThaliValidationError(
          'duplicate_item_id',
          'Thali item portable IDs must be unique.',
        );
      }
      if (!positions.add(item.position)) {
        throw const NutritionThaliValidationError(
          'duplicate_item_position',
          'Thali item positions must be unique.',
        );
      }
    }
    final expected = List<int>.generate(this.items.length, (index) => index);
    final actual = this.items.map((item) => item.position).toList()..sort();
    if (actual.length != expected.length || !_sameInts(actual, expected)) {
      throw const NutritionThaliValidationError(
        'non_contiguous_item_positions',
        'Thali item positions must be contiguous from zero.',
      );
    }
  }

  NutritionThaliDraft copyWith({
    String? name,
    String? description,
    String? lifecycle,
    int? currentVersion,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    Iterable<NutritionThaliItem>? items,
  }) => NutritionThaliDraft(
    id: id,
    userId: userId,
    name: name ?? this.name,
    description: description ?? this.description,
    lifecycle: lifecycle ?? this.lifecycle,
    currentVersion: currentVersion ?? this.currentVersion,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    items: items ?? this.items,
  );

  Map<String, dynamic> toJson({bool includeLabels = false}) => {
    'contract_version': kNutritionThaliContractVersion,
    'id': id,
    'user_id': userId,
    'name': name,
    if (description != null) 'description': description,
    'lifecycle': lifecycle,
    'current_version': currentVersion,
    'items': items
        .map((item) => item.toJson(includeLabel: includeLabels))
        .toList(growable: false),
  };

  String get compositionFingerprint => _sha256(toJson());
}

class NutritionThaliFoodOption {
  final String id;
  final String displayName;
  final String kind;
  final String sourceType;
  final String? region;

  const NutritionThaliFoodOption({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.sourceType,
    required this.region,
  });
}

class NutritionThaliRecipeOption {
  final String recipeId;
  final String recipeName;
  final String recipeVersionId;
  final int versionNumber;
  final DateTime versionUpdatedAtUtc;

  const NutritionThaliRecipeOption({
    required this.recipeId,
    required this.recipeName,
    required this.recipeVersionId,
    required this.versionNumber,
    required this.versionUpdatedAtUtc,
  });
}

class NutritionThaliResolvedQuantity {
  final Quantity original;
  final Quantity calculationQuantity;
  final String? measureId;
  final Map<String, dynamic> evidence;

  const NutritionThaliResolvedQuantity({
    required this.original,
    required this.calculationQuantity,
    required this.measureId,
    required this.evidence,
  });
}

class NutritionThaliItemPreview {
  final NutritionThaliItem item;
  final String displayLabel;
  final NutritionThaliResolvedQuantity resolvedQuantity;
  final NutritionCalculationResult calculation;
  final Map<String, dynamic> evidence;

  const NutritionThaliItemPreview({
    required this.item,
    required this.displayLabel,
    required this.resolvedQuantity,
    required this.calculation,
    required this.evidence,
  });
}

class NutritionThaliPreview {
  final NutritionThaliDraft draft;
  final List<NutritionThaliItemPreview> items;
  final NutrientAggregationResult aggregate;
  final NutritionConstraintEvaluationResult? constraintEvaluation;
  final String calculationVersion;
  final Map<String, dynamic> evidence;

  NutritionThaliPreview({
    required this.draft,
    required Iterable<NutritionThaliItemPreview> items,
    required this.aggregate,
    required this.constraintEvaluation,
    required this.calculationVersion,
    required this.evidence,
  }) : items = List.unmodifiable(items);

  bool get isEmpty => items.isEmpty;
  bool get isPartial =>
      aggregate.completeness.state == NutrientCompletenessState.partial;
  bool get isUnknown =>
      aggregate.completeness.state == NutrientCompletenessState.unknown;
  bool get hasUnresolvedInputs =>
      items.any((item) => item.calculation.unresolvedInputs.isNotEmpty);

  NutritionConsumptionCalculationSnapshot snapshotFor(
    NutritionThaliItemPreview item,
    NutrientRegistry registry,
  ) => NutritionConsumptionCalculationSnapshot.fromFacts(
    facts: item.calculation.facts,
    registry: registry,
    requestedNutrientIds: item.calculation.completeness.requestedNutrientIds,
    calculatorVersion: calculationVersion,
    calculationFingerprint: item.calculation.lineage.fingerprint,
    lineage: {
      'thali_item_calculation': item.calculation.toJson(),
      'resolved_quantity': item.resolvedQuantity.calculationQuantity.toJson(),
      'original_quantity': item.resolvedQuantity.original.toJson(),
      'quantity_evidence': item.resolvedQuantity.evidence,
      'item_evidence': item.evidence,
    },
  );
}

bool _sameInts(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _sha256(Map<String, dynamic> value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();

dynamic _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
