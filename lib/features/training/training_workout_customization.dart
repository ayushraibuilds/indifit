import 'package:flutter/material.dart';

import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../data/services/b02_occurrence_snapshot_customizer.dart';
import '../exercise_picker/exercise_picker.dart';
import 'training_workout_preview.dart';

typedef SaveTrainingWorkoutCustomization =
    Future<void> Function({
      required String baseSnapshotJson,
      required List<OccurrenceExerciseCustomization> changes,
    });

/// Consumer-facing editor for the resolved, unstarted workout on this date.
/// The screen holds a local draft until one explicit Save action; persistence
/// is delegated to the occurrence repository supplied by Training.
class TrainingWorkoutCustomizationScreen extends StatefulWidget {
  const TrainingWorkoutCustomizationScreen({
    required this.preview,
    required this.onSave,
    required this.onOpenScheduleActions,
    super.key,
  });

  final TrainingWorkoutPreviewData preview;
  final SaveTrainingWorkoutCustomization onSave;
  final VoidCallback onOpenScheduleActions;

  @override
  State<TrainingWorkoutCustomizationScreen> createState() =>
      _TrainingWorkoutCustomizationScreenState();
}

class _TrainingWorkoutCustomizationScreenState
    extends State<TrainingWorkoutCustomizationScreen> {
  late final List<_EditableWorkoutExercise> _exercises = [
    for (final exercise in widget.preview.exercises)
      _EditableWorkoutExercise.fromPreview(exercise),
  ];
  ProductFailurePresentation? _failure;
  var _saving = false;

  bool get _hasChanges => _exercises.any((exercise) => exercise.hasChanges);

  Future<void> _replaceExercise(_EditableWorkoutExercise exercise) async {
    if (_saving) return;
    final selection = await showExercisePicker(
      context: context,
      selectionContext: ExerciseLibraryPickerContext(
        title: 'Replace ${exercise.name}',
        semanticLabel: 'Choose a replacement for ${exercise.name}',
        selectedExerciseId:
            exercise.replacementExerciseId ?? exercise.original.exerciseId,
      ),
    );
    if (!mounted || selection == null) return;
    setState(() {
      exercise.replacementExerciseId = selection.exerciseId;
      exercise.name = selection.exerciseNameSnapshot;
      // A replacement must not visually or persistently inherit the planned
      // exercise's load. B02 will resolve evidence for the selected identity
      // when this occurrence starts.
      exercise.targetLoadKg = null;
      _failure = null;
    });
  }

  Future<void> _editTarget(_EditableWorkoutExercise exercise) async {
    if (_saving) return;
    final edited = await showDialog<_TargetEditResult>(
      context: context,
      builder: (_) => _TargetEditDialog(exercise: exercise),
    );
    if (!mounted || edited == null) return;
    setState(() {
      exercise.plannedSets = edited.plannedSets;
      exercise.repsRange = edited.repsRange;
      exercise.targetLoadKg = edited.targetLoadKg;
      _failure = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    final baseSnapshotJson = widget.preview.sourceSnapshotJson;
    if (baseSnapshotJson == null || baseSnapshotJson.trim().isEmpty) {
      setState(() {
        _failure = ProductFailurePresentation.fromError(
          const FormatException('The workout details are unavailable.'),
          title: 'Changes not saved',
        );
      });
      return;
    }
    final changes = [
      for (final exercise in _exercises)
        if (exercise.hasChanges) exercise.toChange(),
    ];
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await widget.onSave(baseSnapshotJson: baseSnapshotJson, changes: changes);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = ProductFailurePresentation.fromError(
          error,
          title: 'Changes not saved',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConsumerTaskScaffold(
      appBar: AppBar(title: const Text("Customize today's workout")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            child: B05Surface(
              tone: B05SurfaceTone.inset,
              padding: const EdgeInsets.all(B05Layout.space12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    color: context.b05Colors.action,
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.preview.workoutName,
                          style: B05Typography.title(context),
                        ),
                        const SizedBox(height: B05Layout.space4),
                        const Text(
                          'These changes apply to this workout only. Your future plan stays the same.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: B05Layout.space16),
          Text('EXERCISES', style: _eyebrow(context)),
          const SizedBox(height: B05Layout.space8),
          for (final exercise in _exercises) ...[
            _ExerciseCustomizationCard(
              exercise: exercise,
              onReplace: () => _replaceExercise(exercise),
              onEditTarget: () => _editTarget(exercise),
              enabled: !_saving,
            ),
            const SizedBox(height: B05Layout.space8),
          ],
          B05Surface(
            tone: B05SurfaceTone.inset,
            padding: const EdgeInsets.all(B05Layout.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('More options', style: B05Typography.label(context)),
                const SizedBox(height: B05Layout.space4),
                const Text(
                  'Adding or removing exercises is not available for scheduled workouts yet.',
                ),
                const SizedBox(height: B05Layout.space8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: B05ActionButton(
                    label: 'Move or skip this workout',
                    hint: 'Open schedule controls for this workout.',
                    icon: Icons.event_repeat_outlined,
                    emphasis: B05ActionEmphasis.tertiary,
                    onPressed: _saving
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onOpenScheduleActions();
                          },
                  ),
                ),
              ],
            ),
          ),
          if (_failure != null) ...[
            const SizedBox(height: B05Layout.space12),
            ProductFailureCard(
              failure: _failure!,
              onRetry: _save,
              onBack: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
      primaryAction: B05ActionButton(
        label: _hasChanges ? 'Save changes' : 'Done',
        hint: _hasChanges
            ? 'Save changes for this workout only.'
            : 'Close workout customization.',
        icon: _hasChanges ? Icons.check_rounded : Icons.done_rounded,
        onPressed: _saving ? null : _save,
      ),
    );
  }

  TextStyle _eyebrow(BuildContext context) => B05Typography.caption(
    context,
  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: .8);
}

class _EditableWorkoutExercise {
  _EditableWorkoutExercise({
    required this.original,
    required this.name,
    required this.plannedSets,
    required this.repsRange,
    required this.targetLoadKg,
    required this.targetLoadBasis,
  });

  factory _EditableWorkoutExercise.fromPreview(
    TrainingWorkoutPreviewExercise exercise,
  ) {
    final loadTarget = exercise.targets
        .cast<TrainingWorkoutPreviewSetTarget?>()
        .firstWhere(
          (target) => target?.targetLoadKg != null,
          orElse: () => null,
        );
    return _EditableWorkoutExercise(
      original: exercise,
      name: exercise.name,
      plannedSets: exercise.plannedSets,
      repsRange: exercise.repsRange,
      targetLoadKg: loadTarget?.targetLoadKg,
      targetLoadBasis: loadTarget?.loadBasis?.dbValue,
    );
  }

  final TrainingWorkoutPreviewExercise original;
  String name;
  int plannedSets;
  String repsRange;
  double? targetLoadKg;
  final String? targetLoadBasis;
  String? replacementExerciseId;

  bool get canEditSetCount => original.groupId == null;
  bool get canEditLoad => targetLoadKg != null;

  bool get hasChanges =>
      replacementExerciseId != null ||
      plannedSets != original.plannedSets ||
      repsRange != original.repsRange ||
      targetLoadKg != _originalLoad;

  double? get _originalLoad {
    final target = original.targets
        .cast<TrainingWorkoutPreviewSetTarget?>()
        .firstWhere((item) => item?.targetLoadKg != null, orElse: () => null);
    return target?.targetLoadKg;
  }

  OccurrenceExerciseCustomization toChange() {
    return OccurrenceExerciseCustomization(
      prescriptionId: original.prescriptionId,
      replacementExerciseId: replacementExerciseId,
      plannedSets: plannedSets == original.plannedSets ? null : plannedSets,
      repsRange: repsRange == original.repsRange ? null : repsRange,
      targetLoadKg: targetLoadKg == _originalLoad ? null : targetLoadKg,
      targetLoadBasis: targetLoadBasis,
    );
  }
}

class _ExerciseCustomizationCard extends StatelessWidget {
  const _ExerciseCustomizationCard({
    required this.exercise,
    required this.onReplace,
    required this.onEditTarget,
    required this.enabled,
  });

  final _EditableWorkoutExercise exercise;
  final VoidCallback onReplace;
  final VoidCallback onEditTarget;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final details = StringBuffer()
      ..write(
        '${exercise.plannedSets} ${exercise.plannedSets == 1 ? 'set' : 'sets'}',
      )
      ..write(' · ${exercise.repsRange} reps');
    if (exercise.targetLoadKg != null) {
      details.write(' · ${_formatLoad(exercise.targetLoadKg!)} kg');
    }
    return B05Surface(
      padding: const EdgeInsets.all(B05Layout.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.name, style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space4),
          Text(details.toString(), style: B05Typography.body(context)),
          if (exercise.hasChanges) ...[
            const SizedBox(height: B05Layout.space4),
            Text(
              'Changed for this workout',
              style: B05Typography.caption(
                context,
              ).copyWith(color: context.b05Colors.action),
            ),
          ],
          const SizedBox(height: B05Layout.space8),
          Wrap(
            spacing: B05Layout.space8,
            runSpacing: B05Layout.space4,
            children: [
              OutlinedButton.icon(
                onPressed: enabled ? onReplace : null,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Replace'),
              ),
              OutlinedButton.icon(
                onPressed: enabled ? onEditTarget : null,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Edit target'),
              ),
            ],
          ),
          if (!exercise.canEditSetCount) ...[
            const SizedBox(height: B05Layout.space4),
            Text(
              'Sets follow this workout group.',
              style: B05Typography.caption(context),
            ),
          ],
          if (exercise.replacementExerciseId != null)
            Text(
              'Load will be set for the replacement when this workout starts.',
              style: B05Typography.caption(context),
            )
          else if (!exercise.canEditLoad)
            Text(
              'Load will be set when this workout starts.',
              style: B05Typography.caption(context),
            ),
        ],
      ),
    );
  }
}

class _TargetEditDialog extends StatefulWidget {
  const _TargetEditDialog({required this.exercise});

  final _EditableWorkoutExercise exercise;

  @override
  State<_TargetEditDialog> createState() => _TargetEditDialogState();
}

class _TargetEditDialogState extends State<_TargetEditDialog> {
  late final TextEditingController _sets = TextEditingController(
    text: '${widget.exercise.plannedSets}',
  );
  late final TextEditingController _reps = TextEditingController(
    text: widget.exercise.repsRange,
  );
  late final TextEditingController _load = TextEditingController(
    text: widget.exercise.targetLoadKg == null
        ? ''
        : _formatLoad(widget.exercise.targetLoadKg!),
  );
  String? _error;

  @override
  void dispose() {
    _sets.dispose();
    _reps.dispose();
    _load.dispose();
    super.dispose();
  }

  void _done() {
    final sets = int.tryParse(_sets.text.trim());
    final reps = _reps.text.trim();
    final load = widget.exercise.canEditLoad
        ? double.tryParse(_load.text.trim())
        : widget.exercise.targetLoadKg;
    if (widget.exercise.canEditSetCount && (sets == null || sets < 1)) {
      setState(() => _error = 'Sets must be at least 1.');
      return;
    }
    if (reps.isEmpty || !RegExp(r'\d').hasMatch(reps)) {
      setState(() => _error = 'Add a repetition target, such as 8–10.');
      return;
    }
    if (widget.exercise.canEditLoad && (load == null || load < 0)) {
      setState(() => _error = 'Load must be a valid non-negative number.');
      return;
    }
    Navigator.of(context).pop(
      _TargetEditResult(
        plannedSets: widget.exercise.canEditSetCount
            ? sets!
            : widget.exercise.plannedSets,
        repsRange: reps,
        targetLoadKg: load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.exercise.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.exercise.canEditSetCount)
              TextField(
                controller: _sets,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sets'),
              ),
            TextField(
              controller: _reps,
              decoration: const InputDecoration(labelText: 'Reps'),
            ),
            if (widget.exercise.canEditLoad)
              TextField(
                controller: _load,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Load (kg)'),
              ),
            if (_error != null) ...[
              const SizedBox(height: B05Layout.space8),
              Text(
                _error!,
                style: TextStyle(color: context.b05Colors.danger.foreground),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _done, child: const Text('Done')),
      ],
    );
  }
}

class _TargetEditResult {
  const _TargetEditResult({
    required this.plannedSets,
    required this.repsRange,
    required this.targetLoadKg,
  });

  final int plannedSets;
  final String repsRange;
  final double? targetLoadKg;
}

String _formatLoad(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}
