import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/catalog/catalog_pack.dart';
import 'package:indifit/data/catalog/catalog_pack_importer.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot, NutritionThaliItem;
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/features/food_log/thali/thali_nutrition_summary_bar.dart';
import 'package:indifit/features/food_log/thali/thali_presets.dart';
import 'package:indifit/features/food_log/thali/thali_route.dart';

import 'support/real_catalogue.dart';

const _roti = 'Whole Wheat Roti / Chapati';
const _dal = 'Toor Dal / Yellow Dal Tadka';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled catalogue pack v1 (audit C-01)', () {
    late RealCatalogue catalogue;

    setUp(() async => catalogue = await RealCatalogue.open());
    tearDown(() => catalogue.close());

    test('every active catalogue food has current energy', () async {
      expect(await _foodsWithoutEnergy(catalogue.db), isEmpty);
      final state = await catalogue.db.select(catalogue.db.catalogState).get();
      expect(state.single.version, kBundledCatalogPackVersion);
      expect(state.single.source, 'bundled');
      expect(state.single.foodCount, 573);
    });

    test('2 roti servings in a thali give 170 kcal', () async {
      final roti = await catalogue.foodId(_roti);
      final preview = await catalogue.thali.preview(
        draft: _draft(catalogue, [(roti, CatalogueServing.quantity(roti, 2))]),
      );
      expect(_kcal(preview), '170');
      expect(preview.itemsWithUnknownEnergy, isEmpty);
      // Only the micronutrients the catalogue doesn't carry stay unknown.
      expect(
        preview.items.single.calculation.unresolvedInputs,
        isNot(contains('item-0:energy')),
      );
    });

    test('pieces, katoris and multi-piece servings convert', () async {
      final roti = await catalogue.foodId(_roti);
      final dal = await catalogue.foodId(_dal);
      final eggs = await catalogue.foodId('Boiled Eggs (2 pieces)');
      final preview = await catalogue.thali.preview(
        draft: _draft(catalogue, [
          (roti, Quantity.fromNum(amount: 2, unit: QuantityUnit.piece)),
          (dal, _katori(1.5)),
          (eggs, Quantity.fromNum(amount: 2, unit: QuantityUnit.piece)),
        ]),
      );
      final kcal = preview.items
          .map((item) => item.calculation.facts['energy']!.point!.value)
          .map((value) => value.toString())
          .toList();
      // 2 × 85; 1.5 × 140; one serving of "Boiled Eggs (2 pieces)" is 155.
      expect(kcal, ['170', '210', '155']);
    });

    test('grams convert only through a known gram weight', () async {
      // Pack v2 gives katori servings the app's 150 g katori (CAT-6), so
      // 75 g of dal is half a katori.
      final dal = await catalogue.foodId(_dal);
      final preview = await catalogue.thali.preview(
        draft: _draft(catalogue, [
          (dal, Quantity.fromNum(amount: 75, unit: QuantityUnit.gram)),
        ]),
      );
      expect(
        preview.items.single.calculation.facts['energy']!.point!.value
            .toString(),
        '70',
      );
      // A roti has no gram weight in the repo, so grams are refused, not
      // guessed.
      expect(
        () async {
          final roti = await catalogue.foodId(_roti);
          await catalogue.thali.preview(
            draft: _draft(catalogue, [
              (roti, Quantity.fromNum(amount: 40, unit: QuantityUnit.gram)),
            ]),
          );
        }(),
        throwsA(
          isA<NutritionThaliValidationError>()
              .having((e) => e.code, 'code', 'unsupported_food_unit')
              .having((e) => e.message, 'message', contains('pieces')),
        ),
      );
    });

    test('the direct-log path reads the same facts as the thali', () async {
      final legacy = await (catalogue.db.select(
        catalogue.db.foodItems,
      )..where((row) => row.name.equals(_roti))).getSingle();
      final option = await catalogue.catalog.ensureLegacyFood(legacy);
      expect(option.id, await catalogue.foodId(_roti));
      expect(option.facts['energy']!.point!.value.toString(), '85');
      // Searching never writes a second fact version over the pack's.
      await catalogue.catalog.search(query: 'roti');
      final versions = await (catalogue.db.select(
        catalogue.db.nutritionFoodNutrientFacts,
      )..where((fact) => fact.foodId.equals(option.id))).get();
      expect(versions.map((row) => row.factVersion).toSet(), {1});
    });

    test('a recipe of catalogue foods has calories (C-07)', () async {
      final roti = await catalogue.foodId(_roti);
      final dal = await catalogue.foodId(_dal);
      final draft = await catalogue.recipes.createRecipe(
        userId: 'user',
        recipeId: 'recipe-dal-roti',
        versionId: 'recipe-dal-roti-v1',
        name: 'Dal roti',
        ingredients: [
          NutritionRecipeIngredientInput.directFood(
            id: 'line-roti',
            foodId: roti,
            quantity: CatalogueServing.quantity(roti, 2),
            position: 0,
          ),
          NutritionRecipeIngredientInput.directFood(
            id: 'line-dal',
            foodId: dal,
            quantity: CatalogueServing.quantity(dal, 1),
            position: 1,
          ),
        ],
        yieldQuantity: Quantity.fromNum(amount: 1, unit: QuantityUnit.piece),
      );
      await catalogue.recipes.publishDraft(
        recipeId: 'recipe-dal-roti',
        draftVersionId: draft.version.id,
      );
      final preview = await catalogue.recipeLogging.preview(
        userId: 'user',
        recipeId: 'recipe-dal-roti',
        amount: NutritionRecipeLogAmount.wholeRecipe(),
      );
      expect(
        preview.calculation.facts['energy']!.point!.value.toString(),
        '310',
      );
    });
  });

  group('thali presets (audit C-03)', () {
    late RealCatalogue catalogue;

    setUp(() async => catalogue = await RealCatalogue.open());
    tearDown(() => catalogue.close());

    test(
      'every preset resolves to its exact foods, all with calories',
      () async {
        for (final preset in ThaliPresets.all) {
          final items = <(String, Quantity)>[];
          for (final def in preset.items) {
            final food = await catalogue.thali.findFoodBySourceRef(
              def.foodSourceRef,
            );
            expect(food, isNotNull, reason: '${preset.id}: ${def.displayName}');
            final quantity = await catalogue.thali.ownUnitQuantity(
              food!.id,
              def.amount,
            );
            items.add((food.id, quantity!));
          }
          final preview = await catalogue.thali.preview(
            draft: _draft(catalogue, items),
          );
          expect(
            preview.itemsWithUnknownEnergy,
            isEmpty,
            reason: '${preset.id} has items without calories',
          );
        }
      },
    );

    test('North Indian Classic is the plate it says it is', () async {
      final names = <String>[];
      final items = <(String, Quantity)>[];
      for (final def in ThaliPresets.northIndianClassic.items) {
        final food = await catalogue.thali.findFoodBySourceRef(
          def.foodSourceRef,
        );
        names.add(food!.displayName);
        items.add((
          food.id,
          (await catalogue.thali.ownUnitQuantity(food.id, def.amount))!,
        ));
      }
      expect(names, [
        _roti,
        _dal,
        'Mix Vegetable Sabji',
        'Basmati White Rice (Cooked)',
        'Plain Curd / Dahi (Cow Milk)',
      ]);
      final preview = await catalogue.thali.preview(
        draft: _draft(catalogue, items),
      );
      // 2 roti 170 + dal 140 + sabji 140 + rice 130 + 100 g curd 60.
      expect(_kcal(preview), '640');
    });
  });

  group('finalize guard', () {
    late RealCatalogue catalogue;

    setUp(() async => catalogue = await RealCatalogue.open());
    tearDown(() => catalogue.close());

    Future<String> insertFoodWithoutFacts() async {
      await catalogue.db
          .into(catalogue.db.nutritionFoods)
          .insert(
            NutritionFoodsCompanion.insert(
              id: 'food-no-facts',
              kind: 'canonical',
              displayName: 'Mystery sabzi',
              locale: 'en-IN',
              sourceType: 'fixture',
              lifecycle: 'active',
            ),
          );
      return 'food-no-facts';
    }

    Future<NutritionThaliPreview> mixedPreview() async {
      final roti = await catalogue.foodId(_roti);
      final mystery = await insertFoodWithoutFacts();
      return catalogue.thali.preview(
        draft: await _saved(catalogue, [
          (roti, Quantity.fromNum(amount: 2, unit: QuantityUnit.piece)),
          (mystery, Quantity.fromNum(amount: 100, unit: QuantityUnit.gram)),
        ]),
      );
    }

    test('logging refuses a thali whose calories are unknown', () async {
      final preview = await mixedPreview();
      expect(preview.itemsWithUnknownEnergy.map((i) => i.displayLabel), [
        'Mystery sabzi',
      ]);
      await expectLater(
        _finalize(catalogue, preview),
        throwsA(
          isA<NutritionThaliValidationError>()
              .having((e) => e.code, 'code', 'thali_nutrition_unknown')
              .having((e) => e.message, 'message', contains('Mystery sabzi')),
        ),
      );
    });

    test('"Log without calories" logs it on purpose', () async {
      final preview = await mixedPreview();
      final snapshot = await _finalize(
        catalogue,
        preview,
        allowUnknownEnergy: true,
      );
      expect(snapshot.items, hasLength(2));
    });

    test(
      'a known thali logs its calories on the chosen day and meal',
      () async {
        final roti = await catalogue.foodId(_roti);
        final dal = await catalogue.foodId(_dal);
        final preview = await catalogue.thali.preview(
          draft: await _saved(catalogue, [
            (roti, Quantity.fromNum(amount: 2, unit: QuantityUnit.piece)),
            (dal, _katori(1)),
          ]),
        );
        final snapshot = await _finalize(catalogue, preview);
        expect(snapshot.totals.facts['energy']!.point!.value.toString(), '310');
        expect(snapshot.localDate, '2026-10-05');
        expect(snapshot.mealCategory, 'dinner');
      },
    );
  });

  group('pack importer (CAT-2)', () {
    late RealCatalogue catalogue;
    late CatalogPackImporter importer;
    late List<String> nutrientIds;

    setUp(() async {
      catalogue = await RealCatalogue.open();
      nutrientIds = catalogue.registry.definitions.map((d) => d.id).toList();
      importer = CatalogPackImporter(
        db: catalogue.db,
        nutrientIds: nutrientIds,
      );
    });
    tearDown(() => catalogue.close());

    CatalogPack pack(Map<String, Object?> json) => CatalogPack.parse(
      json,
      sha256: 'test',
      registryVersion: '${catalogue.registry.version}',
      nutrientIds: nutrientIds.toSet(),
    );

    test('applying the installed version again is a no-op', () async {
      final before = await _factCount(catalogue.db);
      final bundled = await _bundledPack(catalogue);
      final result = await importer.apply(bundled, source: 'bundled');
      expect(result.applied, isFalse);
      expect(await _factCount(catalogue.db), before);
    });

    test('a delta on the wrong base is rejected and changes nothing', () async {
      final before = await _factCount(catalogue.db);
      final delta = pack(
        _packJson(version: 4, base: 3, kind: 'delta', energy: 90),
      );
      await expectLater(
        importer.apply(delta, source: 'download'),
        throwsA(
          isA<CatalogPackError>().having(
            (e) => e.code,
            'code',
            'base_mismatch',
          ),
        ),
      );
      expect(await importer.installedVersion(), kBundledCatalogPackVersion);
      expect(await _factCount(catalogue.db), before);
    });

    test(
      'a corrected value becomes a new fact version; logs keep theirs',
      () async {
        final roti = await catalogue.foodId(_roti);
        final logged = await _finalize(
          catalogue,
          await catalogue.thali.preview(
            draft: await _saved(catalogue, [
              (roti, CatalogueServing.quantity(roti, 1)),
            ]),
          ),
        );
        final delta = pack(
          _packJson(version: 3, base: 2, kind: 'delta', energy: 90, id: roti),
        );
        final result = await importer.apply(delta, source: 'download');
        expect(result.applied, isTrue);
        expect(result.foodsWithNewFacts, 1);

        final current =
            await (catalogue.db.select(catalogue.db.nutritionFoodNutrientFacts)
                  ..where(
                    (f) =>
                        f.foodId.equals(roti) &
                        f.nutrientId.equals('energy') &
                        f.isCurrent.equals(true),
                  ))
                .getSingle();
        expect(current.amount, 90);
        expect(current.factVersion, 2);
        final reread = await catalogue.consumption.getSnapshot(
          userId: 'user',
          consumptionId: logged.id,
        );
        expect(reread!.totals.facts['energy']!.point!.value.toString(), '85');
      },
    );

    test('a failure mid-apply leaves the previous catalogue intact', () async {
      final roti = await catalogue.foodId(_roti);
      final broken = CatalogPackImporter(
        db: catalogue.db,
        // An unknown nutrient breaks the foreign key on insert.
        nutrientIds: [...nutrientIds, 'not_a_nutrient'],
      );
      final delta = pack(
        _packJson(version: 3, base: 2, kind: 'delta', energy: 90, id: roti),
      );
      await expectLater(
        broken.apply(delta, source: 'download'),
        throwsA(anything),
      );
      expect(await importer.installedVersion(), kBundledCatalogPackVersion);
      final energy =
          await (catalogue.db.select(catalogue.db.nutritionFoodNutrientFacts)
                ..where(
                  (f) =>
                      f.foodId.equals(roti) &
                      f.nutrientId.equals('energy') &
                      f.isCurrent.equals(true),
                ))
              .getSingle();
      expect(energy.amount, 85);
    });

    test('a retirement deprecates the food without deleting it', () async {
      final roti = await catalogue.foodId(_roti);
      final json = _packJson(version: 3, base: 2, kind: 'delta', energy: 85)
        ..['retire'] = [
          {'id': roti, 'replaced_by': null},
        ];
      await importer.apply(pack(json), source: 'download');
      final row = await (catalogue.db.select(
        catalogue.db.nutritionFoods,
      )..where((f) => f.id.equals(roti))).getSingle();
      expect(row.lifecycle, 'deprecated');
    });
  });

  group('pack decoding (CAT-1)', () {
    final nutrientIds = {'energy', 'protein'};
    final json = _packJson(version: 1, kind: 'full', energy: 85);
    List<int> gz(Object value) => gzip.encode(utf8.encode(jsonEncode(value)));

    test('rejects bytes that do not match the published checksum', () {
      expect(
        () => CatalogPack.decode(
          gz(json),
          expectedSha256: 'deadbeef',
          registryVersion: '1',
          nutrientIds: nutrientIds,
        ),
        throwsA(
          isA<CatalogPackError>().having(
            (e) => e.code,
            'code',
            'sha256_mismatch',
          ),
        ),
      );
    });

    test('rejects an unknown format, and a dangling replacement', () {
      CatalogPackError? parse(Map<String, Object?> value) {
        try {
          CatalogPack.parse(
            value,
            sha256: 'x',
            registryVersion: '1',
            nutrientIds: nutrientIds,
          );
          return null;
        } on CatalogPackError catch (error) {
          return error;
        }
      }

      expect(parse({...json, 'format': 2})?.code, 'unsupported_format');
      expect(
        parse({
          ...json,
          'retire': [
            {'id': 'food-a', 'replaced_by': 'food-missing'},
          ],
        })?.code,
        'dangling_replacement',
      );
      expect(
        parse(_packJson(version: 1, kind: 'full', energy: -1))?.code,
        'invalid_value',
      );
    });

    test('reads variant_of, and rejects a self or dangling variant', () {
      CatalogPack parseFood(Map<String, Object?> extra) => CatalogPack.parse(
        {
          ...json,
          'foods': [
            {
              ...(json['foods']! as List).single as Map<String, Object?>,
              ...extra,
            },
          ],
        },
        sha256: 'x',
        registryVersion: '1',
        nutrientIds: nutrientIds,
      );
      String? code(Map<String, Object?> extra) {
        try {
          parseFood(extra);
          return null;
        } on CatalogPackError catch (error) {
          return error.code;
        }
      }

      // Format 1 packs from before the field (pack v1) don't declare it.
      final legacy = parseFood({}).foods.single;
      expect((legacy.declaresVariantOf, legacy.variantOf), (false, null));
      final base = parseFood({'variant_of': null}).foods.single;
      expect((base.declaresVariantOf, base.variantOf), (true, null));
      expect(code({'variant_of': 'food-a'}), 'invalid_variant');
      expect(code({'variant_of': 'food-missing'}), 'dangling_variant');
    });

    test('the bundled pack is the latest pack the pipeline built', () {
      // tool/catalog/validate.py (CI) checks packs/ against sources and
      // overlays; this checks the app bundles exactly that pack.
      final manifest = CatalogPackManifest.parse(
        jsonDecode(File(kBundledCatalogManifestAsset).readAsStringSync()),
      );
      final entry = manifest.fullPack(kBundledCatalogPackVersion);
      expect(manifest.latest, kBundledCatalogPackVersion);
      expect(
        File('$kBundledCatalogAssetDirectory${entry.url}').readAsBytesSync(),
        File(
          'tool/catalog/packs/v$kBundledCatalogPackVersion/'
          '$kBundledCatalogPackVersion.json.gz',
        ).readAsBytesSync(),
      );
    });
  });

  test(
    'upgrading from v23 applies the pack and keeps lazily written facts',
    () async {
      final dir = Directory.systemTemp.createTempSync('indifit_v24_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/indifit.sqlite');

      // A v23 device: catalogue seeded, no pack, roti facts written lazily by
      // an earlier food search (legacy adapter, version 1).
      var db = AppDatabase.executor(NativeDatabase(file));
      await db.customSelect('SELECT 1').get();
      await db.customStatement(
        "DELETE FROM nutrition_food_nutrient_facts WHERE source_ref LIKE 'catalog-pack:%'",
      );
      await db.customStatement('DELETE FROM nutrition_quantity_conversions');
      await db.customStatement('DROP TABLE catalog_state');
      final catalog = NutritionFoodCatalogRepository(
        db: db,
        registry: RealCatalogue.loadRegistry(),
      );
      final rotiRow = await (db.select(
        db.foodItems,
      )..where((row) => row.name.equals(_roti))).getSingle();
      final lazy = await catalog.ensureLegacyFood(rotiRow);
      await db.customStatement('PRAGMA user_version = 23');
      await db.close();

      db = AppDatabase.executor(NativeDatabase(file));
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      expect(
        (await db.select(db.catalogState).get()).single.version,
        kBundledCatalogPackVersion,
      );
      expect(await _foodsWithoutEnergy(db), isEmpty);
      final rotiFacts = await (db.select(
        db.nutritionFoodNutrientFacts,
      )..where((fact) => fact.foodId.equals(lazy.id))).get();
      // Same values and basis: the lazily written version stays current.
      expect(rotiFacts.map((row) => row.factVersion).toSet(), {1});
    },
  );

  group('thali route (audit C-02)', () {
    test('carries the meal and the day being logged', () {
      expect(
        thaliRouteLocation(mealType: 'dinner', date: DateTime(2026, 10, 5)),
        '/food/thali?meal=dinner&date=2026-10-05',
      );
      expect(thaliRouteLocation(), '/food/thali');
    });
  });

  testWidgets('the summary bar blocks logging when calories are unknown '
      '(audit R-04)', (tester) async {
    late RealCatalogue catalogue;
    late NutritionThaliPreview preview;
    await tester.runAsync(() async {
      catalogue = await RealCatalogue.open();
      await catalogue.db
          .into(catalogue.db.nutritionFoods)
          .insert(
            NutritionFoodsCompanion.insert(
              id: 'food-no-facts',
              kind: 'canonical',
              displayName: 'Mystery sabzi',
              locale: 'en-IN',
              sourceType: 'fixture',
              lifecycle: 'active',
            ),
          );
      preview = await catalogue.thali.preview(
        draft: _draft(catalogue, [
          (
            'food-no-facts',
            Quantity.fromNum(amount: 1, unit: QuantityUnit.gram),
          ),
        ]),
      );
    });
    addTearDown(() => tester.runAsync(catalogue.close));

    var withoutCalories = 0;
    Widget bar({NutritionThaliPreview? preview, String? failure}) =>
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ThaliNutritionSummaryBar(
              preview: preview,
              hasItems: true,
              onLogThali: () {},
              onSaveTemplate: () {},
              failureMessage: failure,
              onLogWithoutCalories: () => withoutCalories++,
            ),
          ),
        );
    ElevatedButton logButton() => tester.widget<ElevatedButton>(
      find.byKey(const Key('thali_log_meal_button')),
    );

    await tester.pumpWidget(bar(preview: preview));
    expect(
      find.byKey(const Key('thali_unknown_energy_notice')),
      findsOneWidget,
    );
    expect(find.textContaining('Mystery sabzi'), findsOneWidget);
    expect(logButton().onPressed, isNull);
    await tester.tap(
      find.byKey(const Key('thali_log_without_calories_button')),
    );
    expect(withoutCalories, 1);

    await tester.pumpWidget(bar(failure: 'The amount is not valid.'));
    expect(find.textContaining("Couldn't calculate"), findsOneWidget);
    expect(find.text('Calculating...'), findsNothing);
    expect(logButton().onPressed, isNull);
  });
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
        measureId: items[i].$2.unit == QuantityUnit.householdReference
            ? items[i].$2.context.householdMeasure!.measureType
            : null,
      ),
  ],
);

