import 'package:drift/drift.dart';

import '../../core/legacy_nutrient_adapter.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/typed_quantities.dart';
import '../database/app_database.dart';

class NutritionLegacyAdapterError implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const NutritionLegacyAdapterError(this.code, this.message, {this.cause});

  @override
  String toString() => 'NutritionLegacyAdapterError($code): $message';
}

/// The sole read-only compatibility boundary for v16 food logs and meal
/// templates. It never writes legacy rows, creates snapshots, resolves names,
/// or reads current catalogue nutrient values for historical facts.
class NutritionLegacyAdapter {
  static const String defaultLegacyUserId = 'legacy-local-user';
  static const String legacyQuantityRevision = 'legacy-quantity-v1';

  final AppDatabase _db;
  final NutrientRegistry _registry;
  final String legacyUserId;

  NutritionLegacyAdapter({
    required AppDatabase db,
    required NutrientRegistry registry,
    this.legacyUserId = defaultLegacyUserId,
  }) : _db = db,
       _registry = registry {
    if (legacyUserId.trim().isEmpty) {
      throw const NutritionLegacyAdapterError(
        'missing_legacy_user_scope',
        'A stable legacy read scope is required.',
      );
    }
  }

  Future<List<NutritionLegacyFoodLogReadModel>> readFoodLogs({
    String? userId,
    DateTime? from,
    DateTime? to,
  }) async {
    final rows =
        await (_db.select(_db.foodLogs)
              ..where((table) {
                final predicates = <Expression<bool>>[];
                if (from != null) {
                  predicates.add(table.loggedAt.isBiggerOrEqualValue(from));
                }
                if (to != null) {
                  predicates.add(table.loggedAt.isSmallerThanValue(to));
                }
                if (predicates.isEmpty) return const Constant(true);
                var result = predicates.first;
                for (final predicate in predicates.skip(1)) {
                  result = result & predicate;
                }
                return result;
              })
              ..orderBy([
                (table) => OrderingTerm(expression: table.loggedAt),
                (table) => OrderingTerm(expression: table.id),
              ]))
            .get();
    final duplicatePortableIds = _duplicatePortableIds(rows);
    final scope = userId?.trim() ?? legacyUserId;
    return Future.wait(
      rows.map(
        (row) => adaptFoodLog(
          row,
          userId: scope,
          duplicatePortableIds: duplicatePortableIds,
        ),
      ),
    );
  }

  Future<NutritionLegacyFoodLogReadModel?> readFoodLog({
    required int legacyRowId,
    String? userId,
  }) async {
    final row = await (_db.select(
      _db.foodLogs,
    )..where((table) => table.id.equals(legacyRowId))).getSingleOrNull();
    if (row == null) return null;
    final duplicatePortableIds = await _duplicatePortableIdsForUuid(row.uuid);
    return adaptFoodLog(
      row,
      userId: userId?.trim() ?? legacyUserId,
      duplicatePortableIds: duplicatePortableIds,
    );
  }

