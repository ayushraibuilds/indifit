import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/fixtures/food_identity_manifest.dart';
import '../database/app_database.dart';
import 'catalog_pack.dart';

/// The rule version on every conversion row a pack writes. Re-applying a
/// pack replaces these rows; user-owned conversions are never touched.
const String kCatalogPackConversionRule = 'catalog-pack';

/// The `source` of every alias row a pack writes. Re-applying a pack
/// replaces these rows; manifest and user aliases are never touched.
const String kCatalogPackAliasSource = 'catalog-pack';

/// The 11 leading fact columns, read from each JSON row array in order.
final String _factColumns = List.generate(
  11,
  (index) => "json_extract(value, '\$[$index]')",
).join(', ');

/// What [CatalogPackImporter.apply] did.
class CatalogPackApplyResult {
  final int version;
  final bool applied;
  final int foodsWithNewFacts;

  const CatalogPackApplyResult({
    required this.version,
    required this.applied,
    required this.foodsWithNewFacts,
  });
}

/// Writes a validated [CatalogPack] into the canonical nutrition tables
/// (CAT-2).
///
/// Everything happens in one transaction: identities, facts, household
/// conversions, retirements and the [CatalogState] row. A failure leaves
/// the previously installed catalogue exactly as it was. Applying the same
/// or an older version is a no-op, so clients never move backwards.
class CatalogPackImporter {
  final AppDatabase _db;
  final List<String> _nutrientIds;
  final DateTime Function() _nowUtc;

  CatalogPackImporter({
    required AppDatabase db,
    required Iterable<String> nutrientIds,
    DateTime Function()? nowUtc,
  }) : _db = db,
       _nutrientIds = List.unmodifiable(nutrientIds),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  Future<int?> installedVersion() async {
    final latest = _db.catalogState.version.max();
    final row = await (_db.selectOnly(
      _db.catalogState,
    )..addColumns([latest])).getSingleOrNull();
    return row?.read(latest);
  }

  Future<CatalogPackApplyResult> apply(
    CatalogPack pack, {
    required String source,
  }) async {
    if (source != 'bundled' && source != 'download') {
      throw ArgumentError.value(source, 'source');
    }
    final result = await _db.transaction(() async {
      final installed = await installedVersion();
      if (installed != null && pack.version <= installed) {
        return CatalogPackApplyResult(
          version: installed,
          applied: false,
          foodsWithNewFacts: 0,
        );
      }
      if (pack.isDelta && pack.base != installed) {
        throw CatalogPackError(
          'base_mismatch',
          'Delta ${pack.version} needs base ${pack.base}, '
              'but $installed is installed.',
        );
      }
      final now = _nowUtc();
      final sources = {for (final source in pack.sources) source.id: source};
      await _writeIdentities(pack, now);
      final changed = await _writeFacts(pack, sources, now);
      await _writeConversions(pack, now);
      await _writeAliases(pack, now);
      if (pack.retire.isNotEmpty) {
        await (_db.update(_db.nutritionFoods)..where(
              (food) => food.id.isIn(pack.retire.map((retired) => retired.id)),
            ))
            .write(
              NutritionFoodsCompanion(
                lifecycle: const Value('deprecated'),
                updatedAt: Value(now),
              ),
            );
      }
      await _db
          .into(_db.catalogState)
          .insert(
            CatalogStateCompanion.insert(
              version: Value(pack.version),
              sha256: pack.sha256,
              source: source,
              foodCount: pack.foods.length,
              appliedAt: Value(now),
            ),
          );
      return CatalogPackApplyResult(
        version: pack.version,
        applied: true,
        foodsWithNewFacts: changed,
      );
    });
    if (result.applied) {
      // Cached online results embed catalogue rows; drop them so search
      // never shows values from the previous pack. The manifest marker row
      // stays (see _checkAndInvalidateFoodSearchCacheOnManifestChange).
      await _db.customStatement(
        "DELETE FROM food_search_cache WHERE query_hash != '__manifest_version__'",
      );
    }
    return result;
  }

