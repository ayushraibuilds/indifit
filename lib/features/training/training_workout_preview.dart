import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/presentation/consumer_date_label.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/calendar_read_repository.dart';

/// A read-only, occurrence-scoped workout preview.
///
/// The preview is built from the occurrence's launch snapshot. For an
/// unstarted occurrence that snapshot is a read-only projection made by the
/// same B01 builder used by the start command. The UI never looks up the
/// active plan or rebuilds a workout from a name.
class TrainingWorkoutPreviewData {
  const TrainingWorkoutPreviewData({
    required this.occurrenceItem,
    required this.workoutName,
    required this.activityType,
    required this.exercises,
    required this.groups,
    required this.substitutions,
    this.durationSeconds,
    required this.isSnapshotBacked,
  });

  final CalendarOccurrenceReadItem occurrenceItem;
  final String workoutName;
  final String activityType;
  final List<TrainingWorkoutPreviewExercise> exercises;
  final List<TrainingWorkoutPreviewGroup> groups;
  final List<TrainingWorkoutPreviewSubstitution> substitutions;
  final int? durationSeconds;
  final bool isSnapshotBacked;

  bool get hasDetails => exercises.isNotEmpty;

  bool get hasPlannedTargets =>
      exercises.any((exercise) => exercise.targets.isNotEmpty);

  factory TrainingWorkoutPreviewData.fromOccurrence(
    CalendarOccurrenceReadItem item, {
    String? snapshotJson,
  }) {
    if (snapshotJson == null || snapshotJson.trim().isEmpty) {
      return _fromReadItem(item);
    }

    final root = _decodeObject(snapshotJson, 'workout preview');
    final snapshotOccurrenceId = root['occurrenceId'];
    if (snapshotOccurrenceId is! String ||
        snapshotOccurrenceId.trim() != item.occurrence.id) {
      throw const FormatException(
        'The workout preview does not belong to this scheduled workout.',
      );
    }
    final snapshotTemplate = root['template'];
    if (snapshotTemplate != null) {
      final template = _decodeObjectValue(snapshotTemplate, 'template');
      final templateId = template['id'];
      if (templateId is! String || templateId.trim() != item.template.id) {
        throw const FormatException(
          'The workout preview template is no longer available.',
        );
      }
    }

    final rawGroups = root['groups'];
    final groups = _parseGroups(rawGroups);
    final groupByPrescriptionId = <String, String>{};
    for (final group in groups) {
      for (final member in group.members) {
        if (groupByPrescriptionId.containsKey(member.exercisePrescriptionId)) {
          throw const FormatException(
            'The workout preview contains a duplicate group member.',
          );
        }
        groupByPrescriptionId[member.exercisePrescriptionId] = group.id;
      }
    }

    final rawPrescriptions = root['prescriptions'];
    if (rawPrescriptions is! List) {
      throw const FormatException(
        'The workout preview has no planned exercises.',
      );
    }
    final exercises = <TrainingWorkoutPreviewExercise>[];
    for (var index = 0; index < rawPrescriptions.length; index++) {
      final raw = rawPrescriptions[index];
      final prescription = _decodeObjectValue(raw, 'exercise prescription');
      final id = _requiredString(prescription['id'], 'prescription ID');
      final ordinal = _requiredNonNegativeInt(
        prescription['ordinal'],
        'exercise order',
      );
      if (ordinal != index) {
        throw const FormatException(
          'The planned exercise order is unavailable.',
        );
      }
      final name = _requiredString(
        prescription['exerciseNameSnapshot'],
        'exercise name',
      );
      final plannedSets = _requiredPositiveInt(
        prescription['plannedSets'],
        'planned sets',
      );
      final repsRange = _requiredString(
        prescription['repsRange'],
        'planned repetitions',
      );
      exercises.add(
        TrainingWorkoutPreviewExercise(
          prescriptionId: id,
          name: name,
          plannedSets: plannedSets,
          repsRange: repsRange,
          groupId: groupByPrescriptionId[id],
          targets: _parseTargets(
            prescription['strengthSetPrescriptions'],
            prescriptionId: id,
          ),
        ),
      );
    }
    _validatePrescriptionIdentity(item, exercises);

    final activityType = root['activityType'];
    final decodedActivityType =
        activityType is String && activityType.trim().isNotEmpty
        ? activityType.trim()
        : item.template.activityType;
    final durationSeconds = _optionalPositiveInt(
      root['durationSeconds'],
      'duration',
    );

    return TrainingWorkoutPreviewData(
      occurrenceItem: item,
      workoutName: item.template.name,
      activityType: decodedActivityType,
      exercises: exercises,
      groups: groups
          .map(
            (group) => TrainingWorkoutPreviewGroup.fromB02(
              group,
              exerciseNames: {
                for (final exercise in exercises)
                  exercise.prescriptionId: exercise.name,
              },
            ),
          )
          .toList(growable: false),
      substitutions: _parseSubstitutions(root['substitutions']),
      durationSeconds: durationSeconds,
      isSnapshotBacked: true,
    );
  }

