import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrients.dart';
import '../../core/typed_quantities.dart';
import '../database/app_database.dart';

/// A production-facing, typed food option used by the B03 feature flows.
///
/// The legacy food tables remain available for compatibility, but new food
/// entry and recipe authoring go through this boundary.  The option carries
/// the quantity context that its nutrient facts expect, so callers never need
/// to guess whether a value is per-serving, per-100-gram, or per-100-mL.
class NutritionFoodOption {
  final String id;
  final String displayName;
  final Quantity baseQuantity;
  final Map<String, NutrientFact> facts;
  final String sourceType;
  final String? sourceReference;
  final String? preparationId;
  final String? servingUnitLabel;

  const NutritionFoodOption({
    required this.id,
    required this.displayName,
    required this.baseQuantity,
    required this.facts,
    required this.sourceType,
    required this.sourceReference,
    required this.preparationId,
    this.servingUnitLabel,
  });

  bool get hasNumericFacts => facts.values.any((fact) => fact.hasNumericValue);
}

/// Owns the small amount of source adaptation required before a food can
/// enter the immutable B03 snapshot graph.
///
/// This repository does not calculate totals or write consumption history.
/// It creates/reads portable food identities and stores versioned source facts;
/// [NutritionFoodLoggingCoordinator] performs calculation and finalization.
class NutritionFoodCatalogRepository {
  final AppDatabase _db;
  final NutrientRegistry _registry;
  final DateTime Function() _nowUtc;

  NutritionFoodCatalogRepository({
    required AppDatabase db,
    required NutrientRegistry registry,
    DateTime Function()? nowUtc,
  }) : _db = db,
       _registry = registry,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  /// Adapts a legacy/local food row to a portable B03 identity and typed
  /// per-serving facts.  Existing reviewed mappings are always preferred.
  Future<NutritionFoodOption> ensureLegacyFood(FoodItem item) async {
    final identity = await _legacyIdentity(item);
    final serving = _servingFor(identity, source: 'legacy');
    final authority = _legacyQuantityAuthority(item, serving);
    final facts = <String, NutrientFact>{
      for (final definition in _registry.definitions)
        definition.id: _legacyFact(
          nutrientId: definition.id,
          value: authority.scale(switch (definition.id) {
            'energy' => item.calories.toDouble(),
            'protein' => item.proteinG,
            'carbohydrate' => item.carbsG,
            'fat' => item.fatG,
            'fibre' => item.fiberG,
            _ => null,
          }),
          sourceReference: 'legacy-food-item:${item.id}',
          basis: authority.basis,
        ),
    };
    await _ensureFacts(
      foodId: identity,
      facts: facts,
      sourceReference: 'legacy-food-item:${item.id}',
    );
    final currentFacts = await _readCurrentFacts(identity, fallback: facts);
    return NutritionFoodOption(
      id: identity,
      displayName: item.name,
      baseQuantity: _baseQuantityFor(identity, currentFacts),
      facts: currentFacts,
      sourceType: item.isCustom ? 'user' : 'legacy',
      sourceReference: 'legacy-food-item:${item.id}',
      preparationId: null,
      servingUnitLabel: authority.servingUnitLabel,
    );
  }