  Future<NutritionLegacyFoodLogReadModel> adaptFoodLog(
    FoodLog row, {
    String? userId,
    Set<String> duplicatePortableIds = const {},
  }) async {
    final scope = userId?.trim() ?? legacyUserId;
    final stableId = _foodLogStableId(row, duplicatePortableIds);
    final issues = <NutritionCompatibilityIssue>[
      const NutritionCompatibilityIssue(
        code: NutritionCompatibilityIssueCode.legacySourceUnknown,
        message:
            'The legacy row does not retain a typed source revision or estimate provenance.',
      ),
      const NutritionCompatibilityIssue(
        code: NutritionCompatibilityIssueCode.legacyNutrientCoverage,
        message:
            'Legacy rows retain four copied macros; fibre and micronutrients remain unknown.',
      ),
    ];
    if (row.uuid == null || row.uuid!.trim().isEmpty) {
      issues.add(
        const NutritionCompatibilityIssue(
          code: NutritionCompatibilityIssueCode.localIdOnlyIdentity,
          message:
              'This legacy row has no portable UUID and uses its namespaced local ID.',
          field: 'uuid',
        ),
      );
    }
    if (duplicatePortableIds.contains(_portableUuid(row.uuid))) {
      issues.add(
        const NutritionCompatibilityIssue(
          code: NutritionCompatibilityIssueCode.duplicateLegacyIdentity,
          message:
              'Duplicate legacy UUIDs were isolated with local row IDs so records do not collapse.',
          field: 'uuid',
        ),
      );
    }

    final identity = await _resolveFoodIdentity(
      legacyFoodItemId: row.foodItemId,
      displayLabel: row.name,
    );
    issues.addAll(identity.issues);
    final quantity = _adaptQuantity(
      amount: row.servingLogged,
      unit: row.servingUnit,
      stableId: stableId,
    );
    issues.addAll(quantity.issues);
    final facts = _legacyFacts(
      calories: row.calories,
      proteinG: row.proteinG,
      carbohydrateG: row.carbsG,
      fatG: row.fatG,
      fibreG: null,
      sourceReference: stableId,
    );
    final totals = _aggregate(facts);
    final item = NutritionHistoricalReadItem(
      stableId: stableId,
      position: 0,
      sourceType: NutritionHistoricalSourceType.legacyFoodLog.stableId,
      displayLabel: row.name,
      foodId: identity.canonicalFoodId,
      recipeVersionId: null,
      quantity: quantity,
      facts: facts,
      issues: [...identity.issues, ...quantity.issues],
    );
    return NutritionLegacyFoodLogReadModel(
      stableId: stableId,
      userId: scope,
      legacyRowId: row.id,
      uuid: _optionalText(row.uuid),
      loggedAtUtc: row.loggedAt.toUtc(),
      localDate: _localDateKey(row.loggedAt),
      mealCategory: row.mealType,
      mealGroupId: _optionalText(row.mealGroupId),
      displayLabel: row.name,
      foodIdentity: identity,
      quantity: quantity,
      isSynced: row.isSynced,
      completeness: totals.completeness,
      totals: totals,
      items: [item],
      issues: issues,
    );
  }

  Future<List<NutritionLegacyMealTemplateReadModel>> readTemplates() async {
    final templates =
        await (_db.select(_db.mealTemplates)..orderBy([
              (table) => OrderingTerm(expression: table.createdAt),
              (table) => OrderingTerm(expression: table.id),
            ]))
            .get();
    return Future.wait(templates.map(adaptTemplate));
  }

  Future<NutritionLegacyMealTemplateReadModel?> readTemplate(
    int templateId,
  ) async {
    final template = await (_db.select(
      _db.mealTemplates,
    )..where((table) => table.id.equals(templateId))).getSingleOrNull();
    if (template == null) return null;
    return adaptTemplate(template);
  }

