import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/equipment_fixtures.dart';
import '../../core/theme/colors.dart';
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
  final TextEditingController _defaultIncrementController =
      TextEditingController();

  /// This is intentionally derived from B01-01's canonical fixture rather
  /// than maintaining a UI-specific list. Bodyweight is an implicit
  /// capability and must not be persisted as an equipment profile item.
  static final List<CanonicalEquipmentItem> _catalogItems =
      CanonicalEquipmentItem.values
          .where((item) => item != CanonicalEquipmentItem.bodyweight)
          .toList(growable: false);

  late final Map<String, bool> _availability;
  late final Map<String, TextEditingController> _incrementControllers;

  bool _isLoading = false;

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

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a profile name.')),
      );
      return;
    }

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
    } on ArgumentError {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid positive numbers.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(equipmentProfileRepositoryProvider);
      if (widget.profileId != null) {
        await repo.updateProfile(
          profileId: widget.profileId!,
          name: name,
          defaultWeightIncrementKg: defaultIncrement,
          clearDefaultWeightIncrement: defaultIncrement == null,
          items: items,
        );
      } else {
        await repo.createProfile(
          name: name,
          defaultWeightIncrementKg: defaultIncrement,
          items: items,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipment profile saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipment profile could not be saved. Try again.'),
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
          widget.profileId == null ? 'New Profile' : 'Edit Profile',
          style: TextStyle(fontFamily: GoogleFonts.outfit().fontFamily),
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
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Profile Name (e.g. Home Gym, Hotel Gym)',
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(
                      fontFamily: GoogleFonts.outfit().fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _defaultIncrementController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Default weight increment (kg, optional)',
                      helperText:
                          'Used when an item does not have its own increment.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Equipment Availability',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.outfit().fontFamily,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bodyweight is always available and is not stored as an item.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ..._catalogItems.map((item) {
                    final isAvailable = _availability[item.id] ?? false;
                    return Card(
                      color: AppColors.cardBackground,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: Text(
                                item.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              value: isAvailable,
                              onChanged: (value) {
                                setState(() => _availability[item.id] = value);
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: TextField(
                                controller: _incrementControllers[item.id],
                                enabled: isAvailable,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText:
                                      '${item.displayName} increment (kg, optional)',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                      label: const Text('Save Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        textStyle: TextStyle(
                          fontFamily: GoogleFonts.outfit().fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
