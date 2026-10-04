import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/features/workout_player/widgets/r07c_workout_presentation.dart';

void main() {
  String? target({double? load, int? min, int? max, int? rpe}) =>
      r07cFormatTarget(
        loadKg: load,
        loadBasis: load == null ? null : B02LoadBasis.totalExternal,
        minReps: min,
        maxReps: max,
        rpe: rpe,
      );

  test('the open 1-20 placeholder is not shown as a plan', () {
    expect(target(load: 60, min: 1, max: 20), '60 kg');
    expect(target(min: 1, max: 20), isNull);
    expect(target(load: 60, min: 1, max: 20, rpe: 8), '60 kg × RPE 8');
  });

  test('real targets still read in full', () {
    expect(target(load: 60, min: 8, max: 12), '60 kg × 8–12 reps');
    expect(target(min: 5, max: 5), '5 reps');
    expect(target(load: 60), '60 kg');
  });

  test('placeholder detection', () {
    expect(r07cIsPlaceholderRepRange(1, 20), isTrue);
    expect(r07cIsPlaceholderRepRange(1, null), isTrue);
    expect(r07cIsPlaceholderRepRange(1, 5), isFalse);
    expect(r07cIsPlaceholderRepRange(8, 20), isFalse);
  });
}
