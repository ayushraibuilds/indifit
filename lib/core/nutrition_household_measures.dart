import 'typed_quantities.dart';

const int kNutritionHouseholdMeasureContractVersion = 1;
const int kNutritionHouseholdMeasureDefinitionVersion = 1;
const String kLocalNutritionUserScopeId = 'local-user-v1';

enum NutritionHouseholdMeasureDimension { volume, count, householdReference }

extension NutritionHouseholdMeasureDimensionValue
    on NutritionHouseholdMeasureDimension {
  String get stableId => name;
}

enum NutritionHouseholdMeasureReviewState { reviewed, unresolved, deprecated }

enum NutritionHouseholdMeasureSource { reviewedStandard, userCalibration }

extension NutritionHouseholdMeasureSourceValue
    on NutritionHouseholdMeasureSource {
  String get stableId => switch (this) {
    NutritionHouseholdMeasureSource.reviewedStandard => 'reviewed_standard',
    NutritionHouseholdMeasureSource.userCalibration => 'user_calibration',
  };
}

/// A typed, recoverable failure at the household-measure boundary.
class NutritionHouseholdMeasureException implements Exception {
  final String code;
  final String message;

  const NutritionHouseholdMeasureException(this.code, this.message);

  @override
  String toString() => 'NutritionHouseholdMeasureException($code): $message';
}

class NutritionVolumeRange {
  final QuantityUnit unit;
  final QuantityAmount? lower;
  final QuantityAmount? point;
  final QuantityAmount? upper;

  factory NutritionVolumeRange({
    required QuantityUnit unit,
    QuantityAmount? lower,
    QuantityAmount? point,
    QuantityAmount? upper,
  }) {
    if (unit != QuantityUnit.millilitre && unit != QuantityUnit.litre) {
      throw const NutritionHouseholdMeasureException(
        'unsupported_volume_unit',
        'Household measure volumes must use millilitres or litres.',
      );
    }
    if (lower == null && point == null && upper == null) {
      throw const NutritionHouseholdMeasureException(
        'empty_volume_range',
        'A volume range requires at least one positive bound.',
      );
    }
    for (final value in [lower, point, upper]) {
      if (value != null && value.isZero) {
        throw const NutritionHouseholdMeasureException(
          'invalid_volume',
          'Volume values must be finite and greater than zero.',
        );
      }
    }
    if (lower != null && point != null && lower.compareTo(point) > 0 ||
        point != null && upper != null && point.compareTo(upper) > 0 ||
        lower != null && upper != null && lower.compareTo(upper) > 0) {
      throw const NutritionHouseholdMeasureException(
        'invalid_volume_range',
        'Volume bounds must be ordered lower ≤ point ≤ upper.',
      );
    }
    return NutritionVolumeRange._(
      unit: unit,
      lower: lower,
      point: point,
      upper: upper,
    );
  }

  const NutritionVolumeRange._({
    required this.unit,
    required this.lower,
    required this.point,
    required this.upper,
  });

  bool get isRange => lower != null || upper != null;

  bool get isPointOnly => lower == null && upper == null && point != null;

  NutritionVolumeRange scale(QuantityAmount factor) {
    if (factor.isZero) {
      throw const NutritionHouseholdMeasureException(
        'invalid_measure_count',
        'A measure count must be greater than zero.',
      );
    }
    return NutritionVolumeRange(
      unit: unit,
      lower: lower?.multiply(factor),
      point: point?.multiply(factor),
      upper: upper?.multiply(factor),
    );
  }

  NutritionVolumeRange normalizedToMillilitres() {
    if (unit == QuantityUnit.millilitre) return this;
    QuantityAmount convert(QuantityAmount amount) => Quantity(
      amount: amount,
      unit: unit,
    ).convertTo(QuantityUnit.millilitre).amount;
    return NutritionVolumeRange(
      unit: QuantityUnit.millilitre,
      lower: lower == null ? null : convert(lower!),
      point: point == null ? null : convert(point!),
      upper: upper == null ? null : convert(upper!),
    );
  }

  Map<String, dynamic> toJson() => {
    'contract_version': kNutritionHouseholdMeasureContractVersion,
    'unit': unit.name,
    if (lower != null) 'lower': lower!.toJsonValue(),
    if (point != null) 'point': point!.toJsonValue(),
    if (upper != null) 'upper': upper!.toJsonValue(),
  };

  @override
  bool operator ==(Object other) =>
      other is NutritionVolumeRange &&
      unit == other.unit &&
      lower == other.lower &&
      point == other.point &&
      upper == other.upper;

  @override
  int get hashCode => Object.hash(unit, lower, point, upper);
}

