import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/models/progress_dashboard_models.dart';
import 'package:indifit/features/progress/progress_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('highlights are compact, dynamic, and factual', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _populated(), AppTheme.darkTheme);

    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    final training = find.byKey(const ValueKey('progress_highlight_training'));
    final strength = find.byKey(const ValueKey('progress_highlight_strength'));
    expect(training, findsOneWidget);
    expect(strength, findsOneWidget);
    expect(
      find.descendant(of: training, matching: find.text('3 training days')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: training,
        matching: find.text('3 workouts this week'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strength, matching: find.text('2 sessions')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: strength,
        matching: find.textContaining('Bench Press'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('progress_highlight_weight')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('progress_highlight_nutrition')),
      findsNothing,
    );
    final highlightTiles = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('progress_highlight_');
    });
    expect(highlightTiles, findsNWidgets(2));
    expect(find.textContaining('e1RM'), findsNothing);
    expect(find.textContaining('readiness'), findsNothing);
    expect(find.textContaining('calories burned'), findsNothing);
    expect(find.textContaining('PR'), findsNothing);
    expect(tester.takeException(), isNull);

    for (final label in ['training', 'strength']) {
      final tile = find.byKey(ValueKey('progress_highlight_$label'));
      expect(
        find.descendant(of: tile, matching: find.byType(InkWell)),
        findsOneWidget,
      );
    }
  });

  testWidgets('missing domains stay hidden while known weight remains useful', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(
      tester,
      ProgressDashboardSnapshot(
        nowUtc: DateTime.utc(2026, 8, 9, 12),
        timezoneId: 'UTC',
        todayLocalDate: '2026-08-09',
        measurements: [
          ProgressMeasurementRecord(
            id: 1,
            recordedAt: DateTime.utc(2026, 8, 9, 8),
            localDate: '2026-08-09',
            weightKg: 82,
          ),
        ],
        workouts: null,
        strengthSets: null,
        muscleBalance: null,
        unavailableSections: {
          ProgressDataSection.workouts,
          ProgressDataSection.strength,
        },
      ),
      AppTheme.lightTheme,
    );

    expect(find.text('Highlights'), findsNothing);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Training'), findsNothing);
    expect(find.text('Strength'), findsNothing);
    expect(find.text('Nutrition'), findsNothing);
    expect(find.text('Some progress details are unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('known training without sets keeps the strength state compact', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(
      tester,
      ProgressDashboardSnapshot(
        nowUtc: DateTime.utc(2026, 8, 9, 12),
        timezoneId: 'UTC',
        todayLocalDate: '2026-08-09',
        measurements: const [],
        workouts: [
          ProgressWorkoutRecord(
            id: 1,
            name: 'Strength session',
            completedAtUtc: DateTime.utc(2026, 8, 8, 8),
            localDate: '2026-08-08',
            activityType: 'strength',
            totalVolumeKg: 0,
          ),
        ],
        strengthSets: const [],
        muscleBalance: null,
        unavailableSections: const {},
      ),
      AppTheme.lightTheme,
    );

    expect(
      find.text('Your logged working sets will appear here after you train.'),
      findsOneWidget,
    );
    expect(find.byType(LineChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('known empty Progress keeps the focused starting state', (
    tester,
  ) async {
    _setViewport(tester, const Size(320, 568));
    await _pump(tester, _empty(), AppTheme.lightTheme, textScale: 2);

    expect(find.text('Your progress starts here'), findsOneWidget);
    expect(find.text('Highlights'), findsNothing);
    expect(find.textContaining('0 workouts'), findsNothing);
    expect(find.textContaining('e1RM'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  ProgressDashboardSnapshot snapshot,
  ThemeData theme, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: const Size(390, 844),
        ),
        child: ProgressScreen(preview: snapshot),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProgressDashboardSnapshot _empty() => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 9, 12),
  timezoneId: 'UTC',
  todayLocalDate: '2026-08-09',
  measurements: const [],
  workouts: const [],
  strengthSets: const [],
  muscleBalance: null,
  unavailableSections: const {},
);

ProgressDashboardSnapshot _populated() => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 9, 12),
  timezoneId: 'UTC',
  todayLocalDate: '2026-08-09',
  measurements: [
    ProgressMeasurementRecord(
      id: 1,
      recordedAt: DateTime.utc(2026, 8, 1, 8),
      localDate: '2026-08-01',
      weightKg: 82,
    ),
    ProgressMeasurementRecord(
      id: 2,
      recordedAt: DateTime.utc(2026, 8, 9, 8),
      localDate: '2026-08-09',
      weightKg: 80.8,
    ),
  ],
  workouts: [
    ProgressWorkoutRecord(
      id: 1,
      name: 'Push day',
      completedAtUtc: DateTime.utc(2026, 8, 3, 9),
      localDate: '2026-08-03',
      activityType: 'strength',
      totalVolumeKg: 0,
    ),
    ProgressWorkoutRecord(
      id: 2,
      name: 'Pull day',
      completedAtUtc: DateTime.utc(2026, 8, 5, 9),
      localDate: '2026-08-05',
      activityType: 'strength',
      totalVolumeKg: 0,
    ),
    ProgressWorkoutRecord(
      id: 3,
      name: 'Leg day',
      completedAtUtc: DateTime.utc(2026, 8, 7, 9),
      localDate: '2026-08-07',
      activityType: 'strength',
      totalVolumeKg: 0,
    ),
  ],
  strengthSets: [
    ProgressStrengthSetRecord(
      performedSetId: 'set-1',
      exerciseId: 'bench',
      exerciseName: 'Bench Press',
      completedAtUtc: DateTime.utc(2026, 8, 1, 9),
      localDate: '2026-08-01',
      loadKg: 80,
      reps: 5,
      loadBasis: 'totalExternal',
    ),
    ProgressStrengthSetRecord(
      performedSetId: 'set-2',
      exerciseId: 'bench',
      exerciseName: 'Bench Press',
      completedAtUtc: DateTime.utc(2026, 8, 8, 9),
      localDate: '2026-08-08',
      loadKg: 90,
      reps: 5,
      loadBasis: 'totalExternal',
    ),
  ],
  muscleBalance: null,
  unavailableSections: const {},
  nutritionSummary: const ProgressNutritionSummary(
    days: [
      ProgressNutritionDaySummary(
        localDate: '2026-08-08',
        dayLabel: 'Sat',
        isToday: false,
        caloriesKcal: 2100,
        calorieTargetKcal: 2200,
        proteinG: 140,
        proteinTargetG: 140,
        hasFoodLog: true,
        isProteinTargetMet: true,
        isNutrientIncomplete: false,
      ),
    ],
    loggedDaysCount: 1,
    calorieEvidenceDaysCount: 1,
    proteinEvidenceDaysCount: 1,
    proteinTargetMetDaysCount: 1,
    averageCaloriesKcal: 2100,
    averageProteinG: 140,
    targetCaloriesKcal: 2200,
    targetProteinG: 140,
    hasTarget: true,
  ),
);
