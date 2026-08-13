/// Display-ready setup guidance for the workout player.
///
/// The execution snapshot may contain maps and persisted keys. They are
/// resolved once at this boundary so widgets only render short, safe labels.
class PlayerSetupPresentation {
  const PlayerSetupPresentation({
    required this.note,
    required this.setupValues,
    required this.cues,
  });

  final String? note;
  final List<PlayerSetupValue> setupValues;
  final List<String> cues;

  bool get hasContent =>
      (note?.isNotEmpty ?? false) || setupValues.isNotEmpty || cues.isNotEmpty;

  factory PlayerSetupPresentation.fromContext(Map<String, dynamic>? context) {
    final data = context ?? const <String, dynamic>{};
    final note = _safeText(data['generalNote']);
    final setupValues = <PlayerSetupValue>[];
    final rawValues = data['setupValues'];
    if (rawValues is Iterable) {
      for (final raw in rawValues) {
        if (raw is! Map) continue;
        final label = _safeText(raw['label']);
        final value = _safeText(raw['value']);
        if (label != null && value != null) {
          setupValues.add(PlayerSetupValue(label: label, value: value));
        }
      }
    }
    final cues = <String>[];
    final rawCues = data['personalCues'];
    if (rawCues is Iterable) {
      for (final raw in rawCues) {
        final cue = raw is Map ? raw['cueText'] : raw;
        final value = _safeText(cue);
        if (value != null) cues.add(value);
      }
    }
    return PlayerSetupPresentation(
      note: note,
      setupValues: List.unmodifiable(setupValues),
      cues: List.unmodifiable(cues),
    );
  }

  static String? _safeText(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    if (text.isEmpty || text.length > 160) return null;
    return text;
  }
}

class PlayerSetupValue {
  const PlayerSetupValue({required this.label, required this.value});

  final String label;
  final String value;
}
