import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/dashboard_personalization_repository.dart';
import 'package:indifit/features/dashboard/dashboard_module_registry.dart';
import 'package:indifit/features/dashboard/dashboard_personalization_controller.dart';
import 'package:indifit/features/dashboard/today_daily_action_surface.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DashboardPersonalizationController personalization;

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

  tearDown(() => database.close());

  test(
    'default Today hierarchy starts with action, then nutrition context',
    () {
      final layout = standardDashboardModuleRegistry.normalize(const []);

      expect(layout.map((item) => item.moduleId), [
        'today.next_action',
        'today.meals',
        'today.meal_rows',
        'today.workout',
        'today.activity',
        'today.progress',
      ]);
      expect(layout[0].isVisible, isTrue);
      expect(layout[1].isVisible, isTrue);
      expect(layout[2].isVisible, isTrue);
      expect(layout.skip(3).every((item) => !item.isVisible), isTrue);
    },
  );

  test('date context makes historical and future browsing explicit', () {
    final now = DateTime(2026, 8, 9, 18);

    expect(
      todayDateContextLabel(DateTime(2026, 8, 9), now),
      'Today · Sunday, 9 August',
    );
    expect(
      todayDateContextLabel(DateTime(2026, 8, 8), now),
      'Past day · Saturday, 8 August',
    );
    expect(
      todayDateContextLabel(DateTime(2026, 8, 10), now),
      'Upcoming · Monday, 10 August',
    );
  });

  testWidgets('default Today omits unavailable secondary modules', (
    tester,
  ) async {
    await tester.pumpWidget(_app(personalization: personalization));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Next up unavailable'), findsOneWidget);
    expect(find.text('Nutrition unavailable'), findsOneWidget);
    expect(find.text('Meals unavailable'), findsOneWidget);
    expect(find.text('Workout unavailable'), findsNothing);
    expect(find.text('Activity unavailable'), findsNothing);
    expect(find.text('Progress unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('future context remains usable at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(2),
          disableAnimations: true,
        ),
        child: _app(
          personalization: personalization,
          selectedDate: DateTime(2026, 8, 10),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Upcoming · Monday, 10 August'), findsOneWidget);
    expect(find.text('Plan ahead'), findsOneWidget);
    expect(find.bySemanticsLabel('Return to today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required DashboardPersonalizationController personalization,
  DateTime? selectedDate,
}) {
  final selected = selectedDate ?? DateTime(2026, 8, 9);
  return ProviderScope(
    overrides: [
      dashboardPersonalizationControllerProvider.overrideWith(
        (ref) => personalization,
      ),
      todaySurfaceSnapshotProvider.overrideWith(
        (ref, date) async => _unavailableSnapshot(date),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: TodayDailyActionSurface(
        selectedDate: selected,
        now: DateTime(2026, 8, 9, 18),
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
  );
}

TodaySurfaceSnapshot _unavailableSnapshot(DateTime date) =>
    TodaySurfaceSnapshot(
      selectedDate: date,
      localDate: todaySurfaceDateKey(date),
      timezoneId: 'Asia/Kolkata',
      calendar: const TodayDomainRead.unavailable('calendar unavailable'),
      progress: const TodayDomainRead.unavailable('progress unavailable'),
      nutrition: const TodayDomainRead.unavailable('nutrition unavailable'),
    );
