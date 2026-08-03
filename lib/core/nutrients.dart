import 'dart:convert';
import 'dart:io';

import 'typed_quantities.dart';

/// Version of the checked-in nutrient vocabulary and its serialized contract.
const int kNutrientRegistryVersion = 1;
const int kNutrientFactContractVersion = 1;

sealed class NutrientError implements Exception {
  final String message;

  const NutrientError(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class NutrientValidationError extends NutrientError {
  const NutrientValidationError(super.message);
}

class NutrientRegistryVersionError extends NutrientError {
  const NutrientRegistryVersionError(super.message);
}

class NutrientUnitMismatchError extends NutrientError {
  const NutrientUnitMismatchError(super.message);
}

class NutrientBasisMismatchError extends NutrientError {
  const NutrientBasisMismatchError(super.message);
}

class UnknownNutrientError extends NutrientError {
  const UnknownNutrientError(super.message);
}

enum NutrientUnit { kilocalorie, gram, milligram, microgram }

extension NutrientUnitContract on NutrientUnit {
  String get stableId => switch (this) {
    NutrientUnit.kilocalorie => 'energy_kilocalorie',
    NutrientUnit.gram => 'mass_gram',
    NutrientUnit.milligram => 'mass_milligram',
    NutrientUnit.microgram => 'mass_microgram',
  };

  String get symbol => switch (this) {
    NutrientUnit.kilocalorie => 'kcal',
    NutrientUnit.gram => 'g',
    NutrientUnit.milligram => 'mg',
    NutrientUnit.microgram => 'µg',
  };

  String get displayLabel => switch (this) {
    NutrientUnit.kilocalorie => 'kilocalories',
    NutrientUnit.gram => 'grams',
    NutrientUnit.milligram => 'milligrams',
    NutrientUnit.microgram => 'micrograms',
  };

  static NutrientUnit fromStableId(String value) => switch (value) {
    'energy_kilocalorie' || 'kilocalorie' => NutrientUnit.kilocalorie,
    'mass_gram' || 'gram' => NutrientUnit.gram,
    'mass_milligram' || 'milligram' => NutrientUnit.milligram,
    'mass_microgram' || 'microgram' => NutrientUnit.microgram,
    _ => throw NutrientValidationError('Unknown nutrient unit: $value'),
  };
}

enum NutrientCategory {
  energy,
  macronutrient,
  micronutrient,
  vitamin,
  mineral,
  aminoAcid,
  other,
}

extension NutrientCategoryContract on NutrientCategory {
  String get stableId => switch (this) {
    NutrientCategory.energy => 'energy',
    NutrientCategory.macronutrient => 'macronutrient',
    NutrientCategory.micronutrient => 'micronutrient',
    NutrientCategory.vitamin => 'vitamin',
    NutrientCategory.mineral => 'mineral',
    NutrientCategory.aminoAcid => 'amino_acid',
    NutrientCategory.other => 'other',
  };

  static NutrientCategory fromStableId(String value) => switch (value) {
    'energy' => NutrientCategory.energy,
    'macronutrient' => NutrientCategory.macronutrient,
    'micronutrient' => NutrientCategory.micronutrient,
    'vitamin' => NutrientCategory.vitamin,
    'mineral' => NutrientCategory.mineral,
    'amino_acid' => NutrientCategory.aminoAcid,
    'other' => NutrientCategory.other,
    _ => throw NutrientValidationError('Unknown nutrient category: $value'),
  };
}

enum NutrientAggregationBehavior { additive }

extension NutrientAggregationContract on NutrientAggregationBehavior {
  String get stableId => 'additive';

  static NutrientAggregationBehavior fromStableId(String value) =>
      switch (value) {
        'additive' => NutrientAggregationBehavior.additive,
        _ => throw NutrientValidationError(
          'Unknown nutrient aggregation: $value',
        ),
      };
}

enum NutrientSupportState { supported, conditional, deprecated }

extension NutrientSupportContract on NutrientSupportState {
  String get stableId => name;

  static NutrientSupportState fromStableId(String value) => switch (value) {
    'supported' => NutrientSupportState.supported,
    'conditional' => NutrientSupportState.conditional,
    'deprecated' => NutrientSupportState.deprecated,
    _ => throw NutrientValidationError(
      'Unknown nutrient support state: $value',
    ),
  };
}

/// A stable registry definition. Display metadata is not identity.
class NutrientDefinition {
  final String id;
  final String machineId;
  final String displayName;
  final NutrientUnit unit;
  final NutrientCategory category;
  final int calculationPrecision;
  final int displayPrecision;
  final NutrientAggregationBehavior aggregation;
  final NutrientSupportState supportState;
  final bool deprecated;

  NutrientDefinition({
    required this.id,
    required this.machineId,
    required this.displayName,
    required this.unit,
    required this.category,
    required this.calculationPrecision,
    required this.displayPrecision,
    required this.aggregation,
    required this.supportState,
    required this.deprecated,
  }) {
    if (id.trim().isEmpty ||
        machineId.trim().isEmpty ||
        displayName.trim().isEmpty) {
      throw const NutrientValidationError(
        'Nutrient identifiers and display name are required.',
      );
    }
    if (calculationPrecision < 0 ||
        calculationPrecision > kQuantityMaxDecimalScale ||
        displayPrecision < 0 ||
        displayPrecision > kQuantityMaxDecimalScale) {
      throw const NutrientValidationError(
        'Nutrient precision is outside the supported range.',
      );
    }
    if (deprecated && supportState != NutrientSupportState.deprecated) {
      throw const NutrientValidationError(
        'Deprecated nutrients must use deprecated support state.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'machine_id': machineId,
    'display_name': displayName,
    'unit': unit.name,
    'category': category.stableId,
    'calculation_precision': calculationPrecision,
    'display_precision': displayPrecision,
    'aggregation': aggregation.stableId,
    'support_state': supportState.stableId,
    'deprecated': deprecated,
  };

  factory NutrientDefinition.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const NutrientValidationError('Nutrient definition is malformed.');
    }
    final id = raw['id'];
    final machineId = raw['machine_id'];
    final displayName = raw['display_name'];
    final calculationPrecision = raw['calculation_precision'];
    final displayPrecision = raw['display_precision'];
    final deprecated = raw['deprecated'];
    if (id is! String ||
        machineId is! String ||
        displayName is! String ||
        raw['unit'] is! String ||
        raw['category'] is! String ||
        calculationPrecision is! int ||
        displayPrecision is! int ||
        raw['aggregation'] is! String ||
        raw['support_state'] is! String ||
        deprecated is! bool) {
      throw const NutrientValidationError('Nutrient definition is malformed.');
    }
    return NutrientDefinition(
      id: id,
      machineId: machineId,
      displayName: displayName,
      unit: NutrientUnitContract.fromStableId(raw['unit'] as String),
      category: NutrientCategoryContract.fromStableId(
        raw['category'] as String,
      ),
      calculationPrecision: calculationPrecision,
      displayPrecision: displayPrecision,
      aggregation: NutrientAggregationContract.fromStableId(
        raw['aggregation'] as String,
      ),
      supportState: NutrientSupportContract.fromStableId(
        raw['support_state'] as String,
      ),
      deprecated: deprecated,
    );
  }
}

/// Immutable, atomically validated nutrient registry.
class NutrientRegistry {
  final int version;
  final List<NutrientDefinition> definitions;
  final Map<String, NutrientDefinition> _byId;
  final Map<String, NutrientDefinition> _byMachineId;

  NutrientRegistry._({
    required this.version,
    required List<NutrientDefinition> definitions,
  }) : definitions = List.unmodifiable(definitions),
       _byId = {
         for (final definition in definitions) definition.id: definition,
       },
       _byMachineId = {
         for (final definition in definitions) definition.machineId: definition,
       };

  factory NutrientRegistry({
    required int version,
    required Iterable<NutrientDefinition> definitions,
  }) {
    if (version != kNutrientRegistryVersion) {
      throw NutrientRegistryVersionError(
        'Unsupported nutrient registry version: $version',
      );
    }
    final entries = List<NutrientDefinition>.of(definitions);
    final ids = <String>{};
    final machineIds = <String>{};
    for (final definition in entries) {
      if (!ids.add(definition.id)) {
        throw NutrientValidationError(
          'Duplicate nutrient ID: ${definition.id}',
        );
      }
      if (!machineIds.add(definition.machineId)) {
        throw NutrientValidationError(
          'Duplicate nutrient machine ID: ${definition.machineId}',
        );
      }
    }
    return NutrientRegistry._(version: version, definitions: entries);
  }

  factory NutrientRegistry.fromJson(Object? raw) {
    if (raw is! Map ||
        raw['registry_version'] is! int ||
        raw['nutrients'] is! List) {
      throw const NutrientValidationError('Nutrient registry is malformed.');
    }
    // Parse and validate into a local collection before constructing the registry.
    final definitions = (raw['nutrients'] as List)
        .map(NutrientDefinition.fromJson)
        .toList(growable: false);
    return NutrientRegistry(
      version: raw['registry_version'] as int,
      definitions: definitions,
    );
  }

  factory NutrientRegistry.fromAssetFileSync(String path) {
    final decoded = jsonDecode(File(path).readAsStringSync());
    return NutrientRegistry.fromJson(decoded);
  }

  NutrientDefinition definitionFor(String nutrientId) {
    final value = _byId[nutrientId];
    if (value == null) {
      throw UnknownNutrientError('Unknown nutrient ID: $nutrientId');
    }
    return value;
  }

  NutrientDefinition definitionForMachineId(String machineId) {
    final value = _byMachineId[machineId];
    if (value == null) {
      throw UnknownNutrientError('Unknown nutrient machine ID: $machineId');
    }
    return value;
  }

  Map<String, dynamic> toJson() => {
    'registry_version': version,
    'nutrients': definitions
        .map((definition) => definition.toJson())
        .toList(growable: false),
  };

  String toJsonString() => jsonEncode(toJson());
}

enum NutrientFactStatus { known, knownZero, missing, notApplicable, estimated }

extension NutrientFactStatusContract on NutrientFactStatus {
  String get stableId => switch (this) {
    NutrientFactStatus.known => 'known',
    NutrientFactStatus.knownZero => 'known_zero',
    NutrientFactStatus.missing => 'missing',
    NutrientFactStatus.notApplicable => 'not_applicable',
    NutrientFactStatus.estimated => 'estimated',
  };

  static NutrientFactStatus fromStableId(String value) => switch (value) {
    'known' => NutrientFactStatus.known,
    'known_zero' => NutrientFactStatus.knownZero,
    'missing' => NutrientFactStatus.missing,
    'not_applicable' => NutrientFactStatus.notApplicable,
    'estimated' => NutrientFactStatus.estimated,
    _ => throw NutrientValidationError('Unknown nutrient fact status: $value'),
  };
}

enum NutrientSourceType {
  bundledCatalogue,
  regionalCatalogue,
  reviewedCatalogue,
  manufacturerLabel,
  userEntered,
  importedProvider,
  recipeCalculation,
  aiEstimate,
  heuristic,
  legacy,
  unknown,
}

extension NutrientSourceContract on NutrientSourceType {
  String get stableId => switch (this) {
    NutrientSourceType.bundledCatalogue => 'bundled_catalogue',
    NutrientSourceType.regionalCatalogue => 'regional_catalogue',
    NutrientSourceType.reviewedCatalogue => 'reviewed_catalogue',
    NutrientSourceType.manufacturerLabel => 'manufacturer_label',
    NutrientSourceType.userEntered => 'user_entered',
    NutrientSourceType.importedProvider => 'imported_provider',
    NutrientSourceType.recipeCalculation => 'recipe_calculation',
    NutrientSourceType.aiEstimate => 'ai_estimate',
    NutrientSourceType.heuristic => 'heuristic',
    NutrientSourceType.legacy => 'legacy',
    NutrientSourceType.unknown => 'unknown',
  };

  static NutrientSourceType fromStableId(String value) =>
      NutrientSourceType.values.firstWhere(
        (source) => source.stableId == value,
        orElse: () =>
            throw NutrientValidationError('Unknown nutrient source: $value'),
      );
}

enum NutrientConfidence { reviewed, high, medium, low, unknown, notProvided }

extension NutrientConfidenceContract on NutrientConfidence {
  String get stableId => switch (this) {
    NutrientConfidence.reviewed => 'reviewed',
    NutrientConfidence.high => 'high',
    NutrientConfidence.medium => 'medium',
    NutrientConfidence.low => 'low',
    NutrientConfidence.unknown => 'unknown',
    NutrientConfidence.notProvided => 'not_provided',
  };

  static NutrientConfidence fromStableId(String value) =>
      NutrientConfidence.values.firstWhere(
        (confidence) => confidence.stableId == value,
        orElse: () => throw NutrientValidationError(
          'Unknown nutrient confidence: $value',
        ),
      );
}

enum NutrientBasisKind { per100Grams, per100Millilitres, perServing, absolute }

extension NutrientBasisContract on NutrientBasisKind {
  String get stableId => switch (this) {
    NutrientBasisKind.per100Grams => 'per_100_grams',
    NutrientBasisKind.per100Millilitres => 'per_100_millilitres',
    NutrientBasisKind.perServing => 'per_serving',
    NutrientBasisKind.absolute => 'absolute',
  };

  static NutrientBasisKind fromStableId(String value) => switch (value) {
    'per_100_grams' => NutrientBasisKind.per100Grams,
    'per_100_millilitres' => NutrientBasisKind.per100Millilitres,
    'per_serving' => NutrientBasisKind.perServing,
    'absolute' => NutrientBasisKind.absolute,
    _ => throw NutrientValidationError('Unknown nutrient basis: $value'),
  };
}

class NutrientBasis {
  final NutrientBasisKind kind;
  final ServingDefinitionReference? servingDefinition;

  NutrientBasis(this.kind, {this.servingDefinition}) {
    if (kind == NutrientBasisKind.perServing && servingDefinition == null) {
      throw NutrientBasisMismatchError(
        'Per-serving facts require a serving definition.',
      );
    }
    if (kind != NutrientBasisKind.perServing && servingDefinition != null) {
      throw NutrientBasisMismatchError(
        'Only per-serving facts may carry a serving definition.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.stableId,
    if (servingDefinition != null)
      'serving_definition': servingDefinition!.toJson(),
  };

  factory NutrientBasis.fromJson(Object? raw) {
    if (raw is! Map || raw['kind'] is! String) {
      throw const NutrientBasisMismatchError('Nutrient basis is malformed.');
    }
    return NutrientBasis(
      NutrientBasisContract.fromStableId(raw['kind'] as String),
      servingDefinition: raw.containsKey('serving_definition')
          ? ServingDefinitionReference.fromJson(raw['serving_definition'])
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NutrientBasis &&
      kind == other.kind &&
      servingDefinition == other.servingDefinition;

  @override
  int get hashCode => Object.hash(kind, servingDefinition);
}

class NutrientAmount {
  final QuantityAmount value;
  final NutrientUnit unit;

  const NutrientAmount({required this.value, required this.unit});

  NutrientAmount add(NutrientAmount other) {
    if (unit != other.unit) {
      throw NutrientUnitMismatchError(
        'Cannot add ${other.unit.symbol} to ${unit.symbol}.',
      );
    }
    return NutrientAmount(value: value + other.value, unit: unit);
  }

  NutrientAmount multiply(QuantityAmount scalar) =>
      NutrientAmount(value: value.multiply(scalar), unit: unit);

  Map<String, dynamic> toJson() => {
    'value': value.toJsonValue(),
    'unit': unit.name,
  };

  factory NutrientAmount.fromJson(Object? raw) {
    if (raw is! Map || raw['value'] is! String || raw['unit'] is! String) {
      throw const NutrientValidationError('Nutrient amount is malformed.');
    }
    return NutrientAmount(
      value: QuantityAmount.fromString(raw['value'] as String),
      unit: NutrientUnitContract.fromStableId(raw['unit'] as String),
    );
  }
}

class NutrientFact {
  final String nutrientId;
  final NutrientUnit unit;
  final NutrientFactStatus status;
  final NutrientAmount? point;
  final NutrientAmount? lower;
  final NutrientAmount? upper;
  final NutrientBasis basis;
  final NutrientSourceType source;
  final String? sourceReference;
  final NutrientConfidence confidence;
  final String factVersion;
  final bool coverageIncomplete;

  NutrientFact({
    required this.nutrientId,
    required this.unit,
    required this.status,
    this.point,
    this.lower,
    this.upper,
    required this.basis,
    required this.source,
    this.sourceReference,
    this.confidence = NutrientConfidence.notProvided,
    required this.factVersion,
    this.coverageIncomplete = false,
  }) {
    _validateIntrinsic();
  }

  factory NutrientFact.known({
    required String nutrientId,
    required NutrientAmount point,
    required NutrientBasis basis,
    required NutrientSourceType source,
    String? sourceReference,
    NutrientConfidence confidence = NutrientConfidence.notProvided,
    String factVersion = '1',
    NutrientAmount? lower,
    NutrientAmount? upper,
  }) => NutrientFact(
    nutrientId: nutrientId,
    unit: point.unit,
    status: NutrientFactStatus.known,
    point: point,
    lower: lower,
    upper: upper,
    basis: basis,
    source: source,
    sourceReference: sourceReference,
    confidence: confidence,
    factVersion: factVersion,
  );

  factory NutrientFact.knownZero({
    required String nutrientId,
    required NutrientUnit unit,
    required NutrientBasis basis,
    required NutrientSourceType source,
    String? sourceReference,
    NutrientConfidence confidence = NutrientConfidence.notProvided,
    String factVersion = '1',
  }) => NutrientFact(
    nutrientId: nutrientId,
    unit: unit,
    status: NutrientFactStatus.knownZero,
    point: NutrientAmount(value: QuantityAmount.zero, unit: unit),
    basis: basis,
    source: source,
    sourceReference: sourceReference,
    confidence: confidence,
    factVersion: factVersion,
  );

  factory NutrientFact.missing({
    required String nutrientId,
    required NutrientUnit unit,
    required NutrientBasis basis,
    required NutrientSourceType source,
    String? sourceReference,
    NutrientConfidence confidence = NutrientConfidence.notProvided,
    String factVersion = '1',
  }) => NutrientFact(
    nutrientId: nutrientId,
    unit: unit,
    status: NutrientFactStatus.missing,
    basis: basis,
    source: source,
    sourceReference: sourceReference,
    confidence: confidence,
    factVersion: factVersion,
  );

  factory NutrientFact.notApplicable({
    required String nutrientId,
    required NutrientUnit unit,
    required NutrientBasis basis,
    required NutrientSourceType source,
    String? sourceReference,
    String factVersion = '1',
  }) => NutrientFact(
    nutrientId: nutrientId,
    unit: unit,
    status: NutrientFactStatus.notApplicable,
    basis: basis,
    source: source,
    sourceReference: sourceReference,
    factVersion: factVersion,
  );

  factory NutrientFact.estimated({
    required String nutrientId,
    required NutrientAmount point,
    required NutrientBasis basis,
    required NutrientSourceType source,
    String? sourceReference,
    NutrientConfidence confidence = NutrientConfidence.unknown,
    NutrientAmount? lower,
    NutrientAmount? upper,
    String factVersion = '1',
  }) => NutrientFact(
    nutrientId: nutrientId,
    unit: point.unit,
    status: NutrientFactStatus.estimated,
    point: point,
    lower: lower,
    upper: upper,
    basis: basis,
    source: source,
    sourceReference: sourceReference,
    confidence: confidence,
    factVersion: factVersion,
  );

  bool get hasNumericValue => point != null || lower != null || upper != null;
  bool get isAvailable =>
      (status == NutrientFactStatus.known ||
          status == NutrientFactStatus.knownZero ||
          status == NutrientFactStatus.estimated) &&
      hasNumericValue;

  void validateAgainst(NutrientRegistry registry) {
    final definition = registry.definitionFor(nutrientId);
    if (definition.unit != unit) {
      throw NutrientUnitMismatchError(
        '$nutrientId requires ${definition.unit.symbol}, received ${unit.symbol}.',
      );
    }
  }

  NutrientFact scaleBy(Quantity quantity) {
    final factor = basis._factorFor(quantity);
    NutrientAmount? scale(NutrientAmount? amount) => amount?.multiply(factor);
    return NutrientFact(
      nutrientId: nutrientId,
      unit: unit,
      status: status,
      point: scale(point),
      lower: scale(lower),
      upper: scale(upper),
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: source,
      sourceReference: sourceReference,
      confidence: confidence,
      factVersion: factVersion,
      coverageIncomplete: coverageIncomplete,
    );
  }

  String? displayPoint(NutrientRegistry registry) {
    if (point == null) return null;
    final definition = registry.definitionFor(nutrientId);
    return point!.value.format(decimalPlaces: definition.displayPrecision);
  }

  Map<String, dynamic> toJson() => {
    'contract_version': kNutrientFactContractVersion,
    'nutrient_id': nutrientId,
    'unit': unit.name,
    'status': status.stableId,
    if (point != null) 'point': point!.toJson(),
    if (lower != null) 'lower': lower!.toJson(),
    if (upper != null) 'upper': upper!.toJson(),
    'basis': basis.toJson(),
    'source': source.stableId,
    if (sourceReference != null) 'source_reference': sourceReference,
    'confidence': confidence.stableId,
    'fact_version': factVersion,
    'coverage_incomplete': coverageIncomplete,
  };

  String toJsonString() => jsonEncode(toJson());

  factory NutrientFact.fromJson(Object? raw, NutrientRegistry registry) {
    if (raw is! Map ||
        raw['contract_version'] != kNutrientFactContractVersion ||
        raw['nutrient_id'] is! String ||
        raw['unit'] is! String ||
        raw['status'] is! String ||
        raw['basis'] == null ||
        raw['source'] is! String ||
        raw['confidence'] is! String ||
        raw['fact_version'] is! String ||
        raw['coverage_incomplete'] is! bool) {
      throw const NutrientValidationError(
        'Nutrient fact is malformed or unsupported.',
      );
    }
    String? readReference() {
      final value = raw['source_reference'];
      if (value == null) return null;
      if (value is! String || value.isEmpty) {
        throw const NutrientValidationError(
          'Nutrient source reference is malformed.',
        );
      }
      return value;
    }

    final fact = NutrientFact(
      nutrientId: raw['nutrient_id'] as String,
      unit: NutrientUnitContract.fromStableId(raw['unit'] as String),
      status: NutrientFactStatusContract.fromStableId(raw['status'] as String),
      point: raw.containsKey('point')
          ? NutrientAmount.fromJson(raw['point'])
          : null,
      lower: raw.containsKey('lower')
          ? NutrientAmount.fromJson(raw['lower'])
          : null,
      upper: raw.containsKey('upper')
          ? NutrientAmount.fromJson(raw['upper'])
          : null,
      basis: NutrientBasis.fromJson(raw['basis']),
      source: NutrientSourceContract.fromStableId(raw['source'] as String),
      sourceReference: readReference(),
      confidence: NutrientConfidenceContract.fromStableId(
        raw['confidence'] as String,
      ),
      factVersion: raw['fact_version'] as String,
      coverageIncomplete: raw['coverage_incomplete'] as bool,
    );
    fact.validateAgainst(registry);
    return fact;
  }

  void _validateIntrinsic() {
    if (nutrientId.trim().isEmpty || factVersion.trim().isEmpty) {
      throw const NutrientValidationError(
        'Nutrient fact identifiers are required.',
      );
    }
    final amounts = [point, lower, upper].whereType<NutrientAmount>().toList();
    for (final amount in amounts) {
      if (amount.unit != unit) {
        throw const NutrientUnitMismatchError(
          'Nutrient fact amounts must use one unit.',
        );
      }
      if (amount.value.compareTo(QuantityAmount.zero) < 0) {
        throw const NutrientValidationError(
          'Nutrient values cannot be negative.',
        );
      }
    }
    if (status == NutrientFactStatus.missing ||
        status == NutrientFactStatus.notApplicable) {
      if (amounts.isNotEmpty) {
        throw const NutrientValidationError(
          'Missing and not-applicable facts cannot carry values.',
        );
      }
    } else if (amounts.isEmpty) {
      throw const NutrientValidationError(
        'A numeric nutrient fact requires a value or range.',
      );
    }
    if (status == NutrientFactStatus.known && point == null) {
      throw const NutrientValidationError('Known facts require a point value.');
    }
    if (status == NutrientFactStatus.knownZero) {
      if (point == null ||
          !point!.value.isZero ||
          (lower != null && !lower!.value.isZero) ||
          (upper != null && !upper!.value.isZero)) {
        throw const NutrientValidationError(
          'Known-zero facts must contain only zero values.',
        );
      }
    }
    if (lower != null &&
            point != null &&
            lower!.value.compareTo(point!.value) > 0 ||
        point != null &&
            upper != null &&
            point!.value.compareTo(upper!.value) > 0 ||
        lower != null &&
            upper != null &&
            lower!.value.compareTo(upper!.value) > 0) {
      throw const NutrientValidationError(
        'Nutrient bounds must be ordered lower ≤ point ≤ upper.',
      );
    }
  }
}

extension on NutrientBasis {
  QuantityAmount _factorFor(Quantity quantity) {
    switch (kind) {
      case NutrientBasisKind.per100Grams:
        if (quantity.dimension != QuantityDimension.mass) {
          throw const NutrientBasisMismatchError(
            'A per-100-gram fact requires a mass quantity.',
          );
        }
        final grams = quantity.convertTo(QuantityUnit.gram).amount;
        return grams.divide(QuantityAmount.fromBigInt(BigInt.from(100)));
      case NutrientBasisKind.per100Millilitres:
        if (quantity.dimension != QuantityDimension.volume) {
          throw const NutrientBasisMismatchError(
            'A per-100-millilitre fact requires a volume quantity.',
          );
        }
        final millilitres = quantity.convertTo(QuantityUnit.millilitre).amount;
        return millilitres.divide(QuantityAmount.fromBigInt(BigInt.from(100)));
      case NutrientBasisKind.perServing:
        if (quantity.unit != QuantityUnit.serving ||
            quantity.context.servingDefinition != servingDefinition) {
          throw const NutrientBasisMismatchError(
            'A per-serving fact requires the matching serving definition.',
          );
        }
        return quantity.amount;
      case NutrientBasisKind.absolute:
        throw const NutrientBasisMismatchError(
          'An absolute fact cannot be scaled without an explicit basis.',
        );
    }
  }
}

enum NutrientCompletenessState {
  complete,
  partial,
  unknown,
  notApplicable,
  invalid,
}

class NutrientCompleteness {
  final NutrientCompletenessState state;
  final List<String> requestedNutrientIds;
  final List<String> availableNutrientIds;
  final List<String> missingNutrientIds;
  final List<String> estimatedNutrientIds;
  final List<String> notApplicableNutrientIds;
  final List<String> partiallyKnownNutrientIds;

  NutrientCompleteness({
    required this.state,
    required Iterable<String> requestedNutrientIds,
    required Iterable<String> availableNutrientIds,
    required Iterable<String> missingNutrientIds,
    required Iterable<String> estimatedNutrientIds,
    required Iterable<String> notApplicableNutrientIds,
    required Iterable<String> partiallyKnownNutrientIds,
  }) : requestedNutrientIds = _sorted(requestedNutrientIds),
       availableNutrientIds = _sorted(availableNutrientIds),
       missingNutrientIds = _sorted(missingNutrientIds),
       estimatedNutrientIds = _sorted(estimatedNutrientIds),
       notApplicableNutrientIds = _sorted(notApplicableNutrientIds),
       partiallyKnownNutrientIds = _sorted(partiallyKnownNutrientIds);

  static List<String> _sorted(Iterable<String> values) =>
      List.unmodifiable(values.toSet().toList()..sort());

  Map<String, dynamic> toJson() => {
    'state': state.name,
    'requested': requestedNutrientIds,
    'available': availableNutrientIds,
    'missing': missingNutrientIds,
    'estimated': estimatedNutrientIds,
    'not_applicable': notApplicableNutrientIds,
    'partially_known': partiallyKnownNutrientIds,
  };

  factory NutrientCompleteness.fromJson(Object? raw) {
    if (raw is! Map ||
        raw['state'] is! String ||
        raw['requested'] is! List ||
        raw['available'] is! List ||
        raw['missing'] is! List ||
        raw['estimated'] is! List ||
        raw['not_applicable'] is! List ||
        raw['partially_known'] is! List) {
      throw const NutrientValidationError(
        'Nutrient completeness is malformed.',
      );
    }
    final states = NutrientCompletenessState.values.where(
      (value) => value.name == raw['state'],
    );
    if (states.isEmpty) {
      throw NutrientValidationError(
        'Unknown nutrient completeness state: ${raw['state']}',
      );
    }
    List<String> readIds(String key) {
      final values = raw[key] as List;
      if (values.any((value) => value is! String)) {
        throw NutrientValidationError(
          'Nutrient completeness field $key is malformed.',
        );
      }
      return values.cast<String>();
    }

    return NutrientCompleteness(
      state: states.single,
      requestedNutrientIds: readIds('requested'),
      availableNutrientIds: readIds('available'),
      missingNutrientIds: readIds('missing'),
      estimatedNutrientIds: readIds('estimated'),
      notApplicableNutrientIds: readIds('not_applicable'),
      partiallyKnownNutrientIds: readIds('partially_known'),
    );
  }
}

class NutrientCompletenessEvaluator {
  NutrientCompletenessEvaluator._();

  static NutrientCompleteness evaluate({
    required NutrientRegistry registry,
    required Map<String, NutrientFact> facts,
    Set<String>? requestedNutrientIds,
  }) {
    final requested =
        requestedNutrientIds ??
        registry.definitions.map((definition) => definition.id).toSet();
    for (final id in requested) {
      registry.definitionFor(id);
    }
    for (final fact in facts.values) {
      fact.validateAgainst(registry);
    }
    final available = <String>{};
    final missing = <String>{};
    final estimated = <String>{};
    final notApplicable = <String>{};
    final partiallyKnown = <String>{};
    for (final id in requested) {
      final fact = facts[id];
      if (fact == null || fact.status == NutrientFactStatus.missing) {
        missing.add(id);
        continue;
      }
      if (fact.status == NutrientFactStatus.notApplicable) {
        notApplicable.add(id);
        continue;
      }
      if (fact.isAvailable) {
        available.add(id);
        if (fact.status == NutrientFactStatus.estimated) estimated.add(id);
        if (fact.coverageIncomplete) {
          partiallyKnown.add(id);
          missing.add(id);
        }
      } else {
        missing.add(id);
      }
    }
    final hasAvailable = available.isNotEmpty;
    final NutrientCompletenessState state;
    if (requested.isEmpty) {
      state = NutrientCompletenessState.invalid;
    } else if (!hasAvailable && notApplicable.length == requested.length) {
      state = NutrientCompletenessState.notApplicable;
    } else if (!hasAvailable) {
      state = NutrientCompletenessState.unknown;
    } else if (missing.isNotEmpty || partiallyKnown.isNotEmpty) {
      state = NutrientCompletenessState.partial;
    } else {
      state = NutrientCompletenessState.complete;
    }
    return NutrientCompleteness(
      state: state,
      requestedNutrientIds: requested,
      availableNutrientIds: available,
      missingNutrientIds: missing,
      estimatedNutrientIds: estimated,
      notApplicableNutrientIds: notApplicable,
      partiallyKnownNutrientIds: partiallyKnown,
    );
  }
}

class NutrientContribution {
  final NutrientFact fact;
  final Quantity? quantity;

  const NutrientContribution({required this.fact, this.quantity});
}

class NutrientAggregationResult {
  final Map<String, NutrientFact> facts;
  final NutrientCompleteness completeness;
  final Map<String, List<NutrientSourceType>> sourceLineage;
  final Map<String, List<String>> factVersionLineage;

  const NutrientAggregationResult({
    required this.facts,
    required this.completeness,
    required this.sourceLineage,
    required this.factVersionLineage,
  });

  String? displayValue(String nutrientId, NutrientRegistry registry) =>
      facts[nutrientId]?.displayPoint(registry);
}

class NutrientAggregationService {
  NutrientAggregationService._();

  static NutrientAggregationResult aggregate({
    required NutrientRegistry registry,
    required Iterable<NutrientContribution> contributions,
    Set<String>? requestedNutrientIds,
  }) {
    final grouped = <String, List<NutrientFact>>{};
    final sources = <String, Set<NutrientSourceType>>{};
    final versions = <String, Set<String>>{};
    for (final contribution in contributions) {
      final fact = contribution.fact;
      fact.validateAgainst(registry);
      final scaled = contribution.quantity == null
          ? _requireAbsolute(fact)
          : fact.scaleBy(contribution.quantity!);
      grouped.putIfAbsent(scaled.nutrientId, () => []).add(scaled);
      sources.putIfAbsent(scaled.nutrientId, () => {}).add(scaled.source);
      versions.putIfAbsent(scaled.nutrientId, () => {}).add(scaled.factVersion);
    }
    final result = <String, NutrientFact>{};
    for (final id in grouped.keys.toList()..sort()) {
      result[id] = _combine(id, grouped[id]!, sources[id]!, versions[id]!);
    }
    final completeness = NutrientCompletenessEvaluator.evaluate(
      registry: registry,
      facts: result,
      requestedNutrientIds: requestedNutrientIds,
    );
    final sourceLineage = <String, List<NutrientSourceType>>{
      for (final entry in sources.entries)
        entry.key: List<NutrientSourceType>.unmodifiable(
          entry.value.toList()
            ..sort((a, b) => a.stableId.compareTo(b.stableId)),
        ),
    };
    final factVersionLineage = <String, List<String>>{
      for (final entry in versions.entries)
        entry.key: List<String>.unmodifiable(entry.value.toList()..sort()),
    };
    return NutrientAggregationResult(
      facts: Map.unmodifiable(result),
      completeness: completeness,
      sourceLineage: Map.unmodifiable(sourceLineage),
      factVersionLineage: Map.unmodifiable(factVersionLineage),
    );
  }

  static NutrientFact _requireAbsolute(NutrientFact fact) {
    if (fact.basis.kind != NutrientBasisKind.absolute) {
      throw const NutrientBasisMismatchError(
        'A non-absolute fact requires a typed quantity context.',
      );
    }
    return fact;
  }

  static NutrientFact _combine(
    String id,
    List<NutrientFact> facts,
    Set<NutrientSourceType> sources,
    Set<String> versions,
  ) {
    final unit = facts.first.unit;
    for (final fact in facts) {
      if (fact.unit != unit) {
        throw const NutrientUnitMismatchError(
          'Nutrient aggregation units do not match.',
        );
      }
    }
    final numeric = facts.where((fact) => fact.hasNumericValue).toList();
    final source = sources.length == 1
        ? sources.single
        : NutrientSourceType.unknown;
    final confidence = facts.length == 1
        ? facts.single.confidence
        : NutrientConfidence.unknown;
    final incomplete = facts.any(
      (fact) =>
          fact.coverageIncomplete || fact.status == NutrientFactStatus.missing,
    );
    final sourceReference = facts.length == 1
        ? facts.single.sourceReference
        : null;
    if (numeric.isEmpty) {
      final status =
          facts.every((fact) => fact.status == NutrientFactStatus.notApplicable)
          ? NutrientFactStatus.notApplicable
          : NutrientFactStatus.missing;
      return NutrientFact(
        nutrientId: id,
        unit: unit,
        status: status,
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: source,
        sourceReference: sourceReference,
        confidence: confidence,
        factVersion: _joinVersions(versions),
      );
    }
    final pointValues = numeric
        .map((fact) => fact.point)
        .whereType<NutrientAmount>()
        .toList();
    final lowerValues = numeric
        .map((fact) => fact.lower)
        .whereType<NutrientAmount>()
        .toList();
    final upperValues = numeric
        .map((fact) => fact.upper)
        .whereType<NutrientAmount>()
        .toList();
    final point = pointValues.length == numeric.length
        ? _sum(pointValues)
        : null;
    final lower = lowerValues.length == numeric.length
        ? _sum(lowerValues)
        : null;
    final upper = upperValues.length == numeric.length
        ? _sum(upperValues)
        : null;
    final status =
        numeric.any((fact) => fact.status == NutrientFactStatus.estimated)
        ? NutrientFactStatus.estimated
        : numeric.every((fact) => fact.status == NutrientFactStatus.knownZero)
        ? NutrientFactStatus.knownZero
        : NutrientFactStatus.known;
    return NutrientFact(
      nutrientId: id,
      unit: unit,
      status: status,
      point: point,
      lower: lower,
      upper: upper,
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: source,
      sourceReference: sourceReference,
      confidence: confidence,
      factVersion: (versions.toList()..sort()).join('+'),
      coverageIncomplete: incomplete,
    );
  }

  static NutrientAmount _sum(List<NutrientAmount> amounts) {
    var total = NutrientAmount(
      value: QuantityAmount.zero,
      unit: amounts.first.unit,
    );
    for (final amount in amounts) {
      total = total.add(amount);
    }
    return total;
  }

  static String _joinVersions(Iterable<String> versions) =>
      (versions.toList()..sort()).join('+');
}
