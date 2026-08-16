import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_muscle_volume_models.dart';
import 'package:indifit/data/models/progress_dashboard_models.dart';
import 'package:indifit/data/repositories/b02_execution_compatibility_read_repository.dart';
import 'package:indifit/features/progress/achievements_screen.dart';
import 'package:indifit/features/progress/progress_screen.dart';
import 'package:indifit/features/training/workout_history_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // R07F-0: Outfit is bundled; no runtime font fetching configuration.

  testWidgets('zero-data Progress is one useful starting state dark golden', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _zeroData(), AppTheme.darkTheme);

    expect(find.text('Your progress starts here'), findsOneWidget);
    expect(
      find.text(
        'Complete a workout or log a weigh-in to start seeing useful trends.',
      ),
      findsOneWidget,
    );
    expect(find.text('Log weight'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
    expect(find.textContaining('0 workouts'), findsNothing);
    expect(find.byKey(const ValueKey('progress_weight_chart')), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r07e_progress_zero_dark.png'),
    );
  });

  testWidgets('zero-data Progress light golden', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _zeroData(), AppTheme.lightTheme);

    expect(find.text('Your progress starts here'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r07e_progress_zero_light.png'),
    );
  });

  testWidgets('one weigh-in stays summary-only dark golden', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _oneMeasurement(), AppTheme.darkTheme);

    expect(find.text('82.0 kg'), findsWidgets);
    expect(find.text('Goal 78.0 kg'), findsOneWidget);
    expect(
      find.text('Log another measurement to start seeing your trend.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('progress_weight_chart')), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r07e_progress_one_measurement_dark.png'),
    );
  });

  testWidgets('two weigh-ins show a comparison not a stable trend', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _twoMeasurements(), AppTheme.darkTheme);

    expect(find.text('82.0 kg → 81.6 kg'), findsWidgets);
    expect(
      find.text(
        'Two measurements recorded. Add another to see a fuller trend.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('progress_weight_chart')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'three or more weigh-ins render interactive line chart dark golden',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pump(tester, _weightTrendOnly(), AppTheme.darkTheme);

      final chart = find.byKey(const ValueKey('progress_weight_chart'));
      await tester.ensureVisible(chart);
      expect(chart, findsOneWidget);
      expect(find.text('Goal 78.0 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ProgressScreen),
        matchesGoldenFile('goldens/ux_r07e_progress_weight_chart_dark.png'),
      );
    },
  );

  testWidgets('training consistency section renders week strip dark golden', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(
      tester,
      _trainingOnly(),
      AppTheme.darkTheme,
      overrides: [
        workoutHistoryItemsProvider.overrideWith(
          (ref) async => [
            B02ActivityHistoryItem(
              sessionId: 1,
              name: 'Push Day',
              activityType: B02ActivityType.strength,
              recordKind: B02HistoryRecordKind.canonical,
              completedAt: DateTime.utc(2026, 8, 3, 9),
              durationSeconds: 2700,
              scheduledOccurrenceId: null,
              legacySetCount: 0,
              performedExerciseCount: 2,
              performedGroupCount: 0,
              cardioIntervalCount: 0,
              hasCardioDetail: false,
              hasMobilityDetail: false,
            ),
            B02ActivityHistoryItem(
              sessionId: 3,
              name: 'Leg Day',
              activityType: B02ActivityType.strength,
              recordKind: B02HistoryRecordKind.canonical,
              completedAt: DateTime.utc(2026, 8, 7, 9),
              durationSeconds: 3300,
              scheduledOccurrenceId: null,
              legacySetCount: 0,
              performedExerciseCount: 3,
              performedGroupCount: 0,
              cardioIntervalCount: 0,
              hasCardioDetail: false,
              hasMobilityDetail: false,
            ),
          ],
        ),
      ],
    );

    expect(find.text('Training consistency'), findsOneWidget);
    expect(find.text('3 workouts'), findsOneWidget);
    expect(find.text('completed this week'), findsOneWidget);
    expect(find.text('View workout history'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r07e_progress_training_dark.png'),
    );

    // Tap View workout history
    await tester.tap(find.text('View workout history'));
    await tester.pumpAndSettle();
    expect(find.text('Workout history'), findsOneWidget);
    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Leg Day'), findsOneWidget);
  });

  testWidgets(
    'strength progress section shows performed load and history dark golden',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pump(tester, _strengthOnly(), AppTheme.darkTheme);

      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('Bench Press'), findsWidgets);
      expect(find.text('90 kg × 5'), findsWidgets);
      expect(find.textContaining('e1RM'), findsNothing);
      expect(find.textContaining('vs previous session'), findsWidgets);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ProgressScreen),
        matchesGoldenFile('goldens/ux_r07e_progress_strength_dark.png'),
      );
    },
  );

  testWidgets('nutrition adherence section renders week strip dark golden', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _nutritionOnly(), AppTheme.darkTheme);

    expect(find.text('Nutrition adherence'), findsOneWidget);
    expect(find.text('2,150 kcal'), findsWidgets);
    expect(find.text('4 of 5 complete days met protein'), findsWidgets);
    expect(
      find.text('Avg protein: 142 / 140 g across 5 complete days'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r07e_progress_nutrition_dark.png'),
    );
  });

  testWidgets('populated overview dark golden', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _populated(), AppTheme.darkTheme);

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Training consistency'), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Nutrition adherence'), findsOneWidget);
    expect(find.text('Training volume'), findsOneWidget);
    expect(find.text('Recent training emphasis'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r07e_progress_populated_dark.png'),
    );
  });

  testWidgets('populated overview light golden', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _populated(), AppTheme.lightTheme);

    expect(find.text('Overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r07e_progress_populated_light.png'),
    );
  });

  testWidgets('Progress is usable at 320pt dark golden', (tester) async {
    _setViewport(tester, const Size(320, 568));
    await _pump(tester, _populated(), AppTheme.darkTheme);

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r07e_progress_320_dark.png'),
    );
  });

  testWidgets('Progress remains usable at 2x text dark golden', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _populated(), AppTheme.darkTheme, textScale: 2.0);

    expect(find.text('Overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r07e_progress_2x_dark.png'),
    );
  });

  testWidgets('popup menu opens Achievements screen', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _populated(), AppTheme.darkTheme);

    await tester.tap(find.byTooltip('More progress options'));
    await tester.pumpAndSettle();
    expect(find.text('Achievements'), findsOneWidget);
    await tester.tap(find.text('Achievements'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AchievementsScreen), findsOneWidget);
  });

  testWidgets('Start workout button opens /training destination', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final router = GoRouter(
      initialLocation: '/progress',
      routes: [
        GoRoute(
          path: '/progress',
          builder: (_, _) => ProgressScreen(preview: _zeroData()),
        ),
        GoRoute(
          path: '/training',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('Training Tab'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    expect(find.text('Training Tab'), findsOneWidget);
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  ProgressDashboardSnapshot snapshot,
  ThemeData theme, {
  double textScale = 1.0,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
            size: const Size(390, 844),
          ),
          child: ProgressScreen(preview: snapshot),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProgressDashboardSnapshot _zeroData() => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 9, 12),
  timezoneId: 'Asia/Kolkata',
  todayLocalDate: '2026-08-09',
  measurements: const [],
  workouts: const [],
  strengthSets: const [],
  muscleBalance: _emptyMuscleModel(),
  unavailableSections: const {},
);

ProgressDashboardSnapshot _oneMeasurement() => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 9, 12),
  timezoneId: 'Asia/Kolkata',
  todayLocalDate: '2026-08-09',
  measurements: [_measurement('2026-08-09', 82.0)],
  workouts: const [],
  strengthSets: const [],
  muscleBalance: _emptyMuscleModel(),
  unavailableSections: const {},
  weightGoal: const ProgressWeightGoal(
    targetKg: 78.0,
    direction: ProgressWeightGoalDirection.loss,
  ),
);

ProgressDashboardSnapshot _twoMeasurements() => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 9, 12),
  timezoneId: 'Asia/Kolkata',
  todayLocalDate: '2026-08-09',
  measurements: [
    _measurement('2026-08-01', 82.0),
    _measurement('2026-08-09', 81.6),
  ],
  workouts: const [],
  strengthSets: const [],
  muscleBalance: _emptyMuscleModel(),
  unavailableSections: const {},
  weightGoal: const ProgressWeightGoal(
    targetKg: 78.0,
    direction: ProgressWeightGoalDirection.loss,
  ),
);

