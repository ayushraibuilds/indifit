import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/confetti_overlay.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';
import 'player_setup_cues_panel.dart';
import 'widgets/exercise_set_input_card.dart';
import 'widgets/prior_session_card.dart';
import 'widgets/rest_timer_bottom_sheet.dart';
import 'widgets/workout_player_header.dart';
import 'workout_player_controller.dart';

class WorkoutPlayerScreen extends ConsumerStatefulWidget {
  final String routineName;
  final List<RoutineExercise> exercises;
  final int initialExerciseIndex;
  final int initialSetIndex;
  final int initialElapsedSeconds;
  final List<WorkoutSetsCompanion>? initialLoggedSets;
  final String? scheduledOccurrenceId;
  final String? executionSnapshotJson;
  final Map<String, Map<String, dynamic>> personalExerciseContextByName;

  const WorkoutPlayerScreen({
    super.key,
    required this.routineName,
    required this.exercises,
    this.initialExerciseIndex = 0,
    this.initialSetIndex = 0,
    this.initialElapsedSeconds = 0,
    this.initialLoggedSets,
    this.scheduledOccurrenceId,
    this.executionSnapshotJson,
    this.personalExerciseContextByName = const {},
  });

  @override
  ConsumerState<WorkoutPlayerScreen> createState() =>
      _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends ConsumerState<WorkoutPlayerScreen>
    with WidgetsBindingObserver {
  late StateNotifierProvider<WorkoutPlayerController, WorkoutPlayerState>
  _controllerProvider;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _inclineController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controllerProvider =
        StateNotifierProvider<WorkoutPlayerController, WorkoutPlayerState>((
          ref,
        ) {
          return WorkoutPlayerController(
            ref,
            routineName: widget.routineName,
            initialExercises: widget.exercises,
            initialExerciseIndex: widget.initialExerciseIndex,
            initialSetIndex: widget.initialSetIndex,
            initialElapsedSeconds: widget.initialElapsedSeconds,
            initialLoggedSets: widget.initialLoggedSets,
            scheduledOccurrenceId: widget.scheduledOccurrenceId,
            executionSnapshotJson: widget.executionSnapshotJson,
          );
        });

    ref.read(_controllerProvider.notifier).prefillInputs().then((_) {
      _syncInputsWithState();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(_controllerProvider.notifier).syncElapsedOnResume();
      unawaited(ref.read(_controllerProvider.notifier).reconcileWakeLock());
    }
  }

  void _syncInputsWithState() {
    final state = ref.read(_controllerProvider);
    if (state.activeExercises.isEmpty) return;

    final currentEx = state.activeExercises[state.currentExerciseIndex];
    double weight = state.suggestedWeight;
    int reps = 10;

    if (state.priorSets.isNotEmpty) {
      final setIndex = state.currentSetIndex.clamp(
        0,
        state.priorSets.length - 1,
      );
      final lastSet = state.priorSets[setIndex];
      weight = lastSet.weight;
      reps = lastSet.reps;
    } else {
      final repsStr = currentEx.repsRange;
      if (repsStr.contains('-')) {
        final parts = repsStr.split('-');
        final min = int.tryParse(parts[0]) ?? 8;
        final max = int.tryParse(parts[1]) ?? 12;
        reps = ((min + max) / 2).round();
      } else {
        reps = int.tryParse(repsStr) ?? 10;
      }
    }

    _weightController.text = weight.toStringAsFixed(1);
    _repsController.text = reps.toString();
    _durationController.clear();
    _distanceController.clear();
    _inclineController.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _weightController.dispose();
    _repsController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _inclineController.dispose();
    super.dispose();
  }

  Future<void> _completeSet() async {
    final controller = ref.read(_controllerProvider.notifier);
    final state = ref.read(_controllerProvider);
    final currentEx = state.activeExercises[state.currentExerciseIndex];

    final double weight = double.tryParse(_weightController.text) ?? 0.0;
    final int reps = int.tryParse(_repsController.text) ?? 0;

    final isCardio = controller.currentExerciseCompatibilityMetadata.isCardio;

    if (!isCardio && (weight <= 0 || reps <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight and reps.')),
      );
      return;
    }

    final int? duration = int.tryParse(_durationController.text);
    final double? distance = double.tryParse(_distanceController.text);
    final double? incline = double.tryParse(_inclineController.text);

    await controller.recordSet(
      weight: weight,
      reps: reps,
      durationSeconds: duration,
      distanceKm: distance,
      inclinePercentage: incline,
    );

    await HapticFeedback.mediumImpact();

    final recommendedRest =
        controller.currentExerciseCompatibilityMetadata.recommendedRestSeconds;
    if (mounted) {
      final updatedState = ref.read(_controllerProvider);
      if (updatedState.showPrConfetti) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      if (mounted) {
        await RestTimerBottomSheet.show(context, recommendedRest);
      }
    }

    final totalSetsRequired = currentEx.sets;
    if (state.currentSetIndex < totalSetsRequired - 1 ||
        state.currentExerciseIndex < state.activeExercises.length - 1) {
      await controller.advanceSetOrExercise();
      _syncInputsWithState();
    } else {
      await controller.finishWorkout();
      if (mounted) {
        final finalState = ref.read(_controllerProvider);
        context.pushReplacement(
          '/workout-summary',
          extra: {
            'routineName': widget.routineName,
            'elapsedSeconds': finalState.elapsedSeconds,
            'loggedSets': finalState.loggedSets,
            'scheduledOccurrenceId': widget.scheduledOccurrenceId,
            'completionCommandId': widget.scheduledOccurrenceId == null
                ? null
                : const Uuid().v4(),
          },
        );
      }
    }
  }

  void _showExerciseHistorySheet(String exerciseName) {
    showIndiFitBottomSheet(
      context: context,
      semanticLabel: '$exerciseName history',
      builder: (context) {
        final colors = context.b05Colors;
        final repo = ref.read(workoutRepositoryProvider);
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: repo.getExerciseHistory(exerciseName),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Semantics(
                  liveRegion: true,
                  label: 'Loading exercise history',
                  child: CircularProgressIndicator(color: colors.action),
                ),
              );
            }
            final history = snapshot.data ?? [];
            return Padding(
              padding: const EdgeInsets.all(B05Layout.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$exerciseName History',
                          style: B05Typography.title(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.insights_rounded, color: colors.action),
                    ],
                  ),
                  const SizedBox(height: B05Layout.space8),
                  Text(
                    'Review recent sets, personal records and estimated strength.',
                    style: B05Typography.caption(context),
                  ),
                  Divider(color: colors.border, height: B05Layout.space24),
                  Expanded(
                    child: history.isEmpty
                        ? Center(
                            child: Text(
                              'No past sets for this exercise yet.',
                              style: B05Typography.body(context),
                            ),
                          )
                        : ListView.builder(
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final item = history[index];
                              final session = item['session'] as WorkoutSession;
                              final sets = item['sets'] as List<WorkoutSet>;

                              final dateStr = MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(session.completedAt.toLocal());

                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: B05Layout.space12,
                                ),
                                child: B05Surface(
                                  tone: B05SurfaceTone.inset,
                                  radius: B05SurfaceRadius.small,
                                  padding: const EdgeInsets.all(
                                    B05Layout.space12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Session on $dateStr: ${session.name}',
                                        style: B05Typography.caption(
                                          context,
                                        ).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: B05Layout.space8),
                                      ...sets.map((s) {
                                        final oneRm =
                                            s.weight * (1 + s.reps / 30.0);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4.0,
                                          ),
                                          child: Wrap(
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            runSpacing: B05Layout.space4,
                                            children: [
                                              Wrap(
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  if (s.isPr)
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        right: B05Layout.space4,
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .emoji_events_rounded,
                                                        color: colors
                                                            .warning
                                                            .indicator,
                                                        size:
                                                            B05Layout.iconSmall,
                                                      ),
                                                    ),
                                                  Text(
                                                    'Set ${s.setNumber}: ${s.weight.toStringAsFixed(1)} kg × ${s.reps} reps',
                                                    style:
                                                        B05Typography.caption(
                                                          context,
                                                        ).copyWith(
                                                          fontWeight: s.isPr
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                    .normal,
                                                        ),
                                                  ),
                                                  if (s.durationSeconds != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: B05Layout
                                                                .space8,
                                                          ),
                                                      child: Text(
                                                        '(${s.durationSeconds}s${s.distanceKm != null ? ", ${s.distanceKm}km" : ""})',
                                                        style:
                                                            B05Typography.caption(
                                                              context,
                                                            ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              Text(
                                                '1RM: ${oneRm.toStringAsFixed(1)} kg',
                                                style:
                                                    B05Typography.caption(
                                                      context,
                                                    ).copyWith(
                                                      color: colors.action,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _substituteExercise() async {
    final repo = ref.read(workoutRepositoryProvider);
    final selectedExerciseName = await showIndiFitBottomSheet<String>(
      context: context,
      semanticLabel: 'Choose a replacement exercise',
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colors = context.b05Colors;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Choose a replacement',
                          style: B05Typography.title(context),
                        ),
                      ),
                      B05IconAction(
                        icon: Icons.close,
                        label: 'Close exercise choices',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search alternative exercise...',
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (val) => setModalState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<String>>(
                      future: repo
                          .searchExercises(searchQuery)
                          .then((list) => list.map((e) => e.name).toList()),
                      builder: (context, snapshot) {
                        final list = snapshot.data ?? [];
                        return ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, idx) {
                            final name = list[idx];
                            return ListTile(
                              title: Text(name),
                              trailing: Icon(
                                Icons.swap_horiz_rounded,
                                color: colors.action,
                              ),
                              onTap: () => Navigator.pop(context, name),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selectedExerciseName != null && mounted) {
      await ref
          .read(_controllerProvider.notifier)
          .substituteExercise(selectedExerciseName);
      _syncInputsWithState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_controllerProvider);
    final controller = ref.read(_controllerProvider.notifier);
    final colors = context.b05Colors;

    if (state.activeExercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.routineName)),
        body: const Center(child: Text('No exercises found in routine.')),
      );
    }

    final currentEx = state.activeExercises[state.currentExerciseIndex];
    final currentExerciseContext =
        widget.personalExerciseContextByName[currentEx.exerciseName];
    final rawStableId = currentExerciseContext?['exerciseId'];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(B05Layout.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: B05IconAction(
                      icon: Icons.close,
                      label: 'Close workout',
                      hint: 'Leave this workout for now.',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  WorkoutPlayerHeader(
                    routineName: widget.routineName,
                    elapsedSeconds: state.elapsedSeconds,
                    exercises: state.activeExercises,
                    currentExerciseIndex: state.currentExerciseIndex,
                    onExerciseSelected: (idx) {
                      controller.selectExerciseIndex(idx);
                      _syncInputsWithState();
                    },
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxWidth < B05Layout.compactBreakpoint ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3;
                      final exerciseTitle = Row(
                        children: [
                          Expanded(
                            child: Text(
                              currentEx.exerciseName,
                              style: B05Typography.title(
                                context,
                              ).copyWith(fontSize: 22, letterSpacing: -0.3),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          B05IconAction(
                            icon: Icons.history_rounded,
                            label:
                                'View exercise history and estimated strength',
                            onPressed: () => _showExerciseHistorySheet(
                              currentEx.exerciseName,
                            ),
                          ),
                        ],
                      );
                      final substituteAction = TextButton.icon(
                        onPressed: _substituteExercise,
                        icon: const Icon(
                          Icons.swap_horiz_rounded,
                          size: B05Layout.iconSmall,
                        ),
                        label: const Text('Substitute'),
                      );
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            exerciseTitle,
                            Align(
                              alignment: Alignment.centerRight,
                              child: substituteAction,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: exerciseTitle),
                          substituteAction,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  PriorSessionCard(
                    priorSets: state.priorSets,
                    bestPrSet: state.bestPrSet,
                    suggestedWeight: state.suggestedWeight,
                  ),
                  const SizedBox(height: 12),
                  PlayerSetupCuesPanel(
                    exerciseName: currentEx.exerciseName,
                    stableId: rawStableId is String ? rawStableId : null,
                    frozenContext: currentExerciseContext,
                  ),
                  const SizedBox(height: 12),
                  ExerciseSetInputCard(
                    currentExercise: currentEx,
                    currentSetIndex: state.currentSetIndex,
                    weightController: _weightController,
                    repsController: _repsController,
                    durationController: _durationController,
                    distanceController: _distanceController,
                    inclineController: _inclineController,
                    executionMetadata:
                        controller.currentExerciseCompatibilityMetadata,
                    isWarmUp: state.isWarmUp,
                    selectedSetType: state.selectedSetType,
                    selectedRpe: state.selectedRpe,
                    onWarmUpChanged: (val) => controller.toggleWarmUp(val),
                    onSetTypeChanged: (val) =>
                        controller.setSelectedSetType(val),
                    onRpeChanged: (val) => controller.setSelectedRpe(val),
                    onCompleteSet: _completeSet,
                  ),
                  const SizedBox(height: 12),

                  // Completed set chips & set navigation bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (state.currentSetIndex > 0 ||
                          state.currentExerciseIndex > 0)
                        TextButton.icon(
                          onPressed: () {
                            controller.goToPreviousSet();
                            _syncInputsWithState();
                          },
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Prev Set'),
                        )
                      else
                        const SizedBox.shrink(),

                      Text(
                        'Set ${state.currentSetIndex + 1} of ${currentEx.sets}',
                        style: B05Typography.caption(context).copyWith(
                          color: colors.action,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Horizontal list of set chips for current exercise
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: currentEx.sets,
                      itemBuilder: (context, idx) {
                        final isSelected = idx == state.currentSetIndex;
                        final loggedForEx = state.loggedSets
                            .where(
                              (s) =>
                                  s.exerciseName.value ==
                                  currentEx.exerciseName,
                            )
                            .toList();
                        final isCompleted = idx < loggedForEx.length;
                        final loggedSet = isCompleted ? loggedForEx[idx] : null;

                        String chipLabel = 'Set ${idx + 1}';
                        if (isCompleted && loggedSet != null) {
                          chipLabel =
                              '${idx + 1}: ${loggedSet.weight.value.toStringAsFixed(1)}k×${loggedSet.reps.value}';
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(chipLabel),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                controller.selectSetIndex(idx);
                                _syncInputsWithState();
                              }
                            },
                            avatar: isCompleted
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    size: B05Layout.iconSmall,
                                    color: colors.success.indicator,
                                  )
                                : null,
                            selectedColor: colors.selected,
                            backgroundColor: colors.inset,
                            labelStyle: B05Typography.caption(context).copyWith(
                              color: isSelected
                                  ? colors.action
                                  : colors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: B05Radii.smallRadius,
                              side: BorderSide(
                                color: isSelected
                                    ? colors.action
                                    : (isCompleted
                                          ? colors.success.indicator.withValues(
                                              alpha: 0.5,
                                            )
                                          : Colors.transparent),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () async {
                      await controller.finishWorkout();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.danger.indicator),
                      foregroundColor: colors.danger.indicator,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Finish Workout Early',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            if (state.showPrConfetti)
              ConfettiOverlay(
                isPlaying: true,
                child: Container(
                  color: colors.selected.withValues(alpha: 0.92),
                  child: Center(
                    child: B05Surface(
                      radius: B05SurfaceRadius.large,
                      padding: const EdgeInsets.all(B05Layout.space24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('👑', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: B05Layout.space8),
                          Text(
                            'NEW PERSONAL RECORD!',
                            style: B05Typography.title(
                              context,
                            ).copyWith(color: colors.action),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${state.prExerciseName}: ${state.prWeight.toStringAsFixed(1)} kg x ${state.prReps} reps',
                            style: B05Typography.caption(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