  Future<void> _writeIdentities(CatalogPack pack, DateTime now) async {
    final existing = {
      for (final row in await (_db.select(
        _db.nutritionFoods,
      )..where((food) => food.id.isIn(pack.foods.map((f) => f.id)))).get())
        row.id: row,
    };
    final inserts = <NutritionFoodsCompanion>[];
    for (final food in pack.foods) {
      final row = existing[food.id];
      if (row == null) {
        inserts.add(
          NutritionFoodsCompanion.insert(
            id: food.id,
            kind: 'canonical',
            displayName: food.displayName,
            locale: 'en-IN',
            sourceType: 'bundled_asset',
            sourceRef: Value(food.sourceRef),
            sourceVersion: Value('catalog-pack-v${pack.version}'),
            lifecycle: 'active',
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      } else if (row.displayName != food.displayName) {
        // Ids never change, so a display name can be corrected freely.
        await (_db.update(
          _db.nutritionFoods,
        )..where((table) => table.id.equals(food.id))).write(
          NutritionFoodsCompanion(
            displayName: Value(food.displayName),
            updatedAt: Value(now),
          ),
        );
      }
    }
    if (inserts.isNotEmpty) {
      await _db.batch((batch) => batch.insertAll(_db.nutritionFoods, inserts));
    }
    // Variant links come from the pack, not the identity manifest, whose
    // kinds and parents miss some variants. Linked after the inserts so a
    // variant may precede its base. `kind` stays as is: search ranks by it.
    final links = [
      for (final food in pack.foods)
        if (food.declaresVariantOf &&
            existing[food.id]?.variantOfFoodId != food.variantOf)
          [food.id, food.variantOf],
    ];
    if (links.isNotEmpty) {
      await _db.customStatement(
        'UPDATE nutrition_foods SET updated_at = ?1, variant_of_food_id = '
        "(SELECT json_extract(value, '\$[1]') FROM json_each(?2) "
        "WHERE json_extract(value, '\$[0]') = nutrition_foods.id) "
        "WHERE id IN (SELECT json_extract(value, '\$[0]') FROM json_each(?2))",
        [now.millisecondsSinceEpoch ~/ 1000, jsonEncode(links)],
      );
    }
  }

  /// Writes a new fact version for each food whose current facts differ from
  /// the pack. Snapshots already logged keep their own copied values.
  Future<int> _writeFacts(
    CatalogPack pack,
    Map<String, CatalogPackSource> sources,
    DateTime now,
  ) async {
    final ids = pack.foods.map((food) => food.id).toList(growable: false);
    final rows = await (_db.select(
      _db.nutritionFoodNutrientFacts,
    )..where((fact) => fact.foodId.isIn(ids))).get();
    final current = <String, Map<String, NutritionFoodNutrientFact>>{};
    final latestVersion = <String, int>{};
    for (final row in rows) {
      final latest = latestVersion[row.foodId] ?? 0;
      if (row.factVersion > latest) latestVersion[row.foodId] = row.factVersion;
      if (row.isCurrent && row.preparationId == null) {
        (current[row.foodId] ??= {})[row.nutrientId] = row;
      }
    }

    final inserts = <List<Object?>>[];
    final superseded = <String>[];
    for (final food in pack.foods) {
      final existing = current[food.id] ?? const {};
      if (_sameFacts(food, existing)) continue;
      if (existing.isNotEmpty) superseded.add(food.id);
      final version = (latestVersion[food.id] ?? 0) + 1;
      final source = sources[food.sourceId]!;
      final perMass = food.basis == CatalogPackBasis.per100Grams;
      final perVolume = food.basis == CatalogPackBasis.per100Millilitres;
      for (final nutrientId in _nutrientIds) {
        final value = food.values[nutrientId];
        inserts.add([
          '${food.id}::$nutrientId::v$version',
          food.id,
          nutrientId,
          value,
          value == null
              ? 'missing'
              : value == 0
              ? 'known_zero'
              : 'known',
          source.reviewed ? 'reviewed_catalogue' : 'legacy',
          'catalog-pack:v${pack.version}:${source.id}',
          version,
          food.basis.stableId,
          perMass || perVolume ? 100 : null,
          perMass
              ? 'gram'
              : perVolume
              ? 'millilitre'
              : null,
        ]);
      }
    }
    if (superseded.isNotEmpty) {
      await (_db.update(_db.nutritionFoodNutrientFacts)..where(
            (fact) =>
                fact.foodId.isIn(superseded) &
                fact.preparationId.isNull() &
                fact.isCurrent.equals(true),
          ))
          .write(
            NutritionFoodNutrientFactsCompanion(
              isCurrent: const Value(false),
              updatedAt: Value(now),
            ),
          );
    }
    if (inserts.isNotEmpty) {
      // One statement for ~10k rows: a row-by-row batch took ~300 ms on
      // every fresh database, which every test and first launch pays.
      await _db.customStatement(
        'INSERT INTO nutrition_food_nutrient_facts (id, food_id, nutrient_id, '
        'amount, status, source, source_ref, fact_version, basis, '
        'basis_quantity, basis_unit, is_current, created_at, updated_at) '
        'SELECT $_factColumns, 1, ?1, ?1 '
        'FROM json_each(?2)',
        [now.millisecondsSinceEpoch ~/ 1000, jsonEncode(inserts)],
      );
    }
    return inserts.length ~/ _nutrientIds.length;
  }

  bool _sameFacts(
    CatalogPackFood food,
    Map<String, NutritionFoodNutrientFact> existing,
  ) {
    if (existing.length != _nutrientIds.length) return false;
    for (final nutrientId in _nutrientIds) {
      final row = existing[nutrientId];
      if (row == null || row.basis != food.basis.stableId) return false;
      final value = food.values[nutrientId];
      if (value == null) {
        if (row.amount != null || row.status != 'missing') return false;
      } else if (row.amount == null || (row.amount! - value).abs() > 1e-9) {
        return false;
      }
    }
    return true;
  }

  Future<void> _writeAliases(CatalogPack pack, DateTime now) async {
    final ids = pack.foods.map((food) => food.id).toList(growable: false);
    await (_db.delete(_db.nutritionFoodAliases)..where(
          (row) =>
              row.foodId.isIn(ids) & row.source.equals(kCatalogPackAliasSource),
        ))
        .go();
    final inserts = [
      for (final food in pack.foods)
        for (final alias in food.aliases)
          NutritionFoodAliasesCompanion.insert(
            id:
                'catalog-pack:${food.id}:'
                '${FoodIdentityNormalizer.normalize(alias.text)}',
            foodId: Value(food.id),
            alias: alias.text,
            normalizedAlias: FoodIdentityNormalizer.normalize(alias.text),
            locale: alias.locale,
            source: kCatalogPackAliasSource,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
    ];
    if (inserts.isNotEmpty) {
      // An alias another source already owns (same text and locale) stays
      // with that source: one alias names exactly one food.
      await _db.batch(
        (batch) => batch.insertAll(
          _db.nutritionFoodAliases,
          inserts,
          mode: InsertMode.insertOrIgnore,
        ),
      );
    }
  }

  Future<void> _writeConversions(CatalogPack pack, DateTime now) async {
    final ids = pack.foods.map((food) => food.id).toList(growable: false);
    await (_db.delete(_db.nutritionQuantityConversions)..where(
          (row) =>
              row.foodId.isIn(ids) &
              row.ownerScope.equals('catalogue') &
              row.ruleVersion.equals(kCatalogPackConversionRule),
        ))
        .go();
    final inserts = <NutritionQuantityConversionsCompanion>[];
    void add(String foodId, String from, String to, double factor) {
      inserts.add(
        NutritionQuantityConversionsCompanion.insert(
          id: 'catalog-pack:$foodId:$from:$to',
          foodId: foodId,
          sourceUnit: from,
          targetUnit: to,
          factor: factor,
          method: 'catalogue_serving',
          source: 'catalog_pack_v${pack.version}',
          ruleVersion: kCatalogPackConversionRule,
          ownerScope: 'catalogue',
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }

    for (final food in pack.foods) {
      final serving = food.defaultServing;
      // Every row reads "1 serving = factor <target>", so amounts stay exact:
      // "Boiled Eggs (2 pieces)" is serving → piece, factor 2.
      if (serving.unit != 'g' && serving.unit != 'ml') {
        add(food.id, 'serving', serving.unit, serving.amount);
      }
      final grams = serving.grams;
      if (grams != null) add(food.id, 'serving', 'gram', grams);
      if (food.basis == CatalogPackBasis.per100Millilitres) {
        add(food.id, 'serving', 'millilitre', serving.amount);
      }
    }
    if (inserts.isNotEmpty) {
      await _db.batch(
        (batch) => batch.insertAll(_db.nutritionQuantityConversions, inserts),
      );
    }
  }
}
