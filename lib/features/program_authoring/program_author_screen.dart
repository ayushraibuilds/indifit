import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_count_label.dart';
import '../../core/theme/colors.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/program_repository.dart';
import '../exercise_picker/exercise_picker.dart';
import '../workout_player/widgets/b02_execution_semantics.dart';
import 'program_authoring_controller.dart';

/// Screen for creating, editing, and copying draft training programs.
class ProgramAuthorScreen extends ConsumerStatefulWidget {
  final String? programId;
  final String? programVersionId;

  const ProgramAuthorScreen({super.key, this.programId, this.programVersionId});

  @override
  ConsumerState<ProgramAuthorScreen> createState() =>
      _ProgramAuthorScreenState();
}

class _ProgramAuthorScreenState extends ConsumerState<ProgramAuthorScreen> {
  final TextEditingController _programNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _currentProgramId;
  String? _currentVersionId;
  bool _isDraftVersion = true;
  List<ProgramBlockInput> _blocks = [];

  @override
  void initState() {
    super.initState();
    _currentProgramId = widget.programId;
    _currentVersionId = widget.programVersionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadOrCreateDraft();
    });
  }

  @override
  void dispose() {
    _programNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadOrCreateDraft() async {
    final authoring = ref.read(programAuthoringControllerProvider.notifier);
    authoring.beginLoading();
    try {
      final repo = ref.read(programRepositoryProvider);
      var loadedExisting = false;

      if (_currentVersionId != null) {
        final versionDetail = await repo.getProgramVersionDetail(
          _currentVersionId!,
        );
        if (versionDetail == null) {
          throw StateError('The selected plan is unavailable.');
        }
        _programNameController.text = versionDetail.program.name;
        _descriptionController.text = versionDetail.program.notes ?? '';
        _currentProgramId = versionDetail.program.id;
        _isDraftVersion = versionDetail.version.status == 'draft';
        _blocks = _mapDetailToBlockInputs(versionDetail);
        loadedExisting = true;
      } else if (_currentProgramId != null) {
        final versions = await repo.getVersionsForProgram(_currentProgramId!);
        if (versions.isEmpty) {
          throw StateError('The selected plan is unavailable.');
        }
        final detail = await repo.getProgramVersionDetail(versions.last.id);
        if (detail == null) {
          throw StateError('The selected plan is unavailable.');
        }
        _programNameController.text = detail.program.name;
        _descriptionController.text = detail.program.notes ?? '';
        _currentVersionId = detail.version.id;
        _isDraftVersion = detail.version.status == 'draft';
        _blocks = _mapDetailToBlockInputs(detail);
        loadedExisting = true;
      }

      if (!loadedExisting) {
        _programNameController.text = _programNameController.text.trim().isEmpty
            ? 'New plan'
            : _programNameController.text;
        _blocks = [
          ProgramBlockInput(
            name: 'Block 1',
            ordinal: 0,
            weeks: [
              ProgramWeekInput(
                name: 'Week 1',
                ordinalInBlock: 0,
                programWeekOrdinal: 0,
                templates: [
                  SessionTemplateInput(
                    name: 'Workout 1',
                    ordinal: 0,
                    plannedWeekday: 1,
                    prescriptions: const [],
                  ),
                ],
              ),
            ],
          ),
        ];
      }
      authoring.markReady();
    } catch (error) {
      authoring.markFailure(error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The plan could not be loaded. Try again.'),
          ),
        );
      }
    }
  }

  List<ProgramBlockInput> _mapDetailToBlockInputs(
    ProgramDetailAggregate detail,
  ) {
    return detail.blocks.map((b) {
      return ProgramBlockInput(
        name: b.name,
        description: b.description,
        ordinal: b.ordinal,
        weeks: detail.weeks.where((w) => w.programBlockId == b.id).map((w) {
          return ProgramWeekInput(
            ordinalInBlock: w.ordinalInBlock,
            programWeekOrdinal: w.programWeekOrdinal,
            isDeload: w.isDeload,
            templates: detail.sessionTemplates
                .where((st) => st.programWeekId == w.id)
                .map((st) {
                  return SessionTemplateInput(
                    name: st.name,
                    ordinal: st.ordinal,
                    plannedWeekday: st.plannedWeekday,
                    plannedStartMinute: st.plannedStartMinute,
                    notes: st.notes,
                    prescriptions: detail.exercisePrescriptions
                        .where((ep) => ep.sessionTemplateId == st.id)
                        .map((ep) {
                          return ExercisePrescriptionInput(
                            id: ep.id,
                            exerciseId: ep.exerciseId,
                            exerciseNameSnapshot: ep.exerciseNameSnapshot,
                            plannedSets: ep.plannedSets,
                            repsRange: ep.repsRange,
                            ordinal: ep.ordinal,
                            allowUnresolvedExerciseFallback:
                                ep.exerciseId == null,
                          );
                        })
                        .toList(),
                    groups: detail.groups
                        .where((group) => group.sessionTemplateId == st.id)
                        .map(
                          (group) => ExerciseGroupInput(
                            id: group.id,
                            ordinal: group.ordinal,
                            groupType: B02GroupType.parse(group.groupType),
                            roundCount: group.roundCount,
                            restAfterRoundSeconds: group.restAfterRoundSeconds,
                            label: group.label,
                            members: detail.groupMembers
                                .where(
                                  (member) =>
                                      member.exerciseGroupId == group.id,
                                )
                                .map(
                                  (member) => ExerciseGroupMemberInput(
                                    id: member.id,
                                    exercisePrescriptionId:
                                        member.exercisePrescriptionId,
                                    ordinal: member.ordinal,
                                    transitionRestSeconds:
                                        member.transitionRestSeconds,
                                  ),
                                )
                                .toList(),
                          ),
                        )
                        .toList(),
                  );
                })
                .toList(),
          );
        }).toList(),
      );
    }).toList();
  }

  void _replaceBlocks(List<ProgramBlockInput> blocks) {
    setState(() => _blocks = _reindexBlocks(blocks));
    ref.read(programAuthoringControllerProvider.notifier).markEdited();
  }

  List<ProgramBlockInput> _reindexBlocks(List<ProgramBlockInput> blocks) {
    var programWeekOrdinal = 0;
    return List<ProgramBlockInput>.generate(blocks.length, (blockIndex) {
      final block = blocks[blockIndex];
      final weeks = List<ProgramWeekInput>.generate(block.weeks.length, (
        weekIndex,
      ) {
        final week = block.weeks[weekIndex];
        final templates = List<SessionTemplateInput>.generate(
          week.templates.length,
          (templateIndex) {
            final template = week.templates[templateIndex];
            final prescriptions = List<ExercisePrescriptionInput>.generate(
              template.prescriptions.length,
              (prescriptionIndex) {
                final prescription = template.prescriptions[prescriptionIndex];
                return ExercisePrescriptionInput(
                  id: prescription.id,
                  exerciseId: prescription.exerciseId,
                  exerciseNameSnapshot: prescription.exerciseNameSnapshot,
                  plannedSets: prescription.plannedSets,
                  repsRange: prescription.repsRange,
                  ordinal: prescriptionIndex,
                  allowUnresolvedExerciseFallback:
                      prescription.allowUnresolvedExerciseFallback,
                );
              },
            );
            return SessionTemplateInput(
              name: template.name,
              ordinal: templateIndex,
              plannedWeekday: template.plannedWeekday,
              plannedStartMinute: template.plannedStartMinute,
              notes: template.notes,
              prescriptions: prescriptions,
              groups: template.groups
                  .asMap()
                  .entries
                  .map(
                    (groupEntry) => ExerciseGroupInput(
                      id: groupEntry.value.id,
                      ordinal: groupEntry.key,
                      groupType: groupEntry.value.groupType,
                      roundCount: groupEntry.value.roundCount,
                      restAfterRoundSeconds:
                          groupEntry.value.restAfterRoundSeconds,
                      label: groupEntry.value.label,
                      members: groupEntry.value.members
                          .asMap()
                          .entries
                          .map(
                            (memberEntry) => ExerciseGroupMemberInput(
                              id: memberEntry.value.id,
                              exercisePrescriptionId:
                                  memberEntry.value.exercisePrescriptionId,
                              ordinal: memberEntry.key,
                              transitionRestSeconds:
                                  memberEntry.value.transitionRestSeconds,
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            );
          },
        );
        return ProgramWeekInput(
          name: week.name,
          ordinalInBlock: weekIndex,
          programWeekOrdinal: programWeekOrdinal++,
          isDeload: week.isDeload,
          templates: templates,
        );
      });
      return ProgramBlockInput(
        name: block.name,
        description: block.description,
        ordinal: blockIndex,
        weeks: weeks,
      );
    });
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value?.isEmpty ?? true ? null : value;
  }

  Future<void> _addBlock() async {
    final name = await _promptText(
      title: 'Add progression block',
      label: 'Block name',
      initialValue: 'Block ${_blocks.length + 1}',
    );
    if (name == null) return;
    _replaceBlocks([
      ..._blocks,
      ProgramBlockInput(name: name, ordinal: _blocks.length, weeks: const []),
    ]);
  }

  Future<void> _renameBlock(int blockIndex) async {
    final block = _blocks[blockIndex];
    final name = await _promptText(
      title: 'Edit block',
      label: 'Block name',
      initialValue: block.name,
    );
    if (name == null) return;
    final updated = [..._blocks];
    updated[blockIndex] = ProgramBlockInput(
      name: name,
      description: block.description,
      ordinal: block.ordinal,
      weeks: block.weeks,
    );
    _replaceBlocks(updated);
  }

  void _deleteBlock(int blockIndex) {
    final updated = [..._blocks]..removeAt(blockIndex);
    _replaceBlocks(updated);
  }

  Future<void> _addWeek(int blockIndex) async {
    final name = await _promptText(
      title: 'Add week',
      label: 'Week name (optional)',
      initialValue: 'Week ${_blocks[blockIndex].weeks.length + 1}',
    );
    if (name == null) return;
    final updated = [..._blocks];
    final block = updated[blockIndex];
    updated[blockIndex] = ProgramBlockInput(
      name: block.name,
      description: block.description,
      ordinal: block.ordinal,
      weeks: [
        ...block.weeks,
        ProgramWeekInput(
          name: name,
          ordinalInBlock: block.weeks.length,
          programWeekOrdinal: 0,
          templates: const [],
        ),
      ],
    );
    _replaceBlocks(updated);
  }

  Future<void> _renameWeek(int blockIndex, int weekIndex) async {
    final week = _blocks[blockIndex].weeks[weekIndex];
    final name = await _promptText(
      title: 'Edit week',
      label: 'Week name',
      initialValue: week.name ?? 'Week ${week.programWeekOrdinal + 1}',
    );
    if (name == null) return;
    final updated = [..._blocks];
    final block = updated[blockIndex];
    final weeks = [...block.weeks];
    weeks[weekIndex] = ProgramWeekInput(
      name: name,
      ordinalInBlock: week.ordinalInBlock,
      programWeekOrdinal: week.programWeekOrdinal,
      isDeload: week.isDeload,
      templates: week.templates,
    );
    updated[blockIndex] = ProgramBlockInput(
      name: block.name,
      description: block.description,
      ordinal: block.ordinal,
      weeks: weeks,
    );
    _replaceBlocks(updated);
  }

  void _deleteWeek(int blockIndex, int weekIndex) {
    final updated = [..._blocks];
    final block = updated[blockIndex];
    final weeks = [...block.weeks]..removeAt(weekIndex);
    updated[blockIndex] = ProgramBlockInput(
      name: block.name,
      description: block.description,
      ordinal: block.ordinal,
      weeks: weeks,
    );
    _replaceBlocks(updated);
  }

  void _setWeekDeload(int blockIndex, int weekIndex, bool isDeload) {
    final updated = [..._blocks];
    final block = updated[blockIndex];
    final weeks = [...block.weeks];
    final week = weeks[weekIndex];
    weeks[weekIndex] = ProgramWeekInput(
      name: week.name,
      ordinalInBlock: week.ordinalInBlock,
      programWeekOrdinal: week.programWeekOrdinal,
      isDeload: isDeload,
      templates: week.templates,
    );
    updated[blockIndex] = ProgramBlockInput(
      name: block.name,
      description: block.description,
      ordinal: block.ordinal,
      weeks: weeks,
    );
    _replaceBlocks(updated);
  }

  Future<({String name, int weekday, int? startMinute})?>
  _promptSessionTemplate({
    required String title,
    required String initialName,
    required int initialWeekday,
    required int? initialStartMinute,
  }) async {
    final controller = TextEditingController(text: initialName);
    var weekday = initialWeekday;
    var startMinute = initialStartMinute;
    String? error;
    final result =
        await showDialog<({String name, int weekday, int? startMinute})>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Workout name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: weekday,
                    decoration: const InputDecoration(labelText: 'Day of week'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Monday')),
                      DropdownMenuItem(value: 2, child: Text('Tuesday')),
                      DropdownMenuItem(value: 3, child: Text('Wednesday')),
                      DropdownMenuItem(value: 4, child: Text('Thursday')),
                      DropdownMenuItem(value: 5, child: Text('Friday')),
                      DropdownMenuItem(value: 6, child: Text('Saturday')),
                      DropdownMenuItem(value: 7, child: Text('Sunday')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => weekday = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final current = startMinute == null
                            ? TimeOfDay.now()
                            : TimeOfDay(
                                hour: startMinute! ~/ 60,
                                minute: startMinute! % 60,
                              );
                        final picked = await showTimePicker(
                          context: dialogContext,
                          initialTime: current,
                        );
                        if (picked != null) {
                          setDialogState(
                            () =>
                                startMinute = picked.hour * 60 + picked.minute,
                          );
                        }
                      },
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(
                        startMinute == null
                            ? 'Add a start time (optional)'
                            : 'Starts at ${_formatTime(startMinute!)}',
                      ),
                    ),
                  ),
                  if (startMinute != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () =>
                            setDialogState(() => startMinute = null),
                        child: const Text('Clear start time'),
                      ),
                    ),
                  if (error != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) {
                      setDialogState(() => error = 'Enter a workout name.');
                      return;
                    }
                    Navigator.pop(dialogContext, (
                      name: controller.text.trim(),
                      weekday: weekday,
                      startMinute: startMinute,
                    ));
                  },
                  child: Text(title.startsWith('Add') ? 'Add workout' : 'Save'),
                ),
              ],
            ),
          ),
        );
    controller.dispose();
    return result;
  }

  Future<void> _addSessionTemplate(int blockIndex, int weekIndex) async {
    final week = _blocks[blockIndex].weeks[weekIndex];
    final result = await _promptSessionTemplate(
      title: 'Add workout',
      initialName: 'Workout ${week.templates.length + 1}',
      initialWeekday: DateTime.monday,
      initialStartMinute: null,
    );
    if (result == null) return;
    final block = _blocks[blockIndex];
    final weeks = [...block.weeks];
    weeks[weekIndex] = ProgramWeekInput(
      name: week.name,
      ordinalInBlock: week.ordinalInBlock,
      programWeekOrdinal: week.programWeekOrdinal,
      isDeload: week.isDeload,
      templates: [
        ...week.templates,
        SessionTemplateInput(
          name: result.name,
          ordinal: week.templates.length,
          plannedWeekday: result.weekday,
          plannedStartMinute: result.startMinute,
          prescriptions: const [],
        ),
      ],
    );
    final updated = [..._blocks];
    updated[blockIndex] = ProgramBlockInput(
      name: block.name,
      description: block.description,
      ordinal: block.ordinal,
      weeks: weeks,
    );
    _replaceBlocks(updated);
  }

  Future<void> _editSessionTemplate(
    int blockIndex,
    int weekIndex,
    int templateIndex,
  ) async {
    final template =
        _blocks[blockIndex].weeks[weekIndex].templates[templateIndex];
    final result = await _promptSessionTemplate(
      title: 'Edit workout',
      initialName: template.name,
      initialWeekday: template.plannedWeekday,
      initialStartMinute: template.plannedStartMinute,
    );
    if (result == null) return;
    _replaceTemplate(
      blockIndex,
      weekIndex,
      templateIndex,
      _copyTemplate(
        template,
        name: result.name,
        plannedWeekday: result.weekday,
        plannedStartMinute: result.startMinute,
        overwritePlannedStartMinute: true,
      ),
    );
  }

  void _deleteSessionTemplate(
    int blockIndex,
    int weekIndex,
    int templateIndex,
  ) {
    final week = _blocks[blockIndex].weeks[weekIndex];
    final templates = [...week.templates]..removeAt(templateIndex);
    final block = _blocks[blockIndex];
    final weeks = [...block.weeks];
    weeks[weekIndex] = ProgramWeekInput(
      name: week.name,
      ordinalInBlock: week.ordinalInBlock,
      programWeekOrdinal: week.programWeekOrdinal,
      isDeload: week.isDeload,
      templates: templates,
    );
    final updated = [..._blocks];
    updated[blockIndex] = ProgramBlockInput(
      name: block.name,
      description: block.description,
      ordinal: block.ordinal,
      weeks: weeks,
    );
    _replaceBlocks(updated);
  }

  Future<ExercisePickerSelection?> _pickExercise({String? selectedId}) {
    return showExercisePicker(
      context: context,
      selectionContext: ExerciseLibraryPickerContext(
        title: 'Choose an exercise',
        semanticLabel: 'Choose an exercise for this plan',
        selectedExerciseId: selectedId,
      ),
    );
  }

  Future<ExercisePrescriptionInput?> _promptPrescription({
    required String title,
    required int ordinal,
    ExercisePrescriptionInput? initial,
  }) async {
    final sets = TextEditingController(text: '${initial?.plannedSets ?? 3}');
    final reps = TextEditingController(text: initial?.repsRange ?? '8-10');
    ExercisePickerSelection? selected =
        initial?.exerciseId?.trim().isNotEmpty == true
        ? ExercisePickerSelection(
            exerciseId: initial!.exerciseId!,
            exerciseNameSnapshot: initial.exerciseNameSnapshot,
          )
        : null;
    String? error;
    final result = await showDialog<ExercisePrescriptionInput>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  label: selected == null
                      ? 'Choose an exercise from the library'
                      : 'Selected exercise ${selected!.exerciseNameSnapshot}',
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _pickExercise(
                        selectedId: selected?.exerciseId,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selected = picked;
                          error = null;
                        });
                      }
                    },
                    icon: const Icon(Icons.search_rounded),
                    label: Text(
                      selected?.exerciseNameSnapshot ??
                          'Choose from exercise library',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (selected == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Choose a library exercise so this plan always opens the right exercise.',
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: sets,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Planned sets'),
                ),
                TextField(
                  controller: reps,
                  decoration: const InputDecoration(
                    labelText: 'Rep range',
                    hintText: 'For example, 8-10',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final count = int.tryParse(sets.text.trim());
                if (selected == null) {
                  setDialogState(
                    () => error = 'Choose an exercise from the library.',
                  );
                  return;
                }
                if (count == null || count <= 0) {
                  setDialogState(
                    () => error = 'Planned sets must be greater than zero.',
                  );
                  return;
                }
                if (reps.text.trim().isEmpty) {
                  setDialogState(() => error = 'Enter a rep range.');
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  ExercisePrescriptionInput(
                    id: initial?.id ?? Uuid().v4(),
                    exerciseId: selected!.exerciseId,
                    exerciseNameSnapshot: selected!.exerciseNameSnapshot,
                    plannedSets: count,
                    repsRange: reps.text.trim(),
                    ordinal: ordinal,
                  ),
                );
              },
              child: Text(initial == null ? 'Add exercise' : 'Save exercise'),
            ),
          ],
        ),
      ),
    );
    sets.dispose();
    reps.dispose();
    return result;
  }

  Future<void> _addPrescription(
    int blockIndex,
    int weekIndex,
    int templateIndex,
  ) async {
    final template =
        _blocks[blockIndex].weeks[weekIndex].templates[templateIndex];
    final result = await _promptPrescription(
      title: 'Add exercise',
      ordinal: template.prescriptions.length,
    );
    if (result == null) return;
    _replaceTemplate(
      blockIndex,
      weekIndex,
      templateIndex,
      _copyTemplate(
        template,
        prescriptions: [...template.prescriptions, result],
      ),
    );
  }

  Future<void> _editPrescription(
    int blockIndex,
    int weekIndex,
    int templateIndex,
    int prescriptionIndex,
  ) async {
    final template =
        _blocks[blockIndex].weeks[weekIndex].templates[templateIndex];
    final result = await _promptPrescription(
      title: 'Edit exercise',
      ordinal: prescriptionIndex,
      initial: template.prescriptions[prescriptionIndex],
    );
    if (result == null) return;
    final prescriptions = [...template.prescriptions];
    prescriptions[prescriptionIndex] = result;
    _replaceTemplate(
      blockIndex,
      weekIndex,
      templateIndex,
      _copyTemplate(template, prescriptions: prescriptions),
    );
  }

  void _deletePrescription(
    int blockIndex,
    int weekIndex,
    int templateIndex,
    int prescriptionIndex,
  ) {
    final template =
        _blocks[blockIndex].weeks[weekIndex].templates[templateIndex];
    final prescription = template.prescriptions[prescriptionIndex];
    if (prescription.id != null &&
        template.groups.any(
          (group) => group.members.any(
            (member) => member.exercisePrescriptionId == prescription.id,
          ),
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Remove this exercise from its group before deleting it.',
          ),
        ),
      );
      return;
    }
    final prescriptions = [...template.prescriptions]
      ..removeAt(prescriptionIndex);
    _replaceTemplate(
      blockIndex,
      weekIndex,
      templateIndex,
      _copyTemplate(template, prescriptions: prescriptions),
    );
  }

  void _movePrescription(
    int blockIndex,
    int weekIndex,
    int templateIndex,
    int prescriptionIndex,
    int delta,
  ) {
    final template =
        _blocks[blockIndex].weeks[weekIndex].templates[templateIndex];
    final targetIndex = prescriptionIndex + delta;
    if (targetIndex < 0 || targetIndex >= template.prescriptions.length) {
      return;
    }
    final prescriptions = [...template.prescriptions];
    final moved = prescriptions.removeAt(prescriptionIndex);
    prescriptions.insert(targetIndex, moved);
    _replaceTemplate(
      blockIndex,
      weekIndex,
      templateIndex,
      _copyTemplate(template, prescriptions: prescriptions),
    );
  }

  SessionTemplateInput _copyTemplate(
    SessionTemplateInput template, {
    String? name,
    int? ordinal,
    int? plannedWeekday,
    int? plannedStartMinute,
    bool overwritePlannedStartMinute = false,
    String? notes,
    List<ExercisePrescriptionInput>? prescriptions,
    List<ExerciseGroupInput>? groups,
  }) {
    return SessionTemplateInput(
      name: name ?? template.name,
      ordinal: ordinal ?? template.ordinal,
      plannedWeekday: plannedWeekday ?? template.plannedWeekday,
      plannedStartMinute: overwritePlannedStartMinute
          ? plannedStartMinute
          : plannedStartMinute ?? template.plannedStartMinute,
      notes: notes ?? template.notes,
      prescriptions: prescriptions ?? template.prescriptions,
      groups: groups ?? template.groups,
    );
  }

  void _replaceTemplate(
    int blockIndex,
    int weekIndex,
    int templateIndex,
    SessionTemplateInput template,
  ) {
    final updated = [..._blocks];
    final block = updated[blockIndex];
    final weeks = [...block.weeks];
    final week = weeks[weekIndex];
    final templates = [...week.templates];
    templates[templateIndex] = template;
    weeks[weekIndex] = ProgramWeekInput(
      name: week.name,
      ordinalInBlock: week.ordinalInBlock,
      programWeekOrdinal: week.programWeekOrdinal,
      isDeload: week.isDeload,
      templates: templates,
    );
    updated[blockIndex] = ProgramBlockInput(
      name: block.name,
      description: block.description,
      ordinal: block.ordinal,
      weeks: weeks,
    );
    _replaceBlocks(updated);
  }

  Future<ExerciseGroupInput?> _promptGroup({
    required String title,
    required SessionTemplateInput template,
    ExerciseGroupInput? initial,
  }) async {
    final options = template.prescriptions
        .where((prescription) => prescription.id != null)
        .toList(growable: false);
    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least two library exercises before grouping.'),
        ),
      );
      return null;
    }
    final optionIds = options.map((prescription) => prescription.id!).toSet();
    final initialMembers =
        initial?.members ?? const <ExerciseGroupMemberInput>[];
    final initialMemberIds = initialMembers
        .map((member) => member.exercisePrescriptionId)
        .toList(growable: false);
    if (initialMemberIds.toSet().length != initialMemberIds.length ||
        initialMemberIds.any((id) => !optionIds.contains(id))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This group includes an unavailable exercise and cannot be edited.',
          ),
        ),
      );
      return null;
    }
    final label = TextEditingController(text: initial?.label ?? '');
    final rounds = TextEditingController(text: '${initial?.roundCount ?? 3}');
    final rest = TextEditingController(
      text: initial?.restAfterRoundSeconds?.toString() ?? '',
    );
    var groupType = initial?.groupType ?? B02GroupType.superset;
    final selectedIds = [...initialMemberIds];
    final transitionRestControllers = <String, TextEditingController>{
      for (final member in initialMembers)
        member.exercisePrescriptionId: TextEditingController(
          text: member.transitionRestSeconds?.toString() ?? '',
        ),
    };
    String? error;
    final result = await showDialog<ExerciseGroupInput>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedCount = selectedIds.length;
          final canSubmit = groupType.acceptsMemberCount(selectedCount);
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<B02GroupType>(
                    initialValue: groupType,
                    decoration: const InputDecoration(labelText: 'Group type'),
                    items: B02GroupType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(b02ExecutionGroupTypeLabel(type)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          groupType = value;
                          error = null;
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: rounds,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Shared rounds',
                    ),
                  ),
                  TextField(
                    controller: rest,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rest after round (seconds, optional)',
                    ),
                  ),
                  TextField(
                    controller: label,
                    decoration: const InputDecoration(
                      labelText: 'Label (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose exercises in the order they should run:',
                    ),
                  ),
                  ...options.map((prescription) {
                    final prescriptionId = prescription.id!;
                    final isSelected = selectedIds.contains(prescriptionId);
                    return Column(
                      children: [
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: isSelected,
                          title: Text(prescription.exerciseNameSnapshot),
                          subtitle: Text(
                            '${prescription.plannedSets} × ${prescription.repsRange}',
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true && !isSelected) {
                                selectedIds.add(prescriptionId);
                                transitionRestControllers[prescriptionId] =
                                    TextEditingController();
                              } else if (value != true && isSelected) {
                                selectedIds.remove(prescriptionId);
                                transitionRestControllers
                                    .remove(prescriptionId)
                                    ?.dispose();
                              }
                              error = null;
                            });
                          },
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: TextField(
                              controller:
                                  transitionRestControllers[prescriptionId],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    'Rest after ${prescription.exerciseNameSnapshot} (seconds, optional)',
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                  if (error != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final roundCount = int.tryParse(rounds.text.trim());
                  final restSeconds = rest.text.trim().isEmpty
                      ? null
                      : int.tryParse(rest.text.trim());
                  if (!canSubmit) {
                    setDialogState(
                      () => error = switch (groupType) {
                        B02GroupType.superset =>
                          'A superset needs exactly two members.',
                        B02GroupType.circuit =>
                          'A circuit needs at least two members.',
                        B02GroupType.giantSet =>
                          'A giant set needs at least three members.',
                      },
                    );
                    return;
                  }
                  if (roundCount == null || roundCount < 1) {
                    setDialogState(
                      () => error = 'Shared rounds must be positive.',
                    );
                    return;
                  }
                  if (rest.text.trim().isNotEmpty &&
                      (restSeconds == null || restSeconds < 0)) {
                    setDialogState(
                      () =>
                          error = 'Rest after round must be zero or positive.',
                    );
                    return;
                  }
                  final selected = [
                    for (final selectedId in selectedIds)
                      ...options.where(
                        (prescription) => prescription.id == selectedId,
                      ),
                  ];
                  final transitionRestByExerciseId = <String, int?>{};
                  for (final selectedId in selectedIds) {
                    final transitionRestText =
                        transitionRestControllers[selectedId]?.text.trim() ??
                        '';
                    final transitionRestSeconds = transitionRestText.isEmpty
                        ? null
                        : int.tryParse(transitionRestText);
                    if (transitionRestText.isNotEmpty &&
                        (transitionRestSeconds == null ||
                            transitionRestSeconds < 0)) {
                      setDialogState(
                        () =>
                            error = 'Transition rest must be zero or positive.',
                      );
                      return;
                    }
                    transitionRestByExerciseId[selectedId] =
                        transitionRestSeconds;
                  }
                  final existingMembersByExerciseId = {
                    for (final member in initialMembers)
                      member.exercisePrescriptionId: member,
                  };
                  Navigator.pop(
                    dialogContext,
                    ExerciseGroupInput(
                      id: initial?.id ?? Uuid().v4(),
                      ordinal: initial?.ordinal ?? template.groups.length,
                      groupType: groupType,
                      roundCount: roundCount,
                      restAfterRoundSeconds: restSeconds,
                      label: label.text.trim().isEmpty
                          ? null
                          : label.text.trim(),
                      members: selected
                          .asMap()
                          .entries
                          .map(
                            (entry) => ExerciseGroupMemberInput(
                              id:
                                  existingMembersByExerciseId[entry.value.id!]
                                      ?.id ??
                                  Uuid().v4(),
                              exercisePrescriptionId: entry.value.id!,
                              ordinal: entry.key,
                              transitionRestSeconds:
                                  transitionRestByExerciseId[entry.value.id!],
                            ),
                          )
                          .toList(growable: false),
                    ),
                  );
                },
                child: Text(initial == null ? 'Add group' : 'Save group'),
              ),
            ],
          );
        },
      ),
    );
    label.dispose();
    rounds.dispose();
    rest.dispose();
    for (final controller in transitionRestControllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _addGroup(
    int blockIndex,
    int weekIndex,
    int templateIndex,
  ) async {
    final template =
        _blocks[blockIndex].weeks[weekIndex].templates[templateIndex];
    final result = await _promptGroup(
      title: 'Add exercise group',
      template: template,
    );
    if (result == null) return;
    _replaceTemplate(
      blockIndex,
      weekIndex,
      templateIndex,
      _copyTemplate(template, groups: [...template.groups, result]),
    );
  }

  Future<void> _editGroup(
    int blockIndex,
    int weekIndex,
    int templateIndex,
    int groupIndex,
  ) async {
    final template =
        _blocks[blockIndex].weeks[weekIndex].templates[templateIndex];
    final existing = template.groups[groupIndex];
    final result = await _promptGroup(
      title: 'Edit exercise group',
      template: template,
      initial: existing,
    );
    if (result == null) return;
    final groups = [...template.groups];
    groups[groupIndex] = result;
    _replaceTemplate(
      blockIndex,
      weekIndex,
      templateIndex,
      _copyTemplate(template, groups: groups),
    );
  }

  void _moveGroup(
    int blockIndex,
    int weekIndex,
    int templateIndex,
    int groupIndex,
    int delta,
  ) {
    final template =
        _blocks[blockIndex].weeks[weekIndex].templates[templateIndex];
    final targetIndex = groupIndex + delta;
    if (targetIndex < 0 || targetIndex >= template.groups.length) return;
    final groups = [...template.groups];
    final moved = groups.removeAt(groupIndex);
    groups.insert(targetIndex, moved);
    _replaceTemplate(
      blockIndex,
      weekIndex,
      templateIndex,
      _copyTemplate(template, groups: groups),
    );
  }

  void _deleteGroup(
    int blockIndex,
    int weekIndex,
    int templateIndex,
    int groupIndex,
  ) {
    final updated = [..._blocks];
    final block = updated[blockIndex];
    final weeks = [...block.weeks];
    final week = weeks[weekIndex];
    final templates = [...week.templates];
    final template = templates[templateIndex];
    final groups = [...template.groups]..removeAt(groupIndex);
    templates[templateIndex] = SessionTemplateInput(
      name: template.name,
      ordinal: template.ordinal,
      plannedWeekday: template.plannedWeekday,
      plannedStartMinute: template.plannedStartMinute,
      notes: template.notes,
      prescriptions: template.prescriptions,
      groups: groups,
    );
    weeks[weekIndex] = ProgramWeekInput(
      name: week.name,
      ordinalInBlock: week.ordinalInBlock,
      programWeekOrdinal: week.programWeekOrdinal,
      isDeload: week.isDeload,
      templates: templates,
    );
    updated[blockIndex] = ProgramBlockInput(
      name: block.name,
      description: block.description,
      ordinal: block.ordinal,
      weeks: weeks,
    );
    _replaceBlocks(updated);
  }

  List<
    ({
      int blockIndex,
      int weekIndex,
      int templateIndex,
      SessionTemplateInput template,
    })
  >
  _consumerDayEntries() {
    return [
      for (var blockIndex = 0; blockIndex < _blocks.length; blockIndex++)
        for (
          var weekIndex = 0;
          weekIndex < _blocks[blockIndex].weeks.length;
          weekIndex++
        )
          for (
            var templateIndex = 0;
            templateIndex <
                _blocks[blockIndex].weeks[weekIndex].templates.length;
            templateIndex++
          )
            (
              blockIndex: blockIndex,
              weekIndex: weekIndex,
              templateIndex: templateIndex,
              template:
                  _blocks[blockIndex].weeks[weekIndex].templates[templateIndex],
            ),
    ];
  }

  Future<void> _addConsumerDay() async {
    if (!_isDraftVersion) return;
    if (_blocks.isEmpty) {
      await _addBlock();
    }
    if (!mounted || _blocks.isEmpty) return;
    if (_blocks.first.weeks.isEmpty) {
      await _addWeek(0);
    }
    if (!mounted || _blocks.first.weeks.isEmpty) return;
    await _addSessionTemplate(0, 0);
  }

  Widget _buildConsumerPlanSurface(BuildContext context) {
    final entries = _consumerDayEntries();
    final canEdit = _isDraftVersion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Days',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          ConsumerCountLabel.format(entries.length, 'day'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (canEdit) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addConsumerDay,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add day'),
            ),
          ),
        ],
        if (entries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add a day to start building workouts and exercises.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          for (var dayIndex = 0; dayIndex < entries.length; dayIndex++)
            _buildConsumerDayCard(
              context,
              entries[dayIndex],
              dayIndex,
              canEdit,
            ),
      ],
    );
  }

  Widget _buildConsumerDayCard(
    BuildContext context,
    ({
      int blockIndex,
      int weekIndex,
      int templateIndex,
      SessionTemplateInput template,
    })
    entry,
    int dayIndex,
    bool canEdit,
  ) {
    final workout = entry.template;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_today_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day ${dayIndex + 1}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_weekdayLabel(workout.plannedWeekday)} · ${workout.name}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Workout',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Exercises',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  'Sets/reps',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (workout.prescriptions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No exercises added yet.'),
              )
            else
              for (final prescription in workout.prescriptions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(prescription.exerciseNameSnapshot),
                  subtitle: prescription.exerciseId == null
                      ? const Text('Choose an exercise')
                      : null,
                  trailing: Text(
                    '${prescription.plannedSets} × ${prescription.repsRange}',
                    textAlign: TextAlign.end,
                  ),
                ),
            if (canEdit)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addPrescription(
                    entry.blockIndex,
                    entry.weekIndex,
                    entry.templateIndex,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add exercise'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _saveDraft() async {
    if (_programNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a plan name.')),
      );
      return false;
    }

    final authoring = ref.read(programAuthoringControllerProvider.notifier);
    try {
      await authoring.run(() async {
        final repo = ref.read(programRepositoryProvider);
        String progId = _currentProgramId ?? '';
        if (progId.isEmpty) {
          progId = await repo.createProgram(
            name: _programNameController.text.trim(),
            notes: _descriptionController.text.trim(),
            blocks: _blocks,
          );
          _currentProgramId = progId;
          final versions = await repo.getVersionsForProgram(progId);
          _currentVersionId = versions.last.id;
          _isDraftVersion = true;
        } else if (_currentVersionId != null) {
          if (!_isDraftVersion) {
            throw StateError(
              'This plan is already in use. Make a copy before editing it.',
            );
          }
          await repo.saveDraft(
            versionId: _currentVersionId!,
            name: _programNameController.text.trim(),
            notes: _descriptionController.text.trim(),
            blocks: _blocks,
          );
        } else {
          throw StateError('This plan has no editable version.');
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Plan saved.')));
      }
      return true;
    } catch (_) {
      // A failed write leaves the in-memory graph intact. Keep the authoring
      // surface in its edited state so the load-retry action cannot replace
      // those edits with the last persisted graph.
      authoring.markEdited();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The plan could not be saved. Try again.'),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _copyToNewDraft() async {
    if (_currentVersionId == null) return;
    final authoring = ref.read(programAuthoringControllerProvider.notifier);
    try {
      final newVersionId = await authoring.run(
        () => ref
            .read(programRepositoryProvider)
            .copyToNewDraftVersion(_currentVersionId!),
      );
      _currentVersionId = newVersionId;
      _isDraftVersion = true;
      await _loadOrCreateDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new editable copy is ready.')),
        );
      }
    } catch (_) {
      // Copy failure does not invalidate the source detail already on screen.
      authoring.markReady();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The plan copy could not be created. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _proceedToReview() async {
    final saved = await _saveDraft();
    if (saved && _currentVersionId != null && mounted) {
      await context.push('/program-review/$_currentVersionId');
    }
  }

  static String _weekdayLabel(int weekday) => switch (weekday) {
    DateTime.monday => 'Mon',
    DateTime.tuesday => 'Tue',
    DateTime.wednesday => 'Wed',
    DateTime.thursday => 'Thu',
    DateTime.friday => 'Fri',
    DateTime.saturday => 'Sat',
    DateTime.sunday => 'Sun',
    _ => 'Unknown day',
  };

  static String _formatTime(int minute) {
    final hour = minute ~/ 60;
    final minutePart = minute % 60;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minutePart.toString().padLeft(2, '0')} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final authoringState = ref.watch(programAuthoringControllerProvider);
    final isLoading = authoringState.isBusy;
    return Scaffold(
      appBar: AppBar(
        title: Text('Build your plan', style: TextStyle(fontFamily: 'Outfit')),
        actions: [
          if (_currentVersionId != null && !_isDraftVersion)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Make an editable copy',
              onPressed: isLoading ? null : _copyToNewDraft,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (authoringState.status ==
                              ProgramAuthoringStatus.failure)
                            Card(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              child: ListTile(
                                title: const Text('Plan could not be loaded'),
                                subtitle: Text(
                                  authoringState.errorMessage ??
                                      'Your changes are still here. Try again when storage is available.',
                                ),
                                trailing: TextButton(
                                  onPressed: () {
                                    ref
                                        .read(
                                          programAuthoringControllerProvider
                                              .notifier,
                                        )
                                        .recover();
                                    _loadOrCreateDraft();
                                  },
                                  child: const Text('Try again'),
                                ),
                              ),
                            ),
                          TextField(
                            controller: _programNameController,
                            readOnly: !_isDraftVersion,
                            onChanged: _isDraftVersion
                                ? (_) => ref
                                      .read(
                                        programAuthoringControllerProvider
                                            .notifier,
                                      )
                                      .markEdited()
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Plan name',
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descriptionController,
                            readOnly: !_isDraftVersion,
                            onChanged: _isDraftVersion
                                ? (_) => ref
                                      .read(
                                        programAuthoringControllerProvider
                                            .notifier,
                                      )
                                      .markEdited()
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Description or notes',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          if (!_isDraftVersion) ...[
                            const SizedBox(height: 12),
                            Card(
                              color: Colors.amber.withValues(alpha: 0.12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.lock_outline,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'This plan is already in use. Make an editable copy to keep scheduled workouts unchanged.',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: isLoading
                                          ? null
                                          : _copyToNewDraft,
                                      child: const Text('Make a copy'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _buildConsumerPlanSurface(context),
                          const SizedBox(height: 16),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Advanced plan structure'),
                            subtitle: const Text(
                              'Optional phases, weeks, groups, and scheduling',
                            ),
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Phases (${ConsumerCountLabel.format(_blocks.length, 'phase')})',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: _isDraftVersion
                                        ? _addBlock
                                        : null,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add phase'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _blocks.length,
                                itemBuilder: (context, bIdx) {
                                  final block = _blocks[bIdx];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  block.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Rename block',
                                                onPressed: _isDraftVersion
                                                    ? () => _renameBlock(bIdx)
                                                    : null,
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete block',
                                                onPressed: _isDraftVersion
                                                    ? () => _deleteBlock(bIdx)
                                                    : null,
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton.icon(
                                              onPressed: _isDraftVersion
                                                  ? () => _addWeek(bIdx)
                                                  : null,
                                              icon: const Icon(
                                                Icons.add,
                                                size: 18,
                                              ),
                                              label: const Text('Add week'),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...block.weeks.asMap().entries.map((
                                            weekEntry,
                                          ) {
                                            final wIdx = weekEntry.key;
                                            final w = weekEntry.value;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                left: 12,
                                                top: 4,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'Week ${w.programWeekOrdinal + 1}: ${ConsumerCountLabel.format(w.templates.length, 'session')}',
                                                          style: TextStyle(
                                                            color: w.isDeload
                                                                ? Colors.purple
                                                                : AppColors
                                                                      .textPrimary,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                      Tooltip(
                                                        message: 'Deload week',
                                                        child: Switch(
                                                          value: w.isDeload,
                                                          onChanged:
                                                              _isDraftVersion
                                                              ? (value) =>
                                                                    _setWeekDeload(
                                                                      bIdx,
                                                                      wIdx,
                                                                      value,
                                                                    )
                                                              : null,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        tooltip:
                                                            'Edit week name',
                                                        onPressed:
                                                            _isDraftVersion
                                                            ? () => _renameWeek(
                                                                bIdx,
                                                                wIdx,
                                                              )
                                                            : null,
                                                        icon: const Icon(
                                                          Icons.edit_outlined,
                                                          size: 20,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        tooltip: 'Delete week',
                                                        onPressed:
                                                            _isDraftVersion
                                                            ? () => _deleteWeek(
                                                                bIdx,
                                                                wIdx,
                                                              )
                                                            : null,
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: TextButton.icon(
                                                      onPressed: _isDraftVersion
                                                          ? () =>
                                                                _addSessionTemplate(
                                                                  bIdx,
                                                                  wIdx,
                                                                )
                                                          : null,
                                                      icon: const Icon(
                                                        Icons.add,
                                                        size: 16,
                                                      ),
                                                      label: const Text(
                                                        'Add session',
                                                      ),
                                                    ),
                                                  ),
                                                  ...w.templates.asMap().entries.map((
                                                    templateEntry,
                                                  ) {
                                                    final templateIndex =
                                                        templateEntry.key;
                                                    final st =
                                                        templateEntry.value;
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 12,
                                                            top: 2,
                                                          ),
                                                      child: Card(
                                                        margin: EdgeInsets.zero,
                                                        color: AppColors
                                                            .cardBackground,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                8,
                                                              ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      '${st.name} • ${_weekdayLabel(st.plannedWeekday)}${st.plannedStartMinute == null ? '' : ' • ${_formatTime(st.plannedStartMinute!)}'}',
                                                                      style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  IconButton(
                                                                    tooltip:
                                                                        'Edit workout',
                                                                    onPressed:
                                                                        _isDraftVersion
                                                                        ? () => _editSessionTemplate(
                                                                            bIdx,
                                                                            wIdx,
                                                                            templateIndex,
                                                                          )
                                                                        : null,
                                                                    icon: const Icon(
                                                                      Icons
                                                                          .edit_outlined,
                                                                      size: 20,
                                                                    ),
                                                                  ),
                                                                  IconButton(
                                                                    tooltip:
                                                                        'Delete workout',
                                                                    onPressed:
                                                                        _isDraftVersion
                                                                        ? () => _deleteSessionTemplate(
                                                                            bIdx,
                                                                            wIdx,
                                                                            templateIndex,
                                                                          )
                                                                        : null,
                                                                    icon: const Icon(
                                                                      Icons
                                                                          .delete_outline,
                                                                      size: 20,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              ...st.prescriptions.asMap().entries.map((
                                                                prescriptionEntry,
                                                              ) {
                                                                final prescriptionIndex =
                                                                    prescriptionEntry
                                                                        .key;
                                                                final prescription =
                                                                    prescriptionEntry
                                                                        .value;
                                                                final exerciseLabel =
                                                                    '${prescription.exerciseNameSnapshot}: ${prescription.plannedSets} × ${prescription.repsRange}${prescription.exerciseId == null ? ' (choose an exercise)' : ''}';
                                                                return ListTile(
                                                                  dense: true,
                                                                  contentPadding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                  title: Text(
                                                                    exerciseLabel,
                                                                  ),
                                                                  leading: Text(
                                                                    '${prescriptionIndex + 1}',
                                                                    semanticsLabel:
                                                                        'Exercise ${prescriptionIndex + 1}',
                                                                  ),
                                                                  trailing: Wrap(
                                                                    spacing: 0,
                                                                    children: [
                                                                      IconButton(
                                                                        tooltip:
                                                                            'Move exercise up',
                                                                        onPressed:
                                                                            !_isDraftVersion ||
                                                                                prescriptionIndex ==
                                                                                    0
                                                                            ? null
                                                                            : () => _movePrescription(
                                                                                bIdx,
                                                                                wIdx,
                                                                                templateIndex,
                                                                                prescriptionIndex,
                                                                                -1,
                                                                              ),
                                                                        icon: const Icon(
                                                                          Icons
                                                                              .keyboard_arrow_up_rounded,
                                                                        ),
                                                                      ),
                                                                      IconButton(
                                                                        tooltip:
                                                                            'Move exercise down',
                                                                        onPressed:
                                                                            !_isDraftVersion ||
                                                                                prescriptionIndex ==
                                                                                    st.prescriptions.length -
                                                                                        1
                                                                            ? null
                                                                            : () => _movePrescription(
                                                                                bIdx,
                                                                                wIdx,
                                                                                templateIndex,
                                                                                prescriptionIndex,
                                                                                1,
                                                                              ),
                                                                        icon: const Icon(
                                                                          Icons
                                                                              .keyboard_arrow_down_rounded,
                                                                        ),
                                                                      ),
                                                                      IconButton(
                                                                        tooltip:
                                                                            'Edit exercise',
                                                                        onPressed:
                                                                            _isDraftVersion
                                                                            ? () => _editPrescription(
                                                                                bIdx,
                                                                                wIdx,
                                                                                templateIndex,
                                                                                prescriptionIndex,
                                                                              )
                                                                            : null,
                                                                        icon: const Icon(
                                                                          Icons
                                                                              .edit_outlined,
                                                                        ),
                                                                      ),
                                                                      IconButton(
                                                                        tooltip:
                                                                            'Delete exercise',
                                                                        onPressed:
                                                                            _isDraftVersion
                                                                            ? () => _deletePrescription(
                                                                                bIdx,
                                                                                wIdx,
                                                                                templateIndex,
                                                                                prescriptionIndex,
                                                                              )
                                                                            : null,
                                                                        icon: const Icon(
                                                                          Icons
                                                                              .delete_outline,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                              }),
                                                              if (st
                                                                  .groups
                                                                  .isNotEmpty) ...[
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                                const Text(
                                                                  'Exercise groups',
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                                ...st.groups.asMap().entries.map((
                                                                  groupEntry,
                                                                ) {
                                                                  final group =
                                                                      groupEntry
                                                                          .value;
                                                                  final namesById = {
                                                                    for (final prescription
                                                                        in st
                                                                            .prescriptions)
                                                                      if (prescription
                                                                              .id !=
                                                                          null)
                                                                        prescription
                                                                            .id!: prescription
                                                                            .exerciseNameSnapshot,
                                                                  };
                                                                  final memberLabels = group
                                                                      .members
                                                                      .map(
                                                                        (
                                                                          member,
                                                                        ) =>
                                                                            namesById[member.exercisePrescriptionId] ??
                                                                            'Unavailable exercise',
                                                                      )
                                                                      .join(
                                                                        ' → ',
                                                                      );
                                                                  return ListTile(
                                                                    dense: true,
                                                                    contentPadding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    title: Text(
                                                                      '${b02ExecutionGroupTypeLabel(group.groupType)} • ${group.roundCount} rounds',
                                                                    ),
                                                                    subtitle: Text(
                                                                      'Exercises: $memberLabels${group.restAfterRoundSeconds == null ? '' : ' • ${group.restAfterRoundSeconds}s rest after round'}',
                                                                    ),
                                                                    trailing: PopupMenuButton<String>(
                                                                      tooltip:
                                                                          'Group actions',
                                                                      enabled:
                                                                          _isDraftVersion,
                                                                      onSelected: (action) {
                                                                        switch (action) {
                                                                          case 'edit':
                                                                            _editGroup(
                                                                              bIdx,
                                                                              wIdx,
                                                                              templateIndex,
                                                                              groupEntry.key,
                                                                            );
                                                                          case 'up':
                                                                            _moveGroup(
                                                                              bIdx,
                                                                              wIdx,
                                                                              templateIndex,
                                                                              groupEntry.key,
                                                                              -1,
                                                                            );
                                                                          case 'down':
                                                                            _moveGroup(
                                                                              bIdx,
                                                                              wIdx,
                                                                              templateIndex,
                                                                              groupEntry.key,
                                                                              1,
                                                                            );
                                                                          case 'delete':
                                                                            _deleteGroup(
                                                                              bIdx,
                                                                              wIdx,
                                                                              templateIndex,
                                                                              groupEntry.key,
                                                                            );
                                                                        }
                                                                      },
                                                                      itemBuilder: (context) => [
                                                                        const PopupMenuItem(
                                                                          value:
                                                                              'edit',
                                                                          child: Text(
                                                                            'Edit group',
                                                                          ),
                                                                        ),
                                                                        PopupMenuItem(
                                                                          value:
                                                                              'up',
                                                                          enabled:
                                                                              groupEntry.key >
                                                                              0,
                                                                          child: const Text(
                                                                            'Move group up',
                                                                          ),
                                                                        ),
                                                                        PopupMenuItem(
                                                                          value:
                                                                              'down',
                                                                          enabled:
                                                                              groupEntry.key <
                                                                              st.groups.length -
                                                                                  1,
                                                                          child: const Text(
                                                                            'Move group down',
                                                                          ),
                                                                        ),
                                                                        const PopupMenuItem(
                                                                          value:
                                                                              'delete',
                                                                          child: Text(
                                                                            'Delete group',
                                                                          ),
                                                                        ),
                                                                      ],
                                                                      icon: const Icon(
                                                                        Icons
                                                                            .more_vert,
                                                                      ),
                                                                    ),
                                                                  );
                                                                }),
                                                              ],
                                                              TextButton.icon(
                                                                onPressed:
                                                                    _isDraftVersion
                                                                    ? () => _addGroup(
                                                                        bIdx,
                                                                        wIdx,
                                                                        templateIndex,
                                                                      )
                                                                    : null,
                                                                icon: const Icon(
                                                                  Icons
                                                                      .account_tree_outlined,
                                                                  size: 16,
                                                                ),
                                                                label: const Text(
                                                                  'Add group',
                                                                ),
                                                              ),
                                                              TextButton.icon(
                                                                onPressed:
                                                                    _isDraftVersion
                                                                    ? () => _addPrescription(
                                                                        bIdx,
                                                                        wIdx,
                                                                        templateIndex,
                                                                      )
                                                                    : null,
                                                                icon:
                                                                    const Icon(
                                                                      Icons.add,
                                                                      size: 16,
                                                                    ),
                                                                label: const Text(
                                                                  'Add exercise',
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }),
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
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isLoading || !_isDraftVersion
                                      ? null
                                      : _saveDraft,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Save plan'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isLoading || !_isDraftVersion
                                      ? null
                                      : _proceedToReview,
                                  icon: const Icon(Icons.rate_review_outlined),
                                  label: const Text('Review plan'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
