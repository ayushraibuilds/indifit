import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/food_identity_manifest.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/catalog/catalog_pack.dart';
import 'package:indifit/data/catalog/catalog_pack_importer.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionThaliItem;
import 'package:indifit/data/repositories/food_repository.dart';

import 'support/real_catalogue.dart';

/// Catalogue pack v2 (CAT-6): the curated overlay built by
/// tool/catalog/build.py and bundled with the app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pack v2 upgrade (CAT-6)', () {
    late RealCatalogue catalogue;
    late CatalogPackImporter importer;

    setUp(() async {
      catalogue = await RealCatalogue.open();
      importer = CatalogPackImporter(
        db: catalogue.db,
        nutrientIds: catalogue.registry.definitions.map((d) => d.id),
      );
      await _resetToBeforePacks(catalogue.db);
    });
    tearDown(() => catalogue.close());

    test('the importer applies v1 then v2, and v2 again is a no-op', () async {
      expect(
        (await importer.apply(
          _builtPack(catalogue, '1.json.gz'),
          source: 'bundled',
        )).applied,
        isTrue,
      );
      final doubleRoti = await catalogue.foodId(
        'Whole Wheat Roti / Chapati (Double)',
      );
      expect(await _conversion(catalogue.db, doubleRoti, 'piece'), 1);
      // v1 predates `variant_of`, so the identity manifest's links stay.
      // Legacy rows share the base names; the pack names the pack's ids.
      final ids = {
        for (final food in (_bundledJson()['foods'] as List).cast<Map>())
          food['display_name'] as String: food['id'] as String,
      };
      final roti = ids['Whole Wheat Roti / Chapati'];
      final miniDosa = await catalogue.foodId('Masala Dosa (Mini size)');
      expect(await _variantOf(catalogue.db, doubleRoti), roti);
      expect(await _variantOf(catalogue.db, miniDosa), isNull);

      final v2 = _builtPack(catalogue, '2.json.gz');
      final first = await importer.apply(v2, source: 'bundled');
      expect(first.applied, isTrue);
      final after = await _state(catalogue.db);
      expect(await importer.installedVersion(), 2);
      expect(await _conversion(catalogue.db, doubleRoti, 'piece'), 2);
      // v2 declares `variant_of`, which the manifest missed for Mini size.
      expect(await _variantOf(catalogue.db, doubleRoti), roti);
      expect(await _variantOf(catalogue.db, miniDosa), ids['Masala Dosa']);
      final dal = await catalogue.foodId('Toor Dal / Yellow Dal Tadka');
      expect(await _conversion(catalogue.db, dal, 'gram'), 150);
      // A gram-as-katori row becomes grams: a new fact version per 100 g.
      final mini = await catalogue.foodId('Basmati White Rice (Cooked) (Mini)');
      final energy = await _energy(catalogue.db, mini);
      expect(
        (energy.basis, energy.amount, energy.factVersion),
        ('per_100_grams', 130, 2),
      );
      expect(await _conversion(catalogue.db, mini, 'katori'), isNull);
      // The importer writes the pack's aliases.
      final arhar =
          await (catalogue.db.select(catalogue.db.nutritionFoodAliases)..where(
                (a) => a.normalizedAlias.equals('arhar dal / yellow dal tadka'),
              ))
              .getSingle();
      expect(
        (arhar.foodId, arhar.locale, arhar.source),
        (dal, 'hi-Latn', 'catalog-pack'),
      );

      final again = await importer.apply(v2, source: 'bundled');
      expect(again.applied, isFalse);
      expect(await _state(catalogue.db), after);
    });

    test(
      'the delta from v1 gives the same catalogue as the full pack',
      () async {
        await importer.apply(
          _builtPack(catalogue, '1.json.gz'),
          source: 'bundled',
        );
        await importer.apply(
          _builtPack(catalogue, '2-from-1.json.gz'),
          source: 'download',
        );
        final viaDelta = await _state(catalogue.db);

        final fresh = await RealCatalogue.open();
        addTearDown(fresh.close);
        expect(await _state(fresh.db), viaDelta);
      },
    );
  });

  group('bundled pack v2 content', () {
    late RealCatalogue catalogue;

    setUp(() async => catalogue = await RealCatalogue.open());
    tearDown(() => catalogue.close());

    test('retired templated variants are hidden from search (C-09)', () async {
      const kept = 'Idli with Sambar (2 Idlis)';
      const retired = 'Idli with Sambar (2 Idlis) (With extra cheese / butter)';
      final catalog = (await catalogue.catalog.search(
        query: 'idli',
      )).map((option) => option.displayName).toSet();
      final thali = (await catalogue.thali.searchFoods(
        query: 'idli',
      )).map((option) => option.displayName).toSet();
      final legacy = (await FoodRepository(
        catalogue.db,
      ).searchFoodLocal('idli')).map((food) => food.name).toSet();
      for (final names in [catalog, thali, legacy]) {
        expect(names, contains(kept));
        expect(names, isNot(contains(retired)));
      }
    });

    test(
      'variant links come from the pack, and kinds stay as they were',
      () async {
        final pack = _bundledJson();
        final expected = {
          for (final food in (pack['foods'] as List).cast<Map>())
            food['id'] as String: food['variant_of'] as String?,
        };
        final rows = await catalogue.db
            .customSelect(
              'SELECT id, kind, variant_of_food_id FROM nutrition_foods '
              'WHERE id IN (SELECT value FROM json_each(?))',
              variables: [Variable(jsonEncode(expected.keys.toList()))],
            )
            .get();
        expect(rows, hasLength(expected.length));
        expect({
          for (final row in rows)
            row.read<String>('id'): row.read<String?>('variant_of_food_id'),
        }, expected);
        // Search ranking reads `kind`; the pack doesn't rewrite it, so the
        // manifest's "canonical" Mini size dosa keeps its kind.
        final miniDosa = await catalogue.foodId('Masala Dosa (Mini size)');
        expect(
          rows
              .singleWhere((row) => row.read<String>('id') == miniDosa)
              .read<String>('kind'),
          'canonical',
        );
      },
    );

    test('no household-unit serving is more than 6 units (C-04)', () async {
      final rows = await catalogue.db
          .customSelect(
            'SELECT f.display_name AS name, c.target_unit AS unit, '
            'c.factor AS factor FROM nutrition_quantity_conversions c '
            'JOIN nutrition_foods f ON f.id = c.food_id '
            "WHERE c.rule_version = 'catalog-pack' "
            "AND c.source_unit = 'serving' "
            "AND c.target_unit NOT IN ('gram', 'millilitre') "
            "AND f.lifecycle = 'active' AND c.factor > 6",
          )
          .get();
      expect(
        rows.map(
          (row) =>
              '${row.read<String>('name')}: '
              '${row.read<double>('factor')} ${row.read<String>('unit')}',
        ),
        isEmpty,
      );
    });

    test(
      "a variant's kcal per gram is within 25 % of its base unless size/oil",
      () {
        final pack = _bundledJson();
        final retired = {
          for (final entry in pack['retire'] as List) entry['id'] as String,
        };
        final foods = (pack['foods'] as List).cast<Map<String, dynamic>>();
        final byName = {for (final food in foods) food['display_name']: food};
        final pattern = RegExp(r'^(.*) \(([^()]*)\)$');
        final violations = <String>[];
        var compared = 0;
        for (final food in foods) {
          if (retired.contains(food['id'])) continue;
          final match = pattern.firstMatch(food['display_name'] as String);
          final base = match == null ? null : byName[match.group(1)];
          if (base == null) continue;
          final tags = (food['tags'] as List?)?.cast<String>() ?? const [];
          if (tags.contains('size') || tags.contains('oil')) continue;
          final (variantGram, variantUnit, variantMeasure) = _kcalPer(food);
          final (baseGram, baseUnit, baseMeasure) = _kcalPer(base);
          final double ratio;
          if (variantGram != null && baseGram != null) {
            ratio = variantGram / baseGram;
          } else if (variantMeasure == baseMeasure) {
            ratio = variantUnit / baseUnit;
          } else {
            continue;
          }
          compared++;
          if ((ratio - 1).abs() > 0.25) {
            violations.add(
              '${food['display_name']}: ${ratio.toStringAsFixed(2)}x',
            );
          }
        }
        expect(violations, isEmpty);
        // Every untagged "Double…" and "Small side bowl" variant.
        expect(compared, 57);
      },
    );

    test('a "Double" roti is 2 rotis: 2 pieces give 170 kcal', () async {
      for (final name in [
        'Whole Wheat Roti / Chapati',
        'Whole Wheat Roti / Chapati (Double)',
      ]) {
        final id = await catalogue.foodId(name);
        final preview = await catalogue.thali.preview(
          draft: _draft(catalogue, [
            (id, Quantity.fromNum(amount: 2, unit: QuantityUnit.piece)),
          ]),
        );
        expect(_kcal(preview), '170', reason: name);
      }
      final doubleRoti = await catalogue.foodId(
        'Whole Wheat Roti / Chapati (Double)',
      );
      final serving = await catalogue.thali.preview(
        draft: _draft(catalogue, [
          (doubleRoti, CatalogueServing.quantity(doubleRoti, 1)),
        ]),
      );
      expect(_kcal(serving), '170');
    });

    test('kRetiredCatalogueFoods is the bundled pack\'s retire list', () {
      final pack = _bundledJson();
      expect({
        for (final entry in pack['retire'] as List)
          entry['id'] as String: entry['replaced_by'] as String,
      }, kRetiredCatalogueFoods);
    });

    test('Hinglish aliases from the pack find foods (arhar → toor)', () async {
      final names = (await catalogue.thali.searchFoods(
        query: 'arhar',
      )).map((option) => option.displayName);
      expect(names, contains('Toor Dal / Yellow Dal Tadka'));
    });
  });
}

