import '../../data/repositories/b02_strength_execution_repository.dart';

/// Typed presentation context for the shared workout execution experience.
///
/// This is deliberately a view boundary over the canonical B02 launch. It
/// carries no mutable execution state and performs no persistence. The launch
/// remains the source of the draft, frozen snapshot, and lifecycle identity.
sealed class WorkoutExecutionContext {
  const WorkoutExecutionContext._({required this.launch});

  final B02StrengthExecutionLaunch launch;

  String get workoutTitle => launch.state.routineName;
  int get draftId => launch.draftId;
  String get snapshotId => launch.state.snapshotId;
  String get modeLabel;
  String? get scheduledOccurrenceId;

  /// Rebinds the presentation context to the latest canonical launch after a
  /// set, rest, or lifecycle mutation without changing its origin.
  WorkoutExecutionContext rebind(B02StrengthExecutionLaunch next) {
    if (next.draftId != draftId ||
        next.state.snapshotId != snapshotId ||
        next.executionSnapshotJson != launch.executionSnapshotJson) {
      throw ArgumentError.value(
        next,
        'next',
        'The launch must belong to the same saved workout and frozen snapshot.',
      );
    }
    return switch (this) {
      PlannedWorkoutExecutionContext(:final occurrenceId) =>
        PlannedWorkoutExecutionContext(
          launch: next,
          occurrenceId: occurrenceId,
        ),
      QuickWorkoutExecutionContext() => QuickWorkoutExecutionContext(
        launch: next,
      ),
    };
  }

  factory WorkoutExecutionContext.fromLaunch(
    B02StrengthExecutionLaunch launch,
  ) {
    final occurrenceId = launch.occurrenceId;
    if (occurrenceId != null) {
      if (occurrenceId.trim().isEmpty) {
        throw ArgumentError.value(
          occurrenceId,
          'launch.occurrenceId',
          'A scheduled occurrence ID must not be blank.',
        );
      }
      return PlannedWorkoutExecutionContext(
        launch: launch,
        occurrenceId: occurrenceId,
      );
    }
    return QuickWorkoutExecutionContext(launch: launch);
  }
}

/// A scheduled/program workout. The occurrence ID is retained exactly as the
/// canonical ancestry key; it is never flattened into a Quick Workout.
final class PlannedWorkoutExecutionContext extends WorkoutExecutionContext {
  factory PlannedWorkoutExecutionContext({
    required B02StrengthExecutionLaunch launch,
    required String occurrenceId,
  }) {
    if (occurrenceId.trim().isEmpty || launch.occurrenceId != occurrenceId) {
      throw ArgumentError.value(
        occurrenceId,
        'occurrenceId',
        'The context must match the launch scheduled occurrence.',
      );
    }
    return PlannedWorkoutExecutionContext._(
      launch: launch,
      occurrenceId: occurrenceId,
    );
  }

  const PlannedWorkoutExecutionContext._({
    required super.launch,
    required this.occurrenceId,
  }) : super._();

  final String occurrenceId;

  @override
  String get modeLabel => 'Planned workout';

  @override
  String get scheduledOccurrenceId => occurrenceId;
}

/// A standalone/ad-hoc workout. It intentionally has no scheduled
/// occurrence; its draft and completed session remain canonical B02 records.
final class QuickWorkoutExecutionContext extends WorkoutExecutionContext {
  factory QuickWorkoutExecutionContext({
    required B02StrengthExecutionLaunch launch,
  }) {
    if (launch.occurrenceId != null) {
      throw ArgumentError.value(
        launch.occurrenceId,
        'launch.occurrenceId',
        'A Quick workout cannot have a scheduled occurrence.',
      );
    }
    return QuickWorkoutExecutionContext._(launch: launch);
  }

  const QuickWorkoutExecutionContext._({required super.launch}) : super._();

  @override
  String get modeLabel => 'Quick workout';

  @override
  String? get scheduledOccurrenceId => null;
}