class NutritionHouseholdMeasureDefinition {
  final String id;
  final String key;
  final String displayName;
  final NutritionHouseholdMeasureDimension dimension;
  final QuantityUnit baseUnit;
  final NutritionVolumeRange? volume;
  final NutritionHouseholdMeasureSource? source;
  final NutritionHouseholdMeasureReviewState reviewState;
  final int version;
  final String locale;

  factory NutritionHouseholdMeasureDefinition({
    required String id,
    required String key,
    required String displayName,
    required NutritionHouseholdMeasureDimension dimension,
    required QuantityUnit baseUnit,
    NutritionVolumeRange? volume,
    NutritionHouseholdMeasureSource? source,
    required NutritionHouseholdMeasureReviewState reviewState,
    int version = kNutritionHouseholdMeasureDefinitionVersion,
    String locale = 'en',
  }) {
    if (id.trim().isEmpty || key.trim().isEmpty || displayName.trim().isEmpty) {
      throw const NutritionHouseholdMeasureException(
        'invalid_measure_definition',
        'A household measure requires a stable ID, key, and display name.',
      );
    }
    if (version < 1 || locale.trim().isEmpty) {
      throw const NutritionHouseholdMeasureException(
        'unsupported_definition_version',
        'Household measure definition version and locale are invalid.',
      );
    }
    if (dimension == NutritionHouseholdMeasureDimension.volume) {
      if (baseUnit != QuantityUnit.millilitre &&
          baseUnit != QuantityUnit.litre) {
        throw const NutritionHouseholdMeasureException(
          'invalid_measure_dimension',
          'A volume measure must use a volume base unit.',
        );
      }
      if (volume != null && volume.unit != baseUnit) {
        throw const NutritionHouseholdMeasureException(
          'invalid_measure_definition',
          'A measure volume must use its declared base unit.',
        );
      }
    } else if (volume != null) {
      throw const NutritionHouseholdMeasureException(
        'invalid_measure_dimension',
        'Only volume measures may carry a volume definition.',
      );
    } else if (dimension == NutritionHouseholdMeasureDimension.count &&
        baseUnit != QuantityUnit.piece) {
      throw const NutritionHouseholdMeasureException(
        'invalid_measure_dimension',
        'A count measure must use the typed piece unit.',
      );
    } else if (dimension ==
            NutritionHouseholdMeasureDimension.householdReference &&
        baseUnit != QuantityUnit.householdReference) {
      throw const NutritionHouseholdMeasureException(
        'invalid_measure_dimension',
        'An unresolved household reference must retain its contextual unit.',
      );
    }
    if (reviewState == NutritionHouseholdMeasureReviewState.reviewed &&
        (volume == null ||
            volume.point == null ||
            source != NutritionHouseholdMeasureSource.reviewedStandard)) {
      throw const NutritionHouseholdMeasureException(
        'invalid_measure_definition',
        'A reviewed measure requires a reviewed standard volume source.',
      );
    }
    return NutritionHouseholdMeasureDefinition._(
      id: id.trim(),
      key: key.trim(),
      displayName: displayName.trim(),
      dimension: dimension,
      baseUnit: baseUnit,
      volume: volume,
      source: source,
      reviewState: reviewState,
      version: version,
      locale: locale.trim(),
    );
  }

  const NutritionHouseholdMeasureDefinition._({
    required this.id,
    required this.key,
    required this.displayName,
    required this.dimension,
    required this.baseUnit,
    required this.volume,
    required this.source,
    required this.reviewState,
    required this.version,
    required this.locale,
  });

  bool get hasReviewedVolume =>
      reviewState == NutritionHouseholdMeasureReviewState.reviewed &&
      volume != null;

  NutritionHouseholdMeasureDefinition copyWith({String? displayName}) =>
      NutritionHouseholdMeasureDefinition._(
        id: id,
        key: key,
        displayName: displayName ?? this.displayName,
        dimension: dimension,
        baseUnit: baseUnit,
        volume: volume,
        source: source,
        reviewState: reviewState,
        version: version,
        locale: locale,
      );

  Map<String, dynamic> toJson() => {
    'contract_version': kNutritionHouseholdMeasureContractVersion,
    'id': id,
    'key': key,
    'display_name': displayName,
    'dimension': dimension.stableId,
    'base_unit': baseUnit.name,
    if (volume != null) 'volume': volume!.toJson(),
    if (source != null) 'source': source!.stableId,
    'review_state': reviewState.name,
    'version': version,
    'locale': locale,
  };
}