ProgressDashboardSnapshot _weightTrendOnly() => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 9, 12),
  timezoneId: 'Asia/Kolkata',
  todayLocalDate: '2026-08-09',
  measurements: [
    _measurement('2026-08-01', 82.0),
    _measurement('2026-08-05', 81.4),
    _measurement('2026-08-09', 80.8),
  ],
  workouts: const [],
  strengthSets: const [],
  muscleBalance: _emptyMuscleModel(),
  unavailableSections: const {},
  weightGoal: const ProgressWeightGoal(
    targetKg: 78.0,
    direction: ProgressWeightGoalDirection.loss,
  ),
);

ProgressDashboardSnapshot _trainingOnly() => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 9, 12),
  timezoneId: 'Asia/Kolkata',
  todayLocalDate: '2026-08-09',
  measurements: const [],
  workouts: [
    _workout(1, 'Push Day', '2026-08-03', volume: 4200, duration: 2700),
    _workout(2, 'Pull Day', '2026-08-05', volume: 4800, duration: 3000),
    _workout(3, 'Leg Day', '2026-08-07', volume: 5500, duration: 3300),
  ],
  weeklyTrainedDates: const {'2026-08-03', '2026-08-05', '2026-08-07'},
  strengthSets: const [],
  muscleBalance: _emptyMuscleModel(),
  unavailableSections: const {},
);

