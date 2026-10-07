/// One dish in a preset: an exact catalogue food and an amount counted in
/// that food's own unit (2 rotis are 2 pieces, dal is 1 katori, curd 100 g).
///
/// Presets never search by text: "egg" once matched Baingan Bharta
/// (eggplant) and "curd" a whole Home Thali (audit C-03).
class ThaliPresetItemDefinition {
  /// The food's stable source reference, `asset:base:<lower-case name>`.
  final String foodSourceRef;
  final String displayName;

  /// How many of the food's own units to add.
  final double amount;

  const ThaliPresetItemDefinition({
    required this.foodSourceRef,
    required this.displayName,
    required this.amount,
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
/// If a food is missing or retired, the loader skips that item and tells
/// the user which one, without crashing.
abstract final class ThaliPresets {
  static const _roti = ThaliPresetItemDefinition(
    foodSourceRef: 'asset:base:whole wheat roti / chapati',
    displayName: 'Whole Wheat Roti',
    amount: 2,
  );
  static const _dal = ThaliPresetItemDefinition(
    foodSourceRef: 'asset:base:toor dal / yellow dal tadka',
    displayName: 'Toor Dal Tadka',
    amount: 1,
  );
  static const _rice = ThaliPresetItemDefinition(
    foodSourceRef: 'asset:base:basmati white rice (cooked)',
    displayName: 'Basmati Rice',
    amount: 1,
  );
  static const _curd = ThaliPresetItemDefinition(
    foodSourceRef: 'asset:base:plain curd / dahi (cow milk)',
    displayName: 'Plain Curd',
    amount: 100,
  );
  static const _salad = ThaliPresetItemDefinition(
    foodSourceRef: 'asset:base:cucumber tomato salad (kachumber)',
    displayName: 'Kachumber Salad',
    amount: 1,
  );

  static const ThaliPresetDefinition northIndianClassic = ThaliPresetDefinition(
    id: 'north_indian_classic',
    name: 'North Indian Classic',
    description: 'Roti, Dal Tadka, Sabzi, Rice & Curd',
    items: [
      _roti,
      _dal,
      ThaliPresetItemDefinition(
        foodSourceRef: 'asset:base:mix vegetable sabji',
        displayName: 'Mix Vegetable Sabji',
        amount: 1,
      ),
      _rice,
      _curd,
    ],
  );

  static const ThaliPresetDefinition southIndianMeals = ThaliPresetDefinition(
    id: 'south_indian_meals',
    name: 'South Indian Meals',
    description: 'Rice, Sambar, Poriyal & Curd',
    items: [
      _rice,
      ThaliPresetItemDefinition(
        foodSourceRef: 'asset:base:sambar',
        displayName: 'Sambar',
        amount: 1,
      ),
      ThaliPresetItemDefinition(
        foodSourceRef: 'asset:base:beans poriyal',
        displayName: 'Beans Poriyal',
        amount: 1,
      ),
      _curd,
    ],
  );

  static const ThaliPresetDefinition highProteinVeg = ThaliPresetDefinition(
    id: 'high_protein_veg',
    name: 'High Protein Veg',
    description: 'Roti, Paneer Bhurji, Dal & Salad',
    items: [
      _roti,
      ThaliPresetItemDefinition(
        foodSourceRef: 'asset:base:paneer bhurji',
        displayName: 'Paneer Bhurji',
        amount: 1,
      ),
      _dal,
      _salad,
    ],
  );

  static const ThaliPresetDefinition highProteinNonVeg = ThaliPresetDefinition(
    id: 'high_protein_non_veg',
    name: 'High Protein Non-Veg',
    description: 'Rice, Chicken Curry, Boiled Eggs & Salad',
    items: [
      _rice,
      ThaliPresetItemDefinition(
        foodSourceRef: 'asset:base:chicken curry (north indian style)',
        displayName: 'Chicken Curry',
        amount: 1,
      ),
      ThaliPresetItemDefinition(
        foodSourceRef: 'asset:base:boiled eggs (2 pieces)',
        displayName: 'Boiled Eggs',
        amount: 2,
      ),
      _salad,
    ],
  );

  static const List<ThaliPresetDefinition> all = [
    northIndianClassic,
    southIndianMeals,
    highProteinVeg,
    highProteinNonVeg,
  ];
}
