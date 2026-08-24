import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/equipment_fixtures.dart';
import '../../core/presentation/equipment_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/repositories/equipment_preference_repository.dart';

/// Screen for creating or editing an equipment profile and configuring equipment availability.
class EquipmentProfileEditorScreen extends ConsumerStatefulWidget {
  final String? profileId;

  const EquipmentProfileEditorScreen({super.key, this.profileId});

  @override
  ConsumerState<EquipmentProfileEditorScreen> createState() =>
      _EquipmentProfileEditorScreenState();
}

class _EquipmentProfileEditorScreenState
    extends ConsumerState<EquipmentProfileEditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _defaultIncrementController =
      TextEditingController();

  static final List<CanonicalEquipmentItem> _catalogItems =
      EquipmentChoicesPresentation.editableItems;

  late final Map<String, bool> _availability;
  late final Map<String, TextEditingController> _incrementControllers;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _availability = {for (final item in _catalogItems) item.id: false};
    _incrementControllers = {
      for (final item in _catalogItems) item.id: TextEditingController(),
    };
    if (widget.profileId != null) {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _defaultIncrementController.dispose();
    for (final controller in _incrementControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(equipmentProfileRepositoryProvider);
      final aggregate = await repo.getProfile(widget.profileId!);
      if (aggregate != null) {
        _nameController.text = aggregate.profile.name;
        _noteController.text = aggregate.profile.note ?? '';
        _defaultIncrementController.text =
            aggregate.profile.defaultWeightIncrementKg?.toString() ?? '';
        for (final item in aggregate.items) {
          _availability[item.equipmentCode] = item.isAvailable;
          _incrementControllers[item.equipmentCode]?.text =
              item.weightIncrementKg?.toString() ?? '';
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipment profile could not be loaded. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyPreset(EquipmentPreset preset) {
    setState(() {
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = preset.name;
      }
      if (_noteController.text.trim().isEmpty && preset.description.isNotEmpty) {
        _noteController.text = preset.description;
      }

      final includedSet = preset.includedItems.map((i) => i.id).toSet();
      for (final item in _catalogItems) {
        final isIncluded = includedSet.contains(item.id);
        _availability[item.id] = isIncluded;
        if (isIncluded && preset.standardIncrements.containsKey(item.id)) {
          _incrementControllers[item.id]?.text =
              preset.standardIncrements[item.id]!.toString();
        } else if (!isIncluded) {
          _incrementControllers[item.id]?.clear();
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied "${preset.name}" preset.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearAllEquipment() {
    setState(() {
      for (final item in _catalogItems) {
        _availability[item.id] = false;
        _incrementControllers[item.id]?.clear();
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Profile name cannot be blank.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a profile name.')),
      );
      return;
    }
    setState(() => _nameError = null);

    double? parseIncrement(String raw, String label) {
      final value = raw.trim();
      if (value.isEmpty) return null;
      final parsed = double.tryParse(value);
      if (parsed == null || !parsed.isFinite || parsed <= 0) {
        throw ArgumentError('$label must be a positive number.');
      }
      return parsed;
    }

    List<EquipmentProfileItemInput> items;
    double? defaultIncrement;
    try {
      defaultIncrement = parseIncrement(
        _defaultIncrementController.text,
        'Default weight increment',
      );
      items = _catalogItems
          .map(
            (item) => EquipmentProfileItemInput(
              equipmentCode: item.id,
              isAvailable: _availability[item.id] ?? false,
              weightIncrementKg: parseIncrement(
                _incrementControllers[item.id]!.text,
                '${item.displayName} weight increment',
              ),
            ),
          )
          .toList(growable: false);
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message.toString())),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(equipmentProfileRepositoryProvider);
      final note = _noteController.text.trim();

      if (widget.profileId != null) {
        await repo.updateProfile(
          profileId: widget.profileId!,
          name: name,
          note: note.isEmpty ? null : note,
          clearNote: note.isEmpty,
          defaultWeightIncrementKg: defaultIncrement,
          clearDefaultWeightIncrement: defaultIncrement == null,
          items: items,
        );
      } else {
        final newId = await repo.createProfile(
          name: name,
          note: note.isEmpty ? null : note,
          defaultWeightIncrementKg: defaultIncrement,
          items: items,
        );

        // If this is the only profile, set it as default
        final currentDefault = await repo.getDefaultProfileId();
        if (currentDefault == null) {
          await repo.setDefaultProfileId(newId);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipment profile saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e is ArgumentError
            ? e.message.toString()
            : e is StateError
            ? e.message
            : 'Equipment profile could not be saved. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
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
          widget.profileId == null ? 'New Profile' : 'Edit Profile',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(B05Layout.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileDetailsSection(colors),
                  const SizedBox(height: B05Layout.space20),
                  _buildPresetsSection(colors),
                  const SizedBox(height: B05Layout.space20),
                  _buildEquipmentListSection(colors),
                  const SizedBox(height: B05Layout.space24),
                  _buildSaveButton(colors),
                  const SizedBox(height: B05Layout.space24),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileDetailsSection(B05SemanticColors colors) {
    return B05Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Details',
            style: B05Typography.title(context),
          ),
          const SizedBox(height: B05Layout.space12),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Profile Name (e.g. Home Gym, Hotel Gym)',
              errorText: _nameError,
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: B05Layout.space12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional, e.g. Basement setup with power rack)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: B05Layout.space12),
          TextField(
            controller: _defaultIncrementController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Default weight increment (kg, optional)',
              helperText:
                  'Used when an item does not have its own increment.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsSection(B05SemanticColors colors) {
    return B05Surface(
      tone: B05SurfaceTone.inset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: B05Layout.iconMedium, color: colors.action),
              const SizedBox(width: B05Layout.space8),
              Text(
                'Quick Presets',
                style: B05Typography.label(context),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Tap a preset to quickly toggle standard equipment items:',
            style: B05Typography.caption(context),
          ),
          const SizedBox(height: B05Layout.space12),
          Wrap(
            spacing: B05Layout.space8,
            runSpacing: B05Layout.space8,
            children: [
              ...EquipmentChoicesPresentation.presets.map((preset) {
                return ActionChip(
                  avatar: const Icon(Icons.bolt, size: B05Layout.iconSmall),
                  label: Text(preset.name),
                  onPressed: () => _applyPreset(preset),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.clear_all, size: B05Layout.iconSmall),
                label: const Text('Clear All'),
                onPressed: _clearAllEquipment,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentListSection(B05SemanticColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Equipment Availability',
          style: B05Typography.title(context),
        ),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Bodyweight is always available and is not stored as an item.',
          style: B05Typography.caption(context),
        ),
        const SizedBox(height: B05Layout.space12),
        ..._catalogItems.map((item) {
          final choice = EquipmentChoicesPresentation.find(item.id);
          final isAvailable = _availability[item.id] ?? false;
          final icon = choice?.icon ?? Icons.fitness_center;
          final description = choice?.description ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: B05Layout.space8),
            child: B05Surface(
              tone: isAvailable ? B05SurfaceTone.selected : B05SurfaceTone.section,
              padding: const EdgeInsets.all(B05Layout.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(icon, color: isAvailable ? colors.action : colors.textSecondary),
                    title: Text(
                      item.displayName,
                      style: B05Typography.label(context),
                    ),
                    subtitle: description.isNotEmpty
                        ? Text(description, style: B05Typography.caption(context))
                        : null,
                    value: isAvailable,
                    onChanged: (value) {
                      setState(() => _availability[item.id] = value);
                    },
                  ),
                  if (isAvailable) ...[
                    const SizedBox(height: B05Layout.space8),
                    Padding(
                      padding: const EdgeInsets.only(left: 40.0),
                      child: TextField(
                        controller: _incrementControllers[item.id],
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: '${item.displayName} increment (kg, optional)',
                          hintText: 'e.g. 2.5',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSaveButton(B05SemanticColors colors) {
    return SizedBox(
      width: double.infinity,
      child: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : B05ActionButton(
              label: 'Save Profile',
              icon: Icons.save_rounded,
              onPressed: _save,
            ),
    );
  }
}
