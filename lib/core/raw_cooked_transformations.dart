import 'dart:convert';

import 'typed_quantities.dart';

/// Version of the raw/cooked transformation contract.
const int kNutritionTransformationContractVersion = 1;

enum NutritionPreparationState { raw, cooked, unspecified, unknown, legacy }

extension NutritionPreparationStateContract on NutritionPreparationState {
  String get stableId => switch (this) {
    NutritionPreparationState.raw => 'raw',
    NutritionPreparationState.cooked => 'cooked',
    NutritionPreparationState.unspecified => 'unspecified',
    NutritionPreparationState.unknown => 'unknown',
    NutritionPreparationState.legacy => 'legacy',
  };

  static NutritionPreparationState fromStableId(String value) =>
      switch (value) {
        'raw' => NutritionPreparationState.raw,
        'cooked' => NutritionPreparationState.cooked,
        'unspecified' => NutritionPreparationState.unspecified,
        'unknown' => NutritionPreparationState.unknown,
        'legacy' => NutritionPreparationState.legacy,
        _ => throw UnsupportedPreparationStateError(
          'Unsupported preparation state: $value',
        ),
      };
}

/// Preparation method is separate from state. For example, `boiled` is a
/// method that may produce a `cooked` target, not a universal food identity.
enum NutritionPreparationMethod {
  boiled,
  steamed,
  pressureCooked,
  fried,
  roasted,
  baked,
  soaked,
  drained,
  prepared,
  unknown,
  legacy,
}

extension NutritionPreparationMethodContract on NutritionPreparationMethod {
  String get stableId => switch (this) {
    NutritionPreparationMethod.boiled => 'boiled',
    NutritionPreparationMethod.steamed => 'steamed',
    NutritionPreparationMethod.pressureCooked => 'pressure_cooked',
    NutritionPreparationMethod.fried => 'fried',
    NutritionPreparationMethod.roasted => 'roasted',
    NutritionPreparationMethod.baked => 'baked',
    NutritionPreparationMethod.soaked => 'soaked',
    NutritionPreparationMethod.drained => 'drained',
    NutritionPreparationMethod.prepared => 'prepared',
    NutritionPreparationMethod.unknown => 'unknown',
    NutritionPreparationMethod.legacy => 'legacy',
  };

  static NutritionPreparationMethod fromStableId(String value) =>
      switch (value) {
        'boiled' => NutritionPreparationMethod.boiled,
        'steamed' => NutritionPreparationMethod.steamed,
        'pressure_cooked' => NutritionPreparationMethod.pressureCooked,
        'fried' => NutritionPreparationMethod.fried,
        'roasted' => NutritionPreparationMethod.roasted,
        'baked' => NutritionPreparationMethod.baked,
        'soaked' => NutritionPreparationMethod.soaked,
        'drained' => NutritionPreparationMethod.drained,
        'prepared' => NutritionPreparationMethod.prepared,
        'unknown' => NutritionPreparationMethod.unknown,
        'legacy' => NutritionPreparationMethod.legacy,
        _ => throw UnsupportedPreparationStateError(
          'Unsupported preparation method: $value',
        ),
      };
}

enum NutritionTransformationSource {
  reviewedCatalogue,
  publishedReference,
  userMeasured,
  userEstimated,
  importedProvider,
  heuristic,
  legacy,
  unknown,
}

extension NutritionTransformationSourceContract
    on NutritionTransformationSource {
  String get stableId => switch (this) {
    NutritionTransformationSource.reviewedCatalogue => 'reviewed_catalogue',
    NutritionTransformationSource.publishedReference => 'published_reference',
    NutritionTransformationSource.userMeasured => 'user_measured',
    NutritionTransformationSource.userEstimated => 'user_estimated',
    NutritionTransformationSource.importedProvider => 'imported_provider',
    NutritionTransformationSource.heuristic => 'heuristic',
    NutritionTransformationSource.legacy => 'legacy',
    NutritionTransformationSource.unknown => 'unknown',
  };

  static NutritionTransformationSource fromStableId(String value) =>
      switch (value) {
        'reviewed_catalogue' => NutritionTransformationSource.reviewedCatalogue,
        'published_reference' =>
          NutritionTransformationSource.publishedReference,
        'user_measured' => NutritionTransformationSource.userMeasured,
        'user_estimated' => NutritionTransformationSource.userEstimated,
        'imported_provider' => NutritionTransformationSource.importedProvider,
        'heuristic' => NutritionTransformationSource.heuristic,
        'legacy' => NutritionTransformationSource.legacy,
        'unknown' => NutritionTransformationSource.unknown,
        _ => throw UnsupportedTransformationSourceError(
          'Unsupported transformation source: $value',
        ),
      };
}

