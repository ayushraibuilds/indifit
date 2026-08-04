import 'nutrients.dart';
import 'nutrition_consumption_snapshots.dart';
import 'typed_quantities.dart';

/// Stable source labels used by the unified historical read boundary.
enum NutritionHistoricalSourceType {
  canonicalSnapshot,
  legacyFoodLog,
  legacyMealTemplate,
}

extension NutritionHistoricalSourceTypeContract
    on NutritionHistoricalSourceType {
  String get stableId => switch (this) {
    NutritionHistoricalSourceType.canonicalSnapshot => 'canonical_snapshot',
    NutritionHistoricalSourceType.legacyFoodLog => 'legacy_food_log',
    NutritionHistoricalSourceType.legacyMealTemplate => 'legacy_meal_template',
  };
}

/// Typed compatibility limitations are visible to callers instead of being
/// silently converted into an apparently complete modern record.
enum NutritionCompatibilityIssueCode {
  unresolvedFoodIdentity,
  ambiguousFoodMapping,
  missingLegacyFoodMapping,
  missingCustomFoodReference,
  localIdOnlyIdentity,
  duplicateLegacyIdentity,
  unsupportedQuantity,
  invalidStoredAmount,
  unknownNutrientValue,
  legacyNutrientCoverage,
  legacySourceUnknown,
  unsupportedTemplateStructure,
  corruptLegacyRelationship,
  unsupportedBackupRecord,
}

extension NutritionCompatibilityIssueCodeContract
    on NutritionCompatibilityIssueCode {
  String get stableId => switch (this) {
    NutritionCompatibilityIssueCode.unresolvedFoodIdentity =>
      'unresolved_food_identity',
    NutritionCompatibilityIssueCode.ambiguousFoodMapping =>
      'ambiguous_food_mapping',
    NutritionCompatibilityIssueCode.missingLegacyFoodMapping =>
      'missing_legacy_food_mapping',
    NutritionCompatibilityIssueCode.missingCustomFoodReference =>
      'missing_custom_food_reference',
    NutritionCompatibilityIssueCode.localIdOnlyIdentity =>
      'local_id_only_identity',
    NutritionCompatibilityIssueCode.duplicateLegacyIdentity =>
      'duplicate_legacy_identity',
    NutritionCompatibilityIssueCode.unsupportedQuantity =>
      'unsupported_quantity',
    NutritionCompatibilityIssueCode.invalidStoredAmount =>
      'invalid_stored_amount',
    NutritionCompatibilityIssueCode.unknownNutrientValue =>
      'unknown_nutrient_value',
    NutritionCompatibilityIssueCode.legacyNutrientCoverage =>
      'legacy_nutrient_coverage',
    NutritionCompatibilityIssueCode.legacySourceUnknown =>
      'legacy_source_unknown',
    NutritionCompatibilityIssueCode.unsupportedTemplateStructure =>
      'unsupported_template_structure',
    NutritionCompatibilityIssueCode.corruptLegacyRelationship =>
      'corrupt_legacy_relationship',
    NutritionCompatibilityIssueCode.unsupportedBackupRecord =>
      'unsupported_backup_record',
  };
}

class NutritionCompatibilityIssue {
  final NutritionCompatibilityIssueCode code;
  final String message;
  final String? field;

  const NutritionCompatibilityIssue({
    required this.code,
    required this.message,
    this.field,
  });

  String get stableId => code.stableId;

  Map<String, dynamic> toJson() => {
    'code': code.stableId,
    'message': message,
    if (field != null) 'field': field,
  };
}

enum NutritionLegacyIdentityResolution { resolved, ambiguous, unresolved }

/// Identity evidence for a legacy row. Display text is deliberately retained
/// but never used as a resolver key.
class NutritionLegacyFoodIdentity {
  final NutritionLegacyIdentityResolution resolution;
  final String displayLabel;
  final int? legacyFoodItemId;
  final String? canonicalFoodId;
  final String? mappingEvidence;
  final List<NutritionCompatibilityIssue> issues;

