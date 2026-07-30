import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../services/crash_reporting_service.dart';
import '../utils/app_logger.dart';
import 'providers.dart';

class UserProfileState {
  final int calorieGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;
  final double currentWeight;
  final double? userHeight;
  final String? userName;
  final String userSex;
  final int userAge;
  final String userActivityLevel;
  final String userGoal;
  final String dietPreference;
  final String equipmentAccess;
  final String injuriesLimitations;

  const UserProfileState({
    required this.calorieGoal,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
    required this.currentWeight,
    this.userHeight,
    this.userName,
    this.userSex = 'male',
    this.userAge = 25,
    this.userActivityLevel = 'moderate',
    this.userGoal = 'maintain',
    this.dietPreference = 'veg',
    this.equipmentAccess = 'full_gym',
    this.injuriesLimitations = '',
  });

  UserProfileState copyWith({
    int? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
    double? currentWeight,
    double? userHeight,
    String? userName,
    String? userSex,
    int? userAge,
    String? userActivityLevel,
    String? userGoal,
    String? dietPreference,
    String? equipmentAccess,
    String? injuriesLimitations,
  }) {
    return UserProfileState(
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      currentWeight: currentWeight ?? this.currentWeight,
      userHeight: userHeight ?? this.userHeight,
      userName: userName ?? this.userName,
      userSex: userSex ?? this.userSex,
      userAge: userAge ?? this.userAge,
      userActivityLevel: userActivityLevel ?? this.userActivityLevel,
      userGoal: userGoal ?? this.userGoal,
      dietPreference: dietPreference ?? this.dietPreference,
      equipmentAccess: equipmentAccess ?? this.equipmentAccess,
      injuriesLimitations: injuriesLimitations ?? this.injuriesLimitations,
    );
  }
}

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final AppDatabase? _db;

  UserProfileNotifier([this._db])
    : super(
        const UserProfileState(
          calorieGoal: 2000,
          proteinGoal: 120.0,
          carbsGoal: 230.0,
          fatGoal: 65.0,
          currentWeight: 74.5,
        ),
      ) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    int cals = prefs.getInt('calorie_goal') ?? 2000;
    double protein = prefs.getDouble('protein_goal') ?? 120.0;
    double carbs = prefs.getDouble('carbs_goal') ?? 230.0;
    double fat = prefs.getDouble('fat_goal') ?? 65.0;
    double weight = prefs.getDouble('current_weight') ?? 74.5;
    double? height = prefs.getDouble('user_height');
    String? name = prefs.getString('user_name');
    String sex = prefs.getString('user_sex') ?? 'male';
    int age = prefs.getInt('user_age') ?? 25;
    String activity = prefs.getString('user_activity_level') ?? 'moderate';
    String goal = prefs.getString('user_goal') ?? 'maintain';
    String diet = prefs.getString('user_diet_preference') ?? 'veg';
    String equipment = prefs.getString('user_equipment') ?? 'full_gym';
    String injuries = prefs.getString('user_injuries') ?? '';

    final db = _db;
    if (db != null) {
      try {
        final profiles = await db.select(db.userProfiles).get();
        if (profiles.isNotEmpty) {
          final p = profiles.first;
          cals = p.calorieGoal;
          protein = p.proteinGoal;
          carbs = p.carbsGoal;
          fat = p.fatGoal;
          weight = p.weight;
          height ??= p.height;
          name = p.name.isNotEmpty ? p.name : name;
          sex = p.sex;
          age = p.age;
          activity = p.activityLevel;
          goal = p.goal;
          diet = p.dietPreference.isNotEmpty ? p.dietPreference : diet;
          equipment = p.equipmentAccess;
          injuries = p.injuriesLimitations;
        } else {
          // Migrate SharedPreferences defaults to initial Drift row
          await db
              .into(db.userProfiles)
              .insert(
                UserProfilesCompanion.insert(
                  calorieGoal: Value(cals),
                  proteinGoal: Value(protein),
                  carbsGoal: Value(carbs),
                  fatGoal: Value(fat),
                  weight: Value(weight),
                  height: height != null ? Value(height) : const Value.absent(),
                  name: Value(name ?? ''),
                  sex: Value(sex),
                  age: Value(age),
                  activityLevel: Value(activity),
                  goal: Value(goal),
                  dietPreference: Value(diet),
                  equipmentAccess: Value(equipment),
                  injuriesLimitations: Value(injuries),
                ),
              );
        }
      } catch (e, st) {
        AppLogger.warning('loadProfile database access failed: $e');
        CrashReportingService.recordCrash(
          e,
          st,
          reason: 'loadProfile db error',
        );
      }
    }

    if (!mounted) return;
    state = UserProfileState(
      calorieGoal: cals,
      proteinGoal: protein,
      carbsGoal: carbs,
      fatGoal: fat,
      currentWeight: weight,
      userHeight: height,
      userName: name,
      userSex: sex,
      userAge: age,
      userActivityLevel: activity,
      userGoal: goal,
      dietPreference: diet,
      equipmentAccess: equipment,
      injuriesLimitations: injuries,
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

    final db = _db;
    if (db != null) {
      try {
        final profiles = await db.select(db.userProfiles).get();
        if (profiles.isNotEmpty) {
          await (db.update(
            db.userProfiles,
          )..where((t) => t.id.equals(profiles.first.id))).write(
            UserProfilesCompanion(
              calorieGoal: calorieGoal != null
                  ? Value(calorieGoal)
                  : const Value.absent(),
              proteinGoal: proteinGoal != null
                  ? Value(proteinGoal)
                  : const Value.absent(),
              carbsGoal: carbsGoal != null
                  ? Value(carbsGoal)
                  : const Value.absent(),
              fatGoal: fatGoal != null ? Value(fatGoal) : const Value.absent(),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      } catch (e, st) {
        AppLogger.warning('updateGoals database write failed: $e');
        CrashReportingService.recordCrash(
          e,
          st,
          reason: 'updateGoals db error',
        );
      }
    }

    state = state.copyWith(
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      carbsGoal: carbsGoal,
      fatGoal: fatGoal,
    );
  }

  Future<void> updateWeight(double weight) async {
    final db = _db;
    if (db != null) {
      final profiles = await db.select(db.userProfiles).get();
      if (profiles.isNotEmpty) {
        await (db.update(
          db.userProfiles,
        )..where((t) => t.id.equals(profiles.first.id))).write(
          UserProfilesCompanion(
            weight: Value(weight),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('current_weight', weight);
    await prefs.setDouble('user_weight', weight);

    state = state.copyWith(currentWeight: weight);
  }

  /// Updates profile state after the dashboard persists a weight change.
  void syncWeightFromPersistence(double weight) {
    if (!mounted) return;
    state = state.copyWith(currentWeight: weight);
  }

  Future<void> updateHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('user_height', height);

    final db = _db;
    if (db != null) {
      try {
        final profiles = await db.select(db.userProfiles).get();
        if (profiles.isNotEmpty) {
          await (db.update(
            db.userProfiles,
          )..where((t) => t.id.equals(profiles.first.id))).write(
            UserProfilesCompanion(
              height: Value(height),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      } catch (e, st) {
        AppLogger.warning('updateHeight database write failed: $e');
        CrashReportingService.recordCrash(
          e,
          st,
          reason: 'updateHeight db error',
        );
      }
    }

    state = state.copyWith(userHeight: height);
  }

  Future<void> updateName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    state = state.copyWith(userName: name);
  }

  Future<void> updateProfile({
    String? name,
    int? age,
    double? height,
    double? weight,
    String? sex,
    String? activityLevel,
    String? goal,
    String? dietPreference,
    int? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
    String? equipmentAccess,
    String? injuriesLimitations,
  }) async {
    final db = _db;
    if (db != null) {
      try {
        final profiles = await db.select(db.userProfiles).get();
        if (profiles.isNotEmpty) {
          await (db.update(
            db.userProfiles,
          )..where((t) => t.id.equals(profiles.first.id))).write(
            UserProfilesCompanion(
              name: name != null ? Value(name) : const Value.absent(),
              age: age != null ? Value(age) : const Value.absent(),
              height: height != null ? Value(height) : const Value.absent(),
              weight: weight != null ? Value(weight) : const Value.absent(),
              sex: sex != null ? Value(sex) : const Value.absent(),
              activityLevel: activityLevel != null
                  ? Value(activityLevel)
                  : const Value.absent(),
              goal: goal != null ? Value(goal) : const Value.absent(),
              dietPreference: dietPreference != null
                  ? Value(dietPreference)
                  : const Value.absent(),
              calorieGoal: calorieGoal != null
                  ? Value(calorieGoal)
                  : const Value.absent(),
              proteinGoal: proteinGoal != null
                  ? Value(proteinGoal)
                  : const Value.absent(),
              carbsGoal: carbsGoal != null
                  ? Value(carbsGoal)
                  : const Value.absent(),
              fatGoal: fatGoal != null ? Value(fatGoal) : const Value.absent(),
              equipmentAccess: equipmentAccess != null
                  ? Value(equipmentAccess)
                  : const Value.absent(),
              injuriesLimitations: injuriesLimitations != null
                  ? Value(injuriesLimitations)
                  : const Value.absent(),
              updatedAt: Value(DateTime.now()),
            ),
          );
        } else {
          await db
              .into(db.userProfiles)
              .insert(
                UserProfilesCompanion.insert(
                  name: Value(name ?? ''),
                  age: Value(age ?? 25),
                  height: Value(height ?? 170.0),
                  weight: Value(weight ?? 70.0),
                  sex: Value(sex ?? 'male'),
                  activityLevel: Value(activityLevel ?? 'moderate'),
                  goal: Value(goal ?? 'maintain'),
                  dietPreference: Value(dietPreference ?? 'balanced'),
                  calorieGoal: Value(calorieGoal ?? 2000),
                  proteinGoal: Value(proteinGoal ?? 140.0),
                  carbsGoal: Value(carbsGoal ?? 220.0),
                  fatGoal: Value(fatGoal ?? 60.0),
                  equipmentAccess: Value(equipmentAccess ?? 'full_gym'),
                  injuriesLimitations: Value(injuriesLimitations ?? ''),
                ),
              );
        }
      } catch (e, st) {
        AppLogger.warning('updateProfile database write failed: $e');
        CrashReportingService.recordCrash(
          e,
          st,
          reason: 'updateProfile db error',
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString('user_name', name);
    if (age != null) await prefs.setInt('user_age', age);
    if (height != null) await prefs.setDouble('user_height', height);
    if (weight != null) {
      await prefs.setDouble('user_weight', weight);
      await prefs.setDouble('current_weight', weight);
    }
    if (sex != null) await prefs.setString('user_sex', sex);
    if (activityLevel != null) {
      await prefs.setString('user_activity_level', activityLevel);
    }
    if (goal != null) await prefs.setString('user_goal', goal);
    if (dietPreference != null) {
      await prefs.setString('user_diet_preference', dietPreference);
    }
    if (calorieGoal != null) await prefs.setInt('calorie_goal', calorieGoal);
    if (proteinGoal != null) await prefs.setDouble('protein_goal', proteinGoal);
    if (carbsGoal != null) await prefs.setDouble('carbs_goal', carbsGoal);
    if (fatGoal != null) await prefs.setDouble('fat_goal', fatGoal);
    if (equipmentAccess != null) {
      await prefs.setString('user_equipment', equipmentAccess);
    }
    if (injuriesLimitations != null) {
      await prefs.setString('user_injuries', injuriesLimitations);
    }

    if (!mounted) return;
    state = state.copyWith(
      userName: name,
      userAge: age,
      userHeight: height,
      currentWeight: weight,
      userSex: sex,
      userActivityLevel: activityLevel,
      userGoal: goal,
      dietPreference: dietPreference,
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      carbsGoal: carbsGoal,
      fatGoal: fatGoal,
      equipmentAccess: equipmentAccess,
      injuriesLimitations: injuriesLimitations,
    );
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
      final db = ref.watch(databaseProvider);
      return UserProfileNotifier(db);
    });
