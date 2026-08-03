import 'dart:convert';

/// Version of the pure typed-quantity contract.
const int kTypedQuantityContractVersion = 1;

/// Version of the stable unit registry referenced by serialized quantities.
const int kTypedQuantityUnitRegistryVersion = 1;

/// Maximum number of fractional decimal places retained by calculations.
///
/// The quantity layer deliberately does not use binary floating point for
/// arithmetic. Values at API boundaries may be supplied as a [num], but are
/// immediately converted to this decimal representation.
const int kQuantityMaxDecimalScale = 12;

enum QuantityDimension {
  mass,
  volume,
  count,
  serving,
  householdReference,
  unknown,
  legacy,
}

enum QuantityUnit {
  milligram,
  gram,
  kilogram,
  millilitre,
  litre,
  piece,
  serving,
  householdReference,
  unknown,
  legacy,
}

enum QuantityPreparationState { unspecified, raw, cooked }

enum HouseholdResolutionState { unresolved, volumeResolved }

/// User-entered quantity boundaries owned by [NutritionQuantityService].
///
/// These contexts are deliberately separate from [QuantityDimension]. A
/// quantity keeps its typed unit and dimension while the caller chooses the
/// domain rule that applies to user input.
enum NutritionQuantityInputContext {
  foodLogConsumed,
  recipeIngredient,
  servingCount,
  userEnteredPortion,
}

extension NutritionQuantityInputContextLabels on NutritionQuantityInputContext {
  String get stableId => switch (this) {
    NutritionQuantityInputContext.foodLogConsumed => 'food_log_consumed',
    NutritionQuantityInputContext.recipeIngredient => 'recipe_ingredient',
    NutritionQuantityInputContext.servingCount => 'serving_count',
    NutritionQuantityInputContext.userEnteredPortion => 'user_entered_portion',
  };

  String get displayLabel => switch (this) {
    NutritionQuantityInputContext.foodLogConsumed => 'food-log quantity',
    NutritionQuantityInputContext.recipeIngredient => 'recipe ingredient',
    NutritionQuantityInputContext.servingCount => 'serving count',
    NutritionQuantityInputContext.userEnteredPortion => 'user-entered portion',
  };
}

/// A typed, recoverable quantity failure.
sealed class QuantityError implements Exception {
  final String message;

