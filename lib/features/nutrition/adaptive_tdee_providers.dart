import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../../core/di/user_profile_provider.dart';
import '../../data/database/app_database.dart';
import '../../data/models/adaptive_tdee_models.dart';
import '../../data/repositories/adaptive_tdee_repository.dart';
import 'nutrition_providers.dart';

/// Reactive change stream for food logs.
final adaptiveTdeeFoodLogsSignalProvider =
    StreamProvider.autoDispose<List<FoodLog>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.foodLogs).watch();
});

/// Reactive change stream for body measurements.
final adaptiveTdeeMeasurementsSignalProvider =
    StreamProvider.autoDispose<List<BodyMeasurement>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.bodyMeasurements).watch();
});

/// Repository provider for adaptive TDEE evaluation.
final adaptiveTdeeRepositoryProvider = Provider<AdaptiveTdeeRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final dates = ref.watch(localScheduleDateServiceProvider);
  final nutrition = ref.watch(nutritionReadModelRepositoryProvider).valueOrNull;
  return AdaptiveTdeeRepository(db, dates: dates, nutrition: nutrition);
});

/// Reactive, auto-disposing provider that re-evaluates when food logs,
/// weight entries, or user profiles change.
final adaptiveTdeeEstimateProvider =
    FutureProvider.autoDispose<AdaptiveTdeeEstimate>((ref) async {
  // Subscribe to table change streams and profile changes
  ref.watch(adaptiveTdeeFoodLogsSignalProvider);
  ref.watch(adaptiveTdeeMeasurementsSignalProvider);
  ref.watch(userProfileProvider);

  final repository = ref.watch(adaptiveTdeeRepositoryProvider);
  final timezone =
      await ref.watch(localTimezoneServiceProvider).currentTimezoneId();

  return repository.evaluate(
    nowUtc: DateTime.now().toUtc(),
    timezoneId: timezone,
  );
});
