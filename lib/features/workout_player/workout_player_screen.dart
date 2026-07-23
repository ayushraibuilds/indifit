import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/widgets/confetti_overlay.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/workout_repository.dart';
import 'widgets/exercise_set_input_card.dart';
import 'widgets/prior_session_card.dart';
import 'widgets/rest_timer_bottom_sheet.dart';
import 'widgets/workout_player_header.dart';
import 'workout_player_controller.dart';
import 'workout_summary_screen.dart';

class WorkoutPlayerScreen extends ConsumerStatefulWidget {
  final String routineName;
  final List<RoutineExercise> exercises;
  final int initialExerciseIndex;
  final int initialSetIndex;
  final int initialElapsedSeconds;
  final List<WorkoutSetsCompanion>? initialLoggedSets;

  const WorkoutPlayerScreen({
    super.key,
    required this.routineName,
    required this.exercises,
    this.initialExerciseIndex = 0,
    this.initialSetIndex = 0,
    this.initialElapsedSeconds = 0,
    this.initialLoggedSets,
  });

  @override
  ConsumerState<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends ConsumerState<WorkoutPlayerScreen> {
  late StateNotifierProvider<WorkoutPlayerController, WorkoutPlayerState> _controllerProvider;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _inclineController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controllerProvider = StateNotifierProvider<WorkoutPlayerController, WorkoutPlayerState>((ref) {
      return WorkoutPlayerController(
        ref,
        routineName: widget.routineName,
        initialExercises: widget.exercises,
        initialExerciseIndex: widget.initialExerciseIndex,
        initialSetIndex: widget.initialSetIndex,
        initialElapsedSeconds: widget.initialElapsedSeconds,
        initialLoggedSets: widget.initialLoggedSets,
      );
    });

    ref.read(_controllerProvider.notifier).prefillInputs().then((_) {
      _syncInputsWithState();
    });
  }