  const QuantityError(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class InvalidQuantityAmountError extends QuantityError {
  const InvalidQuantityAmountError(super.message);
}

class UnsupportedQuantityUnitError extends QuantityError {
  const UnsupportedQuantityUnitError(super.message);
}

class IncompatibleQuantityDimensionError extends QuantityError {
  const IncompatibleQuantityDimensionError(super.message);
}

class IncompatibleQuantityContextError extends QuantityError {
  const IncompatibleQuantityContextError(super.message);
}

class MissingDensityError extends QuantityError {
  const MissingDensityError(super.message);
}

class MissingPortionConversionError extends QuantityError {
  const MissingPortionConversionError(super.message);
}

class UnknownServingDefinitionError extends QuantityError {
  const UnknownServingDefinitionError(super.message);
}

class MissingHouseholdCalibrationError extends QuantityError {
  const MissingHouseholdCalibrationError(super.message);
}

class MissingContextualConversionError extends QuantityError {
  const MissingContextualConversionError(super.message);
}

class RawCookedConversionUnavailableError extends QuantityError {
  const RawCookedConversionUnavailableError(super.message);
}

class UnsupportedLegacyQuantityError extends QuantityError {
  const UnsupportedLegacyQuantityError(super.message);
}

class MalformedQuantityTextError extends QuantityError {
  const MalformedQuantityTextError(super.message);
}

class PrecisionOverflowError extends QuantityError {
  const PrecisionOverflowError(super.message);
}

/// A context-specific positive-input failure.
///
/// Core quantities intentionally allow zero for arithmetic and aggregation.
/// This error is raised only when a caller applies a positive user-input
/// boundary. The original typed amount, unit, and dimension are retained for
/// recovery and accessible error reporting.
class NonPositiveQuantityError extends QuantityError {
  final NutritionQuantityInputContext context;
  final QuantityAmount amount;
  final QuantityUnit unit;
  final QuantityDimension dimension;

  NonPositiveQuantityError({
    required this.context,
    required this.amount,
    required this.unit,
    required this.dimension,
  }) : super(
         '${context.displayLabel} must be greater than zero; '
         'received ${amount.toString()} ${QuantityUnitRegistry.definitionFor(unit).symbol}.',
       );
}

/// An exact non-negative decimal value.
///
/// `coefficient / 10^scale` is the represented value. Trailing zeroes are
/// removed, so equality and JSON serialization are deterministic.
class QuantityAmount implements Comparable<QuantityAmount> {
  final BigInt coefficient;
  final int scale;

  const QuantityAmount._({required this.coefficient, required this.scale});

  factory QuantityAmount.fromString(String input) {
    final value = input.trim();
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(value);
    if (match == null) {
      throw const InvalidQuantityAmountError(
        'Amount must be a finite, non-negative decimal.',
      );
    }
    return _fromDigits(match.group(1)!, match.group(2) ?? '');
  }

  factory QuantityAmount.fromNum(num value) {
    if (!value.isFinite) {
      throw const InvalidQuantityAmountError('Amount must be finite.');
    }
    if (value < 0) {
      throw const InvalidQuantityAmountError(
        'Negative quantities are not supported.',
      );
    }
    if (value == 0) return QuantityAmount.zero;
    return QuantityAmount.fromString(_expandScientific(value.toString()));
  }

  factory QuantityAmount.fromBigInt(BigInt value) {
    if (value < BigInt.zero) {
      throw const InvalidQuantityAmountError(
        'Negative quantities are not supported.',
      );
    }
    return QuantityAmount._(coefficient: value, scale: 0);
  }

  static QuantityAmount _fromDigits(String integerPart, String fractionPart) {
    final digits = '$integerPart$fractionPart';
    return _fromCoefficientScale(BigInt.parse(digits), fractionPart.length);
  }

  static QuantityAmount _fromCoefficientScale(BigInt coefficient, int scale) {
    if (coefficient < BigInt.zero) {
      throw const InvalidQuantityAmountError(
        'Negative quantities are not supported.',
      );
    }
    while (scale > 0 &&
        coefficient != BigInt.zero &&
        coefficient % BigInt.from(10) == BigInt.zero) {
      coefficient ~/= BigInt.from(10);
      scale--;
    }
    if (scale > kQuantityMaxDecimalScale) {
      throw const PrecisionOverflowError(
        'Amount exceeds the supported decimal precision.',
      );
    }
    if (coefficient == BigInt.zero) scale = 0;
    return QuantityAmount._(coefficient: coefficient, scale: scale);
  }

  static QuantityAmount fromRational(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) {
      throw const InvalidQuantityAmountError('Division by zero.');
    }
    if (numerator < BigInt.zero && denominator > BigInt.zero ||
        numerator > BigInt.zero && denominator < BigInt.zero) {
      throw const InvalidQuantityAmountError(
        'A quantity calculation produced a negative amount.',
      );
    }
    if (numerator == BigInt.zero) return QuantityAmount.zero;

    final positiveNumerator = numerator.abs();
    final positiveDenominator = denominator.abs();
    final scaleFactor = _pow10(kQuantityMaxDecimalScale);
    final scaled = positiveNumerator * scaleFactor;
    var coefficient = scaled ~/ positiveDenominator;
    final remainder = scaled % positiveDenominator;
    if (remainder * BigInt.two >= positiveDenominator) {
      coefficient += BigInt.one;
    }
    return _fromCoefficientScale(coefficient, kQuantityMaxDecimalScale);
  }

  static final zero = QuantityAmount._(coefficient: BigInt.zero, scale: 0);

  static final one = QuantityAmount._(coefficient: BigInt.one, scale: 0);

  bool get isZero => coefficient == BigInt.zero;

  double get asDouble => double.parse(toString());

  String toJsonValue() => toString();

  factory QuantityAmount.fromJsonValue(Object? value) {
    if (value is! String) {
      throw const FormatException('Quantity amount must be a decimal string.');
    }
    return QuantityAmount.fromString(value);
  }

  QuantityAmount operator +(QuantityAmount other) {
    final targetScale = scale > other.scale ? scale : other.scale;
    final left = coefficient * _pow10(targetScale - scale);
    final right = other.coefficient * _pow10(targetScale - other.scale);
    return _fromCoefficientScale(left + right, targetScale);
  }

  QuantityAmount subtract(QuantityAmount other) {
    final targetScale = scale > other.scale ? scale : other.scale;
    final left = coefficient * _pow10(targetScale - scale);
    final right = other.coefficient * _pow10(targetScale - other.scale);
    final difference = left - right;
    if (difference < BigInt.zero) {
      throw const InvalidQuantityAmountError(
        'Subtraction cannot produce a negative quantity.',
      );
    }
    return _fromCoefficientScale(difference, targetScale);
  }

  QuantityAmount multiply(QuantityAmount scalar) {
    return _fromCoefficientScale(
      coefficient * scalar.coefficient,
      scale + scalar.scale,
    );
  }

  QuantityAmount divide(QuantityAmount scalar) {
    if (scalar.isZero) {
      throw const InvalidQuantityAmountError('Cannot divide by zero.');
    }
    final numerator = coefficient * _pow10(scalar.scale);
    final denominator = _pow10(scale) * scalar.coefficient;
    return fromRational(numerator, denominator);
  }

  @override
  int compareTo(QuantityAmount other) {
    final targetScale = scale > other.scale ? scale : other.scale;
    final left = coefficient * _pow10(targetScale - scale);
    final right = other.coefficient * _pow10(targetScale - other.scale);
    return left.compareTo(right);
  }

  String format({int? decimalPlaces}) {
    if (decimalPlaces == null) return toString();
    if (decimalPlaces < 0 || decimalPlaces > kQuantityMaxDecimalScale) {
      throw const PrecisionOverflowError(
        'Display precision is outside the supported range.',
      );
    }
    var roundedCoefficient = coefficient;
    if (scale > decimalPlaces) {
      final divisor = _pow10(scale - decimalPlaces);
      final quotient = coefficient ~/ divisor;
      final remainder = coefficient % divisor;
      roundedCoefficient = remainder * BigInt.two >= divisor
          ? quotient + BigInt.one
          : quotient;
    } else if (scale < decimalPlaces) {
      roundedCoefficient *= _pow10(decimalPlaces - scale);
    }
    final text = roundedCoefficient.toString().padLeft(decimalPlaces + 1, '0');
    if (decimalPlaces == 0) return text;
    final split = text.length - decimalPlaces;
    return '${text.substring(0, split)}.${text.substring(split)}';
  }

  @override
  String toString() {
    if (scale == 0) return coefficient.toString();
    final digits = coefficient.toString().padLeft(scale + 1, '0');
    final split = digits.length - scale;
    final result = '${digits.substring(0, split)}.${digits.substring(split)}';
    return result
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  bool operator ==(Object other) {
    return other is QuantityAmount &&
        coefficient == other.coefficient &&
        scale == other.scale;
  }

  @override
  int get hashCode => Object.hash(coefficient, scale);

  static BigInt _pow10(int exponent) {
    if (exponent < 0) {
      throw ArgumentError.value(exponent, 'exponent');
    }
    return BigInt.from(10).pow(exponent);
  }
}

String _expandScientific(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d+))?[eE]([+-]?\d+)$').firstMatch(value);
  if (match == null) return value;
  final integerPart = match.group(1)!;
  final fractionPart = match.group(2) ?? '';
  final exponent = int.parse(match.group(3)!);
  final digits = '$integerPart$fractionPart';
  final decimalIndex = integerPart.length + exponent;
  if (decimalIndex <= 0) {
    return '0.${'0' * -decimalIndex}$digits';
  }
  if (decimalIndex >= digits.length) {
    return '$digits${'0' * (decimalIndex - digits.length)}';
  }
  return '${digits.substring(0, decimalIndex)}.${digits.substring(decimalIndex)}';
}

