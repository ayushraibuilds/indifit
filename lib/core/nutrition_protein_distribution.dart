import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'nutrients.dart';
import 'nutrition_legacy_read_models.dart';
import 'typed_quantities.dart';

/// Version of the descriptive protein/leucine read-model contract.
const int kNutritionProteinDistributionContractVersion = 1;

const String nutritionProteinNutrientId = 'protein';
const String nutritionLeucineNutrientId = 'leucine';

enum NutritionLeucineAvailability {
  unavailable,
  unknown,
  measuredOrReviewed,
  estimated,
  mixed,
}

extension NutritionLeucineAvailabilityContract on NutritionLeucineAvailability {
  String get stableId => switch (this) {
    NutritionLeucineAvailability.unavailable => 'unavailable',
    NutritionLeucineAvailability.unknown => 'unknown',
    NutritionLeucineAvailability.measuredOrReviewed => 'measured_or_reviewed',
    NutritionLeucineAvailability.estimated => 'estimated',
    NutritionLeucineAvailability.mixed => 'mixed',
  };
}

/// A display-safe projection of one immutable nutrient aggregation.
///
/// The raw fact remains available to non-UI read-model consumers for lineage,
/// while screens can render the preformatted values without parsing facts or
/// performing nutrient arithmetic.
class NutritionDistributionNutrientSummary {
  final String nutrientId;
  final NutrientFact? fact;
  final NutrientCompleteness completeness;
  final String? unitSymbol;
  final String? pointText;
  final String? lowerText;
  final String? upperText;
  final List<NutrientSourceType> sources;
  final List<String> factVersions;

  const NutritionDistributionNutrientSummary({
    required this.nutrientId,
    required this.fact,
    required this.completeness,
    required this.unitSymbol,
    required this.pointText,
    required this.lowerText,
    required this.upperText,
    required this.sources,
    required this.factVersions,
  });

  factory NutritionDistributionNutrientSummary.fromAggregation({
    required String nutrientId,
    required NutrientRegistry registry,
    required NutrientAggregationResult aggregation,
  }) {
    final definition = registry.definitionFor(nutrientId);
    final fact = aggregation.facts[nutrientId];
    String? format(NutrientAmount? amount) =>
        amount?.value.format(decimalPlaces: definition.displayPrecision);
    return NutritionDistributionNutrientSummary(
      nutrientId: nutrientId,
      fact: fact,
      completeness: aggregation.completeness,
      unitSymbol: definition.unit.symbol,
      pointText: format(fact?.point),
      lowerText: format(fact?.lower),
      upperText: format(fact?.upper),
      sources: List.unmodifiable(
        (aggregation.sourceLineage[nutrientId] ?? const <NutrientSourceType>[])
            .toSet()
            .toList()
          ..sort((left, right) => left.stableId.compareTo(right.stableId)),
      ),
      factVersions: List.unmodifiable(
        (aggregation.factVersionLineage[nutrientId] ?? const <String>[])
            .toSet()
            .toList()
          ..sort(),
      ),
    );
  }

  factory NutritionDistributionNutrientSummary.unavailable({
    required String nutrientId,
  }) => NutritionDistributionNutrientSummary(
    nutrientId: nutrientId,
    fact: null,
    completeness: NutrientCompleteness(
      state: NutrientCompletenessState.notApplicable,
      requestedNutrientIds: [nutrientId],
      availableNutrientIds: const [],
      missingNutrientIds: const [],
      estimatedNutrientIds: const [],
      notApplicableNutrientIds: [nutrientId],
      partiallyKnownNutrientIds: const [],
    ),
    unitSymbol: null,
    pointText: null,
    lowerText: null,
    upperText: null,
    sources: const [],
    factVersions: const [],
  );

  bool get isAvailable => fact?.isAvailable == true;
  bool get isEstimated => fact?.status == NutrientFactStatus.estimated;
  bool get isKnownPoint =>
      fact != null &&
      (fact!.status == NutrientFactStatus.known ||
          fact!.status == NutrientFactStatus.knownZero) &&
      fact!.point != null &&
      !fact!.coverageIncomplete;
  bool get hasRange => lowerText != null || upperText != null;

