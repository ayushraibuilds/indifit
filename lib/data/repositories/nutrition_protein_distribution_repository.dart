import '../../core/nutrients.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/nutrition_protein_distribution.dart';
import 'nutrition_read_model_repository.dart';

/// Read-only owner for the B03-15 descriptive protein distribution.
///
/// It consumes the unified history boundary and removes superseded immutable
/// events before delegating all nutrient arithmetic to the B03-05 aggregation
/// service. It never writes, recalculates catalogue data, or reads mutable
/// recipe/estimate state.
class NutritionProteinDistributionRepository {
  final NutrientRegistry _registry;
  final NutritionReadModelRepository _history;
  final NutritionProteinDistributionService _service;

  const NutritionProteinDistributionRepository({
    required NutrientRegistry registry,
    required NutritionReadModelRepository history,
    NutritionProteinDistributionService service =
        const NutritionProteinDistributionService(),
  }) : _registry = registry,
       _history = history,
       _service = service;

  Future<NutritionProteinDistribution> forLocalDate({
    required String userId,
    required String localDate,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedDate = localDate.trim();
    if (normalizedUserId.isEmpty) {
      throw const NutritionProteinDistributionError(
        'missing_user_id',
        'A user ID is required to read protein distribution.',
      );
    }
    if (!_isIsoDate(normalizedDate)) {
      throw const NutritionProteinDistributionError(
        'invalid_local_date',
        'A local date must use the YYYY-MM-DD compatibility format.',
      );
    }

    final history = await _history.listHistory(userId: normalizedUserId);
    final superseded = <String>{};
    for (final record in history) {
      if (record is NutritionCanonicalSnapshotReadModel) {
        final predecessor = record.snapshot.lineage.supersedesSnapshotId;
        if (predecessor != null) superseded.add(predecessor);
      }
    }
    final activeForDate = history.where(
      (record) =>
          record.localDate == normalizedDate &&
          !superseded.contains(record.stableId),
    );
    return _service.build(
      registry: _registry,
      userId: normalizedUserId,
      localDate: normalizedDate,
      records: activeForDate,
    );
  }

  static bool _isIsoDate(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      DateTime.tryParse(value) != null;
}

class NutritionProteinDistributionError implements Exception {
  final String code;
  final String message;

  const NutritionProteinDistributionError(this.code, this.message);

  @override
  String toString() => 'NutritionProteinDistributionError($code): $message';
}