  Future<NutritionLegacyMealTemplateReadModel> adaptTemplate(
    MealTemplate template,
  ) async {
    final rows =
        await (_db.select(_db.mealTemplateItems)
              ..where((table) => table.templateId.equals(template.id))
              ..orderBy([(table) => OrderingTerm(expression: table.id)]))
            .get();
    final stableId = 'legacy-meal-template:local-id:${template.id}';
    final issues = <NutritionCompatibilityIssue>[
      const NutritionCompatibilityIssue(
        code: NutritionCompatibilityIssueCode.localIdOnlyIdentity,
        message:
            'Legacy templates have no portable identity field and use a namespaced local ID.',
        field: 'template.id',
      ),
      const NutritionCompatibilityIssue(
        code: NutritionCompatibilityIssueCode.legacySourceUnknown,
        message:
            'Template rows do not retain nutrient source revisions or recipe lineage.',
      ),
      const NutritionCompatibilityIssue(
        code: NutritionCompatibilityIssueCode.legacyNutrientCoverage,
        message:
            'Template items retain four copied macros; fibre and micronutrients remain unknown.',
      ),
    ];
    if (rows.isEmpty) {
      issues.add(
        const NutritionCompatibilityIssue(
          code: NutritionCompatibilityIssueCode.unsupportedTemplateStructure,
          message:
              'An empty legacy template cannot provide a reusable item graph.',
        ),
      );
    }

    final items = <NutritionLegacyMealTemplateItemReadModel>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final itemStableId = 'legacy-meal-template-item:local-id:${row.id}';
      final identity = NutritionLegacyFoodIdentity(
        resolution: NutritionLegacyIdentityResolution.unresolved,
        displayLabel: row.name,
        legacyFoodItemId: null,
        canonicalFoodId: null,
        mappingEvidence: null,
        issues: [
          const NutritionCompatibilityIssue(
            code: NutritionCompatibilityIssueCode.unresolvedFoodIdentity,
            message:
                'Legacy template items have no food identity field; display text is not resolved.',
            field: 'name',
          ),
        ],
      );
      final quantity = _adaptQuantity(
        amount: row.servingLogged,
        unit: row.servingUnit,
        stableId: itemStableId,
      );
      final facts = _legacyFacts(
        calories: row.calories,
        proteinG: row.proteinG,
        carbohydrateG: row.carbsG,
        fatG: row.fatG,
        fibreG: null,
        sourceReference: itemStableId,
      );
      final itemIssues = [...identity.issues, ...quantity.issues];
      issues.addAll(itemIssues);
      items.add(
        NutritionLegacyMealTemplateItemReadModel(
          stableId: itemStableId,
          legacyRowId: row.id,
          position: index,
          displayLabel: row.name,
          foodIdentity: identity,
          quantity: quantity,
          facts: facts,
          issues: itemIssues,
        ),
      );
    }
    final totals = _aggregate(
      items.expand((item) => item.facts.values).toList(growable: false),
    );
    return NutritionLegacyMealTemplateReadModel(
      stableId: stableId,
      legacyRowId: template.id,
      name: template.name,
      defaultMealType: template.defaultMealType,
      createdAtUtc: template.createdAt.toUtc(),
      items: items,
      completeness: totals.completeness,
      totals: totals,
      issues: issues,
    );
  }

  Future<NutritionLegacyUsageMetrics> usageMetrics() async {
    final logs = await readFoodLogs();
    final templates = await readTemplates();
    return NutritionLegacyUsageMetrics(
      foodLogRows: logs.length,
      templateRows: templates.length,
      unresolvedFoodIdentityRows: logs
          .where((row) => !row.foodIdentity.isResolved)
          .length,
      localIdOnlyRows: logs
          .where(
            (row) => row.issues.any(
              (issue) =>
                  issue.code ==
                  NutritionCompatibilityIssueCode.localIdOnlyIdentity,
            ),
          )
          .length,
      unsupportedQuantityRows: logs
          .where(
            (row) =>
                row.quantity.state ==
                    NutritionHistoricalQuantityState.invalid ||
                row.quantity.state ==
                    NutritionHistoricalQuantityState.unresolved,
          )
          .length,
    );
  }

  Future<NutritionLegacyFoodIdentity> _resolveFoodIdentity({
    required int? legacyFoodItemId,
    required String displayLabel,
  }) async {
    final localId = legacyFoodItemId;
    if (localId == null) {
      return NutritionLegacyFoodIdentity(
        resolution: NutritionLegacyIdentityResolution.unresolved,
        displayLabel: displayLabel,
        legacyFoodItemId: null,
        canonicalFoodId: null,
        mappingEvidence: null,
        issues: const [
          NutritionCompatibilityIssue(
            code: NutritionCompatibilityIssueCode.unresolvedFoodIdentity,
            message:
                'This legacy row has no food identity; its copied display label remains authoritative.',
            field: 'food_item_id',
          ),
        ],
      );
    }
    final mapping =
        await (_db.select(_db.nutritionLegacyFoodMappings)
              ..where((table) => table.legacyFoodItemId.equals(localId)))
            .getSingleOrNull();
    if (mapping == null) {
      return NutritionLegacyFoodIdentity(
        resolution: NutritionLegacyIdentityResolution.unresolved,
        displayLabel: displayLabel,
        legacyFoodItemId: localId,
        canonicalFoodId: null,
        mappingEvidence: null,
        issues: const [
          NutritionCompatibilityIssue(
            code: NutritionCompatibilityIssueCode.missingLegacyFoodMapping,
            message:
                'No explicit B03 legacy mapping exists; the local food ID was not treated as portable identity.',
            field: 'food_item_id',
          ),
        ],
      );
    }
    final status = mapping.mappingStatus;
    if (status == 'reviewed' && mapping.foodId != null) {
      final target = await (_db.select(
        _db.nutritionFoods,
      )..where((table) => table.id.equals(mapping.foodId!))).getSingleOrNull();
      if (target == null) {
        return NutritionLegacyFoodIdentity(
          resolution: NutritionLegacyIdentityResolution.unresolved,
          displayLabel: displayLabel,
          legacyFoodItemId: localId,
          canonicalFoodId: null,
          mappingEvidence: mapping.evidence,
          issues: const [
            NutritionCompatibilityIssue(
              code: NutritionCompatibilityIssueCode.corruptLegacyRelationship,
              message:
                  'The reviewed legacy mapping points to a missing canonical food.',
              field: 'nutrition_legacy_food_mappings.food_id',
            ),
          ],
        );
      }
      return NutritionLegacyFoodIdentity(
        resolution: NutritionLegacyIdentityResolution.resolved,
        displayLabel: displayLabel,
        legacyFoodItemId: localId,
        canonicalFoodId: mapping.foodId,
        mappingEvidence: mapping.evidence,
        issues: const [],
      );
    }
    final issue = status == 'ambiguous'
        ? const NutritionCompatibilityIssue(
            code: NutritionCompatibilityIssueCode.ambiguousFoodMapping,
            message:
                'The explicit legacy mapping is ambiguous; no canonical food was selected.',
            field: 'nutrition_legacy_food_mappings.mapping_status',
          )
        : const NutritionCompatibilityIssue(
            code: NutritionCompatibilityIssueCode.unresolvedFoodIdentity,
            message:
                'The explicit legacy mapping remains unresolved; no name fallback was attempted.',
            field: 'nutrition_legacy_food_mappings.mapping_status',
          );
    return NutritionLegacyFoodIdentity(
      resolution: status == 'ambiguous'
          ? NutritionLegacyIdentityResolution.ambiguous
          : NutritionLegacyIdentityResolution.unresolved,
      displayLabel: displayLabel,
      legacyFoodItemId: localId,
      canonicalFoodId: null,
      mappingEvidence: mapping.evidence,
      issues: [issue],
    );
  }

  NutritionHistoricalQuantity _adaptQuantity({
    required double amount,
    required String unit,
    required String stableId,
  }) {
    final normalizedUnit = unit.trim().toLowerCase();
    if (!amount.isFinite || amount <= 0) {
      return NutritionHistoricalQuantity(
        storedAmount: amount,
        storedUnit: unit,
        quantity: null,
        state: NutritionHistoricalQuantityState.invalid,
        issues: [
          NutritionCompatibilityIssue(
            code: NutritionCompatibilityIssueCode.invalidStoredAmount,
            message:
                'The legacy numeric amount is not a positive finite quantity; the stored value was not coerced.',
            field: 'serving_logged',
          ),
        ],
      );
    }
    final amountValue = QuantityAmount.fromNum(amount);
    try {
      if ({'serving', 'servings'}.contains(normalizedUnit)) {
        final quantity = Quantity.serving(
          amount: amountValue.toString(),
          definition: ServingDefinitionReference(
            id: 'legacy-serving:$stableId',
            revision: legacyQuantityRevision,
            source: 'legacy',
          ),
          source: 'legacy',
          approximate: true,
        );
        return NutritionHistoricalQuantity(
          storedAmount: amount,
          storedUnit: unit,
          quantity: quantity,
          state: NutritionHistoricalQuantityState.contextual,
          issues: const [
            NutritionCompatibilityIssue(
              code: NutritionCompatibilityIssueCode.unsupportedQuantity,
              message:
                  'The legacy serving remains contextual because no serving definition was stored.',
              field: 'serving_unit',
            ),
          ],
        );
      }
      if (_householdMeasureLabels.contains(normalizedUnit)) {
        final quantity = Quantity.householdReference(
          count: amountValue.toString(),
          reference: HouseholdMeasureReference(
            measureType: normalizedUnit,
            resolutionState: HouseholdResolutionState.unresolved,
          ),
          source: 'legacy',
          approximate: true,
        );
        return NutritionHistoricalQuantity(
          storedAmount: amount,
          storedUnit: unit,
          quantity: quantity,
          state: NutritionHistoricalQuantityState.unresolved,
          issues: const [
            NutritionCompatibilityIssue(
              code: NutritionCompatibilityIssueCode.unsupportedQuantity,
              message:
                  'The legacy household label is preserved without a universal mass conversion.',
              field: 'serving_unit',
            ),
          ],
        );
      }
      final unitDefinition = _resolveLegacyUnit(normalizedUnit);
      final quantity = Quantity(
        amount: amountValue,
        unit: unitDefinition.unit,
        context: const QuantityContext(
          source: 'legacy',
          sourceScope: legacyQuantityRevision,
          legacy: true,
        ),
      );
      return NutritionHistoricalQuantity(
        storedAmount: amount,
        storedUnit: unit,
        quantity: quantity,
        state: NutritionHistoricalQuantityState.typed,
        issues: const [],
      );
    } on QuantityError catch (error) {
      return NutritionHistoricalQuantity(
        storedAmount: amount,
        storedUnit: unit,
        quantity: null,
        state: NutritionHistoricalQuantityState.unresolved,
        issues: [
          NutritionCompatibilityIssue(
            code: NutritionCompatibilityIssueCode.unsupportedQuantity,
            message: error.message,
            field: 'serving_unit',
          ),
        ],
      );
    }
  }

  QuantityUnitDefinition _resolveLegacyUnit(String token) {
    if (token == 'count' || token == 'unit' || token == 'units') {
      return QuantityUnitRegistry.definitionFor(QuantityUnit.piece);
    }
    return QuantityUnitRegistry.resolveToken(token);
  }

  Map<String, NutrientFact> _legacyFacts({
    required num? calories,
    required num? proteinG,
    required num? carbohydrateG,
    required num? fatG,
    required num? fibreG,
    required String sourceReference,
  }) {
    final facts = LegacyNutrientAdapter.adaptMacros(
      registry: _registry,
      calories: calories,
      proteinG: proteinG,
      carbohydrateG: carbohydrateG,
      fatG: fatG,
      fibreG: fibreG,
      basis: NutrientBasis(NutrientBasisKind.absolute),
      sourceReference: sourceReference,
    );
    for (final definition in _registry.definitions) {
      facts.putIfAbsent(
        definition.id,
        () => LegacyNutrientAdapter.adapt(
          registry: _registry,
          nutrientId: definition.id,
          value: null,
          unit: definition.unit,
          basis: NutrientBasis(NutrientBasisKind.absolute),
          sourceReference: sourceReference,
        ),
      );
    }
    return facts;
  }

  NutrientAggregationResult _aggregate(Object factsOrValues) {
    final Iterable<NutrientFact> facts = factsOrValues is Map
        ? (factsOrValues as Map<String, NutrientFact>).values
        : (factsOrValues as Iterable<NutrientFact>);
    return NutrientAggregationService.aggregate(
      registry: _registry,
      contributions: facts.map((fact) => NutrientContribution(fact: fact)),
      requestedNutrientIds: _registry.definitions
          .map((definition) => definition.id)
          .toSet(),
    );
  }

  Set<String> _duplicatePortableIds(List<FoodLog> rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      final value = _portableUuid(row.uuid);
      if (value != null) counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toSet();
  }

  Future<Set<String>> _duplicatePortableIdsForUuid(String? uuid) async {
    final value = _portableUuid(uuid);
    if (value == null) return const {};
    final rows = await (_db.select(
      _db.foodLogs,
    )..where((table) => table.uuid.equals(value))).get();
    return rows.length > 1 ? {value} : const {};
  }

  String _foodLogStableId(FoodLog row, Set<String> duplicatePortableIds) {
    final uuid = _portableUuid(row.uuid);
    if (uuid != null && !duplicatePortableIds.contains(uuid)) {
      return 'legacy-food-log:uuid:$uuid';
    }
    return 'legacy-food-log:local-id:${row.id}';
  }

  static String? _portableUuid(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _localDateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static const Set<String> _householdMeasureLabels = {
    'katori',
    'bowl',
    'cup',
    'glass',
    'ladle',
    'scoop',
    'tablespoon',
    'tbsp',
    'teaspoon',
    'tsp',
    'handful',
    'plate',
    'thali',
    'roti',
    'rotis',
    'chapati',
    'chapatis',
  };
}

class NutritionLegacyUsageMetrics {
  final int foodLogRows;
  final int templateRows;
  final int unresolvedFoodIdentityRows;
  final int localIdOnlyRows;
  final int unsupportedQuantityRows;

  const NutritionLegacyUsageMetrics({
    required this.foodLogRows,
    required this.templateRows,
    required this.unresolvedFoodIdentityRows,
    required this.localIdOnlyRows,
    required this.unsupportedQuantityRows,
  });
}
