import 'package:flutter/material.dart';

import '../../data/models/b02_execution_models.dart';
import '../../data/models/b02_rich_set_helpers.dart';
import '../workout_player/widgets/b02_execution_semantics.dart';

/// Reusable editor primitive for composable strength-set techniques.
///
/// This widget owns only temporary form controls. The parent remains the owner
/// of the typed [B02TechniqueFields] value through [onChanged]. Invalid edits
/// stay visible in the form and are never emitted as a domain value.
class B02TechniqueEditor extends StatefulWidget {
  final B02TechniqueFields? initialValue;
  final int? headerReps;
  final ValueChanged<B02TechniqueFields> onChanged;

  const B02TechniqueEditor({
    super.key,
    this.initialValue,
    this.headerReps,
    required this.onChanged,
  });

  @override
  State<B02TechniqueEditor> createState() => _B02TechniqueEditorState();
}

class _B02TechniqueEditorState extends State<B02TechniqueEditor> {
  late B02TechniqueFields _value;
  String? _error;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue ?? B02TechniqueFields();
    _validateAndEmit();
  }

  @override
  void didUpdateWidget(covariant B02TechniqueEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue ||
        oldWidget.headerReps != widget.headerReps) {
      _value = widget.initialValue ?? B02TechniqueFields();
      _validateAndEmit();
    }
  }

  void _update(B02TechniqueFields next) {
    setState(() => _value = next);
    _validateAndEmit();
  }

  void _tryUpdate(B02TechniqueFields Function() build) {
    try {
      _update(build());
    } on B02ValidationException catch (error) {
      setState(() => _error = error.message);
    }
  }

  void _validateAndEmit() {
    try {
      B02RichSetValidator.validateTechnique(
        _value,
        headerReps: widget.headerReps,
      );
      if (_error != null) {
        if (mounted) {
          setState(() => _error = null);
        } else {
          _error = null;
        }
      }
      widget.onChanged(_value);
    } on B02ValidationException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      } else {
        _error = error.message;
      }
    }
  }

  B02TechniqueFields _withSegments(List<B02SetSegment> segments) {
    return _value.copyWith(segments: segments);
  }

  void _toggleDrop(bool enabled) {
    final segments = enabled || _value.isRestPause
        ? (_value.segments.isEmpty ? _defaultSegments() : _value.segments)
        : const <B02SetSegment>[];
    _update(_value.copyWith(isDropSet: enabled, segments: segments));
  }

  void _toggleRestPause(bool enabled) {
    final segments = enabled || _value.isDropSet
        ? (_value.segments.isEmpty ? _defaultSegments() : _value.segments)
        : const <B02SetSegment>[];
    _update(_value.copyWith(isRestPause: enabled, segments: segments));
  }

  List<B02SetSegment> _defaultSegments() => [
    B02SetSegment(ordinal: 0, reps: 1, externalLoadKg: 1),
    B02SetSegment(ordinal: 1, reps: 1, externalLoadKg: 0, restBeforeSeconds: 1),
  ];

  void _updateSegment(int index, B02SetSegment segment) {
    final segments = [..._value.segments];
    segments[index] = segment;
    _update(_withSegments(segments));
  }

  void _addSegment() {
    final ordinal = _value.segments.length;
    final previousLoad = _value.segments.isEmpty
        ? 1.0
        : _value.segments.last.externalLoadKg;
    _update(
      _withSegments([
        ..._value.segments,
        B02SetSegment(
          ordinal: ordinal,
          reps: 1,
          externalLoadKg: _value.isDropSet && previousLoad != null
              ? (previousLoad - 1).clamp(0, double.infinity).toDouble()
              : previousLoad,
          restBeforeSeconds: _value.isRestPause ? 1 : null,
        ),
      ]),
    );
  }

  void _removeSegment(int index) {
    if (_value.segments.length <= 2) return;
    final segments = [
      for (var i = 0; i < _value.segments.length; i++)
        if (i != index) _value.segments[i].copyWith(ordinal: i),
    ];
    _update(_withSegments(segments));
  }

  int? _parseInt(String raw) => int.tryParse(raw.trim());
  double? _parseDouble(String raw) => double.tryParse(raw.trim());

  Widget _effortEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Set effort intent',
          child: DropdownButtonFormField<B02EffortMode>(
            isExpanded: true,
            initialValue: _value.effortMode,
            decoration: const InputDecoration(labelText: 'Effort intent'),
            items: [
              for (final mode in B02EffortMode.values)
                DropdownMenuItem(
                  value: mode,
                  child: Text(b02ExecutionEffortLabel(mode)),
                ),
            ],
            onChanged: (mode) {
              if (mode != null) _update(_value.copyWith(effortMode: mode));
            },
          ),
        ),
        Semantics(
          container: true,
          label: 'Reached failure',
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                Checkbox(
                  value: _value.endedAtFailure,
                  onChanged: (value) =>
                      _update(_value.copyWith(endedAtFailure: value ?? false)),
                ),
                const Expanded(child: Text('Reached failure')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _numberField({
    required String label,
    required String semanticLabel,
    required String initialValue,
    required ValueChanged<String> onChanged,
    bool decimal = false,
  }) {
    return SizedBox(
      width: 150,
      child: Semantics(
        label: semanticLabel,
        textField: true,
        child: TextFormField(
          key: ValueKey(semanticLabel),
          initialValue: initialValue,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: InputDecoration(labelText: label),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _tempoEditor() {
    final enabled = _value.hasTempo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tempo'),
          subtitle: const Text(
            'Eccentric · bottom pause · concentric · lockout pause',
          ),
          value: enabled,
          onChanged: (checked) {
            _update(
              checked
                  ? _value.copyWith(
                      tempoEccentricSeconds: 3,
                      tempoBottomPauseSeconds: 1,
                      tempoConcentricSeconds: 1,
                      tempoLockoutPauseSeconds: 0,
                    )
                  : _value.copyWith(
                      tempoEccentricSeconds: null,
                      tempoBottomPauseSeconds: null,
                      tempoConcentricSeconds: null,
                      tempoLockoutPauseSeconds: null,
                    ),
            );
          },
        ),
        if (enabled)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _numberField(
                label: 'Eccentric (s)',
                semanticLabel: 'Tempo eccentric seconds',
                initialValue: '${_value.tempoEccentricSeconds}',
                onChanged: (raw) => _tryUpdate(
                  () => _value.copyWith(tempoEccentricSeconds: _parseInt(raw)),
                ),
              ),
              _numberField(
                label: 'Bottom pause (s)',
                semanticLabel: 'Tempo bottom pause seconds',
                initialValue: '${_value.tempoBottomPauseSeconds}',
                onChanged: (raw) => _tryUpdate(
                  () =>
                      _value.copyWith(tempoBottomPauseSeconds: _parseInt(raw)),
                ),
              ),
              _numberField(
                label: 'Concentric (s)',
                semanticLabel: 'Tempo concentric seconds',
                initialValue: '${_value.tempoConcentricSeconds}',
                onChanged: (raw) => _tryUpdate(
                  () => _value.copyWith(tempoConcentricSeconds: _parseInt(raw)),
                ),
              ),
              _numberField(
                label: 'Lockout pause (s)',
                semanticLabel: 'Tempo lockout pause seconds',
                initialValue: '${_value.tempoLockoutPauseSeconds}',
                onChanged: (raw) => _tryUpdate(
                  () =>
                      _value.copyWith(tempoLockoutPauseSeconds: _parseInt(raw)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _pausedRepEditor() {
    final enabled = _value.pausedRepPosition != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Paused reps'),
          subtitle: const Text('Pause at a position for each repetition'),
          value: enabled,
          onChanged: (checked) => _update(
            checked
                ? _value.copyWith(
                    pausedRepPosition: B02PausedRepPosition.bottom,
                    pausedRepSeconds: 1,
                  )
                : _value.copyWith(
                    pausedRepPosition: null,
                    pausedRepSeconds: null,
                  ),
          ),
        ),
        if (enabled)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Semantics(
                label: 'Paused rep position',
                child: SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<B02PausedRepPosition>(
                    isExpanded: true,
                    initialValue: _value.pausedRepPosition,
                    decoration: const InputDecoration(
                      labelText: 'Pause position',
                    ),
                    items: [
                      for (final position in B02PausedRepPosition.values)
                        DropdownMenuItem(
                          value: position,
                          child: Text(
                            b02ExecutionPausedRepPositionLabel(position),
                          ),
                        ),
                    ],
                    onChanged: (position) {
                      if (position != null) {
                        _update(_value.copyWith(pausedRepPosition: position));
                      }
                    },
                  ),
                ),
              ),
              _numberField(
                label: 'Duration (s)',
                semanticLabel: 'Paused rep duration seconds',
                initialValue: '${_value.pausedRepSeconds}',
                onChanged: (raw) => _tryUpdate(
                  () => _value.copyWith(pausedRepSeconds: _parseInt(raw)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _assistanceEditor() {
    final enabled = _value.assistanceMode != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Assisted reps'),
          subtitle: const Text('Keep support separate from external load'),
          value: enabled,
          onChanged: (checked) => _update(
            checked
                ? _value.copyWith(
                    assistanceMode: B02AssistanceMode.machine,
                    assistanceKg: 1,
                  )
                : _value.copyWith(assistanceMode: null, assistanceKg: null),
          ),
        ),
        if (enabled)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Semantics(
                label: 'Assistance mode',
                child: SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<B02AssistanceMode>(
                    isExpanded: true,
                    initialValue: _value.assistanceMode,
                    decoration: const InputDecoration(
                      labelText: 'Assistance type',
                    ),
                    items: [
                      for (final mode in B02AssistanceMode.values)
                        DropdownMenuItem(
                          value: mode,
                          child: Text(b02ExecutionAssistanceLabel(mode)),
                        ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        _update(_value.copyWith(assistanceMode: mode));
                      }
                    },
                  ),
                ),
              ),
              _numberField(
                label: 'Support (kg)',
                semanticLabel: 'Assistance support kilograms',
                initialValue: '${_value.assistanceKg}',
                onChanged: (raw) => _tryUpdate(
                  () => _value.copyWith(assistanceKg: _parseDouble(raw)),
                ),
                decimal: true,
              ),
            ],
          ),
      ],
    );
  }

  Widget _segmentEditor(B02SetSegment segment, int index) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Segment ${index + 1}'),
            _numberField(
              label: 'Reps',
              semanticLabel: 'Segment ${index + 1} reps',
              initialValue: '${segment.reps}',
              onChanged: (raw) {
                final reps = _parseInt(raw);
                if (reps != null) {
                  try {
                    _updateSegment(index, segment.copyWith(reps: reps));
                  } on B02ValidationException catch (error) {
                    setState(() => _error = error.message);
                  }
                }
              },
            ),
            _numberField(
              label: 'Load (kg)',
              semanticLabel: 'Segment ${index + 1} external load kilograms',
              initialValue: segment.externalLoadKg?.toString() ?? '',
              onChanged: (raw) {
                try {
                  _updateSegment(
                    index,
                    segment.copyWith(
                      externalLoadKg: raw.trim().isEmpty
                          ? null
                          : _parseDouble(raw),
                    ),
                  );
                } on B02ValidationException catch (error) {
                  setState(() => _error = error.message);
                }
              },
              decimal: true,
            ),
            Semantics(
              label: 'Segment ${index + 1} load basis',
              child: SizedBox(
                width: 180,
                child: DropdownButton<B02LoadBasis?>(
                  isExpanded: true,
                  hint: const Text('Load basis'),
                  value: segment.loadBasis,
                  items: [
                    const DropdownMenuItem<B02LoadBasis?>(
                      value: null,
                      child: Text('Load basis not set'),
                    ),
                    for (final basis in B02LoadBasis.values)
                      DropdownMenuItem<B02LoadBasis?>(
                        value: basis,
                        child: Text(b02ExecutionLoadBasisLabel(basis)),
                      ),
                  ],
                  onChanged: (basis) {
                    try {
                      _updateSegment(index, segment.copyWith(loadBasis: basis));
                    } on B02ValidationException catch (error) {
                      setState(() => _error = error.message);
                    }
                  },
                ),
              ),
            ),
            _numberField(
              label: 'Assistance (kg)',
              semanticLabel: 'Segment ${index + 1} assistance kilograms',
              initialValue: segment.assistanceKg?.toString() ?? '',
              onChanged: (raw) {
                try {
                  _updateSegment(
                    index,
                    segment.copyWith(
                      assistanceKg: raw.trim().isEmpty
                          ? null
                          : _parseDouble(raw),
                    ),
                  );
                } on B02ValidationException catch (error) {
                  setState(() => _error = error.message);
                }
              },
              decimal: true,
            ),
            if (_value.isRestPause)
              _numberField(
                label: 'Rest before (s)',
                semanticLabel: 'Segment ${index + 1} rest before seconds',
                initialValue: segment.restBeforeSeconds?.toString() ?? '',
                onChanged: (raw) {
                  try {
                    _updateSegment(
                      index,
                      segment.copyWith(
                        restBeforeSeconds: raw.trim().isEmpty
                            ? null
                            : _parseInt(raw),
                      ),
                    );
                  } on B02ValidationException catch (error) {
                    setState(() => _error = error.message);
                  }
                },
              ),
            if (_value.segments.length > 2)
              IconButton(
                tooltip: 'Remove segment ${index + 1}',
                onPressed: () => _removeSegment(index),
                icon: const Icon(Icons.remove_circle_outline),
              ),
          ],
        ),
      ),
    );
  }

  Widget _segmentsEditor() {
    final enabled = _value.isDropSet || _value.isRestPause;
    if (!enabled) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Ordered segments', style: Theme.of(context).textTheme.titleSmall),
        for (var index = 0; index < _value.segments.length; index++)
          _segmentEditor(_value.segments[index], index),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addSegment,
            icon: const Icon(Icons.add),
            label: const Text('Add segment'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTechnique =
        _value.effortMode != B02EffortMode.standard ||
        _value.endedAtFailure ||
        _value.hasTempo ||
        _value.pausedRepPosition != null ||
        _value.assistanceMode != null ||
        _value.isDropSet ||
        _value.isRestPause;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: hasTechnique || _error != null,
        title: const Text('Advanced technique'),
        subtitle: const Text('Tempo, pauses, assistance, drops and rest-pause'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _effortEditor(),
                  _tempoEditor(),
                  _pausedRepEditor(),
                  _assistanceEditor(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Drop set'),
                    subtitle: const Text(
                      'Record decreasing external loads by segment',
                    ),
                    value: _value.isDropSet,
                    onChanged: _toggleDrop,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rest-pause'),
                    subtitle: const Text(
                      'Record positive rest before later clusters',
                    ),
                    value: _value.isRestPause,
                    onChanged: _toggleRestPause,
                  ),
                  _segmentsEditor(),
                  if (_error != null)
                    Semantics(
                      container: true,
                      liveRegion: true,
                      label: 'Technique validation error: $_error',
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ExcludeSemantics(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