  Map<String, dynamic> toJson() => {
    'nutrient_id': nutrientId,
    'completeness': completeness.toJson(),
    if (unitSymbol != null) 'unit_symbol': unitSymbol,
    if (pointText != null) 'point': pointText,
    if (lowerText != null) 'lower': lowerText,
    if (upperText != null) 'upper': upperText,
    'status': fact?.status.stableId,
    'sources': sources.map((source) => source.stableId).toList()..sort(),
    'fact_versions': factVersions.toList()..sort(),
  };
}

class NutritionProteinMealSummary {
  final String id;
  final String localDate;
  final DateTime loggedAtUtc;
  final String mealCategory;
  final List<String> mealCategories;
  final String? mealGroupId;
  final List<String> recordIds;
  final List<String> sourceTypes;
  final int itemCount;
  final int unknownProteinItemCount;
  final int estimatedProteinItemCount;
  final int unknownLeucineItemCount;
  final NutritionDistributionNutrientSummary protein;
  final NutritionDistributionNutrientSummary knownProtein;
  final NutritionDistributionNutrientSummary leucine;
  final NutritionLeucineAvailability leucineAvailability;
  final QuantityAmount? knownProteinPoint;
  final QuantityAmount? distributionPercentage;

  const NutritionProteinMealSummary({
    required this.id,
    required this.localDate,
    required this.loggedAtUtc,
    required this.mealCategory,
    required this.mealCategories,
    required this.mealGroupId,
    required this.recordIds,
    required this.sourceTypes,
    required this.itemCount,
    required this.unknownProteinItemCount,
    required this.estimatedProteinItemCount,
    required this.unknownLeucineItemCount,
    required this.protein,
    required this.knownProtein,
    required this.leucine,
    required this.leucineAvailability,
    required this.knownProteinPoint,
    required this.distributionPercentage,
  });

  String? get distributionPercentageText =>
      distributionPercentage?.format(decimalPlaces: 1);

  bool get hasUnknownProtein => unknownProteinItemCount > 0;
  bool get hasEstimatedProtein => estimatedProteinItemCount > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'local_date': localDate,
    'logged_at_utc': loggedAtUtc.toUtc().toIso8601String(),
    'meal_category': mealCategory,
    'meal_categories': mealCategories.toList()..sort(),
    if (mealGroupId != null) 'meal_group_id': mealGroupId,
    'record_ids': recordIds.toList()..sort(),
    'source_types': sourceTypes.toList()..sort(),
    'item_count': itemCount,
    'unknown_protein_item_count': unknownProteinItemCount,
    'estimated_protein_item_count': estimatedProteinItemCount,
    'unknown_leucine_item_count': unknownLeucineItemCount,
    'protein': protein.toJson(),
    'known_protein': knownProtein.toJson(),
    'leucine': leucine.toJson(),
    'leucine_availability': leucineAvailability.stableId,
    if (knownProteinPoint != null)
      'known_protein_point': knownProteinPoint!.toJsonValue(),
    if (distributionPercentage != null)
      'distribution_percentage': distributionPercentage!.toJsonValue(),
  };
}

class NutritionProteinDistribution {
  final String userId;
  final String localDate;
  final bool isEmpty;
  final List<NutritionProteinMealSummary> meals;
  final NutritionDistributionNutrientSummary totalProtein;
  final NutritionDistributionNutrientSummary knownProtein;
  final NutritionDistributionNutrientSummary totalLeucine;
  final NutritionLeucineAvailability leucineAvailability;
  final int totalItemCount;
  final int unknownProteinItemCount;
  final int estimatedProteinItemCount;
  final bool percentagesAvailable;
  final String? percentageUnavailableReason;
  final List<String> recordIds;

  const NutritionProteinDistribution({
    required this.userId,
    required this.localDate,
    required this.isEmpty,
    required this.meals,
    required this.totalProtein,
    required this.knownProtein,
    required this.totalLeucine,
    required this.leucineAvailability,
    required this.totalItemCount,
    required this.unknownProteinItemCount,
    required this.estimatedProteinItemCount,
    required this.percentagesAvailable,
    required this.percentageUnavailableReason,
    required this.recordIds,
  });

  bool get hasUnknownProtein => unknownProteinItemCount > 0;
  bool get hasEstimatedProtein => estimatedProteinItemCount > 0;
  bool get hasIncompleteProtein =>
      totalProtein.completeness.state != NutrientCompletenessState.complete;

