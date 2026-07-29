import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/providers.dart';
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

  static const List<String> _catalogCodes = [
    'barbell',
    'dumbbell',
    'cable',
    'machine',
    'smith_machine',
    'kettlebell',
    'bodyweight',
    'band',
  ];

  final Map<String, bool> _availability = {
    for (final code in _catalogCodes) code: true,
  };

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.profileId != null) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(equipmentProfileRepositoryProvider);
      final aggregate = await repo.getProfile(widget.profileId!);
      if (aggregate != null) {
        _nameController.text = aggregate.profile.name;
        for (final item in aggregate.items) {
          _availability[item.equipmentCode] = item.isAvailable;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
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

    final items = _availability.entries.map((e) {
      return EquipmentProfileItemInput(
        equipmentCode: e.key,
        isAvailable: e.value,
      );
    }).toList();

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(equipmentProfileRepositoryProvider);
      if (widget.profileId != null) {
        await repo.updateProfile(
          profileId: widget.profileId!,
          name: name,
          items: items,
        );
      } else {
        await repo.createProfile(name: name, items: items);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipment profile saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
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
                  Text(
                    'Equipment Availability',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.outfit().fontFamily,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._catalogCodes.map((code) {
                    final isAvailable = _availability[code] ?? true;
                    return SwitchListTile(
                      tileColor: AppColors.cardBackground,
                      title: Text(
                        code.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: isAvailable,
                      onChanged: (val) {
                        setState(() {
                          _availability[code] = val;
                        });
                      },
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
