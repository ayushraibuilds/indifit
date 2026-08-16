import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/equipment_preference_repository.dart';

/// Screen for editing personal setup values (seat, pins) and personal technique cues for an exercise.
class ExercisePreferenceEditorScreen extends ConsumerStatefulWidget {
  final String? stableId;
  final String rawName;

  const ExercisePreferenceEditorScreen({
    super.key,
    this.stableId,
    required this.rawName,
  });

  @override
  ConsumerState<ExercisePreferenceEditorScreen> createState() =>
      _ExercisePreferenceEditorScreenState();
}

class _ExercisePreferenceEditorScreenState
    extends ConsumerState<ExercisePreferenceEditorScreen> {
  final TextEditingController _generalNoteController = TextEditingController();
  final List<Map<String, TextEditingController>> _setupValueControllers = [];
  final List<TextEditingController> _cueControllers = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  @override
  void dispose() {
    _generalNoteController.dispose();
    for (final controllers in _setupValueControllers) {
      controllers['label']?.dispose();
      controllers['value']?.dispose();
    }
    for (final controller in _cueControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPreference() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(exercisePreferenceRepositoryProvider);
      final aggregate = await repo.getPreference(
        stableId: widget.stableId,
        rawName: widget.rawName,
      );

      if (aggregate != null) {
        for (final controllers in _setupValueControllers) {
          controllers['label']?.dispose();
          controllers['value']?.dispose();
        }
        for (final controller in _cueControllers) {
          controller.dispose();
        }
        _setupValueControllers.clear();
        _cueControllers.clear();
        _generalNoteController.text = aggregate.preference.generalNote ?? '';
        for (final sv in aggregate.setupValues) {
          _setupValueControllers.add({
            'label': TextEditingController(text: sv.label),
            'value': TextEditingController(text: sv.value),
          });
        }
        for (final c in aggregate.personalCues) {
          _cueControllers.add(TextEditingController(text: c.cueText));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Exercise preferences could not be loaded. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addSetupValue() {
    setState(() {
      _setupValueControllers.add({
        'label': TextEditingController(),
        'value': TextEditingController(),
      });
    });
  }

  void _addCue() {
    setState(() {
      _cueControllers.add(TextEditingController());
    });
  }

  Future<void> _save() async {
    final setupInputs = <SetupValueInput>[];
    for (int i = 0; i < _setupValueControllers.length; i++) {
      final label = _setupValueControllers[i]['label']!.text.trim();
      final val = _setupValueControllers[i]['value']!.text.trim();
      if (label.isNotEmpty && val.isNotEmpty) {
        setupInputs.add(SetupValueInput(ordinal: i, label: label, value: val));
      }
    }

    final cueInputs = _cueControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(exercisePreferenceRepositoryProvider);
      await repo.savePreference(
        stableId: widget.stableId,
        rawName: widget.rawName,
        allowUnresolvedRawFallback: widget.stableId == null,
        generalNote: _generalNoteController.text.trim(),
        setupValues: setupInputs,
        personalCues: cueInputs,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercise setup & cues saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Exercise preferences could not be saved. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Setup & Cues: ${widget.rawName}',
          style: TextStyle(fontFamily: 'Outfit', fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _generalNoteController,
                    decoration: const InputDecoration(
                      labelText: 'General Exercise Note',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Setup Values (Seats, Pins, Knobs)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _addSetupValue,
                      ),
                    ],
                  ),
                  ..._setupValueControllers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final controllers = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers['label'],
                              decoration: const InputDecoration(
                                labelText: 'Label (e.g. Seat)',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: controllers['value'],
                              decoration: const InputDecoration(
                                labelText: 'Value (e.g. 3)',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                final removed = _setupValueControllers.removeAt(
                                  idx,
                                );
                                removed['label']?.dispose();
                                removed['value']?.dispose();
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Personal Technique Cues',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _addCue,
                      ),
                    ],
                  ),
                  ..._cueControllers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final controller = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                labelText: 'Cue (e.g. Squeeze chest at peak)',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() {
                                _cueControllers.removeAt(idx).dispose();
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Setup & Cues'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