  const NutritionLegacyFoodIdentity({
    required this.resolution,
    required this.displayLabel,
    required this.legacyFoodItemId,
    required this.canonicalFoodId,
    required this.mappingEvidence,
    required this.issues,
  });

  bool get isResolved =>
      resolution == NutritionLegacyIdentityResolution.resolved &&
      canonicalFoodId != null;
}

enum NutritionHistoricalQuantityState { typed, contextual, unresolved, invalid }

/// A quantity projection that preserves the original legacy value/unit even
/// when no safe canonical conversion exists.
class NutritionHistoricalQuantity {
  final double? storedAmount;
  final String storedUnit;
  final Quantity? quantity;
  final NutritionHistoricalQuantityState state;
  final List<NutritionCompatibilityIssue> issues;

  const NutritionHistoricalQuantity({
    required this.storedAmount,
    required this.storedUnit,
    required this.quantity,
    required this.state,
    required this.issues,
  });

  bool get isResolved => quantity != null;
}

/// Common item shape consumed by history/daily-total UI.
class NutritionHistoricalReadItem {
  final String stableId;
  final int position;
  final String sourceType;
  final String? displayLabel;
  final String? foodId;
  final String? recipeVersionId;
  final NutritionHistoricalQuantity quantity;
  final Map<String, NutrientFact> facts;
  final List<NutritionCompatibilityIssue> issues;

  NutritionHistoricalReadItem({
    required this.stableId,
    required this.position,
    required this.sourceType,
    required this.displayLabel,
    required this.foodId,
    required this.recipeVersionId,
    required this.quantity,
    required Map<String, NutrientFact> facts,
    required List<NutritionCompatibilityIssue> issues,
  }) : facts = Map.unmodifiable(facts),
       issues = List.unmodifiable(issues);
}

/// Unified historical record contract. Implementations are either immutable
/// canonical snapshots or read-only legacy adaptations.
abstract interface class NutritionHistoricalReadRecord {
  String get stableId;
  String get userId;
  String get sourceType;
  DateTime get loggedAtUtc;
  String get localDate;
  String get mealCategory;
  String? get mealGroupId;
  String get displayLabel;
  NutrientCompleteness get completeness;
  NutrientAggregationResult get totals;
  List<NutritionHistoricalReadItem> get items;
  List<NutritionCompatibilityIssue> get issues;
  bool get isLegacy;
}

class NutritionLegacyFoodLogReadModel implements NutritionHistoricalReadRecord {
  @override
  final String stableId;
  @override
  final String userId;
  final int legacyRowId;
  final String? uuid;
  @override
  final DateTime loggedAtUtc;
  @override
  final String localDate;
  @override
  final String mealCategory;
  @override
  final String? mealGroupId;
  @override
  final String displayLabel;
  final NutritionLegacyFoodIdentity foodIdentity;
  final NutritionHistoricalQuantity quantity;
  final bool isSynced;
  @override
  final NutrientCompleteness completeness;
  @override
  final NutrientAggregationResult totals;
  @override
  final List<NutritionHistoricalReadItem> items;
  @override
  final List<NutritionCompatibilityIssue> issues;

  NutritionLegacyFoodLogReadModel({
    required this.stableId,
    required this.userId,
    required this.legacyRowId,
    required this.uuid,
    required this.loggedAtUtc,
    required this.localDate,
    required this.mealCategory,
    required this.mealGroupId,
    required this.displayLabel,
    required this.foodIdentity,
    required this.quantity,
    required this.isSynced,
    required this.completeness,
    required this.totals,
    required List<NutritionHistoricalReadItem> items,
    required List<NutritionCompatibilityIssue> issues,
  }) : items = List.unmodifiable(items),
       issues = List.unmodifiable(issues);

  @override
  String get sourceType => NutritionHistoricalSourceType.legacyFoodLog.stableId;

  @override
  bool get isLegacy => true;
}

