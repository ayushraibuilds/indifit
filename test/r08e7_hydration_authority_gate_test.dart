import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/dashboard_personalization_repository.dart';
import 'package:indifit/features/dashboard/dashboard_module_registry.dart';
import 'package:indifit/features/dashboard/dashboard_personalization_controller.dart';
import 'package:indifit/features/dashboard/dashboard_screen.dart';
import 'package:indifit/features/dashboard/today_daily_action_surface.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
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
      'standard module registry registers canonical today.hydration module and rejects unbacked aliases',
      () {
        final moduleIds = standardDashboardModuleRegistry.descriptors.map(
          (d) => d.id,
        );
        expect(moduleIds, contains('today.hydration'));
        expect(moduleIds, isNot(contains('today.water')));
        expect(
          standardDashboardModuleRegistry.contains('today.hydration'),
          isTrue,
        );
        expect(
          standardDashboardModuleRegistry.contains('today.water'),
          isFalse,
        );
      },
    );

    testWidgets(
      'Today dashboard renders only supported modules and honest unavailable state for hydration',
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
        expect(find.text('Hydration unavailable'), findsOneWidget);

        // Confirm zero fake water trackers, glasses placeholders, or "coming soon" hacks
        expect(find.textContaining('Coming soon'), findsNothing);
        expect(find.textContaining('glasses'), findsNothing);
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

      expect(
        find.textContaining(RegExp('workout reminder', caseSensitive: false)),
        findsWidgets,
      );
      expect(
        find.textContaining(RegExp('meal logging', caseSensitive: false)),
        findsWidgets,
      );
      expect(find.text('Water Intake'), findsNothing);
      expect(find.textContaining('hydration'), findsNothing);
      expect(tester.takeException(), isNull);
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
