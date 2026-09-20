import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/core_providers.dart';
import '../../../data/models/progress_period_comparison_models.dart';
import '../../../data/repositories/progress_period_comparison_repository.dart';
import '../../nutrition/nutrition_providers.dart';

/// Holds the currently selected comparative time range.
final periodComparisonRangeProvider =
    StateProvider<PeriodComparisonRange>((ref) => PeriodComparisonRange.week);

/// Async state holding the comparative snapshot for the active range.
final progressPeriodComparisonSnapshotProvider =
    FutureProvider.autoDispose<ProgressPeriodComparisonSnapshot>((ref) async {
  final db = ref.watch(databaseProvider);
  final dates = ref.watch(localScheduleDateServiceProvider);
  final nutrition = await ref.watch(nutritionReadModelRepositoryProvider.future);
  final nutritionTargets = ref.watch(nutritionTargetAuthorityProvider);

  final repository = ProgressPeriodComparisonRepository(
    database: db,
    dates: dates,
    nutrition: nutrition,
    nutritionTargets: nutritionTargets,
  );

  final range = ref.watch(periodComparisonRangeProvider);
  final timezoneService = ref.watch(localTimezoneServiceProvider);
  final timezoneId = await timezoneService.currentTimezoneId();
  final nowUtc = DateTime.now().toUtc();

  return repository.comparePeriods(
    range: range,
    nowUtc: nowUtc,
    timezoneId: timezoneId,
  );
});
