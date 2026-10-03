import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/food_identity_manifest.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';

void main() {
  // The database seeds the food catalogue from assets via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('catalogue duplicate merge (2026-10-03)', () {
    late AppDatabase db;
    late NutritionFoodCatalogRepository catalog;

    setUp(() {
      db = AppDatabase.memory();
      catalog = NutritionFoodCatalogRepository(
        db: db,
        registry: NutrientRegistry.fromAssetFileSync(
          'assets/data/nutrient_registry.json',
        ),
      );
    });

    tearDown(() => db.close());

    test('the manifest and kRetiredCatalogueFoods agree', () {
      final manifest = FoodIdentityManifest.loadFromAssetFileSync();
      final deprecated = {
        for (final entry in manifest.catalogueEntries)
          if (entry.deprecated) entry.id: entry.replacementId,
      };
      expect(deprecated, kRetiredCatalogueFoods);

      final byId = {for (final e in manifest.entries) e.id: e};
      for (final replacement in kRetiredCatalogueFoods.values) {
        expect(byId[replacement]?.deprecated, isFalse, reason: replacement);
      }
    });

    test('retired duplicates leave both search paths', () async {
      final names = (await catalog.search(
        query: 'dal tadka',
      )).map((o) => o.displayName).toSet();
      expect(names, contains('Toor Dal / Yellow Dal Tadka'));
      expect(names, isNot(contains('Yellow Dal Tadka')));

      final legacy = (await FoodRepository(
        db,
      ).searchFoodLocal('rajma')).map((f) => f.name).toSet();
      expect(legacy, contains('Rajma Masala (Red Kidney Beans)'));
      expect(legacy, isNot(contains('Rajma Masala (Kidney Beans)')));
    });

    test(
      'nonsense dairy variants leave search; their base foods stay',
      () async {
        for (final (query, base) in [
          ('toned milk', 'Toned Milk (1 Glass)'),
          ('lassi', 'Masala Lassi (Sweet)'),
          ('fresh paneer', 'Amul Fresh Paneer (Raw)'),
          ('low fat paneer', 'Low Fat Paneer'),
        ]) {
          final names = (await catalog.search(
            query: query,
          )).map((o) => o.displayName).toList();
          expect(names, contains(base), reason: query);
          expect(
            names.where(
              (n) => n.contains('(Double Paneer)') || n.contains('(Low Oil'),
            ),
            isEmpty,
            reason: query,
          );
        }
      },
    );

    test('a retired food keeps its identity and facts for past logs', () async {
      // Searching adapts legacy rows, writing their facts as logging did.
      await catalog.search(query: 'yellow dal tadka');

      final row = await (db.select(
        db.nutritionFoods,
      )..where((food) => food.id.equals('food-seed-0570'))).getSingle();
      expect(row.lifecycle, 'deprecated');
      final facts = await (db.select(
        db.nutritionFoodNutrientFacts,
      )..where((fact) => fact.foodId.equals('food-seed-0570'))).get();
      expect(facts, isNotEmpty);
      // No parallel identity was minted for the retired legacy row.
      final parallel = await (db.select(
        db.nutritionFoods,
      )..where((food) => food.displayName.equals('Yellow Dal Tadka'))).get();
      expect(parallel.map((r) => r.id), ['food-seed-0570']);
    });

    test('installs seeded before the merge are brought in line', () async {
      final retired = kRetiredCatalogueFoods.keys.toList();
      await (db.update(db.nutritionFoods)
            ..where((food) => food.id.isIn(retired)))
          .write(const NutritionFoodsCompanion(lifecycle: Value('active')));

      await db.retireMergedCatalogueDuplicates();
      await db.retireMergedCatalogueDuplicates(); // idempotent

      final rows = await (db.select(
        db.nutritionFoods,
      )..where((food) => food.id.isIn(retired))).get();
      expect(rows, hasLength(retired.length));
      expect(rows.map((r) => r.lifecycle).toSet(), {'deprecated'});
    });
  });
}