enum NutritionTransformationReviewState {
  reviewed,
  userOverride,
  estimated,
  unresolved,
  archived,
}

extension NutritionTransformationReviewStateContract
    on NutritionTransformationReviewState {
  String get stableId => switch (this) {
    NutritionTransformationReviewState.reviewed => 'reviewed',
    NutritionTransformationReviewState.userOverride => 'user_override',
    NutritionTransformationReviewState.estimated => 'estimated',
    NutritionTransformationReviewState.unresolved => 'unresolved',
    NutritionTransformationReviewState.archived => 'archived',
  };

  static NutritionTransformationReviewState fromStableId(String value) =>
      switch (value) {
        'reviewed' => NutritionTransformationReviewState.reviewed,
        'user_override' => NutritionTransformationReviewState.userOverride,
        'estimated' => NutritionTransformationReviewState.estimated,
        'unresolved' => NutritionTransformationReviewState.unresolved,
        'archived' => NutritionTransformationReviewState.archived,
        _ => throw UnsupportedTransformationReviewStateError(
          'Unsupported transformation review state: $value',
        ),
      };
}

enum NutritionTransformationDirection { forward, inverse }

sealed class NutritionTransformationError implements Exception {
  final String message;

  const NutritionTransformationError(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class InvalidTransformationError extends NutritionTransformationError {
  const InvalidTransformationError(super.message);
}

class UnsupportedPreparationStateError extends NutritionTransformationError {
  const UnsupportedPreparationStateError(super.message);
}

class UnsupportedTransformationSourceError
    extends NutritionTransformationError {
  const UnsupportedTransformationSourceError(super.message);
}

class UnsupportedTransformationReviewStateError
    extends NutritionTransformationError {
  const UnsupportedTransformationReviewStateError(super.message);
}

class TransformationPersistenceError extends NutritionTransformationError {
  const TransformationPersistenceError(super.message);
}

class TransformationUnavailableError extends NutritionTransformationError {
  const TransformationUnavailableError(super.message);
}

class UnsupportedInverseTransformationError
    extends NutritionTransformationError {
  const UnsupportedInverseTransformationError(super.message);
}

class TransformationIdentityMismatchError extends NutritionTransformationError {
  const TransformationIdentityMismatchError(super.message);
}

class InvalidTransformationInputError extends NutritionTransformationError {
  const InvalidTransformationInputError(super.message);
}

class TransformationRange {
  final QuantityAmount? lower;
  final QuantityAmount? point;
  final QuantityAmount? upper;

  const TransformationRange({this.lower, this.point, this.upper})
    : assert(lower != null || point != null || upper != null);

  bool get isPointKnown => point != null;

  Map<String, dynamic> toJson() => {
    if (lower != null) 'lower': lower!.toJsonValue(),
    if (point != null) 'point': point!.toJsonValue(),
    if (upper != null) 'upper': upper!.toJsonValue(),
  };
}

/// A directional, food-specific transformation. The v17 conversion table
/// stores [sourceFoodId] and [sourcePreparationId] as foreign keys. Target
/// identity and the remaining typed metadata are persisted in the versioned
/// provenance envelope by [NutritionTransformationRepository].
class NutritionTransformation {
  final String id;
  final String sourceFoodId;
  final String? sourcePreparationId;
  final NutritionPreparationState sourceState;
  final String targetFoodId;
  final String? targetPreparationId;
  final NutritionPreparationState targetState;
  final QuantityUnit sourceUnit;
  final QuantityUnit targetUnit;
  final TransformationRange yieldRange;
  final NutritionTransformationDirection direction;
  final NutritionPreparationMethod method;
  final NutritionTransformationSource source;
  final NutritionTransformationReviewState reviewState;
  final String evidence;
  final String ruleVersion;
  final double? confidence;
  final String? densityContextId;
  final String? supersedesId;

  NutritionTransformation({
    required this.id,
    required this.sourceFoodId,
    this.sourcePreparationId,
    required this.sourceState,
    required this.targetFoodId,
    this.targetPreparationId,
    required this.targetState,
    required this.sourceUnit,
    required this.targetUnit,
    required this.yieldRange,
    this.direction = NutritionTransformationDirection.forward,
    required this.method,
    required this.source,
    required this.reviewState,
    required this.evidence,
    required this.ruleVersion,
    this.confidence,
    this.densityContextId,
    this.supersedesId,
  }) {
    _validate();
  }

  bool get isUserOwned =>
      reviewState == NutritionTransformationReviewState.userOverride ||
      source == NutritionTransformationSource.userMeasured ||
      source == NutritionTransformationSource.userEstimated;

  bool get isArchived =>
      reviewState == NutritionTransformationReviewState.archived;

  bool get isRangeOnly => !yieldRange.isPointKnown;

  /// Only reviewed catalogue/reference rules and explicit user-measured
  /// overrides are authoritative executable transformations. Other evidence
  /// may be retained for review, but it cannot silently become a rule.
  bool get isAuthoritativeExecutable =>
      (reviewState == NutritionTransformationReviewState.reviewed &&
          (source == NutritionTransformationSource.reviewedCatalogue ||
              source == NutritionTransformationSource.publishedReference)) ||
      (reviewState == NutritionTransformationReviewState.userOverride &&
          source == NutritionTransformationSource.userMeasured);

  bool get crossesDimensions =>
      QuantityUnitRegistry.definitionFor(sourceUnit).dimension !=
      QuantityUnitRegistry.definitionFor(targetUnit).dimension;

  String get storageSource => jsonEncode({
    'contract_version': kNutritionTransformationContractVersion,
    'source': source.stableId,
    'review_state': reviewState.stableId,
    'source_food_id': sourceFoodId,
    'source_preparation_id': sourcePreparationId,
    'source_state': sourceState.stableId,
    'target_food_id': targetFoodId,
    'target_preparation_id': targetPreparationId,
    'target_state': targetState.stableId,
    'direction': direction.name,
    'point_available': yieldRange.point != null,
    'evidence': evidence,
    'density_context_id': densityContextId,
    'supersedes_id': supersedesId,
  });

  Map<String, dynamic> toJson() => {
    'contract_version': kNutritionTransformationContractVersion,
    'id': id,
    'source_food_id': sourceFoodId,
    'source_preparation_id': sourcePreparationId,
    'source_state': sourceState.stableId,
    'target_food_id': targetFoodId,
    'target_preparation_id': targetPreparationId,
    'target_state': targetState.stableId,
    'source_unit': QuantityUnitRegistry.definitionFor(sourceUnit).stableId,
    'target_unit': QuantityUnitRegistry.definitionFor(targetUnit).stableId,
    'yield': yieldRange.toJson(),
    'direction': direction.name,
    'method': method.stableId,
    'source': source.stableId,
    'review_state': reviewState.stableId,
    'evidence': evidence,
    'rule_version': ruleVersion,
    'confidence': confidence,
    'density_context_id': densityContextId,
    'supersedes_id': supersedesId,
  };

  factory NutritionTransformation.fromJson(Object? raw) {
    try {
      if (raw is! Map ||
          raw['contract_version'] != kNutritionTransformationContractVersion) {
        throw const TransformationPersistenceError(
          'Unsupported or malformed transformation contract.',
        );
      }
      final id = raw['id'];
      final sourceFoodId = raw['source_food_id'];
      final targetFoodId = raw['target_food_id'];
      final evidence = raw['evidence'];
      final ruleVersion = raw['rule_version'];
      final confidence = raw['confidence'];
      if (id is! String ||
          sourceFoodId is! String ||
          targetFoodId is! String ||
          evidence is! String ||
          ruleVersion is! String ||
          (confidence != null && confidence is! num)) {
        throw const TransformationPersistenceError(
          'Transformation identity, evidence, version, or confidence is malformed.',
        );
      }
      return NutritionTransformation(
        id: id,
        sourceFoodId: sourceFoodId,
        sourcePreparationId: raw['source_preparation_id'] as String?,
        sourceState: NutritionPreparationStateContract.fromStableId(
          raw['source_state'] as String,
        ),
        targetFoodId: targetFoodId,
        targetPreparationId: raw['target_preparation_id'] as String?,
        targetState: NutritionPreparationStateContract.fromStableId(
          raw['target_state'] as String,
        ),
        sourceUnit: QuantityUnitRegistry.fromStableId(
          raw['source_unit'] as String,
        ).unit,
        targetUnit: QuantityUnitRegistry.fromStableId(
          raw['target_unit'] as String,
        ).unit,
        yieldRange: _rangeFromJson(raw['yield']),
        direction: nutritionTransformationDirectionFromStableId(
          raw['direction'],
        ),
        method: NutritionPreparationMethodContract.fromStableId(
          raw['method'] as String,
        ),
        source: NutritionTransformationSourceContract.fromStableId(
          raw['source'] as String,
        ),
        reviewState: NutritionTransformationReviewStateContract.fromStableId(
          raw['review_state'] as String,
        ),
        evidence: evidence,
        ruleVersion: ruleVersion,
        confidence: (confidence as num?)?.toDouble(),
        densityContextId: raw['density_context_id'] as String?,
        supersedesId: raw['supersedes_id'] as String?,
      );
    } on NutritionTransformationError {
      rethrow;
    } on Object catch (error) {
      throw TransformationPersistenceError(
        'Transformation payload is malformed: $error',
      );
    }
  }

  NutritionTransformation copyWith({
    String? id,
    TransformationRange? yieldRange,
    NutritionTransformationReviewState? reviewState,
    String? ruleVersion,
    String? supersedesId,
    NutritionTransformationDirection? direction,
  }) => NutritionTransformation(
    id: id ?? this.id,
    sourceFoodId: sourceFoodId,
    sourcePreparationId: sourcePreparationId,
    sourceState: sourceState,
    targetFoodId: targetFoodId,
    targetPreparationId: targetPreparationId,
    targetState: targetState,
    sourceUnit: sourceUnit,
    targetUnit: targetUnit,
    yieldRange: yieldRange ?? this.yieldRange,
    direction: direction ?? this.direction,
    method: method,
    source: source,
    reviewState: reviewState ?? this.reviewState,
    evidence: evidence,
    ruleVersion: ruleVersion ?? this.ruleVersion,
    confidence: confidence,
    densityContextId: densityContextId,
    supersedesId: supersedesId ?? this.supersedesId,
  );

  void _validate() {
    if (id.trim().isEmpty ||
        sourceFoodId.trim().isEmpty ||
        targetFoodId.trim().isEmpty ||
        evidence.trim().isEmpty ||
        ruleVersion.trim().isEmpty) {
      throw const InvalidTransformationError(
        'Transformation ID, food identities, evidence, and rule version are required.',
      );
    }
    if (sourceFoodId == targetFoodId &&
        sourcePreparationId == targetPreparationId &&
        sourceState == targetState) {
      throw const InvalidTransformationError(
        'A transformation source and target must be distinct.',
      );
    }
    _validateCanonicalUnit(sourceUnit, 'source');
    _validateCanonicalUnit(targetUnit, 'target');
    _validateRange(yieldRange);
    if (confidence != null &&
        (!confidence!.isFinite || confidence! < 0 || confidence! > 1)) {
      throw const InvalidTransformationError(
        'Transformation confidence must be finite and between 0 and 1.',
      );
    }
    if (reviewState == NutritionTransformationReviewState.reviewed &&
        source != NutritionTransformationSource.reviewedCatalogue &&
        source != NutritionTransformationSource.publishedReference) {
      throw const InvalidTransformationError(
        'Reviewed transformations require a reviewed or published source.',
      );
    }
    if (reviewState == NutritionTransformationReviewState.userOverride &&
        source != NutritionTransformationSource.userMeasured &&
        source != NutritionTransformationSource.userEstimated) {
      throw const InvalidTransformationError(
        'User overrides require user-measured or user-estimated provenance.',
      );
    }
    if (sourceState == NutritionPreparationState.unknown ||
        sourceState == NutritionPreparationState.legacy ||
        targetState == NutritionPreparationState.unknown ||
        targetState == NutritionPreparationState.legacy) {
      if (reviewState != NutritionTransformationReviewState.unresolved) {
        throw const InvalidTransformationError(
          'Unknown or legacy preparation states must remain unresolved.',
        );
      }
    }
  }

  static void _validateCanonicalUnit(QuantityUnit unit, String side) {
    final dimension = QuantityUnitRegistry.definitionFor(unit).dimension;
    if (dimension != QuantityDimension.mass &&
        dimension != QuantityDimension.volume &&
        dimension != QuantityDimension.count) {
      throw InvalidTransformationError(
        '$side transformation units must be mass, volume, or count.',
      );
    }
  }

  static void _validateRange(TransformationRange range) {
    final values = [range.lower, range.point, range.upper];
    if (values.every((value) => value == null)) {
      throw const InvalidTransformationError(
        'A transformation requires a point or an ordered range.',
      );
    }
    if (range.lower != null && range.lower!.isZero ||
        range.point != null && range.point!.isZero ||
        range.upper != null && range.upper!.isZero) {
      throw const InvalidTransformationError('Yield factors must be positive.');
    }
    if (range.lower != null &&
        range.point != null &&
        range.lower!.compareTo(range.point!) > 0) {
      throw const InvalidTransformationError(
        'Yield lower bound cannot exceed the point factor.',
      );
    }
    if (range.point != null &&
        range.upper != null &&
        range.point!.compareTo(range.upper!) > 0) {
      throw const InvalidTransformationError(
        'Yield point factor cannot exceed the upper bound.',
      );
    }
    if (range.lower != null &&
        range.upper != null &&
        range.lower!.compareTo(range.upper!) > 0) {
      throw const InvalidTransformationError(
        'Yield lower bound cannot exceed the upper bound.',
      );
    }
  }
}

NutritionTransformationDirection nutritionTransformationDirectionFromStableId(
  Object? raw,
) {
  if (raw is! String) {
    throw const TransformationPersistenceError(
      'Transformation direction is malformed.',
    );
  }
  return switch (raw) {
    'forward' => NutritionTransformationDirection.forward,
    'inverse' => NutritionTransformationDirection.inverse,
    _ => throw const TransformationPersistenceError(
      'Transformation direction is unsupported.',
    ),
  };
}

class NutritionTransformationLineage {
  final String transformationId;
  final String ruleVersion;
  final NutritionTransformationDirection direction;
  final NutritionTransformationSource source;
  final NutritionTransformationReviewState reviewState;

  const NutritionTransformationLineage({
    required this.transformationId,
    required this.ruleVersion,
    required this.direction,
    required this.source,
    required this.reviewState,
  });

  Map<String, dynamic> toJson() => {
    'transformation_id': transformationId,
    'rule_version': ruleVersion,
    'direction': direction.name,
    'source': source.stableId,
    'review_state': reviewState.stableId,
  };
}

sealed class NutritionTransformationResult {
  const NutritionTransformationResult();
}

class NutritionTransformationApplied extends NutritionTransformationResult {
  final Quantity? point;
  final Quantity? lower;
  final Quantity? upper;
  final NutritionTransformationLineage lineage;

  const NutritionTransformationApplied({
    required this.point,
    required this.lower,
    required this.upper,
    required this.lineage,
  });

  bool get isRangeOnly => point == null;
}

class NutritionTransformationUnresolved extends NutritionTransformationResult {
  final String code;
  final String message;

  const NutritionTransformationUnresolved({
    required this.code,
    required this.message,
  });
}

/// Pure deterministic yield application. It never mutates a database and it
/// never derives applicability from display names.
class NutritionTransformationService {
  NutritionTransformationService._();

  static NutritionTransformationResult apply({
    required NutritionTransformation transformation,
    required String sourceFoodId,
    String? sourcePreparationId,
    required Quantity input,
    NutritionTransformationDirection? direction,
  }) {
    if (transformation.isArchived) {
      return const NutritionTransformationUnresolved(
        code: 'archived_transformation',
        message: 'The transformation has been archived.',
      );
    }
    if (transformation.reviewState ==
        NutritionTransformationReviewState.unresolved) {
      return const NutritionTransformationUnresolved(
        code: 'unresolved_transformation',
        message: 'The transformation evidence is unresolved.',
      );
    }
    if (!transformation.isAuthoritativeExecutable) {
      return const NutritionTransformationUnresolved(
        code: 'unreviewed_transformation',
        message:
            'Only reviewed rules or explicit user-measured overrides may execute.',
      );
    }
    final appliedDirection = direction ?? transformation.direction;
    if (appliedDirection != transformation.direction) {
      throw const UnsupportedInverseTransformationError(
        'The requested direction requires an explicit inverse transformation record.',
      );
    }
    if (transformation.sourceFoodId != sourceFoodId ||
        transformation.sourcePreparationId != sourcePreparationId) {
      throw const TransformationIdentityMismatchError(
        'Input identity does not match the transformation source.',
      );
    }
    if (transformation.crossesDimensions &&
        transformation.densityContextId == null) {
      return const NutritionTransformationUnresolved(
        code: 'missing_density_context',
        message:
            'Cross-dimension transformation requires explicit density or portion evidence.',
      );
    }

    final sourceDefinition = QuantityUnitRegistry.definitionFor(
      transformation.sourceUnit,
    );
    if (input.dimension != sourceDefinition.dimension) {
      throw const IncompatibleQuantityDimensionError(
        'Transformation input dimension does not match the source dimension.',
      );
    }
    final normalized = input.unit == transformation.sourceUnit
        ? input
        : input.convertTo(transformation.sourceUnit);
    if (normalized.isZero) {
      throw const InvalidTransformationInputError(
        'Transformation input quantity must be positive.',
      );
    }

    Quantity makeOutput(QuantityAmount factor) {
      final context = QuantityContext(
        conversion: QuantityConversionContext(
          foodIdentityId: transformation.targetFoodId,
          preparationState: _quantityPreparationState(
            transformation.targetState,
          ),
        ),
        source: transformation.source.stableId,
        sourceScope: transformation.ruleVersion,
        approximate:
            transformation.isRangeOnly ||
            transformation.reviewState !=
                NutritionTransformationReviewState.reviewed,
      );
      return Quantity(
        amount: normalized.amount.multiply(factor),
        unit: transformation.targetUnit,
        context: context,
      );
    }

    final point = transformation.yieldRange.point == null
        ? null
        : makeOutput(transformation.yieldRange.point!);
    final lower = transformation.yieldRange.lower == null
        ? null
        : makeOutput(transformation.yieldRange.lower!);
    final upper = transformation.yieldRange.upper == null
        ? null
        : makeOutput(transformation.yieldRange.upper!);
    return NutritionTransformationApplied(
      point: point,
      lower: lower,
      upper: upper,
      lineage: NutritionTransformationLineage(
        transformationId: transformation.id,
        ruleVersion: transformation.ruleVersion,
        direction: appliedDirection,
        source: transformation.source,
        reviewState: transformation.reviewState,
      ),
    );
  }

  static QuantityPreparationState _quantityPreparationState(
    NutritionPreparationState state,
  ) => switch (state) {
    NutritionPreparationState.raw => QuantityPreparationState.raw,
    NutritionPreparationState.cooked => QuantityPreparationState.cooked,
    NutritionPreparationState.unspecified ||
    NutritionPreparationState.unknown ||
    NutritionPreparationState.legacy => QuantityPreparationState.unspecified,
  };
}

TransformationRange _rangeFromJson(Object? raw) {
  if (raw is! Map) {
    throw const TransformationPersistenceError(
      'Transformation yield range is malformed.',
    );
  }
  try {
    return TransformationRange(
      lower: raw['lower'] == null
          ? null
          : QuantityAmount.fromJsonValue(raw['lower']),
      point: raw['point'] == null
          ? null
          : QuantityAmount.fromJsonValue(raw['point']),
      upper: raw['upper'] == null
          ? null
          : QuantityAmount.fromJsonValue(raw['upper']),
    );
  } on QuantityError catch (error) {
    throw TransformationPersistenceError(error.message);
  }
}