class QuantityUnitDefinition {
  final QuantityUnit unit;
  final String stableId;
  final QuantityDimension dimension;
  final String symbol;
  final String displayLabel;
  final BigInt? baseNumerator;
  final BigInt? baseDenominator;

  const QuantityUnitDefinition({
    required this.unit,
    required this.stableId,
    required this.dimension,
    required this.symbol,
    required this.displayLabel,
    this.baseNumerator,
    this.baseDenominator,
  });

  bool get supportsDeterministicConversion =>
      baseNumerator != null && baseDenominator != null;
}

/// Stable typed unit registry. Aliases are explicit parser vocabulary; they
/// never change the stable IDs used in serialized quantities.
class QuantityUnitRegistry {
  QuantityUnitRegistry._();

  static final List<QuantityUnitDefinition> definitions = List.unmodifiable([
    QuantityUnitDefinition(
      unit: QuantityUnit.milligram,
      stableId: 'mass_milligram',
      dimension: QuantityDimension.mass,
      symbol: 'mg',
      displayLabel: 'milligrams',
      baseNumerator: BigInt.from(1),
      baseDenominator: BigInt.from(1),
    ),
    QuantityUnitDefinition(
      unit: QuantityUnit.gram,
      stableId: 'mass_gram',
      dimension: QuantityDimension.mass,
      symbol: 'g',
      displayLabel: 'grams',
      baseNumerator: BigInt.from(1000),
      baseDenominator: BigInt.from(1),
    ),
    QuantityUnitDefinition(
      unit: QuantityUnit.kilogram,
      stableId: 'mass_kilogram',
      dimension: QuantityDimension.mass,
      symbol: 'kg',
      displayLabel: 'kilograms',
      baseNumerator: BigInt.from(1000000),
      baseDenominator: BigInt.from(1),
    ),
    QuantityUnitDefinition(
      unit: QuantityUnit.millilitre,
      stableId: 'volume_millilitre',
      dimension: QuantityDimension.volume,
      symbol: 'mL',
      displayLabel: 'millilitres',
      baseNumerator: BigInt.from(1),
      baseDenominator: BigInt.from(1),
    ),
    QuantityUnitDefinition(
      unit: QuantityUnit.litre,
      stableId: 'volume_litre',
      dimension: QuantityDimension.volume,
      symbol: 'L',
      displayLabel: 'litres',
      baseNumerator: BigInt.from(1000),
      baseDenominator: BigInt.from(1),
    ),
    QuantityUnitDefinition(
      unit: QuantityUnit.piece,
      stableId: 'count_piece',
      dimension: QuantityDimension.count,
      symbol: 'piece',
      displayLabel: 'pieces',
      baseNumerator: BigInt.from(1),
      baseDenominator: BigInt.from(1),
    ),
    QuantityUnitDefinition(
      unit: QuantityUnit.serving,
      stableId: 'serving_contextual',
      dimension: QuantityDimension.serving,
      symbol: 'serving',
      displayLabel: 'servings',
    ),
    QuantityUnitDefinition(
      unit: QuantityUnit.householdReference,
      stableId: 'household_reference',
      dimension: QuantityDimension.householdReference,
      symbol: 'measure',
      displayLabel: 'household measures',
    ),
    QuantityUnitDefinition(
      unit: QuantityUnit.unknown,
      stableId: 'unknown_quantity',
      dimension: QuantityDimension.unknown,
      symbol: '?',
      displayLabel: 'unknown quantity',
    ),
    QuantityUnitDefinition(
      unit: QuantityUnit.legacy,
      stableId: 'legacy_quantity',
      dimension: QuantityDimension.legacy,
      symbol: 'legacy',
      displayLabel: 'legacy quantity',
    ),
  ]);

