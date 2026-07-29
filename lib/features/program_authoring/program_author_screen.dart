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
                  const SessionTemplateInput(
                    name: 'Day 1 - Push',
                    ordinal: 0,
                    plannedWeekday: 1,
                    prescriptions: [
                      ExercisePrescriptionInput(
                        exerciseNameSnapshot: 'Barbell Bench Press',
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
      } else if (_currentVersionId != null) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentVersionId == null ? 'New Program' : 'Program Authoring',
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
                              Text(
                                block.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...block.weeks.map((w) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    top: 4,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Week ${w.programWeekOrdinal + 1}${w.isDeload ? " (Deload)" : ""}: ${w.templates.length} Templates',
                                        style: TextStyle(
                                          color: w.isDeload
                                              ? Colors.purple
                                              : AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      ...w.templates.map((st) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            left: 12,
                                            top: 2,
                                          ),
                                          child: Text(
                                            '• ${st.name} (${st.prescriptions.length} exercises)',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
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
                          onPressed: _isLoading ? null : _saveDraft,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save Draft'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _proceedToReview,
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
