import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/consumer_date_label.dart';
import '../../../core/presentation/product_failure_presentation.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/consumer_task_primitives.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../../core/widgets/responsive_form_primitives.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/workout_repository.dart';

class ManualLogSheet extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final String? initialWorkoutName;

  const ManualLogSheet({
    super.key,
    required this.selectedDate,
    this.initialWorkoutName,
  });

  @override
  ConsumerState<ManualLogSheet> createState() => _ManualLogSheetState();
}

class _ManualLogSheetState extends ConsumerState<ManualLogSheet> {
  late TextEditingController _nameController;
  late TextEditingController _durationController;
  final List<_ManualExerciseInput> _exercises = [];
  var _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialWorkoutName ?? 'Completed Workout',
    );
    _durationController = TextEditingController(text: '45');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    for (final exercise in _exercises) {
      exercise.dispose();
    }
    super.dispose();
  }

  void _addExercise() async {
    final repo = ref.read(workoutRepositoryProvider);
    final allExercises = await repo.searchExercises('');
    if (!mounted) return;

    await showIndiFitBottomSheet(
      context: context,
      semanticLabel: 'Choose exercise',
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = allExercises
                .where(
                  (e) => e.name.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search exercise library...',
                    ),
                    onChanged: (val) => setModalState(() => query = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final ex = filtered[i];
                        return ListTile(
                          title: Text(
                            ex.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${ex.muscleGroups} • ${ex.equipment}',
                            style: B05Typography.caption(ctx),
                          ),
                          trailing: Icon(
                            Icons.add_circle_outline,
                            color: ctx.b05Colors.action,
                          ),
                          onTap: () {
                            setState(() {
                              _exercises.add(
                                _ManualExerciseInput(
                                  exerciseName: ex.name,
                                  sets: [
                                    _SetInput(weightKg: 40.0, reps: 10),
                                    _SetInput(weightKg: 40.0, reps: 10),
                                    _SetInput(weightKg: 40.0, reps: 10),
                                  ],
                                ),
                              );
                            });
                            Navigator.pop(ctx);
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
  }

  Future<void> _saveLoggedSession() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a session title.')),
      );
      return;
    }

    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise.')),
      );
      return;
    }

    final durationMins = int.tryParse(_durationController.text) ?? 45;
    final repo = ref.read(workoutRepositoryProvider);

    final setCompanions = <WorkoutSetsCompanion>[];
    double totalVol = 0.0;
    for (final ex in _exercises) {
      for (int i = 0; i < ex.sets.length; i++) {
        final s = ex.sets[i];
        totalVol += (s.weightKg * s.reps);
        setCompanions.add(
          WorkoutSetsCompanion(
            exerciseName: Value(ex.exerciseName),
            setNumber: Value(i + 1),
            reps: Value(s.reps),
            weight: Value(s.weightKg),
          ),
        );
      }
    }

    final int estCalories = (durationMins * 5.5).round();

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await repo.logSession(
        name: name,
        volume: totalVol,
        durationSeconds: durationMins * 60,
        calories: estCalories,
        sets: setCompanions,
        completedAt: widget.selectedDate,
      );

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged "$name" for ${widget.selectedDate.day}/${widget.selectedDate.month}!',
            ),
            backgroundColor: context.b05Colors.success.indicator,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = ProductFailurePresentation.fromError(
          error,
          title: 'Workout could not be saved',
          code: 'workout_save_failed',
        ).message;
      });
    }
  }

  void _addSet(_ManualExerciseInput exercise) {
    late final _SetInput newSet;
    setState(() {
      final lastWeight = exercise.sets.isNotEmpty
          ? exercise.sets.last.weightKg
          : 40.0;
      final lastReps = exercise.sets.isNotEmpty ? exercise.sets.last.reps : 10;
      newSet = _SetInput(weightKg: lastWeight, reps: lastReps);
      exercise.sets.add(newSet);
    });
    // Keep the newly-created set and its correction controls reachable when
    // the sheet is shorter than the completed workout form.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = newSet.key.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, alignment: 1, duration: Duration.zero);
      }
    });
  }

  Widget _buildExerciseCard(_ManualExerciseInput exercise, int exerciseIndex) {
    final colors = context.b05Colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: B05Surface(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.exerciseName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${exercise.exerciseName}',
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _exercises.removeAt(exerciseIndex).dispose();
                    });
                  },
                ),
              ],
            ),
            // Keep the set action adjacent to the exercise heading so it
            // remains reachable before the lower set rows on compact sheets.
            TextButton.icon(
              onPressed: () => _addSet(exercise),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Set', style: TextStyle(fontSize: 11)),
            ),
            ...exercise.sets.asMap().entries.map((setEntry) {
              final setIndex = setEntry.key;
              final setInput = setEntry.value;
              return KeyedSubtree(
                key: setInput.key,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Set ${setIndex + 1}',
                              style: B05Typography.caption(context),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove set ${setIndex + 1}',
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: colors.textSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                exercise.sets.removeAt(setIndex).dispose();
                              });
                            },
                          ),
                        ],
                      ),
                      IndiFitResponsiveFieldGroup(
                        spacing: 8,
                        children: [
                          TextField(
                            controller: setInput.weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'kg',
                              isDense: true,
                            ),
                            onChanged: (value) => setInput.weightKg =
                                double.tryParse(value) ?? 0.0,
                          ),
                          TextField(
                            controller: setInput.repsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'reps',
                              isDense: true,
                            ),
                            onChanged: (value) =>
                                setInput.reps = int.tryParse(value) ?? 0,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = ConsumerDateLabel.dateTime(widget.selectedDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Log Completed Workout',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      B05Surface(
                        tone: B05SurfaceTone.selected,
                        radius: B05SurfaceRadius.small,
                        padding: const EdgeInsets.symmetric(
                          horizontal: B05Layout.space8,
                          vertical: B05Layout.space4,
                        ),
                        child: Text(
                          dateStr,
                          style: B05Typography.caption(
                            context,
                          ).copyWith(color: context.b05Colors.action),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  IndiFitResponsiveFieldGroup(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Workout Title',
                          isDense: true,
                        ),
                      ),
                      TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (min)',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'EXERCISES LOGGED',
                        style: B05Typography.caption(context).copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: .6,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addExercise,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Add Exercise',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (_exercises.isEmpty)
                    ProductEmptyState(
                      icon: Icons.fitness_center_rounded,
                      title: 'Add your first exercise',
                      message: 'Choose the exercises and sets you completed.',
                      action: _addExercise,
                      actionLabel: 'Tap to add exercises to this log',
                      actionIcon: Icons.add,
                    )
                  else
                    Column(
                      children: [
                        for (var index = 0; index < _exercises.length; index++)
                          _buildExerciseCard(_exercises[index], index),
                      ],
                    ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 12),
                    ConsumerStatusRow(
                      label: 'Workout could not be saved',
                      detail: _saveError,
                      error: true,
                      onRetry: _saving ? null : _saveLoggedSession,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: B05ActionButton(
              onPressed: _saving ? null : _saveLoggedSession,
              icon: Icons.check_circle_rounded,
              label: _saving ? 'Saving workout…' : 'Save Workout Session',
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualExerciseInput {
  String exerciseName;
  List<_SetInput> sets;

  _ManualExerciseInput({required this.exerciseName, required this.sets});

  void dispose() {
    for (final set in sets) {
      set.dispose();
    }
  }
}

class _SetInput {
  final GlobalKey key = GlobalKey();
  double weightKg;
  int reps;
  late final TextEditingController weightController;
  late final TextEditingController repsController;

  _SetInput({required this.weightKg, required this.reps}) {
    weightController = TextEditingController(text: '$weightKg');
    repsController = TextEditingController(text: '$reps');
  }

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}
