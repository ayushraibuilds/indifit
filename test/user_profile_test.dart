import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:indifit/core/di/user_profile_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'calorie_goal': 2200,
      'protein_goal': 140.0,
      'carbs_goal': 250.0,
      'fat_goal': 70.0,
      'current_weight': 75.0,
    });
  });

  group('UserProfileNotifier Tests', () {
    test('loads initial profile goals from SharedPreferences', () async {
      final notifier = UserProfileNotifier();
      await notifier.loadProfile();

      expect(notifier.state.calorieGoal, 2200);
      expect(notifier.state.proteinGoal, 140.0);
      expect(notifier.state.carbsGoal, 250.0);
      expect(notifier.state.fatGoal, 70.0);
      expect(notifier.state.currentWeight, 75.0);
    });

    test('updates goals and persists changes to SharedPreferences', () async {
      final notifier = UserProfileNotifier();
      await notifier.updateGoals(
        calorieGoal: 2400,
        proteinGoal: 150.0,
      );

      expect(notifier.state.calorieGoal, 2400);
      expect(notifier.state.proteinGoal, 150.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('calorie_goal'), 2400);
      expect(prefs.getDouble('protein_goal'), 150.0);
    });

    test('updates current weight', () async {
      final notifier = UserProfileNotifier();
      await notifier.updateWeight(76.2);

      expect(notifier.state.currentWeight, 76.2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('current_weight'), 76.2);
    });
  });
}
