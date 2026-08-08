import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

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

  const NutritionFoodOption({
    required this.id,
    required this.displayName,
    required this.baseQuantity,
    required this.facts,
    required this.sourceType,
    required this.sourceReference,
    required this.preparationId,
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
    final facts = <String, NutrientFact>{
      for (final definition in _registry.definitions)
        definition.id: _legacyFact(
          nutrientId: definition.id,
          value: switch (definition.id) {
            'energy' => item.calories.toDouble(),
            'protein' => item.proteinG,
            'carbohydrate' => item.carbsG,
            'fat' => item.fatG,
            'fibre' => item.fiberG,
            _ => null,
          },
          sourceReference: 'legacy-food-item:${item.id}',
          serving: serving.context.servingDefinition!,
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
    final serving = _servingFor(id, source: 'imported_provider');
    final servingFactor = _providerServingFactor(
      servingSize: servingSize,
      servingUnit: servingUnit,
    );
    final facts = <String, NutrientFact>{
      for (final definition in _registry.definitions)
        definition.id: _providerFact(
          nutrientId: definition.id,
          value: _scaleProviderValue(switch (definition.id) {
            'energy' => energyKcal,
            'protein' => proteinG,
            'carbohydrate' => carbohydrateG,
            'fat' => fatG,
            _ => null,
          }, servingFactor),
          sourceReference: normalizedReference,
          serving: serving.context.servingDefinition!,
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
    final current =
        await (_db.select(_db.nutritionFoodNutrientFacts)..where(
              (row) => row.foodId.equals(foodId) & row.isCurrent.equals(true),
            ))
            .get();
    if (current.isNotEmpty) return;
    final historical = await (_db.select(
      _db.nutritionFoodNutrientFacts,
    )..where((row) => row.foodId.equals(foodId))).get();
    final version =
        historical.fold<int>(0, (max, row) {
          return row.factVersion > max ? row.factVersion : max;
        }) +
        1;
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
            basis: fact.basis.kind.stableId,
            basisQuantity:
                fact.basis.kind == NutrientBasisKind.per100Grams ||
                    fact.basis.kind == NutrientBasisKind.per100Millilitres
                ? const Value(100)
                : const Value.absent(),
            basisUnit: fact.basis.kind == NutrientBasisKind.per100Grams
                ? const Value('gram')
                : fact.basis.kind == NutrientBasisKind.per100Millilitres
                ? const Value('millilitre')
                : const Value.absent(),
            isCurrent: const Value(true),
            createdAt: Value(_nowUtc()),
            updatedAt: Value(_nowUtc()),
          ),
      ]);
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
    required ServingDefinitionReference serving,
  }) => _factFromValue(
    nutrientId: nutrientId,
    value: value,
    source: NutrientSourceType.legacy,
    sourceReference: sourceReference,
    serving: serving,
    factVersion: 'legacy-v1',
  );

  NutrientFact _providerFact({
    required String nutrientId,
    required double? value,
    required String sourceReference,
    required ServingDefinitionReference serving,
  }) => _factFromValue(
    nutrientId: nutrientId,
    value: value,
    source: NutrientSourceType.importedProvider,
    sourceReference: sourceReference,
    serving: serving,
    factVersion: 'open-food-facts-v2',
  );

  NutrientFact _factFromValue({
    required String nutrientId,
    required double? value,
    required NutrientSourceType source,
    required String sourceReference,
    required ServingDefinitionReference serving,
    required String factVersion,
  }) {
    final definition = _registry.definitionFor(nutrientId);
    final basis = NutrientBasis(
      NutrientBasisKind.perServing,
      servingDefinition: serving,
    );
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

  double _providerServingFactor({
    required double servingSize,
    required String servingUnit,
  }) {
    switch (servingUnit.trim().toLowerCase()) {
      case 'g':
      case 'gram':
      case 'grams':
      case 'ml':
      case 'millilitre':
      case 'milliliter':
      case 'millilitres':
      case 'milliliters':
        // Open Food Facts values used by FoodApiService are per 100 g/mL.
        return servingSize / 100;
      default:
        // A provider that supplies a non-dimensional serving cannot be safely
        // converted to another portion. Preserve its declared value as one
        // serving rather than inventing a generic mass factor.
        return 1;
    }
  }

  double? _scaleProviderValue(double? value, double factor) =>
      value == null ? null : value * factor;

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

class NutritionFoodCatalogError implements Exception {
  final String code;
  final String message;

  const NutritionFoodCatalogError(this.code, this.message);

  @override
  String toString() => 'NutritionFoodCatalogError($code): $message';
}