  /// Adapts a provider/barcode result without filling absent nutrients with
  /// zero.  The provider identity is deterministic, so retries do not create
  /// duplicate foods or duplicate current fact rows.
  Future<NutritionFoodOption> ensureProviderFood({
    required String displayName,
    required String sourceReference,
    required double servingSize,
    required String servingUnit,
    required double? energyKcal,
    required double? proteinG,
    required double? carbohydrateG,
    required double? fatG,
  }) async {
    if (!servingSize.isFinite || servingSize <= 0) {
      throw const NutritionFoodCatalogError(
        'invalid_serving',
        'A provider food must include a positive serving size.',
      );
    }
    final normalizedReference = sourceReference.trim();
    if (normalizedReference.isEmpty) {
      throw const NutritionFoodCatalogError(
        'missing_provider_reference',
        'A provider food must include a stable source reference.',
      );
    }
    final id = _providerId(normalizedReference);
    // FoodApiService deliberately reads Open Food Facts' *_100g fields. Keep
    // that authoritative mass basis instead of converting the values into an
    // abstract provider serving and losing g/kg entry on the consumer UI.
    final providerBasis = NutrientBasis(NutrientBasisKind.per100Grams);
    final facts = <String, NutrientFact>{
      for (final definition in _registry.definitions)
        definition.id: _providerFact(
          nutrientId: definition.id,
          value: switch (definition.id) {
            'energy' => energyKcal,
            'protein' => proteinG,
            'carbohydrate' => carbohydrateG,
            'fat' => fatG,
            _ => null,
          },
          sourceReference: normalizedReference,
          basis: providerBasis,
        ),
    };
    await _ensureIdentity(
      id: id,
      displayName: displayName,
      kind: 'branded',
      sourceType: 'provider',
      sourceReference: normalizedReference,
      sourceVersion: 'open-food-facts-v2',
    );
    await _ensureFacts(
      foodId: id,
      facts: facts,
      sourceReference: normalizedReference,
    );
    final currentFacts = await _readCurrentFacts(id, fallback: facts);
    return NutritionFoodOption(
      id: id,
      displayName: displayName,
      baseQuantity: _baseQuantityFor(id, currentFacts),
      facts: currentFacts,
      sourceType: 'imported_provider',
      sourceReference: normalizedReference,
      preparationId: null,
      servingUnitLabel: null,
    );
  }

  /// Creates a user-owned food with per-serving facts.
  ///
  /// Optional nutrient inputs remain missing in the canonical fact graph;
  /// they are never converted to zero just to satisfy the legacy table shape.
  Future<NutritionFoodOption> createUserFood({
    required String displayName,
    required double servingSize,
    required String servingUnit,
    required double? energyKcal,
    required double? proteinG,
    required double? carbohydrateG,
    required double? fatG,
    double? fibreG,
  }) async {
    final name = displayName.trim();
    final unit = servingUnit.trim();
    if (name.isEmpty) {
      throw const NutritionFoodCatalogError(
        'missing_food_name',
        'A custom food needs a name.',
      );
    }
    if (!servingSize.isFinite || servingSize <= 0 || unit.isEmpty) {
      throw const NutritionFoodCatalogError(
        'invalid_serving',
        'A custom food needs a positive serving size and unit.',
      );
    }
    final id = 'user-food::${const Uuid().v4()}';
    final sourceReference =
        'user-custom-food::$id|serving=${_numberLabel(servingSize)} $unit';
    final servingDefinition = ServingDefinitionReference(
      id: 'food-serving::$id',
      revision: 'b03-food-entry-v1',
      source: 'catalogue',
    );
    final basis = NutrientBasis(
      NutrientBasisKind.perServing,
      servingDefinition: servingDefinition,
    );
    final values = <String, double?>{
      'energy': energyKcal,
      'protein': proteinG,
      'carbohydrate': carbohydrateG,
      'fat': fatG,
      'fibre': fibreG,
    };
    final facts = <String, NutrientFact>{};
    for (final definition in _registry.definitions) {
      final value = values[definition.id];
      if (value == null) {
        facts[definition.id] = NutrientFact.missing(
          nutrientId: definition.id,
          unit: definition.unit,
          basis: basis,
          source: NutrientSourceType.userEntered,
          sourceReference: sourceReference,
          factVersion: 'custom-food-v1',
        );
      } else if (value == 0) {
        facts[definition.id] = NutrientFact.knownZero(
          nutrientId: definition.id,
          unit: definition.unit,
          basis: basis,
          source: NutrientSourceType.userEntered,
          sourceReference: sourceReference,
          factVersion: 'custom-food-v1',
        );
      } else {
        facts[definition.id] = NutrientFact.known(
          nutrientId: definition.id,
          point: NutrientAmount(
            value: QuantityAmount.fromNum(value),
            unit: definition.unit,
          ),
          basis: basis,
          source: NutrientSourceType.userEntered,
          sourceReference: sourceReference,
          factVersion: 'custom-food-v1',
        );
      }
    }
    await _ensureIdentity(
      id: id,
      displayName: name,
      kind: 'userCreated',
      sourceType: 'user',
      sourceReference: sourceReference,
      sourceVersion: 'custom-food-v1',
    );
    await _ensureFacts(
      foodId: id,
      facts: facts,
      sourceReference: sourceReference,
    );
    final currentFacts = await _readCurrentFacts(id, fallback: facts);
    return NutritionFoodOption(
      id: id,
      displayName: name,
      baseQuantity: Quantity.serving(
        amount: '1',
        definition: servingDefinition,
        source: 'user',
      ),
      facts: currentFacts,
      sourceType: 'user',
      sourceReference: sourceReference,
      preparationId: null,
      servingUnitLabel: '${_numberLabel(servingSize)} $unit',
    );
  }

