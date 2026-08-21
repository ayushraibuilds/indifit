import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/providers.dart';
import '../../data/repositories/nutrition_read_model_repository.dart';
import '../../data/repositories/progress_dashboard_read_repository.dart';
import 'progress_dashboard_models.dart';

final progressDashboardReadRepositoryProvider =
    FutureProvider<ProgressDashboardReadRepository>((ref) async {
      ref.watch(nutritionGoalVersionChangesProvider);
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
      final preferences = await SharedPreferences.getInstance();
      final goal = _acceptedWeightGoal(preferences);
      final repo = await ref.watch(
        progressDashboardReadRepositoryProvider.future,
      );
      return repo.read(
        nowUtc: DateTime.now().toUtc(),
        timezoneId: timezoneId,
        weightGoal: goal,
      );
    });

ProgressWeightGoal? _acceptedWeightGoal(SharedPreferences preferences) {
  // The current repository has no typed B04 body-target read model. Keep the
  // existing onboarding compatibility setting visible only as the user's
  // persisted weight reference; Progress must not present it as a newly
  // calculated or nutrition-goal-derived target.
  final target = preferences.getDouble('user_target_weight');
  final direction = switch (preferences.getString('user_goal')?.trim()) {
    'lose' || 'loss' => ProgressWeightGoalDirection.loss,
    'gain' => ProgressWeightGoalDirection.gain,
    'maintain' || 'maintenance' => ProgressWeightGoalDirection.maintenance,
    _ => null,
  };
  if (target == null || target <= 0 || direction == null) return null;
  return ProgressWeightGoal(targetKg: target, direction: direction);
}
