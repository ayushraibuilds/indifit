import 'food_catalog_models.dart';

/// Standard taxonomy of food categories for Indian culinary tracking.
/// Replaces fragile substring heuristics with explicit taxonomy-driven serving intelligence.
class FoodCategoryTaxonomy {
  const FoodCategoryTaxonomy._();

  static const String dalLentil = 'dal_lentil';
  static const String gravyCurry = 'gravy_curry';
  static const String drySabzi = 'dry_sabzi';
  static const String stapleBread = 'staple_bread';
  static const String stapleRice = 'staple_rice';
  static const String dairyLiquid = 'dairy_liquid';
  static const String snackStreet = 'snack_street';
  static const String sweetDessert = 'sweet_dessert';
  static const String oilFat = 'oil_fat';
  static const String general = 'general';

  /// Resolves canonical category ID from dish name and optional raw category text.
  static String resolveCategoryId({
    required String name,
    String? rawCategory,
  }) {
    final lower = name.toLowerCase();
    if (lower.contains('biryani') ||
        lower.contains('pulao') ||
        lower.contains('rice') ||
        lower.contains('khichdi')) {
      return stapleRice;
    }
    if (lower.contains('roti') ||
        lower.contains('chapati') ||
        lower.contains('phulka') ||
        lower.contains('paratha') ||
        lower.contains('naan') ||
        lower.contains('kulcha') ||
        lower.contains('puri') ||
        lower.contains('idli') ||
        lower.contains('dosa')) {
      return stapleBread;
    }
    if (lower.contains('dal') ||
        lower.contains('curry') ||
        lower.contains('sambar') ||
        lower.contains('kadhi') ||
        lower.contains('raita') ||
        lower.contains('chana') ||
        lower.contains('rajma') ||
        lower.contains('lentil')) {
      return dalLentil;
    }
    if (lower.contains('sabzi') ||
        lower.contains('subzi') ||
        lower.contains('bhindi') ||
        lower.contains('gobi') ||
        lower.contains('aloo') ||
        lower.contains('palak')) {
      return drySabzi;
    }
    if (lower.contains('milk') ||
        lower.contains('chaas') ||
        lower.contains('lassi') ||
        lower.contains('dahi') ||
        lower.contains('curd') ||
        lower.contains('juice')) {
      return dairyLiquid;
    }
    if (lower.contains('ghee') ||
        lower.contains('butter') ||
        lower.contains('oil')) {
      return oilFat;
    }
    if (lower.contains('ladoo') ||
        lower.contains('halwa') ||
        lower.contains('kheer') ||
        lower.contains('gulab jamun') ||
        lower.contains('jalebi')) {
      return sweetDessert;
    }

    if (rawCategory != null && rawCategory.isNotEmpty) {
      final rc = rawCategory.toLowerCase();
      if (rc.contains('bread') || rc.contains('grain')) return stapleBread;
      if (rc.contains('dal') || rc.contains('pulse') || rc.contains('legume')) {
        return dalLentil;
      }
      if (rc.contains('sabzi') || rc.contains('vegetable') || rc.contains('salad')) {
        return drySabzi;
      }
      if (rc.contains('curry') || rc.contains('non-veg')) return gravyCurry;
      if (rc.contains('dairy') || rc.contains('beverage')) return dairyLiquid;
      if (rc.contains('snack')) return snackStreet;
      if (rc.contains('sweet') || rc.contains('dessert')) return sweetDessert;
      if (rc.contains('oil') || rc.contains('fat')) return oilFat;
    }

    return general;
  }

  /// Synthesizes serving options directly from category ID without brittle substring matching.
  static List<ServingOption> servingOptionsForCategory({
    required String categoryId,
    double servingSize = 100.0,
    String servingUnit = 'g',
    bool isStuffedParatha = false,
  }) {
    final options = <ServingOption>[];

    // 1. Original package serving size
    final cleanUnit = servingUnit.isNotEmpty ? servingUnit : 'g';
    final isMl = cleanUnit.toLowerCase() == 'ml';
    if (servingSize > 0 && servingSize.isFinite) {
      options.add(
        ServingOption(
          unitName: cleanUnit,
          gramWeight: isMl ? servingSize * 1.03 : servingSize,
          isDefault: true,
        ),
      );
    }

    // 2. Standard 100g basis
    if (servingSize != 100.0) {
      options.add(const ServingOption(unitName: '100g', gramWeight: 100.0));
    }

    // 3. Category-driven culinary household measures
    switch (categoryId) {
      case dalLentil:
      case gravyCurry:
        options.add(const ServingOption(unitName: 'katori', gramWeight: 150.0));
        options.add(const ServingOption(unitName: 'serving_bowl', gramWeight: 300.0));
        break;

      case drySabzi:
        options.add(const ServingOption(unitName: 'katori', gramWeight: 150.0));
        options.add(const ServingOption(unitName: 'small_katori', gramWeight: 80.0));
        break;

      case stapleRice:
        options.add(const ServingOption(unitName: 'medium_katori', gramWeight: 200.0));
        options.add(const ServingOption(unitName: 'serving_bowl', gramWeight: 300.0));
        break;

      case stapleBread:
        options.add(const ServingOption(unitName: 'roti_piece', gramWeight: 35.0));
        options.add(
          ServingOption(
            unitName: isStuffedParatha ? 'stuffed_paratha' : 'paratha_piece',
            gramWeight: isStuffedParatha ? 110.0 : 60.0,
          ),
        );
        break;

      case dairyLiquid:
        options.add(const ServingOption(unitName: 'glass', gramWeight: 206.0));
        options.add(const ServingOption(unitName: 'katori', gramWeight: 150.0));
        break;

      case oilFat:
        options.add(const ServingOption(unitName: 'tablespoon', gramWeight: 15.0));
        options.add(const ServingOption(unitName: 'teaspoon', gramWeight: 5.0));
        break;

      case snackStreet:
        options.add(const ServingOption(unitName: 'piece', gramWeight: 50.0));
        options.add(const ServingOption(unitName: 'plate', gramWeight: 150.0));
        break;

      case sweetDessert:
        options.add(const ServingOption(unitName: 'piece', gramWeight: 40.0));
        options.add(const ServingOption(unitName: 'katori', gramWeight: 100.0));
        break;

      case general:
      default:
        break;
    }

    return options;
  }
}
