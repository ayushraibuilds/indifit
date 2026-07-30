import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/providers.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/program_repository.dart';

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

  bool _isLoading = false;
  String? _currentProgramId;
  String? _currentVersionId;
  bool _isDraftVersion = true;
  List<ExerciseAuthoringOption> _exerciseOptions = const [];
  List<ProgramBlockInput> _blocks = [];

  @override
  void initState() {
    super.initState();
    _currentProgramId = widget.programId;
    _currentVersionId = widget.programVersionId;
    _loadOrCreateDraft();
  }

  Future<void> _loadOrCreateDraft() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(programRepositoryProvider);

      if (_currentVersionId != null) {
        final versionDetail = await repo.getProgramVersionDetail(
          _currentVersionId!,
        );
        if (versionDetail != null) {
          _programNameController.text = versionDetail.program.name;
          _descriptionController.text = versionDetail.program.notes ?? '';
          _currentProgramId = versionDetail.program.id;
          _isDraftVersion = versionDetail.version.status == 'draft';
          _blocks = _mapDetailToBlockInputs(versionDetail);
        }
      } else if (_currentProgramId != null) {
        final versions = await repo.getVersionsForProgram(_currentProgramId!);
        if (versions.isNotEmpty) {
          final detail = await repo.getProgramVersionDetail(versions.last.id);
          if (detail != null) {
            _programNameController.text = detail.program.name;
            _descriptionController.text = detail.program.notes ?? '';
            _currentVersionId = detail.version.id;
            _isDraftVersion = detail.version.status == 'draft';
            _blocks = _mapDetailToBlockInputs(detail);
          }
        }
      }

      if (_blocks.isEmpty) {
        _programNameController.text = 'New Program';
        _blocks = [
          ProgramBlockInput(
            name: 'Block 1 - Hypertrophy',
            ordinal: 0,
            weeks: [
              ProgramWeekInput(
                ordinalInBlock: 0,
                programWeekOrdinal: 0,
                templates: [
                  SessionTemplateInput(
                    name: 'Day 1 - Push',
                    ordinal: 0,
                    plannedWeekday: 1,
                    prescriptions: [
                      ExercisePrescriptionInput(
                        exerciseNameSnapshot: 'Custom exercise',
                        plannedSets: 4,
                        repsRange: '8-10',
                        ordinal: 0,
                        allowUnresolvedExerciseFallback: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading draft: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      title: 'Add program week',
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

  Future<void> _addSessionTemplate(int blockIndex, int weekIndex) async {
    final controller = TextEditingController(
      text:
          'Session ${_blocks[blockIndex].weeks[weekIndex].templates.length + 1}',
    );
    var weekday = DateTime.monday;
    final result = await showDialog<({String name, int weekday})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add session template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Session name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: weekday,
                decoration: const InputDecoration(labelText: 'Planned weekday'),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, (
                name: controller.text.trim(),
                weekday: weekday,
              )),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || result.name.isEmpty) return;
    final updated = [..._blocks];
    final block = updated[blockIndex];
    final weeks = [...block.weeks];
    final week = weeks[weekIndex];
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
          prescriptions: const [],
        ),
      ],
    );
    updated[blockIndex] = ProgramBlockInput(
      name: block.name,
      description: block.description,
      ordinal: block.ordinal,
      weeks: weeks,
    );
    _replaceBlocks(updated);
  }

  Future<void> _addPrescription(
    int blockIndex,
    int weekIndex,
    int templateIndex,
  ) async {
    if (_exerciseOptions.isEmpty) {
      final options = await ref
          .read(programRepositoryProvider)
          .getExercisesForAuthoring();
      if (!mounted) return;
      setState(() => _exerciseOptions = options);
    }
    final customName = TextEditingController();
    final reps = TextEditingController(text: '8-10');
    final sets = TextEditingController(text: '3');
    ExerciseAuthoringOption? selected = _exerciseOptions.isEmpty
        ? null
        : _exerciseOptions.first;
    final result = await showDialog<ExercisePrescriptionInput>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add exercise prescription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_exerciseOptions.isNotEmpty)
                  DropdownButtonFormField<ExerciseAuthoringOption>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Exercise'),
                    items: _exerciseOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text('${option.name} (${option.equipment})'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setDialogState(() => selected = value),
                  )
                else
                  TextField(
                    controller: customName,
                    decoration: const InputDecoration(
                      labelText: 'Custom/unresolved exercise name',
                      helperText:
                          'Shown as compatibility unknown until linked.',
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
                  decoration: const InputDecoration(labelText: 'Rep range'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final count = int.tryParse(sets.text.trim());
                if (count == null || count <= 0 || reps.text.trim().isEmpty) {
                  return;
                }
                final exerciseName = selected?.name ?? customName.text.trim();
                if (exerciseName.isEmpty) return;
                final template = _blocks[blockIndex]
                    .weeks[weekIndex]
                    .templates[templateIndex];
                Navigator.pop(
                  context,
                  ExercisePrescriptionInput(
                    exerciseId: selected?.stableId,
                    exerciseNameSnapshot: exerciseName,
                    plannedSets: count,
                    repsRange: reps.text.trim(),
                    ordinal: template.prescriptions.length,
                    allowUnresolvedExerciseFallback: selected == null,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    customName.dispose();
    reps.dispose();
    sets.dispose();
    if (result == null) return;
    final updated = [..._blocks];
    final block = updated[blockIndex];
    final weeks = [...block.weeks];
    final week = weeks[weekIndex];
    final templates = [...week.templates];
    final template = templates[templateIndex];
    templates[templateIndex] = SessionTemplateInput(
      name: template.name,
      ordinal: template.ordinal,
      plannedWeekday: template.plannedWeekday,
      plannedStartMinute: template.plannedStartMinute,
      notes: template.notes,
      prescriptions: [...template.prescriptions, result],
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

  Future<void> _saveDraft() async {
    if (_programNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a program name.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
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
            'Published versions are immutable. Create a new draft before editing.',
          );
        }
        await repo.updateProgramMetadata(
          programId: progId,
          name: _programNameController.text.trim(),
          notes: _descriptionController.text.trim(),
        );
        await repo.updateDraftVersion(_currentVersionId!, blocks: _blocks);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving draft: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyToNewDraft() async {
    if (_currentVersionId == null) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(programRepositoryProvider);
      final newVersionId = await repo.copyToNewDraftVersion(_currentVersionId!);
      _currentVersionId = newVersionId;
      _isDraftVersion = true;
      await _loadOrCreateDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to new draft version.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error copying draft: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _proceedToReview() async {
    await _saveDraft();
    if (_currentVersionId != null && mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Program Authoring',
          style: TextStyle(fontFamily: GoogleFonts.outfit().fontFamily),
        ),
        actions: [
          if (_currentVersionId != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copy to New Draft',
              onPressed: _isLoading ? null : _copyToNewDraft,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _programNameController,
                    decoration: const InputDecoration(
                      labelText: 'Program Name',
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(
                      fontFamily: GoogleFonts.outfit().fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description / Notes',
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
                            const Icon(Icons.lock_outline, color: Colors.amber),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Published versions are immutable. Create a new draft to edit this program.',
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : _copyToNewDraft,
                              child: const Text('Create draft'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Program Structure (${_blocks.length} Blocks)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: GoogleFonts.outfit().fontFamily,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isDraftVersion ? _addBlock : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Add block'),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                    icon: const Icon(Icons.edit_outlined),
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
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add week'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...block.weeks.asMap().entries.map((weekEntry) {
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
                                              'Week ${w.programWeekOrdinal + 1}: ${w.templates.length} sessions',
                                              style: TextStyle(
                                                color: w.isDeload
                                                    ? Colors.purple
                                                    : AppColors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Tooltip(
                                            message: 'Deload week',
                                            child: Switch(
                                              value: w.isDeload,
                                              onChanged: _isDraftVersion
                                                  ? (value) => _setWeekDeload(
                                                      bIdx,
                                                      wIdx,
                                                      value,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: _isDraftVersion
                                              ? () => _addSessionTemplate(
                                                  bIdx,
                                                  wIdx,
                                                )
                                              : null,
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('Add session'),
                                        ),
                                      ),
                                      ...w.templates.asMap().entries.map((
                                        templateEntry,
                                      ) {
                                        final templateIndex = templateEntry.key;
                                        final st = templateEntry.value;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            left: 12,
                                            top: 2,
                                          ),
                                          child: Card(
                                            margin: EdgeInsets.zero,
                                            color: AppColors.cardBackground,
                                            child: Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${st.name} • ${_weekdayLabel(st.plannedWeekday)}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  ...st.prescriptions.map(
                                                    (prescription) => Text(
                                                      '• ${prescription.exerciseNameSnapshot}: ${prescription.plannedSets} × ${prescription.repsRange}${prescription.exerciseId == null ? " (compatibility unknown)" : ""}',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                  TextButton.icon(
                                                    onPressed: _isDraftVersion
                                                        ? () =>
                                                              _addPrescription(
                                                                bIdx,
                                                                wIdx,
                                                                templateIndex,
                                                              )
                                                        : null,
                                                    icon: const Icon(
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading || !_isDraftVersion
                              ? null
                              : _saveDraft,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save Draft'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading || !_isDraftVersion
                              ? null
                              : _proceedToReview,
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text('Review & Activate'),
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
    );
  }
}
