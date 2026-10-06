import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/catalog/catalog_pack.dart';

import 'support/real_catalogue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled catalogue pack v1 (audit C-01)', () {
    late RealCatalogue catalogue;

    setUp(() async => catalogue = await RealCatalogue.open());
    tearDown(() => catalogue.close());

    test('every active catalogue food has current energy', () async {
      final rows = await catalogue.db
          .customSelect(
            "SELECT f.id FROM nutrition_foods f WHERE f.lifecycle = 'active' "
            "AND f.id LIKE 'food-seed-%' AND NOT EXISTS ("
            'SELECT 1 FROM nutrition_food_nutrient_facts n '
            "WHERE n.food_id = f.id AND n.nutrient_id = 'energy' "
            'AND n.is_current = 1 AND n.amount IS NOT NULL)',
          )
          .get();
      expect(rows.map((row) => row.read<String>('id')), isEmpty);
      final state = await catalogue.db.select(catalogue.db.catalogState).get();
      expect(state.single.version, kBundledCatalogPackVersion);
      expect(state.single.source, 'bundled');
    });

    test('2 rotis in a thali give 170 kcal with nothing unresolved', () async {
      final roti = await catalogue.foodId('Whole Wheat Roti / Chapati');
      final draft = catalogue.thali.newDraft(
        userId: 'user',
        items: [
          NutritionThaliItem(
            id: 'item-roti',
            position: 0,
            source: NutritionThaliItemSource.food,
            foodId: roti,
            recipeVersionId: null,
            quantity: CatalogueServing.quantity(roti, 2),
          ),
        ],
      );
      final preview = await catalogue.thali.preview(draft: draft);
      expect(preview.aggregate.facts['energy']?.point?.value.toString(), '170');
      // Only the micronutrients the catalogue doesn't carry stay unknown.
      expect(
        preview.items.single.calculation.unresolvedInputs,
        isNot(contains('item-roti:energy')),
      );
    });

    test('2 pieces of roti give the same 170 kcal', () async {
      final roti = await catalogue.foodId('Whole Wheat Roti / Chapati');
      final draft = catalogue.thali.newDraft(
        userId: 'user',
        items: [
          NutritionThaliItem(
            id: 'item-roti',
            position: 0,
            source: NutritionThaliItemSource.food,
            foodId: roti,
            recipeVersionId: null,
            quantity: Quantity.fromNum(amount: 2, unit: QuantityUnit.piece),
          ),
        ],
      );
      final preview = await catalogue.thali.preview(draft: draft);
      expect(preview.aggregate.facts['energy']?.point?.value.toString(), '170');
    });
  });
}
