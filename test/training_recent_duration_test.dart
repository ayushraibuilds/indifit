import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/features/training/training_screen.dart';

void main() {
  test('Recent shows short workouts as under a minute, not 0 min', () {
    expect(recentWorkoutDuration(58), 'under 1 min');
    expect(recentWorkoutDuration(1), 'under 1 min');
    expect(recentWorkoutDuration(60), '1 min');
    expect(recentWorkoutDuration(3599), '59 min');
  });
}
