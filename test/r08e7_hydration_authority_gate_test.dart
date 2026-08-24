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
import 'package:indifit/features/dashboard/today_daily_action_surface.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
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
        expect(standardDashboardModuleRegistry.contains('today.hydration'), isFalse);
        expect(standardDashboardModuleRegistry.contains('today.water'), isFalse);
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
                  calendar: const TodayDomainRead.unavailable('calendar unavailable'),
                  progress: const TodayDomainRead.unavailable('progress unavailable'),
                  nutrition: const TodayDomainRead.unavailable('nutrition unavailable'),
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
            overrides: [
              databaseProvider.overrideWithValue(database),
            ],
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
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.text('Units'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Customize Today'), findsOneWidget);

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
        await database.into(database.dailyHydrations).insert(
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
  });
}
