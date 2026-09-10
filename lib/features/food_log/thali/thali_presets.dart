import '../../../core/typed_quantities.dart';

/// Defines an individual dish item within an Indian meal archetype preset.
class ThaliPresetItemDefinition {
  final String searchQuery;
  final String displayName;
  final Quantity defaultQuantity;
  final String? measureId;

  const ThaliPresetItemDefinition({
    required this.searchQuery,
    required this.displayName,
    required this.defaultQuantity,
    this.measureId,
  });
}

/// A pre-configured multi-item Indian meal composition.
class ThaliPresetDefinition {
  final String id;
  final String name;
  final String description;
  final List<ThaliPresetItemDefinition> items;

  const ThaliPresetDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.items,
  });
}

/// Canonical Indian Thali archetype presets.
///
/// If any constituent food is absent from the user's local database / regional pack,
/// the loader gracefully skips that item and alerts the user without crashing.
abstract final class ThaliPresets {
  static final ThaliPresetDefinition northIndianClassic = ThaliPresetDefinition(
    id: 'north_indian_classic',
    name: 'North Indian Classic',
    description: 'Roti, Dal Tadka, Sabzi, Rice & Curd',
    items: [
      ThaliPresetItemDefinition(
        searchQuery: 'roti',
        displayName: 'Roti (Whole Wheat)',
        defaultQuantity: Quantity.fromNum(amount: 2, unit: QuantityUnit.piece),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'dal',
        displayName: 'Dal Tadka',
        defaultQuantity: Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'sabzi',
        displayName: 'Mixed Veg Sabzi',
        defaultQuantity: Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'rice',
        displayName: 'Steamed Rice',
        defaultQuantity: Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'curd',
        displayName: 'Curd / Dahi',
        defaultQuantity: Quantity.fromNum(amount: 100, unit: QuantityUnit.gram),
      ),
    ],
  );

  static final ThaliPresetDefinition southIndianMeals = ThaliPresetDefinition(
    id: 'south_indian_meals',
    name: 'South Indian Meals',
    description: 'Rice, Sambar, Poriyal & Curd',
    items: [
      ThaliPresetItemDefinition(
        searchQuery: 'rice',
        displayName: 'Steamed Rice',
        defaultQuantity: Quantity.fromNum(amount: 200, unit: QuantityUnit.gram),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'sambar',
        displayName: 'Vegetable Sambar',
        defaultQuantity: Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'poriyal',
        displayName: 'Poriyal / Thoran',
        defaultQuantity: Quantity.fromNum(amount: 100, unit: QuantityUnit.gram),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'curd',
        displayName: 'Curd / Dahi',
        defaultQuantity: Quantity.fromNum(amount: 100, unit: QuantityUnit.gram),
      ),
    ],
  );

  static final ThaliPresetDefinition highProteinVeg = ThaliPresetDefinition(
    id: 'high_protein_veg',
    name: 'High Protein Veg',
    description: 'Roti, Paneer Bhurji, Dal & Salad',
    items: [
      ThaliPresetItemDefinition(
        searchQuery: 'roti',
        displayName: 'Roti (Whole Wheat)',
        defaultQuantity: Quantity.fromNum(amount: 2, unit: QuantityUnit.piece),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'paneer',
        displayName: 'Paneer Bhurji',
        defaultQuantity: Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'dal',
        displayName: 'Yellow Dal',
        defaultQuantity: Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'salad',
        displayName: 'Cucumber Salad',
        defaultQuantity: Quantity.fromNum(amount: 100, unit: QuantityUnit.gram),
      ),
    ],
  );

  static final ThaliPresetDefinition highProteinNonVeg = ThaliPresetDefinition(
    id: 'high_protein_non_veg',
    name: 'High Protein Non-Veg',
    description: 'Rice, Chicken Curry, Boiled Eggs & Salad',
    items: [
      ThaliPresetItemDefinition(
        searchQuery: 'rice',
        displayName: 'Steamed Rice',
        defaultQuantity: Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'chicken',
        displayName: 'Chicken Curry',
        defaultQuantity: Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'egg',
        displayName: 'Boiled Egg',
        defaultQuantity: Quantity.fromNum(amount: 2, unit: QuantityUnit.piece),
      ),
      ThaliPresetItemDefinition(
        searchQuery: 'salad',
        displayName: 'Green Salad',
        defaultQuantity: Quantity.fromNum(amount: 100, unit: QuantityUnit.gram),
      ),
    ],
  );

  static final List<ThaliPresetDefinition> all = [
    northIndianClassic,
    southIndianMeals,
    highProteinVeg,
    highProteinNonVeg,
  ];
}
