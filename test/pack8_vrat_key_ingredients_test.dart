import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/catalog/catalog_pack.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/real_catalogue.dart';

/// Pack 8: vrat foods (SR Legacy) and dishes' key ingredients (TF-2 C).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  CatalogPack bundledPack() {
    final manifest = CatalogPackManifest.parse(
      jsonDecode(File(kBundledCatalogManifestAsset).readAsStringSync()),
    );
    final entry = manifest.fullPack(kBundledCatalogPackVersion);
    final registry =
        jsonDecode(
              File('assets/data/nutrient_registry.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    return CatalogPack.decode(
      File('$kBundledCatalogAssetDirectory${entry.url}').readAsBytesSync(),
      expectedSha256: entry.sha256,
      registryVersion: '${registry['registry_version']}',
      nutrientIds: {
        for (final nutrient in registry['nutrients'] as List)
          (nutrient as Map<String, dynamic>)['id'] as String,
      },
    );
  }

  test('pack 8 is bundled; dishes carry their key ingredients', () {
    expect(kBundledCatalogPackVersion, greaterThanOrEqualTo(8));
    final pack = bundledPack();
    final foods = {for (final f in pack.foods) f.displayName: f};
    expect(foods['Kadai Paneer']!.keyIngredients, [
      'paneer',
      'capsicum',
      'onion',
      'tomato',
    ]);
    expect(foods['Kuttu Puri']!.keyIngredients, ['kuttu atta', 'potato']);
    // Single foods and variants have none.
    expect(foods['Kuttu Atta (Buckwheat Flour)']!.keyIngredients, isEmpty);
    final variants = pack.foods.where(
      (f) => f.variantOf == foods['Kadai Paneer']!.id,
    );
    expect(variants, isNotEmpty);
    for (final variant in variants) {
      expect(variant.keyIngredients, isEmpty);
    }
  });

  test('every key ingredient is in the bundled vocabulary', () {
    final vocabulary =
        (jsonDecode(
                  File(
                    '${kBundledCatalogAssetDirectory}key_ingredients.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['vocabulary']
            as Map<String, dynamic>;
    for (final food in bundledPack().foods) {
      for (final word in food.keyIngredients) {
        expect(vocabulary, contains(word), reason: food.displayName);
      }
    }
  });

  group('vrat foods', () {
    late RealCatalogue c;
    setUp(() async => c = await RealCatalogue.open());
    tearDown(() => c.close());

    test('kuttu atta is SR Legacy 170687 per 100 g', () async {
      final option = (await c.catalog.getOption('food-usda-0307'))!;
      expect(option.displayName, 'Kuttu Atta (Buckwheat Flour)');
      final serving = option.defaultLoggingQuantity;
      expect(serving.unit, QuantityUnit.gram);
      expect(serving.amount.asDouble, 50);
    });

    test('vrat words find the vrat foods', () async {
      final repo = FoodRepository(c.db);
      for (final (query, id) in [
        ('kuttu', 'food-usda-0307'),
        ('kuttu puri', 'food-usda-0308'),
        ('rajgira ladoo', 'food-usda-0311'),
        ('vrat aloo', 'food-usda-0312'),
        ('shakarkandi chaat', 'food-usda-0313'),
        ('makhana kheer', 'food-usda-0314'),
      ]) {
        final hits = await repo.searchCatalogueOnlyFoods(query);
        expect(hits.map((hit) => hit.foodId), contains(id), reason: query);
      }
    });
  });
}
