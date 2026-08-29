import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/equipment_presentation.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/repositories/equipment_preference_repository.dart';

/// Screen listing user equipment profiles, indicating default selection and available gear.
class EquipmentProfilesScreen extends ConsumerStatefulWidget {
  const EquipmentProfilesScreen({super.key});

  @override
  ConsumerState<EquipmentProfilesScreen> createState() =>
      _EquipmentProfilesScreenState();
}

class _EquipmentProfilesScreenState
    extends ConsumerState<EquipmentProfilesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<EquipmentProfilePresentation> _profiles = [];
  String? _defaultProfileId;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    if (!_isLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final repo = ref.read(equipmentProfileRepositoryProvider);
      final activeProfiles = await repo.getActiveProfiles();
      final defaultId = await repo.getDefaultProfileId();

      final presentations = <EquipmentProfilePresentation>[];
      for (final p in activeProfiles) {
        final agg = await repo.getProfile(p.id);
        if (agg != null) {
          presentations.add(
            EquipmentProfilePresentation.fromAggregate(
              agg,
              isDefault: agg.profile.id == defaultId,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _profiles = presentations;
          _defaultProfileId = defaultId;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Equipment profiles could not be loaded. Check your data and try again.';
        });
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
    } catch (e) {
      if (mounted) {
        final msg = e is StateError
            ? e.message
            : 'Default profile could not be updated. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  Future<void> _createFromPreset(EquipmentPreset preset) async {
    try {
      final repo = ref.read(equipmentProfileRepositoryProvider);
      final items = preset.includedItems
          .map(
            (item) => EquipmentProfileItemInput(
              equipmentCode: item.id,
              isAvailable: true,
              weightIncrementKg: preset.standardIncrements[item.id],
            ),
          )
          .toList(growable: false);

      final newId = await repo.createProfile(
        name: preset.name,
        note: preset.description,
        items: items,
      );

      // If no default profile is set yet, make this one the default.
      if (_defaultProfileId == null) {
        await repo.setDefaultProfileId(newId);
      }

      await _loadProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created "${preset.name}" profile.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ArgumentError
            ? e.message.toString()
            : 'Profile could not be created. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  Future<void> _archiveProfile(String profileId, String profileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive "$profileName"?'),
        content: const Text(
          'Archived profiles stay available for historical workouts but cannot be selected for future planning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile archived.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e is StateError
            ? e.message
            : 'Equipment profile could not be archived. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Profiles'),
      ),
      floatingActionButton: _profiles.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/equipment-profile-editor');
                await _loadProfiles();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Profile'),
            )
          : null,
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(B05SemanticColors colors) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(B05Layout.space16),
          child: ProductFailureCard(
            failure: ProductFailurePresentation(
              title: 'Unable to Load Profiles',
              message: _errorMessage!,
              canRetry: true,
            ),
            onRetry: _loadProfiles,
          ),
        ),
      );
    }

    if (_profiles.isEmpty) {
      return _buildEmptyState(colors);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(B05Layout.space16),
      itemCount: _profiles.length + 1,
      itemBuilder: (context, idx) {
        if (idx == 0) {
          return _buildInfoBanner(colors);
        }
        final profile = _profiles[idx - 1];
        return _buildProfileCard(profile, colors);
      },
    );
  }

  Widget _buildInfoBanner(B05SemanticColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space16),
      child: B05Surface(
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
                'Equipment profiles define what gear is available in your gym or training space. Your active profile helps IndiFit suggest suitable exercises and show the right weight steps.',
                style: B05Typography.caption(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(B05SemanticColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(B05Layout.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          B05Surface(
            child: Column(
              children: [
                Icon(
                  Icons.fitness_center_outlined,
                  size: 48,
                  color: colors.action,
                ),
                const SizedBox(height: B05Layout.space16),
                Text(
                  'No Equipment Profiles Yet',
                  style: B05Typography.title(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: B05Layout.space8),
                Text(
                  'Set up an equipment profile to specify your available gear for workouts and future planning.',
                  style: B05Typography.body(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: B05Layout.space20),
                B05ActionButton(
                  label: 'Create Custom Profile',
                  icon: Icons.add_rounded,
                  onPressed: () async {
                    await context.push('/equipment-profile-editor');
                    await _loadProfiles();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: B05Layout.space24),
          Text(
            'Quick Starter Presets',
            style: B05Typography.label(context),
          ),
          const SizedBox(height: B05Layout.space8),
          Text(
            'Choose a preset to create your first equipment profile in one tap:',
            style: B05Typography.caption(context),
          ),
          const SizedBox(height: B05Layout.space12),
          ...EquipmentChoicesPresentation.presets.map((preset) {
            return Padding(
              padding: const EdgeInsets.only(bottom: B05Layout.space8),
              child: B05Surface(
                tone: B05SurfaceTone.interactive,
                child: InkWell(
                  onTap: () => _createFromPreset(preset),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: B05Layout.space4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: colors.action,
                          size: B05Layout.iconMedium,
                        ),
                        const SizedBox(width: B05Layout.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preset.name,
                                style: B05Typography.label(context),
                              ),
                              Text(
                                preset.description,
                                style: B05Typography.caption(context),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: B05Layout.iconSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    EquipmentProfilePresentation profile,
    B05SemanticColors colors,
  ) {
    final isDefault = profile.isDefault;

    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space12),
      child: B05Surface(
        tone: isDefault ? B05SurfaceTone.selected : B05SurfaceTone.section,
        showBorder: isDefault,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          style: B05Typography.title(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: B05Layout.space8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: B05Layout.space8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.action.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(B05Radii.small),
                            border: Border.all(
                              color: colors.action.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'DEFAULT',
                            style: TextStyle(
                              color: colors.action,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Profile options for ${profile.name}',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (val) {
                    if (val == 'default') _setDefault(profile.id);
                    if (val == 'edit') {
                      context
                          .push(
                            '/equipment-profile-editor?profileId=${profile.id}',
                          )
                          .then((_) => _loadProfiles());
                    }
                    if (val == 'archive') {
                      _archiveProfile(profile.id, profile.name);
                    }
                  },
                  itemBuilder: (popupContext) => [
                    if (!isDefault)
                      const PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 20),
                            SizedBox(width: 8),
                            Text('Set as Default'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Edit Profile'),
                        ],
                      ),
                    ),
                    if (!isDefault)
                      PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(
                              Icons.archive_outlined,
                              size: 20,
                              color: colors.danger.indicator,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Archive',
                              style: TextStyle(color: colors.danger.indicator),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (profile.note != null && profile.note!.isNotEmpty) ...[
              const SizedBox(height: B05Layout.space4),
              Text(
                profile.note!,
                style: B05Typography.body(context),
              ),
            ],
            const SizedBox(height: B05Layout.space8),
            Text(
              profile.formattedItemCount,
              style: B05Typography.caption(context),
            ),
            if (profile.formattedDefaultIncrement != null) ...[
              const SizedBox(height: B05Layout.space4),
              Text(
                'Default load increment: ${profile.formattedDefaultIncrement}',
                style: B05Typography.caption(context),
              ),
            ],
            if (profile.itemChips.isNotEmpty) ...[
              const SizedBox(height: B05Layout.space12),
              Wrap(
                spacing: B05Layout.space8,
                runSpacing: B05Layout.space4,
                children: profile.itemChips.map((chip) {
                  return Chip(
                    avatar: Icon(chip.icon, size: B05Layout.iconSmall),
                    label: Text(
                      chip.incrementText != null
                          ? '${chip.name} (${chip.incrementText})'
                          : chip.name,
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