  Future<NutritionFoodOption?> getOption(String foodId) async {
    final row = await (_db.select(
      _db.nutritionFoods,
    )..where((table) => table.id.equals(foodId.trim()))).getSingleOrNull();
    if (row == null || row.lifecycle != 'active') return null;
    final facts = await _readCurrentFacts(row.id);
    return NutritionFoodOption(
      id: row.id,
      displayName: row.displayName,
      baseQuantity: _baseQuantityFor(row.id, facts),
      facts: facts,
      sourceType: row.sourceType,
      sourceReference: row.sourceRef,
      preparationId: null,
      servingUnitLabel: await _servingUnitLabelFor(row.sourceRef),
    );
  }

  Future<List<NutritionFoodOption>> search({String query = ''}) async {
    final normalized = query.trim().toLowerCase();
    final rows =
        await (_db.select(_db.nutritionFoods)
              ..where(
                (table) =>
                    table.lifecycle.equals('active') &
                    (normalized.isEmpty
                        ? const Constant(true)
                        : table.displayName.lower().contains(normalized)),
              )
              ..orderBy([
                (table) => OrderingTerm(expression: table.displayName),
              ]))
            .get();
    final resultById = <String, NutritionFoodOption>{};
    for (final row in rows) {
      final option = await getOption(row.id);
      if (option != null) resultById[option.id] = option;
    }

    // The installed catalogue is not the only offline source.  Legacy/local
    // foods (including user-created foods) are adapted lazily through the
    // same canonical identity boundary so recipe authoring works immediately
    // after an upgrade and does not require a prior meal log.
    final legacyRows =
        await (_db.select(_db.foodItems)
              ..where(
                (table) => normalized.isEmpty
                    ? const Constant(true)
                    : table.name.lower().contains(normalized),
              )
              ..orderBy([(table) => OrderingTerm(expression: table.name)])
              ..limit(200))
            .get();
    for (final item in legacyRows) {
      final option = await ensureLegacyFood(item);
      resultById.putIfAbsent(option.id, () => option);
    }
    final result = resultById.values.toList()
      ..sort(
        (left, right) => left.displayName.toLowerCase().compareTo(
          right.displayName.toLowerCase(),
        ),
      );
    return List.unmodifiable(result);
  }

  Future<String> _legacyIdentity(FoodItem item) async {
    final mapping = await (_db.select(
      _db.nutritionLegacyFoodMappings,
    )..where((row) => row.legacyFoodItemId.equals(item.id))).getSingleOrNull();
    if (mapping?.mappingStatus == 'reviewed' && mapping?.foodId != null) {
      final canonical = await (_db.select(
        _db.nutritionFoods,
      )..where((row) => row.id.equals(mapping!.foodId!))).getSingleOrNull();
      if (canonical != null && canonical.lifecycle == 'active') {
        return canonical.id;
      }
    }
    final id = 'legacy-food-item::${item.id}';
    await _ensureIdentity(
      id: id,
      displayName: item.name,
      kind: item.isCustom ? 'userCreated' : 'legacy',
      sourceType: item.isCustom ? 'user' : 'legacy',
      sourceReference: 'food-items:${item.id}',
      sourceVersion: 'legacy-v1',
    );
    return id;
  }

