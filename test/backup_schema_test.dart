import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'water_logged': 5,
      'water_goal': 10,
      'water_glass_size': 300,
      'water_last_logged_date': '2026-07-27',
      'streak_freezes_count': 2,
      'pref_streak_freeze_count': 2,
      'user_streak_count': 14,
      'last_streak_date': '2026-07-27',
      'prefRemindWorkout': true,
      'prefRemindMeals': false,
      'prefRemindWater': true,
      'prefRemindEvening': false,
      'prefRemindWeekly': true,
      'prefQuietHoursEnabled': true,
      'prefQuietHoursStart': 22,
      'prefQuietHoursEnd': 7,
      'weekly_action_type': 'workout',
      'weekly_action_text': 'Complete 4 workouts',
      'weekly_action_target': 4,
      'weekly_action_target_date': '2026-08-02',
      'pref_crash_reporting_enabled': true,
      'pref_offline_only': true,
      'offline_only': true,
      'user_name': 'Aarav Sharma',
      'user_target_weight': 75.0,
      'last_freeze_claimed_at': 1774000000000,
      'installed_food_packs': ['north_indian_pack', 'south_indian_pack'],
      'unlocked_achievement_ids': ['streak_7', 'first_workout'],
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('Task T3: Canonical Versioned Backup Schema Tests', () {
    test('Empty database produces valid version 5 backup', () async {
      final prefs = await SharedPreferences.getInstance();
      final backup = await BackupData.createFromDatabase(db, prefs);

      expect(backup.version, equals(5));
      expect(backup.schemaVersion, equals(14));

      final jsonMap = backup.toJson();
      expect(jsonMap['version'], equals(5));
      expect(jsonMap['schema_version'], equals(14));
      expect(jsonMap.containsKey('user_preferences'), isTrue);

      final restored = BackupData.fromJson(jsonMap);
      expect(restored.version, equals(5));
      expect(restored.userPreferences['water_logged'], equals(5));
      expect(restored.userPreferences['user_streak_count'], equals(14));
    });

    test(
      'All user-owned tables and fields survive round-trip serialization',
      () async {
        // 1. User Profile
        await db
            .into(db.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                age: const Value(30),
                height: const Value(180.0),
                weight: const Value(82.5),
                sex: const Value('male'),
                activityLevel: const Value('high'),
                goal: const Value('build_muscle'),
                dietPreference: const Value('high_protein'),
                calorieGoal: const Value(2800),
                proteinGoal: const Value(180.0),
                carbsGoal: const Value(300.0),
                fatGoal: const Value(80.0),
              ),
            );

        // 2. Custom Food Item with Hindi unicode
        final customFoodId = await db
            .into(db.foodItems)
            .insert(
              FoodItemsCompanion.insert(
                name: 'Paneer Bhurji (पनीर भुर्जी)',
                nameHindi: const Value('पनीर भुर्जी'),
                calories: 320,
                proteinG: 22.0,
                carbsG: 8.0,
                fatG: 22.0,
                fiberG: const Value(2.5),
                servingSize: 150.0,
                servingUnit: 'g',
                category: 'sabzi',
                isCustom: const Value(true),
              ),
            );

        // 3. Food Log
        await db
            .into(db.foodLogs)
            .insert(
              FoodLogsCompanion.insert(
                foodItemId: Value(customFoodId),
                name: 'Paneer Bhurji (पनीर भुर्जी)',
                calories: 320,
                proteinG: 22.0,
                carbsG: 8.0,
                fatG: 22.0,
                servingLogged: 1.0,
                servingUnit: 'serving',
                mealType: 'lunch',
                uuid: const Value('food-log-uuid-123'),
              ),
            );

        // 4. Meal Template & Item
        final templateId = await db
            .into(db.mealTemplates)
            .insert(
              MealTemplatesCompanion.insert(
                name: 'High Protein Breakfast',
                defaultMealType: const Value('breakfast'),
              ),
            );

        await db
            .into(db.mealTemplateItems)
            .insert(
              MealTemplateItemsCompanion.insert(
                templateId: templateId,
                name: 'Egg Omelette',
                calories: 250,
                proteinG: 20.0,
                carbsG: 2.0,
                fatG: 18.0,
                servingLogged: 2.0,
                servingUnit: 'eggs',
              ),
            );

        // 5. Custom Exercise
        await db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(
                name: 'Zercher Squat',
                muscleGroups: 'Quadriceps,Core',
                equipment: 'Barbell',
                difficulty: 'Advanced',
                formCues: 'Keep elbows high and core braced.',
                commonMistakes: 'Rounding upper back.',
                isCustom: const Value(true),
              ),
            );

        // 6. Workout Session & Sets (including cardio and setType fields)
        final sessionId = await db
            .into(db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                name: 'Leg Day & Cardio',
                totalVolume: 1250.0,
                durationSeconds: 3600,
                estimatedCalories: 450,
                uuid: const Value('session-uuid-456'),
              ),
            );

        await db
            .into(db.workoutSets)
            .insert(
              WorkoutSetsCompanion.insert(
                sessionId: sessionId,
                exerciseName: 'Treadmill Run',
                weight: 0.0,
                reps: 0,
                setNumber: 1,
                isPr: const Value(true),
                rpe: const Value(8),
                isWarmUp: const Value(false),
                setNotes: const Value('Incline interval run'),
                uuid: const Value('set-uuid-789'),
                setType: const Value('cardio'),
                durationSeconds: const Value(1200),
                distanceKm: const Value(3.5),
                inclinePercentage: const Value(4.0),
              ),
            );

        // 7. Workout Routine, Days & Exercises
        final routineId = await db
            .into(db.workoutRoutines)
            .insert(
              WorkoutRoutinesCompanion.insert(
                name: 'PPL Routine',
                goal: 'hypertrophy',
                notes: const Value('6-day push pull legs split'),
              ),
            );

        final dayId = await db
            .into(db.routineDays)
            .insert(
              RoutineDaysCompanion.insert(
                routineId: routineId,
                dayOfWeek: 1,
                name: 'Push Day',
              ),
            );

        await db
            .into(db.routineExercises)
            .insert(
              RoutineExercisesCompanion.insert(
                dayId: dayId,
                exerciseName: 'Bench Press',
                sets: 4,
                repsRange: '8-12',
                orderIndex: 1,
              ),
            );

        // 8. Workout Draft
        await db
            .into(db.workoutDrafts)
            .insert(
              WorkoutDraftsCompanion.insert(
                routineName: 'Push Day Draft',
                currentExerciseIndex: 2,
                currentSetIndex: 1,
                elapsedSeconds: 840,
                loggedSetsJson: '[]',
              ),
            );

        // 9. Body Measurement
        await db
            .into(db.bodyMeasurements)
            .insert(
              BodyMeasurementsCompanion.insert(
                weight: const Value(82.5),
                waist: const Value(84.0),
                chest: const Value(102.0),
                arms: const Value(38.5),
              ),
            );

        final prefs = await SharedPreferences.getInstance();
        final backup = await BackupData.createFromDatabase(db, prefs);
        final jsonMap = backup.toJson();
        final jsonString = jsonEncode(jsonMap);

        // Deserialization verification
        final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;
        final restored = BackupData.fromJson(decodedMap);

        expect(restored.version, equals(5));
        expect(restored.schemaVersion, equals(14));

        // 1. User Profile check
        expect(restored.userProfile, isNotNull);
        expect(restored.userProfile!.age, equals(30));
        expect(restored.userProfile!.calorieGoal, equals(2800));

        // 2. Custom Food check
        expect(restored.customFoodItems.length, equals(1));
        expect(
          restored.customFoodItems.first.name,
          equals('Paneer Bhurji (पनीर भुर्जी)'),
        );

        // 3. Food Log check
        expect(restored.foodLogs.length, equals(1));
        expect(restored.foodLogs.first.uuid, equals('food-log-uuid-123'));
        expect(restored.foodLogs.first.foodItemId, equals(customFoodId));

        // 4. Meal Templates check
        expect(restored.mealTemplates.length, equals(1));
        expect(
          restored.mealTemplates.first.name,
          equals('High Protein Breakfast'),
        );
        expect(restored.mealTemplateItems.length, equals(1));
        expect(restored.mealTemplateItems.first.templateId, equals(templateId));

        // 5. Custom Exercises check
        expect(restored.customExercises.length, equals(1));
        expect(restored.customExercises.first.name, equals('Zercher Squat'));

        // 6. Workout Sessions & Sets check
        expect(restored.workoutSessions.length, equals(1));
        expect(restored.workoutSessions.first.uuid, equals('session-uuid-456'));
        expect(restored.workoutSets.length, equals(1));
        final set = restored.workoutSets.first;
        expect(set.setType, equals('cardio'));
        expect(set.durationSeconds, equals(1200));
        expect(set.distanceKm, equals(3.5));
        expect(set.inclinePercentage, equals(4.0));

        // 7. Workout Routines, Days, Exercises check
        expect(restored.workoutRoutines.length, equals(1));
        expect(restored.routineDays.length, equals(1));
        expect(restored.routineDays.first.routineId, equals(routineId));
        expect(restored.routineExercises.length, equals(1));
        expect(restored.routineExercises.first.dayId, equals(dayId));

        // 8. Workout Drafts check
        expect(restored.workoutDrafts.length, equals(1));
        expect(
          restored.workoutDrafts.first.routineName,
          equals('Push Day Draft'),
        );

        // 9. Body Measurements check
        expect(restored.bodyMeasurements.length, equals(1));
        expect(restored.bodyMeasurements.first.weight, equals(82.5));

        // 10. User Preferences check
        expect(restored.userPreferences['onboarding_completed'], isTrue);
        expect(restored.userPreferences['water_logged'], equals(5));
        expect(restored.userPreferences['user_name'], equals('Aarav Sharma'));
        expect(restored.userPreferences['user_target_weight'], equals(75.0));
        expect(
          restored.userPreferences['last_freeze_claimed_at'],
          equals(1774000000000),
        );
        expect(
          restored.userPreferences['unlocked_achievement_ids'],
          equals(['streak_7', 'first_workout']),
        );
      },
    );

    test('Rejects backup payload with missing or invalid version', () {
      expect(
        () => BackupData.fromJson({'schema_version': 13}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('missing numeric "version" identifier'),
          ),
        ),
      );
    });

    test('Rejects unsupported newer backup format versions (version > 5)', () {
      expect(
        () => BackupData.fromJson({'version': 6, 'schema_version': 14}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported backup format version 6'),
          ),
        ),
      );
    });

    test('Rejects unsupported legacy backup format versions (version < 3)', () {
      expect(
        () => BackupData.fromJson({'version': 2, 'schema_version': 13}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported legacy backup format version 2'),
          ),
        ),
      );
    });

    test(
      'Version 3 backup payload parses gracefully with default fallback collections',
      () {
        final v3Payload = {
          'version': 3,
          'timestamp': '2026-07-27T12:00:00.000Z',
          'schema_version': 13,
          'food_logs': [
            {
              'name': 'Apple',
              'calories': 95,
              'protein_g': 0.5,
              'carbs_g': 25.0,
              'fat_g': 0.3,
              'serving_logged': 1.0,
              'serving_unit': 'apple',
              'meal_type': 'snack',
              'logged_at': '2026-07-27T10:00:00.000Z',
            },
          ],
          'workout_sessions': [],
          'workout_sets': [],
          'body_measurements': [],
        };

        final restored = BackupData.fromJson(v3Payload);
        expect(restored.version, equals(3));
        expect(restored.foodLogs.length, equals(1));
        expect(restored.mealTemplates, isEmpty);
        expect(restored.workoutDrafts, isEmpty);
        expect(restored.userProfile, isNull);
      },
    );

    test(
      'Secrets and backend credentials are excluded from backup output',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final backup = await BackupData.createFromDatabase(db, prefs);
        final jsonString = jsonEncode(backup.toJson());

        expect(jsonString.contains('INDIFIT_API_KEY'), isFalse);
        expect(jsonString.contains('x-indifit-key'), isFalse);
      },
    );
  });
}