  static TrainingWorkoutPreviewData _fromReadItem(
    CalendarOccurrenceReadItem item,
  ) {
    final exercises = item.prescriptions
        .map(
          (prescription) => TrainingWorkoutPreviewExercise(
            prescriptionId: prescription.id,
            name: _requiredString(
              prescription.exerciseNameSnapshot,
              'exercise name',
            ),
            plannedSets: _requiredPositiveInt(
              prescription.plannedSets,
              'planned sets',
            ),
            repsRange: _requiredString(
              prescription.repsRange,
              'planned repetitions',
            ),
            targets: const [],
          ),
        )
        .toList(growable: false);
    return TrainingWorkoutPreviewData(
      occurrenceItem: item,
      workoutName: item.template.name,
      activityType: item.template.activityType,
      exercises: exercises,
      groups: const [],
      substitutions: const [],
      durationSeconds: null,
      isSnapshotBacked: false,
    );
  }

  static void _validatePrescriptionIdentity(
    CalendarOccurrenceReadItem item,
    List<TrainingWorkoutPreviewExercise> exercises,
  ) {
    if (item.prescriptions.isEmpty) return;
    final expected = item.prescriptions.map((item) => item.id).toList();
    final actual = exercises.map((item) => item.prescriptionId).toList();
    if (expected.length != actual.length ||
        expected.toSet().length != expected.length ||
        !List.generate(
          expected.length,
          (index) => index,
        ).every((index) => expected[index] == actual[index])) {
      throw const FormatException(
        'The workout preview does not match its planned exercises.',
      );
    }
  }
}

class TrainingWorkoutPreviewExercise {
  const TrainingWorkoutPreviewExercise({
    required this.prescriptionId,
    required this.name,
    required this.plannedSets,
    required this.repsRange,
    this.groupId,
    this.targets = const [],
  });

  final String prescriptionId;
  final String name;
  final int plannedSets;
  final String repsRange;
  final String? groupId;
  final List<TrainingWorkoutPreviewSetTarget> targets;
}

class TrainingWorkoutPreviewSetTarget {
  const TrainingWorkoutPreviewSetTarget({
    required this.ordinal,
    this.targetLoadKg,
    this.loadBasis,
    this.targetRepsMin,
    this.targetRepsMax,
    this.targetRpe,
    this.restSeconds,
    this.effortMode = B02EffortMode.standard,
  });

  final int ordinal;
  final double? targetLoadKg;
  final B02LoadBasis? loadBasis;
  final int? targetRepsMin;
  final int? targetRepsMax;
  final int? targetRpe;
  final int? restSeconds;
  final B02EffortMode effortMode;
}

class TrainingWorkoutPreviewGroup {
  const TrainingWorkoutPreviewGroup({
    required this.id,
    required this.ordinal,
    required this.groupType,
    required this.roundCount,
    required this.label,
    required this.members,
    this.restAfterRoundSeconds,
  });

  final String id;
  final int ordinal;
  final B02GroupType groupType;
  final int roundCount;
  final int? restAfterRoundSeconds;
  final String? label;
  final List<TrainingWorkoutPreviewGroupMember> members;

  String get typeLabel => switch (groupType) {
    B02GroupType.superset => 'Superset',
    B02GroupType.circuit => 'Circuit',
    B02GroupType.giantSet => 'Giant set',
  };

  String get title => label?.trim().isNotEmpty == true
      ? label!.trim()
      : '$typeLabel ${ordinal + 1}';

