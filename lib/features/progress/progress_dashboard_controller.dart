import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/repositories/nutrition_read_model_repository.dart';
import '../../data/repositories/progress_dashboard_read_repository.dart';
import 'progress_dashboard_models.dart';

final progressDashboardReadRepositoryProvider =
    FutureProvider<ProgressDashboardReadRepository>((ref) async {
      ref.watch(nutritionTargetAuthorityChangesProvider);
      NutritionReadModelRepository? nutrition;
      try {
        nutrition = await ref.watch(
          nutritionReadModelRepositoryProvider.future,
        );
      } catch (_) {
        // Graceful fallback if nutrition registry/catalog is uninitialized.
      }
      final targets = ref.watch(nutritionTargetAuthorityProvider);
      return ProgressDashboardReadRepository(
        ref.watch(databaseProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
        nutrition: nutrition,
        nutritionTargets: targets,
      );
    });

/// A single refreshable screen read. Logging remains owned by the established
/// workout repository; successful logs simply invalidate this presentation
/// snapshot so the visible value updates without an app restart.
final progressDashboardSnapshotProvider =
    FutureProvider.autoDispose<ProgressDashboardSnapshot>((ref) async {
      final timezoneId = await ref
          .watch(localTimezoneServiceProvider)
          .currentTimezoneId();
      final repo = await ref.watch(
        progressDashboardReadRepositoryProvider.future,
      );
      return repo.read(nowUtc: DateTime.now().toUtc(), timezoneId: timezoneId);
    });