/// Logging validates against the stored draft, as the app does.
Future<NutritionThaliDraft> _saved(
  RealCatalogue catalogue,
  List<(String, Quantity)> items,
) => catalogue.thali.saveDraft(_draft(catalogue, items));

Quantity _katori(num amount) => Quantity(
  amount: QuantityAmount.fromNum(amount),
  unit: QuantityUnit.householdReference,
  context: const QuantityContext(
    householdMeasure: HouseholdMeasureReference(
      measureType: 'household_measure_katori_v1',
    ),
  ),
);

String? _kcal(NutritionThaliPreview preview) =>
    preview.aggregate.facts['energy']?.point?.value.toString();

Future<NutritionConsumptionSnapshot> _finalize(
  RealCatalogue catalogue,
  NutritionThaliPreview preview, {
  bool allowUnknownEnergy = false,
}) => catalogue.thali.finalize(
  preview: preview,
  mealCategory: 'dinner',
  loggedAt: DateTime.utc(2026, 10, 5, 15),
  commandId: 'command-${preview.draft.id}-$allowUnknownEnergy',
  localDate: '2026-10-05',
  timezoneId: 'Asia/Kolkata',
  allowPartial: true,
  allowUnknownEnergy: allowUnknownEnergy,
);

Future<List<String>> _foodsWithoutEnergy(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT f.id FROM nutrition_foods f WHERE f.lifecycle = 'active' "
        "AND f.id LIKE 'food-seed-%' AND NOT EXISTS ("
        'SELECT 1 FROM nutrition_food_nutrient_facts n '
        "WHERE n.food_id = f.id AND n.nutrient_id = 'energy' "
        'AND n.is_current = 1 AND n.amount IS NOT NULL)',
      )
      .get();
  return rows.map((row) => row.read<String>('id')).toList();
}