  Map<String, dynamic> toJson() => {
    'contract_version': kNutritionProteinDistributionContractVersion,
    'user_id': userId,
    'local_date': localDate,
    'is_empty': isEmpty,
    'meals': meals.map((meal) => meal.toJson()).toList(growable: false),
    'total_protein': totalProtein.toJson(),
    'known_protein': knownProtein.toJson(),
    'total_leucine': totalLeucine.toJson(),
    'leucine_availability': leucineAvailability.stableId,
    'total_item_count': totalItemCount,
    'unknown_protein_item_count': unknownProteinItemCount,
    'estimated_protein_item_count': estimatedProteinItemCount,
    'percentages_available': percentagesAvailable,
    if (percentageUnavailableReason != null)
      'percentage_unavailable_reason': percentageUnavailableReason,
    'record_ids': recordIds.toList()..sort(),
  };

  String get fingerprint => sha256
      .convert(utf8.encode(jsonEncode(_canonicalizeJson(toJson()))))
      .toString();
}

/// Pure descriptive aggregation over the unified immutable history boundary.
/// It never reads a current food, recipe, estimate, or catalogue row.
class NutritionProteinDistributionService {
  const NutritionProteinDistributionService();

  NutritionProteinDistribution build({
    required NutrientRegistry registry,
    required String userId,
    required String localDate,
    required Iterable<NutritionHistoricalReadRecord> records,
  }) {
    registry.definitionFor(nutritionProteinNutrientId);
    final leucineSupported = _supports(registry, nutritionLeucineNutrientId);
    final normalizedRecords = <String, NutritionHistoricalReadRecord>{};
    for (final record in records) {
      if (record.userId != userId || record.localDate != localDate) continue;
      final key = '${record.sourceType}\u0000${record.stableId}';
      normalizedRecords.putIfAbsent(key, () => record);
    }
    final activeRecords = _sortRecords(normalizedRecords.values);

    if (activeRecords.isEmpty) {
      return _empty(
        registry: registry,
        userId: userId,
        localDate: localDate,
        leucineSupported: leucineSupported,
      );
    }

    final buckets = _groupRecords(activeRecords, localDate);
    final meals = <NutritionProteinMealSummary>[];
    for (final bucket in buckets) {
      meals.add(
        _buildMeal(
          registry: registry,
          localDate: localDate,
          bucket: bucket,
          leucineSupported: leucineSupported,
        ),
      );
    }

    final allItems = activeRecords.expand((record) => record.items).toList();
    final totalProteinAggregation = _aggregate(
      registry: registry,
      nutrientId: nutritionProteinNutrientId,
      items: allItems,
    );
    final knownProteinAggregation = _aggregateKnown(
      registry: registry,
      nutrientId: nutritionProteinNutrientId,
      items: allItems,
    );
    final totalProtein = NutritionDistributionNutrientSummary.fromAggregation(
      nutrientId: nutritionProteinNutrientId,
      registry: registry,
      aggregation: totalProteinAggregation,
    );
    final knownProtein = NutritionDistributionNutrientSummary.fromAggregation(
      nutrientId: nutritionProteinNutrientId,
      registry: registry,
      aggregation: knownProteinAggregation,
    );
    final totalLeucine = leucineSupported
        ? NutritionDistributionNutrientSummary.fromAggregation(
            nutrientId: nutritionLeucineNutrientId,
            registry: registry,
            aggregation: _aggregate(
              registry: registry,
              nutrientId: nutritionLeucineNutrientId,
              items: allItems,
            ),
          )
        : NutritionDistributionNutrientSummary.unavailable(
            nutrientId: nutritionLeucineNutrientId,
          );
    final leucineAvailability = _leucineAvailability(
      registry: registry,
      items: allItems,
      supported: leucineSupported,
    );
    final knownTotal =
        knownProteinAggregation.facts[nutritionProteinNutrientId]?.point?.value;
    final percentagesAvailable =
        knownTotal != null &&
        !knownTotal.isZero &&
        knownProteinAggregation.completeness.state !=
            NutrientCompletenessState.unknown;
    final percentageReason = percentagesAvailable
        ? null
        : knownTotal?.isZero == true
        ? 'zero_known_total'
        : 'requires_known_point_values';
    final mealsWithPercentages = [
      for (final meal in meals)
        _withPercentage(
          meal,
          total: knownTotal,
          percentagesAvailable: percentagesAvailable,
        ),
    ];

    return NutritionProteinDistribution(
      userId: userId,
      localDate: localDate,
      isEmpty: false,
      meals: List.unmodifiable(mealsWithPercentages),
      totalProtein: totalProtein,
      knownProtein: knownProtein,
      totalLeucine: totalLeucine,
      leucineAvailability: leucineAvailability,
      totalItemCount: allItems.length,
      unknownProteinItemCount: _unknownCount(
        allItems,
        nutritionProteinNutrientId,
      ),
      estimatedProteinItemCount: _estimatedCount(
        allItems,
        nutritionProteinNutrientId,
      ),
      percentagesAvailable: percentagesAvailable,
      percentageUnavailableReason: percentageReason,
      recordIds: List.unmodifiable(
        activeRecords.map((record) => record.stableId).toList()..sort(),
      ),
    );
  }

