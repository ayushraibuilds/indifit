import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/workout_draft_codec.dart';
import '../../core/services/workout_session_wake_lock_coordinator.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/legacy_workout_compatibility_adapter.dart';
import '../../data/repositories/workout_repository.dart';

class WorkoutPlayerState {
  final int currentExerciseIndex;
  final int currentSetIndex;
  final int elapsedSeconds;
  final List<WorkoutSetsCompanion> loggedSets;
  final List<RoutineExercise> activeExercises;
  final List<WorkoutSet> priorSets;
  final double suggestedWeight;
  final bool isWarmUp;
  final String selectedSetType;
  final int? selectedRpe;

  const WorkoutPlayerState({
    this.currentExerciseIndex = 0,
    this.currentSetIndex = 0,
    this.elapsedSeconds = 0,
    this.loggedSets = const [],
    this.activeExercises = const [],
    this.priorSets = const [],
    this.suggestedWeight = 20.0,
    this.isWarmUp = false,
    this.selectedSetType = 'working',
    this.selectedRpe,
  });

  WorkoutPlayerState copyWith({
    int? currentExerciseIndex,
    int? currentSetIndex,
    int? elapsedSeconds,
    List<WorkoutSetsCompanion>? loggedSets,
    List<RoutineExercise>? activeExercises,
    List<WorkoutSet>? priorSets,
    double? suggestedWeight,
    bool? isWarmUp,
    String? selectedSetType,
    int? selectedRpe,
  }) {
    return WorkoutPlayerState(
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      currentSetIndex: currentSetIndex ?? this.currentSetIndex,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      loggedSets: loggedSets ?? this.loggedSets,
      activeExercises: activeExercises ?? this.activeExercises,
      priorSets: priorSets ?? this.priorSets,
      suggestedWeight: suggestedWeight ?? this.suggestedWeight,
      isWarmUp: isWarmUp ?? this.isWarmUp,
      selectedSetType: selectedSetType ?? this.selectedSetType,
      selectedRpe: selectedRpe,
    );
  }
}

class WorkoutPlayerController extends StateNotifier<WorkoutPlayerState> {
  final Ref _ref;
  final String routineName;
  final String? scheduledOccurrenceId;
  final String? executionSnapshotJson;
  final LegacyWorkoutCompatibilityAdapter _legacyCompatibility;
  final WorkoutSessionWakeLockCoordinator _wakeLockCoordinator;
  Timer? _timer;

  WorkoutPlayerController(
    this._ref, {
    required this.routineName,
    required List<RoutineExercise> initialExercises,
    int initialExerciseIndex = 0,
    int initialSetIndex = 0,
    int initialElapsedSeconds = 0,
    List<WorkoutSetsCompanion>? initialLoggedSets,
    this.scheduledOccurrenceId,
    this.executionSnapshotJson,
    LegacyWorkoutCompatibilityAdapter? legacyCompatibility,
  }) : _legacyCompatibility =
           legacyCompatibility ?? const LegacyWorkoutCompatibilityAdapter(),
       _wakeLockCoordinator = _ref.read(
         workoutSessionWakeLockCoordinatorProvider,
       ),
       super(
         WorkoutPlayerState(
           activeExercises: initialExercises,
           currentExerciseIndex: initialExerciseIndex,
           currentSetIndex: initialSetIndex,
           elapsedSeconds: initialElapsedSeconds,
           loggedSets: initialLoggedSets ?? [],
         ),
       ) {
    _wakeLockCoordinator.attachToAppLifecycle();
    unawaited(
      _wakeLockCoordinator.setActiveSession(
        legacyWorkoutSessionWakeLockKey(scheduledOccurrenceId),
      ),
    );
    _startTimer();
    prefillInputs();
  }

  DateTime? _sessionStartedAt;
  int _baseElapsedSeconds = 0;