ProgressDashboardSnapshot _strengthOnly() => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 9, 12),
  timezoneId: 'Asia/Kolkata',
  todayLocalDate: '2026-08-09',
  measurements: const [],
  workouts: const [],
  strengthSets: [
    _set('set-1', 'bench', 'Bench Press', '2026-08-01', 80.0, 5),
    _set('set-2', 'bench', 'Bench Press', '2026-08-08', 90.0, 5),
  ],
  strengthExercises: [
    ProgressStrengthExerciseSummary(
      exerciseId: 'bench',
      exerciseName: 'Bench Press',
      latestSet: _set('set-2', 'bench', 'Bench Press', '2026-08-08', 90.0, 5),
      bestSet: _set('set-2', 'bench', 'Bench Press', '2026-08-08', 90.0, 5),
      sessionCount: 2,
      comparisonText: '+10 kg at 5 reps',
      history: [
        _set('set-1', 'bench', 'Bench Press', '2026-08-01', 80.0, 5),
        _set('set-2', 'bench', 'Bench Press', '2026-08-08', 90.0, 5),
      ],
    ),
  ],
  muscleBalance: _emptyMuscleModel(),
  unavailableSections: const {},
);

ProgressDashboardSnapshot _nutritionOnly() => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 9, 12),
  timezoneId: 'Asia/Kolkata',
  todayLocalDate: '2026-08-09',
  measurements: const [],
  workouts: const [],
  strengthSets: const [],
  muscleBalance: _emptyMuscleModel(),
  unavailableSections: const {},
  nutritionSummary: const ProgressNutritionSummary(
    days: [
      ProgressNutritionDaySummary(
        localDate: '2026-08-03',
        dayLabel: 'Mon',
        isToday: false,
        caloriesKcal: 2100,
        calorieTargetKcal: 2200,
        proteinG: 145,
        proteinTargetG: 140,
        hasFoodLog: true,
        isProteinTargetMet: true,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-04',
        dayLabel: 'Tue',
        isToday: false,
        caloriesKcal: 2180,
        calorieTargetKcal: 2200,
        proteinG: 142,
        proteinTargetG: 140,
        hasFoodLog: true,
        isProteinTargetMet: true,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-05',
        dayLabel: 'Wed',
        isToday: false,
        caloriesKcal: 2250,
        calorieTargetKcal: 2200,
        proteinG: 138,
        proteinTargetG: 140,
        hasFoodLog: true,
        isProteinTargetMet: false,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-06',
        dayLabel: 'Thu',
        isToday: false,
        caloriesKcal: 2120,
        calorieTargetKcal: 2200,
        proteinG: 144,
        proteinTargetG: 140,
        hasFoodLog: true,
        isProteinTargetMet: true,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-07',
        dayLabel: 'Fri',
        isToday: false,
        caloriesKcal: 2100,
        calorieTargetKcal: 2200,
        proteinG: 141,
        proteinTargetG: 140,
        hasFoodLog: true,
        isProteinTargetMet: true,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-08',
        dayLabel: 'Sat',
        isToday: false,
        hasFoodLog: false,
        isProteinTargetMet: false,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-09',
        dayLabel: 'Sun',
        isToday: true,
        hasFoodLog: false,
        isProteinTargetMet: false,
        isNutrientIncomplete: false,
      ),
    ],
    loggedDaysCount: 5,
    calorieEvidenceDaysCount: 5,
    proteinEvidenceDaysCount: 5,
    proteinTargetMetDaysCount: 4,
    averageCaloriesKcal: 2150,
    averageProteinG: 142,
    targetCaloriesKcal: 2200,
    targetProteinG: 140,
    hasTarget: true,
  ),
);

