import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/indifit_haptics.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/models/progress_dashboard_models.dart';
import 'package:indifit/features/progress/progress_screen.dart';
import 'package:indifit/features/progress/r08f4_training_volume_presentation.dart';
import 'package:indifit/features/progress/widgets/progress_stat.dart';
import 'package:indifit/features/progress/widgets/weekly_volume_chart.dart';

// Sunday; the current week starts Monday 3 Aug.
const _today = '2026-08-09';

ProgressWorkoutRecord _workout(
  int id,
  String localDate,
  double volumeKg, {
  bool trustworthy = true,
  String activityType = 'strength',
}) {
  final parts = localDate.split('-').map(int.parse).toList();
  return ProgressWorkoutRecord(
    id: id,
    name: 'Workout $id',
    completedAtUtc: DateTime.utc(parts[0], parts[1], parts[2], 6),
    localDate: localDate,
    activityType: activityType,
    totalVolumeKg: volumeKg,
    volumeIsTrustworthy: trustworthy,
  );
}

ProgressDashboardSnapshot _snapshot(List<ProgressWorkoutRecord> workouts) =>
    ProgressDashboardSnapshot(
      nowUtc: DateTime.utc(2026, 8, 9, 12),
      timezoneId: 'Asia/Kolkata',
      todayLocalDate: _today,
      measurements: const [],
      workouts: workouts,
      weeklyTrainedDates: {
        for (final w in workouts)
          if (w.localDate.compareTo('2026-08-03') >= 0) w.localDate,
      },
      strengthSets: const [],
      muscleBalance: null,
      unavailableSections: const {},
    );

