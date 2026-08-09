import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/providers.dart';
import '../../data/repositories/progress_dashboard_read_repository.dart';
import 'progress_dashboard_models.dart';

final progressDashboardReadRepositoryProvider =
    Provider<ProgressDashboardReadRepository>((ref) {
      return ProgressDashboardReadRepository(
        ref.watch(databaseProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
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
      return ref
          .watch(progressDashboardReadRepositoryProvider)
          .read(
            nowUtc: DateTime.now().toUtc(),
            timezoneId: timezoneId,
            weightGoal: goal,
          );
    });

ProgressWeightGoal? _acceptedWeightGoal(SharedPreferences preferences) {
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