ProgressDashboardSnapshot _populated() => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 9, 12),
  timezoneId: 'Asia/Kolkata',
  todayLocalDate: '2026-08-09',
  measurements: [
    _measurement('2026-08-01', 82.0),
    _measurement('2026-08-05', 81.4),
    _measurement('2026-08-09', 80.8),
  ],
  workouts: [
    _workout(1, 'Push Day', '2026-08-03', volume: 4200, duration: 2700),
    _workout(2, 'Pull Day', '2026-08-05', volume: 4800, duration: 3000),
    _workout(3, 'Leg Day', '2026-08-07', volume: 5500, duration: 3300),
  ],
  weeklyTrainedDates: const {'2026-08-03', '2026-08-05', '2026-08-07'},
  strengthSets: [
    _set('set-1', 'bench', 'Bench Press', '2026-08-01', 80.0, 5),
    _set('set-2', 'bench', 'Bench Press', '2026-08-08', 90.0, 5),
  ],
  strengthExercises: [
    ProgressStrengthExerciseSummary(
      exerciseId: 'bench',
      exerciseName: 'Bench Press',
      latestSet: _set('set-2', 'bench', 'Bench Press', '2026-08-08', 90.0, 5),
      bestSet: _set('set-2', 'bench', 'Bench Press', '2026-08-08', 90.0, 5),
      sessionCount: 2,
      comparisonText: '+10 kg at 5 reps',
      history: [
        _set('set-1', 'bench', 'Bench Press', '2026-08-01', 80.0, 5),
        _set('set-2', 'bench', 'Bench Press', '2026-08-08', 90.0, 5),
      ],
    ),
  ],
  muscleBalance: _populatedMuscleModel(),
  unavailableSections: const {},
  weightGoal: const ProgressWeightGoal(
    targetKg: 78.0,
    direction: ProgressWeightGoalDirection.loss,
  ),
  nutritionSummary: const ProgressNutritionSummary(
    days: [
      ProgressNutritionDaySummary(
        localDate: '2026-08-03',
        dayLabel: 'Mon',
        isToday: false,
        caloriesKcal: 2100,
        calorieTargetKcal: 2200,
        proteinG: 145,
        proteinTargetG: 140,
        hasFoodLog: true,
        isProteinTargetMet: true,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-04',
        dayLabel: 'Tue',
        isToday: false,
        caloriesKcal: 2180,
        calorieTargetKcal: 2200,
        proteinG: 142,
        proteinTargetG: 140,
        hasFoodLog: true,
        isProteinTargetMet: true,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-05',
        dayLabel: 'Wed',
        isToday: false,
        caloriesKcal: 2250,
        calorieTargetKcal: 2200,
        proteinG: 138,
        proteinTargetG: 140,
        hasFoodLog: true,
        isProteinTargetMet: false,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-06',
        dayLabel: 'Thu',
        isToday: false,
        caloriesKcal: 2120,
        calorieTargetKcal: 2200,
        proteinG: 144,
        proteinTargetG: 140,
        hasFoodLog: true,
        isProteinTargetMet: true,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-07',
        dayLabel: 'Fri',
        isToday: false,
        caloriesKcal: 2100,
        calorieTargetKcal: 2200,
        proteinG: 141,
        proteinTargetG: 140,
        hasFoodLog: true,
        isProteinTargetMet: true,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-08',
        dayLabel: 'Sat',
        isToday: false,
        hasFoodLog: false,
        isProteinTargetMet: false,
        isNutrientIncomplete: false,
      ),
      ProgressNutritionDaySummary(
        localDate: '2026-08-09',
        dayLabel: 'Sun',
        isToday: true,
        hasFoodLog: false,
        isProteinTargetMet: false,
        isNutrientIncomplete: false,
      ),
    ],
    loggedDaysCount: 5,
    calorieEvidenceDaysCount: 5,
    proteinEvidenceDaysCount: 5,
    proteinTargetMetDaysCount: 4,
    averageCaloriesKcal: 2150,
    averageProteinG: 142,
    targetCaloriesKcal: 2200,
    targetProteinG: 140,
    hasTarget: true,
  ),
);

