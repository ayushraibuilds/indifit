/// Compatibility policy for the retained B01 workout player.
///
/// B02 routes must use typed activity/technique metadata. This adapter is the
/// deliberately narrow boundary for the old v0/v1 player, where an exercise
/// only has a display-name snapshot and the old set model has no modality or
/// rest fields. Keeping the rule here preserves B01 behaviour without letting
/// name-based decisions leak into B02 widgets or repositories.
class LegacyExerciseExecutionMetadata {
  final bool isCardio;
  final int recommendedRestSeconds;
  final String formCue;

  const LegacyExerciseExecutionMetadata({
    required this.isCardio,
    required this.recommendedRestSeconds,
    required this.formCue,
  });
}

class LegacyWorkoutCompatibilityAdapter {
  static const String ruleVersion = 'b01-legacy-player-v1';

  const LegacyWorkoutCompatibilityAdapter();

  LegacyExerciseExecutionMetadata metadataFor(String exerciseName) {
    final normalized = exerciseName.trim().toLowerCase();
    final isCardio = _cardioTokens.any(normalized.contains);
    final rest = _heavyTokens.any(normalized.contains)
        ? 120
        : _isolationTokens.any(normalized.contains)
        ? 60
        : 90;
    return LegacyExerciseExecutionMetadata(
      isCardio: isCardio,
      recommendedRestSeconds: rest,
      formCue: _formCueFor(normalized),
    );
  }

  static String _formCueFor(String normalizedName) {
    if (normalizedName.contains('bench press') ||
        normalizedName.contains('chest press')) {
      return 'Form: Scapula retracted (shoulders back and down), chest up, flat feet on floor. Lower under control to touch your mid-chest and press up.';
    }
    if (normalizedName.contains('shoulder press') ||
        normalizedName.contains('overhead press')) {
      return 'Form: Keep core tight, avoid excessive arch in lower back. Drive weight straight up, keeping elbows slightly tucked.';
    }
    if (normalizedName.contains('squat')) {
      return 'Form: Hips back first, push knees outward, keep chest high, brace core. Squat to parallel or lower.';
    }
    if (normalizedName.contains('deadlift')) {
      return 'Form: Hinge at hips, keep flat back, pull bar close to shins. Drive feet into the ground to lock out.';
    }
    if (normalizedName.contains('lat pulldown') ||
        normalizedName.contains('pull')) {
      return 'Form: Pull shoulders down and back, pull down to upper chest using elbows, lean back slightly.';
    }
    if (_isolationTokens.any(normalizedName.contains)) {
      return 'Form: Pin elbows, avoid swinging, squeeze targeted arm muscles.';
    }
    return 'Form: Perform with strict form. Keep core braced, breathe out on exertion, and control the negative phase.';
  }

  static const List<String> _cardioTokens = [
    'run',
    'treadmill',
    'cardio',
    'cycle',
    'cycling',
    'elliptical',
    'walk',
    'swim',
  ];

  static const List<String> _heavyTokens = ['squat', 'deadlift', 'bench press'];

  static const List<String> _isolationTokens = [
    'curl',
    'tricep',
    'lateral',
    'raise',
  ];
}
