import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/dashboard_personalization_repository.dart';
import 'package:indifit/data/repositories/progress_statistics_repository.dart';
import 'package:indifit/data/repositories/weekly_report_service.dart';
import 'package:indifit/features/dashboard/dashboard_module_registry.dart';
import 'package:indifit/features/dashboard/dashboard_personalization_controller.dart';
import 'package:indifit/features/dashboard/dashboard_screen.dart';
import 'package:indifit/features/dashboard/today_daily_action_surface.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/reports/weekly_report_screen.dart';
import 'package:indifit/features/settings/notification_settings_screen.dart';
import 'package:indifit/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DashboardPersonalizationController personalization;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.memory();
    personalization = DashboardPersonalizationController(
      repository: DashboardPersonalizationRepository(
        database: database,
        registry: standardDashboardModuleRegistry,
      ),
      userId: 'local-nutrition-user',
    );
    await personalization.load();
  });

  tearDown(() => unawaited(database.close()));

  group('R08E.7 — Hydration Authority Gate', () {
    test(
      'standard module registry does not register an unsupported hydration module',
      () {
        final moduleIds = standardDashboardModuleRegistry.descriptors.map(
          (d) => d.id,
        );
        expect(moduleIds, isNot(contains('today.hydration')));
        expect(moduleIds, isNot(contains('today.water')));
        expect(
          standardDashboardModuleRegistry.contains('today.hydration'),
          isFalse,
        );
        expect(
          standardDashboardModuleRegistry.contains('today.water'),
          isFalse,
        );
      },
    );

    testWidgets(
      'Today dashboard renders only supported modules and no fake hydration tracker or placeholder',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardPersonalizationControllerProvider.overrideWith(
                (ref) => personalization,
              ),
              todaySurfaceSnapshotProvider.overrideWith(
                (ref, date) async => TodaySurfaceSnapshot(
                  selectedDate: date,
                  localDate: todaySurfaceDateKey(date),
                  timezoneId: 'Asia/Kolkata',
                  calendar: const TodayDomainRead.unavailable(
                    'calendar unavailable',
                  ),
                  progress: const TodayDomainRead.unavailable(
                    'progress unavailable',
                  ),
                  nutrition: const TodayDomainRead.unavailable(
                    'nutrition unavailable',
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: TodayDailyActionSurface(
                selectedDate: DateTime(2026, 8, 25),
                now: DateTime(2026, 8, 25, 12),
                userName: 'Ari',
                streakCount: 3,
                onDateChanged: (_) {},
                onRefresh: () async {},
                onOpenSettings: () {},
                onCustomize: () {},
                onOpenWorkoutPlan: () {},
                onLogMeal: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Confirm supported modules render honest states
        expect(find.text('Next up unavailable'), findsOneWidget);
        expect(find.text('Nutrition unavailable'), findsOneWidget);
        expect(find.text('Meals unavailable'), findsOneWidget);

        // Confirm zero hydration surfaces, water trackers, or fake progress
        expect(find.textContaining('Hydration'), findsNothing);
        expect(find.textContaining('HYDRATION'), findsNothing);
        expect(find.textContaining('Water'), findsNothing);
        expect(find.textContaining('water'), findsNothing);
        expect(find.textContaining('glasses'), findsNothing);
        expect(find.textContaining('Coming soon'), findsNothing);
        expect(find.byIcon(Icons.water_drop), findsNothing);
        expect(find.byIcon(Icons.water_drop_rounded), findsNothing);
        expect(find.byIcon(Icons.water_drop_outlined), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Settings screen does not expose dead Hydration configuration or unbacked recommendations',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Confirm primary settings groups exist
        expect(find.text('Settings'), findsOneWidget);
        for (final label in const [
          'Appearance',
          'Units',
          'Notifications & reminders',
          'Customize today',
        ]) {
          final row = find.widgetWithText(ListTile, label);
          await tester.scrollUntilVisible(row, 300);
          expect(row, findsOneWidget);
        }

        // Confirm stale/unsupported Hydration subscreen entry is absent
        expect(find.text('Hydration'), findsNothing);
        expect(find.text('Water goal and glass size'), findsNothing);
        expect(find.textContaining('35ml/kg'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'underlying schema and backup retain DailyHydrations table without creating fake UI',
      () async {
        // Confirm underlying drift schema retains DailyHydrations without error
        final count = await database.select(database.dailyHydrations).get();
        expect(count, isEmpty);

        // Inserting test record into table operates normally
        await database
            .into(database.dailyHydrations)
            .insert(
              DailyHydrationsCompanion.insert(
                dateString: '2026-08-25',
                totalMl: 1500,
                goalMl: 2000,
              ),
            );
        final records = await database.select(database.dailyHydrations).get();
        expect(records.length, 1);
        expect(records.first.dateString, '2026-08-25');
        expect(records.first.totalMl, 1500);
      },
    );

    testWidgets(
      'normal weekly report UI exposes neither a hydration target nor water recommendation',
      (tester) async {
        final metrics = WeeklyMetrics(
          startDate: DateTime(2026, 8, 19),
          endDate: DateTime(2026, 8, 25),
          totalCaloriesLogged: 4200,
          totalCaloriesGoal: 14000,
          calorieAdherenceScore: .3,
          totalProteinG: 420,
          totalProteinGoal: 980,
          proteinAdherenceScore: .43,
          nutritionDaysLogged: 4,
          hydrationDaysAtGoal: 7,
          totalHydrationMl: 14000,
          totalHydrationGoalMl: 14000,
          completedWorkoutsCount: 2,
          plannedWorkoutsCount: 3,
          workoutCompletionScore: .67,
          totalVolumeKg: 3200,
          prsCount: 0,
          overallAdherenceScore: .47,
          adherenceBreakdown: AdherenceBreakdown(
            calorieScore: .3,
            proteinScore: .43,
            workoutScore: .67,
            hydrationScore: 1,
            overallScore: .47,
          ),
        );
        final report = WeeklyReportResult(
          headline: 'Weekly summary',
          adherenceScore: 47,
          summary: 'Four food-log days and two completed workouts.',
          coachingTip: 'Keep training consistently.',
          topPrs: const [],
          isFallback: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              progressStatisticsRepositoryProvider.overrideWithValue(
                _FixedProgressStatisticsRepository(database, metrics),
              ),
              weeklyReportServiceProvider.overrideWithValue(
                _FixedWeeklyReportService(report),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const WeeklyReportScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('WEEKLY ADHERENCE'), findsOneWidget);
        expect(find.text('Hydration Goal'), findsNothing);
        expect(find.textContaining('water', findRichText: true), findsNothing);
        expect(
          find.textContaining('hydration', findRichText: true),
          findsNothing,
        );
        expect(
          kWeeklyActionOptions.map((option) => option.type),
          isNot(contains('water_intake')),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('notification settings do not expose dead water logging', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workout Reminder'), findsOneWidget);
      expect(find.text('Meal Logging'), findsOneWidget);
      expect(find.text('Water Intake'), findsNothing);
      expect(find.textContaining('hydration'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('weekly report fallback copy does not recommend hydration', () async {
      final service = WeeklyReportService(
        null,
        const PrivacyPolicy(isOfflineOnly: true, isTelemetryEnabled: false),
      );
      final insufficient = await service.generateReport(
        totalCaloriesLogged: 0,
        calorieGoal: 14000,
        workoutSessionsCount: 0,
        totalVolumeKg: 0,
        prsCount: 0,
        adherenceScore: 0,
      );
      final available = await service.generateReport(
        totalCaloriesLogged: 1200,
        calorieGoal: 14000,
        workoutSessionsCount: 1,
        totalVolumeKg: 800,
        prsCount: 0,
        adherenceScore: 45,
      );

      final copy = [
        insufficient.summary,
        insufficient.coachingTip,
        available.summary,
        available.coachingTip,
      ].join(' ').toLowerCase();
      expect(copy, isNot(contains('hydration')));
      expect(copy, isNot(contains('hydrated')));
      expect(copy, isNot(contains('water intake')));
    });

    test(
      'dashboard recovery prompt does not compete with workout Resume',
      () async {
        final strength = await database
            .into(database.workoutDrafts)
            .insertReturning(
              WorkoutDraftsCompanion.insert(
                routineName: 'Strength draft',
                currentExerciseIndex: 0,
                currentSetIndex: 0,
                elapsedSeconds: 30,
                loggedSetsJson: '[]',
                activityType: const Value('strength'),
                executionStateJson: const Value('{}'),
              ),
            );
        expect(shouldShowDashboardActivityRecoveryPrompt(strength), isFalse);

        await database.delete(database.workoutDrafts).go();
        final running = await database
            .into(database.workoutDrafts)
            .insertReturning(
              WorkoutDraftsCompanion.insert(
                routineName: 'Running draft',
                currentExerciseIndex: 0,
                currentSetIndex: 0,
                elapsedSeconds: 30,
                loggedSetsJson: '[]',
                activityType: const Value('running'),
                executionStateJson: const Value('{}'),
              ),
            );
        expect(shouldShowDashboardActivityRecoveryPrompt(running), isTrue);
      },
    );
  });
}

class _FixedProgressStatisticsRepository extends ProgressStatisticsRepository {
  _FixedProgressStatisticsRepository(super.database, this.metrics);

  final WeeklyMetrics metrics;

  @override
  Future<WeeklyMetrics> getWeeklyMetrics({DateTime? referenceDate}) async =>
      metrics;
}

class _FixedWeeklyReportService extends WeeklyReportService {
  _FixedWeeklyReportService(this.report);

  final WeeklyReportResult report;

  @override
  Future<WeeklyReportResult> generateReportFromMetrics(
    WeeklyMetrics metrics,
  ) async => report;
}
