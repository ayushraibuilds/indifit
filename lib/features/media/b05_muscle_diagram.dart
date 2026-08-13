import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fixtures/b02_muscle_catalog.dart';
import '../../core/fixtures/b05_foundation_registry.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/models/b02_execution_models.dart';
import '../education/b05_education_content.dart';

/// Validates the approved visual-region packet against the canonical B02
/// muscle IDs. A diagram cannot introduce a second taxonomy.
class B05MuscleDiagramValidator {
  final Set<String> canonicalMuscleIds;

  B05MuscleDiagramValidator({Iterable<String>? canonicalMuscleIds})
    : canonicalMuscleIds = Set.unmodifiable(
        canonicalMuscleIds ??
            B02CanonicalMuscleCatalog.muscles.map((muscle) => muscle.id),
      );

  void validate(B05MuscleVisualRegistry registry) {
    final regionIds = <String>{};
    for (final region in registry.regions) {
      if (!regionIds.add(region.regionId) ||
          !canonicalMuscleIds.contains(region.muscleId)) {
        throw B05RegistryValidationException(
          'muscle_diagram_mapping',
          'Every diagram region must map to a unique canonical B02 muscle ID.',
        );
      }
    }
  }
}

/// Product supplies the approved packaged diagram registry. Until that
/// rights/mapping packet exists, the null default keeps the canonical text
/// equivalent visible and makes the diagram honestly unavailable.
final b05MuscleVisualRegistryProvider = Provider<B05MuscleVisualRegistry?>(
  (_) => null,
);

/// Interactive region/list projection for canonical B02 labels. The visual
/// region packet is injected because its source and rights are product input;
/// when it is absent, the accessible canonical text list remains available.
class B05InteractiveMuscleDiagram extends StatefulWidget {
  final B05MuscleLabelSet muscles;
  final B05MuscleVisualRegistry? visualRegistry;

  const B05InteractiveMuscleDiagram({
    required this.muscles,
    super.key,
    this.visualRegistry,
  });

  @override
  State<B05InteractiveMuscleDiagram> createState() =>
      _B05InteractiveMuscleDiagramState();
}

class _B05InteractiveMuscleDiagramState
    extends State<B05InteractiveMuscleDiagram> {
  String? _selectedRegionId;

  @override
  Widget build(BuildContext context) {
    final registry = widget.visualRegistry;
    if (registry == null || registry.regions.isEmpty) {
      return _textFallback(context);
    }
    try {
      B05MuscleDiagramValidator().validate(registry);
    } on B05RegistryValidationException {
      return _textFallback(context);
    }
    final labelsById = {
      for (final label in widget.muscles.labels) label.muscleId: label,
    };
    final regions = [...registry.regions]
      ..sort((a, b) => a.textOrder.compareTo(b.textOrder));
    final selected = regions
        .where((region) => region.regionId == _selectedRegionId)
        .firstOrNull;
    final selectedLabel = selected == null
        ? null
        : labelsById[selected.muscleId];
    return B05Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interactive muscle diagram',
            style: B05Typography.title(context),
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Select a labelled region to see how it supports your workout.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space12),
          B05MotionContent(
            animatedChild: _regionGrid(context, regions, labelsById),
            reducedMotionChild: _regionList(context, regions, labelsById),
          ),
          if (selected != null) ...[
            const SizedBox(height: B05Layout.space12),
            B05StatusMessage(
              status: selectedLabel?.role == null
                  ? B05SemanticStatus.unavailable
                  : B05SemanticStatus.info,
              label: selected.label,
              value: selectedLabel?.roleLabel == null
                  ? 'Contribution mapping is unknown.'
                  : '${selectedLabel!.roleLabel} contribution',
            ),
          ],
          const SizedBox(height: B05Layout.space12),
          _textEquivalent(context, regions, labelsById),
        ],
      ),
    );
  }

  Widget _regionGrid(
    BuildContext context,
    List<B05MuscleDiagramRegion> regions,
    Map<String, B05MuscleLabel> labelsById,
  ) => Wrap(
    spacing: B05Layout.space8,
    runSpacing: B05Layout.space8,
    children: [
      for (final region in regions)
        B05ActionButton(
          label: region.label,
          hint: _regionHint(region, labelsById),
          selected: region.regionId == _selectedRegionId,
          emphasis: B05ActionEmphasis.secondary,
          onPressed: () => setState(() => _selectedRegionId = region.regionId),
        ),
    ],
  );

  Widget _regionList(
    BuildContext context,
    List<B05MuscleDiagramRegion> regions,
    Map<String, B05MuscleLabel> labelsById,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final region in regions) ...[
        B05ActionButton(
          label: region.label,
          hint: _regionHint(region, labelsById),
          selected: region.regionId == _selectedRegionId,
          emphasis: B05ActionEmphasis.secondary,
          onPressed: () => setState(() => _selectedRegionId = region.regionId),
        ),
        const SizedBox(height: B05Layout.space8),
      ],
    ],
  );

  Widget _textEquivalent(
    BuildContext context,
    List<B05MuscleDiagramRegion> regions,
    Map<String, B05MuscleLabel> labelsById,
  ) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Muscle diagram text equivalent',
    value: regions
        .map((region) => '${region.label}: ${_regionHint(region, labelsById)}')
        .join('. '),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Text list', style: B05Typography.label(context)),
        const SizedBox(height: B05Layout.space4),
        for (final region in regions)
          Padding(
            padding: const EdgeInsets.only(bottom: B05Layout.space4),
            child: Text(
              '${region.label}: ${_regionHint(region, labelsById)}',
              style: B05Typography.body(context),
            ),
          ),
      ],
    ),
  );

  Widget _textFallback(BuildContext context) {
    final labels = widget.muscles.labels;
    if (labels.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Muscle contribution text list',
      value: labels
          .map((label) => '${label.displayName}: ${label.roleLabel}')
          .join('. '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Muscle contribution', style: B05Typography.label(context)),
          const SizedBox(height: B05Layout.space4),
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.only(bottom: B05Layout.space4),
              child: Text(
                '${label.displayName}: ${label.roleLabel}',
                style: B05Typography.body(context),
              ),
            ),
        ],
      ),
    );
  }

  static String _regionHint(
    B05MuscleDiagramRegion region,
    Map<String, B05MuscleLabel> labelsById,
  ) {
    final role = labelsById[region.muscleId]?.role;
    return role == null
        ? 'Contribution not available'
        : '${switch (role) {
            B02MuscleRole.primary => 'Main',
            B02MuscleRole.secondary => 'Supporting',
            B02MuscleRole.stabilizing => 'Stabilising',
          }} contribution';
  }
}
