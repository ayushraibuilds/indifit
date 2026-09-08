import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/equipment_fixtures.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/equipment_preference_repository.dart';
import '../../data/services/b02_occurrence_snapshot_customizer.dart';
import '../exercise_picker/exercise_picker.dart';
import 'training_workout_preview.dart';

enum WorkoutCustomizationScope {
  single,
  allFuture,
}

typedef SaveTrainingWorkoutCustomization =
    Future<void> Function({
      required String baseSnapshotJson,
      required List<OccurrenceExerciseCustomization> changes,
      required WorkoutCustomizationScope scope,
    });

typedef ResetTrainingWorkoutCustomization =
    Future<void> Function({
      required bool allFuture,
    });

/// Consumer-facing editor for the resolved, unstarted workout on this date.
/// The screen holds a local draft until one explicit Save action; persistence
/// is delegated to the occurrence repository supplied by Training.
class TrainingWorkoutCustomizationScreen extends ConsumerStatefulWidget {
  const TrainingWorkoutCustomizationScreen({
    required this.preview,
    required this.onSave,
    this.onReset,
    this.onOpenScheduleActions,
    this.futureOccurrencesCount = 1,
    this.initialScope = WorkoutCustomizationScope.single,
    super.key,
  });

  final TrainingWorkoutPreviewData preview;
  final SaveTrainingWorkoutCustomization onSave;
  final ResetTrainingWorkoutCustomization? onReset;
  final VoidCallback? onOpenScheduleActions;
  final int futureOccurrencesCount;
  final WorkoutCustomizationScope initialScope;

  @override
  ConsumerState<TrainingWorkoutCustomizationScreen> createState() =>
      _TrainingWorkoutCustomizationScreenState();
}

