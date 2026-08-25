import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_muscle_volume_models.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/progress/progress_dashboard_controller.dart';
import 'package:indifit/features/progress/progress_dashboard_models.dart';
import 'package:indifit/features/progress/progress_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // R07F-0: Outfit is bundled; no runtime font fetching configuration.

  test(
    'a canonical weight save refreshes the production Progress snapshot',
    () async {
      SharedPreferences.setMockInitialValues({});
      final database = AppDatabase.memory();
      final dates = LocalScheduleDateService();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          localScheduleDateServiceProvider.overrideWithValue(dates),
          localTimezoneServiceProvider.overrideWithValue(
            LocalTimezoneService(read: () async => 'UTC', dates: dates),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      final snapshot = await container
          .read(progressDashboardSnapshotProvider.future)
          .timeout(const Duration(seconds: 5));

      expect(snapshot.hasKnownZeroData, isTrue);

      await container
          .read(workoutRepositoryProvider)
          .logWeightAndSyncProfile(weight: 80);
      container.invalidate(progressDashboardSnapshotProvider);
      final refreshed = await container
          .read(progressDashboardSnapshotProvider.future)
          .timeout(const Duration(seconds: 5));

      expect(refreshed.weightMeasurements, hasLength(1));
      expect(refreshed.weightMeasurements.single.weightKg, 80);
    },
  );

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
      matchesGoldenFile('goldens/ux_r05_progress_zero_dark.png'),
    );
  });

  testWidgets('a zero-valued measurement is not presented as body progress', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(
      tester,
      _snapshot(measurements: [_measurement('2026-08-09', 0)]),
      AppTheme.darkTheme,
    );

    expect(find.text('Your progress starts here'), findsOneWidget);
    expect(find.text('0.0 kg'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a secondary analytics failure keeps a known empty start useful',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pump(
        tester,
        _snapshot(unavailable: const {ProgressDataSection.muscleBalance}),
        AppTheme.darkTheme,
      );

      expect(find.text('Your progress starts here'), findsOneWidget);
      expect(find.text('Some progress details are unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a missing primary history without facts offers one safe retry', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(
      tester,
      _snapshot(
        measurements: null,
        unavailable: const {ProgressDataSection.measurements},
      ),
      AppTheme.darkTheme,
    );

    expect(find.text('Couldn’t load your progress'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one weigh-in stays summary-only golden', (tester) async {
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
      matchesGoldenFile('goldens/ux_r05_progress_one_measurement_dark.png'),
    );
  });

  testWidgets('two weigh-ins show a comparison, not a stable trend', (
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

  testWidgets('same-day duplicate weigh-ins never become a trend chart', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _sameDayMeasurements(), AppTheme.darkTheme);

    expect(find.text('Multiple weigh-ins recorded on Aug 9'), findsWidgets);
    expect(
      find.text(
        'Multiple weigh-ins were recorded on one day. Log a measurement on another day to start seeing a trend.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('progress_weight_chart')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same-day duplicates plus one other day remain a two-day comparison',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pump(
        tester,
        _snapshot(
          measurements: [
            _measurement('2026-08-01', 82, id: 1, hour: 8),
            _measurement('2026-08-01', 81.8, id: 2, hour: 20),
            _measurement('2026-08-09', 81.6, id: 3),
          ],
        ),
        AppTheme.darkTheme,
      );

      expect(find.text('81.8 kg → 81.6 kg'), findsWidgets);
      expect(
        find.text(
          'Two measurements recorded. Add another to see a fuller trend.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('progress_weight_chart')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a crossed loss goal is not presented as ongoing success', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(
      tester,
      _snapshot(
        measurements: [
          _measurement('2026-08-01', 82),
          _measurement('2026-08-05', 80),
          _measurement('2026-08-09', 77),
        ],
        goal: const ProgressWeightGoal(
          targetKg: 78,
          direction: ProgressWeightGoalDirection.loss,
        ),
      ),
      AppTheme.darkTheme,
    );

    expect(find.text('1.0 kg below your goal'), findsOneWidget);
    expect(find.text('Moving closer to your goal'), findsNothing);
    final overviewWeight = find.text('77.0 kg').first;
    expect(
      tester.widget<Text>(overviewWeight).style?.color,
      isNot(equals(B05SemanticColors.dark.success.indicator)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an intermediate overshoot also stays neutral', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(
      tester,
      _snapshot(
        measurements: [
          _measurement('2026-08-01', 82),
          _measurement('2026-08-05', 77),
          _measurement('2026-08-09', 79),
        ],
        goal: const ProgressWeightGoal(
          targetKg: 78,
          direction: ProgressWeightGoalDirection.loss,
        ),
      ),
      AppTheme.darkTheme,
    );

    expect(find.text('1.0 kg to go'), findsOneWidget);
    expect(find.text('Moving closer to your goal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fresh Start workout opens the canonical Training destination', (
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
              const Scaffold(body: Center(child: Text('Training destination'))),
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

    expect(find.text('Training destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('populated overview ${brightness.name} golden', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pump(
        tester,
        _populated(),
        brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
      );

      expect(find.text('Highlights'), findsOneWidget);
      expect(find.text('Training consistency'), findsOneWidget);
      expect(find.text('Strength'), findsWidgets);
      expect(find.text('Training volume'), findsOneWidget);
      expect(find.text('Recent training emphasis'), findsOneWidget);
      expect(find.text('Moving closer to your goal'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ProgressScreen),
        matchesGoldenFile(
          'goldens/ux_r05_progress_populated_${brightness.name}.png',
        ),
      );
    });
  }

  testWidgets('weight chart has a coherent period switch and inspection', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _populated(), AppTheme.darkTheme);

    final chart = find.byKey(const ValueKey('progress_weight_chart'));
    await tester.ensureVisible(chart);
    expect(chart, findsOneWidget);
    expect(
      tester
          .widget<LineChart>(
            find.descendant(of: chart, matching: find.byType(LineChart)),
          )
          .duration,
      Duration.zero,
      reason: 'The chart must respect the active reduced-motion preference.',
    );
    expect(
      find.text('All'),
      findsNothing,
      reason:
          'Do not offer a redundant all-time range for a two-month history.',
    );
    await tester.ensureVisible(find.text('3M'));
    await tester.tap(find.text('3M'));
    await tester.pump();
    await tester.ensureVisible(chart);
    await tester.drag(chart, const Offset(-120, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(
      chart,
      matchesGoldenFile('goldens/ux_r05_weight_chart_dark.png'),
    );
  });

  testWidgets('weight chart preserves local-day spacing between observations', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(
      tester,
      _snapshot(
        measurements: [
          _measurement('2026-08-01', 82),
          _measurement('2026-08-02', 81.8),
          _measurement('2026-08-09', 81.6),
        ],
      ),
      AppTheme.darkTheme,
    );

    final chart = find.byKey(const ValueKey('progress_weight_chart'));
    await tester.ensureVisible(chart);
    final lineChart = tester.widget<LineChart>(
      find.descendant(of: chart, matching: find.byType(LineChart)),
    );

    expect(lineChart.data.lineBarsData.single.spots.map((spot) => spot.x), [
      0.0,
      1.0,
      8.0,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-time range appears only when it adds older history', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _longWeightHistory(), AppTheme.darkTheme);

    final allRange = find.text('All');
    await tester.ensureVisible(allRange);
    expect(find.text('All'), findsOneWidget);
    await tester.tap(allRange);
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('progress_weight_chart')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('strength state is based on performed values', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _strengthOnly(), AppTheme.darkTheme);

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('90 kg × 5'), findsWidgets);
    expect(
      find.textContaining('+7.5 kg at 5 reps vs previous session'),
      findsWidgets,
    );
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r05_progress_strength_dark.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'body measurements show recorded fields and open compact history',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pump(tester, _bodyMeasurementOnly(), AppTheme.darkTheme);

      await tester.ensureVisible(find.text('Measurements').last);
      expect(find.text('Weight'), findsNothing);
      expect(find.text('Waist'), findsOneWidget);
      expect(find.text('80 cm'), findsWidgets);
      expect(find.text('2 cm lower than Jul 10'), findsOneWidget);
      expect(find.text('Chest'), findsOneWidget);
      await tester.tap(find.text('View history'));
      await tester.pumpAndSettle();
      expect(find.text('Measurement history'), findsOneWidget);
      expect(find.text('Waist 80 cm'), findsOneWidget);
      expect(find.text('Chest 100 cm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('older workout history does not become a bare zero this week', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(
      tester,
      _snapshot(workouts: [_workout('2026-06-10', 'Gym session', 0)]),
      AppTheme.darkTheme,
    );

    expect(find.text('No workouts this week'), findsOneWidget);
    expect(find.text('No workouts yet'), findsNothing);
    expect(find.text('Weight'), findsNothing);
    expect(find.text('0 workouts'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Progress is usable at 320pt', (tester) async {
    _setViewport(tester, const Size(320, 568));
    await _pump(tester, _populated(), AppTheme.darkTheme);

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r05_progress_320_dark.png'),
    );
  });

  testWidgets('Progress remains usable at 2x text', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await _pump(tester, _oneMeasurement(), AppTheme.darkTheme, textScale: 2);

    expect(
      find.text('Log another measurement to start seeing your trend.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProgressScreen),
      matchesGoldenFile('goldens/ux_r05_progress_2x_dark.png'),
    );
  });

  testWidgets('Progress has no layout exceptions across the phone matrix', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    const sizes = [Size(320, 568), Size(390, 844), Size(430, 932)];
    for (final size in sizes) {
      for (final textScale in [1.0, 1.5, 2.0]) {
        for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          await _pump(tester, _responsiveData(), theme, textScale: textScale);
          expect(
            tester.takeException(),
            isNull,
            reason: '${size.width}x${size.height} at ${textScale}x text',
          );
        }
      }
    }
  });

  testWidgets(
    'mixed data keeps available sections when a secondary read fails',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pump(tester, _mixedData(), AppTheme.lightTheme);

      expect(find.text('Weight'), findsWidgets);
      expect(find.text('Training consistency'), findsNothing);
      expect(
        find.text('Some progress details are unavailable'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ProgressScreen),
        matchesGoldenFile('goldens/ux_r05_progress_mixed_light.png'),
      );
    },
  );

  testWidgets('chart and metric have useful nonvisual summaries', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final handle = tester.ensureSemantics();
    await _pump(tester, _populated(), AppTheme.darkTheme);

    expect(
      find.bySemanticsLabel(
        'Weight: 82.0 kg. 0.8 kg lower than 28 days ago. Goal 78.0 kg, 4.0 kg to go.',
      ),
      findsWidgets,
    );
    expect(find.bySemanticsLabel('Weight chart time range'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}

Future<void> _pump(
  WidgetTester tester,
  ProgressDashboardSnapshot snapshot,
  ThemeData theme, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData.fromView(tester.view).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: ProgressScreen(preview: snapshot),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

ProgressDashboardSnapshot _zeroData() => _snapshot();

ProgressDashboardSnapshot _oneMeasurement() => _snapshot(
  measurements: [_measurement('2026-08-09', 82)],
  goal: const ProgressWeightGoal(
    targetKg: 78,
    direction: ProgressWeightGoalDirection.loss,
  ),
);

ProgressDashboardSnapshot _twoMeasurements() => _snapshot(
  measurements: [
    _measurement('2026-07-26', 82),
    _measurement('2026-08-09', 81.6),
  ],
);

ProgressDashboardSnapshot _sameDayMeasurements() => _snapshot(
  measurements: [
    _measurement('2026-08-09', 82),
    _measurement('2026-08-09', 81.8),
    _measurement('2026-08-09', 81.7),
  ],
);

ProgressDashboardSnapshot _populated() => _snapshot(
  measurements: [
    _measurement('2026-06-12', 83.5),
    _measurement('2026-06-28', 83.0),
    _measurement('2026-07-12', 82.8),
    _measurement('2026-07-28', 82.4),
    _measurement('2026-08-09', 82.0, waist: 82, chest: 101),
  ],
  workouts: [
    _workout('2026-08-08', 'Push day', 8200),
    _workout('2026-08-06', 'Pull day', 7600),
    _workout('2026-08-03', 'Lower body', 10500),
    _workout('2026-07-29', 'Push day', 7800),
    _workout('2026-07-24', 'Pull day', 7200),
  ],
  strengthSets: [
    _strength('2026-06-14', 82.5, 5),
    _strength('2026-07-13', 87.5, 5),
    _strength('2026-08-08', 90, 5),
    _strength('2026-08-08', 92.5, 3),
  ],
  muscle: _muscleModel(),
  goal: const ProgressWeightGoal(
    targetKg: 78,
    direction: ProgressWeightGoalDirection.loss,
  ),
);

ProgressDashboardSnapshot _strengthOnly() => _snapshot(
  strengthSets: [
    _strength('2026-06-14', 82.5, 5),
    _strength('2026-08-08', 90, 5),
  ],
);

ProgressDashboardSnapshot _bodyMeasurementOnly() => _snapshot(
  measurements: [
    _bodyMeasurement('2026-07-10', waist: 82, chest: 100),
    _bodyMeasurement('2026-08-09', waist: 80),
  ],
);

ProgressDashboardSnapshot _longWeightHistory() => _snapshot(
  measurements: [
    _measurement('2025-07-10', 86),
    _measurement('2026-07-12', 82.8),
    _measurement('2026-08-09', 82),
  ],
);

ProgressDashboardSnapshot _mixedData() => _snapshot(
  measurements: [
    _measurement('2026-07-12', 81.4),
    _measurement('2026-07-28', 81.0),
    _measurement('2026-08-09', 80.8),
  ],
  unavailable: const {ProgressDataSection.strength},
);

ProgressDashboardSnapshot _responsiveData() => _snapshot(
  measurements: [
    _measurement('2026-07-12', 82.8),
    _measurement('2026-07-28', 82.4),
    _measurement('2026-08-09', 82.0),
  ],
  workouts: [
    _workout('2026-08-08', 'Upper body', 8200),
    _workout('2026-08-06', 'Lower body', 7600),
  ],
  strengthSets: [
    _strength(
      '2026-06-14',
      20,
      8,
      exerciseName: 'Bulgarian Split Squat With Dumbbells',
      exerciseId: 'bulgarian-split-squat',
    ),
    _strength(
      '2026-08-08',
      25,
      8,
      exerciseName: 'Bulgarian Split Squat With Dumbbells',
      exerciseId: 'bulgarian-split-squat',
    ),
  ],
  goal: const ProgressWeightGoal(
    targetKg: 78,
    direction: ProgressWeightGoalDirection.loss,
  ),
);

ProgressDashboardSnapshot _snapshot({
  List<ProgressMeasurementRecord>? measurements = const [],
  List<ProgressWorkoutRecord>? workouts = const [],
  List<ProgressStrengthSetRecord>? strengthSets = const [],
  B02MuscleVolumeReadModel? muscle,
  Set<ProgressDataSection> unavailable = const {},
  ProgressWeightGoal? goal,
}) {
  return ProgressDashboardSnapshot(
    nowUtc: DateTime.utc(2026, 8, 9, 12),
    timezoneId: 'Asia/Kolkata',
    todayLocalDate: '2026-08-09',
    measurements: measurements,
    workouts: workouts,
    strengthSets: strengthSets,
    muscleBalance: muscle,
    unavailableSections: unavailable,
    weightGoal: goal,
  );
}

ProgressMeasurementRecord _measurement(
  String localDate,
  double weight, {
  int? id,
  int hour = 8,
  double? waist,
  double? chest,
}) {
  final parts = localDate.split('-').map(int.parse).toList();
  return ProgressMeasurementRecord(
    id: id ?? parts.last,
    recordedAt: DateTime(parts[0], parts[1], parts[2], hour),
    localDate: localDate,
    weightKg: weight,
    waistCm: waist,
    chestCm: chest,
  );
}

ProgressMeasurementRecord _bodyMeasurement(
  String localDate, {
  double? waist,
  double? chest,
  double? arms,
}) {
  final parts = localDate.split('-').map(int.parse).toList();
  return ProgressMeasurementRecord(
    id: parts.last,
    recordedAt: DateTime(parts[0], parts[1], parts[2], 8),
    localDate: localDate,
    waistCm: waist,
    chestCm: chest,
    armsCm: arms,
  );
}

ProgressWorkoutRecord _workout(String localDate, String name, double volume) =>
    ProgressWorkoutRecord(
      id: localDate.hashCode,
      name: name,
      completedAtUtc: DateTime.parse('${localDate}T12:00:00Z'),
      localDate: localDate,
      activityType: 'strength',
      totalVolumeKg: volume,
    );

ProgressStrengthSetRecord _strength(
  String localDate,
  double load,
  int reps, {
  String exerciseName = 'Bench Press',
  String exerciseId = 'bench-press',
}) => ProgressStrengthSetRecord(
  performedSetId: '$localDate-$exerciseId-$load-$reps',
  exerciseId: exerciseId,
  exerciseName: exerciseName,
  completedAtUtc: DateTime.parse('${localDate}T12:00:00Z'),
  localDate: localDate,
  loadKg: load,
  reps: reps,
  loadBasis: 'totalExternal',
);

B02MuscleVolumeReadModel _muscleModel() => B02MuscleVolumeReadModel(
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
      workingSetUnits: 10,
      effectiveSetUnits: 10,
      effectiveEvidenceUnits: 10,
    ),
    B02MuscleVolumeCell(
      muscleId: 'back',
      displayName: 'Back',
      region: 'torso',
      catalogVersion: 1,
      workingSetUnits: 8,
      effectiveSetUnits: 8,
      effectiveEvidenceUnits: 8,
    ),
  ],
  unknown: const B02MuscleVolumeUnknown(
    workingSetUnits: 0,
    effectiveSetUnits: 0,
    effectiveEvidenceUnits: 0,
    workingSetCount: 0,
  ),
  totalWorkingSetCount: 18,
  mappedWorkingSetCount: 18,
  mappedWorkingSetUnits: 18,
  mappedEffectiveSetUnits: 18,
  totalEffectiveEvidenceUnits: 18,
);