class NutritionCanonicalSnapshotReadModel
    implements NutritionHistoricalReadRecord {
  final NutritionConsumptionSnapshot snapshot;

  const NutritionCanonicalSnapshotReadModel(this.snapshot);

  @override
  String get stableId => snapshot.id;

  @override
  String get userId => snapshot.userId;

  @override
  String get sourceType =>
      NutritionHistoricalSourceType.canonicalSnapshot.stableId;

  @override
  DateTime get loggedAtUtc => snapshot.loggedAtUtc;

  @override
  String get localDate =>
      snapshot.localDate ?? _localDateKey(snapshot.loggedAtUtc);

  @override
  String get mealCategory => snapshot.mealCategory;

  @override
  String? get mealGroupId => snapshot.mealGroupId;

  @override
  String get displayLabel =>
      snapshot.items.length == 1 && snapshot.items.single.displayLabel != null
      ? snapshot.items.single.displayLabel!
      : 'Canonical nutrition snapshot';

  @override
  NutrientCompleteness get completeness => snapshot.completeness;

  @override
  NutrientAggregationResult get totals => snapshot.totals;

  @override
  List<NutritionHistoricalReadItem> get items => [
    for (final item in snapshot.items)
      NutritionHistoricalReadItem(
        stableId: item.id,
        position: item.position,
        sourceType: sourceType,
        displayLabel: item.displayLabel,
        foodId: item.foodId,
        recipeVersionId: item.recipeVersionId,
        quantity: NutritionHistoricalQuantity(
          storedAmount: item.quantity.amount.asDouble,
          storedUnit: item.quantity.definition.stableId,
          quantity: item.quantity,
          state: NutritionHistoricalQuantityState.typed,
          issues: const [],
        ),
        facts: item.facts,
        issues: const [],
      ),
  ];

  @override
  List<NutritionCompatibilityIssue> get issues => const [];

  @override
  bool get isLegacy => false;
}

class NutritionLegacyMealTemplateItemReadModel {
  final String stableId;
  final int legacyRowId;
  final int position;
  final String displayLabel;
  final NutritionLegacyFoodIdentity foodIdentity;
  final NutritionHistoricalQuantity quantity;
  final Map<String, NutrientFact> facts;
  final List<NutritionCompatibilityIssue> issues;

  NutritionLegacyMealTemplateItemReadModel({
    required this.stableId,
    required this.legacyRowId,
    required this.position,
    required this.displayLabel,
    required this.foodIdentity,
    required this.quantity,
    required Map<String, NutrientFact> facts,
    required List<NutritionCompatibilityIssue> issues,
  }) : facts = Map.unmodifiable(facts),
       issues = List.unmodifiable(issues);
}

class NutritionLegacyMealTemplateReadModel {
  final String stableId;
  final int legacyRowId;
  final String name;
  final String defaultMealType;
  final DateTime createdAtUtc;
  final List<NutritionLegacyMealTemplateItemReadModel> items;
  final NutrientCompleteness completeness;
  final NutrientAggregationResult totals;
  final List<NutritionCompatibilityIssue> issues;

  NutritionLegacyMealTemplateReadModel({
    required this.stableId,
    required this.legacyRowId,
    required this.name,
    required this.defaultMealType,
    required this.createdAtUtc,
    required List<NutritionLegacyMealTemplateItemReadModel> items,
    required this.completeness,
    required this.totals,
    required List<NutritionCompatibilityIssue> issues,
  }) : items = List.unmodifiable(items),
       issues = List.unmodifiable(issues);

  String get sourceType =>
      NutritionHistoricalSourceType.legacyMealTemplate.stableId;
}

class NutritionDailyReadModel {
  final String userId;
  final String localDate;
  final List<NutritionHistoricalReadRecord> records;
  final List<String> recordIds;
  final NutrientAggregationResult totals;
  final Map<String, int> sourceCounts;
  final List<NutritionCompatibilityIssue> issues;

  NutritionDailyReadModel({
    required this.userId,
    required this.localDate,
    required List<NutritionHistoricalReadRecord> records,
    required List<String> recordIds,
    required this.totals,
    required Map<String, int> sourceCounts,
    required List<NutritionCompatibilityIssue> issues,
  }) : records = List.unmodifiable(records),
       recordIds = List.unmodifiable(recordIds),
       sourceCounts = Map.unmodifiable(sourceCounts),
       issues = List.unmodifiable(issues);
}

String _localDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
