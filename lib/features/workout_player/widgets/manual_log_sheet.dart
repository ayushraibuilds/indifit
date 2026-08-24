import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../core/presentation/consumer_date_label.dart';
import '../../../core/presentation/product_failure_presentation.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/consumer_task_primitives.dart';
import '../../../core/widgets/indi_fit_feedback.dart';
import '../../../core/widgets/responsive_form_primitives.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/b02_execution_models.dart';
import '../../../data/repositories/exercise_picker_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../exercise_picker/exercise_picker.dart';

/// Retrospective strength entry for a workout that has already happened.
///
/// This surface deliberately does not start a B02 draft. It collects actual
/// facts and hands them to the canonical strength history writer. Planned
/// prescription, elapsed-session state, occurrence identity, and resume state
/// therefore cannot be fabricated by this form.
class ManualLogSheet extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final String? initialWorkoutName;
  final List<ExercisePickerSelection> initialExercises;

  const ManualLogSheet({
    super.key,
    required this.selectedDate,
    this.initialWorkoutName,
    this.initialExercises = const [],
  });

  @override
  ConsumerState<ManualLogSheet> createState() => _ManualLogSheetState();
}

class _ManualLogSheetState extends ConsumerState<ManualLogSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  final List<_ManualExerciseInput> _exercises = [];
  final String _submissionKey = 'manual-strength:${const Uuid().v4()}';
  late DateTime _selectedDate;
  var _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.selectedDate);
    _nameController = TextEditingController(
      text: widget.initialWorkoutName ?? 'Completed Workout',
    );
    _durationController = TextEditingController(text: '45');
    final initialIds = <String>{};
    for (final selection in widget.initialExercises) {
      if (!initialIds.add(selection.exerciseId)) continue;
      _exercises.add(
        _ManualExerciseInput(
          exerciseId: selection.exerciseId,
          exerciseName: selection.exerciseNameSnapshot,
        ),
      );
    }
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

  Future<void> _addExercise() async {
    final selections = await showExerciseMultiPicker(
      context: context,
      repository: _exercisePickerRepository,
      selectionContext: const ExerciseLibraryPickerContext(
        title: 'Add exercises',
        semanticLabel: 'Add exercises to completed workout',
      ),
      initialSelectedExerciseIds: {
        for (final exercise in _exercises) exercise.exerciseId,
      },
    );
    if (!mounted || selections == null) return;
    final existingIds = _exercises
        .map((exercise) => exercise.exerciseId)
        .toSet();
    setState(() {
      for (final selection in selections) {
        if (!existingIds.add(selection.exerciseId)) continue;
        _exercises.add(
          _ManualExerciseInput(
            exerciseId: selection.exerciseId,
            exerciseName: selection.exerciseNameSnapshot,
          ),
        );
      }
    });
  }

  ExercisePickerRepository get _exercisePickerRepository {
    // The legacy repository remains a read-only catalog bridge here so old
    // callers/tests that provide a catalog fixture keep working. Selection
    // still returns the exact stable ID and all writes use B02 authorities.
    return ExercisePickerRepository.fromSource(
      _WorkoutRepositoryExerciseCatalogSource(
        ref.read(workoutRepositoryProvider),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: _dateOnly(DateTime.now().add(const Duration(days: 1))),
      helpText: 'Choose workout date',
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedDate = _dateOnly(picked));
  }

  Future<void> _saveLoggedSession() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final durationMinutes = int.tryParse(_durationController.text.trim());
    final validation = _validate(name: name, durationMinutes: durationMinutes);
    if (validation != null) {
      setState(() => _saveError = validation);
      return;
    }

    final performedExercises = <B02PerformedExerciseDraft>[];
    try {
      for (
        var exerciseOrdinal = 0;
        exerciseOrdinal < _exercises.length;
        exerciseOrdinal++
      ) {
        final exercise = _exercises[exerciseOrdinal];
        final sets = <B02PerformedSet>[];
        for (
          var setOrdinal = 0;
          setOrdinal < exercise.sets.length;
          setOrdinal++
        ) {
          final input = exercise.sets[setOrdinal];
          final reps = int.tryParse(input.repsController.text.trim());
          final loadText = input.loadController.text.trim();
          final load = loadText.isEmpty ? null : double.tryParse(loadText);
          if (reps == null || reps < 1) {
            throw const B02ValidationException(
              'Enter positive reps for every recorded set.',
            );
          }
          if (loadText.isNotEmpty && (load == null || load < 0)) {
            throw const B02ValidationException(
              'Enter a valid non-negative load or leave load blank.',
            );
          }
          sets.add(
            B02PerformedSet(
              id: '${exercise.exerciseId}:set:$setOrdinal',
              performedExerciseId: exercise.exerciseId,
              ordinal: setOrdinal,
              role: input.isWarmup ? B02SetRole.warmup : B02SetRole.working,
              actualLoadKg: load,
              actualLoadBasis: load == null ? null : B02LoadBasis.totalExternal,
              actualReps: reps,
              actualRpe: input.rpe,
            ),
          );
        }
        performedExercises.add(
          B02PerformedExerciseDraft(
            id: exercise.exerciseId,
            ordinal: exerciseOrdinal,
            actualExerciseId: exercise.exerciseId,
            actualExerciseNameSnapshot: exercise.exerciseName,
            status: 'completed',
            sets: sets,
          ),
        );
      }
    } on B02ValidationException catch (error) {
      setState(() => _saveError = error.message);
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final completedAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        12,
      ).toUtc();
      await ref
          .read(strengthExecutionCompatibilityAdapterProvider)
          .saveManualCompletedWorkout(
            routineName: name,
            durationSeconds: durationMinutes! * 60,
            completedAtUtc: completedAt,
            performedExercises: performedExercises,
            idempotencyKey: _submissionKey,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(indiFitSuccessSnackBar('✓ Workout logged'));
      Navigator.of(context).pop(true);
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

  String? _validate({required String name, required int? durationMinutes}) {
    if (name.isEmpty) return 'Enter a workout title.';
    if (durationMinutes == null || durationMinutes < 1) {
      return 'Enter a positive duration in minutes.';
    }
    if (_exercises.isEmpty) {
      return 'Add at least one exercise.';
    }
    if (_exercises.any((exercise) => exercise.sets.isEmpty)) {
      return 'Add at least one set for each exercise.';
    }
    return null;
  }

  void _addSet(_ManualExerciseInput exercise) {
    final previous = exercise.sets.isEmpty ? null : exercise.sets.last;
    late final _ManualSetInput newSet;
    setState(() {
      newSet = _ManualSetInput(
        load: previous?.loadController.text ?? '',
        reps: previous?.repsController.text ?? '',
        isWarmup: previous?.isWarmup ?? false,
        rpe: previous?.rpe,
      );
      exercise.sets.add(newSet);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = newSet.key.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, alignment: 1, duration: Duration.zero);
      }
    });
  }

  void _removeSet(_ManualExerciseInput exercise, int setIndex) {
    setState(() => exercise.sets.removeAt(setIndex).dispose());
    _revealExerciseHeader(exercise);
  }

  void _removeExercise(int exerciseIndex) {
    final anchor = exerciseIndex + 1 < _exercises.length
        ? _exercises[exerciseIndex + 1]
        : exerciseIndex > 0
        ? _exercises[exerciseIndex - 1]
        : null;
    setState(() => _exercises.removeAt(exerciseIndex).dispose());
    if (anchor != null) _revealExerciseHeader(anchor);
  }

  void _revealExerciseHeader(_ManualExerciseInput exercise) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = exercise.key.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, alignment: 0, duration: Duration.zero);
      }
    });
  }

  Widget _buildExerciseCard(_ManualExerciseInput exercise, int exerciseIndex) {
    final colors = context.b05Colors;
    return Padding(
      key: exercise.key,
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
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  onPressed: _saving
                      ? null
                      : () => _removeExercise(exerciseIndex),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _saving ? null : () => _addSet(exercise),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Set', style: TextStyle(fontSize: 12)),
            ),
            ...exercise.sets.asMap().entries.map((entry) {
              final setIndex = entry.key;
              final setInput = entry.value;
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
                            onPressed: _saving || exercise.sets.length == 1
                                ? null
                                : () => _removeSet(exercise, setIndex),
                          ),
                        ],
                      ),
                      IndiFitResponsiveFieldGroup(
                        spacing: 8,
                        children: [
                          TextField(
                            controller: setInput.loadController,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Load (kg, optional)',
                              isDense: true,
                            ),
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                          ),
                          TextField(
                            controller: setInput.repsController,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Reps',
                              isDense: true,
                            ),
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: DropdownButton<int?>(
                              isExpanded: true,
                              value: setInput.rpe,
                              hint: const Text('RPE'),
                              onChanged: _saving
                                  ? null
                                  : (value) =>
                                        setState(() => setInput.rpe = value),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('RPE not set'),
                                ),
                                for (var value = 1; value <= 10; value++)
                                  DropdownMenuItem<int?>(
                                    value: value,
                                    child: Text('RPE $value'),
                                  ),
                              ],
                            ),
                          ),
                          FilterChip(
                            label: const Text('Warm-up set'),
                            selected: setInput.isWarmup,
                            onSelected: _saving
                                ? null
                                : (value) =>
                                      setState(() => setInput.isWarmup = value),
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
    final dateLabel = ConsumerDateLabel.dateTime(_selectedDate);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Material(
        color: context.b05Colors.section,
        surfaceTintColor: Colors.transparent,
        child: SafeArea(
          top: true,
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text('Workout date, $dateLabel'),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IndiFitResponsiveFieldGroup(
                          children: [
                            TextField(
                              controller: _nameController,
                              enabled: !_saving,
                              decoration: const InputDecoration(
                                labelText: 'Workout Title',
                                isDense: true,
                              ),
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
                            ),
                            TextField(
                              controller: _durationController,
                              enabled: !_saving,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (min)',
                                isDense: true,
                              ),
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
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
                              onPressed: _saving ? null : _addExercise,
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
                            message:
                                'Choose the exercises and sets you completed.',
                            action: _saving ? null : _addExercise,
                            actionLabel: 'Tap to add exercises to this log',
                            actionIcon: Icons.add,
                          )
                        else
                          Column(
                            children: [
                              for (
                                var index = 0;
                                index < _exercises.length;
                                index++
                              )
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
          ),
        ),
      ),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class _ManualExerciseInput {
  final GlobalKey key = GlobalKey();
  final String exerciseId;
  final String exerciseName;
  final List<_ManualSetInput> sets = [
    _ManualSetInput(),
    _ManualSetInput(),
    _ManualSetInput(),
  ];

  _ManualExerciseInput({required this.exerciseId, required this.exerciseName});

  void dispose() {
    for (final set in sets) {
      set.dispose();
    }
  }
}

class _ManualSetInput {
  final GlobalKey key = GlobalKey();
  late final TextEditingController loadController;
  late final TextEditingController repsController;
  bool isWarmup;
  int? rpe;

  _ManualSetInput({
    String load = '',
    String reps = '',
    this.isWarmup = false,
    this.rpe,
  }) {
    loadController = TextEditingController(text: load);
    repsController = TextEditingController(text: reps);
  }

  void dispose() {
    loadController.dispose();
    repsController.dispose();
  }
}

/// Read-only compatibility source for the picker. The old repository's
/// search method is intentionally used only to discover catalog rows; it is
/// not a write authority for the new historical record.
final class _WorkoutRepositoryExerciseCatalogSource
    implements ExerciseCatalogSource {
  final WorkoutRepository repository;

  const _WorkoutRepositoryExerciseCatalogSource(this.repository);

  @override
  Future<List<Exercise>> readAll() => repository.searchExercises('');

  @override
  Future<Exercise?> readByStableId(String stableId) async {
    final clean = stableId.trim();
    if (clean.isEmpty) return null;
    final exercises = await repository.searchExercises('');
    for (final exercise in exercises) {
      if (exercise.stableId?.trim() == clean) return exercise;
    }
    return null;
  }
}
