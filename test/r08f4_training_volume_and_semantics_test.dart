import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/progress_dashboard_models.dart';
import 'package:indifit/data/repositories/progress_dashboard_read_repository.dart';
import 'package:indifit/features/progress/progress_screen.dart';
import 'package:indifit/features/progress/r08f4_training_volume_presentation.dart';
import 'package:indifit/features/settings/unit_preference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R08F.4 — Training consistency & session/day semantics', () {
    test('distinguishes multiple sessions on the same local calendar day', () {
      final workouts = [
        ProgressWorkoutRecord(
          id: 1,
          name: 'Morning Upper',
          completedAtUtc: DateTime.utc(2026, 8, 3, 7),
          localDate: '2026-08-03',
          activityType: 'strength',
          totalVolumeKg: 3000,
          workingSetsCount: 6,
        ),
        ProgressWorkoutRecord(
          id: 2,
          name: 'Evening Core',
          completedAtUtc: DateTime.utc(2026, 8, 3, 18),
          localDate: '2026-08-03',
          activityType: 'strength',
          totalVolumeKg: 1000,
          workingSetsCount: 3,
        ),
      ];

      final summary =
          R08F4TrainingVolumePresentation.summarizeConsistency(workouts);

      expect(summary.sessionCount, 2);
      expect(summary.trainingDayCount, 1);
      expect(summary.hasMultipleSessionsOnSameDay, isTrue);
      expect(summary.trainingDays, {'2026-08-03'});
      expect(summary.workingSetsCount, 9);
      expect(
        R08F4TrainingVolumePresentation.formatThisWeekHeading(
          summary.sessionCount,
        ),
        '2 workouts',
      );
      expect(
        R08F4TrainingVolumePresentation.formatThisWeekSubtitle(
          sessionCount: summary.sessionCount,
          dayCount: summary.trainingDayCount,
        ),
        'completed across 1 training day this week',
      );
      expect(
        R08F4TrainingVolumePresentation.formatThisWeekSemantics(
          sessionCount: summary.sessionCount,
          dayCount: summary.trainingDayCount,
        ),
        '2 workouts completed across 1 training day this week.',
      );
    });

    test('handles sessions across different local days normally', () {
      final workouts = [
        ProgressWorkoutRecord(
          id: 1,
          name: 'Push Day',
          completedAtUtc: DateTime.utc(2026, 8, 3, 9),
          localDate: '2026-08-03',
          activityType: 'strength',
          totalVolumeKg: 4000,
          workingSetsCount: 8,
        ),
        ProgressWorkoutRecord(
          id: 2,
          name: 'Pull Day',
          completedAtUtc: DateTime.utc(2026, 8, 5, 9),
          localDate: '2026-08-05',
          activityType: 'strength',
          totalVolumeKg: 4500,
          workingSetsCount: 8,
        ),
        ProgressWorkoutRecord(
          id: 3,
          name: 'Leg Day',
          completedAtUtc: DateTime.utc(2026, 8, 7, 9),
          localDate: '2026-08-07',
          activityType: 'strength',
          totalVolumeKg: 5000,
          workingSetsCount: 10,
        ),
      ];

      final summary =
          R08F4TrainingVolumePresentation.summarizeConsistency(workouts);

      expect(summary.sessionCount, 3);
      expect(summary.trainingDayCount, 3);
      expect(summary.hasMultipleSessionsOnSameDay, isFalse);
      expect(
        R08F4TrainingVolumePresentation.formatThisWeekHeading(
          summary.sessionCount,
        ),
        '3 workouts',
      );
      expect(
        R08F4TrainingVolumePresentation.formatThisWeekSubtitle(
          sessionCount: summary.sessionCount,
          dayCount: summary.trainingDayCount,
        ),
        'completed this week',
      );
      expect(
        R08F4TrainingVolumePresentation.formatThisWeekSemantics(
          sessionCount: summary.sessionCount,
          dayCount: summary.trainingDayCount,
        ),
        '3 workouts completed this week.',
      );
      expect(
        R08F4TrainingVolumePresentation.formatRecentHistorySummary(
          sessionCount: summary.sessionCount,
          dayCount: summary.trainingDayCount,
          workingSetsCount: summary.workingSetsCount,
          weeks: 4,
        ),
        '3 workouts completed in the last 4 weeks · 26 working sets',
      );
    });

    test('preserves partial session completion kind without data fabrication', () {
      final workouts = [
        ProgressWorkoutRecord(
          id: 1,
          name: 'Full Workout',
          completedAtUtc: DateTime.utc(2026, 8, 3, 9),
          localDate: '2026-08-03',
          activityType: 'strength',
          totalVolumeKg: 4000,
          completionKind: 'full',
          workingSetsCount: 8,
        ),
        ProgressWorkoutRecord(
          id: 2,
          name: 'Partial Workout',
          completedAtUtc: DateTime.utc(2026, 8, 5, 9),
          localDate: '2026-08-05',
          activityType: 'strength',
          totalVolumeKg: 1500,
          completionKind: 'partial',
          workingSetsCount: 3,
        ),
      ];

      final summary =
          R08F4TrainingVolumePresentation.summarizeConsistency(workouts);

      expect(summary.sessionCount, 2);
      expect(summary.partialSessionCount, 1);
      expect(workouts[1].isPartial, isTrue);
      expect(workouts[1].isFull, isFalse);
      expect(workouts[0].isPartial, isFalse);
      expect(workouts[0].isFull, isTrue);
    });

    test('accurately counts different activity types without force-coercing to strength', () {
      final workouts = [
        ProgressWorkoutRecord(
          id: 1,
          name: 'Gym Strength',
          completedAtUtc: DateTime.utc(2026, 8, 3, 9),
          localDate: '2026-08-03',
          activityType: 'strength',
          totalVolumeKg: 3500,
        ),
        ProgressWorkoutRecord(
          id: 2,
          name: 'Morning Run',
          completedAtUtc: DateTime.utc(2026, 8, 4, 7),
          localDate: '2026-08-04',
          activityType: 'running',
          totalVolumeKg: 0,
        ),
        ProgressWorkoutRecord(
          id: 3,
          name: 'Evening Yoga',
          completedAtUtc: DateTime.utc(2026, 8, 5, 18),
          localDate: '2026-08-05',
          activityType: 'yoga',
          totalVolumeKg: 0,
        ),
      ];

      final summary =
          R08F4TrainingVolumePresentation.summarizeConsistency(workouts);

      expect(summary.sessionCount, 3);
      expect(summary.trainingDayCount, 3);
      expect(summary.activityTypeCounts['strength'], 1);
      expect(summary.activityTypeCounts['running'], 1);
      expect(summary.activityTypeCounts['yoga'], 1);
    });

    test('generates accurate screen-reader semantics for calendar strip days', () {
      expect(
        R08F4TrainingVolumePresentation.formatDaySemanticLabel(
          dayLabel: 'Mon',
          sessionCount: 2,
          isToday: false,
        ),
        'Mon, 2 workouts completed.',
      );
      expect(
        R08F4TrainingVolumePresentation.formatDaySemanticLabel(
          dayLabel: 'Tue',
          sessionCount: 1,
          isToday: false,
        ),
        'Tue, workout completed.',
      );
      expect(
        R08F4TrainingVolumePresentation.formatDaySemanticLabel(
          dayLabel: 'Wed',
          sessionCount: 0,
          isToday: true,
        ),
        'Wed, today.',
      );
      expect(
        R08F4TrainingVolumePresentation.formatDaySemanticLabel(
          dayLabel: 'Thu',
          sessionCount: 0,
          isToday: false,
        ),
        'Thu, rest day.',
      );
    });
  });

  group('R08F.4 — Training volume calculation & units', () {
    test('sums only trustworthy canonical strength workouts', () {
      final workouts = [
        ProgressWorkoutRecord(
          id: 1,
          name: 'Strength Valid',
          completedAtUtc: DateTime.utc(2026, 8, 1, 9),
          localDate: '2026-08-01',
          activityType: 'strength',
          totalVolumeKg: 2500,
          volumeIsTrustworthy: true,
        ),
        ProgressWorkoutRecord(
          id: 2,
          name: 'Bodyweight / Untrusted',
          completedAtUtc: DateTime.utc(2026, 8, 3, 9),
          localDate: '2026-08-03',
          activityType: 'strength',
          totalVolumeKg: 0,
          volumeIsTrustworthy: false,
        ),
        ProgressWorkoutRecord(
          id: 3,
          name: 'Cardio Run',
          completedAtUtc: DateTime.utc(2026, 8, 5, 9),
          localDate: '2026-08-05',
          activityType: 'running',
          totalVolumeKg: 0,
          volumeIsTrustworthy: false,
        ),
      ];

      final volume = R08F4TrainingVolumePresentation.summarizeVolume(
        allWorkouts: workouts,
        todayLocalDate: '2026-08-09',
        timezoneId: 'Asia/Kolkata',
        units: 'kg',
      );

      expect(volume.hasTrustworthyVolume, isTrue);
      expect(volume.totalVolumeKg, 2500.0);
      expect(volume.displayVolume, 2500.0);
      expect(volume.unitSymbol, 'kg');
      expect(volume.isImperial, isFalse);
    });

    test('supports imperial conversion correctly', () {
      final workouts = [
        ProgressWorkoutRecord(
          id: 1,
          name: 'Heavy Bench',
          completedAtUtc: DateTime.utc(2026, 8, 5, 9),
          localDate: '2026-08-05',
          activityType: 'strength',
          totalVolumeKg: 1000,
          volumeIsTrustworthy: true,
        ),
      ];

      final volumeImperial = R08F4TrainingVolumePresentation.summarizeVolume(
        allWorkouts: workouts,
        todayLocalDate: '2026-08-09',
        timezoneId: 'Asia/Kolkata',
        units: UnitPreferenceNotifier.imperial,
      );

      expect(volumeImperial.totalVolumeKg, 1000.0);
      expect(volumeImperial.isImperial, isTrue);
      expect(volumeImperial.unitSymbol, 'lb');
      expect(
        R08F4TrainingVolumePresentation.formatVolume(
          volumeImperial.displayVolume,
        ),
        '2,205',
      );
      expect(
        R08F4TrainingVolumePresentation.formatVolumeSubtitle(
          units: UnitPreferenceNotifier.imperial,
          useRecent: true,
        ),
        'lb recorded in the last 4 weeks',
      );
      expect(
        R08F4TrainingVolumePresentation.formatVolumeSemantics(
          displayVolume: volumeImperial.displayVolume,
          units: UnitPreferenceNotifier.imperial,
          useRecent: true,
        ),
        '2,205 pounds in the last four weeks.',
      );
    });

    test('falls back to all-time label when only older workouts exist', () {
      final workouts = [
        ProgressWorkoutRecord(
          id: 1,
          name: 'Old Workout',
          completedAtUtc: DateTime.utc(2026, 5, 1, 9),
          localDate: '2026-05-01',
          activityType: 'strength',
          totalVolumeKg: 5000,
          volumeIsTrustworthy: true,
        ),
      ];

      final volume = R08F4TrainingVolumePresentation.summarizeVolume(
        allWorkouts: workouts,
        todayLocalDate: '2026-08-09',
        timezoneId: 'Asia/Kolkata',
        units: 'kg',
      );

      expect(volume.useRecent, isFalse);
      expect(
        R08F4TrainingVolumePresentation.formatVolumeSubtitle(
          units: 'kg',
          useRecent: false,
        ),
        'kg across recorded strength workouts',
      );
      expect(
        R08F4TrainingVolumePresentation.formatVolumeSemantics(
          displayVolume: volume.displayVolume,
          units: 'kg',
          useRecent: false,
        ),
        '5,000 kilograms across recorded strength workouts.',
      );
    });
  });

  group('R08F.4 — Database repository reading facts', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.memory();
    });

    tearDown(() => database.close());

    test('read sets correct localDate according to configured timezone', () async {
      // 2026-08-03 19:30 UTC is 2026-08-04 01:00 in Asia/Kolkata (UTC+5:30)
      final completedUtc = DateTime.utc(2026, 8, 3, 19, 30);
      await database.into(database.workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          name: 'Late Night Workout',
          totalVolume: 1000,
          durationSeconds: 1800,
          estimatedCalories: 0,
          completedAt: Value(completedUtc),
          activityType: const Value('strength'),
          completionKind: const Value('full'),
        ),
      );

      final repo = ProgressDashboardReadRepository(database);
      final snapshotKolkata = await repo.read(
        nowUtc: DateTime.utc(2026, 8, 9, 12),
        timezoneId: 'Asia/Kolkata',
      );
      final snapshotUtc = await repo.read(
        nowUtc: DateTime.utc(2026, 8, 9, 12),
        timezoneId: 'UTC',
      );

      expect(snapshotKolkata.workouts!.first.localDate, '2026-08-04');
      expect(snapshotUtc.workouts!.first.localDate, '2026-08-03');
    });
  });

  group('R08F.4 — Widget presentation', () {
    testWidgets('renders multiple sessions on single day with exact factual copy', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final snapshot = ProgressDashboardSnapshot(
        nowUtc: DateTime.utc(2026, 8, 9, 12),
        timezoneId: 'Asia/Kolkata',
        todayLocalDate: '2026-08-09',
        measurements: const [],
        workouts: [
          ProgressWorkoutRecord(
            id: 1,
            name: 'Session 1',
            completedAtUtc: DateTime.utc(2026, 8, 3, 8),
            localDate: '2026-08-03',
            activityType: 'strength',
            totalVolumeKg: 2000,
            workingSetsCount: 4,
          ),
          ProgressWorkoutRecord(
            id: 2,
            name: 'Session 2',
            completedAtUtc: DateTime.utc(2026, 8, 3, 17),
            localDate: '2026-08-03',
            activityType: 'strength',
            totalVolumeKg: 2500,
            workingSetsCount: 5,
          ),
        ],
        weeklyTrainedDates: const {'2026-08-03'},
        strengthSets: const [],
        muscleBalance: null,
        unavailableSections: const {},
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ProgressScreen(preview: snapshot),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 workouts'), findsWidgets);
      expect(find.text('completed across 1 training day this week'), findsOneWidget);
      expect(
        find.text('2 workouts across 1 training day in the last 4 weeks · 9 working sets'),
        findsOneWidget,
      );
      expect(find.text('Training volume'), findsOneWidget);
      expect(find.text('4,500'), findsOneWidget);
      expect(find.text('kg recorded in the last 4 weeks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Progress screen remains usable at 320 width with 2x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final snapshot = ProgressDashboardSnapshot(
        nowUtc: DateTime.utc(2026, 8, 9, 12),
        timezoneId: 'Asia/Kolkata',
        todayLocalDate: '2026-08-09',
        measurements: const [],
        workouts: [
          ProgressWorkoutRecord(
            id: 1,
            name: 'Workout 1',
            completedAtUtc: DateTime.utc(2026, 8, 3, 8),
            localDate: '2026-08-03',
            activityType: 'strength',
            totalVolumeKg: 1500,
          ),
        ],
        weeklyTrainedDates: const {'2026-08-03'},
        strengthSets: const [],
        muscleBalance: null,
        unavailableSections: const {},
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: ProgressScreen(preview: snapshot),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 workout'), findsWidgets);
      expect(find.text('completed this week'), findsWidgets);
      expect(find.text('Training volume'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
