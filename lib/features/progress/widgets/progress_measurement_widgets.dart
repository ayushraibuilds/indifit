import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/repositories/workout_repository.dart';
import '../progress_dashboard_models.dart';
import 'progress_formatters.dart';
import 'progress_view_models.dart';

/// Progress measurement widgets (PV1-ENG-05A first pass).
///
/// Extracted verbatim from `progress_screen.dart`; behavior unchanged.

class ProgressMeasurementHistoryScreen extends StatelessWidget {
  const ProgressMeasurementHistoryScreen({
    super.key,
    required this.measurements,
  });

  final List<ProgressMeasurementRecord> measurements;

  @override
  Widget build(BuildContext context) {
    final ordered = measurements.toList(growable: true)
      ..sort(compareMeasurementsNewestFirst);
    return Scaffold(
      appBar: AppBar(title: const Text('Measurement history')),
      body: ListView.separated(
        padding: const EdgeInsets.all(B05Layout.space20),
        itemCount: ordered.length,
        separatorBuilder: (_, _) => const SizedBox(height: B05Layout.space8),
        itemBuilder: (context, index) {
          final measurement = ordered[index];
          final values = <String>[
            if (measurement.waistCm case final value?)
              'Waist ${formatNumber(value)} cm',
            if (measurement.chestCm case final value?)
              'Chest ${formatNumber(value)} cm',
            if (measurement.armsCm case final value?)
              'Arms ${formatNumber(value)} cm',
          ];
          return Semantics(
            label:
                '${shortCivilDate(measurement.localDate)}. ${values.join(', ')}.',
            child: B05Surface(
              tone: B05SurfaceTone.interactive,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortCivilDate(measurement.localDate),
                      style: B05Typography.label(context),
                    ),
                    const SizedBox(height: B05Layout.space8),
                    Wrap(
                      spacing: B05Layout.space8,
                      runSpacing: B05Layout.space4,
                      children: [
                        for (final value in values)
                          Text(value, style: B05Typography.caption(context)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProgressLogBodyMeasurementsSheet extends ConsumerStatefulWidget {
  const ProgressLogBodyMeasurementsSheet({super.key, required this.onSaved});

  final Future<void> Function() onSaved;

  @override
  ConsumerState<ProgressLogBodyMeasurementsSheet> createState() =>
      ProgressLogBodyMeasurementsSheetState();
}

class ProgressLogBodyMeasurementsSheetState
    extends ConsumerState<ProgressLogBodyMeasurementsSheet> {
  late final TextEditingController _waist;
  late final TextEditingController _chest;
  late final TextEditingController _arms;
  var _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _waist = TextEditingController();
    _chest = TextEditingController();
    _arms = TextEditingController();
  }

  @override
  void dispose() {
    _waist.dispose();
    _chest.dispose();
    _arms.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final waist = parseMeasurement(_waist.text);
    final chest = parseMeasurement(_chest.text);
    final arms = parseMeasurement(_arms.text);
    if (waist == null && chest == null && arms == null) {
      setState(
        () => _message = 'Enter at least one measurement in centimetres.',
      );
      return;
    }
    if ([waist, chest, arms].any((value) => value != null && value <= 0)) {
      setState(() => _message = 'Measurements must be greater than zero.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref
          .read(workoutRepositoryProvider)
          .logBodyMeasurement(waist: waist, chest: chest, arms: arms);
      await widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _message = 'Measurements could not be saved. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Log measurements',
                  style: B05Typography.title(context),
                ),
              ),
              B05IconAction(
                icon: Icons.close_rounded,
                label: 'Close',
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Record today’s values in centimetres.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space16),
          ProgressMeasurementField(label: 'Waist', controller: _waist),
          const SizedBox(height: B05Layout.space12),
          ProgressMeasurementField(label: 'Chest', controller: _chest),
          const SizedBox(height: B05Layout.space12),
          ProgressMeasurementField(label: 'Arms', controller: _arms),
          if (_message != null) ...[
            const SizedBox(height: B05Layout.space12),
            Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                style: B05Typography.caption(
                  context,
                ).copyWith(color: context.b05Colors.danger.indicator),
              ),
            ),
          ],
          const SizedBox(height: B05Layout.space20),
          SizedBox(
            width: double.infinity,
            child: B05ActionButton(
              label: _saving ? 'Saving…' : 'Save measurements',
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressMeasurementField extends StatelessWidget {
  const ProgressMeasurementField({super.key, required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, suffixText: 'cm'),
    );
  }
}