class _TrainingWorkoutCustomizationScreenState
    extends ConsumerState<TrainingWorkoutCustomizationScreen> {
  late WorkoutCustomizationScope _selectedScope = widget.initialScope;
  late final List<_EditableWorkoutExercise> _exercises = [
    for (final exercise in widget.preview.exercises)
      _EditableWorkoutExercise.fromPreview(exercise),
  ];
  EquipmentProfileAggregate? _activeProfile;
  final Map<String, Exercise> _catalogExercises = {};
  final Map<String, EquipmentCompatibility> _compatibilities = {};
  ProductFailurePresentation? _failure;
  var _saving = false;

  bool get _hasChanges => _exercises.any((exercise) => exercise.hasChanges);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadEquipmentAndCatalog();
    });
  }

  Future<void> _loadEquipmentAndCatalog() async {
    try {
      final db = ref.read(databaseProvider);
      final equipmentRepo = ref.read(equipmentProfileRepositoryProvider);
      final defaultProfileId = await equipmentRepo.getDefaultProfileId();
      if (defaultProfileId != null) {
        _activeProfile = await equipmentRepo.getProfile(defaultProfileId);
      }
      final allIds = <String>{
        for (final ex in _exercises)
          if (ex.original.exerciseId != null) ex.original.exerciseId!,
      };
      if (allIds.isNotEmpty) {
        final rows = await (db.select(db.exercises)..where((t) => t.stableId.isIn(allIds))).get();
        for (final row in rows) {
          if (row.stableId != null) {
            _catalogExercises[row.stableId!] = row;
          }
        }
      }
      await _updateCompatibilities();
      if (mounted) setState(() {});
    } catch (_) {
      // Non-fatal if equipment profile lookup fails
    }
  }

  Future<void> _updateCompatibilities() async {
    if (_activeProfile == null) return;
    final equipmentRepo = ref.read(equipmentProfileRepositoryProvider);
    for (final ex in _exercises) {
      final currentId = ex.replacementExerciseId ?? ex.original.exerciseId;
      if (currentId == null) continue;
      final exercise = _catalogExercises[currentId];
      if (exercise != null && exercise.equipment.trim().isNotEmpty) {
        final compat = await equipmentRepo.checkCompatibility(
          profileId: _activeProfile!.profile.id,
          exerciseEquipmentRequirement: exercise.equipment,
        );
        _compatibilities[currentId] = compat;
      }
    }
  }

  Future<void> _replaceExercise(_EditableWorkoutExercise exercise) async {
    if (_saving) return;
    final currentExerciseId = exercise.replacementExerciseId ?? exercise.original.exerciseId;
    final currentCatalog = currentExerciseId != null ? _catalogExercises[currentExerciseId] : null;

    final selection = await showExercisePicker(
      context: context,
      selectionContext: ExerciseLibraryPickerContext(
        title: 'Replace ${exercise.name}',
        semanticLabel: 'Choose a replacement for ${exercise.name}',
        selectedExerciseId: currentExerciseId,
        initialEquipment: currentCatalog?.equipment,
      ),
    );
    if (!mounted || selection == null) return;

    if (!_catalogExercises.containsKey(selection.exerciseId)) {
      final db = ref.read(databaseProvider);
      final row = await (db.select(db.exercises)..where((t) => t.stableId.equals(selection.exerciseId))).getSingleOrNull();
      if (row != null) {
        _catalogExercises[selection.exerciseId] = row;
      }
    }

    setState(() {
      exercise.replacementExerciseId = selection.exerciseId;
      exercise.name = selection.exerciseNameSnapshot;
      exercise.targetLoadKg = null;
      _failure = null;
    });
    await _updateCompatibilities();
    if (mounted) setState(() {});
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

  Future<void> _confirmReset() async {
    if (_saving || widget.onReset == null) return;
    var resetAllFuture = false;
    if (widget.futureOccurrencesCount > 1) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          var localResetAll = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Reset workout customizations'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Choose the reset scope:'),
                    const SizedBox(height: B05Layout.space12),
                    // ignore: deprecated_member_use
                    RadioListTile<bool>(
                      value: false,
                      // ignore: deprecated_member_use
                      groupValue: localResetAll,
                      title: const Text('Reset this workout only'),
                      subtitle: const Text('Restores published defaults for this date.'),
                      // ignore: deprecated_member_use
                      onChanged: (val) => setDialogState(() => localResetAll = val!),
                      contentPadding: EdgeInsets.zero,
                    ),
                    // ignore: deprecated_member_use
                    RadioListTile<bool>(
                      value: true,
                      // ignore: deprecated_member_use
                      groupValue: localResetAll,
                      title: const Text('Reset all upcoming workouts'),
                      subtitle: Text(
                        'Wipes individual customizations across ${widget.futureOccurrencesCount} upcoming workouts.',
                      ),
                      // ignore: deprecated_member_use
                      onChanged: (val) => setDialogState(() => localResetAll = val!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(null),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      resetAllFuture = localResetAll;
                      Navigator.of(dialogContext).pop(true);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (confirmed != true) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reset this workout?'),
          content: const Text(
            'This will revert all customizations on this workout back to the original plan defaults.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await widget.onReset!(allFuture: resetAllFuture);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = ProductFailurePresentation.fromError(
          error,
          title: 'Reset failed',
        );
      });
    }
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
      await widget.onSave(
        baseSnapshotJson: baseSnapshotJson,
        changes: changes,
        scope: _selectedScope,
      );
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            if (_activeProfile != null) ...[
                              const SizedBox(height: B05Layout.space4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.fitness_center_outlined,
                                    size: 14,
                                    color: context.b05Colors.textSecondary,
                                  ),
                                  const SizedBox(width: B05Layout.space4),
                                  Text(
                                    'Equipment profile: ${_activeProfile!.profile.name}',
                                    style: B05Typography.caption(context).copyWith(
                                      color: context.b05Colors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: B05Layout.space12),
                  Text('CUSTOMIZATION SCOPE', style: _eyebrow(context)),
                  const SizedBox(height: B05Layout.space8),
                  _ScopeChoiceTile(
                    title: 'This workout only',
                    subtitle: 'These changes apply to this workout only. Your future plan stays the same.',
                    selected: _selectedScope == WorkoutCustomizationScope.single,
                    onTap: _saving
                        ? null
                        : () => setState(() => _selectedScope = WorkoutCustomizationScope.single),
                  ),
                  const SizedBox(height: B05Layout.space8),
                  _ScopeChoiceTile(
                    title: 'This and future workouts',
                    subtitle: widget.futureOccurrencesCount > 1
                        ? 'Replaces individual customizations on all ${widget.futureOccurrencesCount} upcoming workouts of this type.'
                        : 'Applies to all upcoming workouts of this type.',
                    selected: _selectedScope == WorkoutCustomizationScope.allFuture,
                    onTap: _saving
                        ? null
                        : () => setState(() => _selectedScope = WorkoutCustomizationScope.allFuture),
                  ),
                  const SizedBox(height: B05Layout.space8),
                  Text(
                    'Past workouts and logged history are frozen and will never be modified.',
                    style: B05Typography.caption(context).copyWith(
                      color: context.b05Colors.textSecondary,
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
              equipment: _catalogExercises[exercise.replacementExerciseId ?? exercise.original.exerciseId]?.equipment,
              compatibility: _compatibilities[exercise.replacementExerciseId ?? exercise.original.exerciseId],
              onReplace: () => _replaceExercise(exercise),
              onEditTarget: () => _editTarget(exercise),
              enabled: !_saving,
            ),
            const SizedBox(height: B05Layout.space8),
          ],
          if (widget.preview.isCustomized && widget.onReset != null) ...[
            B05Surface(
              tone: B05SurfaceTone.inset,
              padding: const EdgeInsets.all(B05Layout.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reset workout', style: B05Typography.label(context)),
                  const SizedBox(height: B05Layout.space4),
                  const Text(
                    'Revert customizations and restore published plan defaults.',
                  ),
                  const SizedBox(height: B05Layout.space8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: B05ActionButton(
                      label: 'Reset to plan default',
                      hint: 'Revert this workout to original template.',
                      icon: Icons.restore_rounded,
                      emphasis: B05ActionEmphasis.secondary,
                      onPressed: _saving ? null : _confirmReset,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: B05Layout.space12),
          ],
          if (widget.onOpenScheduleActions != null) ...[
            B05Surface(
              tone: B05SurfaceTone.inset,
              padding: const EdgeInsets.all(B05Layout.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('More options', style: B05Typography.label(context)),
                  const SizedBox(height: B05Layout.space4),
                  const Text(
                    'Scheduled workout exercises can’t be changed here.',
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
                              widget.onOpenScheduleActions!();
                            },
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            ? (_selectedScope == WorkoutCustomizationScope.allFuture
                ? 'Save changes across upcoming workouts.'
                : 'Save changes for this workout only.')
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

class _ScopeChoiceTile extends StatelessWidget {
  const _ScopeChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(B05Radii.small),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: B05Layout.space12,
          vertical: B05Layout.space8,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.action.withValues(alpha: 0.08) : Colors.transparent,
          border: Border.all(
            color: selected ? colors.action : colors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(B05Radii.small),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? colors.action : colors.textSecondary,
              ),
            ),
            const SizedBox(width: B05Layout.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: B05Typography.label(context).copyWith(
                      color: selected ? colors.action : null,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: B05Typography.caption(context).copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    this.equipment,
    this.compatibility,
  });

  final _EditableWorkoutExercise exercise;
  final VoidCallback onReplace;
  final VoidCallback onEditTarget;
  final bool enabled;
  final String? equipment;
  final EquipmentCompatibility? compatibility;

  @override
  Widget build(BuildContext context) {
    final details = StringBuffer()
      ..write(
        '${exercise.plannedSets} ${exercise.plannedSets == 1 ? "set" : "sets"}',
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
          if (equipment != null && equipment!.trim().isNotEmpty) ...[
            const SizedBox(height: B05Layout.space8),
            Wrap(
              spacing: B05Layout.space8,
              runSpacing: B05Layout.space4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.b05Colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    equipment!,
                    style: B05Typography.caption(context).copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (compatibility != null &&
                    compatibility!.status == EquipmentCompatibilityStatus.incompatible &&
                    compatibility!.unavailableEquipmentCodes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.b05Colors.warning.container,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: context.b05Colors.warning.foreground,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Missing: ${compatibility!.unavailableEquipmentCodes.map((code) => CanonicalEquipmentItem.fromId(code)?.displayName ?? code).join(", ")}',
                          style: B05Typography.caption(context).copyWith(
                            color: context.b05Colors.warning.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
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
