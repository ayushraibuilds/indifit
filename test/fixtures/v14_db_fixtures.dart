import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:path/path.dart' as p;

/// Deterministic v14 database fixture builders and seeders.
class V14DbFixtures {
  /// Opens an AppDatabase backed by an on-disk SQLite file in [dir].
  static AppDatabase openOnDiskDatabase(Directory dir, String filename) {
    final file = File(p.join(dir.path, filename));
    return AppDatabase.executor(NativeDatabase(file));
  }

  /// Seeds a database with Zero Routines / Zero Sessions baseline.
  static Future<void> seedZeroRoutines(AppDatabase db) async {
    // Database remains empty of routines and sessions
  }

  /// Seeds a database with Single Routine ("Push Day").
  static Future<int> seedSingleRoutine(AppDatabase db) async {
    final routineId = await db
        .into(db.workoutRoutines)
        .insert(
          WorkoutRoutinesCompanion.insert(
            name: 'Push Day',
            goal: 'Hypertrophy',
          ),
        );

    final dayId = await db
        .into(db.routineDays)
        .insert(
          RoutineDaysCompanion.insert(
            routineId: routineId,
            dayOfWeek: 1,
            name: 'Push Primary',
          ),
        );

    await db
        .into(db.routineExercises)
        .insert(
          RoutineExercisesCompanion.insert(
            dayId: dayId,
            exerciseName: 'Flat Barbell Bench Press',
            sets: 4,
            repsRange: '8',
            orderIndex: 0,
          ),
        );

    await db
        .into(db.routineExercises)
        .insert(
          RoutineExercisesCompanion.insert(
            dayId: dayId,
            exerciseName: 'Seated Dumbbell Shoulder Press',
            sets: 3,
            repsRange: '10',
            orderIndex: 1,
          ),
        );

    return routineId;
  }

  /// Seeds a database with Multiple Routines ("Push", "Pull", "Legs") and historical sessions/sets.
  static Future<void> seedMultipleRoutinesAndHistory(AppDatabase db) async {
    // 1. Push Routine
    await seedSingleRoutine(db);

    // 2. Pull Routine
    final pullId = await db
        .into(db.workoutRoutines)
        .insert(
          WorkoutRoutinesCompanion.insert(name: 'Pull Day', goal: 'Strength'),
        );

    final pullDayId = await db
        .into(db.routineDays)
        .insert(
          RoutineDaysCompanion.insert(
            routineId: pullId,
            dayOfWeek: 1,
            name: 'Pull Primary',
          ),
        );

    await db
        .into(db.routineExercises)
        .insert(
          RoutineExercisesCompanion.insert(
            dayId: pullDayId,
            exerciseName: 'Barbell Deadlift',
            sets: 3,
            repsRange: '5',
            orderIndex: 0,
          ),
        );

    await db
        .into(db.routineExercises)
        .insert(
          RoutineExercisesCompanion.insert(
            dayId: pullDayId,
            exerciseName: 'Lat Pulldown',
            sets: 4,
            repsRange: '10',
            orderIndex: 1,
          ),
        );

    // 3. Historical Workout Session 1
    final sess1Id = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            name: 'Push Day',
            totalVolume: 3200.0,
            durationSeconds: 2700,
            estimatedCalories: 320,
            completedAt: Value(
              DateTime.now().subtract(const Duration(days: 2)),
            ),
          ),
        );

    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sess1Id,
            exerciseName: 'Flat Barbell Bench Press',
            weight: 80.0,
            reps: 8,
            setNumber: 1,
            isPr: const Value(true),
            rpe: const Value(8),
            setNotes: const Value('Felt strong, clean form 💪'),
          ),
        );

    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sess1Id,
            exerciseName: 'Seated Dumbbell Shoulder Press',
            weight: 24.0,
            reps: 10,
            setNumber: 1,
            isPr: const Value(false),
            rpe: const Value(7),
          ),
        );

    // 4. Historical Workout Session 2 (Cardio & Bodyweight)
    final sess2Id = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            name: 'Cardio & Abs',
            totalVolume: 0.0,
            durationSeconds: 1800,
            estimatedCalories: 200,
            completedAt: Value(
              DateTime.now().subtract(const Duration(days: 1)),
            ),
          ),
        );

    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sess2Id,
            exerciseName: 'Treadmill Run',
            weight: 0.0,
            reps: 0,
            setNumber: 1,
            durationSeconds: const Value(1200),
            distanceKm: const Value(3.2),
            inclinePercentage: const Value(2.0),
          ),
        );

    // 5. Active Workout Draft row
    await db
        .into(db.workoutDrafts)
        .insert(
          WorkoutDraftsCompanion.insert(
            routineName: 'Push Day',
            currentExerciseIndex: 1,
            currentSetIndex: 0,
            elapsedSeconds: 900,
            loggedSetsJson:
                '[{"sessionId":0,"exerciseName":"Flat Barbell Bench Press","weight":82.5,"reps":8,"setNumber":1,"isPr":false,"rpe":8,"isWarmUp":false,"setType":"working","setNotes":"Draft note"}]',
          ),
        );
  }

  /// Seeds a database containing custom/uncatalogued user exercises.
  static Future<void> seedCustomAndUnresolvedExercises(AppDatabase db) async {
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Pike Push-ups',
            muscleGroups: 'Shoulders, Triceps',
            equipment: 'Bodyweight',
            difficulty: 'Intermediate',
            formCues: 'Keep hips high',
            commonMistakes: 'Flaring elbows',
            isCustom: const Value(true),
          ),
        );

    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: 'Superman Lat Pulls',
            muscleGroups: 'Back',
            equipment: 'Bands',
            difficulty: 'Beginner',
            formCues: 'Squeeze lats',
            commonMistakes: 'Arching too much',
            isCustom: const Value(true),
          ),
        );

    final sessId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            name: 'Bodyweight Skill Session',
            totalVolume: 0.0,
            durationSeconds: 1500,
            estimatedCalories: 150,
          ),
        );

    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessId,
            exerciseName: 'Pike Push-ups',
            weight: 0.0,
            reps: 12,
            setNumber: 1,
          ),
        );
  }

  /// Seeds a database containing known and unknown equipment strings.
  static Future<void> seedKnownAndUnknownEquipment(AppDatabase db) async {
    await db
        .into(db.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            equipmentAccess: const Value('full_gym'),
            calorieGoal: const Value(2400),
          ),
        );

    final routineId = await db
        .into(db.workoutRoutines)
        .insert(
          WorkoutRoutinesCompanion.insert(
            name: 'Special Equipment Routine',
            goal: 'General Fitness',
          ),
        );

    final dayId = await db
        .into(db.routineDays)
        .insert(
          RoutineDaysCompanion.insert(
            routineId: routineId,
            dayOfWeek: 1,
            name: 'Day 1',
          ),
        );

    await db
        .into(db.routineExercises)
        .insert(
          RoutineExercisesCompanion.insert(
            dayId: dayId,
            exerciseName: 'Anti-gravity Chamber Press',
            sets: 3,
            repsRange: '10',
            orderIndex: 0,
          ),
        );
  }

  /// Seeds a database containing malformed / orphaned relationships (for test assertion).
  static Future<void> seedMalformedRelationships(AppDatabase db) async {
    await db.customStatement('''
      INSERT INTO workout_sets (session_id, exercise_name, weight, reps, set_number, is_pr, is_warm_up, set_type)
      VALUES (999, 'Orphaned Bench Press', 80.0, 10, 1, 0, 0, 'normal');
    ''');
  }
}
