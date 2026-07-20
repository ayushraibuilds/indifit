import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileState {
  final int calorieGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;
  final double currentWeight;

  const UserProfileState({
    required this.calorieGoal,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
    required this.currentWeight,
  });

  UserProfileState copyWith({
    int? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
    double? currentWeight,
  }) {
    return UserProfileState(
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      currentWeight: currentWeight ?? this.currentWeight,
    );
  }
}

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier()
      : super(const UserProfileState(
          calorieGoal: 2000,
          proteinGoal: 120.0,
          carbsGoal: 230.0,
          fatGoal: 65.0,
          currentWeight: 74.5,
        )) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    state = UserProfileState(
      calorieGoal: prefs.getInt('calorie_goal') ?? 2000,
      proteinGoal: prefs.getDouble('protein_goal') ?? 120.0,
      carbsGoal: prefs.getDouble('carbs_goal') ?? 230.0,
      fatGoal: prefs.getDouble('fat_goal') ?? 65.0,
      currentWeight: prefs.getDouble('current_weight') ?? 74.5,
    );
  }

  Future<void> updateGoals({
    int? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (calorieGoal != null) await prefs.setInt('calorie_goal', calorieGoal);
    if (proteinGoal != null) await prefs.setDouble('protein_goal', proteinGoal);
    if (carbsGoal != null) await prefs.setDouble('carbs_goal', carbsGoal);
    if (fatGoal != null) await prefs.setDouble('fat_goal', fatGoal);

    state = state.copyWith(
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      carbsGoal: carbsGoal,
      fatGoal: fatGoal,
    );
  }

  Future<void> updateWeight(double weight) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('current_weight', weight);
    state = state.copyWith(currentWeight: weight);
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  return UserProfileNotifier();
});
