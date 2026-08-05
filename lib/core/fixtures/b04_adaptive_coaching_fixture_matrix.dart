// B04-01 contract and fixture matrix.
//
// This file is intentionally a contract fixture, not a production model or
// calculator. It freezes the accepted B04 boundaries for later schema,
// repository, engine, safety, presentation and AI tasks.

const int kB04AdaptiveCoachingFixtureContractVersion = 1;
const String kB04HoldPolicyVersion = 'B04-D04-HOLD-1';
const String kB04EnabledPolicyVersion = 'B04-D04-ENABLED-1';
const String kB04ReadinessHoldPolicyVersion = 'B04-D04-READINESS-HOLD-1';
const String kB04TrendAlgorithmVersion = 'B04-D04-ENABLED-1-TREND-THEILSEN-V1';

enum B04FixtureCaseKind { positive, boundary, negative }

enum B04FixtureOutcome {
  available,
  onTrack,
  unavailable,
  invalidEvidence,
  policyBoundaryReached,
  rapidChangeReview,
  userTargetOutsideSupportedPolicy,
  expired,
  inactive,
}

enum B04LineageKind { appendOnly, effectiveDated, derivedProjection }

class B04Rational implements Comparable<B04Rational> {
  final BigInt numerator;
  final BigInt denominator;

  factory B04Rational(BigInt numerator, [BigInt? denominator]) {
    final rawDenominator = denominator ?? BigInt.one;
    if (rawDenominator == BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator', 'must be non-zero');
    }
    final sign = rawDenominator.isNegative ? -BigInt.one : BigInt.one;
    final positiveDenominator = rawDenominator * sign;
    final positiveNumerator = numerator * sign;
    final divisor = _gcd(positiveNumerator.abs(), positiveDenominator);
    return B04Rational._(
      positiveNumerator ~/ divisor,
      positiveDenominator ~/ divisor,
    );
  }

  B04Rational._(this.numerator, this.denominator);

  factory B04Rational.fromInt(int value) => B04Rational(BigInt.from(value));

  factory B04Rational.fromInts(int numerator, [int? denominator]) =>
      B04Rational(BigInt.from(numerator), BigInt.from(denominator ?? 1));

