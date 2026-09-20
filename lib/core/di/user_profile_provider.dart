import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/repositories/nutrition_goal_repository.dart';
import '../config/app_preferences_keys.dart';
import '../services/crash_reporting_service.dart';
import '../services/local_schedule_date_service.dart';
import '../services/local_timezone_service.dart';
import '../utils/app_logger.dart';
import 'providers.dart';

class UserProfileState {
  final bool isLoaded;
  final bool hasProfile;
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
    this.isLoaded = false,
    this.hasProfile = false,
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
    bool? isLoaded,
    bool? hasProfile,
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
      isLoaded: isLoaded ?? this.isLoaded,
      hasProfile: hasProfile ?? this.hasProfile,
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
  final LocalTimezoneService _timezones;
  final SharedPreferences? _prefs;
  Future<void>? _profileLoad;

  UserProfileNotifier([
    this._db,
    LocalTimezoneService? timezones,
    SharedPreferences? prefs,
  ])  : _timezones = timezones ?? LocalTimezoneService(),
        _prefs = prefs,
        super(
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

  Future<SharedPreferences> _getPrefs() async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<void> loadProfile() {
    final inFlight = _profileLoad;
    if (inFlight != null) return inFlight;
    final load = _loadProfileOnce();
    _profileLoad = load;
    return load.whenComplete(() {
      if (identical(_profileLoad, load)) _profileLoad = null;
    });
  }

  Future<void> _loadProfileOnce() async {
    final prefs = await _getPrefs();
    final onboardingSkipped =
        prefs.getBool(AppPreferenceKeys.onboardingSkipped) ?? false;
    var hasProfile =
        !onboardingSkipped &&
        (prefs.containsKey(AppPreferenceKeys.userAge) ||
            prefs.containsKey(AppPreferenceKeys.userHeight) ||
            prefs.containsKey(AppPreferenceKeys.currentWeight) ||
            prefs.containsKey(AppPreferenceKeys.userSex));
    int cals = prefs.getInt(AppPreferenceKeys.calorieGoal) ?? 2000;
    double protein = prefs.getDouble(AppPreferenceKeys.proteinGoal) ?? 120.0;
    double carbs = prefs.getDouble(AppPreferenceKeys.carbsGoal) ?? 230.0;
    double fat = prefs.getDouble(AppPreferenceKeys.fatGoal) ?? 65.0;
    double weight = prefs.getDouble(AppPreferenceKeys.currentWeight) ?? 74.5;
    double? height = prefs.getDouble(AppPreferenceKeys.userHeight);
    String? name = prefs.getString(AppPreferenceKeys.userName);
    String sex = prefs.getString(AppPreferenceKeys.userSex) ?? 'male';
    int age = prefs.getInt(AppPreferenceKeys.userAge) ?? 25;
    String activity =
        prefs.getString(AppPreferenceKeys.userActivityLevel) ?? 'moderate';
    String goal = prefs.getString(AppPreferenceKeys.userGoal) ?? 'maintain';
    String diet = prefs.getString(AppPreferenceKeys.userDietPreference) ?? 'veg';
    String equipment =
        prefs.getString(AppPreferenceKeys.userEquipment) ?? 'full_gym';
    String injuries = prefs.getString(AppPreferenceKeys.userInjuries) ?? '';
    final db = _db;
    if (db != null) {
      try {
        var profiles = await db.select(db.userProfiles).get();
        if (profiles.isNotEmpty) {
          hasProfile = true;
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
        } else if (!onboardingSkipped) {
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
          profiles = await db.select(db.userProfiles).get();
          hasProfile = profiles.isNotEmpty;
        }

        if (profiles.isNotEmpty) {
          final p = profiles.first;
          final timezoneId = await _readTimezoneId();
          final dates = LocalScheduleDateService();
          final goalRepository = NutritionGoalRepository(
            database: db,
            dates: dates,
          );
          final owner = p.id.toString();
          await goalRepository.ensureCompatibilityImport(
            userId: owner,
            legacyProfile: NutritionGoalCommand(
              userId: owner,
              goalType: NutritionGoalTypeId.parse(p.goal),
              calorieTargetKcal: p.calorieGoal,
              proteinTargetG: p.proteinGoal,
              carbsTargetG: p.carbsGoal,
              fatTargetG: p.fatGoal,
              effectiveFromLocalDate: dates.todayIn(timezoneId),
              timezoneId: timezoneId,
            ),
          );
          final active = await goalRepository.activeGoal(
            userId: owner,
            localDate: dates.todayIn(timezoneId),
            timezoneId: timezoneId,
          );
          if (active != null) {
            cals = active.calorieTargetKcal ?? cals;
            protein = active.proteinTargetG ?? protein;
            carbs = active.carbsTargetG ?? carbs;
            fat = active.fatTargetG ?? fat;
            goal = switch (active.goalType) {
              NutritionGoalType.loss => 'lose',
              NutritionGoalType.maintenance => 'maintain',
              NutritionGoalType.gain => 'gain',
              NutritionGoalType.custom => 'custom',
            };
          }
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
      isLoaded: true,
      hasProfile: hasProfile,
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
    String? commandId,
  }) async {
    final db = _db;
    if (db != null) {
      try {
        var profiles = await db.select(db.userProfiles).get();
        if (profiles.isEmpty) {
          await db
              .into(db.userProfiles)
              .insert(
                UserProfilesCompanion.insert(
                  calorieGoal: Value(state.calorieGoal),
                  proteinGoal: Value(state.proteinGoal),
                  carbsGoal: Value(state.carbsGoal),
                  fatGoal: Value(state.fatGoal),
                  weight: Value(state.currentWeight),
                  height: state.userHeight != null
                      ? Value(state.userHeight!)
                      : const Value.absent(),
                  name: Value(state.userName ?? ''),
                  sex: Value(state.userSex),
                  age: Value(state.userAge),
                  activityLevel: Value(state.userActivityLevel),
                  goal: Value(state.userGoal),
                  dietPreference: Value(state.dietPreference),
                  equipmentAccess: Value(state.equipmentAccess),
                  injuriesLimitations: Value(state.injuriesLimitations),
                ),
              );
          profiles = await db.select(db.userProfiles).get();
        }
        if (profiles.isNotEmpty) {
          final timezoneId = await _readTimezoneId();
          final dates = LocalScheduleDateService();
          final owner = profiles.first.id.toString();
          final repository = NutritionGoalRepository(
            database: db,
            dates: dates,
          );
          await repository.ensureCompatibilityImport(
            userId: owner,
            legacyProfile: NutritionGoalCommand(
              userId: owner,
              goalType: NutritionGoalTypeId.parse(profiles.first.goal),
              calorieTargetKcal: profiles.first.calorieGoal,
              proteinTargetG: profiles.first.proteinGoal,
              carbsTargetG: profiles.first.carbsGoal,
              fatTargetG: profiles.first.fatGoal,
              effectiveFromLocalDate: dates.todayIn(timezoneId),
              timezoneId: timezoneId,
            ),
          );
          final today = dates.todayIn(timezoneId);
          final active = await repository.activeGoal(
            userId: owner,
            localDate: today,
            timezoneId: timezoneId,
          );
          await repository.recordUserSetGoal(
            NutritionGoalCommand(
              userId: owner,
              goalType: NutritionGoalTypeId.parse(state.userGoal),
              calorieTargetKcal:
                  calorieGoal ?? active?.calorieTargetKcal ?? state.calorieGoal,
              proteinTargetG:
                  proteinGoal ?? active?.proteinTargetG ?? state.proteinGoal,
              carbsTargetG:
                  carbsGoal ?? active?.carbsTargetG ?? state.carbsGoal,
              fatTargetG: fatGoal ?? active?.fatTargetG ?? state.fatGoal,
              effectiveFromLocalDate: today,
              timezoneId: timezoneId,
              commandId: commandId,
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
        rethrow;
      }

      state = state.copyWith(
        calorieGoal: calorieGoal,
        proteinGoal: proteinGoal,
        carbsGoal: carbsGoal,
        fatGoal: fatGoal,
      );
      return;
    }

    final prefs = await _getPrefs();
    if (calorieGoal != null) {
      await prefs.setInt(AppPreferenceKeys.calorieGoal, calorieGoal);
    }
    if (proteinGoal != null) {
      await prefs.setDouble(AppPreferenceKeys.proteinGoal, proteinGoal);
    }
    if (carbsGoal != null) {
      await prefs.setDouble(AppPreferenceKeys.carbsGoal, carbsGoal);
    }
    if (fatGoal != null) {
      await prefs.setDouble(AppPreferenceKeys.fatGoal, fatGoal);
    }

    state = state.copyWith(
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      carbsGoal: carbsGoal,
      fatGoal: fatGoal,
    );
  }

  Future<String> _readTimezoneId() async {
    try {
      return await _timezones.currentTimezoneId();
    } catch (_) {
      return 'UTC';
    }
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

    final prefs = await _getPrefs();
    await prefs.setDouble(AppPreferenceKeys.currentWeight, weight);
    await prefs.setDouble(AppPreferenceKeys.userWeight, weight);

    state = state.copyWith(currentWeight: weight);
  }

  /// Updates profile state after the dashboard persists a weight change.
  void syncWeightFromPersistence(double weight) {
    if (!mounted) return;
    state = state.copyWith(currentWeight: weight);
  }

  Future<void> updateHeight(double height) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(AppPreferenceKeys.userHeight, height);

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
    final prefs = await _getPrefs();
    await prefs.setString(AppPreferenceKeys.userName, name);
    state = state.copyWith(userName: name);
  }

  /// Persists the dietary pattern without manufacturing the remaining profile
  /// fields. This is important for users who intentionally skipped onboarding:
  /// choosing a diet must not create default age, sex, goals, or eligibility
  /// evidence underneath a partial settings edit.
  Future<void> updateDietPreference(String dietPreference) async {
    final db = _db;
    if (db != null) {
      final profiles = await db.select(db.userProfiles).get();
      if (profiles.isNotEmpty) {
        await (db.update(
          db.userProfiles,
        )..where((table) => table.id.equals(profiles.first.id))).write(
          UserProfilesCompanion(
            dietPreference: Value(dietPreference),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }

    final prefs = await _getPrefs();
    await prefs.setString(AppPreferenceKeys.userDietPreference, dietPreference);
    if (!mounted) return;
    state = state.copyWith(dietPreference: dietPreference);
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
        var profiles = await db.select(db.userProfiles).get();
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
              dietPreference: dietPreference != null
                  ? Value(dietPreference)
                  : const Value.absent(),
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
                  goal: Value(state.userGoal),
                  dietPreference: Value(dietPreference ?? 'balanced'),
                  calorieGoal: Value(state.calorieGoal),
                  proteinGoal: Value(state.proteinGoal),
                  carbsGoal: Value(state.carbsGoal),
                  fatGoal: Value(state.fatGoal),
                  equipmentAccess: Value(equipmentAccess ?? 'full_gym'),
                  injuriesLimitations: Value(injuriesLimitations ?? ''),
                ),
              );
          profiles = await db.select(db.userProfiles).get();
        }
        if (profiles.isNotEmpty) {
          final timezoneId = await _readTimezoneId();
          final dates = LocalScheduleDateService();
          final owner = profiles.first.id.toString();
          final repository = NutritionGoalRepository(
            database: db,
            dates: dates,
          );
          await repository.ensureCompatibilityImport(
            userId: owner,
            legacyProfile: NutritionGoalCommand(
              userId: owner,
              goalType: NutritionGoalTypeId.parse(profiles.first.goal),
              calorieTargetKcal: profiles.first.calorieGoal,
              proteinTargetG: profiles.first.proteinGoal,
              carbsTargetG: profiles.first.carbsGoal,
              fatTargetG: profiles.first.fatGoal,
              effectiveFromLocalDate: dates.todayIn(timezoneId),
              timezoneId: timezoneId,
            ),
          );
          final goalChangeRequested =
              goal != null ||
              calorieGoal != null ||
              proteinGoal != null ||
              carbsGoal != null ||
              fatGoal != null;
          if (goalChangeRequested) {
            final today = dates.todayIn(timezoneId);
            final active = await repository.activeGoal(
              userId: owner,
              localDate: today,
              timezoneId: timezoneId,
            );
            await repository.recordUserSetGoal(
              NutritionGoalCommand(
                userId: owner,
                goalType: goal != null
                    ? NutritionGoalTypeId.parse(goal)
                    : active?.goalType ??
                          NutritionGoalTypeId.parse(profiles.first.goal),
                calorieTargetKcal:
                    calorieGoal ??
                    active?.calorieTargetKcal ??
                    state.calorieGoal,
                proteinTargetG:
                    proteinGoal ?? active?.proteinTargetG ?? state.proteinGoal,
                carbsTargetG:
                    carbsGoal ?? active?.carbsTargetG ?? state.carbsGoal,
                fatTargetG: fatGoal ?? active?.fatTargetG ?? state.fatGoal,
                effectiveFromLocalDate: today,
                timezoneId: timezoneId,
              ),
            );
          }
        }
      } catch (e, st) {
        AppLogger.warning('updateProfile database write failed: $e');
        CrashReportingService.recordCrash(
          e,
          st,
          reason: 'updateProfile db error',
        );
        rethrow;
      }
    }

    final prefs = await _getPrefs();
    if (name != null) await prefs.setString(AppPreferenceKeys.userName, name);
    if (age != null) await prefs.setInt(AppPreferenceKeys.userAge, age);
    if (height != null) {
      await prefs.setDouble(AppPreferenceKeys.userHeight, height);
    }
    if (weight != null) {
      await prefs.setDouble(AppPreferenceKeys.userWeight, weight);
      await prefs.setDouble(AppPreferenceKeys.currentWeight, weight);
    }
    if (sex != null) await prefs.setString(AppPreferenceKeys.userSex, sex);
    if (activityLevel != null) {
      await prefs.setString(AppPreferenceKeys.userActivityLevel, activityLevel);
    }
    if (db == null && goal != null) {
      await prefs.setString(AppPreferenceKeys.userGoal, goal);
    }
    if (dietPreference != null) {
      await prefs.setString(
        AppPreferenceKeys.userDietPreference,
        dietPreference,
      );
    }
    if (db == null && calorieGoal != null) {
      await prefs.setInt(AppPreferenceKeys.calorieGoal, calorieGoal);
    }
    if (db == null && proteinGoal != null) {
      await prefs.setDouble(AppPreferenceKeys.proteinGoal, proteinGoal);
    }
    if (db == null && carbsGoal != null) {
      await prefs.setDouble(AppPreferenceKeys.carbsGoal, carbsGoal);
    }
    if (db == null && fatGoal != null) {
      await prefs.setDouble(AppPreferenceKeys.fatGoal, fatGoal);
    }
    if (equipmentAccess != null) {
      await prefs.setString(AppPreferenceKeys.userEquipment, equipmentAccess);
    }
    if (injuriesLimitations != null) {
      await prefs.setString(AppPreferenceKeys.userInjuries, injuriesLimitations);
    }

    if (!mounted) return;
    state = state.copyWith(
      isLoaded: true,
      hasProfile: true,
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
      final timezones = ref.watch(localTimezoneServiceProvider);
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } catch (_) {}
      return UserProfileNotifier(db, timezones, prefs);
    });