  Future<void> _ensureIdentity({
    required String id,
    required String displayName,
    required String kind,
    required String sourceType,
    required String sourceReference,
    required String sourceVersion,
  }) async {
    final existing = await (_db.select(
      _db.nutritionFoods,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (existing != null) return;
    await _db
        .into(_db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: id,
            kind: kind,
            displayName: displayName.trim().isEmpty ? 'Food' : displayName,
            locale: 'en-IN',
            sourceType: sourceType,
            sourceRef: Value(sourceReference),
            sourceVersion: Value(sourceVersion),
            lifecycle: 'active',
            createdAt: Value(_nowUtc()),
            updatedAt: Value(_nowUtc()),
          ),
        );
  }

  Future<void> _ensureFacts({
    required String foodId,
    required Map<String, NutrientFact> facts,
    required String sourceReference,
  }) async {
    await _db.transaction(() async {
      final current =
          await (_db.select(_db.nutritionFoodNutrientFacts)..where(
                (row) => row.foodId.equals(foodId) & row.isCurrent.equals(true),
              ))
              .get();
      final basisMatches =
          current.isNotEmpty &&
          current.every(
            (row) => facts[row.nutrientId]?.basis.kind.stableId == row.basis,
          );
      if (basisMatches) return;

      final historical = await (_db.select(
        _db.nutritionFoodNutrientFacts,
      )..where((row) => row.foodId.equals(foodId))).get();
      final version =
          historical.fold<int>(0, (max, row) {
            return row.factVersion > max ? row.factVersion : max;
          }) +
          1;
      final now = _nowUtc();
      if (current.isNotEmpty) {
        await (_db.update(_db.nutritionFoodNutrientFacts)..where(
              (row) => row.foodId.equals(foodId) & row.isCurrent.equals(true),
            ))
            .write(
              NutritionFoodNutrientFactsCompanion(
                isCurrent: const Value(false),
                updatedAt: Value(now),
              ),
            );
      }
      await _db.batch((batch) {
        batch.insertAll(_db.nutritionFoodNutrientFacts, [
          for (final fact in facts.values)
            NutritionFoodNutrientFactsCompanion.insert(
              id: '$foodId::${fact.nutrientId}::v$version',
              foodId: foodId,
              nutrientId: fact.nutrientId,
              amount: Value(fact.point?.value.asDouble),
              lower: Value(fact.lower?.value.asDouble),
              upper: Value(fact.upper?.value.asDouble),
              status: fact.status.stableId,
              source: fact.source.stableId,
              sourceRef: Value(fact.sourceReference ?? sourceReference),
              confidence: Value(_confidenceValue(fact.confidence)),
              factVersion: version,
              basisQuantity:
                  fact.basis.kind == NutrientBasisKind.per100Grams ||
                      fact.basis.kind == NutrientBasisKind.per100Millilitres
                  ? const Value(100)
                  : const Value.absent(),
              basis: fact.basis.kind.stableId,
              basisUnit: fact.basis.kind == NutrientBasisKind.per100Grams
                  ? const Value('gram')
                  : fact.basis.kind == NutrientBasisKind.per100Millilitres
                  ? const Value('millilitre')
                  : const Value.absent(),
              isCurrent: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
        ]);
      });
    });
  }

  Future<Map<String, NutrientFact>> _readCurrentFacts(
    String foodId, {
    Map<String, NutrientFact>? fallback,
  }) async {
    final rows =
        await (_db.select(_db.nutritionFoodNutrientFacts)
              ..where(
                (row) => row.foodId.equals(foodId) & row.isCurrent.equals(true),
              )
              ..orderBy([(row) => OrderingTerm(expression: row.factVersion)]))
            .get();
    if (rows.isEmpty) return fallback ?? _allMissingFacts(foodId);
    final serving = _servingFor(foodId, source: 'catalogue');
    final result = <String, NutrientFact>{};
    for (final row in rows) {
      if (result.containsKey(row.nutrientId)) continue;
      final definition = _registry.definitionFor(row.nutrientId);
      final basis = NutrientBasis(
        NutrientBasisContract.fromStableId(row.basis),
        servingDefinition: row.basis == 'per_serving'
            ? serving.context.servingDefinition
            : null,
      );
      NutrientAmount? amount(double? value) => value == null
          ? null
          : NutrientAmount(
              value: QuantityAmount.fromNum(value),
              unit: definition.unit,
            );
      result[row.nutrientId] = NutrientFact(
        nutrientId: row.nutrientId,
        unit: definition.unit,
        status: NutrientFactStatusContract.fromStableId(row.status),
        point: amount(row.amount),
        lower: amount(row.lower),
        upper: amount(row.upper),
        basis: basis,
        source: NutrientSourceContract.fromStableId(row.source),
        sourceReference: row.sourceRef,
        confidence: row.confidence == null
            ? NutrientConfidence.notProvided
            : _confidenceFromValue(row.confidence!),
        factVersion: row.factVersion.toString(),
      );
    }
    return Map.unmodifiable(result);
  }

  Map<String, NutrientFact> _allMissingFacts(String foodId) {
    return {
      for (final definition in _registry.definitions)
        definition.id: NutrientFact.missing(
          nutrientId: definition.id,
          unit: definition.unit,
          basis: NutrientBasis(NutrientBasisKind.absolute),
          source: NutrientSourceType.unknown,
          sourceReference: 'missing-food-facts:$foodId',
          factVersion: 'unavailable',
        ),
    };
  }

  Quantity _baseQuantityFor(String foodId, Map<String, NutrientFact> facts) {
    final basis = facts.values
        .firstWhere(
          (fact) => fact.basis.kind != NutrientBasisKind.absolute,
          orElse: () => facts.values.first,
        )
        .basis
        .kind;
    return switch (basis) {
      NutrientBasisKind.per100Grams => Quantity.fromDecimal(
        amount: '100',
        unit: QuantityUnit.gram,
      ),
      NutrientBasisKind.per100Millilitres => Quantity.fromDecimal(
        amount: '100',
        unit: QuantityUnit.millilitre,
      ),
      NutrientBasisKind.perServing => _servingFor(foodId, source: 'catalogue'),
      NutrientBasisKind.absolute => Quantity.fromDecimal(
        amount: '1',
        unit: QuantityUnit.gram,
      ),
    };
  }

  Quantity _servingFor(String foodId, {required String source}) =>
      Quantity.serving(
        amount: '1',
        definition: ServingDefinitionReference(
          id: 'food-serving::$foodId',
          revision: 'b03-food-entry-v1',
          source: source,
        ),
        source: source,
      );

  NutrientFact _legacyFact({
    required String nutrientId,
    required double? value,
    required String sourceReference,
    required NutrientBasis basis,
  }) => _factFromValue(
    nutrientId: nutrientId,
    value: value,
    source: NutrientSourceType.legacy,
    sourceReference: sourceReference,
    basis: basis,
    factVersion: 'legacy-v1',
  );

  NutrientFact _providerFact({
    required String nutrientId,
    required double? value,
    required String sourceReference,
    required NutrientBasis basis,
  }) => _factFromValue(
    nutrientId: nutrientId,
    value: value,
    source: NutrientSourceType.importedProvider,
    sourceReference: sourceReference,
    basis: basis,
    factVersion: 'open-food-facts-v2',
  );

  NutrientFact _factFromValue({
    required String nutrientId,
    required double? value,
    required NutrientSourceType source,
    required String sourceReference,
    required NutrientBasis basis,
    required String factVersion,
  }) {
    final definition = _registry.definitionFor(nutrientId);
    if (value == null) {
      return NutrientFact.missing(
        nutrientId: nutrientId,
        unit: definition.unit,
        basis: basis,
        source: source,
        sourceReference: sourceReference,
        factVersion: factVersion,
      );
    }
    final amount = NutrientAmount(
      value: QuantityAmount.fromNum(value),
      unit: definition.unit,
    );
    if (value == 0) {
      return NutrientFact.knownZero(
        nutrientId: nutrientId,
        unit: definition.unit,
        basis: basis,
        source: source,
        sourceReference: sourceReference,
        factVersion: factVersion,
      );
    }
    return NutrientFact.known(
      nutrientId: nutrientId,
      point: amount,
      basis: basis,
      source: source,
      sourceReference: sourceReference,
      factVersion: factVersion,
    );
  }

  String _providerId(String sourceReference) {
    final digest = sha256.convert(utf8.encode(sourceReference)).toString();
    return 'provider-food::${digest.substring(0, 32)}';
  }

  _LegacyQuantityAuthority _legacyQuantityAuthority(
    FoodItem item,
    Quantity serving,
  ) {
    final unit = item.servingUnit.trim().toLowerCase();
    final size = item.servingSize;
    if (size > 0 && size.isFinite) {
      if (const {'g', 'gram', 'grams'}.contains(unit)) {
        return _LegacyQuantityAuthority(
          basis: NutrientBasis(NutrientBasisKind.per100Grams),
          factScale: 100 / size,
        );
      }
      if (const {'kg', 'kilogram', 'kilograms'}.contains(unit)) {
        return _LegacyQuantityAuthority(
          basis: NutrientBasis(NutrientBasisKind.per100Grams),
          factScale: 100 / (size * 1000),
        );
      }
      if (const {
        'ml',
        'millilitre',
        'millilitres',
        'milliliter',
        'milliliters',
      }.contains(unit)) {
        return _LegacyQuantityAuthority(
          basis: NutrientBasis(NutrientBasisKind.per100Millilitres),
          factScale: 100 / size,
        );
      }
      if (const {'l', 'litre', 'litres', 'liter', 'liters'}.contains(unit)) {
        return _LegacyQuantityAuthority(
          basis: NutrientBasis(NutrientBasisKind.per100Millilitres),
          factScale: 100 / (size * 1000),
        );
      }
    }
    final label = size == 1 && unit.isNotEmpty && unit != 'serving'
        ? item.servingUnit.trim()
        : null;
    return _LegacyQuantityAuthority(
      basis: NutrientBasis(
        NutrientBasisKind.perServing,
        servingDefinition: serving.context.servingDefinition!,
      ),
      factScale: 1,
      servingUnitLabel: label,
    );
  }

  Future<String?> _servingUnitLabelFor(String? sourceReference) async {
    if (sourceReference?.startsWith('user-custom-food::') == true) {
      const marker = '|serving=';
      final index = sourceReference!.indexOf(marker);
      if (index >= 0) return sourceReference.substring(index + marker.length);
    }
    const prefix = 'food-items:';
    if (sourceReference == null || !sourceReference.startsWith(prefix)) {
      return null;
    }
    final id = int.tryParse(sourceReference.substring(prefix.length));
    if (id == null) return null;
    final item = await (_db.select(
      _db.foodItems,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (item == null || item.servingSize != 1) return null;
    final label = item.servingUnit.trim();
    return label.isEmpty || label.toLowerCase() == 'serving' ? null : label;
  }

  String _numberLabel(num value) => value.toDouble() == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  double? _confidenceValue(NutrientConfidence confidence) =>
      switch (confidence) {
        NutrientConfidence.reviewed => 1,
        NutrientConfidence.high => 0.9,
        NutrientConfidence.medium => 0.7,
        NutrientConfidence.low => 0.4,
        NutrientConfidence.unknown || NutrientConfidence.notProvided => null,
      };

  NutrientConfidence _confidenceFromValue(double value) => value >= 0.9
      ? NutrientConfidence.high
      : value >= 0.7
      ? NutrientConfidence.medium
      : NutrientConfidence.low;
}

class _LegacyQuantityAuthority {
  const _LegacyQuantityAuthority({
    required this.basis,
    required this.factScale,
    this.servingUnitLabel,
  });

  final NutrientBasis basis;
  final double factScale;
  final String? servingUnitLabel;

  double? scale(double? value) {
    if (value == null) return null;
    // Legacy source values are doubles. Bound their normalization precision
    // before they enter the exact decimal quantity contract so binary
    // floating-point tails cannot become false precision overflows.
    return double.parse((value * factScale).toStringAsFixed(6));
  }
}

class NutritionFoodCatalogError implements Exception {
  final String code;
  final String message;

  const NutritionFoodCatalogError(this.code, this.message);

  @override
  String toString() => 'NutritionFoodCatalogError($code): $message';
}
