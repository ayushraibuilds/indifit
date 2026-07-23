import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import 'providers.dart';

class UserProfileState {
  final int calorieGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;
  final double currentWeight;
  final String? userName;

  const UserProfileState({
    required this.calorieGoal,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
    required this.currentWeight,
    this.userName,
  });

  UserProfileState copyWith({
    int? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
    double? currentWeight,
    String? userName,
  }) {
    return UserProfileState(
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      currentWeight: currentWeight ?? this.currentWeight,
      userName: userName ?? this.userName,
    );
  }
}

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final AppDatabase? _db;

  UserProfileNotifier([this._db])
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
    int cals = prefs.getInt('calorie_goal') ?? 2000;
    double protein = prefs.getDouble('protein_goal') ?? 120.0;
    double carbs = prefs.getDouble('carbs_goal') ?? 230.0;
    double fat = prefs.getDouble('fat_goal') ?? 65.0;
    double weight = prefs.getDouble('current_weight') ?? 74.5;
    String? name = prefs.getString('user_name');

    if (_db != null) {
      try {
        final profiles = await _db!.select(_db!.userProfiles).get();
        if (profiles.isNotEmpty) {
          final p = profiles.first;
          cals = p.calorieGoal;
          protein = p.proteinGoal;
          carbs = p.carbsGoal;
          fat = p.fatGoal;
          weight = p.weight;
        } else {
          // Migrate SharedPreferences defaults to initial Drift row
          await _db!.into(_db!.userProfiles).insert(UserProfilesCompanion.insert(
            calorieGoal: Value(cals),
            proteinGoal: Value(protein),
            carbsGoal: Value(carbs),
            fatGoal: Value(fat),
            weight: Value(weight),
          ));
        }
      } catch (_) {}
    }

    state = UserProfileState(
      calorieGoal: cals,
      proteinGoal: protein,
      carbsGoal: carbs,
      fatGoal: fat,
      currentWeight: weight,
      userName: name,
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

    if (_db != null) {
      try {
        final profiles = await _db!.select(_db!.userProfiles).get();
        if (profiles.isNotEmpty) {
          await (_db!.update(_db!.userProfiles)..where((t) => t.id.equals(profiles.first.id))).write(
            UserProfilesCompanion(
              calorieGoal: calorieGoal != null ? Value(calorieGoal) : const Value.absent(),
              proteinGoal: proteinGoal != null ? Value(proteinGoal) : const Value.absent(),
              carbsGoal: carbsGoal != null ? Value(carbsGoal) : const Value.absent(),
              fatGoal: fatGoal != null ? Value(fatGoal) : const Value.absent(),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      } catch (_) {}
    }

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

    if (_db != null) {
      try {
        final profiles = await _db!.select(_db!.userProfiles).get();
        if (profiles.isNotEmpty) {
          await (_db!.update(_db!.userProfiles)..where((t) => t.id.equals(profiles.first.id))).write(
            UserProfilesCompanion(
              weight: Value(weight),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      } catch (_) {}
    }

    state = state.copyWith(currentWeight: weight);
  }

  Future<void> updateName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    state = state.copyWith(userName: name);
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  final db = ref.watch(databaseProvider);
  return UserProfileNotifier(db);
});