  static final Map<QuantityUnit, QuantityUnitDefinition> _byUnit = {
    for (final definition in definitions) definition.unit: definition,
  };

  static final Map<String, QuantityUnitDefinition> _byStableId = {
    for (final definition in definitions) definition.stableId: definition,
  };

  static final Map<String, QuantityUnitDefinition> _aliases = {
    for (final entry in <String, QuantityUnit>{
      'mg': QuantityUnit.milligram,
      'milligram': QuantityUnit.milligram,
      'milligrams': QuantityUnit.milligram,
      'g': QuantityUnit.gram,
      'gram': QuantityUnit.gram,
      'grams': QuantityUnit.gram,
      'kg': QuantityUnit.kilogram,
      'kilogram': QuantityUnit.kilogram,
      'kilograms': QuantityUnit.kilogram,
      'ml': QuantityUnit.millilitre,
      'millilitre': QuantityUnit.millilitre,
      'millilitres': QuantityUnit.millilitre,
      'milliliter': QuantityUnit.millilitre,
      'milliliters': QuantityUnit.millilitre,
      'l': QuantityUnit.litre,
      'litre': QuantityUnit.litre,
      'litres': QuantityUnit.litre,
      'liter': QuantityUnit.litre,
      'liters': QuantityUnit.litre,
      'piece': QuantityUnit.piece,
      'pieces': QuantityUnit.piece,
      'pc': QuantityUnit.piece,
      'item': QuantityUnit.piece,
      'items': QuantityUnit.piece,
      'serving': QuantityUnit.serving,
      'servings': QuantityUnit.serving,
      'household': QuantityUnit.householdReference,
      'household_reference': QuantityUnit.householdReference,
    }.entries)
      entry.key: _byUnit[entry.value]!,
  };

  static QuantityUnitDefinition definitionFor(QuantityUnit unit) {
    final definition = _byUnit[unit];
    if (definition == null) {
      throw UnsupportedQuantityUnitError('Unsupported unit: $unit');
    }
    return definition;
  }

  static QuantityUnitDefinition fromStableId(String stableId) {
    final definition = _byStableId[stableId];
    if (definition == null) {
      throw UnsupportedQuantityUnitError(
        'Unknown stable quantity unit identifier: $stableId',
      );
    }
    return definition;
  }

  static QuantityUnitDefinition resolveToken(String token) {
    final normalized = token.trim().toLowerCase();
    final definition = _aliases[normalized];
    if (definition == null) {
      throw UnsupportedQuantityUnitError('Unknown quantity unit: $token');
    }
    return definition;
  }
}

class ServingDefinitionReference {
  final String id;
  final String revision;
  final String? source;

  const ServingDefinitionReference({
    required this.id,
    required this.revision,
    this.source,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'revision': revision,
    if (source != null) 'source': source,
  };

  factory ServingDefinitionReference.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Serving definition reference is malformed.');
    }
    final id = raw['id'];
    final revision = raw['revision'];
    final source = raw['source'];
    if (id is! String ||
        id.isEmpty ||
        revision is! String ||
        revision.isEmpty ||
        source is! String? && source != null) {
      throw const FormatException('Serving definition reference is malformed.');
    }
    return ServingDefinitionReference(
      id: id,
      revision: revision,
      source: source as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ServingDefinitionReference &&
      id == other.id &&
      revision == other.revision &&
      source == other.source;

  @override
  int get hashCode => Object.hash(id, revision, source);
}

class HouseholdMeasureReference {
  final String measureType;
  final String? calibrationId;
  final HouseholdResolutionState resolutionState;

  const HouseholdMeasureReference({
    required this.measureType,
    this.calibrationId,
    this.resolutionState = HouseholdResolutionState.unresolved,
  });

  Map<String, dynamic> toJson() => {
    'measure_type': measureType,
    if (calibrationId != null) 'calibration_id': calibrationId,
    'resolution': resolutionState.name,
  };

  factory HouseholdMeasureReference.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Household measure reference is malformed.');
    }
    final measureType = raw['measure_type'];
    final calibrationId = raw['calibration_id'];
    final resolution = raw['resolution'];
    if (measureType is! String ||
        measureType.trim().isEmpty ||
        calibrationId is! String? && calibrationId != null ||
        resolution is! String) {
      throw const FormatException('Household measure reference is malformed.');
    }
    final state = switch (resolution) {
      'unresolved' => HouseholdResolutionState.unresolved,
      'volumeResolved' => HouseholdResolutionState.volumeResolved,
      _ => throw FormatException('Unknown household resolution: $resolution'),
    };
    return HouseholdMeasureReference(
      measureType: measureType,
      calibrationId: calibrationId as String?,
      resolutionState: state,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HouseholdMeasureReference &&
      measureType == other.measureType &&
      calibrationId == other.calibrationId &&
      resolutionState == other.resolutionState;

  @override
  int get hashCode => Object.hash(measureType, calibrationId, resolutionState);
}

/// Boundary for future food-specific conversions. This contract does not
/// populate or execute any of these records.
class QuantityConversionContext {
  final String? foodIdentityId;
  final String? servingDefinitionId;
  final String? densityRecordId;
  final String? portionRecordId;
  final String? vesselCalibrationId;
  final String? yieldTransformationId;
  final QuantityPreparationState preparationState;

