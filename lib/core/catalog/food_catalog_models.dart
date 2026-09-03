import 'package:flutter/foundation.dart';

/// External and local providers for food nutrition data.
enum FoodCatalogProvider {
  /// ICMR-NIN Indian Food Composition Tables 2017 scientific dataset.
  ifct,

  /// Open Food Facts crowdsourced global and Indian barcode database.
  openFoodFacts,

  /// IndiFit Cloud curated, lab-verified Indian recipes and fitness staples.
  indifitCloud,

  /// User-created custom food item.
  localCustom,
}

/// Verification level representing data confidence.
enum FoodVerificationLevel {
  unverified,
  communityReported,
  expertVerified,
  governmentStandard,
}

/// A standard portion or culinary serving option with equivalent gram weight.
@immutable
class ServingOption {
  const ServingOption({
    required this.unitName,
    required this.gramWeight,
    this.isDefault = false,
  });

  final String unitName;
  final double gramWeight;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
        'unitName': unitName,
        'gramWeight': gramWeight,
        'isDefault': isDefault,
      };

  factory ServingOption.fromJson(Map<String, dynamic> json) {
    return ServingOption(
      unitName: json['unitName'] as String,
      gramWeight: (json['gramWeight'] as num).toDouble(),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServingOption &&
          runtimeType == other.runtimeType &&
          unitName == other.unitName &&
          gramWeight == other.gramWeight &&
          isDefault == other.isDefault;

  @override
  int get hashCode => Object.hash(unitName, gramWeight, isDefault);
}

/// Provenance metadata tracking third-party source, licensing, and attribution.
@immutable
class FoodProvenance {
  const FoodProvenance({
    required this.provider,
    required this.attributionText,
    required this.license,
    this.sourceUrl,
    required this.fetchedAtUtc,
  });

  final FoodCatalogProvider provider;
  final String attributionText;
  final String license;
  final String? sourceUrl;
  final DateTime fetchedAtUtc;

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'attributionText': attributionText,
        'license': license,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        'fetchedAtUtc': fetchedAtUtc.toIso8601String(),
      };

  factory FoodProvenance.fromJson(Map<String, dynamic> json) {
    return FoodProvenance(
      provider: FoodCatalogProvider.values.firstWhere(
        (p) => p.name == json['provider'],
        orElse: () => FoodCatalogProvider.openFoodFacts,
      ),
      attributionText: json['attributionText'] as String,
      license: json['license'] as String,
      sourceUrl: json['sourceUrl'] as String?,
      fetchedAtUtc: DateTime.parse(json['fetchedAtUtc'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodProvenance &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          attributionText == other.attributionText &&
          license == other.license &&
          sourceUrl == other.sourceUrl &&
          fetchedAtUtc == other.fetchedAtUtc;

  @override
  int get hashCode =>
      Object.hash(provider, attributionText, license, sourceUrl, fetchedAtUtc);
}

/// Normalized remote food candidate model prior to local database persistence.
@immutable
class RemoteFoodCandidate {
  const RemoteFoodCandidate({
    required this.id,
    required this.provider,
    this.providerId,
    required this.name,
    this.nameHindi,
    this.brand,
    this.barcode,
    required this.category,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g,
    required this.servingOptions,
    required this.provenance,
    this.verificationLevel = FoodVerificationLevel.communityReported,
  });

  final String id;
  final FoodCatalogProvider provider;
  final String? providerId;
  final String name;
  final String? nameHindi;
  final String? brand;
  final String? barcode;
  final String category;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double? fiberPer100g;
  final List<ServingOption> servingOptions;
  final FoodProvenance provenance;
  final FoodVerificationLevel verificationLevel;

  /// Theoretical Atwater energy value per 100g: 4P + 4C + 9F.
  double get expectedCaloriesPer100g =>
      (4.0 * proteinPer100g) + (4.0 * carbsPer100g) + (9.0 * fatPer100g);

  /// Validates reported calories against Atwater expected calories within 20% variance.
  bool get isMacroBalanced {
    final diff = (caloriesPer100g - expectedCaloriesPer100g).abs();
    final allowedVariance =
        caloriesPer100g * 0.20 > 15.0 ? caloriesPer100g * 0.20 : 15.0;
    return diff <= allowedVariance;
  }

  /// Total macronutrient weight must not exceed physical bounds of 100g (+ 5g margin for analytical variance).
  bool get isPhysicallyPossible {
    final totalMacros =
        proteinPer100g + carbsPer100g + fatPer100g + (fiberPer100g ?? 0.0);
    return totalMacros <= 105.0;
  }

  /// Returns the default serving option or standard 100g basis.
  ServingOption get defaultServing {
    return servingOptions.firstWhere(
      (s) => s.isDefault,
      orElse: () => const ServingOption(
        unitName: 'g',
        gramWeight: 100.0,
        isDefault: true,
      ),
    );
  }

  /// Calculates nutritional values for a specified serving quantity and unit.
  Map<String, double> calculateNutrientsFor({
    required double quantity,
    required String unitName,
  }) {
    final serving = servingOptions.firstWhere(
      (s) => s.unitName.toLowerCase() == unitName.toLowerCase(),
      orElse: () => ServingOption(unitName: unitName, gramWeight: 100.0),
    );

    final totalGrams = serving.gramWeight * quantity;
    final factor = totalGrams / 100.0;

    return {
      'calories': caloriesPer100g * factor,
      'protein': proteinPer100g * factor,
      'carbs': carbsPer100g * factor,
      'fat': fatPer100g * factor,
      if (fiberPer100g != null) 'fiber': fiberPer100g! * factor,
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.name,
        if (providerId != null) 'providerId': providerId,
        'name': name,
        if (nameHindi != null) 'nameHindi': nameHindi,
        if (brand != null) 'brand': brand,
        if (barcode != null) 'barcode': barcode,
        'category': category,
        'caloriesPer100g': caloriesPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
        if (fiberPer100g != null) 'fiberPer100g': fiberPer100g,
        'servingOptions': servingOptions.map((s) => s.toJson()).toList(),
        'provenance': provenance.toJson(),
        'verificationLevel': verificationLevel.name,
      };

  factory RemoteFoodCandidate.fromJson(Map<String, dynamic> json) {
    return RemoteFoodCandidate(
      id: json['id'] as String,
      provider: FoodCatalogProvider.values.firstWhere(
        (p) => p.name == json['provider'],
        orElse: () => FoodCatalogProvider.openFoodFacts,
      ),
      providerId: json['providerId'] as String?,
      name: json['name'] as String,
      nameHindi: json['nameHindi'] as String?,
      brand: json['brand'] as String?,
      barcode: json['barcode'] as String?,
      category: json['category'] as String? ?? 'general',
      caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
      proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
      carbsPer100g: (json['carbsPer100g'] as num).toDouble(),
      fatPer100g: (json['fatPer100g'] as num).toDouble(),
      fiberPer100g: (json['fiberPer100g'] as num?)?.toDouble(),
      servingOptions: (json['servingOptions'] as List? ?? [])
          .map((s) => ServingOption.fromJson(s as Map<String, dynamic>))
          .toList(),
      provenance: FoodProvenance.fromJson(
        json['provenance'] as Map<String, dynamic>,
      ),
      verificationLevel: FoodVerificationLevel.values.firstWhere(
        (v) => v.name == json['verificationLevel'],
        orElse: () => FoodVerificationLevel.communityReported,
      ),
    );
  }
}

/// Paginated food search result envelope.
@immutable
class FoodSearchPage {
  const FoodSearchPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.hasMore,
    required this.query,
  });

  final List<RemoteFoodCandidate> items;
  final int totalCount;
  final int page;
  final bool hasMore;
  final String query;

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'totalCount': totalCount,
        'page': page,
        'hasMore': hasMore,
        'query': query,
      };

  factory FoodSearchPage.fromJson(Map<String, dynamic> json) {
    return FoodSearchPage(
      items: (json['items'] as List)
          .map((i) => RemoteFoodCandidate.fromJson(i as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      hasMore: json['hasMore'] as bool? ?? false,
      query: json['query'] as String? ?? '',
    );
  }
}