  void _syncInputsWithState() {
    final state = ref.read(_controllerProvider);
    if (state.activeExercises.isEmpty) return;

    final currentEx = state.activeExercises[state.currentExerciseIndex];
    double weight = state.suggestedWeight;
    int reps = 10;

    if (state.priorSets.isNotEmpty) {
      final setIndex = state.currentSetIndex.clamp(0, state.priorSets.length - 1);
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

    final nameLower = currentEx.exerciseName.toLowerCase();
    final isCardio = nameLower.contains('run') ||
        nameLower.contains('treadmill') ||
        nameLower.contains('cardio') ||
        nameLower.contains('cycle') ||
        nameLower.contains('cycling') ||
        nameLower.contains('elliptical') ||
        nameLower.contains('walk') ||
        nameLower.contains('swim');

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

    final recommendedRest = _getRecommendedRestSeconds(currentEx.exerciseName);
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
    if (state.currentSetIndex < totalSetsRequired - 1 || state.currentExerciseIndex < state.activeExercises.length - 1) {
      await controller.advanceSetOrExercise();
      _syncInputsWithState();
    } else {
      await controller.finishWorkout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutSummaryScreen(
              routineName: widget.routineName,
              elapsedSeconds: state.elapsedSeconds,
              loggedSets: state.loggedSets,
            ),
          ),
        );
      }
    }
  }

  int _getRecommendedRestSeconds(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('squat') || name.contains('deadlift') || name.contains('bench press')) {
      return 120;
    } else if (name.contains('curl') || name.contains('tricep') || name.contains('lateral') || name.contains('raise')) {
      return 60;
    }
    return 90;
  }

  void _showExerciseHistorySheet(String exerciseName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final repo = ref.read(workoutRepositoryProvider);
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: repo.getExerciseHistory(exerciseName),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final history = snapshot.data ?? [];
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$exerciseName History',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.insights_rounded, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Track your estimated 1RM (Epley formula) and PR progression below.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const Divider(color: AppColors.border, height: 24),
                  Expanded(
                    child: history.isEmpty
                        ? const Center(
                            child: Text(
                              'No past logs for this exercise.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final item = history[index];
                              final session = item['session'] as WorkoutSession;
                              final sets = item['sets'] as List<WorkoutSet>;

                              final dateStr = '${session.completedAt.year}-${session.completedAt.month.toString().padLeft(2, '0')}-${session.completedAt.day.toString().padLeft(2, '0')}';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Session on $dateStr: ${session.name}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 8),
                                      ...sets.map((s) {
                                        final oneRm = s.weight * (1 + s.reps / 30.0);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  if (s.isPr)
                                                    const Padding(
                                                      padding: EdgeInsets.only(right: 6.0),
                                                      child: Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 16),
                                                    ),
                                                  Text(
                                                    'Set ${s.setNumber}: ${s.weight.toStringAsFixed(1)} kg × ${s.reps} reps',
                                                    style: TextStyle(fontWeight: s.isPr ? FontWeight.bold : FontWeight.normal, fontSize: 12),
                                                  ),
                                                  if (s.durationSeconds != null)
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 8.0),
                                                      child: Text(
                                                        '(${s.durationSeconds}s${s.distanceKm != null ? ", ${s.distanceKm}km" : ""})',
                                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              Text(
                                                '1RM: ${oneRm.toStringAsFixed(1)} kg',
                                                style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
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
    final selectedExerciseName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  const Text('Substitute Exercise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search alternative exercise...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setModalState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<String>>(
                      future: repo.searchExercises(searchQuery).then((list) => list.map((e) => e.name).toList()),
                      builder: (context, snapshot) {
                        final list = snapshot.data ?? [];
                        return ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, idx) {
                            final name = list[idx];
                            return ListTile(
                              title: Text(name),
                              trailing: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
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
      await ref.read(_controllerProvider.notifier).substituteExercise(selectedExerciseName);
      _syncInputsWithState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_controllerProvider);
    final controller = ref.read(_controllerProvider.notifier);

    if (state.activeExercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.routineName)),
        body: const Center(child: Text('No exercises found in routine.')),
      );
    }

    final currentEx = state.activeExercises[state.currentExerciseIndex];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentEx.exerciseName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
                              tooltip: 'Exercise History & 1RM',
                              onPressed: () => _showExerciseHistorySheet(currentEx.exerciseName),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _substituteExercise,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text('Substitute'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PriorSessionCard(
                    priorSets: state.priorSets,
                    bestPrSet: state.bestPrSet,
                    suggestedWeight: state.suggestedWeight,
                  ),
                  const SizedBox(height: 16),
                  ExerciseSetInputCard(
                    currentExercise: currentEx,
                    currentSetIndex: state.currentSetIndex,
                    weightController: _weightController,
                    repsController: _repsController,
                    durationController: _durationController,
                    distanceController: _distanceController,
                    inclineController: _inclineController,
                    isWarmUp: state.isWarmUp,
                    selectedSetType: state.selectedSetType,
                    selectedRpe: state.selectedRpe,
                    onWarmUpChanged: (val) => controller.toggleWarmUp(val),
                    onSetTypeChanged: (val) => controller.setSelectedSetType(val),
                    onRpeChanged: (val) => controller.setSelectedRpe(val),
                    onCompleteSet: _completeSet,
                  ),
                  const SizedBox(height: 12),

                  // Completed set chips & set navigation bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (state.currentSetIndex > 0 || state.currentExerciseIndex > 0)
                        TextButton.icon(
                          onPressed: () {
                            controller.goToPreviousSet();
                            _syncInputsWithState();
                          },
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Prev Set'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                        )
                      else
                        const SizedBox.shrink(),
                      
                      Text(
                        'Set ${state.currentSetIndex + 1} of ${currentEx.sets}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
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
                        final loggedForEx = state.loggedSets.where((s) => s.exerciseName.value == currentEx.exerciseName).toList();
                        final isCompleted = idx < loggedForEx.length;
                        final loggedSet = isCompleted ? loggedForEx[idx] : null;

                        String chipLabel = 'Set ${idx + 1}';
                        if (isCompleted && loggedSet != null) {
                          chipLabel = '${idx + 1}: ${loggedSet.weight.value.toStringAsFixed(1)}k×${loggedSet.reps.value}';
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
                                ? const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success)
                                : null,
                            selectedColor: AppColors.primaryGlow,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : (isCompleted ? AppColors.success.withOpacity(0.5) : AppColors.border),
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
                      side: const BorderSide(color: AppColors.danger),
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Finish Workout Early', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            if (state.showPrConfetti)
              ConfettiOverlay(
                isPlaying: true,
                child: Container(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  child: Center(
                    child: Card(
                      color: AppColors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 8),
                            const Text('NEW PERSONAL RECORD!', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${state.prExerciseName}: ${state.prWeight.toStringAsFixed(1)} kg x ${state.prReps} reps', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
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
