import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/food_identity_manifest.dart';
import 'package:indifit/data/catalog/catalog_search_index.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/services/nutrition_food_search_ranking.dart';

import 'support/real_catalogue.dart';

/// CAT-9 (PR-I): on-device full-text search over the catalogue's names and
/// pack aliases, with prefix and typo matching, on the real bundled pack.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RealCatalogue catalogue;
  late CatalogSearchIndex index;

  setUp(() async {
    catalogue = await RealCatalogue.open();
    index = CatalogSearchIndex(catalogue.db);
  });
  tearDown(() => catalogue.close());

  Future<List<String>> names(String query) async {
    final hits = await index.search(query);
    final ids = hits.map((hit) => hit.foodId).toList();
    final rows = await (catalogue.db.select(
      catalogue.db.nutritionFoods,
    )..where((food) => food.id.isIn(ids))).get();
    final byId = {for (final row in rows) row.id: row.displayName};
    return [for (final id in ids) byId[id]!];
  }

  test('FTS5 is available and the index is built on open', () async {
    final count = await catalogue.db
        .customSelect('SELECT count(*) AS n FROM ${CatalogSearchIndex.table}')
        .getSingle();
    // Every active catalogue food of pack v2.
    expect(count.read<int>('n'), greaterThanOrEqualTo(498));
  });

  test('"arhar dal" finds Toor Dal through its pack alias', () async {
    expect(await names('arhar dal'), contains('Toor Dal / Yellow Dal Tadka'));
  });

  test('"chapti" finds Chapati despite the typo', () async {
    expect(await names('chapti'), contains('Whole Wheat Roti / Chapati'));
  });

  test('prefixes and any word order match', () async {
    expect(await names('toor'), contains('Toor Dal / Yellow Dal Tadka'));
    expect(await names('tadka dal'), contains('Toor Dal / Yellow Dal Tadka'));
    expect(await names('panee'), contains('Mattar Paneer'));
  });

  test('retired foods never come back', () async {
    final retiredIds = kRetiredCatalogueFoods.keys.toSet();
    for (final query in ['idli', 'dosa', 'paneer', 'chicken', 'samosa']) {
      final hits = await index.search(query);
      expect(
        hits.map((hit) => hit.foodId).where(retiredIds.contains),
        isEmpty,
        reason: query,
      );
    }
  });

  test('a search over 3,000 foods takes under 50 ms', () async {
    final db = catalogue.db;
    final now = DateTime.utc(2026, 10, 8);
    await db.batch((batch) {
      batch.insertAll(db.nutritionFoods, [
        for (var i = 0; i < 2600; i++)
          NutritionFoodsCompanion.insert(
            id: 'perf-food-$i',
            kind: 'canonical',
            displayName: 'Test dish $i masala ${i.isEven ? 'tadka' : 'fry'}',
            locale: 'en-IN',
            sourceType: 'bundled_asset',
            sourceRef: Value('perf:$i'),
            sourceVersion: const Value('perf'),
            lifecycle: 'active',
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
      ]);
    });
    await index.rebuild();
    final count = await db
        .customSelect('SELECT count(*) AS n FROM ${CatalogSearchIndex.table}')
        .getSingle();
    expect(count.read<int>('n'), greaterThanOrEqualTo(3000));

    await index.search('dal tadka'); // warm the statement cache
    final times = <int>[];
    for (final query in ['dal tadka', 'paneer', 'masala fry', 'roti', 'rice']) {
      final watch = Stopwatch()..start();
      await index.search(query);
      times.add(watch.elapsedMilliseconds);
    }
    times.sort();
    expect(times[times.length ~/ 2], lessThan(50), reason: '$times ms');
  });

  test('the food screen keeps an alias hit through its ranking', () async {
    final found = await FoodRepository(
      catalogue.db,
    ).searchCatalogueIndex('arhar dal');
    final toor = found.items.singleWhere(
      (item) => item.name == 'Toor Dal / Yellow Dal Tadka',
    );
    final terms = found.matchedTerms[toor.id]!;
    expect(terms.join(' '), contains('arhar'));

    final ranked = NutritionFoodSearchRanking.rank(
      query: 'arhar dal',
      candidates: [
        NutritionFoodSearchCandidate.legacy(toor, matchedTerms: terms),
      ],
    );
    expect(ranked.single.candidate.displayName, toor.name);

    // Without the matched terms the ranking would drop it.
    expect(
      NutritionFoodSearchRanking.rank(
        query: 'arhar dal',
        candidates: [NutritionFoodSearchCandidate.legacy(toor)],
      ),
      isEmpty,
    );
  });
}
