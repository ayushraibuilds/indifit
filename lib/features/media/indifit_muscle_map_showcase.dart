import 'package:flutter/material.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';

import 'indifit_muscle_map.dart';

/// Isolated development/test showcase for the local renderer foundation.
///
/// This widget is intentionally not registered in the production router and
/// has no persistence or product-screen dependencies.
class IndiFitMuscleMapShowcase extends StatefulWidget {
  const IndiFitMuscleMapShowcase({super.key});

  @override
  State<IndiFitMuscleMapShowcase> createState() =>
      _IndiFitMuscleMapShowcaseState();
}

class _IndiFitMuscleMapShowcaseState extends State<IndiFitMuscleMapShowcase> {
  IndiFitMuscleMapBody _body = IndiFitMuscleMapBody.male;
  IndiFitMuscleMapView _view = IndiFitMuscleMapView.both;
  IndiFitMuscleMapMode _mode = IndiFitMuscleMapMode.exercise;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return ListView(
      padding: const EdgeInsets.all(B05Layout.space16),
      children: [
        Text('Local IndiFit Muscle Map', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Pinned local geometry showcase. This is not production integration.',
          style: B05Typography.caption(context),
        ),
        const SizedBox(height: B05Layout.space16),
        B05Surface(
          tone: B05SurfaceTone.inset,
          padding: const EdgeInsets.all(B05Layout.space12),
          child: Wrap(
            spacing: B05Layout.space12,
            runSpacing: B05Layout.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Selector<IndiFitMuscleMapBody>(
                label: 'Body',
                value: _body,
                items: IndiFitMuscleMapBody.values,
                labelFor: (value) => value.name,
                onChanged: (value) => setState(() => _body = value),
              ),
              _Selector<IndiFitMuscleMapView>(
                label: 'View',
                value: _view,
                items: IndiFitMuscleMapView.values,
                labelFor: (value) => value.name,
                onChanged: (value) => setState(() => _view = value),
              ),
              _Selector<IndiFitMuscleMapMode>(
                label: 'Mode',
                value: _mode,
                items: const [
                  IndiFitMuscleMapMode.exercise,
                  IndiFitMuscleMapMode.intensity,
                ],
                labelFor: (value) => value.name,
                onChanged: (value) => setState(() => _mode = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space16),
        _mode == IndiFitMuscleMapMode.exercise
            ? IndiFitMuscleMap.exercise(
                primaryMuscle: 'Chest',
                secondaryMuscles: const ['Triceps', 'Shoulders'],
                bodyModel: _body,
                view: _view,
              )
            : IndiFitMuscleMap.intensity(
                intensityValues: const {
                  'Chest': 0.9,
                  'Triceps': 0.55,
                  'Shoulders': 0.3,
                },
                metricLabel: 'Illustrative intensity',
                bodyModel: _body,
                view: _view,
              ),
        const SizedBox(height: B05Layout.space24),
        Text('Representative states', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space8),
        Text(
          'These samples cover broad mappings, unknown/no-data behavior, '
          'both body models, both directions, and heat values.',
          style: B05Typography.caption(context),
        ),
        const SizedBox(height: B05Layout.space12),
        _sample(
          context,
          title: 'Chest primary — male front',
          child: const IndiFitMuscleMap.exercise(
            primaryMuscle: 'Chest',
            bodyModel: IndiFitMuscleMapBody.male,
            view: IndiFitMuscleMapView.front,
          ),
        ),
        _sample(
          context,
          title: 'Chest + Triceps/Shoulders — male back',
          child: const IndiFitMuscleMap.exercise(
            primaryMuscle: 'Chest',
            secondaryMuscles: ['Triceps', 'Shoulders'],
            bodyModel: IndiFitMuscleMapBody.male,
            view: IndiFitMuscleMapView.back,
          ),
        ),
        _sample(
          context,
          title: 'Back broad mapping — male both',
          child: const IndiFitMuscleMap.exercise(
            primaryMuscle: 'Back',
            bodyModel: IndiFitMuscleMapBody.male,
            view: IndiFitMuscleMapView.both,
          ),
        ),
        _sample(
          context,
          title: 'Quads — female front',
          child: const IndiFitMuscleMap.exercise(
            primaryMuscle: 'Quads',
            bodyModel: IndiFitMuscleMapBody.female,
            view: IndiFitMuscleMapView.front,
          ),
        ),
        _sample(
          context,
          title: 'Hamstrings + Glutes — female back',
          child: const IndiFitMuscleMap.exercise(
            primaryMuscle: 'Hamstrings',
            secondaryMuscles: ['Glutes'],
            bodyModel: IndiFitMuscleMapBody.female,
            view: IndiFitMuscleMapView.back,
          ),
        ),
        _sample(
          context,
          title: 'Core — female both',
          child: const IndiFitMuscleMap.exercise(
            primaryMuscle: 'Core',
            bodyModel: IndiFitMuscleMapBody.female,
            view: IndiFitMuscleMapView.both,
          ),
        ),
        _sample(
          context,
          title: 'Multiple heat levels — male both',
          child: const IndiFitMuscleMap.intensity(
            intensityValues: {'Chest': 0.95, 'Back': 0.55, 'Calves': 0.15},
            metricLabel: 'Illustrative intensity',
            bodyModel: IndiFitMuscleMapBody.male,
            view: IndiFitMuscleMapView.both,
          ),
        ),
        _sample(
          context,
          title: 'No data — neutral female both',
          child: const IndiFitMuscleMap.noData(
            bodyModel: IndiFitMuscleMapBody.female,
            view: IndiFitMuscleMapView.both,
          ),
        ),
        _sample(
          context,
          title: 'Unknown muscle — neutral unmatched regions',
          child: const IndiFitMuscleMap.exercise(
            primaryMuscle: 'Imaginary muscle',
            bodyModel: IndiFitMuscleMapBody.female,
            view: IndiFitMuscleMapView.front,
          ),
        ),
        const SizedBox(height: B05Layout.space16),
        Text('Visual legend', style: B05Typography.label(context)),
        const SizedBox(height: B05Layout.space8),
        Wrap(
          spacing: B05Layout.space16,
          runSpacing: B05Layout.space8,
          children: [
            _LegendSwatch(color: colors.success.indicator, label: 'Primary'),
            _LegendSwatch(
              color: colors.info.indicator,
              label: 'Secondary / patterned',
            ),
            _LegendSwatch(
              color: colors.danger.indicator,
              label: 'Heat intensity',
            ),
          ],
        ),
      ],
    );
  }

  Widget _sample(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space12),
      child: B05Surface(
        tone: B05SurfaceTone.section,
        showBorder: true,
        padding: const EdgeInsets.all(B05Layout.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: B05Typography.label(context)),
            const SizedBox(height: B05Layout.space8),
            child,
          ],
        ),
      ),
    );
  }
}

class _Selector<T> extends StatelessWidget {
  const _Selector({
    required this.label,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<T>(
      value: value,
      isDense: true,
      underline: const SizedBox.shrink(),
      hint: Text(label),
      selectedItemBuilder: (context) => [
        for (final item in items) Text('$label: ${labelFor(item)}'),
      ],
      items: [
        for (final item in items)
          DropdownMenuItem<T>(value: item, child: Text(labelFor(item))),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: B05Radii.smallRadius,
          ),
          child: const SizedBox(width: 18, height: 18),
        ),
        const SizedBox(width: B05Layout.space4),
        Text(label, style: B05Typography.caption(context)),
      ],
    );
  }
}
