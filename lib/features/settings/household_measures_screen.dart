import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_household_measures.dart';
import '../../core/presentation/secondary_presentation.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import 'household_measures_controller.dart';

class HouseholdMeasuresScreen extends ConsumerStatefulWidget {
  const HouseholdMeasuresScreen({super.key});

  @override
  ConsumerState<HouseholdMeasuresScreen> createState() =>
      _HouseholdMeasuresScreenState();
}

class _HouseholdMeasuresScreenState
    extends ConsumerState<HouseholdMeasuresScreen> {
  String? _selectedMeasure;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      householdMeasuresControllerProvider(kLocalNutritionUserScopeId),
    );
    final controller = ref.read(
      householdMeasuresControllerProvider(kLocalNutritionUserScopeId).notifier,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measuring at home'),
        actions: [
          IconButton(
            tooltip: 'Retry loading household measures',
            onPressed: state.isSaving ? null : controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isSaving ? null : () => _showCreateVessel(context),
        icon: const Icon(Icons.add),
        label: const Text('Measure your own'),
      ),
      body: state.isLoading
          ? const Center(
              child: ConsumerStatusRow(
                label: 'Loading your measures',
                detail: 'Getting your cups, bowls, and calibrations ready.',
                loading: true,
              ),
            )
          : state.status == HouseholdMeasuresStatus.error
          ? _ErrorState(message: state.message, onRetry: controller.load)
          : _content(context, state, controller),
    );
  }

  Widget _content(
    BuildContext context,
    HouseholdMeasuresState state,
    HouseholdMeasuresController controller,
  ) {
    final standardMeasures = NutritionStandardHouseholdMeasures.definitions;
    final activeVessels = state.vessels.where((vessel) => !vessel.isArchived);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Semantics(
          container: true,
          label: 'Volume-only household measure information',
          child: B05Surface(
            showBorder: false,
            subtle: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A quick note about measuring',
                  style: B05Typography.title(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'A cup tells us volume, not weight. Your measured cup is useful for portions, but it does not turn water, rice, dal, or another food into grams.',
                  style: B05Typography.body(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('STANDARD MEASURES', style: B05Typography.label(context)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final definition in standardMeasures)
              _standardChoice(context, definition),
            for (final vessel in activeVessels)
              Semantics(
                button: true,
                label: _vesselSemanticsLabel(
                  vessel,
                  state.currentCalibrations[vessel.id],
                ),
                child: ChoiceChip(
                  label: Text(
                    '${vessel.displayName} (${_vesselVolumeLabel(state.currentCalibrations[vessel.id])})',
                  ),
                  selected: _selectedMeasure == vessel.id,
                  onSelected: (_) =>
                      setState(() => _selectedMeasure = vessel.id),
                ),
              ),
          ],
        ),
        if (state.status == HouseholdMeasuresStatus.empty) ...[
          const SizedBox(height: 20),
          const Text(
            'No personal measures yet. Add one when you want to measure your everyday cup or bowl.',
          ),
        ],
        if (state.message != null &&
            state.status == HouseholdMeasuresStatus.validationError) ...[
          const SizedBox(height: 12),
          _MessageCard(message: state.message!, isError: true),
        ],
        const SizedBox(height: 24),
        Text('YOUR MEASURES', style: B05Typography.label(context)),
        const SizedBox(height: 8),
        if (state.vessels.isEmpty)
          const Text('Your measured cups and bowls will appear here.')
        else
          for (final vessel in state.vessels)
            _vesselCard(context, state, controller, vessel),
      ],
    );
  }

  Widget _vesselCard(
    BuildContext context,
    HouseholdMeasuresState state,
    HouseholdMeasuresController controller,
    NutritionPersonalVessel vessel,
  ) {
    final calibration = state.currentCalibrations[vessel.id];
    final archived = vessel.isArchived;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: B05Surface(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vessel.displayName,
                    style: B05Typography.title(context),
                  ),
                ),
                if (archived)
                  const Chip(
                    label: Text('Past measure'),
                    visualDensity: VisualDensity.compact,
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Measure actions',
                  onSelected: (action) {
                    switch (action) {
                      case 'rename':
                        _showRenameVessel(context, vessel);
                      case 'archive':
                        _confirmArchive(context, vessel, controller);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    if (!archived)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Keep in history'),
                      ),
                  ],
                ),
              ],
            ),
            if (vessel.vesselType != null) ...[
              const SizedBox(height: 2),
              Text(vessel.vesselType!, style: B05Typography.body(context)),
            ],
            const SizedBox(height: 8),
            Semantics(
              label: 'Measured capacity',
              child: Text(
                archived
                    ? 'Past capacity: ${_vesselVolumeLabel(calibration)}'
                    : 'Capacity: ${_vesselVolumeLabel(calibration)}',
              ),
            ),
            const SizedBox(height: 8),
            if (!archived)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: state.isSaving
                      ? null
                      : () => _showCalibration(context, vessel),
                  icon: const Icon(Icons.water_drop_outlined, size: 18),
                  label: Text(
                    calibration == null
                        ? 'Measure this cup or bowl'
                        : 'Measure again',
                  ),
                ),
              ),
            if (archived)
              Text(
                'This measure is kept for your history and is no longer offered for new entries.',
                style: B05Typography.body(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _standardChoice(
    BuildContext context,
    NutritionHouseholdMeasureDefinition definition,
  ) {
    final presentation = HouseholdMeasurePresentation.fromDefinition(
      definition,
    );
    return Semantics(
      button: true,
      label: _standardSemanticsLabel(definition),
      child: ChoiceChip(
        label: Text(
          presentation.volume == null
              ? '${presentation.label} (Not calibrated)'
              : '${presentation.label} (${presentation.volume})',
        ),
        selected: _selectedMeasure == definition.id,
        onSelected: (_) => setState(() => _selectedMeasure = definition.id),
      ),
    );
  }

  Future<void> _showCreateVessel(BuildContext context) async {
    var name = '';
    var type = '';
    final values = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Measure your own cup or bowl'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'What should we call it?',
                hintText: 'Breakfast bowl',
              ),
              onChanged: (value) => name = value,
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Shape (optional)',
                hintText: 'Bowl, cup, or katori',
              ),
              onChanged: (value) => type = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'name': name,
              'type': type.trim().isEmpty ? null : type.trim(),
            }),
            child: const Text('Add measure'),
          ),
        ],
      ),
    );
    if (!mounted || values == null) return;
    await ref
        .read(
          householdMeasuresControllerProvider(
            kLocalNutritionUserScopeId,
          ).notifier,
        )
        .createVessel(
          displayName: values['name'] ?? '',
          vesselType: values['type'],
        );
  }

  Future<void> _showRenameVessel(
    BuildContext context,
    NutritionPersonalVessel vessel,
  ) async {
    var name = vessel.displayName;
    final nameController = TextEditingController(text: vessel.displayName);
    String? updatedName;
    try {
      updatedName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rename measure'),
          content: TextField(
            autofocus: true,
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Measure name'),
            onChanged: (value) => name = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, name),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      nameController.dispose();
    }
    if (!mounted || updatedName == null) return;
    await ref
        .read(
          householdMeasuresControllerProvider(
            kLocalNutritionUserScopeId,
          ).notifier,
        )
        .renameVessel(vesselId: vessel.id, displayName: updatedName);
  }

  Future<void> _showCalibration(
    BuildContext context,
    NutritionPersonalVessel vessel,
  ) async {
    var volume = '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Measure its capacity'),
        content: TextField(
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Capacity',
            hintText: '180',
            suffixText: 'mL',
            helperText: 'Volume only — it does not tell us food weight.',
          ),
          onChanged: (input) => volume = input,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, volume),
            child: const Text('Save measurement'),
          ),
        ],
      ),
    );
    if (!mounted || value == null) return;
    await ref
        .read(
          householdMeasuresControllerProvider(
            kLocalNutritionUserScopeId,
          ).notifier,
        )
        .calibrateVessel(vesselId: vessel.id, volumeMillilitres: value);
  }

  Future<void> _confirmArchive(
    BuildContext context,
    NutritionPersonalVessel vessel,
    HouseholdMeasuresController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep this measure in history?'),
        content: const Text(
          'Its measurement will remain readable, but it will no longer be offered for new entries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keep in history'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await controller.archiveVessel(vessel.id);
    }
  }

  static String _standardSemanticsLabel(
    NutritionHouseholdMeasureDefinition definition,
  ) => definition.hasReviewedVolume
      ? '${definition.displayName}, reviewed volume ${definition.volume!.point} mL'
      : '${definition.displayName}, not calibrated; measure yours';

  static String _vesselSemanticsLabel(
    NutritionPersonalVessel vessel,
    NutritionVesselCalibration? calibration,
  ) => '${vessel.displayName}, ${_vesselVolumeLabel(calibration)}';

  static String _vesselVolumeLabel(NutritionVesselCalibration? calibration) {
    if (calibration == null) return 'Not calibrated';
    final volume = calibration.volume.normalizedToMillilitres();
    if (volume.point == null) return 'Needs measuring';
    return '${volume.point} mL';
  }
}

class _ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 42),
          const SizedBox(height: 12),
          const Text('Household measures could not be loaded. Try again.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageCard({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) => Card(
    color: isError
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
  );
}
