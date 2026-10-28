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

  /// The food's catalogue id, tried when [foodSourceRef] finds nothing.
  final String? foodId;

  /// Left out quietly when the food isn't in the catalogue yet (it ships in
  /// a later pack), instead of being reported missing.
  final bool optional;

  const ThaliPresetItemDefinition({
    required this.foodSourceRef,
    required this.displayName,
    required this.amount,
    this.foodId,
    this.optional = false,
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

  /// Shown first in the quick start on a marked vrat day (UF-9), and only
  /// then. Catalogue foods only: sabudana khichdi, curd and a banana from
  /// pack 7; kuttu roti and vrat aloo join once pack 8 is installed.
  static const ThaliPresetDefinition vratThali = ThaliPresetDefinition(
    id: 'vrat_thali',
    name: 'Vrat Thali',
    description: 'Sabudana Khichdi, Curd & Fruit',
    items: [
      ThaliPresetItemDefinition(
        foodSourceRef: 'usda-staples-v1:sabudana khichdi',
        foodId: 'food-usda-0078',
        displayName: 'Sabudana Khichdi',
        amount: 1,
      ),
      ThaliPresetItemDefinition(
        foodSourceRef: 'usda-vrat-v1:kuttu roti',
        foodId: 'food-usda-0309',
        displayName: 'Kuttu Roti',
        amount: 2,
        optional: true,
      ),
      ThaliPresetItemDefinition(
        foodSourceRef: 'usda-vrat-v1:vrat aloo (sendha namak)',
        foodId: 'food-usda-0312',
        displayName: 'Vrat Aloo',
        amount: 1,
        optional: true,
      ),
      _curd,
      ThaliPresetItemDefinition(
        foodSourceRef: 'usda-staples-v1:banana',
        foodId: 'food-usda-0001',
        displayName: 'Banana',
        amount: 1,
      ),
    ],
  );

  /// The quick start's presets; on a vrat day the Vrat Thali leads.
  static List<ThaliPresetDefinition> forDay({required bool vratDay}) =>
      vratDay ? [vratThali, ...all] : all;

  static const List<ThaliPresetDefinition> all = [
    northIndianClassic,
    southIndianMeals,
    highProteinVeg,
    highProteinNonVeg,
  ];
}