  factory TrainingWorkoutPreviewGroup.fromB02(
    B02ExerciseGroup group, {
    required Map<String, String> exerciseNames,
  }) {
    final members = group.members
        .map(
          (member) => TrainingWorkoutPreviewGroupMember(
            exercisePrescriptionId: member.exercisePrescriptionId,
            name:
                exerciseNames[member.exercisePrescriptionId] ??
                (throw const FormatException(
                  'A grouped exercise is not in the planned order.',
                )),
            transitionRestSeconds: member.transitionRestSeconds,
          ),
        )
        .toList(growable: false);
    return TrainingWorkoutPreviewGroup(
      id: group.id,
      ordinal: group.ordinal,
      groupType: group.groupType,
      roundCount: group.roundCount,
      restAfterRoundSeconds: group.restAfterRoundSeconds,
      label: group.label,
      members: members,
    );
  }
}

class TrainingWorkoutPreviewGroupMember {
  const TrainingWorkoutPreviewGroupMember({
    required this.exercisePrescriptionId,
    required this.name,
    this.transitionRestSeconds,
  });

  final String exercisePrescriptionId;
  final String name;
  final int? transitionRestSeconds;
}

class TrainingWorkoutPreviewSubstitution {
  const TrainingWorkoutPreviewSubstitution({
    required this.expectedName,
    required this.actualName,
  });

  final String expectedName;
  final String actualName;
}

/// Read-only preview surface. The callbacks deliberately route back to the
/// existing start/occurrence commands; this widget owns no schedule or draft
/// mutation and never creates a second picker.
class TrainingWorkoutPreviewScreen extends StatefulWidget {
  const TrainingWorkoutPreviewScreen({
    required this.preview,
    required this.onStartWorkout,
    required this.onOpenScheduleActions,
    super.key,
  });

  final TrainingWorkoutPreviewData preview;
  final VoidCallback onStartWorkout;
  final VoidCallback onOpenScheduleActions;

  @override
  State<TrainingWorkoutPreviewScreen> createState() =>
      _TrainingWorkoutPreviewScreenState();
}