  const QuantityConversionContext({
    this.foodIdentityId,
    this.servingDefinitionId,
    this.densityRecordId,
    this.portionRecordId,
    this.vesselCalibrationId,
    this.yieldTransformationId,
    this.preparationState = QuantityPreparationState.unspecified,
  });

  Map<String, dynamic> toJson() => {
    if (foodIdentityId != null) 'food_identity_id': foodIdentityId,
    if (servingDefinitionId != null)
      'serving_definition_id': servingDefinitionId,
    if (densityRecordId != null) 'density_record_id': densityRecordId,
    if (portionRecordId != null) 'portion_record_id': portionRecordId,
    if (vesselCalibrationId != null)
      'vessel_calibration_id': vesselCalibrationId,
    if (yieldTransformationId != null)
      'yield_transformation_id': yieldTransformationId,
    'preparation_state': preparationState.name,
  };

  factory QuantityConversionContext.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Quantity conversion context is malformed.');
    }
    String? readString(String key) {
      final value = raw[key];
      if (value == null) return null;
      if (value is! String || value.isEmpty) {
        throw FormatException('Quantity context field $key is malformed.');
      }
      return value;
    }

    final preparation = raw['preparation_state'];
    if (preparation is! String) {
      throw const FormatException('Quantity preparation state is malformed.');
    }
    final preparationState = switch (preparation) {
      'unspecified' => QuantityPreparationState.unspecified,
      'raw' => QuantityPreparationState.raw,
      'cooked' => QuantityPreparationState.cooked,
      _ => throw FormatException('Unknown preparation state: $preparation'),
    };
    return QuantityConversionContext(
      foodIdentityId: readString('food_identity_id'),
      servingDefinitionId: readString('serving_definition_id'),
      densityRecordId: readString('density_record_id'),
      portionRecordId: readString('portion_record_id'),
      vesselCalibrationId: readString('vessel_calibration_id'),
      yieldTransformationId: readString('yield_transformation_id'),
      preparationState: preparationState,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuantityConversionContext &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

class QuantityContext {
  final ServingDefinitionReference? servingDefinition;
  final HouseholdMeasureReference? householdMeasure;
  final QuantityConversionContext? conversion;
  final String? source;
  final String? sourceScope;
  final bool approximate;
  final bool legacy;

  const QuantityContext({
    this.servingDefinition,
    this.householdMeasure,
    this.conversion,
    this.source,
    this.sourceScope,
    this.approximate = false,
    this.legacy = false,
  });

  Map<String, dynamic> toJson() => {
    if (servingDefinition != null)
      'serving_definition': servingDefinition!.toJson(),
    if (householdMeasure != null)
      'household_measure': householdMeasure!.toJson(),
    if (conversion != null) 'conversion': conversion!.toJson(),
    if (source != null) 'source': source,
    if (sourceScope != null) 'source_scope': sourceScope,
    'approximate': approximate,
    'legacy': legacy,
  };

  factory QuantityContext.fromJson(Object? raw) {
    if (raw == null) return const QuantityContext();
    if (raw is! Map) {
      throw const FormatException('Quantity context is malformed.');
    }
    final source = raw['source'];
    final sourceScope = raw['source_scope'];
    final approximate = raw['approximate'];
    final legacy = raw['legacy'];
    if (source is! String? && source != null ||
        sourceScope is! String? && sourceScope != null ||
        approximate is! bool ||
        legacy is! bool) {
      throw const FormatException('Quantity context is malformed.');
    }
    return QuantityContext(
      servingDefinition: raw.containsKey('serving_definition')
          ? ServingDefinitionReference.fromJson(raw['serving_definition'])
          : null,
      householdMeasure: raw.containsKey('household_measure')
          ? HouseholdMeasureReference.fromJson(raw['household_measure'])
          : null,
      conversion: raw.containsKey('conversion')
          ? QuantityConversionContext.fromJson(raw['conversion'])
          : null,
      source: source as String?,
      sourceScope: sourceScope as String?,
      approximate: approximate,
      legacy: legacy,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuantityContext &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

class Quantity implements Comparable<Quantity> {
  final QuantityAmount amount;
  final QuantityUnit unit;
  final QuantityContext context;

  Quantity._({required this.amount, required this.unit, required this.context});

  factory Quantity({
    required QuantityAmount amount,
    required QuantityUnit unit,
    QuantityContext context = const QuantityContext(),
  }) {
    final definition = QuantityUnitRegistry.definitionFor(unit);
    if (unit == QuantityUnit.unknown || unit == QuantityUnit.legacy) {
      throw UnsupportedQuantityUnitError(
        'Unknown and legacy values require a legacy quantity wrapper.',
      );
    }
    if (unit == QuantityUnit.serving && context.servingDefinition == null) {
      throw const UnknownServingDefinitionError(
        'A serving quantity requires a serving definition reference.',
      );
    }
    if (unit == QuantityUnit.householdReference &&
        context.householdMeasure == null) {
      throw const MissingHouseholdCalibrationError(
        'A household quantity requires a typed measure reference.',
      );
    }
    if (definition.dimension == QuantityDimension.unknown ||
        definition.dimension == QuantityDimension.legacy) {
      throw UnsupportedQuantityUnitError(
        'Unit ${definition.stableId} cannot construct a typed quantity.',
      );
    }
    return Quantity._(amount: amount, unit: unit, context: context);
  }

  factory Quantity.fromDecimal({
    required String amount,
    required QuantityUnit unit,
    QuantityContext context = const QuantityContext(),
  }) {
    return Quantity(
      amount: QuantityAmount.fromString(amount),
      unit: unit,
      context: context,
    );
  }

  factory Quantity.fromNum({
    required num amount,
    required QuantityUnit unit,
    QuantityContext context = const QuantityContext(),
  }) {
    return Quantity(
      amount: QuantityAmount.fromNum(amount),
      unit: unit,
      context: context,
    );
  }

  factory Quantity.serving({
    required String amount,
    required ServingDefinitionReference definition,
    String? source,
    bool approximate = false,
  }) {
    return Quantity.fromDecimal(
      amount: amount,
      unit: QuantityUnit.serving,
      context: QuantityContext(
        servingDefinition: definition,
        source: source,
        approximate: approximate,
      ),
    );
  }

  factory Quantity.householdReference({
    required String count,
    required HouseholdMeasureReference reference,
    String? source,
    bool approximate = true,
  }) {
    return Quantity.fromDecimal(
      amount: count,
      unit: QuantityUnit.householdReference,
      context: QuantityContext(
        householdMeasure: reference,
        source: source,
        approximate: approximate,
      ),
    );
  }

  QuantityDimension get dimension =>
      QuantityUnitRegistry.definitionFor(unit).dimension;

  QuantityUnitDefinition get definition =>
      QuantityUnitRegistry.definitionFor(unit);

  bool get isZero => amount.isZero;

  Quantity convertTo(QuantityUnit targetUnit) {
    return QuantityConversionService.convert(this, targetUnit);
  }

  Quantity operator +(Quantity other) {
    _assertCompatibleContext(other);
    final converted = other.unit == unit ? other : other.convertTo(unit);
    return Quantity(
      amount: amount + converted.amount,
      unit: unit,
      context: context,
    );
  }

  Quantity operator -(Quantity other) {
    _assertCompatibleContext(other);
    final converted = other.unit == unit ? other : other.convertTo(unit);
    return Quantity(
      amount: amount.subtract(converted.amount),
      unit: unit,
      context: context,
    );
  }

  Quantity operator *(Object scalar) {
    return Quantity(
      amount: amount.multiply(_coerceScalar(scalar)),
      unit: unit,
      context: context,
    );
  }

  Quantity operator /(Object scalar) {
    return Quantity(
      amount: amount.divide(_coerceScalar(scalar)),
      unit: unit,
      context: context,
    );
  }

  Quantity multiplyBy(String scalar) =>
      this * QuantityAmount.fromString(scalar);

  Quantity divideBy(String scalar) => this / QuantityAmount.fromString(scalar);

  @override
  int compareTo(Quantity other) {
    _assertCompatibleContext(other);
    final converted = other.unit == unit ? other : other.convertTo(unit);
    return amount.compareTo(converted.amount);
  }

  Map<String, dynamic> toJson() => {
    'contract_version': kTypedQuantityContractVersion,
    'unit_registry_version': kTypedQuantityUnitRegistryVersion,
    'amount': amount.toJsonValue(),
    'unit': definition.stableId,
    'dimension': dimension.name,
    'context': context.toJson(),
  };

  factory Quantity.fromJson(Map<String, dynamic> json) {
    final version = json['contract_version'];
    if (version != kTypedQuantityContractVersion) {
      throw FormatException('Unsupported typed quantity contract: $version');
    }
    final registryVersion = json['unit_registry_version'];
    if (registryVersion != kTypedQuantityUnitRegistryVersion) {
      throw FormatException(
        'Unsupported typed quantity unit registry: $registryVersion',
      );
    }
    final amount = QuantityAmount.fromJsonValue(json['amount']);
    final unitId = json['unit'];
    if (unitId is! String) {
      throw const FormatException('Typed quantity unit is malformed.');
    }
    final definition = QuantityUnitRegistry.fromStableId(unitId);
    final dimension = json['dimension'];
    if (dimension != definition.dimension.name) {
      throw const FormatException(
        'Typed quantity dimension does not match its unit.',
      );
    }
    final context = QuantityContext.fromJson(json['context']);
    return Quantity(amount: amount, unit: definition.unit, context: context);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Quantity || dimension != other.dimension) return false;
    if (dimension == QuantityDimension.serving ||
        dimension == QuantityDimension.householdReference) {
      return unit == other.unit &&
          context == other.context &&
          amount == other.amount;
    }
    return _baseAmount == other._baseAmount;
  }

  @override
  int get hashCode => Object.hash(
    dimension,
    dimension == QuantityDimension.serving ||
            dimension == QuantityDimension.householdReference
        ? amount
        : _baseAmount,
    dimension == QuantityDimension.serving ||
            dimension == QuantityDimension.householdReference
        ? context
        : null,
  );

  QuantityAmount get _baseAmount {
    final numerator = definition.baseNumerator;
    final denominator = definition.baseDenominator;
    if (numerator == null || denominator == null) return amount;
    return QuantityAmount.fromRational(
      amount.coefficient * numerator,
      QuantityAmount._pow10(amount.scale) * denominator,
    );
  }

  void _assertCompatibleContext(Quantity other) {
    if (dimension != other.dimension) {
      throw IncompatibleQuantityDimensionError(
        'Cannot combine $dimension with ${other.dimension}.',
      );
    }
    if ((dimension == QuantityDimension.serving ||
            dimension == QuantityDimension.householdReference) &&
        context != other.context) {
      throw const IncompatibleQuantityContextError(
        'Contextual quantities require the same definition or reference.',
      );
    }
  }
}

/// Pure quantity arithmetic and validation owned by the nutrition domain.
///
/// [Quantity] itself remains suitable for zero-valued accumulators, known-zero
/// nutrient totals, subtraction that reaches zero, and empty aggregation.
/// Callers that accept user-entered food quantities must apply one of these
/// positive-input boundaries before persistence or calculation.
class NutritionQuantityService {
  NutritionQuantityService._();

  /// Validates a quantity for a positive user-input context and returns the
  /// same typed value unchanged on success.
  static Quantity validatePositive(
    Quantity quantity, {
    required NutritionQuantityInputContext context,
  }) {
    if (quantity.isZero) {
      throw NonPositiveQuantityError(
        context: context,
        amount: quantity.amount,
        unit: quantity.unit,
        dimension: quantity.dimension,
      );
    }
    return quantity;
  }

  static Quantity validatePositiveConsumedFoodLogQuantity(Quantity quantity) =>
      validatePositive(
        quantity,
        context: NutritionQuantityInputContext.foodLogConsumed,
      );

  static Quantity validatePositiveRecipeIngredientQuantity(Quantity quantity) =>
      validatePositive(
        quantity,
        context: NutritionQuantityInputContext.recipeIngredient,
      );

  static Quantity validatePositiveServingCount(Quantity quantity) =>
      validatePositive(
        quantity,
        context: NutritionQuantityInputContext.servingCount,
      );

  static Quantity validatePositiveUserEnteredPortion(Quantity quantity) =>
      validatePositive(
        quantity,
        context: NutritionQuantityInputContext.userEnteredPortion,
      );

  /// Short alias for callers that already identify the food-log boundary.
  static Quantity validatePositiveConsumedQuantity(Quantity quantity) =>
      validatePositiveConsumedFoodLogQuantity(quantity);

  /// Short alias for callers that already identify the recipe boundary.
  static Quantity validatePositiveRecipeIngredient(Quantity quantity) =>
      validatePositiveRecipeIngredientQuantity(quantity);
}

QuantityAmount _coerceScalar(Object scalar) {
  if (scalar is QuantityAmount) return scalar;
  if (scalar is num) return QuantityAmount.fromNum(scalar);
  if (scalar is String) return QuantityAmount.fromString(scalar);
  throw InvalidQuantityAmountError(
    'Scalar must be a decimal quantity amount, number, or string: $scalar',
  );
}

sealed class QuantityConversionResult {
  const QuantityConversionResult();
}

class QuantityConversionAvailable extends QuantityConversionResult {
  final Quantity value;

  const QuantityConversionAvailable(this.value);
}

class QuantityConversionUnavailable extends QuantityConversionResult {
  final Quantity source;
  final QuantityUnit targetUnit;
  final QuantityError error;

  const QuantityConversionUnavailable({
    required this.source,
    required this.targetUnit,
    required this.error,
  });
}

class QuantityConversionService {
  QuantityConversionService._();

  static Quantity convert(Quantity source, QuantityUnit targetUnit) {
    final target = QuantityUnitRegistry.definitionFor(targetUnit);
    if (source.unit == targetUnit) return source;

    if (source.dimension != target.dimension) {
      throw _crossDimensionError(source, target);
    }
    if (!source.definition.supportsDeterministicConversion ||
        !target.supportsDeterministicConversion) {
      throw const MissingContextualConversionError(
        'No deterministic conversion is defined for this contextual unit.',
      );
    }

    final amount = QuantityAmount.fromRational(
      source.amount.coefficient *
          source.definition.baseNumerator! *
          target.baseDenominator!,
      QuantityAmount._pow10(source.amount.scale) *
          source.definition.baseDenominator! *
          target.baseNumerator!,
    );
    return Quantity(amount: amount, unit: targetUnit, context: source.context);
  }

  static QuantityConversionResult tryConvert(
    Quantity source,
    QuantityUnit targetUnit,
  ) {
    try {
      return QuantityConversionAvailable(convert(source, targetUnit));
    } on QuantityError catch (error) {
      return QuantityConversionUnavailable(
        source: source,
        targetUnit: targetUnit,
        error: error,
      );
    }
  }

  static Quantity convertWithContext(
    Quantity source,
    QuantityUnit targetUnit, {
    QuantityConversionContext? context,
  }) {
    // Context is intentionally accepted at this boundary so later tasks can
    // supply reviewed records. B03-04 has no food-specific conversion rules,
    // so a context never silently creates one here.
    if (context?.preparationState == QuantityPreparationState.raw ||
        context?.preparationState == QuantityPreparationState.cooked) {
      throw const RawCookedConversionUnavailableError(
        'Raw/cooked transformations are deferred to a reviewed rule.',
      );
    }
    return convert(source, targetUnit);
  }

  static Quantity convertRawCooked(
    Quantity source,
    Quantity target, {
    QuantityConversionContext? context,
  }) {
    throw const RawCookedConversionUnavailableError(
      'Raw/cooked transformations are not available in B03-04.',
    );
  }

  static QuantityError _crossDimensionError(
    Quantity source,
    QuantityUnitDefinition target,
  ) {
    final sourceDimension = source.dimension;
    final targetDimension = target.dimension;
    if ((sourceDimension == QuantityDimension.mass &&
            targetDimension == QuantityDimension.volume) ||
        (sourceDimension == QuantityDimension.volume &&
            targetDimension == QuantityDimension.mass)) {
      return const MissingDensityError(
        'Mass and volume require a reviewed density record.',
      );
    }
    if ((sourceDimension == QuantityDimension.count &&
            targetDimension == QuantityDimension.mass) ||
        (sourceDimension == QuantityDimension.mass &&
            targetDimension == QuantityDimension.count)) {
      return const MissingPortionConversionError(
        'Count and mass require a food-specific portion definition.',
      );
    }
    if (sourceDimension == QuantityDimension.serving ||
        targetDimension == QuantityDimension.serving) {
      if (source.context.servingDefinition == null) {
        return const UnknownServingDefinitionError(
          'Serving conversion requires a serving definition.',
        );
      }
      return const MissingContextualConversionError(
        'Serving conversion requires a reviewed food-specific rule.',
      );
    }
    if (sourceDimension == QuantityDimension.householdReference ||
        targetDimension == QuantityDimension.householdReference) {
      return const MissingHouseholdCalibrationError(
        'Household conversion requires a reviewed calibration or context.',
      );
    }
    return IncompatibleQuantityDimensionError(
      'Cannot convert $sourceDimension to $targetDimension.',
    );
  }
}

class QuantityParser {
  QuantityParser._();

  static Quantity parse(
    String input, {
    ServingDefinitionReference? servingDefinition,
    HouseholdMeasureReference? householdReference,
  }) {
    final trimmed = input.trim();
    final match = RegExp(r'^(\d+(?:\.\d+)?)\s+([^\s]+)$').firstMatch(trimmed);
    if (match == null) {
      throw const MalformedQuantityTextError(
        'Quantity text must contain an amount and an explicit supported unit.',
      );
    }
    final amount = QuantityAmount.fromString(match.group(1)!);
    final definition = QuantityUnitRegistry.resolveToken(match.group(2)!);
    if (definition.unit == QuantityUnit.serving && servingDefinition == null) {
      throw const UnknownServingDefinitionError(
        'A serving token requires a serving definition.',
      );
    }
    if (definition.unit == QuantityUnit.householdReference &&
        householdReference == null) {
      throw const MissingHouseholdCalibrationError(
        'A household token requires a typed measure reference.',
      );
    }
    return Quantity(
      amount: amount,
      unit: definition.unit,
      context: QuantityContext(
        servingDefinition: servingDefinition,
        householdMeasure: householdReference,
      ),
    );
  }
}

class QuantityFormatter {
  QuantityFormatter._();

  static String format(
    Quantity quantity, {
    QuantityUnit? displayUnit,
    int? decimalPlaces,
  }) {
    final targetUnit = displayUnit ?? quantity.unit;
    final displayed = targetUnit == quantity.unit
        ? quantity
        : quantity.convertTo(targetUnit);
    final definition = QuantityUnitRegistry.definitionFor(targetUnit);
    final label = targetUnit == QuantityUnit.householdReference
        ? quantity.context.householdMeasure!.measureType
        : definition.displayLabel;
    return '${displayed.amount.format(decimalPlaces: decimalPlaces)} $label';
  }
}

/// A bounded edible-fraction value object. It is a future transformation input
/// only; B03-04 does not apply it to a food quantity.
class EdibleFractionBounds {
  final QuantityAmount? lower;
  final QuantityAmount? point;
  final QuantityAmount? upper;

  EdibleFractionBounds({this.lower, this.point, this.upper}) {
    if (lower == null && point == null && upper == null) {
      throw const InvalidQuantityAmountError(
        'An edible fraction must contain at least one bound.',
      );
    }
    for (final value in [lower, point, upper]) {
      if (value != null && value.compareTo(QuantityAmount.one) > 0) {
        throw const InvalidQuantityAmountError(
          'Edible fraction values must be between zero and one.',
        );
      }
    }
    if (lower != null && point != null && lower!.compareTo(point!) > 0 ||
        point != null && upper != null && point!.compareTo(upper!) > 0 ||
        lower != null && upper != null && lower!.compareTo(upper!) > 0) {
      throw const InvalidQuantityAmountError(
        'Edible fraction bounds must be ordered.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    if (lower != null) 'lower': lower!.toJsonValue(),
    if (point != null) 'point': point!.toJsonValue(),
    if (upper != null) 'upper': upper!.toJsonValue(),
  };
}