  NutritionProteinDistribution _empty({
    required NutrientRegistry registry,
    required String userId,
    required String localDate,
    required bool leucineSupported,
  }) {
    final proteinUnknown = NutritionDistributionNutrientSummary.fromAggregation(
      nutrientId: nutritionProteinNutrientId,
      registry: registry,
      aggregation: _emptyAggregation(
        registry: registry,
        nutrientId: nutritionProteinNutrientId,
      ),
    );
    final leucine = leucineSupported
        ? NutritionDistributionNutrientSummary.fromAggregation(
            nutrientId: nutritionLeucineNutrientId,
            registry: registry,
            aggregation: _emptyAggregation(
              registry: registry,
              nutrientId: nutritionLeucineNutrientId,
            ),
          )
        : NutritionDistributionNutrientSummary.unavailable(
            nutrientId: nutritionLeucineNutrientId,
          );
    return NutritionProteinDistribution(
      userId: userId,
      localDate: localDate,
      isEmpty: true,
      meals: const [],
      totalProtein: proteinUnknown,
      knownProtein: proteinUnknown,
      totalLeucine: leucine,
      leucineAvailability: leucineSupported
          ? NutritionLeucineAvailability.unknown
          : NutritionLeucineAvailability.unavailable,
      totalItemCount: 0,
      unknownProteinItemCount: 0,
      estimatedProteinItemCount: 0,
      percentagesAvailable: false,
      percentageUnavailableReason: 'empty_day',
      recordIds: const [],
    );
  }

  NutritionProteinMealSummary _buildMeal({
    required NutrientRegistry registry,
    required String localDate,
    required _NutritionProteinMealBucket bucket,
    required bool leucineSupported,
  }) {
    final items = bucket.records.expand((record) => record.items).toList();
    final proteinAggregation = _aggregate(
      registry: registry,
      nutrientId: nutritionProteinNutrientId,
      items: items,
    );
    final knownProteinAggregation = _aggregateKnown(
      registry: registry,
      nutrientId: nutritionProteinNutrientId,
      items: items,
    );
    final leucineAggregation = leucineSupported
        ? _aggregate(
            registry: registry,
            nutrientId: nutritionLeucineNutrientId,
            items: items,
          )
        : null;
    final protein = NutritionDistributionNutrientSummary.fromAggregation(
      nutrientId: nutritionProteinNutrientId,
      registry: registry,
      aggregation: proteinAggregation,
    );
    final knownProtein = NutritionDistributionNutrientSummary.fromAggregation(
      nutrientId: nutritionProteinNutrientId,
      registry: registry,
      aggregation: knownProteinAggregation,
    );
    final leucine = leucineSupported
        ? NutritionDistributionNutrientSummary.fromAggregation(
            nutrientId: nutritionLeucineNutrientId,
            registry: registry,
            aggregation: leucineAggregation!,
          )
        : NutritionDistributionNutrientSummary.unavailable(
            nutrientId: nutritionLeucineNutrientId,
          );
    return NutritionProteinMealSummary(
      id: bucket.id,
      localDate: localDate,
      loggedAtUtc: bucket.loggedAtUtc!,
      mealCategory: bucket.mealCategories.first,
      mealCategories: List.unmodifiable(bucket.mealCategories),
      mealGroupId: bucket.mealGroupId,
      recordIds: List.unmodifiable(
        bucket.records.map((record) => record.stableId).toList()..sort(),
      ),
      sourceTypes: List.unmodifiable(
        bucket.records.map((record) => record.sourceType).toSet().toList()
          ..sort(),
      ),
      itemCount: items.length,
      unknownProteinItemCount: _unknownCount(items, nutritionProteinNutrientId),
      estimatedProteinItemCount: _estimatedCount(
        items,
        nutritionProteinNutrientId,
      ),
      unknownLeucineItemCount: leucineSupported
          ? _unknownCount(items, nutritionLeucineNutrientId)
          : 0,
      protein: protein,
      knownProtein: knownProtein,
      leucine: leucine,
      leucineAvailability: _leucineAvailability(
        registry: registry,
        items: items,
        supported: leucineSupported,
      ),
      knownProteinPoint: knownProteinAggregation
          .facts[nutritionProteinNutrientId]
          ?.point
          ?.value,
      distributionPercentage: null,
    );
  }

