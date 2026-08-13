import '../../core/nutrients.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../database/app_database.dart';
import 'nutrition_consumption_repository.dart';
import 'nutrition_legacy_adapter.dart';

/// The unified, read-only B03 history boundary.
///
/// Canonical records are read through [NutritionConsumptionRepository], while
/// legacy records are adapted through [NutritionLegacyAdapter]. This class
/// owns neither source graph and never writes or recalculates either one from
/// mutable catalogue state.
class NutritionReadModelRepository {
  final NutrientRegistry _registry;
  final NutritionConsumptionRepository _canonical;
  final NutritionLegacyAdapter _legacy;

  NutritionReadModelRepository({
    required AppDatabase db,
    required NutrientRegistry registry,
    NutritionConsumptionRepository? canonicalRepository,
    NutritionLegacyAdapter? legacyAdapter,
    String legacyUserId = NutritionLegacyAdapter.defaultLegacyUserId,
  }) : _registry = registry,
       _canonical =
           canonicalRepository ??
           NutritionConsumptionRepository(db: db, registry: registry),
       _legacy =
           legacyAdapter ??
           NutritionLegacyAdapter(
             db: db,
             registry: registry,
             legacyUserId: legacyUserId,
           );

  /// Emits canonical-history invalidations without exposing the Drift graph.
  ///
  /// Legacy food-log changes are already delivered through the existing
  /// [FoodRepository] day stream. The dashboard combines that stream with this
  /// canonical stream and always re-reads through this repository.
  Stream<void> watchCanonicalChanges({required String userId}) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw const NutritionReadModelError(
        'missing_user_id',
        'A user ID is required to watch canonical history changes.',
      );
    }
    return _canonical.watchChanges(userId: normalizedUserId);
  }

  Future<List<NutritionHistoricalReadRecord>> listHistory({
    required String userId,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) async {
    final canonical = await _canonical.listAllForUser(
      userId: userId,
      fromUtc: fromUtc,
      toUtc: toUtc,
    );
    final legacy = await _legacy.readFoodLogs(
      userId: userId,
      from: fromUtc,
      to: toUtc,
    );
    return _sortAndDedupe([
      ...canonical.map(NutritionCanonicalSnapshotReadModel.new),
      ...legacy,
    ]);
  }

  Future<List<NutritionHistoricalReadRecord>> listForLocalDate({
    required String userId,
    required String localDate,
  }) async {
    final normalizedDate = localDate.trim();
    if (!_isIsoDate(normalizedDate)) {
      throw const NutritionReadModelError(
        'invalid_local_date',
        'A local date must use the YYYY-MM-DD compatibility format.',
      );
    }
    final records = await listHistory(userId: userId);
    final superseded = _supersededCanonicalIds(records);
    return records
        .where(
          (record) =>
              record.localDate == normalizedDate &&
              (record is! NutritionCanonicalSnapshotReadModel ||
                  (!superseded.contains(record.stableId) &&
                      !record.snapshot.isRetraction)),
        )
        .toList(growable: false);
  }

  Future<NutritionDailyReadModel> dailyTotals({
    required String userId,
    required String localDate,
  }) async {
    final allRecords = await listHistory(userId: userId);
    final superseded = _supersededCanonicalIds(allRecords);
    final records = allRecords
        .where(
          (record) =>
              record.localDate == localDate &&
              // Canonical correction lineage must not hide a legacy row with
              // the same text ID; history identity includes source type.
              (record is! NutritionCanonicalSnapshotReadModel ||
                  (!superseded.contains(record.stableId) &&
                      !record.snapshot.isRetraction)),
        )
        .toList(growable: false);
    final contributions = records.expand(
      (record) => record.items.expand((item) => item.facts.values),
    );
    final totals = NutrientAggregationService.aggregate(
      registry: _registry,
      contributions: contributions.map(
        (fact) => NutrientContribution(fact: fact),
      ),
      requestedNutrientIds: _registry.definitions
          .map((definition) => definition.id)
          .toSet(),
    );
    final sourceCounts = <String, int>{};
    final issues = <NutritionCompatibilityIssue>[];
    for (final record in records) {
      sourceCounts.update(
        record.sourceType,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      issues.addAll(record.issues);
    }
    return NutritionDailyReadModel(
      userId: userId,
      localDate: localDate,
      records: records,
      recordIds: records
          .map((record) => record.stableId)
          .toList(growable: false),
      totals: totals,
      sourceCounts: sourceCounts,
      issues: _dedupeIssues(issues),
    );
  }

  Future<List<NutritionLegacyMealTemplateReadModel>> listLegacyTemplates() =>
      _legacy.readTemplates();

  Future<NutritionLegacyMealTemplateReadModel?> getLegacyTemplate(
    int templateId,
  ) => _legacy.readTemplate(templateId);

  Future<NutritionLegacyUsageMetrics> legacyUsageMetrics() =>
      _legacy.usageMetrics();

  List<NutritionHistoricalReadRecord> _sortAndDedupe(
    Iterable<NutritionHistoricalReadRecord> records,
  ) {
    final byId = <String, NutritionHistoricalReadRecord>{};
    for (final record in records) {
      // Canonical IDs are user-provided portable IDs while legacy IDs are
      // namespaced compatibility IDs. Keep the source namespace in the
      // de-duplication key so a canonical ID cannot hide a legacy row with
      // the same text.
      final key = '${record.sourceType}\u0000${record.stableId}';
      byId.putIfAbsent(key, () => record);
    }
    final result = byId.values.toList();
    result.sort((left, right) {
      final time = left.loggedAtUtc.compareTo(right.loggedAtUtc);
      return time == 0 ? left.stableId.compareTo(right.stableId) : time;
    });
    return List.unmodifiable(result);
  }

  static List<NutritionCompatibilityIssue> _dedupeIssues(
    Iterable<NutritionCompatibilityIssue> issues,
  ) {
    final seen = <String>{};
    return List.unmodifiable(
      issues.where((issue) => seen.add('${issue.stableId}:${issue.field}')),
    );
  }

  static Set<String> _supersededCanonicalIds(
    Iterable<NutritionHistoricalReadRecord> records,
  ) => {
    for (final record in records)
      if (record is NutritionCanonicalSnapshotReadModel &&
          record.snapshot.lineage.supersedesSnapshotId != null)
        record.snapshot.lineage.supersedesSnapshotId!,
  };

  static bool _isIsoDate(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      DateTime.tryParse(value) != null;
}

class NutritionReadModelError implements Exception {
  final String code;
  final String message;

  const NutritionReadModelError(this.code, this.message);

  @override
  String toString() => 'NutritionReadModelError($code): $message';
}
