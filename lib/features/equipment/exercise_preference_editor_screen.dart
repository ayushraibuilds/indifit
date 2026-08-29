import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
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

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasExistingPreference = false;

  static const List<String> _commonSetupSuggestions = [
    'Seat',
    'Pin',
    'Bench Incline',
    'Cable Height',
    'Foot Position',
    'Handle Width',
  ];

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
        _hasExistingPreference = true;
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

  void _addSetupValue({String initialLabel = '', String initialValue = ''}) {
    setState(() {
      _setupValueControllers.add({
        'label': TextEditingController(text: initialLabel),
        'value': TextEditingController(text: initialValue),
      });
    });
  }

  void _addCue({String initialText = ''}) {
    setState(() {
      _cueControllers.add(TextEditingController(text: initialText));
    });
  }

  Future<void> _save() async {
    final setupInputs = <SetupValueInput>[];
    int ordinal = 0;
    for (int i = 0; i < _setupValueControllers.length; i++) {
      final label = _setupValueControllers[i]['label']!.text.trim();
      final val = _setupValueControllers[i]['value']!.text.trim();
      if (label.isNotEmpty && val.isNotEmpty) {
        setupInputs.add(
          SetupValueInput(ordinal: ordinal++, label: label, value: val),
        );
      }
    }

    final cueInputs = _cueControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final note = _generalNoteController.text.trim();

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(exercisePreferenceRepositoryProvider);
      await repo.savePreference(
        stableId: widget.stableId,
        rawName: widget.rawName,
        allowUnresolvedRawFallback: widget.stableId == null,
        generalNote: note.isEmpty ? null : note,
        clearGeneralNote: note.isEmpty,
        setupValues: setupInputs,
        personalCues: cueInputs,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercise setup & cues saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ArgumentError
            ? e.message.toString()
            : 'Exercise preferences could not be saved. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deletePreferences() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Exercise Preferences?'),
        content: Text(
          'Remove all custom setup values, personal technique cues, and notes for "${widget.rawName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(exercisePreferenceRepositoryProvider);
      await repo.deletePreference(
        stableId: widget.stableId,
        rawName: widget.rawName,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercise preferences reset.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reset preferences. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Setup & Cues: ${widget.rawName}',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          if (_hasExistingPreference)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Reset preferences',
              onPressed: _deletePreferences,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(B05Layout.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNoticeBanner(colors),
                  const SizedBox(height: B05Layout.space16),
                  _buildGeneralNoteSection(colors),
                  const SizedBox(height: B05Layout.space20),
                  _buildSetupValuesSection(colors),
                  const SizedBox(height: B05Layout.space20),
                  _buildPersonalCuesSection(colors),
                  const SizedBox(height: B05Layout.space24),
                  _buildSaveButton(colors),
                  const SizedBox(height: B05Layout.space24),
                ],
              ),
            ),
    );
  }

  Widget _buildNoticeBanner(B05SemanticColors colors) {
    return B05Surface(
      tone: B05SurfaceTone.inset,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: colors.action,
            size: B05Layout.iconMedium,
          ),
          const SizedBox(width: B05Layout.space12),
          Expanded(
            child: Text(
              'Setup values and personal cues are saved for future workouts. Changes do not alter active or completed workout records.',
              style: B05Typography.caption(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralNoteSection(B05SemanticColors colors) {
    return B05Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Exercise Note',
            style: B05Typography.title(context),
          ),
          const SizedBox(height: B05Layout.space8),
          TextField(
            controller: _generalNoteController,
            decoration: const InputDecoration(
              hintText: 'e.g. Always warm up with empty bar first.',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSetupValuesSection(B05SemanticColors colors) {
    return B05Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Setup Values (Seats, Pins, Knobs)',
                  style: B05Typography.title(context),
                ),
              ),
              B05TouchTarget(
                child: IconButton(
                  icon: Icon(Icons.add_circle_outline, color: colors.action),
                  tooltip: 'Add setup value',
                  onPressed: _addSetupValue,
                ),
              ),
            ],
          ),
          Text(
            'Machine seats, pin numbers, cable heights, or bench angles.',
            style: B05Typography.caption(context),
          ),
          if (_setupValueControllers.isEmpty) ...[
            const SizedBox(height: B05Layout.space12),
            Text(
              'Quick suggestions:',
              style: B05Typography.caption(context),
            ),
            const SizedBox(height: B05Layout.space8),
            Wrap(
              spacing: B05Layout.space8,
              runSpacing: B05Layout.space4,
              children: _commonSetupSuggestions.map((suggestion) {
                return ActionChip(
                  label: Text(suggestion),
                  avatar: const Icon(Icons.add, size: B05Layout.iconSmall),
                  onPressed: () => _addSetupValue(initialLabel: suggestion),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: B05Layout.space12),
          ..._setupValueControllers.asMap().entries.map((entry) {
            final idx = entry.key;
            final controllers = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: B05Layout.space8),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: controllers['label'],
                      decoration: const InputDecoration(
                        labelText: 'Label (e.g. Seat)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: controllers['value'],
                      decoration: const InputDecoration(
                        labelText: 'Value (e.g. 3)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.danger.indicator,
                    ),
                    tooltip: 'Remove setup value',
                    onPressed: () {
                      setState(() {
                        final removed = _setupValueControllers.removeAt(idx);
                        removed['label']?.dispose();
                        removed['value']?.dispose();
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPersonalCuesSection(B05SemanticColors colors) {
    return B05Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Personal Technique Cues',
                style: B05Typography.title(context),
              ),
              B05TouchTarget(
                child: IconButton(
                  icon: Icon(Icons.add_circle_outline, color: colors.action),
                  tooltip: 'Add cue',
                  onPressed: _addCue,
                ),
              ),
            ],
          ),
          Text(
            'Reminders shown before or during sets (e.g. "Tuck elbows", "Pause at bottom").',
            style: B05Typography.caption(context),
          ),
          const SizedBox(height: B05Layout.space12),
          if (_cueControllers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: B05Layout.space8),
              child: Text(
                'No custom cues added yet.',
                style: B05Typography.body(context),
              ),
            ),
          ..._cueControllers.asMap().entries.map((entry) {
            final idx = entry.key;
            final controller = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: B05Layout.space8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: B05Layout.iconMedium,
                    color: colors.action,
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Personal Cue',
                        hintText: 'e.g. Squeeze chest at peak contraction',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.danger.indicator,
                    ),
                    tooltip: 'Remove cue',
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
        ],
      ),
    );
  }

  Widget _buildSaveButton(B05SemanticColors colors) {
    return SizedBox(
      width: double.infinity,
      child: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : B05ActionButton(
              label: 'Save Setup & Cues',
              icon: Icons.save_rounded,
              onPressed: _save,
            ),
    );
  }
}
