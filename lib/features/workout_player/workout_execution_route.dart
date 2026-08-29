import '../../data/repositories/b02_strength_execution_repository.dart';
import 'workout_execution_context.dart';

/// Typed payload used by the shared execution and review routes.
///
/// Existing map/launch extras are accepted only by the route compatibility
/// parser while older deep links drain away. New callers pass this object
/// directly so route identity cannot be lost to untyped string keys.
class WorkoutExecutionRouteData {
  final WorkoutExecutionContext execution;

  const WorkoutExecutionRouteData(this.execution);

  /// Alias that makes the route boundary read naturally at call sites while
  /// keeping [execution] as the stable serialized-field name.
  WorkoutExecutionContext get context => execution;

  factory WorkoutExecutionRouteData.fromLaunch(
    B02StrengthExecutionLaunch launch,
  ) => WorkoutExecutionRouteData(WorkoutExecutionContext.fromLaunch(launch));
}

WorkoutExecutionRouteData? workoutExecutionRouteDataFromExtra(Object? extra) {
  if (extra is WorkoutExecutionRouteData) return extra;
  try {
    if (extra is B02StrengthExecutionLaunch) {
      return WorkoutExecutionRouteData.fromLaunch(extra);
    }
    // Compatibility for retained links and older callers. This branch is a
    // one-way adapter; the shared player never reads a map or infers a mode.
    if (extra is Map) {
      final launch = extra['launch'];
      if (launch is B02StrengthExecutionLaunch) {
        return WorkoutExecutionRouteData.fromLaunch(launch);
      }
    }
  } on ArgumentError {
    return null;
  }
  return null;
}