/// A device on the pre-pack catalogue: no pack state, facts, conversions or
/// aliases, only the retirements made before packs existed, and the identity
/// manifest's variant links.
Future<void> _resetToBeforePacks(AppDatabase db) async {
  final manifest =
      jsonDecode(
            File(
              'assets/data/nutrition_food_identity_manifest.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  await db.customStatement(
    'UPDATE nutrition_foods SET variant_of_food_id = '
    "(SELECT json_extract(value, '\$.parent_id') FROM json_each(?) "
    "WHERE json_extract(value, '\$.id') = nutrition_foods.id) "
    "WHERE id LIKE 'food-seed-%'",
    [jsonEncode(manifest['entries'])],
  );
  await db.customStatement(
    "DELETE FROM nutrition_food_nutrient_facts WHERE source_ref LIKE 'catalog-pack:%'",
  );
  await db.customStatement(
    "DELETE FROM nutrition_quantity_conversions WHERE rule_version = '$kCatalogPackConversionRule'",
  );
  await db.customStatement(
    "DELETE FROM nutrition_food_aliases WHERE source = 'catalog-pack'",
  );
  await db.customStatement('DELETE FROM catalog_state');
  await db.customStatement(
    "UPDATE nutrition_foods SET lifecycle = 'active' "
    "WHERE lifecycle = 'deprecated' AND id LIKE 'food-seed-%'",
  );
}

CatalogPack _builtPack(RealCatalogue catalogue, String file) {
  final manifest =
      jsonDecode(File('tool/catalog/packs/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  final entry = (manifest['packs'] as List).cast<Map>().singleWhere(
    (pack) => (pack['url'] as String).endsWith('/$file'),
  );
  return CatalogPack.decode(
    File('tool/catalog/packs/${entry['url']}').readAsBytesSync(),
    expectedSha256: entry['sha256'] as String,
    registryVersion: '${catalogue.registry.version}',
    nutrientIds: catalogue.registry.definitions.map((d) => d.id).toSet(),
  );
}

Map<String, dynamic> _bundledJson() {
  final manifest = CatalogPackManifest.parse(
    jsonDecode(File(kBundledCatalogManifestAsset).readAsStringSync()),
  );
  final entry = manifest.fullPack(kBundledCatalogPackVersion);
  return jsonDecode(
        utf8.decode(
          gzip.decode(
            File(
              '$kBundledCatalogAssetDirectory${entry.url}',
            ).readAsBytesSync(),
          ),
        ),
      )
      as Map<String, dynamic>;
}

/// (kcal per gram or null, kcal per unit, unit) of a pack food's serving.
(double?, double, String) _kcalPer(Map<String, dynamic> food) {
  final serving = (food['servings'] as List).cast<Map>().firstWhere(
    (s) => s['default'] == true,
  );
  final facts = food['facts'] as Map;
  final energy = ((facts['values'] as Map)['energy'] as num).toDouble();
  final amount = (serving['amount'] as num).toDouble();
  final grams = (serving['grams'] as num?)?.toDouble();
  final perServing = switch (facts['basis']) {
    'per_100_grams' => energy * grams! / 100,
    'per_100_millilitres' => energy * amount / 100,
    _ => energy,
  };
  return (
    grams == null ? null : perServing / grams,
    perServing / amount,
    serving['unit'] as String,
  );
}

Future<double?> _conversion(AppDatabase db, String foodId, String to) async {
  final row = await db
      .customSelect(
        'SELECT factor FROM nutrition_quantity_conversions '
        "WHERE food_id = ? AND source_unit = 'serving' AND target_unit = ?",
        variables: [Variable(foodId), Variable(to)],
      )
      .getSingleOrNull();
  return row?.read<double>('factor');
}

Future<String?> _variantOf(AppDatabase db, String foodId) async =>
    (await (db.select(
      db.nutritionFoods,
    )..where((f) => f.id.equals(foodId))).getSingle()).variantOfFoodId;

Future<NutritionFoodNutrientFact> _energy(AppDatabase db, String foodId) =>
    (db.select(db.nutritionFoodNutrientFacts)..where(
          (f) =>
              f.foodId.equals(foodId) &
              f.nutrientId.equals('energy') &
              f.isCurrent.equals(true),
        ))
        .getSingle();

/// The catalogue as the app reads it: current facts, pack conversions, pack
/// aliases and lifecycles.
Future<List<String>> _state(AppDatabase db) async {
  final rows = <String>[];
  for (final query in [
    'SELECT food_id, nutrient_id, amount, status, basis FROM '
        'nutrition_food_nutrient_facts WHERE is_current = 1 '
        'AND preparation_id IS NULL ORDER BY 1, 2',
    'SELECT food_id, source_unit, target_unit, factor FROM '
        'nutrition_quantity_conversions ORDER BY 1, 2, 3',
    'SELECT food_id, alias, locale FROM nutrition_food_aliases '
        "WHERE source = 'catalog-pack' ORDER BY 1, 2",
    'SELECT id, display_name, lifecycle, variant_of_food_id FROM nutrition_foods '
        "WHERE id LIKE 'food-seed-%' ORDER BY 1",
  ]) {
    for (final row in await db.customSelect(query).get()) {
      rows.add(row.data.values.join('|'));
    }
  }
  return rows;
}

NutritionThaliDraft _draft(
  RealCatalogue catalogue,
  List<(String, Quantity)> items,
) => catalogue.thali.newDraft(
  userId: 'user',
  items: [
    for (var i = 0; i < items.length; i++)
      NutritionThaliItem(
        id: 'item-$i',
        position: i,
        source: NutritionThaliItemSource.food,
        foodId: items[i].$1,
        recipeVersionId: null,
        quantity: items[i].$2,
        measureId: null,
      ),
  ],
);

String? _kcal(NutritionThaliPreview preview) =>
    preview.aggregate.facts['energy']?.point?.value.toString();
