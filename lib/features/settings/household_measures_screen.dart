import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_household_measures.dart';
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
        title: const Text('Household Measures'),
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
        label: const Text('Add vessel'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
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
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Volume only',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A calibrated vessel records its capacity in mL. It does not imply grams for water, rice, dal, or any other food.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'SELECT A MEASURE',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final definition in standardMeasures)
              Semantics(
                button: true,
                label: _standardSemanticsLabel(definition),
                child: ChoiceChip(
                  label: Text(
                    definition.hasReviewedVolume
                        ? '${definition.displayName} (${definition.volume!.point} mL)'
                        : '${definition.displayName} (unresolved)',
                  ),
                  selected: _selectedMeasure == definition.id,
                  onSelected: (_) =>
                      setState(() => _selectedMeasure = definition.id),
                ),
              ),
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
            'No personal vessels yet. Add one when you want to record a measured capacity.',
          ),
        ],
        if (state.message != null &&
            state.status == HouseholdMeasuresStatus.validationError) ...[
          const SizedBox(height: 12),
          _MessageCard(message: state.message!, isError: true),
        ],
        const SizedBox(height: 24),
        const Text(
          'PERSONAL VESSELS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (state.vessels.isEmpty)
          const Text('Personal vessel history will appear here.')
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vessel.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (archived)
                  const Chip(
                    label: Text('Archived'),
                    visualDensity: VisualDensity.compact,
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Vessel actions',
                  onSelected: (action) {
                    switch (action) {
                      case 'rename':
                        _showRenameVessel(context, vessel);
                      case 'archive':
                        _confirmArchive(context, vessel, controller);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename vessel'),
                    ),
                    if (!archived)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Archive vessel'),
                      ),
                  ],
                ),
              ],
            ),
            if (vessel.vesselType != null) ...[
              const SizedBox(height: 2),
              Text(
                vessel.vesselType!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Semantics(
              label: 'Current calibrated vessel capacity',
              child: Text(
                archived
                    ? 'Historical calibration: ${_vesselVolumeLabel(calibration)}'
                    : 'Current capacity: ${_vesselVolumeLabel(calibration)}',
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
                        ? 'Record volume calibration'
                        : 'Recalibrate volume',
                  ),
                ),
              ),
            if (archived)
              Text(
                'Archived vessels remain readable for history and cannot be used for new entries.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateVessel(BuildContext context) async {
    var name = '';
    var type = '';
    final values = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add personal vessel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Vessel name',
                hintText: 'Breakfast bowl',
              ),
              onChanged: (value) => name = value,
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Type (optional)',
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
            child: const Text('Create'),
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
          title: const Text('Rename vessel'),
          content: TextField(
            autofocus: true,
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Vessel name'),
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
        title: const Text('Record vessel capacity'),
        content: TextField(
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Capacity (mL)',
            hintText: '180',
            suffixText: 'mL',
            helperText: 'This measures volume only, not food mass.',
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
            child: const Text('Save volume'),
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
        title: const Text('Archive vessel?'),
        content: const Text(
          'The vessel and its calibration history will remain readable, but it will not be offered for new entries.',
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
    if (confirmed == true && mounted) {
      await controller.archiveVessel(vessel.id);
    }
  }

  static String _standardSemanticsLabel(
    NutritionHouseholdMeasureDefinition definition,
  ) => definition.hasReviewedVolume
      ? '${definition.displayName}, reviewed volume ${definition.volume!.point} mL'
      : '${definition.displayName}, unresolved volume';

  static String _vesselSemanticsLabel(
    NutritionPersonalVessel vessel,
    NutritionVesselCalibration? calibration,
  ) => '${vessel.displayName}, ${_vesselVolumeLabel(calibration)}';

  static String _vesselVolumeLabel(NutritionVesselCalibration? calibration) {
    if (calibration == null) return 'volume unresolved';
    final volume = calibration.volume.normalizedToMillilitres();
    if (volume.point == null) return 'volume range unresolved';
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
          Text(message ?? 'Household measures could not be loaded.'),
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