Future<void> _pumpProgress(
  WidgetTester tester,
  ProgressDashboardSnapshot snapshot, {
  Size size = const Size(390, 2400),
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: Scaffold(body: ProgressScreen(preview: snapshot)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final workouts = [
    _workout(1, '2026-08-08', 3000),
    _workout(2, '2026-08-04', 1500),
    _workout(3, '2026-07-21', 4000),
    _workout(4, '2026-07-02', 2500),
    // Not counted: unknown load, cardio, before the window.
    _workout(5, '2026-07-22', 9000, trustworthy: false),
    _workout(6, '2026-07-23', 900, activityType: 'cardio'),
    _workout(7, '2026-06-01', 7000),
  ];

  group('V9 weekly volume', () {
    test('buckets eight Monday weeks, keeps empty weeks and skips '
        'untrustworthy, non-strength, old and future workouts', () {
      final weeks = R08F4TrainingVolumePresentation.weeklyVolume(
        allWorkouts: [...workouts, _workout(8, '2026-08-10', 7000)],
        todayLocalDate: _today,
        timezoneId: 'Asia/Kolkata',
        units: 'kg',
      );

      expect(weeks.map((w) => w.weekStartLocalDate), [
        '2026-06-15',
        '2026-06-22',
        '2026-06-29',
        '2026-07-06',
        '2026-07-13',
        '2026-07-20',
        '2026-07-27',
        '2026-08-03',
      ]);
      expect(weeks.map((w) => w.volumeKg), [0, 0, 2500, 0, 0, 4000, 0, 4500]);
      expect(weeks.last.sessionCount, 2);
      expect(weeks.where((w) => w.isCurrentWeek).single, weeks.last);
    });

    test('converts to pounds for display', () {
      final weeks = R08F4TrainingVolumePresentation.weeklyVolume(
        allWorkouts: [_workout(1, '2026-08-08', 1000)],
        todayLocalDate: _today,
        timezoneId: 'Asia/Kolkata',
        units: 'Imperial',
      );
      expect(weeks.last.volumeKg, 1000);
      expect(weeks.last.displayVolume, closeTo(2204.6, 0.1));
    });

    test('needs two weeks with volume to draw a chart', () {
      List<R08F4WeeklyVolume> weeksFor(List<ProgressWorkoutRecord> list) =>
          R08F4TrainingVolumePresentation.weeklyVolume(
            allWorkouts: list,
            todayLocalDate: _today,
            timezoneId: 'Asia/Kolkata',
            units: 'kg',
          );
      expect(WeeklyVolumeChart.canShow(weeksFor(workouts)), isTrue);
      expect(
        WeeklyVolumeChart.canShow(weeksFor([_workout(1, '2026-08-08', 10)])),
        isFalse,
      );
    });

    test('formats the change against the previous four weeks', () {
      R08F4VolumeSummary summary(double current, double? previous) =>
          R08F4VolumeSummary(
            totalVolumeKg: current,
            displayVolume: current,
            unitSymbol: 'kg',
            isImperial: false,
            useRecent: true,
            contributingSessionCount: 1,
            hasTrustworthyVolume: true,
            previousPeriodVolumeKg: previous,
            previousPeriodDisplayVolume: previous,
            previousPeriodContributingSessionCount: previous == null ? 0 : 1,
          );
      String? change(double current, double? previous) =>
          R08F4TrainingVolumePresentation.formatVolumeChangePercent(
            summary(current, previous),
          );

      expect(change(5000, 2000), '+150%');
      expect(change(1500, 2000), '−25%');
      expect(change(2004, 2000), 'Same');
      expect(change(2000, null), isNull);
    });
  });

  group('V9 ProgressStat', () {
    testWidgets('splits a leading number from its unit and keeps the plain '
        'text whole', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                ProgressStat.split('70.0 kg'),
                ProgressStat.split(
                  '3 training days',
                  size: ProgressStatSize.compact,
                ),
                ProgressStat.split('No records'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('70.0 kg'), findsOneWidget);
      expect(find.text('3 training days'), findsOneWidget);
      expect(find.text('No records'), findsOneWidget);

      final rich = tester.widget<Text>(find.text('70.0 kg'));
      final spans = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.map((s) => s.text), ['70.0', ' kg']);
      expect(
        spans.first.style!.fontSize,
        greaterThan(spans.last.style!.fontSize!),
      );
      expect(spans.first.style!.fontFeatures, [
        const FontFeature.tabularFigures(),
      ]);
    });
  });

  group('V9 Progress volume chart', () {
    testWidgets('leads with the four-week total, change chip and the chart '
        'on this week', (tester) async {
      await _pumpProgress(tester, _snapshot(workouts));

      expect(find.text('8,500 kg'), findsOneWidget);
      expect(find.text('Loaded in the last 4 weeks'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('progress_weekly_volume_chart')),
        findsOneWidget,
      );
      expect(find.text('This week · 4,500 kg · 2 workouts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a bar selects that week with a selection haptic', (
      tester,
    ) async {
      final haptics = <IndiFitHapticType>[];
      IndiFitHaptics.debugHandler = haptics.add;
      addTearDown(() => IndiFitHaptics.debugHandler = null);
      await _pumpProgress(tester, _snapshot(workouts));

      await tester.tap(find.byKey(const ValueKey('weekly_volume_bar_5')));
      await tester.pumpAndSettle();
      expect(
        find.text('Week of 20 Jul · 4,000 kg · 1 workout'),
        findsOneWidget,
      );
      expect(haptics, [IndiFitHapticType.selection]);

      await tester.tap(find.byKey(const ValueKey('weekly_volume_bar_4')));
      await tester.pumpAndSettle();
      expect(find.text('Week of 13 Jul · No loaded volume'), findsOneWidget);

      // Tapping the selected bar again does nothing.
      await tester.tap(find.byKey(const ValueKey('weekly_volume_bar_4')));
      await tester.pumpAndSettle();
      expect(haptics, hasLength(2));
    });

    testWidgets('each bar is a labelled, selectable button', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpProgress(tester, _snapshot(workouts));

      expect(
        tester.getSemantics(find.byKey(const ValueKey('weekly_volume_bar_7'))),
        matchesSemantics(
          label: 'This week, 4,500 kilograms, 2 workouts.',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('weekly_volume_bar_0'))),
        matchesSemantics(
          label: 'Week of 15 Jun, no loaded volume.',
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('bars change height without animation under Reduce Motion', (
      tester,
    ) async {
      await _pumpProgress(tester, _snapshot(workouts), reduceMotion: true);
      final bars = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(WeeklyVolumeChart),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(bars, hasLength(8));
      expect(bars.every((bar) => bar.duration == Duration.zero), isTrue);
    });

    testWidgets('hides the chart with only one week of volume', (tester) async {
      await _pumpProgress(tester, _snapshot([_workout(1, '2026-08-08', 3000)]));
      expect(find.text('3,000 kg'), findsOneWidget);
      expect(find.byType(WeeklyVolumeChart), findsNothing);
    });

    testWidgets('fits at 320 pt with 2x text', (tester) async {
      await _pumpProgress(
        tester,
        _snapshot(workouts),
        size: const Size(320, 4000),
        textScale: 2,
      );
      expect(find.byType(WeeklyVolumeChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