  NutritionProteinMealSummary _withPercentage(
    NutritionProteinMealSummary meal, {
    required QuantityAmount? total,
    required bool percentagesAvailable,
  }) {
    final point = meal.knownProteinPoint;
    final percentage = percentagesAvailable && total != null && point != null
        ? point.divide(total).multiply(QuantityAmount.fromNum(100))
        : null;
    return NutritionProteinMealSummary(
      id: meal.id,
      localDate: meal.localDate,
      loggedAtUtc: meal.loggedAtUtc,
      mealCategory: meal.mealCategory,
      mealCategories: meal.mealCategories,
      mealGroupId: meal.mealGroupId,
      recordIds: meal.recordIds,
      sourceTypes: meal.sourceTypes,
      itemCount: meal.itemCount,
      unknownProteinItemCount: meal.unknownProteinItemCount,
      estimatedProteinItemCount: meal.estimatedProteinItemCount,
      unknownLeucineItemCount: meal.unknownLeucineItemCount,
      protein: meal.protein,
      knownProtein: meal.knownProtein,
      leucine: meal.leucine,
      leucineAvailability: meal.leucineAvailability,
      knownProteinPoint: meal.knownProteinPoint,
      distributionPercentage: percentage,
    );
  }

  NutrientAggregationResult _aggregate({
    required NutrientRegistry registry,
    required String nutrientId,
    required Iterable<NutritionHistoricalReadItem> items,
  }) => NutrientAggregationService.aggregate(
    registry: registry,
    contributions: _contributions(
      registry: registry,
      nutrientId: nutrientId,
      items: items,
    ),
    requestedNutrientIds: {nutrientId},
  );

  NutrientAggregationResult _aggregateKnown({
    required NutrientRegistry registry,
    required String nutrientId,
    required Iterable<NutritionHistoricalReadItem> items,
  }) => NutrientAggregationService.aggregate(
    registry: registry,
    contributions: items
        .map((item) => item.facts[nutrientId])
        .whereType<NutrientFact>()
        .where(_isKnownPointFact)
        .map((fact) => NutrientContribution(fact: fact)),
    requestedNutrientIds: {nutrientId},
  );

  Iterable<NutrientContribution> _contributions({
    required NutrientRegistry registry,
    required String nutrientId,
    required Iterable<NutritionHistoricalReadItem> items,
  }) sync* {
    final definition = registry.definitionFor(nutrientId);
    for (final item in items) {
      yield NutrientContribution(
        fact:
            item.facts[nutrientId] ??
            NutrientFact.missing(
              nutrientId: nutrientId,
              unit: definition.unit,
              basis: NutrientBasis(NutrientBasisKind.absolute),
              source: NutrientSourceType.unknown,
              factVersion: 'read_model_missing_v1',
            ),
      );
    }
  }

  NutrientAggregationResult _emptyAggregation({
    required NutrientRegistry registry,
    required String nutrientId,
  }) => NutrientAggregationService.aggregate(
    registry: registry,
    contributions: const [],
    requestedNutrientIds: {nutrientId},
  );

  List<_NutritionProteinMealBucket> _groupRecords(
    List<NutritionHistoricalReadRecord> records,
    String localDate,
  ) {
    final groups = <String, _NutritionProteinMealBucket>{};
    for (final record in records) {
      final groupId = record.mealGroupId?.trim();
      final key = groupId == null || groupId.isEmpty
          ? 'record::${record.sourceType}::${record.stableId}'
          : 'group::$localDate::$groupId';
      final bucket = groups.putIfAbsent(
        key,
        () => _NutritionProteinMealBucket(
          id: key,
          mealGroupId: groupId?.isEmpty == true ? null : groupId,
        ),
      );
      bucket.records.add(record);
      bucket.mealCategories.add(record.mealCategory);
      if (bucket.loggedAtUtc == null ||
          record.loggedAtUtc.isBefore(bucket.loggedAtUtc!)) {
        bucket.loggedAtUtc = record.loggedAtUtc;
      }
    }
    final result = groups.values.toList();
    for (final bucket in result) {
      bucket.records.sort(_compareRecords);
      bucket.mealCategories = bucket.mealCategories.toSet().toList()..sort();
    }
    result.sort((left, right) {
      final time = left.loggedAtUtc!.compareTo(right.loggedAtUtc!);
      return time == 0 ? left.id.compareTo(right.id) : time;
    });
    return result;
  }