  void _startTimer() {
    _baseElapsedSeconds = state.elapsedSeconds;
    _sessionStartedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sessionStartedAt != null) {
        final diff = DateTime.now().difference(_sessionStartedAt!).inSeconds;
        state = state.copyWith(elapsedSeconds: _baseElapsedSeconds + diff);
      }
    });
  }

  void syncElapsedOnResume() {
    if (_sessionStartedAt != null) {
      final diff = DateTime.now().difference(_sessionStartedAt!).inSeconds;
      state = state.copyWith(elapsedSeconds: _baseElapsedSeconds + diff);
    }
  }

  Future<void> reconcileWakeLock() =>
      _wakeLockCoordinator.reconcileForActiveSession(
        legacyWorkoutSessionWakeLockKey(scheduledOccurrenceId),
      );

  Future<void> releaseWakeLock() => _wakeLockCoordinator.clearActiveSession(
    legacyWorkoutSessionWakeLockKey(scheduledOccurrenceId),
  );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> prefillInputs() async {
    if (state.activeExercises.isEmpty) return;

    final currentEx = state.activeExercises[state.currentExerciseIndex];
    final repo = _ref.read(workoutRepositoryProvider);

    final latestSets = await repo.getLatestSetsForExercise(
      currentEx.exerciseName,
    );

    double suggested = 20.0;
    if (latestSets.isNotEmpty) {
      final setIndex = state.currentSetIndex.clamp(0, latestSets.length - 1);
      final lastSet = latestSets[setIndex];

      int targetRepMax = 10;
      final repsStr = currentEx.repsRange;
      if (repsStr.contains('-')) {
        final parts = repsStr.split('-');
        targetRepMax = int.tryParse(parts[1]) ?? 12;
      } else {
        targetRepMax = int.tryParse(repsStr) ?? 10;
      }

      if (lastSet.reps >= targetRepMax) {
        suggested = lastSet.weight + 2.5;
      } else {
        suggested = lastSet.weight;
      }
    }

    state = state.copyWith(priorSets: latestSets, suggestedWeight: suggested);
  }

  /// The retained B01 player has no typed modality field. Its compatibility
  /// policy is intentionally exposed through the controller so the widget
  /// never performs display-name classification itself.
  LegacyExerciseExecutionMetadata get currentExerciseCompatibilityMetadata {
    if (state.activeExercises.isEmpty) {
      return const LegacyExerciseExecutionMetadata(
        isCardio: false,
        recommendedRestSeconds: 90,
        formCue:
            'Form: Perform with strict form. Keep core braced, breathe out on exertion, and control the negative phase.',
      );
    }
    return _legacyCompatibility.metadataFor(
      state.activeExercises[state.currentExerciseIndex].exerciseName,
    );
  }

  void toggleWarmUp(bool val) {
    state = state.copyWith(
      isWarmUp: val,
      selectedSetType: val ? 'warmup' : 'working',
    );
  }

  void setSelectedSetType(String setType) {
    state = state.copyWith(
      selectedSetType: setType,
      isWarmUp: setType == 'warmup',
    );
  }

  void setSelectedRpe(int? rpe) {
    state = state.copyWith(selectedRpe: rpe);
  }

  void selectExerciseIndex(int index) {
    if (index >= 0 && index < state.activeExercises.length) {
      state = state.copyWith(currentExerciseIndex: index, currentSetIndex: 0);
      prefillInputs();
    }
  }

  Future<void> recordSet({
    required double weight,
    required int reps,
    int? durationSeconds,
    double? distanceKm,
    double? inclinePercentage,
  }) async {
    final currentEx = state.activeExercises[state.currentExerciseIndex];

    final newSet = WorkoutSetsCompanion.insert(
      sessionId: 0,
      exerciseName: currentEx.exerciseName,
      weight: weight,
      reps: reps,
      setNumber: state.currentSetIndex + 1,
      // Retain the legacy field for draft/backup compatibility, but do not
      // manufacture PR truth without a canonical PR-event authority.
      isPr: const Value(false),
      isWarmUp: Value(state.isWarmUp),
      rpe: Value(state.selectedRpe),
      setType: Value(state.selectedSetType),
      durationSeconds: Value(durationSeconds),
      distanceKm: Value(distanceKm),
      inclinePercentage: Value(inclinePercentage),
    );

    final updatedLoggedSets = [...state.loggedSets, newSet];
    state = state.copyWith(loggedSets: updatedLoggedSets);

    await saveDraft();
  }

  Future<void> advanceSetOrExercise() async {
    final currentEx = state.activeExercises[state.currentExerciseIndex];
    final totalSetsRequired = currentEx.sets;

    if (state.currentSetIndex < totalSetsRequired - 1) {
      state = state.copyWith(currentSetIndex: state.currentSetIndex + 1);
      await prefillInputs();
    } else {
      if (state.currentExerciseIndex < state.activeExercises.length - 1) {
        state = state.copyWith(
          currentExerciseIndex: state.currentExerciseIndex + 1,
          currentSetIndex: 0,
        );
        await prefillInputs();
      }
    }
  }

  void goToPreviousSet() {
    if (state.currentSetIndex > 0) {
      state = state.copyWith(currentSetIndex: state.currentSetIndex - 1);
      prefillInputs();
    } else if (state.currentExerciseIndex > 0) {
      final prevExIndex = state.currentExerciseIndex - 1;
      final prevEx = state.activeExercises[prevExIndex];
      state = state.copyWith(
        currentExerciseIndex: prevExIndex,
        currentSetIndex: prevEx.sets - 1,
      );
      prefillInputs();
    }
  }

  void selectSetIndex(int setIndex) {
    final currentEx = state.activeExercises[state.currentExerciseIndex];
    if (setIndex >= 0 && setIndex < currentEx.sets) {
      state = state.copyWith(currentSetIndex: setIndex);
      prefillInputs();
    }
  }

  Future<void> substituteExercise(String newExerciseName) async {
    final currentEx = state.activeExercises[state.currentExerciseIndex];
    final updatedEx = RoutineExercise(
      id: currentEx.id,
      dayId: currentEx.dayId,
      exerciseName: newExerciseName,
      sets: currentEx.sets,
      repsRange: currentEx.repsRange,
      orderIndex: currentEx.orderIndex,
    );

    final newActive = [...state.activeExercises];
    newActive[state.currentExerciseIndex] = updatedEx;
    state = state.copyWith(activeExercises: newActive);
    await prefillInputs();
  }

  Future<void> saveDraft() async {
    final repo = _ref.read(workoutRepositoryProvider);
    final jsonStr = WorkoutDraftCodec.encode(
      routineName: routineName,
      currentExerciseIndex: state.currentExerciseIndex,
      currentSetIndex: state.currentSetIndex,
      elapsedSeconds: state.elapsedSeconds,
      loggedSets: state.loggedSets,
    );

    await repo.saveWorkoutDraft(
      WorkoutDraftsCompanion.insert(
        routineName: routineName,
        currentExerciseIndex: state.currentExerciseIndex,
        currentSetIndex: state.currentSetIndex,
        elapsedSeconds: state.elapsedSeconds,
        loggedSetsJson: jsonStr,
        scheduledOccurrenceId: Value(scheduledOccurrenceId),
        executionSnapshotJson: Value(executionSnapshotJson),
      ),
    );
  }

  /// Cancels the active player timer when transitioning to summary screen.
  /// Note: The active draft remains preserved in the database until the session is durably saved.
  Future<void> finishWorkout() async {
    _timer?.cancel();
  }

  /// Explicit user action to discard the workout draft.
  Future<void> discardDraft() async {
    _timer?.cancel();
    if (scheduledOccurrenceId case final occurrenceId?) {
      await _ref
          .read(workoutExecutionCompatibilityAdapterProvider)
          .discardScheduledOccurrenceDraft(
            occurrenceId: occurrenceId,
            commandId: const Uuid().v4(),
          );
      await releaseWakeLock();
      return;
    }
    final repo = _ref.read(workoutRepositoryProvider);
    await repo.deleteActiveDraft();
    await releaseWakeLock();
  }
}
