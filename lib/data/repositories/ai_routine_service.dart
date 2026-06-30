import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import 'workout_repository.dart';

final aiRoutineServiceProvider = Provider<AiRoutineService>((ref) {
  return AiRoutineService();
});

class GeneratedRoutineResult {
  final String name;
  final String goal;
  final String notes;
  final List<RoutineDayWithExercises> days;

  GeneratedRoutineResult({
    required this.name,
    required this.goal,
    required this.notes,
    required this.days,
  });
}

class AiRoutineService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
  ));

  // 1. Generate routine (attempts online FastAPI API -> falls back to offline local rule generator)
  Future<GeneratedRoutineResult> generateRoutine({
    required String goal,
    required String equipment,
    required int daysPerWeek,
    required String experience,
    required String injuries,
  }) async {
    try {
      // API call to local Python backend running FastAPI AI endpoint
      final response = await _dio.post('${AppConfig.backendUrl}/api/ai/routine', data: {
        'goal': goal,
        'equipment': equipment,
        'days_per_week': daysPerWeek,
        'experience': experience,
        'injuries': injuries,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        
        // Parse online response
        final List<dynamic> daysList = data['days'] ?? [];
        final days = daysList.map((dayData) {
          final List<dynamic> exList = dayData['exercises'] ?? [];
          final exercises = exList.map((ex) {
            return RoutineExerciseInput(
              name: ex['name'] ?? 'Exercise',
              sets: ex['sets'] ?? 3,
              repsRange: ex['reps'] ?? '10',
            );
          }).toList();

          return RoutineDayWithExercises(
            dayName: dayData['name'] ?? 'Workout',
            dayOfWeek: dayData['day_of_week'] ?? 1,
            isRestDay: dayData['is_rest_day'] ?? false,
            exercises: exercises,
          );
        }).toList();

        return GeneratedRoutineResult(
          name: data['name'] ?? 'AI Workout Routine',
          goal: goal,
          notes: data['notes'] ?? 'Generated specifically for your parameters.',
          days: days,
        );
      }
    } catch (e) {
      // Log error, continue to offline fallback
    }

    // 2. Offline-First fallback generation (Local rule engine)
    return _generateOfflineFallback(goal, equipment, daysPerWeek, experience);
  }

  GeneratedRoutineResult _generateOfflineFallback(
    String goal,
    String equipment,
    int daysPerWeek,
    String experience,
  ) {
    // Generate structured fallback routines locally
    final String routineName = 'Offline ${experience.toUpperCase()} $goal Routine';
    final String notes = 'Generated locally. Equipment: ${equipment.toUpperCase()}. Days: $daysPerWeek days/week.';
    
    final List<RoutineDayWithExercises> days = [];

    // Let's create days based on requested count (typical 3-day split is Push/Pull/Legs)
    if (daysPerWeek == 3) {
      // Day 1: Push (Monday = 1)
      days.add(RoutineDayWithExercises(
        dayName: 'Day 1: Chest & Shoulders (Push)',
        dayOfWeek: 1,
        isRestDay: false,
        exercises: [
          RoutineExerciseInput(name: 'Flat Barbell Bench Press', sets: 4, repsRange: '8-12'),
          RoutineExerciseInput(name: 'Dumbbell Shoulder Press', sets: 3, repsRange: '10-12'),
          RoutineExerciseInput(name: 'Incline Dumbbell Press', sets: 3, repsRange: '10'),
          RoutineExerciseInput(name: 'Tricep Pushdown', sets: 3, repsRange: '12-15'),
        ],
      ));

      // Day 2: Rest (Wednesday = 3)
      days.add(RoutineDayWithExercises(dayName: 'Rest Day', dayOfWeek: 2, isRestDay: true, exercises: []));

      // Day 3: Pull (Wednesday = 3)
      days.add(RoutineDayWithExercises(
        dayName: 'Day 2: Back & Biceps (Pull)',
        dayOfWeek: 3,
        isRestDay: false,
        exercises: [
          RoutineExerciseInput(name: 'Lat Pulldown', sets: 4, repsRange: '10-12'),
          RoutineExerciseInput(name: 'Bicep Dumbbell Curl', sets: 3, repsRange: '12'),
          RoutineExerciseInput(name: 'Romanian Deadlift (RDL)', sets: 3, repsRange: '8-10'),
        ],
      ));

      // Day 4: Rest (Thursday = 4)
      days.add(RoutineDayWithExercises(dayName: 'Rest Day', dayOfWeek: 4, isRestDay: true, exercises: []));

      // Day 5: Legs (Friday = 5)
      days.add(RoutineDayWithExercises(
        dayName: 'Day 3: Lower Body (Legs)',
        dayOfWeek: 5,
        isRestDay: false,
        exercises: [
          RoutineExerciseInput(name: 'Barbell Squat', sets: 4, repsRange: '8-10'),
          RoutineExerciseInput(name: 'Romanian Deadlift (RDL)', sets: 3, repsRange: '10-12'),
        ],
      ));

      // Day 6 & 7: Rest
      days.add(RoutineDayWithExercises(dayName: 'Rest Day', dayOfWeek: 6, isRestDay: true, exercises: []));
      days.add(RoutineDayWithExercises(dayName: 'Rest Day', dayOfWeek: 7, isRestDay: true, exercises: []));
    } else {
      // 4 or 5 days fallback: Upper / Lower splits
      days.add(RoutineDayWithExercises(
        dayName: 'Day 1: Upper Body A',
        dayOfWeek: 1,
        isRestDay: false,
        exercises: [
          RoutineExerciseInput(name: 'Flat Barbell Bench Press', sets: 4, repsRange: '8-10'),
          RoutineExerciseInput(name: 'Lat Pulldown', sets: 4, repsRange: '10'),
          RoutineExerciseInput(name: 'Dumbbell Shoulder Press', sets: 3, repsRange: '12'),
          RoutineExerciseInput(name: 'Bicep Dumbbell Curl', sets: 3, repsRange: '12'),
        ],
      ));

      days.add(RoutineDayWithExercises(
        dayName: 'Day 2: Lower Body A',
        dayOfWeek: 2,
        isRestDay: false,
        exercises: [
          RoutineExerciseInput(name: 'Barbell Squat', sets: 4, repsRange: '8-10'),
          RoutineExerciseInput(name: 'Romanian Deadlift (RDL)', sets: 4, repsRange: '10'),
        ],
      ));

      days.add(RoutineDayWithExercises(dayName: 'Rest Day', dayOfWeek: 3, isRestDay: true, exercises: []));

      days.add(RoutineDayWithExercises(
        dayName: 'Day 3: Upper Body B',
        dayOfWeek: 4,
        isRestDay: false,
        exercises: [
          RoutineExerciseInput(name: 'Incline Dumbbell Press', sets: 4, repsRange: '10'),
          RoutineExerciseInput(name: 'Lat Pulldown', sets: 3, repsRange: '12'),
          RoutineExerciseInput(name: 'Tricep Pushdown', sets: 3, repsRange: '12-15'),
        ],
      ));

      days.add(RoutineDayWithExercises(
        dayName: 'Day 4: Lower Body B',
        dayOfWeek: 5,
        isRestDay: false,
        exercises: [
          RoutineExerciseInput(name: 'Barbell Squat', sets: 3, repsRange: '12'),
          RoutineExerciseInput(name: 'Romanian Deadlift (RDL)', sets: 3, repsRange: '12'),
        ],
      ));

      days.add(RoutineDayWithExercises(dayName: 'Rest Day', dayOfWeek: 6, isRestDay: true, exercises: []));
      days.add(RoutineDayWithExercises(dayName: 'Rest Day', dayOfWeek: 7, isRestDay: true, exercises: []));
    }

    return GeneratedRoutineResult(
      name: routineName,
      goal: goal,
      notes: notes,
      days: days,
    );
  }
}