ProgressMeasurementRecord _measurement(String localDate, double weight) =>
    ProgressMeasurementRecord(
      id: localDate.hashCode,
      recordedAt: DateTime.parse('${localDate}T08:00:00Z'),
      localDate: localDate,
      weightKg: weight,
    );

ProgressWorkoutRecord _workout(
  int id,
  String name,
  String localDate, {
  double volume = 0,
  int duration = 1800,
}) => ProgressWorkoutRecord(
  id: id,
  name: name,
  completedAtUtc: DateTime.parse('${localDate}T09:00:00Z'),
  localDate: localDate,
  activityType: 'strength',
  totalVolumeKg: volume,
  durationSeconds: duration,
);

ProgressStrengthSetRecord _set(
  String id,
  String exerciseId,
  String name,
  String localDate,
  double loadKg,
  int reps,
) => ProgressStrengthSetRecord(
  performedSetId: id,
  exerciseId: exerciseId,
  exerciseName: name,
  completedAtUtc: DateTime.parse('${localDate}T09:30:00Z'),
  localDate: localDate,
  loadKg: loadKg,
  reps: reps,
  loadBasis: 'totalExternal',
);

B02MuscleVolumeReadModel _emptyMuscleModel() => B02MuscleVolumeReadModel(
  startLocalDate: '2026-07-12',
  endLocalDate: '2026-08-08',
  timezoneId: 'Asia/Kolkata',
  startUtc: DateTime.utc(2026, 7, 11, 18, 30),
  endExclusiveUtc: DateTime.utc(2026, 8, 8, 18, 30),
  muscles: const [],
  unknown: const B02MuscleVolumeUnknown(
    workingSetUnits: 0,
    effectiveSetUnits: 0,
    effectiveEvidenceUnits: 0,
    workingSetCount: 0,
  ),
  totalWorkingSetCount: 0,
  mappedWorkingSetCount: 0,
  mappedWorkingSetUnits: 0,
  mappedEffectiveSetUnits: 0,
  totalEffectiveEvidenceUnits: 0,
);

B02MuscleVolumeReadModel _populatedMuscleModel() => B02MuscleVolumeReadModel(
  startLocalDate: '2026-07-12',
  endLocalDate: '2026-08-08',
  timezoneId: 'Asia/Kolkata',
  startUtc: DateTime.utc(2026, 7, 11, 18, 30),
  endExclusiveUtc: DateTime.utc(2026, 8, 8, 18, 30),
  muscles: const [
    B02MuscleVolumeCell(
      muscleId: 'chest',
      displayName: 'Chest',
      region: 'torso',
      catalogVersion: 1,
      workingSetUnits: 12,
      effectiveSetUnits: 12,
      effectiveEvidenceUnits: 12,
    ),
    B02MuscleVolumeCell(
      muscleId: 'back',
      displayName: 'Back',
      region: 'torso',
      catalogVersion: 1,
      workingSetUnits: 10,
      effectiveSetUnits: 10,
      effectiveEvidenceUnits: 10,
    ),
  ],
  unknown: const B02MuscleVolumeUnknown(
    workingSetUnits: 0,
    effectiveSetUnits: 0,
    effectiveEvidenceUnits: 0,
    workingSetCount: 0,
  ),
  totalWorkingSetCount: 22,
  mappedWorkingSetCount: 22,
  mappedWorkingSetUnits: 22,
  mappedEffectiveSetUnits: 22,
  totalEffectiveEvidenceUnits: 22,
);
