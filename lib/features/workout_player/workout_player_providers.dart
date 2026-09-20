import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../../core/services/workout_session_wake_lock_coordinator.dart';
import '../../data/repositories/b02_exercise_performance_read_repository.dart';
import '../../data/repositories/b02_previous_performance_repository.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/b07_exercise_context_repository.dart';
import '../../data/repositories/travel_repository.dart';
import '../../data/repositories/workout_execution_compatibility_adapter.dart';
import '../../data/repositories/workout_repository.dart';
import '../media/b05_exercise_visual_registry.dart';
import '../training/training_providers.dart';

/// One app-scoped owner for the active workout's screen-awake intent. It is
/// intentionally not auto-disposed with an individual player route.
final workoutSessionWakeLockCoordinatorProvider =
    Provider<WorkoutSessionWakeLockCoordinator>((ref) {
      final coordinator = WorkoutSessionWakeLockCoordinator();
      coordinator.attachToAppLifecycle();
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

/// The existing R08-0 exact-UUID visual registry, loaded through the packaged
/// manifest boundary. Missing local/private RepDB files are expected: the
/// registry remains useful for exact binding, while [ExerciseVisual] falls
/// through to the canonical muscle map or semantic icon.
final b05ExerciseVisualRegistryProvider =
    FutureProvider<B05ExerciseVisualRegistry>((ref) async {
      try {
        return await B05AssetBundleExerciseVisualRegistrySource(
          bundle: rootBundle,
        ).load();
      } catch (_) {
        return const B05ExerciseVisualRegistry.empty();
      }
    });

final b07ExerciseContextRepositoryProvider =
    Provider<B07ExerciseContextRepository>(
      (ref) => B07ExerciseContextRepository(ref.watch(databaseProvider)),
    );

/// Exact actual-exercise context keyed by the canonical performed UUID.
/// Riverpod's family key also prevents a late A lookup from painting over a
/// replacement B lookup.
final b07ExerciseContextProvider =
    FutureProvider.family<B07ExerciseContextResult, String>((ref, id) {
      return ref.watch(b07ExerciseContextRepositoryProvider).resolve(id);
    });

final workoutExecutionCompatibilityAdapterProvider =
    Provider<WorkoutExecutionCompatibilityAdapter>((ref) {
      return WorkoutExecutionCompatibilityAdapter(
        db: ref.watch(databaseProvider),
        calendarRepo: ref.watch(calendarRepositoryProvider),
        workoutRepo: ref.watch(workoutRepositoryProvider),
        preferenceRepo: ref.watch(exercisePreferenceRepositoryProvider),
        travelRepo: ref.watch(travelRepositoryProvider),
      );
    });

final strengthExecutionRepositoryProvider =
    Provider<StrengthExecutionRepository>(
      (ref) => StrengthExecutionRepository(
        db: ref.watch(databaseProvider),
        calendarRepo: ref.watch(calendarRepositoryProvider),
      ),
    );

final b02ExercisePerformanceReadRepositoryProvider =
    Provider<B02ExercisePerformanceReadRepository>(
      (ref) =>
          B02ExercisePerformanceReadRepository(ref.watch(databaseProvider)),
    );

/// UI-independent B.3 boundary. B.2 can consume factual previous evidence
/// without importing a player widget or the progression recommendation rule.
final b02PreviousPerformanceRepositoryProvider =
    Provider<B02PreviousPerformanceRepository>(
      (ref) => B02PreviousPerformanceRepository(ref.watch(databaseProvider)),
    );

final strengthExecutionCompatibilityAdapterProvider =
    Provider<StrengthExecutionCompatibilityAdapter>(
      (ref) => StrengthExecutionCompatibilityAdapter(
        ref.watch(strengthExecutionRepositoryProvider),
      ),
    );

final travelRepositoryProvider = Provider<TravelRepository>((ref) {
  return TravelRepository(
    db: ref.watch(databaseProvider),
    calendarRepo: ref.watch(calendarRepositoryProvider),
    equipmentRepo: ref.watch(equipmentProfileRepositoryProvider),
  );
});
