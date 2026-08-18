import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/equipment_preference_repository.dart';

/// Screen listing user equipment profiles, indicating default selection and active travel usage.
class EquipmentProfilesScreen extends ConsumerStatefulWidget {
  const EquipmentProfilesScreen({super.key});

  @override
  ConsumerState<EquipmentProfilesScreen> createState() =>
      _EquipmentProfilesScreenState();
}

class _EquipmentProfilesScreenState
    extends ConsumerState<EquipmentProfilesScreen> {
  bool _isLoading = true;
  List<EquipmentProfileAggregate> _profiles = [];
  String? _defaultProfileId;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(equipmentProfileRepositoryProvider);
      final activeProfiles = await repo.getActiveProfiles();
      final defaultId = await repo.getDefaultProfileId();

      final aggregates = <EquipmentProfileAggregate>[];
      for (final p in activeProfiles) {
        final agg = await repo.getProfile(p.id);
        if (agg != null) aggregates.add(agg);
      }

      setState(() {
        _profiles = aggregates;
        _defaultProfileId = defaultId;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipment profiles could not be loaded. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _setDefault(String profileId) async {
    try {
      final repo = ref.read(equipmentProfileRepositoryProvider);
      await repo.setDefaultProfileId(profileId);
      await _loadProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default equipment profile updated.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default profile could not be updated. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _archiveProfile(String profileId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive equipment profile?'),
        content: const Text(
          'Archived profiles stay available for historical workouts but cannot be selected for future planning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final repo = ref.read(equipmentProfileRepositoryProvider);
      await repo.archiveProfile(profileId);
      await _loadProfiles();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile archived.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Equipment profile could not be archived. Try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Equipment Profiles',
          style: TextStyle(fontFamily: 'Outfit'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/equipment-profile-editor');
          await _loadProfiles();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
          ? Center(
              child: Text(
                'No equipment profiles found.',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _profiles.length,
              itemBuilder: (context, idx) {
                final aggregate = _profiles[idx];
                final profile = aggregate.profile;
                final isDefault = profile.id == _defaultProfileId;

                final availableCount = aggregate.items
                    .where((i) => i.isAvailable)
                    .length;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppColors.cardBackground,
                  child: ListTile(
                    title: Row(
                      children: [
                        Text(
                          profile.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'DEFAULT',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text('$availableCount equipment items available'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'default') _setDefault(profile.id);
                        if (val == 'edit') {
                          context
                              .push(
                                '/equipment-profile-editor?profileId=${profile.id}',
                              )
                              .then((_) => _loadProfiles());
                        }
                        if (val == 'archive') _archiveProfile(profile.id);
                      },
                      itemBuilder: (context) => [
                        if (!isDefault)
                          const PopupMenuItem(
                            value: 'default',
                            child: Text('Set as Default'),
                          ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Profile'),
                        ),
                        if (!isDefault)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text(
                              'Archive Profile',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