Future<int> _factCount(AppDatabase db) async =>
    (await db
            .customSelect(
              'SELECT COUNT(*) AS c FROM nutrition_food_nutrient_facts',
            )
            .getSingle())
        .read<int>('c');

Future<CatalogPack> _bundledPack(RealCatalogue catalogue) async {
  final manifest = CatalogPackManifest.parse(
    jsonDecode(File(kBundledCatalogManifestAsset).readAsStringSync()),
  );
  final entry = manifest.fullPack(kBundledCatalogPackVersion);
  return CatalogPack.decode(
    File('$kBundledCatalogAssetDirectory${entry.url}').readAsBytesSync(),
    expectedSha256: entry.sha256,
    registryVersion: '${catalogue.registry.version}',
    nutrientIds: catalogue.registry.definitions.map((d) => d.id).toSet(),
  );
}

Map<String, Object?> _packJson({
  required int version,
  int? base,
  required String kind,
  required double energy,
  String id = 'food-a',
}) => {
  'format': 1,
  'version': version,
  'base': base,
  'kind': kind,
  'min_app_build': 1,
  'registry_version': '1',
  'sources': [
    {'id': 'test', 'licence': 'proprietary', 'attribution': null},
  ],
  'foods': [
    {
      'id': id,
      'display_name': 'Whole Wheat Roti / Chapati',
      'source_ref': 'asset:base:whole wheat roti / chapati',
      'source_id': 'test',
      'facts': {
        'basis': 'per_serving',
        'values': {'energy': energy},
      },
      'servings': [
        {'id': 'default', 'unit': 'piece', 'amount': 1, 'default': true},
      ],
    },
  ],
  'retire': <Object>[],
};
