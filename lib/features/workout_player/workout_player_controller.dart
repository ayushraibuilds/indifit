import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:drift/drift.dart' show Value;

import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';

class WorkoutPlayerState {
  final int currentExerciseIndex;
  final int currentSetIndex;
  final int elapsedSeconds;
  final List<WorkoutSetsCompanion> loggedSets;
  final List<RoutineExercise> activeExercises;
  final List<WorkoutSet> priorSets;
  final WorkoutSet? bestPrSet;
  final double suggestedWeight;
  final bool isWarmUp;
  final String selectedSetType;
  final int? selectedRpe;
  final bool showPrConfetti;
  final String prExerciseName;
  final double prWeight;
  final int prReps;

  const WorkoutPlayerState({
    this.currentExerciseIndex = 0,
    this.currentSetIndex = 0,
    this.elapsedSeconds = 0,
    this.loggedSets = const [],
    this.activeExercises = const [],
    this.priorSets = const [],
    this.bestPrSet,
    this.suggestedWeight = 20.0,
    this.isWarmUp = false,
    this.selectedSetType = 'working',
    this.selectedRpe,
    this.showPrConfetti = false,
    this.prExerciseName = '',
    this.prWeight = 0.0,
    this.prReps = 0,
  });

  WorkoutPlayerState copyWith({
    int? currentExerciseIndex,
    int? currentSetIndex,
    int? elapsedSeconds,
    List<WorkoutSetsCompanion>? loggedSets,
    List<RoutineExercise>? activeExercises,
    List<WorkoutSet>? priorSets,
    WorkoutSet? bestPrSet,
    double? suggestedWeight,
    bool? isWarmUp,
    String? selectedSetType,
    int? selectedRpe,
    bool? showPrConfetti,
    String? prExerciseName,
    double? prWeight,
    int? prReps,
  }) {
    return WorkoutPlayerState(
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      currentSetIndex: currentSetIndex ?? this.currentSetIndex,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      loggedSets: loggedSets ?? this.loggedSets,
      activeExercises: activeExercises ?? this.activeExercises,
      priorSets: priorSets ?? this.priorSets,
      bestPrSet: bestPrSet ?? this.bestPrSet,
      suggestedWeight: suggestedWeight ?? this.suggestedWeight,
      isWarmUp: isWarmUp ?? this.isWarmUp,
      selectedSetType: selectedSetType ?? this.selectedSetType,
      selectedRpe: selectedRpe,
      showPrConfetti: showPrConfetti ?? this.showPrConfetti,
      prExerciseName: prExerciseName ?? this.prExerciseName,
      prWeight: prWeight ?? this.prWeight,
      prReps: prReps ?? this.prReps,
    );
  }
}

class WorkoutPlayerController extends StateNotifier<WorkoutPlayerState> {
  final Ref _ref;
  final String routineName;
  Timer? _timer;

  WorkoutPlayerController(
    this._ref, {
    required this.routineName,
    required List<RoutineExercise> initialExercises,
    int initialExerciseIndex = 0,
    int initialSetIndex = 0,
    int initialElapsedSeconds = 0,
    List<WorkoutSetsCompanion>? initialLoggedSets,
  }) : super(WorkoutPlayerState(
          activeExercises: initialExercises,
          currentExerciseIndex: initialExerciseIndex,
          currentSetIndex: initialSetIndex,
          elapsedSeconds: initialElapsedSeconds,
          loggedSets: initialLoggedSets ?? [],
        )) {
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> prefillInputs() async {
    if (state.activeExercises.isEmpty) return;

    final currentEx = state.activeExercises[state.currentExerciseIndex];
    final repo = _ref.read(workoutRepositoryProvider);

    final latestSets = await repo.getLatestSetsForExercise(currentEx.exerciseName);
    final prSet = await repo.getPersonalRecord(currentEx.exerciseName);

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

    state = state.copyWith(
      priorSets: latestSets,
      bestPrSet: prSet,
      suggestedWeight: suggested,
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

  Future<bool> recordSet({
    required double weight,
    required int reps,
    int? durationSeconds,
    double? distanceKm,
    double? inclinePercentage,
  }) async {
    final currentEx = state.activeExercises[state.currentExerciseIndex];
    final repo = _ref.read(workoutRepositoryProvider);
    final previousPr = await repo.getPersonalRecord(currentEx.exerciseName);

    bool isPr = false;
    final current1Rm = weight * (1 + reps / 30.0);

    if (previousPr != null) {
      final prev1Rm = previousPr.weight * (1 + previousPr.reps / 30.0);
      if (current1Rm > prev1Rm) {
        isPr = true;
        triggerPrConfetti(currentEx.exerciseName, weight, reps);
      }
    } else {
      isPr = true;
      triggerPrConfetti(currentEx.exerciseName, weight, reps);
    }

    final newSet = WorkoutSetsCompanion.insert(
      sessionId: 0,
      exerciseName: currentEx.exerciseName,
      weight: weight,
      reps: reps,
      setNumber: state.currentSetIndex + 1,
      isPr: Value(isPr),
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
    return isPr;
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

  void triggerPrConfetti(String exerciseName, double weight, int reps) {
    state = state.copyWith(
      prExerciseName: exerciseName,
      prWeight: weight,
      prReps: reps,
      showPrConfetti: true,
    );

    Vibration.hasVibrator().then((hasVib) {
      if (hasVib == true) {
        Vibration.vibrate(pattern: [0, 100, 100, 200]);
      }
    });

    Future.delayed(const Duration(seconds: 3), () {
      state = state.copyWith(showPrConfetti: false);
    });
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
    final rawSets = state.loggedSets.map((s) => {
      'sessionId': s.sessionId.value,
      'exerciseName': s.exerciseName.value,
      'weight': s.weight.value,
      'reps': s.reps.value,
      'setNumber': s.setNumber.value,
      'isPr': s.isPr.value,
    }).toList();
    final jsonStr = jsonEncode(rawSets);

    await repo.saveWorkoutDraft(
      WorkoutDraftsCompanion.insert(
        routineName: routineName,
        currentExerciseIndex: state.currentExerciseIndex,
        currentSetIndex: state.currentSetIndex,
        elapsedSeconds: state.elapsedSeconds,
        loggedSetsJson: jsonStr,
      ),
    );
  }

  Future<void> finishWorkout() async {
    _timer?.cancel();
    final repo = _ref.read(workoutRepositoryProvider);
    await repo.deleteActiveDraft();
  }
}
