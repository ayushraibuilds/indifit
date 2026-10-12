// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/catalog/food_category_taxonomy.dart';

// Categories added for the 12 Oct staples draft
// (docs/audit/food-search-2026-10-12/staples_draft.csv).
void main() {
  String resolve(String name, [String? category]) =>
      FoodCategoryTaxonomy.resolveCategoryId(name: name, rawCategory: category);

  test('every draft category maps to a serving group', () {
    expect(resolve('Anything', 'Fruits'), FoodCategoryTaxonomy.fruit);
    expect(resolve('Anything', 'Nuts & Seeds'), FoodCategoryTaxonomy.nutSeed);
    expect(
      resolve('Anything', 'Breakfast Cereals'),
      FoodCategoryTaxonomy.breakfastCereal,
    );
    expect(resolve('Anything', 'Supplements'), FoodCategoryTaxonomy.supplement);
    expect(
      resolve('Anything', 'Sweets & Desserts'),
      FoodCategoryTaxonomy.sweetDessert,
    );
    expect(
      resolve('Anything', 'Rice & Rice Dishes'),
      FoodCategoryTaxonomy.stapleRice,
    );
    expect(
      resolve('Anything', 'Western & Fast Food'),
      FoodCategoryTaxonomy.snackStreet,
    );
    expect(
      resolve('Anything', 'Packaged Snacks'),
      FoodCategoryTaxonomy.snackStreet,
    );
  });

  test('names alone place the new groups', () {
    expect(resolve('Banana'), FoodCategoryTaxonomy.fruit);
    expect(resolve('Apple'), FoodCategoryTaxonomy.fruit);
    expect(resolve('Almonds'), FoodCategoryTaxonomy.nutSeed);
    expect(resolve('Makhana (Roasted)'), FoodCategoryTaxonomy.nutSeed);
    expect(resolve('Muesli'), FoodCategoryTaxonomy.breakfastCereal);
    expect(resolve('Whey Protein'), FoodCategoryTaxonomy.supplement);
  });

  test('look-alike names keep their old groups', () {
    expect(resolve('Mango Lassi'), FoodCategoryTaxonomy.dairyLiquid);
    expect(resolve('Gulab Jamun'), FoodCategoryTaxonomy.sweetDessert);
    expect(resolve('Raw Banana Stir Fry'), isNot(FoodCategoryTaxonomy.fruit));
    expect(resolve('Banana Chips'), isNot(FoodCategoryTaxonomy.fruit));
    expect(resolve('Peanut Chikki'), isNot(FoodCategoryTaxonomy.nutSeed));
    expect(resolve('Dal Makhani'), FoodCategoryTaxonomy.dalLentil);
    expect(resolve('Oats Upma'), isNot(FoodCategoryTaxonomy.breakfastCereal));
  });

  test('new groups offer household measures', () {
    List<String> units(String id) => [
      for (final option in FoodCategoryTaxonomy.servingOptionsForCategory(
        categoryId: id,
      ))
        option.unitName,
    ];
    expect(units(FoodCategoryTaxonomy.fruit), contains('fruit_piece'));
    expect(units(FoodCategoryTaxonomy.nutSeed), contains('handful'));
    expect(
      units(FoodCategoryTaxonomy.breakfastCereal),
      contains('cereal_bowl'),
    );
    expect(units(FoodCategoryTaxonomy.supplement), contains('scoop'));
  });
}
