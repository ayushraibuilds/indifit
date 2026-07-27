import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/di/providers.dart';
import 'workout_repository.dart';

final aiRoutineServiceProvider = Provider<AiRoutineService>((ref) {
  final dio = ref.watch(dioProvider);
  return AiRoutineService(dio);
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
  final Dio _dio;

  AiRoutineService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 35),
            ),
          );

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
      final response = await _dio.post(
        '${AppConfig.backendUrl}/api/ai/routine',
        data: {
          'goal': goal,
          'equipment': equipment,
          'days_per_week': daysPerWeek,
          'experience': experience,
          'injuries': injuries,
        },
      );

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
          notes: data['notes'] ?? 'Generated via IndiFit AI Coach',
          days: days,
        );
      }
    } catch (e) {
      // Log error, continue to offline fallback
    }

    // 2. Offline-First fallback generation (Local rule engine)
    return _generateOfflineFallback(
      goal,
      equipment,
      daysPerWeek,
      experience,
      injuries,
    );
  }

  GeneratedRoutineResult _generateOfflineFallback(
    String goal,
    String equipment,
    int daysPerWeek,
    String experience,
    String injuries,
  ) {
    final String routineName =
        'Smart ${equipment.toUpperCase()} $daysPerWeek-Day ${goal.toUpperCase()} Split';
    final String notes =
        'Generated via Offline Engine (Equipment: ${equipment.toUpperCase()}, Days: $daysPerWeek/wk)';

    final reps = switch (goal) {
      'strength' => '4-6',
      'weight_loss' => '12-15',
      _ => '8-12',
    };

    final lowerInjured =
        injuries.toLowerCase().contains('knee') ||
        injuries.toLowerCase().contains('back');
    final shoulderInjured = injuries.toLowerCase().contains('shoulder');

    // Exercise pools by equipment & target
    final pushEx = switch (equipment) {
      'bodyweight' => [
        'Push-ups',
        'Pike Push-ups',
        'Decline Push-ups',
        'Tricep Dips',
      ],
      'dumbbells' => [
        'Dumbbell Bench Press',
        if (!shoulderInjured)
          'Dumbbell Shoulder Press'
        else
          'Incline Dumbbell Press',
        'Dumbbell Chest Flyes',
        'Overhead Dumbbell Tricep Extension',
      ],
      _ => [
        'Flat Barbell Bench Press',
        if (!shoulderInjured)
          'Dumbbell Shoulder Press'
        else
          'Incline Dumbbell Press',
        'Incline Dumbbell Press',
        'Tricep Pushdown',
      ],
    };

    final pullEx = switch (equipment) {
      'bodyweight' => [
        'Chin-ups',
        'Inverted Rows',
        'Superman Lat Pulls',
        'Doorway Bicep Curls',
      ],
      'dumbbells' => [
        'Dumbbell Bent Over Row',
        'Single-Arm Dumbbell Row',
        'Dumbbell Bicep Curl',
        'Dumbbell Hammer Curl',
      ],
      _ => [
        'Lat Pulldown',
        'Seated Cable Row',
        'Bicep Dumbbell Curl',
        'Barbell Row',
      ],
    };

    final legEx = switch (equipment) {
      'bodyweight' => [
        if (!lowerInjured) 'Bodyweight Squats' else 'Glute Bridges',
        'Walking Lunges',
        'Single-Leg Calf Raises',
      ],
      'dumbbells' => [
        if (!lowerInjured)
          'Dumbbell Goblet Squat'
        else
          'Dumbbell Glute Bridges',
        if (!lowerInjured)
          'Dumbbell Romanian Deadlift'
        else
          'Dumbbell Step-Ups',
        'Dumbbell Lunges',
      ],
      _ => [
        if (!lowerInjured) 'Barbell Squat' else 'Leg Press',
        if (!lowerInjured) 'Romanian Deadlift (RDL)' else 'Leg Curl Machine',
        'Leg Extension Machine',
      ],
    };

    final List<RoutineDayWithExercises> days = [];

    if (daysPerWeek == 3) {
      // 3-Day Push / Pull / Legs
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 1: Push (Chest/Shoulders/Triceps)',
          dayOfWeek: 1,
          isRestDay: false,
          exercises: pushEx
              .map(
                (name) =>
                    RoutineExerciseInput(name: name, sets: 4, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Rest Day',
          dayOfWeek: 2,
          isRestDay: true,
          exercises: [],
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 2: Pull (Back/Biceps)',
          dayOfWeek: 3,
          isRestDay: false,
          exercises: pullEx
              .map(
                (name) =>
                    RoutineExerciseInput(name: name, sets: 4, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Rest Day',
          dayOfWeek: 4,
          isRestDay: true,
          exercises: [],
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 3: Legs & Core',
          dayOfWeek: 5,
          isRestDay: false,
          exercises: legEx
              .map(
                (name) =>
                    RoutineExerciseInput(name: name, sets: 4, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Rest Day',
          dayOfWeek: 6,
          isRestDay: true,
          exercises: [],
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Rest Day',
          dayOfWeek: 7,
          isRestDay: true,
          exercises: [],
        ),
      );
    } else if (daysPerWeek == 4) {
      // 4-Day Upper / Lower Split
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 1: Upper Body A',
          dayOfWeek: 1,
          isRestDay: false,
          exercises: [pushEx[0], pullEx[0], pushEx[1], pullEx[2]]
              .map(
                (name) =>
                    RoutineExerciseInput(name: name, sets: 4, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 2: Lower Body A',
          dayOfWeek: 2,
          isRestDay: false,
          exercises: legEx
              .map(
                (name) =>
                    RoutineExerciseInput(name: name, sets: 4, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Rest Day',
          dayOfWeek: 3,
          isRestDay: true,
          exercises: [],
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 3: Upper Body B',
          dayOfWeek: 4,
          isRestDay: false,
          exercises: [pushEx[1], pullEx[1], pushEx[3], pullEx[3]]
              .map(
                (name) =>
                    RoutineExerciseInput(name: name, sets: 4, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 4: Lower Body B',
          dayOfWeek: 5,
          isRestDay: false,
          exercises: legEx
              .map(
                (name) =>
                    RoutineExerciseInput(name: name, sets: 3, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Rest Day',
          dayOfWeek: 6,
          isRestDay: true,
          exercises: [],
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Rest Day',
          dayOfWeek: 7,
          isRestDay: true,
          exercises: [],
        ),
      );
    } else if (daysPerWeek == 5) {
      // 5-Day Split
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 1: Chest & Triceps',
          dayOfWeek: 1,
          isRestDay: false,
          exercises: [pushEx[0], pushEx[2], pushEx[3]]
              .map(
                (n) => RoutineExerciseInput(name: n, sets: 4, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 2: Back & Biceps',
          dayOfWeek: 2,
          isRestDay: false,
          exercises: [pullEx[0], pullEx[1], pullEx[2]]
              .map(
                (n) => RoutineExerciseInput(name: n, sets: 4, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 3: Legs & Lower Body',
          dayOfWeek: 3,
          isRestDay: false,
          exercises: legEx
              .map(
                (n) => RoutineExerciseInput(name: n, sets: 4, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 4: Shoulders & Arms',
          dayOfWeek: 4,
          isRestDay: false,
          exercises: [pushEx[1], pullEx[2], pushEx[3]]
              .map(
                (n) => RoutineExerciseInput(name: n, sets: 4, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Day 5: Full Body Conditioning',
          dayOfWeek: 5,
          isRestDay: false,
          exercises: [pushEx[0], pullEx[0], legEx[0]]
              .map(
                (n) => RoutineExerciseInput(name: n, sets: 3, repsRange: reps),
              )
              .toList(),
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Rest Day',
          dayOfWeek: 6,
          isRestDay: true,
          exercises: [],
        ),
      );
      days.add(
        RoutineDayWithExercises(
          dayName: 'Rest Day',
          dayOfWeek: 7,
          isRestDay: true,
          exercises: [],
        ),
      );
    } else {
      // 6-Day Push / Pull / Legs x 2
      for (int day = 1; day <= 6; day++) {
        final isPush = day == 1 || day == 4;
        final isPull = day == 2 || day == 5;
        final exList = isPush ? pushEx : (isPull ? pullEx : legEx);
        final title = isPush ? 'Push' : (isPull ? 'Pull' : 'Legs');
        days.add(
          RoutineDayWithExercises(
            dayName: 'Day $day: $title',
            dayOfWeek: day,
            isRestDay: false,
            exercises: exList
                .map(
                  (n) =>
                      RoutineExerciseInput(name: n, sets: 3, repsRange: reps),
                )
                .toList(),
          ),
        );
      }
      days.add(
        RoutineDayWithExercises(
          dayName: 'Rest Day',
          dayOfWeek: 7,
          isRestDay: true,
          exercises: [],
        ),
      );
    }

    return GeneratedRoutineResult(
      name: routineName,
      goal: goal,
      notes: notes,
      days: days,
    );
  }
}