  factory B04Rational.parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed == 'NaN' ||
        trimmed == 'Infinity' ||
        trimmed == '-Infinity' ||
        trimmed == '+Infinity') {
      throw const FormatException('Value is not a finite decimal.');
    }
    final negative = trimmed.startsWith('-');
    final unsigned = (trimmed.startsWith('-') || trimmed.startsWith('+'))
        ? trimmed.substring(1)
        : trimmed;
    final parts = unsigned.split('.');
    if (parts.length > 2 || parts.any((part) => part.isEmpty)) {
      throw FormatException('Invalid decimal: $value');
    }
    final whole = BigInt.parse(parts.first);
    final fractionText = parts.length == 2 ? parts.last : '';
    final scale = fractionText.isEmpty
        ? BigInt.one
        : BigInt.from(10).pow(fractionText.length);
    final fraction = fractionText.isEmpty
        ? BigInt.zero
        : BigInt.parse(fractionText);
    final numerator = whole * scale + fraction;
    return B04Rational(negative ? -numerator : numerator, scale);
  }

  factory B04Rational.fromJson(dynamic value) {
    if (value is! Map) {
      throw const FormatException('Rational must be an object.');
    }
    final numerator = value['numerator'];
    final denominator = value['denominator'];
    if (numerator is! String || denominator is! String) {
      throw const FormatException(
        'Rational numerator/denominator are strings.',
      );
    }
    return B04Rational(BigInt.parse(numerator), BigInt.parse(denominator));
  }

  B04Rational operator +(B04Rational other) => B04Rational(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  B04Rational operator -(B04Rational other) => B04Rational(
    numerator * other.denominator - other.numerator * denominator,
    denominator * other.denominator,
  );

  B04Rational operator *(B04Rational other) =>
      B04Rational(numerator * other.numerator, denominator * other.denominator);

  B04Rational operator /(B04Rational other) =>
      B04Rational(numerator * other.denominator, denominator * other.numerator);

  B04Rational abs() =>
      numerator.isNegative ? B04Rational(-numerator, denominator) : this;

  BigInt floorInteger() {
    if (!numerator.isNegative) return numerator ~/ denominator;
    return -((-numerator + denominator - BigInt.one) ~/ denominator);
  }

  BigInt ceilInteger() {
    if (numerator.isNegative) return -((-numerator) ~/ denominator);
    return (numerator + denominator - BigInt.one) ~/ denominator;
  }

  BigInt roundAwayFromZero() {
    final absolute = numerator.abs();
    final quotient = absolute ~/ denominator;
    final remainder = absolute % denominator;
    final rounded = remainder * BigInt.from(2) >= denominator
        ? quotient + BigInt.one
        : quotient;
    return numerator.isNegative ? -rounded : rounded;
  }

  String get canonical => '$numerator/$denominator';

  Map<String, String> toJson() => {
    'numerator': numerator.toString(),
    'denominator': denominator.toString(),
  };

  @override
  int compareTo(B04Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  bool operator <(B04Rational other) => compareTo(other) < 0;

  bool operator <=(B04Rational other) => compareTo(other) <= 0;

  bool operator >(B04Rational other) => compareTo(other) > 0;

  bool operator >=(B04Rational other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is B04Rational && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => canonical;
}

BigInt _gcd(BigInt a, BigInt b) {
  var left = a;
  var right = b;
  while (right != BigInt.zero) {
    final remainder = left % right;
    left = right;
    right = remainder;
  }
  return left == BigInt.zero ? BigInt.one : left;
}

/// The typed numerical contract selected for the proposed first enabled
/// policy. This is fixture data, not an active runtime policy.
class B04EnabledPolicyContract {
  final String policyVersion;
  final int minimumAgeYears;
  final int evaluationWindowDays;
  final int minimumValidWeightDays;
  final int minimumWeightSpanDays;
  final int minimumFirstBlockWeightDays;
  final int minimumFinalBlockWeightDays;
  final int latestWeightFreshnessDays;
  final int minimumNutritionValidDays;
  final String nutritionCompletenessPercent;
  final String nutritionMaximumRangePercent;
  final int maintenanceFreshnessDays;
  final String maintenanceMaximumRangePercent;
  final List<String> supportedGoalRates;
  final Map<String, String> defaultGoalRates;
  final String lossGainDeadbandPercent;
  final String maintenanceDeadbandPercent;
  final String lossRapidChangePercent;
  final String gainRapidChangePercent;
  final int proposalStepKcal;
  final int proposalCadenceDays;
  final int proposalExpiryDays;
  final int aggregateWindowDays;
  final int aggregateMinimumKcal;
  final int aggregateMaximumKcal;
  final int lossMaximumDeficitKcal;
  final String lossMaximumDeficitPercent;
  final int lossMinimumFloorKcal;
  final String lossMinimumFloorPercent;
  final int gainMaximumSurplusKcal;
  final String gainMaximumSurplusPercent;
  final List<String> blockingActivationGates;
  final String unitRule;
  final String missingDataRule;
  final String overrideRule;

  const B04EnabledPolicyContract({
    required this.policyVersion,
    required this.minimumAgeYears,
    required this.evaluationWindowDays,
    required this.minimumValidWeightDays,
    required this.minimumWeightSpanDays,
    required this.minimumFirstBlockWeightDays,
    required this.minimumFinalBlockWeightDays,
    required this.latestWeightFreshnessDays,
    required this.minimumNutritionValidDays,
    required this.nutritionCompletenessPercent,
    required this.nutritionMaximumRangePercent,
    required this.maintenanceFreshnessDays,
    required this.maintenanceMaximumRangePercent,
    required this.supportedGoalRates,
    required this.defaultGoalRates,
    required this.lossGainDeadbandPercent,
    required this.maintenanceDeadbandPercent,
    required this.lossRapidChangePercent,
    required this.gainRapidChangePercent,
    required this.proposalStepKcal,
    required this.proposalCadenceDays,
    required this.proposalExpiryDays,
    required this.aggregateWindowDays,
    required this.aggregateMinimumKcal,
    required this.aggregateMaximumKcal,
    required this.lossMaximumDeficitKcal,
    required this.lossMaximumDeficitPercent,
    required this.lossMinimumFloorKcal,
    required this.lossMinimumFloorPercent,
    required this.gainMaximumSurplusKcal,
    required this.gainMaximumSurplusPercent,
    required this.blockingActivationGates,
    required this.unitRule,
    required this.missingDataRule,
    required this.overrideRule,
  });

  static const current = B04EnabledPolicyContract(
    policyVersion: kB04EnabledPolicyVersion,
    minimumAgeYears: 18,
    evaluationWindowDays: 21,
    minimumValidWeightDays: 10,
    minimumWeightSpanDays: 14,
    minimumFirstBlockWeightDays: 3,
    minimumFinalBlockWeightDays: 3,
    latestWeightFreshnessDays: 4,
    minimumNutritionValidDays: 14,
    nutritionCompletenessPercent: '80',
    nutritionMaximumRangePercent: '20',
    maintenanceFreshnessDays: 30,
    maintenanceMaximumRangePercent: '15',
    supportedGoalRates: [
      'loss:-0.25% body weight/week',
      'loss:-0.50% body weight/week',
      'maintenance:0.00% body weight/week',
      'gain:+0.10% body weight/week',
      'gain:+0.25% body weight/week',
    ],
    defaultGoalRates: {
      'loss': '-0.50% body weight/week',
      'maintenance': '0.00% body weight/week',
      'gain': '+0.25% body weight/week',
    },
    lossGainDeadbandPercent: '0.15',
    maintenanceDeadbandPercent: '0.25',
    lossRapidChangePercent: '-1.00',
    gainRapidChangePercent: '+0.50',
    proposalStepKcal: 100,
    proposalCadenceDays: 21,
    proposalExpiryDays: 7,
    aggregateWindowDays: 42,
    aggregateMinimumKcal: -200,
    aggregateMaximumKcal: 200,
    lossMaximumDeficitKcal: 500,
    lossMaximumDeficitPercent: '20',
    lossMinimumFloorKcal: 1200,
    lossMinimumFloorPercent: '80',
    gainMaximumSurplusKcal: 300,
    gainMaximumSurplusPercent: '15',
    blockingActivationGates: [
      'Product Owner approval',
      'fresh independent Sol High verdict',
      'policy branch merge',
      'explicit release/feature-policy selection',
    ],
    unitRule: 'Every numeric value is finite, unit-correct and in-domain.',
    missingDataRule:
        'Missing, invalid, stale or conflicting data is unavailable, never zero.',
    overrideRule:
        'User actions and AI cannot bypass safety or numerical boundaries.',
  );

  Map<String, dynamic> toJson() => {
    'policy_version': policyVersion,
    'minimum_age_years': minimumAgeYears,
    'evaluation_window_days': evaluationWindowDays,
    'minimum_valid_weight_days': minimumValidWeightDays,
    'minimum_weight_span_days': minimumWeightSpanDays,
    'minimum_first_block_weight_days': minimumFirstBlockWeightDays,
    'minimum_final_block_weight_days': minimumFinalBlockWeightDays,
    'latest_weight_freshness_days': latestWeightFreshnessDays,
    'minimum_nutrition_valid_days': minimumNutritionValidDays,
    'nutrition_completeness_percent': nutritionCompletenessPercent,
    'nutrition_maximum_range_percent': nutritionMaximumRangePercent,
    'maintenance_freshness_days': maintenanceFreshnessDays,
    'maintenance_maximum_range_percent': maintenanceMaximumRangePercent,
    'supported_goal_rates': supportedGoalRates,
    'default_goal_rates': defaultGoalRates,
    'loss_gain_deadband_percent': lossGainDeadbandPercent,
    'maintenance_deadband_percent': maintenanceDeadbandPercent,
    'loss_rapid_change_percent': lossRapidChangePercent,
    'gain_rapid_change_percent': gainRapidChangePercent,
    'proposal_step_kcal': proposalStepKcal,
    'proposal_cadence_days': proposalCadenceDays,
    'proposal_expiry_days': proposalExpiryDays,
    'aggregate_window_days': aggregateWindowDays,
    'aggregate_minimum_kcal': aggregateMinimumKcal,
    'aggregate_maximum_kcal': aggregateMaximumKcal,
    'loss_maximum_deficit_kcal': lossMaximumDeficitKcal,
    'loss_maximum_deficit_percent': lossMaximumDeficitPercent,
    'loss_minimum_floor_kcal': lossMinimumFloorKcal,
    'loss_minimum_floor_percent': lossMinimumFloorPercent,
    'gain_maximum_surplus_kcal': gainMaximumSurplusKcal,
    'gain_maximum_surplus_percent': gainMaximumSurplusPercent,
    'blocking_activation_gates': blockingActivationGates,
    'unit_rule': unitRule,
    'missing_data_rule': missingDataRule,
    'override_rule': overrideRule,
  };

  factory B04EnabledPolicyContract.fromJson(
    Map<String, dynamic> json,
  ) => B04EnabledPolicyContract(
    policyVersion: _string(json, 'policy_version'),
    minimumAgeYears: _int(json, 'minimum_age_years'),
    evaluationWindowDays: _int(json, 'evaluation_window_days'),
    minimumValidWeightDays: _int(json, 'minimum_valid_weight_days'),
    minimumWeightSpanDays: _int(json, 'minimum_weight_span_days'),
    minimumFirstBlockWeightDays: _int(json, 'minimum_first_block_weight_days'),
    minimumFinalBlockWeightDays: _int(json, 'minimum_final_block_weight_days'),
    latestWeightFreshnessDays: _int(json, 'latest_weight_freshness_days'),
    minimumNutritionValidDays: _int(json, 'minimum_nutrition_valid_days'),
    nutritionCompletenessPercent: _string(
      json,
      'nutrition_completeness_percent',
    ),
    nutritionMaximumRangePercent: _string(
      json,
      'nutrition_maximum_range_percent',
    ),
    maintenanceFreshnessDays: _int(json, 'maintenance_freshness_days'),
    maintenanceMaximumRangePercent: _string(
      json,
      'maintenance_maximum_range_percent',
    ),
    supportedGoalRates: _strings(json, 'supported_goal_rates'),
    defaultGoalRates: _stringMap(json, 'default_goal_rates'),
    lossGainDeadbandPercent: _string(json, 'loss_gain_deadband_percent'),
    maintenanceDeadbandPercent: _string(json, 'maintenance_deadband_percent'),
    lossRapidChangePercent: _string(json, 'loss_rapid_change_percent'),
    gainRapidChangePercent: _string(json, 'gain_rapid_change_percent'),
    proposalStepKcal: _int(json, 'proposal_step_kcal'),
    proposalCadenceDays: _int(json, 'proposal_cadence_days'),
    proposalExpiryDays: _int(json, 'proposal_expiry_days'),
    aggregateWindowDays: _int(json, 'aggregate_window_days'),
    aggregateMinimumKcal: _int(json, 'aggregate_minimum_kcal'),
    aggregateMaximumKcal: _int(json, 'aggregate_maximum_kcal'),
    lossMaximumDeficitKcal: _int(json, 'loss_maximum_deficit_kcal'),
    lossMaximumDeficitPercent: _string(json, 'loss_maximum_deficit_percent'),
    lossMinimumFloorKcal: _int(json, 'loss_minimum_floor_kcal'),
    lossMinimumFloorPercent: _string(json, 'loss_minimum_floor_percent'),
    gainMaximumSurplusKcal: _int(json, 'gain_maximum_surplus_kcal'),
    gainMaximumSurplusPercent: _string(json, 'gain_maximum_surplus_percent'),
    blockingActivationGates: _strings(json, 'blocking_activation_gates'),
    unitRule: _string(json, 'unit_rule'),
    missingDataRule: _string(json, 'missing_data_rule'),
    overrideRule: _string(json, 'override_rule'),
  );

  void validate() {
    final expected = B04EnabledPolicyContract.current;
    if (policyVersion != expected.policyVersion ||
        minimumAgeYears != expected.minimumAgeYears ||
        evaluationWindowDays != expected.evaluationWindowDays ||
        minimumValidWeightDays != expected.minimumValidWeightDays ||
        minimumWeightSpanDays != expected.minimumWeightSpanDays ||
        minimumFirstBlockWeightDays != expected.minimumFirstBlockWeightDays ||
        minimumFinalBlockWeightDays != expected.minimumFinalBlockWeightDays ||
        latestWeightFreshnessDays != expected.latestWeightFreshnessDays ||
        minimumNutritionValidDays != expected.minimumNutritionValidDays ||
        nutritionCompletenessPercent != expected.nutritionCompletenessPercent ||
        nutritionMaximumRangePercent != expected.nutritionMaximumRangePercent ||
        maintenanceFreshnessDays != expected.maintenanceFreshnessDays ||
        maintenanceMaximumRangePercent !=
            expected.maintenanceMaximumRangePercent ||
        !_sameStrings(supportedGoalRates, expected.supportedGoalRates) ||
        !_sameStringMap(defaultGoalRates, expected.defaultGoalRates) ||
        lossGainDeadbandPercent != expected.lossGainDeadbandPercent ||
        maintenanceDeadbandPercent != expected.maintenanceDeadbandPercent ||
        lossRapidChangePercent != expected.lossRapidChangePercent ||
        gainRapidChangePercent != expected.gainRapidChangePercent ||
        proposalStepKcal != expected.proposalStepKcal ||
        proposalCadenceDays != expected.proposalCadenceDays ||
        proposalExpiryDays != expected.proposalExpiryDays ||
        aggregateWindowDays != expected.aggregateWindowDays ||
        aggregateMinimumKcal != expected.aggregateMinimumKcal ||
        aggregateMaximumKcal != expected.aggregateMaximumKcal ||
        lossMaximumDeficitKcal != expected.lossMaximumDeficitKcal ||
        lossMaximumDeficitPercent != expected.lossMaximumDeficitPercent ||
        lossMinimumFloorKcal != expected.lossMinimumFloorKcal ||
        lossMinimumFloorPercent != expected.lossMinimumFloorPercent ||
        gainMaximumSurplusKcal != expected.gainMaximumSurplusKcal ||
        gainMaximumSurplusPercent != expected.gainMaximumSurplusPercent ||
        !_sameStrings(
          blockingActivationGates,
          expected.blockingActivationGates,
        ) ||
        unitRule != expected.unitRule ||
        missingDataRule != expected.missingDataRule ||
        overrideRule != expected.overrideRule) {
      throw StateError('B04 ENABLED-1 numerical contract changed.');
    }
  }
}

class B04RangeFixture {
  final String id;
  final String lower;
  final String upper;
  final String unit;
  final String? lowerUnit;
  final String? upperUnit;
  final B04FixtureOutcome expectedOutcome;
  final String expectedReason;

  const B04RangeFixture({
    required this.id,
    required this.lower,
    required this.upper,
    required this.unit,
    this.lowerUnit,
    this.upperUnit,
    required this.expectedOutcome,
    required this.expectedReason,
  });

  B04Rational? get width =>
      _validValues == null ? null : _validValues!.$2 - _validValues!.$1;

  B04Rational? get midpoint => _validValues == null
      ? null
      : (_validValues!.$1 + _validValues!.$2) / B04Rational.fromInt(2);

  B04Rational? get relativeWidthPercent {
    final rangeMidpoint = midpoint;
    final rangeWidth = width;
    if (rangeMidpoint == null || rangeWidth == null) return null;
    return rangeWidth / rangeMidpoint * B04Rational.fromInt(100);
  }

  (B04Rational, B04Rational)? get _validValues {
    try {
      final lowerValue = B04Rational.parse(lower);
      final upperValue = B04Rational.parse(upper);
      final normalizedLowerUnit = lowerUnit ?? unit;
      final normalizedUpperUnit = upperUnit ?? unit;
      if (unit.isEmpty ||
          normalizedLowerUnit.isEmpty ||
          normalizedUpperUnit.isEmpty ||
          normalizedLowerUnit != normalizedUpperUnit ||
          normalizedLowerUnit != unit ||
          lowerValue.numerator.isNegative ||
          upperValue.compareTo(lowerValue) < 0) {
        return null;
      }
      final rangeMidpoint = (lowerValue + upperValue) / B04Rational.fromInt(2);
      if (rangeMidpoint.numerator <= BigInt.zero) return null;
      return (lowerValue, upperValue);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lower': lower,
    'upper': upper,
    'unit': unit,
    'lower_unit': lowerUnit ?? unit,
    'upper_unit': upperUnit ?? unit,
    'expected_outcome': expectedOutcome.name,
    'expected_reason': expectedReason,
  };

  factory B04RangeFixture.fromJson(Map<String, dynamic> json) =>
      B04RangeFixture(
        id: _string(json, 'id'),
        lower: _string(json, 'lower'),
        upper: _string(json, 'upper'),
        unit: _string(json, 'unit'),
        lowerUnit: _optionalString(json, 'lower_unit'),
        upperUnit: _optionalString(json, 'upper_unit'),
        expectedOutcome: _outcome(json['expected_outcome']),
        expectedReason: _string(json, 'expected_reason'),
      );
}

class B04DailyWeightFixture {
  final int localDay;
  final int grams;

  const B04DailyWeightFixture({required this.localDay, required this.grams});

  Map<String, dynamic> toJson() => {'local_day': localDay, 'grams': grams};

  factory B04DailyWeightFixture.fromJson(Map<String, dynamic> json) =>
      B04DailyWeightFixture(
        localDay: _int(json, 'local_day'),
        grams: _int(json, 'grams'),
      );
}

class B04TrendFixture {
  final String id;
  final List<B04DailyWeightFixture> weights;
  final B04Rational expectedMedianGrams;
  final B04Rational expectedSlopeGramsPerDay;
  final B04Rational expectedWeeklyRatePercent;
  final String policyVersion;
  final String algorithmVersion;
  final String unit;
  final String timezone;
  final String effectivePeriod;

  const B04TrendFixture({
    required this.id,
    required this.weights,
    required this.expectedMedianGrams,
    required this.expectedSlopeGramsPerDay,
    required this.expectedWeeklyRatePercent,
    this.policyVersion = kB04EnabledPolicyVersion,
    this.algorithmVersion = kB04TrendAlgorithmVersion,
    this.unit = 'grams/day and percentage points/week',
    this.timezone = 'recorded IANA evaluation timezone',
    this.effectivePeriod = 'completed local civil days',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'weights': weights.map((item) => item.toJson()).toList(),
    'expected_median_grams': expectedMedianGrams.toJson(),
    'expected_slope_grams_per_day': expectedSlopeGramsPerDay.toJson(),
    'expected_weekly_rate_percent': expectedWeeklyRatePercent.toJson(),
    'policy_version': policyVersion,
    'algorithm_version': algorithmVersion,
    'unit': unit,
    'timezone': timezone,
    'effective_period': effectivePeriod,
  };

  factory B04TrendFixture.fromJson(Map<String, dynamic> json) =>
      B04TrendFixture(
        id: _string(json, 'id'),
        weights: _objects(json, 'weights', B04DailyWeightFixture.fromJson),
        expectedMedianGrams: B04Rational.fromJson(
          json['expected_median_grams'],
        ),
        expectedSlopeGramsPerDay: B04Rational.fromJson(
          json['expected_slope_grams_per_day'],
        ),
        expectedWeeklyRatePercent: B04Rational.fromJson(
          json['expected_weekly_rate_percent'],
        ),
        policyVersion: _stringOrDefault(
          json,
          'policy_version',
          kB04EnabledPolicyVersion,
        ),
        algorithmVersion: _stringOrDefault(
          json,
          'algorithm_version',
          kB04TrendAlgorithmVersion,
        ),
        unit: _stringOrDefault(
          json,
          'unit',
          'grams/day and percentage points/week',
        ),
        timezone: _stringOrDefault(
          json,
          'timezone',
          'recorded IANA evaluation timezone',
        ),
        effectivePeriod: _stringOrDefault(
          json,
          'effective_period',
          'completed local civil days',
        ),
      );
}

class B04MaintenanceNormalizationFixture {
  final String id;
  final String rawPointKcal;
  final int normalizedM;
  final int deficitCap;
  final int targetFloor;
  final int surplusCap;
  final int targetCeiling;
  final String policyVersion;
  final String unit;
  final String roundingRule;

  const B04MaintenanceNormalizationFixture({
    required this.id,
    required this.rawPointKcal,
    required this.normalizedM,
    required this.deficitCap,
    required this.targetFloor,
    required this.surplusCap,
    required this.targetCeiling,
    this.policyVersion = kB04EnabledPolicyVersion,
    this.unit = 'kcal/day',
    this.roundingRule = 'nearest whole kcal; halfway ties away from zero',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'raw_point_kcal': rawPointKcal,
    'normalized_m': normalizedM,
    'deficit_cap': deficitCap,
    'target_floor': targetFloor,
    'surplus_cap': surplusCap,
    'target_ceiling': targetCeiling,
    'policy_version': policyVersion,
    'unit': unit,
    'rounding_rule': roundingRule,
  };

  factory B04MaintenanceNormalizationFixture.fromJson(
    Map<String, dynamic> json,
  ) => B04MaintenanceNormalizationFixture(
    id: _string(json, 'id'),
    rawPointKcal: _string(json, 'raw_point_kcal'),
    normalizedM: _int(json, 'normalized_m'),
    deficitCap: _int(json, 'deficit_cap'),
    targetFloor: _int(json, 'target_floor'),
    surplusCap: _int(json, 'surplus_cap'),
    targetCeiling: _int(json, 'target_ceiling'),
    policyVersion: _stringOrDefault(
      json,
      'policy_version',
      kB04EnabledPolicyVersion,
    ),
    unit: _stringOrDefault(json, 'unit', 'kcal/day'),
    roundingRule: _stringOrDefault(
      json,
      'rounding_rule',
      'nearest whole kcal; halfway ties away from zero',
    ),
  );
}

class B04ContractReference {
  final String id;
  final String owner;
  final String description;
  final List<String> fixtureIds;
  final List<String> downstreamTasks;

  const B04ContractReference({
    required this.id,
    required this.owner,
    required this.description,
    required this.fixtureIds,
    required this.downstreamTasks,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner': owner,
    'description': description,
    'fixture_ids': fixtureIds,
    'downstream_tasks': downstreamTasks,
  };

  factory B04ContractReference.fromJson(Map<String, dynamic> json) =>
      B04ContractReference(
        id: _string(json, 'id'),
        owner: _string(json, 'owner'),
        description: _string(json, 'description'),
        fixtureIds: _strings(json, 'fixture_ids'),
        downstreamTasks: _strings(json, 'downstream_tasks'),
      );
}

class B04DecisionRecord {
  final String id;
  final String selectedOption;
  final String unit;
  final String effectivePeriod;
  final String boundaryRule;
  final String missingDataRule;
  final String policyVersion;
  final String overrideRule;
  final String negativeFixtureId;
  final List<String> affectedTasks;
  final bool blocking;

  const B04DecisionRecord({
    required this.id,
    required this.selectedOption,
    required this.unit,
    required this.effectivePeriod,
    required this.boundaryRule,
    required this.missingDataRule,
    required this.policyVersion,
    required this.overrideRule,
    required this.negativeFixtureId,
    required this.affectedTasks,
    required this.blocking,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'selected_option': selectedOption,
    'unit': unit,
    'effective_period': effectivePeriod,
    'boundary_rule': boundaryRule,
    'missing_data_rule': missingDataRule,
    'policy_version': policyVersion,
    'override_rule': overrideRule,
    'negative_fixture_id': negativeFixtureId,
    'affected_tasks': affectedTasks,
    'blocking': blocking,
  };

  factory B04DecisionRecord.fromJson(Map<String, dynamic> json) =>
      B04DecisionRecord(
        id: _string(json, 'id'),
        selectedOption: _string(json, 'selected_option'),
        unit: _string(json, 'unit'),
        effectivePeriod: _string(json, 'effective_period'),
        boundaryRule: _string(json, 'boundary_rule'),
        missingDataRule: _string(json, 'missing_data_rule'),
        policyVersion: _string(json, 'policy_version'),
        overrideRule: _string(json, 'override_rule'),
        negativeFixtureId: _string(json, 'negative_fixture_id'),
        affectedTasks: _strings(json, 'affected_tasks'),
        blocking: _bool(json, 'blocking'),
      );
}

class B04DecisionNegativeFixture {
  final String id;
  final String decisionId;
  final String scenario;
  final B04FixtureOutcome expectedOutcome;
  final String policyVersion;
  final int adaptiveDeltaKcal;
  final bool targetUnchanged;
  final bool historyUnchanged;

  const B04DecisionNegativeFixture({
    required this.id,
    required this.decisionId,
    required this.scenario,
    required this.expectedOutcome,
    required this.policyVersion,
    required this.adaptiveDeltaKcal,
    required this.targetUnchanged,
    required this.historyUnchanged,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'decision_id': decisionId,
    'scenario': scenario,
    'expected_outcome': expectedOutcome.name,
    'policy_version': policyVersion,
    'adaptive_delta_kcal': adaptiveDeltaKcal,
    'target_unchanged': targetUnchanged,
    'history_unchanged': historyUnchanged,
  };

  factory B04DecisionNegativeFixture.fromJson(Map<String, dynamic> json) =>
      B04DecisionNegativeFixture(
        id: _string(json, 'id'),
        decisionId: _string(json, 'decision_id'),
        scenario: _string(json, 'scenario'),
        expectedOutcome: _outcome(json['expected_outcome']),
        policyVersion: _string(json, 'policy_version'),
        adaptiveDeltaKcal: _int(json, 'adaptive_delta_kcal'),
        targetUnchanged: _bool(json, 'target_unchanged'),
        historyUnchanged: _bool(json, 'history_unchanged'),
      );
}

class B04StateFixture {
  final String id;
  final String state;
  final String inputCondition;
  final B04FixtureOutcome expectedOutcome;
  final String policyVersion;
  final B04LineageKind lineage;
  final int adaptiveDeltaKcal;
  final bool userSetTargetPreserved;

  const B04StateFixture({
    required this.id,
    required this.state,
    required this.inputCondition,
    required this.expectedOutcome,
    required this.policyVersion,
    required this.lineage,
    required this.adaptiveDeltaKcal,
    required this.userSetTargetPreserved,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'state': state,
    'input_condition': inputCondition,
    'expected_outcome': expectedOutcome.name,
    'policy_version': policyVersion,
    'lineage': lineage.name,
    'adaptive_delta_kcal': adaptiveDeltaKcal,
    'user_set_target_preserved': userSetTargetPreserved,
  };

  factory B04StateFixture.fromJson(Map<String, dynamic> json) =>
      B04StateFixture(
        id: _string(json, 'id'),
        state: _string(json, 'state'),
        inputCondition: _string(json, 'input_condition'),
        expectedOutcome: _outcome(json['expected_outcome']),
        policyVersion: _string(json, 'policy_version'),
        lineage: B04LineageKind.values.byName(_string(json, 'lineage')),
        adaptiveDeltaKcal: _int(json, 'adaptive_delta_kcal'),
        userSetTargetPreserved: _bool(json, 'user_set_target_preserved'),
      );
}

class B04EdgeFixture {
  final String id;
  final B04FixtureCaseKind kind;
  final String scenario;
  final String expectedResult;
  final List<String> policyVersions;
  final String unit;
  final String period;
  final String timezone;
  final String missingDataResult;
  final String overrideRule;
  final String evidenceReference;
  final Map<String, String> exactValues;

  const B04EdgeFixture({
    required this.id,
    required this.kind,
    required this.scenario,
    required this.expectedResult,
    required this.policyVersions,
    required this.unit,
    required this.period,
    required this.timezone,
    required this.missingDataResult,
    required this.overrideRule,
    required this.evidenceReference,
    required this.exactValues,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'scenario': scenario,
    'expected_result': expectedResult,
    'policy_versions': policyVersions,
    'unit': unit,
    'period': period,
    'timezone': timezone,
    'missing_data_result': missingDataResult,
    'override_rule': overrideRule,
    'evidence_reference': evidenceReference,
    'exact_values': exactValues,
  };

  factory B04EdgeFixture.fromJson(Map<String, dynamic> json) => B04EdgeFixture(
    id: _string(json, 'id'),
    kind: B04FixtureCaseKind.values.byName(_string(json, 'kind')),
    scenario: _string(json, 'scenario'),
    expectedResult: _string(json, 'expected_result'),
    policyVersions: _strings(json, 'policy_versions'),
    unit: _string(json, 'unit'),
    period: _string(json, 'period'),
    timezone: _string(json, 'timezone'),
    missingDataResult: _string(json, 'missing_data_result'),
    overrideRule: _string(json, 'override_rule'),
    evidenceReference: _string(json, 'evidence_reference'),
    exactValues: _stringMap(json, 'exact_values'),
  );
}

class B04AuthorityFixture {
  final String id;
  final String authority;
  final String owner;
  final String disposition;
  final bool duplicateCreated;

  const B04AuthorityFixture({
    required this.id,
    required this.authority,
    required this.owner,
    required this.disposition,
    required this.duplicateCreated,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'authority': authority,
    'owner': owner,
    'disposition': disposition,
    'duplicate_created': duplicateCreated,
  };

  factory B04AuthorityFixture.fromJson(Map<String, dynamic> json) =>
      B04AuthorityFixture(
        id: _string(json, 'id'),
        authority: _string(json, 'authority'),
        owner: _string(json, 'owner'),
        disposition: _string(json, 'disposition'),
        duplicateCreated: _bool(json, 'duplicate_created'),
      );
}

class B04DurableAuthorityFixture {
  final String name;
  final B04LineageKind lineage;
  final List<String> requiredFields;
  final List<String> indexes;
  final List<String> foreignKeys;
  final List<String> rejectedRestoreCases;
  final String correctionRule;

  const B04DurableAuthorityFixture({
    required this.name,
    required this.lineage,
    required this.requiredFields,
    required this.indexes,
    required this.foreignKeys,
    required this.rejectedRestoreCases,
    required this.correctionRule,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'lineage': lineage.name,
    'required_fields': requiredFields,
    'indexes': indexes,
    'foreign_keys': foreignKeys,
    'rejected_restore_cases': rejectedRestoreCases,
    'correction_rule': correctionRule,
  };

  factory B04DurableAuthorityFixture.fromJson(Map<String, dynamic> json) =>
      B04DurableAuthorityFixture(
        name: _string(json, 'name'),
        lineage: B04LineageKind.values.byName(_string(json, 'lineage')),
        requiredFields: _strings(json, 'required_fields'),
        indexes: _strings(json, 'indexes'),
        foreignKeys: _strings(json, 'foreign_keys'),
        rejectedRestoreCases: _strings(json, 'rejected_restore_cases'),
        correctionRule: _string(json, 'correction_rule'),
      );
}

class B04AdaptiveCoachingFixtureMatrix {
  final int version;
  final B04EnabledPolicyContract enabledPolicy;
  final List<B04ContractReference> outcomes;
  final List<B04DecisionRecord> decisions;
  final List<B04DecisionNegativeFixture> negativeFixtures;
  final List<B04EdgeFixture> enabledEdges;
  final List<B04StateFixture> states;
  final List<B04RangeFixture> ranges;
  final List<B04TrendFixture> trends;
  final List<B04MaintenanceNormalizationFixture> maintenance;
  final List<B04AuthorityFixture> authorities;
  final List<B04DurableAuthorityFixture> durableAuthorities;

  const B04AdaptiveCoachingFixtureMatrix({
    required this.version,
    required this.enabledPolicy,
    required this.outcomes,
    required this.decisions,
    required this.negativeFixtures,
    required this.enabledEdges,
    required this.states,
    required this.ranges,
    required this.trends,
    required this.maintenance,
    required this.authorities,
    required this.durableAuthorities,
  });

  static final current = _buildCurrentMatrix();

  Map<String, dynamic> toJson() => {
    'version': version,
    'enabled_policy': enabledPolicy.toJson(),
    'outcomes': outcomes.map((item) => item.toJson()).toList(),
    'decisions': decisions.map((item) => item.toJson()).toList(),
    'negative_fixtures': negativeFixtures.map((item) => item.toJson()).toList(),
    'enabled_edges': enabledEdges.map((item) => item.toJson()).toList(),
    'states': states.map((item) => item.toJson()).toList(),
    'ranges': ranges.map((item) => item.toJson()).toList(),
    'trends': trends.map((item) => item.toJson()).toList(),
    'maintenance': maintenance.map((item) => item.toJson()).toList(),
    'authorities': authorities.map((item) => item.toJson()).toList(),
    'durable_authorities': durableAuthorities
        .map((item) => item.toJson())
        .toList(),
  };

  factory B04AdaptiveCoachingFixtureMatrix.fromJson(dynamic payload) {
    if (payload is! Map) {
      throw const FormatException('B04 fixture matrix must be an object.');
    }
    final json = Map<String, dynamic>.from(payload);
    final version = json['version'];
    if (version != kB04AdaptiveCoachingFixtureContractVersion) {
      throw FormatException(
        'Unsupported B04 fixture matrix version: $version.',
      );
    }
    final matrix = B04AdaptiveCoachingFixtureMatrix(
      version: version as int,
      enabledPolicy: B04EnabledPolicyContract.fromJson(
        _map(json['enabled_policy'], 'enabled_policy'),
      ),
      outcomes: _objects(json, 'outcomes', B04ContractReference.fromJson),
      decisions: _objects(json, 'decisions', B04DecisionRecord.fromJson),
      negativeFixtures: _objects(
        json,
        'negative_fixtures',
        B04DecisionNegativeFixture.fromJson,
      ),
      enabledEdges: _objects(json, 'enabled_edges', B04EdgeFixture.fromJson),
      states: _objects(json, 'states', B04StateFixture.fromJson),
      ranges: _objects(json, 'ranges', B04RangeFixture.fromJson),
      trends: _objects(json, 'trends', B04TrendFixture.fromJson),
      maintenance: _objects(
        json,
        'maintenance',
        B04MaintenanceNormalizationFixture.fromJson,
      ),
      authorities: _objects(json, 'authorities', B04AuthorityFixture.fromJson),
      durableAuthorities: _objects(
        json,
        'durable_authorities',
        B04DurableAuthorityFixture.fromJson,
      ),
    );
    matrix.validate();
    return matrix;
  }

  void validate() {
    if (version != kB04AdaptiveCoachingFixtureContractVersion) {
      throw StateError('Unsupported B04 fixture matrix version: $version.');
    }
    _validateUnique('outcome', outcomes.map((item) => item.id));
    _validateUnique('decision', decisions.map((item) => item.id));
    _validateUnique(
      'decision negative fixture',
      negativeFixtures.map((item) => item.id),
    );
    _validateUnique('enabled edge', enabledEdges.map((item) => item.id));
    _validateUnique('state', states.map((item) => item.id));
    _validateUnique('range', ranges.map((item) => item.id));
    _validateUnique('trend', trends.map((item) => item.id));
    _validateUnique('maintenance fixture', maintenance.map((item) => item.id));
    enabledPolicy.validate();

    final fixtureIds = {
      ...enabledEdges.map((item) => item.id),
      ...states.map((item) => item.id),
    };
    for (final outcome in outcomes) {
      if (outcome.owner.isEmpty ||
          outcome.description.isEmpty ||
          outcome.fixtureIds.isEmpty ||
          outcome.downstreamTasks.isEmpty) {
        throw StateError('Outcome ${outcome.id} is missing traceability.');
      }
      if (!fixtureIds.containsAll(outcome.fixtureIds)) {
        throw StateError('Outcome ${outcome.id} references a missing fixture.');
      }
      if (outcome.downstreamTasks.any(
        (task) => !b04KnownTaskIds.contains(task),
      )) {
        throw StateError('Outcome ${outcome.id} references an unknown task.');
      }
    }

    final decisionIds = decisions.map((item) => item.id).toSet();
    if (decisionIds.length != 20 ||
        !decisionIds.containsAll(b04D04DecisionIds)) {
      throw StateError('B04-D04-01 through B04-D04-20 are required.');
    }
    final edgeIds = enabledEdges.map((item) => item.id).toSet();
    if (edgeIds.length != 47 || !edgeIds.containsAll(b04EnabledEdgeIds)) {
      throw StateError('B04 ENABLED-1 E01 through E47 are required.');
    }
    final negativeById = {
      for (final fixture in negativeFixtures) fixture.id: fixture,
    };
    final negativeDecisionIds = <String>{};
    for (final decision in decisions) {
      if (decision.selectedOption.isEmpty ||
          decision.unit.isEmpty ||
          decision.effectivePeriod.isEmpty ||
          decision.boundaryRule.isEmpty ||
          decision.missingDataRule.isEmpty ||
          decision.policyVersion.isEmpty ||
          decision.overrideRule.isEmpty ||
          decision.negativeFixtureId.isEmpty ||
          decision.affectedTasks.isEmpty ||
          !decision.blocking) {
        throw StateError('Decision ${decision.id} is incomplete.');
      }
      if (!b04KnownTaskIds.containsAll(decision.affectedTasks)) {
        throw StateError('Decision ${decision.id} has an unknown task.');
      }
      final negative = negativeById[decision.negativeFixtureId];
      if (negative == null || negative.decisionId != decision.id) {
        throw StateError('Decision ${decision.id} has no negative fixture.');
      }
      if (!negativeDecisionIds.add(negative.decisionId)) {
        throw StateError('Decision ${decision.id} shares a negative fixture.');
      }
    }
    if (negativeDecisionIds.length != 20 ||
        !negativeDecisionIds.containsAll(b04D04DecisionIds)) {
      throw StateError('Every D04 decision needs its own negative fixture.');
    }
    for (final negative in negativeFixtures) {
      if (!b04D04DecisionIds.contains(negative.decisionId) ||
          negative.id != _decisionNegativeFixtureId(negative.decisionId) ||
          negative.scenario.isEmpty ||
          negative.policyVersion.isEmpty ||
          (negative.policyVersion != kB04HoldPolicyVersion &&
              negative.policyVersion != kB04EnabledPolicyVersion &&
              negative.policyVersion != kB04ReadinessHoldPolicyVersion) ||
          (negative.expectedOutcome != B04FixtureOutcome.unavailable &&
              negative.expectedOutcome != B04FixtureOutcome.invalidEvidence) ||
          negative.adaptiveDeltaKcal != 0 ||
          !negative.targetUnchanged ||
          !negative.historyUnchanged) {
        throw StateError(
          'Decision negative fixture ${negative.id} is invalid.',
        );
      }
    }

    for (final edge in enabledEdges) {
      if (edge.scenario.isEmpty ||
          edge.expectedResult.isEmpty ||
          edge.policyVersions.isEmpty ||
          edge.policyVersions.any(
            (version) =>
                version != kB04HoldPolicyVersion &&
                version != kB04EnabledPolicyVersion &&
                version != kB04ReadinessHoldPolicyVersion,
          ) ||
          edge.unit.isEmpty ||
          edge.period.isEmpty ||
          edge.timezone.isEmpty ||
          edge.missingDataResult.isEmpty ||
          edge.overrideRule.isEmpty ||
          edge.evidenceReference.isEmpty ||
          edge.exactValues.keys.any(
            (key) => key.isEmpty || edge.exactValues[key]!.isEmpty,
          )) {
        throw StateError('Edge ${edge.id} is missing required metadata.');
      }
      if (edge.kind != _edgeKind(edge.id)) {
        throw StateError('Edge ${edge.id} has the wrong fixture kind.');
      }
    }

    final stateIds = states.map((item) => item.id).toSet();
    const requiredStates = {
      'hold-unavailable-zero-delta',
      'missing-required-evidence',
      'dangling-lineage',
      'dietary-possible-unavailable',
      'dietary-unknown-unavailable',
      'dietary-insufficient-unavailable',
      'unknown-nutrition-preserved',
      'range-crosses-decision-boundary',
      'missing-provenance-unavailable',
      'timezone-dst-local-date-frozen',
      'feedback-acknowledge-append-only',
      'feedback-override-user-set',
      'feedback-snooze-presentation-only',
    };
    if (!stateIds.containsAll(requiredStates)) {
      throw StateError('Required negative B04 state fixtures are missing.');
    }
    final hold = states.singleWhere(
      (item) => item.id == 'hold-unavailable-zero-delta',
    );
    if (hold.policyVersion != kB04HoldPolicyVersion ||
        hold.expectedOutcome != B04FixtureOutcome.unavailable ||
        hold.adaptiveDeltaKcal != 0 ||
        !hold.userSetTargetPreserved) {
      throw StateError('HOLD-1 must be unavailable with exactly zero delta.');
    }

    const requiredDurable = {
      'coaching_consent_events',
      'coaching_eligibility_evaluations',
    };
    final durableNames = durableAuthorities.map((item) => item.name).toSet();
    if (!durableNames.containsAll(requiredDurable)) {
      throw StateError('Required append-only B04 authorities are missing.');
    }
    for (final authority in authorities) {
      if (authority.duplicateCreated) {
        throw StateError(
          'B04 authority ${authority.id} duplicates a producer.',
        );
      }
    }
    for (final durable in durableAuthorities) {
      if (durable.lineage != B04LineageKind.appendOnly ||
          durable.requiredFields.isEmpty ||
          durable.indexes.isEmpty ||
          durable.foreignKeys.isEmpty ||
          durable.rejectedRestoreCases.isEmpty ||
          durable.correctionRule.isEmpty) {
        throw StateError('Durable authority ${durable.name} is incomplete.');
      }
    }
  }
}

const Set<String> b04KnownTaskIds = {
  'B04-01',
  'B04-02',
  'B04-03',
  'B04-04',
  'B04-05',
  'B04-06',
  'B04-07',
  'B04-08',
  'B04-09',
  'B04-10',
  'B04-11',
  'B04-12',
  'B04-13',
  'B04-14',
  'B04-15',
  'B04-16',
  'B04-17',
  'B04-18',
};

final List<String> b04D04DecisionIds = List.unmodifiable([
  for (var index = 1; index <= 20; index++)
    'B04-D04-${index.toString().padLeft(2, '0')}',
]);

final List<String> b04EnabledEdgeIds = List.unmodifiable([
  for (var index = 1; index <= 47; index++)
    'E${index.toString().padLeft(2, '0')}',
]);

String _decisionNegativeFixtureId(String decisionId) =>
    'd04-${decisionId.substring(8)}-negative';

List<B04DecisionNegativeFixture> _buildDecisionNegativeFixtures() => [
  const B04DecisionNegativeFixture(
    id: 'd04-01-negative',
    decisionId: 'B04-D04-01',
    scenario: 'missing or unverified age cannot enter adaptive eligibility',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-02-negative',
    decisionId: 'B04-D04-02',
    scenario: 'verified below-18 user receives coaching_unavailable_age',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-03-negative',
    decisionId: 'B04-D04-03',
    scenario: 'default-off coaching cannot be enabled by logging or inactivity',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04HoldPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-04-negative',
    decisionId: 'B04-D04-04',
    scenario: 'implicit bundled consent cannot enable coaching or AI',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04HoldPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-05-negative',
    decisionId: 'B04-D04-05',
    scenario: 'one observation or background trigger cannot change a target',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04HoldPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-06-negative',
    decisionId: 'B04-D04-06',
    scenario: 'single measurement cannot establish a trend window',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04HoldPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-07-negative',
    decisionId: 'B04-D04-07',
    scenario: 'missing required evidence never becomes zero or a default',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-08-negative',
    decisionId: 'B04-D04-08',
    scenario: 'HOLD-1 rejects a non-zero adjustment and aggregate delta',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04HoldPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-09-negative',
    decisionId: 'B04-D04-09',
    scenario: 'HOLD-1 rejects adaptive deficit, surplus, floor and ceiling',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04HoldPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-10-negative',
    decisionId: 'B04-D04-10',
    scenario: 'missing, stale or conflicting body metrics have no fallback',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-11-negative',
    decisionId: 'B04-D04-11',
    scenario: 'missing or partial nutrition remains non-numeric',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-12-negative',
    decisionId: 'B04-D04-12',
    scenario: 'denied or stale readiness remains unknown and has zero effect',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04ReadinessHoldPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-13-negative',
    decisionId: 'B04-D04-13',
    scenario:
        'free-form clinical or guarantee wording is not an approved state',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-14-negative',
    decisionId: 'B04-D04-14',
    scenario: 'medical restriction cannot be diagnosed or prescribed for',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-15-negative',
    decisionId: 'B04-D04-15',
    scenario:
        'confirmed strict conflict stays hard-blocked after override attempt',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-16-negative',
    decisionId: 'B04-D04-16',
    scenario:
        'possible, unknown or insufficient safety evidence is unavailable',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-17-negative',
    decisionId: 'B04-D04-17',
    scenario:
        'offline provider failure cannot invent evidence or queue a target',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-18-negative',
    decisionId: 'B04-D04-18',
    scenario:
        'malformed or conflicting AI cannot alter deterministic authority',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-19-negative',
    decisionId: 'B04-D04-19',
    scenario:
        'HOLD-1 has no adaptive proposal available for acceptance or override',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04HoldPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
  const B04DecisionNegativeFixture(
    id: 'd04-20-negative',
    decisionId: 'B04-D04-20',
    scenario:
        'holiday, location, clock or food history cannot infer N8 context',
    expectedOutcome: B04FixtureOutcome.unavailable,
    policyVersion: kB04EnabledPolicyVersion,
    adaptiveDeltaKcal: 0,
    targetUnchanged: true,
    historyUnchanged: true,
  ),
];

List<B04DecisionRecord> _buildDecisions() {
  final affected = <String, List<String>>{
    '01': ['B04-02', 'B04-05', 'B04-07', 'B04-13', 'B04-15', 'B04-17'],
    '02': [
      'B04-02',
      'B04-05',
      'B04-07',
      'B04-10',
      'B04-13',
      'B04-15',
      'B04-17',
    ],
    '03': ['B04-02', 'B04-05', 'B04-07', 'B04-13', 'B04-15', 'B04-17'],
    '04': ['B04-02', 'B04-05', 'B04-13', 'B04-14', 'B04-15', 'B04-17'],
    '05': [
      'B04-02',
      'B04-05',
      'B04-07',
      'B04-10',
      'B04-11',
      'B04-13',
      'B04-17',
    ],
    '06': [
      'B04-02',
      'B04-06',
      'B04-07',
      'B04-08',
      'B04-10',
      'B04-13',
      'B04-17',
    ],
    '07': [
      'B04-01',
      'B04-02',
      'B04-06',
      'B04-07',
      'B04-08',
      'B04-10',
      'B04-12',
      'B04-13',
      'B04-17',
    ],
    '08': ['B04-02', 'B04-07', 'B04-10', 'B04-13', 'B04-17'],
    '09': ['B04-02', 'B04-07', 'B04-10', 'B04-13', 'B04-15', 'B04-17'],
    '10': [
      'B04-01',
      'B04-06',
      'B04-07',
      'B04-08',
      'B04-10',
      'B04-13',
      'B04-15',
      'B04-17',
    ],
    '11': [
      'B04-01',
      'B04-07',
      'B04-08',
      'B04-10',
      'B04-12',
      'B04-13',
      'B04-15',
      'B04-17',
    ],
    '12': ['B04-01', 'B04-06', 'B04-07', 'B04-10', 'B04-13', 'B04-17'],
    '13': [
      'B04-02',
      'B04-09',
      'B04-10',
      'B04-12',
      'B04-13',
      'B04-14',
      'B04-15',
      'B04-17',
    ],
    '14': [
      'B04-02',
      'B04-09',
      'B04-10',
      'B04-12',
      'B04-13',
      'B04-14',
      'B04-15',
      'B04-17',
    ],
    '15': [
      'B04-01',
      'B04-09',
      'B04-10',
      'B04-12',
      'B04-13',
      'B04-14',
      'B04-15',
      'B04-16',
      'B04-17',
    ],
    '16': [
      'B04-01',
      'B04-08',
      'B04-09',
      'B04-10',
      'B04-12',
      'B04-13',
      'B04-15',
      'B04-17',
    ],
    '17': [
      'B04-01',
      'B04-08',
      'B04-10',
      'B04-12',
      'B04-13',
      'B04-14',
      'B04-15',
      'B04-16',
      'B04-17',
    ],
    '18': [
      'B04-01',
      'B04-10',
      'B04-13',
      'B04-14',
      'B04-15',
      'B04-16',
      'B04-17',
    ],
    '19': [
      'B04-05',
      'B04-07',
      'B04-09',
      'B04-10',
      'B04-11',
      'B04-12',
      'B04-13',
      'B04-15',
      'B04-16',
      'B04-17',
    ],
    '20': [
      'B04-01',
      'B04-02',
      'B04-08',
      'B04-10',
      'B04-13',
      'B04-14',
      'B04-15',
      'B04-17',
      'B04-18',
    ],
  };
  return [
    for (final id in b04D04DecisionIds)
      B04DecisionRecord(
        id: id,
        selectedOption: switch (id) {
          'B04-D04-01' => 'verified 18 completed years inclusive',
          'B04-D04-02' => 'below age is coaching_unavailable_age',
          'B04-D04-03' => 'adaptive coaching off by default',
          'B04-D04-04' => 'separate adaptive and optional AI consent',
          'B04-D04-05' => 'no background automatic target changes',
          'B04-D04-06' => 'versioned local civil day trend window',
          'B04-D04-07' => 'explicit evidence and completeness gate',
          'B04-D04-08' => 'HOLD-1 zero per-event and aggregate bounds',
          'B04-D04-09' => 'HOLD-1 no adaptive deficit or surplus',
          'B04-D04-10' => 'missing metrics remain typed and unavailable',
          'B04-D04-11' => 'B03 immutable nutrition read model only',
          'B04-D04-12' => 'readiness unknown suppresses numerical effects',
          'B04-D04-13' => 'reviewed deterministic wording catalog',
          'B04-D04-14' => 'exclude diagnosis treatment and guarantees',
          'B04-D04-15' => 'confirmed strict conflicts hard-block',
          'B04-D04-16' =>
            'possible and insufficient safety evidence unavailable',
          'B04-D04-17' => 'local deterministic offline behavior',
          'B04-D04-18' => 'AI wording-only optional adapter',
          'B04-D04-19' => 'append-only actions and explicit acceptance',
          _ => 'N8 remains conditional and uninferred',
        },
        unit: id == 'B04-D04-01' || id == 'B04-D04-02'
            ? 'completed years'
            : 'typed contract value',
        effectivePeriod: id == 'B04-D04-06'
            ? 'local civil day window'
            : 'future evaluations only',
        boundaryRule: id == 'B04-D04-01'
            ? 'inclusive 18th local birthday'
            : 'explicit recorded edge',
        missingDataRule:
            'missing, unknown, stale or conflicting remains unavailable',
        policyVersion: id == 'B04-D04-08' || id == 'B04-D04-09'
            ? kB04HoldPolicyVersion
            : kB04EnabledPolicyVersion,
        overrideRule: 'user action cannot bypass safety or rewrite history',
        negativeFixtureId: _decisionNegativeFixtureId(id),
        affectedTasks: affected[id.substring(8)]!,
        blocking: true,
      ),
  ];
}

List<B04EdgeFixture> _buildEdges() {
  const scenarios = [
    'activation gate',
    '18th birthday',
    'age states',
    'pregnancy or breastfeeding',
    'BMI boundary',
    'evaluation day count',
    'valid weight-day count',
    'weight span',
    'first and final block distribution',
    'latest weight freshness',
    'nutrition-valid day count',
    'daily completeness',
    'nutrition range width and midpoint',
    'different nutrition bound actions',
    'maintenance freshness',
    'maintenance range width and midpoint',
    'loss deadband',
    'gain deadband',
    'maintenance deadband',
    'exact proposal step',
    'proposal cadence',
    'proposal expiry',
    'rolling aggregate',
    'loss absolute deficit',
    'loss percentage deficit',
    'loss floor boundary crossing',
    'gain absolute surplus',
    'gain percentage surplus',
    'loss rapid change',
    'gain rapid change',
    'user target outside policy',
    'readiness hold',
    'AI conflict',
    'timezone and incomplete current day',
    'corrected evidence',
    'duplicate acceptance',
    'policy-version replay',
    'offline evidence states',
    'supported goal rates',
    'post-change evidence reset',
    'invalid ranges and non-finite input',
    'maintenance normalization',
    'odd and even medians and slopes',
    'ties and fractional slopes',
    'unrounded boundaries',
    'display-only rounding',
    'prospective aggregate',
  ];
  final edges = <B04EdgeFixture>[];
  for (var index = 0; index < scenarios.length; index++) {
    final id = 'E${(index + 1).toString().padLeft(2, '0')}';
    edges.add(
      B04EdgeFixture(
        id: id,
        kind: _edgeKind(id),
        scenario: scenarios[index],
        policyVersions: _edgePolicyVersions(id),
        expectedResult: switch (id) {
          'E01' => 'ENABLED-1 inactive; HOLD-1 current; no proposal',
          'E02' => 'eligible when all other gates pass',
          'E13' => '20% inclusive passes; 20.1% fails',
          'E16' => '15% inclusive passes; 15.1% fails',
          'E20' => 'exactly +100 or -100 kcal/day',
          'E22' => 'seven completed days is expiry boundary',
          'E23' => 'inclusive ±200; one unit beyond blocked',
          'E26' => 'policy_boundary_reached with no smaller clamp',
          'E29' ||
          'E30' => 'exact rapid threshold does not trigger; faster does',
          'E32' => 'readiness numerical effects are exactly zero',
          'E33' => 'deterministic result remains authoritative',
          'E37' => 'stored policy version controls replay',
          'E38' => 'local result or explicit unavailable; no invented evidence',
          'E41' => 'typed invalid or unavailable result',
          'E42' => 'recorded normalized M drives exact floor and cap math',
          'E43' || 'E44' => 'exact rational median and Theil-Sen result',
          'E45' => 'unrounded inclusive/exclusive boundary comparison',
          'E46' => 'display rounds only; canonical result remains exact',
          _ => 'deterministic contract result',
        },
        unit: index >= 19 && index <= 29
            ? 'kcal/day or percentage points'
            : 'typed policy input',
        period: index == 5 || index == 6 || index == 10 || index == 14
            ? 'completed local civil days'
            : 'evaluation policy period',
        timezone: 'recorded IANA evaluation timezone',
        missingDataResult: 'typed unavailable; never zero or profile default',
        overrideRule:
            'override is append-only and cannot bypass policy or safety',
        evidenceReference: 'VERIFICATION.md#$id',
        exactValues: switch (id) {
          'E13' => const {
            'range_a_width': '400',
            'range_a_midpoint': '2000',
            'range_a_relative_percent': '20',
            'range_b_width': '402',
            'range_b_midpoint': '2000',
            'range_b_relative_percent': '20.1',
          },
          'E16' => const {
            'range_a_width': '300',
            'range_a_midpoint': '2000',
            'range_a_relative_percent': '15',
            'range_b_width': '302',
            'range_b_midpoint': '2000',
            'range_b_relative_percent': '15.1',
          },
          'E41' => const {
            'valid_range': '2000-2000',
            'zero_midpoint': '0-0',
            'invalid_examples': 'negative,reversed,NaN,Infinity',
          },
          'E42' => const {'M_2000': '2000', 'M_2001': '2001', 'M_1801': '1801'},
          'E45' => const {
            'loss_lower_edge': '-0.65',
            'loss_upper_edge': '-0.35',
            'rapid_exact_edge': '-1.00',
            'rapid_outside': '-1.0000000001',
          },
          'E46' => const {
            'positive_display_input': '0.125',
            'positive_display': '0.13',
            'negative_display_input': '-0.125',
            'negative_display': '-0.13',
          },
          'E47' => const {
            'engine_positive': '100',
            'engine_negative': '-100',
            'manual_change': '100',
            'aggregate_window_days': '42',
            'prospective_delta': '100',
          },
          _ => const {},
        },
      ),
    );
  }
  return edges;
}

B04FixtureCaseKind _edgeKind(String id) => switch (id) {
  'E01' ||
  'E03' ||
  'E04' ||
  'E14' ||
  'E31' ||
  'E32' ||
  'E33' ||
  'E35' ||
  'E37' ||
  'E38' ||
  'E41' => B04FixtureCaseKind.negative,
  'E20' || 'E42' || 'E43' || 'E44' => B04FixtureCaseKind.positive,
  _ => B04FixtureCaseKind.boundary,
};

List<String> _edgePolicyVersions(String id) => switch (id) {
  'E01' || 'E37' => [kB04EnabledPolicyVersion, kB04HoldPolicyVersion],
  'E32' => [kB04ReadinessHoldPolicyVersion, kB04EnabledPolicyVersion],
  _ => [kB04EnabledPolicyVersion],
};

B04AdaptiveCoachingFixtureMatrix _buildCurrentMatrix() {
  final states = [
    const B04StateFixture(
      id: 'hold-unavailable-zero-delta',
      state: 'unavailable',
      inputCondition: 'HOLD-1 current/default or no enabled activation',
      expectedOutcome: B04FixtureOutcome.unavailable,
      policyVersion: kB04HoldPolicyVersion,
      lineage: B04LineageKind.appendOnly,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    const B04StateFixture(
      id: 'missing-required-evidence',
      state: 'unavailable_missing_evidence',
      inputCondition: 'weight, nutrition or maintenance evidence missing/stale',
      expectedOutcome: B04FixtureOutcome.unavailable,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.appendOnly,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    const B04StateFixture(
      id: 'dangling-lineage',
      state: 'invalid_evidence',
      inputCondition: 'recommendation references missing goal or evidence ID',
      expectedOutcome: B04FixtureOutcome.invalidEvidence,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.appendOnly,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    for (final kind in ['possible', 'unknown', 'insufficient'])
      B04StateFixture(
        id: 'dietary-$kind-unavailable',
        state: 'dietary_$kind',
        inputCondition:
            '$kind conflict or evidence for safety-sensitive output',
        expectedOutcome: B04FixtureOutcome.unavailable,
        policyVersion: kB04EnabledPolicyVersion,
        lineage: B04LineageKind.appendOnly,
        adaptiveDeltaKcal: 0,
        userSetTargetPreserved: true,
      ),
    const B04StateFixture(
      id: 'feedback-accept-append-only',
      state: 'accept',
      inputCondition: 'explicit acceptance of an enabled proposal',
      expectedOutcome: B04FixtureOutcome.available,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.effectiveDated,
      adaptiveDeltaKcal: 100,
      userSetTargetPreserved: false,
    ),
    const B04StateFixture(
      id: 'feedback-dismiss-no-mutation',
      state: 'dismiss',
      inputCondition: 'dismissal or expiry of a read-only proposal',
      expectedOutcome: B04FixtureOutcome.expired,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.appendOnly,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    const B04StateFixture(
      id: 'readiness-hold-zero-effect',
      state: 'readiness_descriptive_only',
      inputCondition:
          'complete, missing, denied, stale or conflicting readiness',
      expectedOutcome: B04FixtureOutcome.unavailable,
      policyVersion: kB04ReadinessHoldPolicyVersion,
      lineage: B04LineageKind.appendOnly,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    const B04StateFixture(
      id: 'future-only-enabled-replay',
      state: 'future_only_activation',
      inputCondition:
          'enabled policy after explicit future activation metadata',
      expectedOutcome: B04FixtureOutcome.inactive,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.effectiveDated,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    const B04StateFixture(
      id: 'unknown-nutrition-preserved',
      state: 'unknown',
      inputCondition: 'unknown nutrient or missing daily evidence',
      expectedOutcome: B04FixtureOutcome.unavailable,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.appendOnly,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    const B04StateFixture(
      id: 'range-crosses-decision-boundary',
      state: 'uncertain_range',
      inputCondition: 'lower and upper estimates produce different actions',
      expectedOutcome: B04FixtureOutcome.unavailable,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.appendOnly,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    const B04StateFixture(
      id: 'missing-provenance-unavailable',
      state: 'invalid_provenance',
      inputCondition: 'accepted evidence lacks source, timestamp or timezone',
      expectedOutcome: B04FixtureOutcome.invalidEvidence,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.appendOnly,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    const B04StateFixture(
      id: 'timezone-dst-local-date-frozen',
      state: 'historical_local_date',
      inputCondition: 'DST transition or travel zone changes device context',
      expectedOutcome: B04FixtureOutcome.available,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.appendOnly,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    const B04StateFixture(
      id: 'feedback-acknowledge-append-only',
      state: 'acknowledge',
      inputCondition:
          'low-risk warning acknowledgement preserves evaluator result',
      expectedOutcome: B04FixtureOutcome.available,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.appendOnly,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    const B04StateFixture(
      id: 'feedback-override-user-set',
      state: 'override',
      inputCondition:
          'manual override records user-set action without safety bypass',
      expectedOutcome: B04FixtureOutcome.available,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.effectiveDated,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
    const B04StateFixture(
      id: 'feedback-snooze-presentation-only',
      state: 'snooze',
      inputCondition: 'typed snooze period changes presentation only',
      expectedOutcome: B04FixtureOutcome.available,
      policyVersion: kB04EnabledPolicyVersion,
      lineage: B04LineageKind.appendOnly,
      adaptiveDeltaKcal: 0,
      userSetTargetPreserved: true,
    ),
  ];

  final outcomes = [
    const B04ContractReference(
      id: 'B04-R01',
      owner: 'B04-02 policy gate',
      description: 'Consent, eligibility and safe target control.',
      fixtureIds: ['hold-unavailable-zero-delta', 'E01', 'E02', 'E03'],
      downstreamTasks: ['B04-02', 'B04-05', 'B04-07', 'B04-15'],
    ),
    const B04ContractReference(
      id: 'B04-R02',
      owner: 'B04-07 adaptive target contract',
      description: 'Evidence-backed adaptive calorie target boundaries.',
      fixtureIds: ['missing-required-evidence', 'E06', 'E13', 'E42'],
      downstreamTasks: ['B04-01', 'B04-06', 'B04-07', 'B04-13'],
    ),
    const B04ContractReference(
      id: 'B04-R03',
      owner: 'B04-10 recommendation engine',
      description: 'One deterministic recommendation engine and lineage.',
      fixtureIds: ['dangling-lineage', 'E33', 'E37', 'E47'],
      downstreamTasks: ['B04-01', 'B04-08', 'B04-09', 'B04-10', 'B04-16'],
    ),
    const B04ContractReference(
      id: 'B04-R04',
      owner: 'B04-06 readiness service',
      description: 'Completeness-aware readiness with no numerical effect.',
      fixtureIds: ['readiness-hold-zero-effect', 'E32'],
      downstreamTasks: ['B04-02', 'B04-06', 'B04-07', 'B04-10', 'B04-13'],
    ),
    const B04ContractReference(
      id: 'B04-R05',
      owner: 'B04-12 meal opportunity and safety boundary',
      description: 'B03 safety outcomes and conditional N8 seam.',
      fixtureIds: [
        'dietary-possible-unavailable',
        'dietary-unknown-unavailable',
        'dietary-insufficient-unavailable',
        'E20',
      ],
      downstreamTasks: ['B04-08', 'B04-09', 'B04-12', 'B04-15'],
    ),
    const B04ContractReference(
      id: 'B04-R06',
      owner: 'B04-11 recommendation history',
      description: 'Feedback and immutable historical replay.',
      fixtureIds: [
        'feedback-accept-append-only',
        'feedback-dismiss-no-mutation',
        'E35',
        'E36',
        'E37',
      ],
      downstreamTasks: ['B04-10', 'B04-11', 'B04-13', 'B04-15'],
    ),
    const B04ContractReference(
      id: 'B04-R07',
      owner: 'B04-16 regression authority',
      description: 'Offline, privacy, legacy ownership and future-only policy.',
      fixtureIds: ['future-only-enabled-replay', 'E01', 'E38', 'E40'],
      downstreamTasks: [
        'B04-01',
        'B04-10',
        'B04-11',
        'B04-13',
        'B04-16',
        'B04-17',
      ],
    ),
  ];

  final matrix = B04AdaptiveCoachingFixtureMatrix(
    version: kB04AdaptiveCoachingFixtureContractVersion,
    enabledPolicy: B04EnabledPolicyContract.current,
    outcomes: outcomes,
    decisions: _buildDecisions(),
    negativeFixtures: _buildDecisionNegativeFixtures(),
    enabledEdges: _buildEdges(),
    states: states,
    ranges: const [
      B04RangeFixture(
        id: 'E13-range-1800-2200',
        lower: '1800',
        upper: '2200',
        unit: 'kcal/day',
        expectedOutcome: B04FixtureOutcome.onTrack,
        expectedReason: 'relative width is exactly inclusive 20%',
      ),
      B04RangeFixture(
        id: 'E13-range-1799-2201',
        lower: '1799',
        upper: '2201',
        unit: 'kcal/day',
        expectedOutcome: B04FixtureOutcome.unavailable,
        expectedReason: 'relative width is exact 20.1%',
      ),
      B04RangeFixture(
        id: 'E16-range-1850-2150',
        lower: '1850',
        upper: '2150',
        unit: 'kcal/day',
        expectedOutcome: B04FixtureOutcome.onTrack,
        expectedReason: 'relative width is exactly inclusive 15%',
      ),
      B04RangeFixture(
        id: 'E16-range-1849-2151',
        lower: '1849',
        upper: '2151',
        unit: 'kcal/day',
        expectedOutcome: B04FixtureOutcome.unavailable,
        expectedReason: 'relative width is exact 15.1%',
      ),
      B04RangeFixture(
        id: 'E41-range-zero-midpoint',
        lower: '0',
        upper: '0',
        unit: 'kcal/day',
        expectedOutcome: B04FixtureOutcome.invalidEvidence,
        expectedReason: 'unavailable_invalid_midpoint',
      ),
      B04RangeFixture(
        id: 'E41-range-reversed',
        lower: '2200',
        upper: '1800',
        unit: 'kcal/day',
        expectedOutcome: B04FixtureOutcome.invalidEvidence,
        expectedReason: 'unavailable_invalid_range',
      ),
      B04RangeFixture(
        id: 'E41-range-positive-point',
        lower: '2000',
        upper: '2000',
        unit: 'kcal/day',
        expectedOutcome: B04FixtureOutcome.available,
        expectedReason: 'positive-midpoint exact range is valid',
      ),
      B04RangeFixture(
        id: 'E41-range-negative-bound',
        lower: '-1',
        upper: '2000',
        unit: 'kcal/day',
        expectedOutcome: B04FixtureOutcome.invalidEvidence,
        expectedReason: 'lower bound must be non-negative',
      ),
      B04RangeFixture(
        id: 'E41-range-non-finite',
        lower: 'NaN',
        upper: '2000',
        unit: 'kcal/day',
        expectedOutcome: B04FixtureOutcome.invalidEvidence,
        expectedReason: 'all numeric inputs must be finite',
      ),
      B04RangeFixture(
        id: 'E41-range-mismatched-units',
        lower: '1800',
        upper: '2200',
        unit: 'kcal/day',
        lowerUnit: 'kcal/day',
        upperUnit: 'grams',
        expectedOutcome: B04FixtureOutcome.invalidEvidence,
        expectedReason: 'range bounds must use the same unit',
      ),
    ],
    trends: [
      B04TrendFixture(
        id: 'E43-odd-median-and-slopes',
        weights: const [
          B04DailyWeightFixture(localDay: 1, grams: 70000),
          B04DailyWeightFixture(localDay: 2, grams: 69900),
          B04DailyWeightFixture(localDay: 3, grams: 69800),
        ],
        expectedMedianGrams: B04Rational.fromInt(69900),
        expectedSlopeGramsPerDay: B04Rational.fromInt(-100),
        expectedWeeklyRatePercent: B04Rational.fromInts(-700, 699),
      ),
      B04TrendFixture(
        id: 'E43-even-median-and-slopes',
        weights: const [
          B04DailyWeightFixture(localDay: 1, grams: 70000),
          B04DailyWeightFixture(localDay: 2, grams: 69900),
          B04DailyWeightFixture(localDay: 3, grams: 69800),
          B04DailyWeightFixture(localDay: 4, grams: 69700),
        ],
        expectedMedianGrams: B04Rational.fromInts(139700, 2),
        expectedSlopeGramsPerDay: B04Rational.fromInt(-100),
        expectedWeeklyRatePercent: B04Rational.fromInts(-1400, 1397),
      ),
      B04TrendFixture(
        id: 'E44-tied-and-fractional-slopes',
        weights: const [
          B04DailyWeightFixture(localDay: 1, grams: 70000),
          B04DailyWeightFixture(localDay: 3, grams: 69900),
          B04DailyWeightFixture(localDay: 4, grams: 69850),
        ],
        expectedMedianGrams: B04Rational.fromInt(69900),
        expectedSlopeGramsPerDay: B04Rational.fromInts(-50),
        expectedWeeklyRatePercent: B04Rational.fromInts(-350, 699),
      ),
    ],
    maintenance: const [
      B04MaintenanceNormalizationFixture(
        id: 'E42-M-2000',
        rawPointKcal: '2000',
        normalizedM: 2000,
        deficitCap: 400,
        targetFloor: 1600,
        surplusCap: 300,
        targetCeiling: 2300,
      ),
      B04MaintenanceNormalizationFixture(
        id: 'E42-M-2001',
        rawPointKcal: '2001',
        normalizedM: 2001,
        deficitCap: 400,
        targetFloor: 1601,
        surplusCap: 300,
        targetCeiling: 2301,
      ),
      B04MaintenanceNormalizationFixture(
        id: 'E42-M-1801',
        rawPointKcal: '1801',
        normalizedM: 1801,
        deficitCap: 360,
        targetFloor: 1441,
        surplusCap: 270,
        targetCeiling: 2071,
      ),
    ],
    authorities: const [
      B04AuthorityFixture(
        id: 'b03-nutrition-read-model',
        authority: 'NutritionReadModelRepository',
        owner: 'B03',
        disposition: 'reuse as sole historical nutrition input',
        duplicateCreated: false,
      ),
      B04AuthorityFixture(
        id: 'b03-constraint-evaluator',
        authority: 'NutritionConstraintRepository',
        owner: 'B03',
        disposition: 'reuse as sole dietary safety evaluator',
        duplicateCreated: false,
      ),
      B04AuthorityFixture(
        id: 'b03-estimate-provenance',
        authority: 'NutritionEstimateRepository',
        owner: 'B03',
        disposition: 'reuse ranges, status and correction lineage',
        duplicateCreated: false,
      ),
      B04AuthorityFixture(
        id: 'b01-local-date',
        authority: 'LocalScheduleDateService',
        owner: 'B01',
        disposition: 'reuse validated IANA civil-date operations',
        duplicateCreated: false,
      ),
      B04AuthorityFixture(
        id: 'b02-readiness-inputs',
        authority: 'B02 health/activity read repositories',
        owner: 'B02',
        disposition: 'read-only provenance-bearing input',
        duplicateCreated: false,
      ),
    ],
    durableAuthorities: const [
      B04DurableAuthorityFixture(
        name: 'coaching_consent_events',
        lineage: B04LineageKind.appendOnly,
        requiredFields: [
          'portable_event_id',
          'user_id',
          'consent_category',
          'action',
          'consent_policy_version',
          'copy_version',
          'timestamp_utc',
          'local_date',
          'iana_timezone',
          'actor_source',
          'related_or_superseded_event_id',
          'created_at_utc',
        ],
        indexes: ['unique(portable_event_id)', 'user_id+local_date'],
        foreignKeys: ['user_id -> users.id', 'related_event_id -> event.id'],
        rejectedRestoreCases: [
          'duplicate_id',
          'cross_user_owner',
          'invalid_event_order',
          'unsupported_policy_version',
        ],
        correctionRule:
            'Disablement and corrections affect future proposals only; prior history is retained.',
      ),
      B04DurableAuthorityFixture(
        name: 'coaching_eligibility_evaluations',
        lineage: B04LineageKind.appendOnly,
        requiredFields: [
          'portable_evaluation_id',
          'user_id',
          'result',
          'reason_code',
          'age_input_source',
          'evidence_timestamp',
          'evaluation_utc',
          'evaluation_local_date',
          'iana_timezone',
          'policy_version',
          'minimum_age_rule_version',
          'goal_reference',
          'recommendation_or_attempt_reference',
          'evidence_fingerprint',
        ],
        indexes: [
          'unique(portable_evaluation_id)',
          'user_id+evaluation_local_date',
        ],
        foreignKeys: [
          'user_id -> users.id',
          'goal_reference -> goal_versions.id',
          'recommendation_reference -> recommendations.id',
        ],
        rejectedRestoreCases: [
          'duplicate_id',
          'cross_user_reference',
          'invalid_result_source',
          'unsupported_policy_version',
        ],
        correctionRule:
            'Corrections append a future evaluation; historical evaluations remain immutable.',
      ),
    ],
  );
  matrix.validate();
  return matrix;
}

B04Rational b04Median(Iterable<B04Rational> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) throw ArgumentError('At least one value is required.');
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / B04Rational.fromInt(2);
}

B04Rational b04TheilSenSlope(Iterable<B04DailyWeightFixture> weights) {
  final ordered = weights.toList()
    ..sort((a, b) => a.localDay.compareTo(b.localDay));
  final slopes = <B04Rational>[];
  for (var i = 0; i < ordered.length; i++) {
    for (var j = i + 1; j < ordered.length; j++) {
      final dayDelta = ordered[j].localDay - ordered[i].localDay;
      if (dayDelta <= 0) throw StateError('Weight days must be increasing.');
      slopes.add(
        B04Rational(
          BigInt.from(ordered[j].grams - ordered[i].grams),
          BigInt.from(dayDelta),
        ),
      );
    }
  }
  return b04Median(slopes);
}

B04Rational b04WeeklyRatePercent({
  required B04Rational slopeGramsPerDay,
  required B04Rational medianWindowWeightGrams,
}) =>
    slopeGramsPerDay *
    B04Rational.fromInt(7) *
    B04Rational.fromInt(100) /
    medianWindowWeightGrams;

B04Rational b04BasisPoints(String percentagePoints) =>
    B04Rational.parse(percentagePoints) * B04Rational.fromInt(100);

class B04AggregateEventFixture {
  final int localDay;
  final int deltaKcal;
  final bool engineAuthored;
  final bool accepted;

  const B04AggregateEventFixture({
    required this.localDay,
    required this.deltaKcal,
    required this.engineAuthored,
    required this.accepted,
  });
}

int b04AcceptedEngineAggregate({
  required Iterable<B04AggregateEventFixture> events,
  required int evaluationDay,
  required int prospectiveDeltaKcal,
}) {
  final historical = events
      .where(
        (event) =>
            event.engineAuthored &&
            event.accepted &&
            evaluationDay - event.localDay >= 0 &&
            evaluationDay - event.localDay < 42,
      )
      .fold<int>(0, (sum, event) => sum + event.deltaKcal);
  return historical + prospectiveDeltaKcal;
}

bool b04AggregateWithinBounds(int aggregateDeltaKcal) =>
    aggregateDeltaKcal >= -200 && aggregateDeltaKcal <= 200;

String b04DisplayPercent(B04Rational percent) {
  final scaled = percent * B04Rational.fromInt(100);
  final rounded = scaled.roundAwayFromZero();
  final negative = rounded.isNegative;
  final absolute = rounded.abs().toString().padLeft(3, '0');
  final whole = absolute.substring(0, absolute.length - 2);
  final fraction = absolute.substring(absolute.length - 2);
  return '${negative ? '-' : ''}$whole.$fraction';
}

int b04NormalizedMaintenance(String rawPointKcal) =>
    B04Rational.parse(rawPointKcal).roundAwayFromZero().toInt();

Map<String, dynamic> _map(dynamic value, String name) {
  if (value is! Map) throw FormatException('$name must be an object.');
  return Map<String, dynamic>.from(value);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string when present.');
  }
  return value;
}

String _stringOrDefault(
  Map<String, dynamic> json,
  String key,
  String defaultValue,
) => json[key] == null ? defaultValue : _string(json, key);

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

List<String> _strings(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String || item.isEmpty)) {
    throw FormatException('$key must contain strings.');
  }
  return List.unmodifiable(value.cast<String>());
}

Map<String, String> _stringMap(Map<String, dynamic> json, String key) {
  final value = _map(json[key], key);
  if (value.values.any((item) => item is! String)) {
    throw FormatException('$key must contain string values.');
  }
  return Map.unmodifiable(value.cast<String, String>());
}

bool _sameStrings(Iterable<String> actual, List<String> expected) {
  final actualList = actual.toList();
  if (actualList.length != expected.length) return false;
  for (var index = 0; index < expected.length; index++) {
    if (actualList[index] != expected[index]) return false;
  }
  return true;
}

bool _sameStringMap(Map<String, String> actual, Map<String, String> expected) {
  if (actual.length != expected.length) return false;
  for (final entry in expected.entries) {
    if (actual[entry.key] != entry.value) return false;
  }
  return true;
}

List<T> _objects<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! Map)) {
    throw FormatException('$key must contain objects.');
  }
  return List.unmodifiable(
    value.map((item) => parse(Map<String, dynamic>.from(item as Map))),
  );
}

B04FixtureOutcome _outcome(dynamic value) {
  if (value is! String) {
    throw const FormatException('Outcome must be a string.');
  }
  return B04FixtureOutcome.values.byName(value);
}

void _validateUnique(String kind, Iterable<String> values) {
  final list = values.toList();
  if (list.any((value) => value.trim().isEmpty) ||
      list.toSet().length != list.length) {
    throw StateError('Duplicate or empty $kind ID.');
  }
}