class NutritionPersonalVessel {
  final String id;
  final String userId;
  final String displayName;
  final String? vesselType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  factory NutritionPersonalVessel({
    required String id,
    required String userId,
    required String displayName,
    String? vesselType,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) {
    if (id.trim().isEmpty ||
        userId.trim().isEmpty ||
        displayName.trim().isEmpty) {
      throw const NutritionHouseholdMeasureException(
        'invalid_vessel',
        'A personal vessel requires a portable ID, owner, and display name.',
      );
    }
    return NutritionPersonalVessel._(
      id: id.trim(),
      userId: userId.trim(),
      displayName: displayName.trim(),
      vesselType: vesselType?.trim().isEmpty == true
          ? null
          : vesselType?.trim(),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      archivedAt: archivedAt?.toUtc(),
    );
  }

  const NutritionPersonalVessel._({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.vesselType,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
  });

  bool get isArchived => archivedAt != null;
}

class NutritionVesselCalibration {
  final String id;
  final String vesselId;
  final NutritionVolumeRange volume;
  final String method;
  final double? confidence;
  final String? supersedesCalibrationId;
  final int version;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory NutritionVesselCalibration({
    required String id,
    required String vesselId,
    required NutritionVolumeRange volume,
    required String method,
    double? confidence,
    String? supersedesCalibrationId,
    required int version,
    String? notes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id.trim().isEmpty || vesselId.trim().isEmpty || method.trim().isEmpty) {
      throw const NutritionHouseholdMeasureException(
        'invalid_calibration',
        'A calibration requires IDs, a positive volume, and a method.',
      );
    }
    if (volume.point == null || volume.point!.isZero) {
      throw const NutritionHouseholdMeasureException(
        'invalid_calibration',
        'A calibration requires one positive measured volume.',
      );
    }
    if (confidence != null &&
        (!confidence.isFinite || confidence < 0 || confidence > 1)) {
      throw const NutritionHouseholdMeasureException(
        'invalid_confidence',
        'Calibration confidence must be finite and between 0 and 1.',
      );
    }
    if (version < 1) {
      throw const NutritionHouseholdMeasureException(
        'invalid_calibration_version',
        'Calibration version must be positive.',
      );
    }
    return NutritionVesselCalibration._(
      id: id.trim(),
      vesselId: vesselId.trim(),
      volume: volume,
      method: method.trim(),
      confidence: confidence,
      supersedesCalibrationId: supersedesCalibrationId?.trim().isEmpty == true
          ? null
          : supersedesCalibrationId?.trim(),
      version: version,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }

  const NutritionVesselCalibration._({
    required this.id,
    required this.vesselId,
    required this.volume,
    required this.method,
    required this.confidence,
    required this.supersedesCalibrationId,
    required this.version,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
}

sealed class NutritionMeasureSelection {
  const NutritionMeasureSelection();

  String get stableId;
}

class NutritionStandardMeasureSelection extends NutritionMeasureSelection {
  final String measureId;

  const NutritionStandardMeasureSelection(this.measureId)
    : assert(measureId != '');

  @override
  String get stableId => measureId;
}

class NutritionPersonalVesselSelection extends NutritionMeasureSelection {
  final String vesselId;

  const NutritionPersonalVesselSelection(this.vesselId)
    : assert(vesselId != '');

  @override
  String get stableId => vesselId;
}

sealed class NutritionMeasureToVolumeResult {
  const NutritionMeasureToVolumeResult();
}

class NutritionMeasureConversionResolved
    extends NutritionMeasureToVolumeResult {
  final String selectionId;
  final Quantity count;
  final NutritionVolumeRange volume;
  final NutritionHouseholdMeasureSource source;
  final int? definitionVersion;
  final String? calibrationId;
  final int? calibrationVersion;

  const NutritionMeasureConversionResolved({
    required this.selectionId,
    required this.count,
    required this.volume,
    required this.source,
    this.definitionVersion,
    this.calibrationId,
    this.calibrationVersion,
  });

  bool get isVolumeOnly => true;
}

class NutritionMeasureConversionUnresolved
    extends NutritionMeasureToVolumeResult {
  final String selectionId;
  final String code;
  final String message;
  final String missingContext;

  const NutritionMeasureConversionUnresolved({
    required this.selectionId,
    required this.code,
    required this.message,
    required this.missingContext,
  });
}

/// Pure scaling and validation for measure-to-volume conversion.
class NutritionHouseholdMeasureConversionService {
  const NutritionHouseholdMeasureConversionService();

  NutritionMeasureConversionResolved scale({
    required String selectionId,
    required Quantity count,
    required NutritionVolumeRange volume,
    required NutritionHouseholdMeasureSource source,
    int? definitionVersion,
    String? calibrationId,
    int? calibrationVersion,
  }) {
    if (count.unit != QuantityUnit.piece) {
      throw const NutritionHouseholdMeasureException(
        'invalid_measure_count_unit',
        'Household measure counts must use the typed piece/count unit.',
      );
    }
    NutritionQuantityService.validatePositive(
      count,
      context: NutritionQuantityInputContext.userEnteredPortion,
    );
    return NutritionMeasureConversionResolved(
      selectionId: selectionId,
      count: count,
      volume: volume.scale(count.amount).normalizedToMillilitres(),
      source: source,
      definitionVersion: definitionVersion,
      calibrationId: calibrationId,
      calibrationVersion: calibrationVersion,
    );
  }
}

class NutritionStandardHouseholdMeasures {
  NutritionStandardHouseholdMeasures._();

  static final List<NutritionHouseholdMeasureDefinition> definitions =
      _validateDefinitions([
        _reviewedVolume(
          key: 'teaspoon',
          displayName: 'Teaspoon',
          millilitres: '5',
        ),
        _reviewedVolume(
          key: 'tablespoon',
          displayName: 'Tablespoon',
          millilitres: '15',
        ),
        _reviewedVolume(key: 'cup', displayName: 'Cup', millilitres: '240'),
        _unresolved(
          key: 'glass',
          displayName: 'Glass',
          dimension: NutritionHouseholdMeasureDimension.householdReference,
        ),
        _unresolved(
          key: 'katori',
          displayName: 'Katori',
          dimension: NutritionHouseholdMeasureDimension.householdReference,
        ),
        _unresolved(
          key: 'bowl',
          displayName: 'Bowl',
          dimension: NutritionHouseholdMeasureDimension.householdReference,
        ),
        _unresolved(
          key: 'ladle',
          displayName: 'Ladle',
          dimension: NutritionHouseholdMeasureDimension.householdReference,
        ),
        _unresolved(
          key: 'handful',
          displayName: 'Handful',
          dimension: NutritionHouseholdMeasureDimension.householdReference,
        ),
        _unresolved(
          key: 'piece',
          displayName: 'Piece',
          dimension: NutritionHouseholdMeasureDimension.count,
          baseUnit: QuantityUnit.piece,
        ),
        _unresolved(
          key: 'roti',
          displayName: 'Roti',
          dimension: NutritionHouseholdMeasureDimension.count,
          baseUnit: QuantityUnit.piece,
        ),
        _unresolved(
          key: 'chapati',
          displayName: 'Chapati',
          dimension: NutritionHouseholdMeasureDimension.count,
          baseUnit: QuantityUnit.piece,
        ),
        _unresolved(
          key: 'plate',
          displayName: 'Plate',
          dimension: NutritionHouseholdMeasureDimension.householdReference,
        ),
        _unresolved(
          key: 'thali',
          displayName: 'Thali',
          dimension: NutritionHouseholdMeasureDimension.householdReference,
        ),
      ]);

  static List<NutritionHouseholdMeasureDefinition> _validateDefinitions(
    List<NutritionHouseholdMeasureDefinition> values,
  ) {
    final ids = <String>{};
    final keys = <String>{};
    for (final definition in values) {
      if (!ids.add(definition.id)) {
        throw NutritionHouseholdMeasureException(
          'duplicate_measure_id',
          'Duplicate standard household measure ID: ${definition.id}.',
        );
      }
      final key =
          '${definition.key}|${definition.locale}|${definition.version}';
      if (!keys.add(key)) {
        throw NutritionHouseholdMeasureException(
          'duplicate_measure_definition',
          'Duplicate standard household measure definition: $key.',
        );
      }
    }
    return List.unmodifiable(values);
  }

  static NutritionHouseholdMeasureDefinition byId(String id) {
    for (final definition in definitions) {
      if (definition.id == id) return definition;
    }
    throw NutritionHouseholdMeasureException(
      'invalid_measure_id',
      'Unknown standard household measure ID: $id.',
    );
  }

  static NutritionHouseholdMeasureDefinition _reviewedVolume({
    required String key,
    required String displayName,
    required String millilitres,
  }) {
    final id = 'household_measure_${key}_v1';
    return NutritionHouseholdMeasureDefinition(
      id: id,
      key: key,
      displayName: displayName,
      dimension: NutritionHouseholdMeasureDimension.volume,
      baseUnit: QuantityUnit.millilitre,
      volume: NutritionVolumeRange(
        unit: QuantityUnit.millilitre,
        point: QuantityAmount.fromString(millilitres),
      ),
      source: NutritionHouseholdMeasureSource.reviewedStandard,
      reviewState: NutritionHouseholdMeasureReviewState.reviewed,
    );
  }

  static NutritionHouseholdMeasureDefinition _unresolved({
    required String key,
    required String displayName,
    required NutritionHouseholdMeasureDimension dimension,
    QuantityUnit baseUnit = QuantityUnit.householdReference,
  }) => NutritionHouseholdMeasureDefinition(
    id: 'household_measure_${key}_v1',
    key: key,
    displayName: displayName,
    dimension: dimension,
    baseUnit: baseUnit,
    source: null,
    reviewState: NutritionHouseholdMeasureReviewState.unresolved,
  );
}
