import 'package:flutter/material.dart';

import '../../../data/models/b02_execution_models.dart';
import '../../../data/models/b02_rich_set_helpers.dart';
import '../../program_authoring/b02_technique_editor.dart';
import 'b02_execution_semantics.dart';

/// Progressive disclosure for the uncommon, typed B02 set controls.
///
/// The compact table owns the ordinary load/reps path. This panel is only
/// mounted inside its existing “More for this set” disclosure, so a normal
/// set does not gain a heavy editor. All emitted values remain typed B02
/// techniques and are validated again by the draft service before mutation.
class B02ExecutionAdvancedControls extends StatefulWidget {
  const B02ExecutionAdvancedControls({
    required this.initialValue,
    required this.headerReps,
    required this.onChanged,
    super.key,
    this.prescribedValue,
  });

  final B02TechniqueFields initialValue;
  final int? headerReps;
  final B02TechniqueFields? prescribedValue;
  final ValueChanged<B02TechniqueFields> onChanged;

  @override
  State<B02ExecutionAdvancedControls> createState() =>
      _B02ExecutionAdvancedControlsState();
}

class _B02ExecutionAdvancedControlsState
    extends State<B02ExecutionAdvancedControls> {
  late B02TechniqueFields _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant B02ExecutionAdvancedControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameTechnique(oldWidget.initialValue, widget.initialValue)) {
      _value = widget.initialValue;
    }
  }

  void _onChanged(B02TechniqueFields value) {
    if (_sameTechnique(_value, value)) return;
    setState(() => _value = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final prescribed = widget.prescribedValue;
    final prescribedSummary = prescribed == null
        ? null
        : b02TechniqueSummary(prescribed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label:
              'RPE explanation: RPE describes how hard the set felt: 1 is very easy and 10 is maximum effort.',
          child: ExcludeSemantics(
            child: Text(
              'RPE describes how hard the set felt: 1 is very easy and 10 is maximum effort.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        if (prescribedSummary != null) ...[
          const SizedBox(height: 8),
          Semantics(
            container: true,
            label: 'Planned set details: $prescribedSummary',
            child: ExcludeSemantics(
              child: Text(
                'Planned set details: $prescribedSummary',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        B02TechniqueEditor(
          initialValue: _value,
          headerReps: widget.headerReps,
          onChanged: _onChanged,
        ),
      ],
    );
  }

  bool _sameTechnique(B02TechniqueFields left, B02TechniqueFields right) {
    return B02TechniqueDraftCodec.encode(left) ==
        B02TechniqueDraftCodec.encode(right);
  }
}
