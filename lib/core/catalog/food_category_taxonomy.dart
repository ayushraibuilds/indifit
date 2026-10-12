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
  // Added with the 12 Oct staples draft (fruit, nuts, cereal, supplements).
  static const String fruit = 'fruit';
  static const String nutSeed = 'nut_seed';
  static const String breakfastCereal = 'breakfast_cereal';
  static const String supplement = 'supplement';
  static const String general = 'general';

  /// Catalogue category names → taxonomy ids for the categories the staples
  /// draft adds. Checked before name keywords: the category is the better
  /// evidence when a food has one.
  static const Map<String, String> catalogueCategories = {
    'fruits': fruit,
    'nuts & seeds': nutSeed,
    'breakfast cereals': breakfastCereal,
    'supplements': supplement,
    'sweets & desserts': sweetDessert,
    'rice & rice dishes': stapleRice,
    'western & fast food': snackStreet,
    'packaged snacks': snackStreet,
  };

  static final RegExp _fruitName = RegExp(
    r'^(banana|apple|mango|orange|papaya|watermelon|guava|pomegranate|'
    r'grapes?|pineapple|chikoo|sapota|pear|muskmelon|strawberr(y|ies)|kiwi|'
    r'dates|raisins?|amla|jamun)\b',
  );
  static final RegExp _nutSeedName = RegExp(
    r'\b(almonds?|cashews?|walnuts?|peanuts?|pistachios?|makhana|chia|flax|'
    r'(pumpkin|sunflower) seeds?)\b',
  );
  static final RegExp _cerealName = RegExp(
    r'\b(corn ?flakes|muesli|granola|rolled oats|oats \(dry\)|oats porridge)',
  );
  static final RegExp _supplementName = RegExp(
    r'\b(whey|protein powder|mass gainer)\b',
  );

  /// Resolves canonical category ID from dish name and optional raw category text.
  /// Deprecated in favor of server-provided category_id from the backend search proxy.
  /// Retained strictly as an offline fallback when disconnected.
  @Deprecated(
    'Use server-provided category_id; retain strictly as offline fallback',
  )
  static String resolveCategoryId({required String name, String? rawCategory}) {
    final lower = name.toLowerCase();
    final listed = catalogueCategories[rawCategory?.trim().toLowerCase()];
    if (listed != null) return listed;
    if (_supplementName.hasMatch(lower)) return supplement;
    if (_cerealName.hasMatch(lower)) return breakfastCereal;
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
    // After drinks and sweets ("Mango Lassi", "Gulab Jamun"), and only for
    // names that start with the fruit ("Raw Banana Stir Fry" is a sabzi).
    if (!lower.contains('chips') && _fruitName.hasMatch(lower)) return fruit;
    if (!lower.contains('chikki') && _nutSeedName.hasMatch(lower)) {
      return nutSeed;
    }

    if (rawCategory != null && rawCategory.isNotEmpty) {
      final rc = rawCategory.toLowerCase();
      if (rc.contains('bread') || rc.contains('grain')) return stapleBread;
      if (rc.contains('dal') || rc.contains('pulse') || rc.contains('legume')) {
        return dalLentil;
      }
      if (rc.contains('sabzi') ||
          rc.contains('vegetable') ||
          rc.contains('salad')) {
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
        options.add(
          const ServingOption(unitName: 'serving_bowl', gramWeight: 300.0),
        );
        break;

      case drySabzi:
        options.add(const ServingOption(unitName: 'katori', gramWeight: 150.0));
        options.add(
          const ServingOption(unitName: 'small_katori', gramWeight: 80.0),
        );
        break;

      case stapleRice:
        options.add(
          const ServingOption(unitName: 'medium_katori', gramWeight: 200.0),
        );
        options.add(
          const ServingOption(unitName: 'serving_bowl', gramWeight: 300.0),
        );
        break;

      case stapleBread:
        options.add(
          const ServingOption(unitName: 'roti_piece', gramWeight: 35.0),
        );
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
        options.add(
          const ServingOption(unitName: 'tablespoon', gramWeight: 15.0),
        );
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

      case fruit:
        options.add(
          const ServingOption(unitName: 'fruit_piece', gramWeight: 120.0),
        );
        options.add(const ServingOption(unitName: 'katori', gramWeight: 150.0));
        break;

      case nutSeed:
        options.add(const ServingOption(unitName: 'handful', gramWeight: 30.0));
        options.add(
          const ServingOption(unitName: 'tablespoon', gramWeight: 15.0),
        );
        break;

      case breakfastCereal:
        options.add(
          const ServingOption(unitName: 'cereal_bowl', gramWeight: 40.0),
        );
        break;

      case supplement:
        options.add(const ServingOption(unitName: 'scoop', gramWeight: 30.0));
        break;

      case general:
      default:
        break;
    }

    // A food whose own serving is already a household measure (say
    // "katori") would otherwise show that chip twice. The first, the food's
    // own default, wins.
    final seen = <String>{};
    return [
      for (final option in options)
        if (seen.add(option.unitName)) option,
    ];
  }
}