class _TrainingWorkoutPreviewScreenState
    extends State<TrainingWorkoutPreviewScreen> {
  var _actionInFlight = false;

  TrainingWorkoutPreviewData get preview => widget.preview;

  void _startWorkout() {
    if (_actionInFlight || !preview.hasDetails) return;
    setState(() => _actionInFlight = true);
    Navigator.of(context).pop();
    widget.onStartWorkout();
  }

  Future<void> _showCustomizeToday() async {
    if (_actionInFlight || !preview.hasDetails) return;
    final action = await showModalBottomSheet<_TodayCustomizationAction>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            B05Layout.space8,
            B05Layout.space8,
            B05Layout.space8,
            B05Layout.space16,
          ),
          children: [
            ListTile(
              title: Text(
                'Customize today',
                style: B05Typography.title(sheetContext),
              ),
              subtitle: const Text(
                'Changes here stay with this workout and do not edit future plan days.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat_outlined),
              title: const Text('Move or skip this workout'),
              subtitle: const Text(
                'Use the existing schedule controls for today’s occurrence.',
              ),
              onTap: () => Navigator.pop(
                sheetContext,
                _TodayCustomizationAction.schedule,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Edit exercises and sets'),
              subtitle: const Text(
                'Open the workout to use its existing replacement and set controls.',
              ),
              onTap: () => Navigator.pop(
                sheetContext,
                _TodayCustomizationAction.execution,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _TodayCustomizationAction.schedule) {
      Navigator.of(context).pop();
      widget.onOpenScheduleActions();
      return;
    }
    _startWorkout();
  }

  @override
  Widget build(BuildContext context) {
    final item = preview.occurrenceItem;
    final occurrence = item.occurrence;
    final dateLabel = ConsumerDateLabel.day(occurrence.effectiveLocalDate);
    final statusLabel = _statusLabel(occurrence.status, dateLabel);
    final activityLabel = _activityLabel(preview.activityType);
    final countLabel =
        '${preview.exercises.length} ${preview.exercises.length == 1 ? 'exercise' : 'exercises'}';
    final canStart =
        preview.hasDetails &&
        (occurrence.status == 'planned' || occurrence.status == 'rescheduled');

    return Scaffold(
      appBar: AppBar(title: const Text('Workout preview')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            B05Layout.space16,
            B05Layout.space12,
            B05Layout.space16,
            B05Layout.space32,
          ),
          children: [
            Semantics(
              container: true,
              excludeSemantics: true,
              label:
                  'Today’s planned workout preview. ${preview.workoutName}. $statusLabel. $countLabel.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("TODAY'S WORKOUT", style: _previewEyebrow(context)),
                  const SizedBox(height: B05Layout.space4),
                  Text(
                    preview.workoutName,
                    style: B05Typography.pageTitle(context),
                  ),
                  const SizedBox(height: B05Layout.space4),
                  Text(
                    '$statusLabel · $activityLabel · $countLabel',
                    style: B05Typography.body(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: B05Layout.space12),
            B05Surface(
              tone: B05SurfaceTone.inset,
              padding: const EdgeInsets.all(B05Layout.space12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.route_outlined, color: context.b05Colors.action),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PLANNED CONTEXT',
                          style: _previewEyebrow(context),
                        ),
                        const SizedBox(height: B05Layout.space4),
                        Text(
                          '${item.block.name} · Week ${item.week.programWeekOrdinal + 1}',
                          style: B05Typography.label(context),
                        ),
                        if (item.isDeload)
                          Text(
                            'Deload week',
                            style: B05Typography.caption(context),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (canStart) ...[
              const SizedBox(height: B05Layout.space12),
              B05ActionButton(
                label: 'Start workout',
                hint: 'Open this exact planned workout.',
                icon: Icons.play_arrow_rounded,
                onPressed: _actionInFlight ? null : _startWorkout,
              ),
              const SizedBox(height: B05Layout.space8),
              Align(
                alignment: Alignment.centerLeft,
                child: B05ActionButton(
                  label: 'Customize today',
                  hint:
                      'Move this workout or edit it using existing workout controls.',
                  icon: Icons.tune_rounded,
                  emphasis: B05ActionEmphasis.tertiary,
                  onPressed: _actionInFlight ? null : _showCustomizeToday,
                ),
              ),
            ],
            if (!preview.hasDetails) ...[
              const SizedBox(height: B05Layout.space12),
              _PreviewUnavailableCard(
                message:
                    'The planned exercise details are unavailable right now. Try again from Training.',
              ),
            ],
            if (preview.groups.isNotEmpty) ...[
              const SizedBox(height: B05Layout.space16),
              const _PreviewSectionLabel(label: 'PLANNED STRUCTURE'),
              const SizedBox(height: B05Layout.space8),
              _PreviewGroups(groups: preview.groups),
            ],
            if (preview.exercises.isNotEmpty) ...[
              const SizedBox(height: B05Layout.space16),
              const _PreviewSectionLabel(label: 'PLANNED EXERCISES'),
              const SizedBox(height: B05Layout.space8),
              _PreviewExerciseList(exercises: preview.exercises),
            ],
            if (preview.hasPlannedTargets) ...[
              const SizedBox(height: B05Layout.space12),
              B05Surface(
                tone: B05SurfaceTone.inset,
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  title: const Text('Show planned targets'),
                  subtitle: const Text(
                    'Load, reps, effort, and rest when set.',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    B05Layout.space12,
                    0,
                    B05Layout.space12,
                    B05Layout.space12,
                  ),
                  children: [
                    for (final exercise in preview.exercises)
                      if (exercise.targets.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            exercise.name,
                            style: B05Typography.label(context),
                          ),
                        ),
                        const SizedBox(height: B05Layout.space4),
                        for (final target in exercise.targets)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: B05Layout.space4,
                              ),
                              child: Text(
                                'Planned set ${target.ordinal + 1}: ${_targetFacts(target)}',
                                style: B05Typography.caption(context),
                              ),
                            ),
                          ),
                        const SizedBox(height: B05Layout.space4),
                      ],
                  ],
                ),
              ),
            ],
            if (preview.substitutions.isNotEmpty) ...[
              const SizedBox(height: B05Layout.space16),
              const _PreviewSectionLabel(label: 'PLANNED CHANGES'),
              const SizedBox(height: B05Layout.space8),
              B05Surface(
                tone: B05SurfaceTone.inset,
                padding: const EdgeInsets.all(B05Layout.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final substitution in preview.substitutions)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: B05Layout.space4,
                        ),
                        child: Text(
                          '${substitution.expectedName} → ${substitution.actualName}',
                          style: B05Typography.body(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (preview.durationSeconds != null) ...[
              const SizedBox(height: B05Layout.space12),
              Text(
                'Planned duration · ${_durationLabel(preview.durationSeconds!)}',
                style: B05Typography.caption(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _TodayCustomizationAction { schedule, execution }

class _PreviewGroups extends StatelessWidget {
  const _PreviewGroups({required this.groups});

  final List<TrainingWorkoutPreviewGroup> groups;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: context.b05Colors.selected,
              child: Text('${index + 1}'),
            ),
            title: Text(groups[index].title),
            subtitle: Text(
              '${groups[index].typeLabel} · ${groups[index].roundCount} ${groups[index].roundCount == 1 ? 'round' : 'rounds'}\n'
              '${groups[index].members.map((member) => member.name).join(' · ')}',
            ),
            isThreeLine: true,
          ),
          if (groups[index].restAfterRoundSeconds != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                B05Layout.space16,
                0,
                B05Layout.space16,
                B05Layout.space8,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Rest after each round · ${groups[index].restAfterRoundSeconds}s',
                  style: B05Typography.caption(context),
                ),
              ),
            ),
          if (index < groups.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

class _PreviewExerciseList extends StatelessWidget {
  const _PreviewExerciseList({required this.exercises});

  final List<TrainingWorkoutPreviewExercise> exercises;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < exercises.length; index++) ...[
          ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: context.b05Colors.selected,
              child: Text('${index + 1}'),
            ),
            title: Text(exercises[index].name),
            subtitle: Text(
              '${exercises[index].plannedSets} ${exercises[index].plannedSets == 1 ? 'set' : 'sets'} · ${exercises[index].repsRange} reps',
            ),
          ),
          if (index < exercises.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

class _PreviewUnavailableCard extends StatelessWidget {
  const _PreviewUnavailableCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    padding: const EdgeInsets.all(B05Layout.space12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: context.b05Colors.unavailable.indicator,
        ),
        const SizedBox(width: B05Layout.space8),
        Expanded(child: Text(message, style: B05Typography.body(context))),
      ],
    ),
  );
}

class _PreviewSectionLabel extends StatelessWidget {
  const _PreviewSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: _previewEyebrow(
      context,
    ).copyWith(color: context.b05Colors.textSecondary),
  );
}

TextStyle _previewEyebrow(BuildContext context) => B05Typography.caption(
  context,
).copyWith(fontWeight: FontWeight.w700, letterSpacing: .8);

String _activityLabel(String value) => switch (value) {
  'strength' => 'Strength',
  'running' => 'Run',
  'cycling' => 'Ride',
  'walking' => 'Walk',
  'yoga' => 'Yoga',
  'mobility' => 'Mobility',
  _ => 'Workout',
};

String _statusLabel(String status, String dateLabel) => switch (status) {
  'planned' => 'Planned · $dateLabel',
  'rescheduled' => 'Planned · moved to $dateLabel',
  'inProgress' => 'In progress · $dateLabel',
  'completed' => 'Completed · $dateLabel',
  'partiallyCompleted' => 'Partially completed · $dateLabel',
  'skipped' => 'Skipped · $dateLabel',
  'cancelled' => 'Cancelled · $dateLabel',
  _ => 'Status unavailable · $dateLabel',
};

String _targetFacts(TrainingWorkoutPreviewSetTarget target) {
  final facts = <String>[];
  final reps = _repsLabel(target.targetRepsMin, target.targetRepsMax);
  if (reps != null) facts.add(reps);
  final load = _loadLabel(target.targetLoadKg, target.loadBasis);
  if (load != null) facts.add(load);
  if (target.targetRpe != null) facts.add('RPE ${target.targetRpe}');
  final effort = _effortLabel(target.effortMode);
  if (effort != null) facts.add(effort);
  if (target.restSeconds != null) facts.add('${target.restSeconds}s rest');
  return facts.isEmpty ? 'Target details unavailable' : facts.join(' · ');
}

String? _repsLabel(int? minimum, int? maximum) {
  if (minimum == null && maximum == null) return null;
  if (minimum != null && maximum != null && minimum == maximum) {
    return '$minimum reps';
  }
  if (minimum != null && maximum != null) return '$minimum–$maximum reps';
  return '${minimum ?? maximum} reps';
}

String? _loadLabel(double? load, B02LoadBasis? basis) {
  if (basis == B02LoadBasis.bodyweight) return 'Bodyweight';
  if (load == null) return null;
  final value = load == load.roundToDouble()
      ? load.toStringAsFixed(0)
      : load.toStringAsFixed(1);
  return switch (basis) {
    B02LoadBasis.perSide => '$value kg each side',
    B02LoadBasis.perImplement => '$value kg each implement',
    B02LoadBasis.totalExternal || null => '$value kg',
    B02LoadBasis.bodyweight => 'Bodyweight',
  };
}

String? _effortLabel(B02EffortMode effortMode) => switch (effortMode) {
  B02EffortMode.standard => null,
  B02EffortMode.amrap => 'As many as possible',
  B02EffortMode.toFailure => 'To failure',
};

String _durationLabel(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  if (remaining == 0) return '$minutes min';
  return '$minutes min ${remaining}s';
}

Map<String, dynamic> _decodeObject(String value, String label) {
  try {
    final decoded = jsonDecode(value);
    return _decodeObjectValue(decoded, label);
  } on FormatException {
    rethrow;
  } on Object {
    throw FormatException('The $label is unavailable.');
  }
}

Map<String, dynamic> _decodeObjectValue(Object? value, String label) {
  if (value is! Map) throw FormatException('The $label is unavailable.');
  return Map<String, dynamic>.from(value);
}

String _requiredString(Object? value, String label) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('The planned $label is unavailable.');
  }
  return value.trim();
}

int _requiredPositiveInt(Object? value, String label) {
  if (value is! int || value < 1) {
    throw FormatException('The planned $label is unavailable.');
  }
  return value;
}

int _requiredNonNegativeInt(Object? value, String label) {
  if (value is! int || value < 0) {
    throw FormatException('The planned $label is unavailable.');
  }
  return value;
}

int? _optionalPositiveInt(Object? value, String label) {
  if (value == null) return null;
  return _requiredPositiveInt(value, label);
}

List<B02ExerciseGroup> _parseGroups(Object? rawGroups) {
  if (rawGroups == null) return const [];
  if (rawGroups is! List) {
    throw const FormatException(
      'The planned workout structure is unavailable.',
    );
  }
  final groups = <B02ExerciseGroup>[];
  for (final raw in rawGroups) {
    try {
      groups.add(B02ExerciseGroup.fromJson(_decodeObjectValue(raw, 'group')));
    } on B02ValidationException catch (error) {
      throw FormatException(
        'The planned workout structure is unavailable: $error',
      );
    }
  }
  groups.sort((left, right) => left.ordinal.compareTo(right.ordinal));
  for (var index = 0; index < groups.length; index++) {
    if (groups[index].ordinal != index) {
      throw const FormatException(
        'The planned workout structure is unavailable.',
      );
    }
  }
  return groups;
}

List<TrainingWorkoutPreviewSetTarget> _parseTargets(
  Object? rawTargets, {
  required String prescriptionId,
}) {
  if (rawTargets == null) return const [];
  if (rawTargets is! List) {
    throw const FormatException('The planned set details are unavailable.');
  }
  final targets = <TrainingWorkoutPreviewSetTarget>[];
  for (final raw in rawTargets) {
    final target = _decodeObjectValue(raw, 'planned set');
    final targetPrescriptionId = target['exercisePrescriptionId'];
    if (targetPrescriptionId is! String ||
        targetPrescriptionId.trim() != prescriptionId) {
      throw const FormatException(
        'The planned set points to another exercise.',
      );
    }
    late final B02StrengthSetPrescription parsed;
    try {
      parsed = B02StrengthSetPrescription.fromJson(target);
    } on B02ValidationException {
      throw const FormatException('The planned set details are unavailable.');
    }
    targets.add(
      TrainingWorkoutPreviewSetTarget(
        ordinal: parsed.ordinal,
        targetLoadKg: parsed.targetLoadKg,
        loadBasis: parsed.loadBasis,
        targetRepsMin: parsed.targetRepsMin,
        targetRepsMax: parsed.targetRepsMax,
        targetRpe: parsed.targetRpe,
        restSeconds: parsed.restSeconds,
        effortMode: parsed.technique.effortMode,
      ),
    );
  }
  targets.sort((left, right) => left.ordinal.compareTo(right.ordinal));
  for (var index = 0; index < targets.length; index++) {
    if (targets[index].ordinal != index) {
      throw const FormatException('The planned set order is unavailable.');
    }
  }
  return targets;
}

List<TrainingWorkoutPreviewSubstitution> _parseSubstitutions(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw const FormatException('The workout substitutions are unavailable.');
  }
  return [
    for (final value in raw)
      _parseSubstitution(_decodeObjectValue(value, 'substitution')),
  ];
}

TrainingWorkoutPreviewSubstitution _parseSubstitution(
  Map<String, dynamic> value,
) {
  final expected =
      value['expectedExerciseNameSnapshot'] ?? value['expectedName'];
  final actual = value['actualExerciseNameSnapshot'] ?? value['actualName'];
  return TrainingWorkoutPreviewSubstitution(
    expectedName: _requiredString(expected, 'original exercise'),
    actualName: _requiredString(actual, 'replacement exercise'),
  );
}