  List<NutritionHistoricalReadRecord> _sortRecords(
    Iterable<NutritionHistoricalReadRecord> records,
  ) => records.toList()..sort(_compareRecords);

  int _compareRecords(
    NutritionHistoricalReadRecord left,
    NutritionHistoricalReadRecord right,
  ) {
    final time = left.loggedAtUtc.compareTo(right.loggedAtUtc);
    return time == 0 ? left.stableId.compareTo(right.stableId) : time;
  }

  NutritionLeucineAvailability _leucineAvailability({
    required NutrientRegistry registry,
    required Iterable<NutritionHistoricalReadItem> items,
    required bool supported,
  }) {
    if (!supported) return NutritionLeucineAvailability.unavailable;
    final facts = items
        .map((item) => item.facts[nutritionLeucineNutrientId])
        .whereType<NutrientFact>()
        .where((fact) => fact.isAvailable)
        .toList(growable: false);
    if (facts.isEmpty) return NutritionLeucineAvailability.unknown;
    final measured = facts.any(_isMeasuredOrReviewedLeucine);
    final estimated = facts.any(_isEstimatedLeucine);
    if (measured && estimated) return NutritionLeucineAvailability.mixed;
    if (estimated) return NutritionLeucineAvailability.estimated;
    if (measured && facts.every(_isMeasuredOrReviewedLeucine)) {
      return NutritionLeucineAvailability.measuredOrReviewed;
    }
    return NutritionLeucineAvailability.unknown;
  }

  static bool _isKnownPointFact(NutrientFact fact) =>
      (fact.status == NutrientFactStatus.known ||
          fact.status == NutrientFactStatus.knownZero) &&
      fact.isAvailable &&
      !fact.coverageIncomplete;

  static bool _isEstimatedLeucine(NutrientFact fact) =>
      fact.status == NutrientFactStatus.estimated ||
      fact.source == NutrientSourceType.aiEstimate ||
      fact.source == NutrientSourceType.heuristic;

  static bool _isMeasuredOrReviewedLeucine(NutrientFact fact) {
    if (!_isKnownPointFact(fact)) return false;
    return switch (fact.source) {
      NutrientSourceType.bundledCatalogue ||
      NutrientSourceType.regionalCatalogue ||
      NutrientSourceType.reviewedCatalogue ||
      NutrientSourceType.manufacturerLabel ||
      NutrientSourceType.recipeCalculation => true,
      _ => false,
    };
  }

  static bool _supports(NutrientRegistry registry, String nutrientId) {
    try {
      final definition = registry.definitionFor(nutrientId);
      return !definition.deprecated;
    } on NutrientError {
      return false;
    }
  }

  static int _unknownCount(
    Iterable<NutritionHistoricalReadItem> items,
    String nutrientId,
  ) => items.where((item) {
    final fact = item.facts[nutrientId];
    return fact == null || !fact.isAvailable || fact.coverageIncomplete;
  }).length;

  static int _estimatedCount(
    Iterable<NutritionHistoricalReadItem> items,
    String nutrientId,
  ) => items
      .map((item) => item.facts[nutrientId])
      .whereType<NutrientFact>()
      .where((fact) => fact.status == NutrientFactStatus.estimated)
      .length;
}

class _NutritionProteinMealBucket {
  final String id;
  final String? mealGroupId;
  final List<NutritionHistoricalReadRecord> records = [];
  List<String> mealCategories = [];
  DateTime? loggedAtUtc;

  _NutritionProteinMealBucket({required this.id, required this.mealGroupId});
}

dynamic _canonicalizeJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalizeJson(value[key]),
    };
  }
  if (value is Iterable) return value.map(_canonicalizeJson).toList();
  return value;
}
