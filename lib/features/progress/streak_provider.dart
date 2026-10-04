import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/core_providers.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/streak_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../nutrition/nutrition_providers.dart';

/// The one place screens and the workout player read the streak from.
final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  return StreakRepository(
    nutrition: () => ref.read(nutritionReadModelRepositoryProvider.future),
    workouts: ref.watch(workoutRepositoryProvider),
    preferences: () async {
      try {
        return ref.read(sharedPreferencesProvider);
      } on Object catch (error) {
        // Tests and early bootstrap may not override the provider.
        AppLogger.info('Streak: reading SharedPreferences directly ($error)');
        return SharedPreferences.getInstance();
      }
    },
  );
});
