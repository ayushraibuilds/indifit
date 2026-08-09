import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

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

  tearDown(() async {
    await database.close();
  });

  testWidgets('Today presents the daily modules in registry order', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        overrides: [
          dashboardPersonalizationControllerProvider.overrideWith(
            (ref) => personalization,
          ),
          todaySurfaceSnapshotProvider.overrideWith(
            (ref, date) async => _unavailableSnapshot(date),
          ),
        ],
        child: TodayDailyActionSurface(
          selectedDate: DateTime(2026, 8, 6),
          now: DateTime(2026, 8, 7),
          userName: 'Ari',
          streakCount: 4,
          onDateChanged: (_) {},
          onRefresh: () async {},
          onOpenSettings: () {},
          onCustomize: () {},
          onOpenWorkoutPlan: () {},
          onLogMeal: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final labels = [
      'Nutrition unavailable',
      'Next up unavailable',
      'Meals unavailable',
      'Workout unavailable',
      'Activity unavailable',
      'Progress unavailable',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text(labels[0])).dy,
      lessThan(tester.getTopLeft(find.text(labels[1])).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('personalization changes visibility, order and collapse', (
    tester,
  ) async {
    final defaults = standardDashboardModuleRegistry.normalize(const []);
    final seeded = _SeededPersonalizationController(
      repository: DashboardPersonalizationRepository(
        database: database,
        registry: standardDashboardModuleRegistry,
      ),
      layout: [
        defaults[5].copyWith(ordinal: 0),
        defaults[2].copyWith(ordinal: 1, isCollapsed: true),
        defaults[3].copyWith(ordinal: 2),
        defaults[0].copyWith(ordinal: 3, isVisible: false),
      ],
    );
    await seeded.load();

    await tester.pumpWidget(
      _app(
        overrides: [
          dashboardPersonalizationControllerProvider.overrideWith(
            (ref) => seeded,
          ),
          todaySurfaceSnapshotProvider.overrideWith(
            (ref, date) async => _unavailableSnapshot(date),
          ),
        ],
        child: TodayDailyActionSurface(
          selectedDate: DateTime(2026, 8, 6),
          now: DateTime(2026, 8, 7),
          userName: 'Ari',
          streakCount: 4,
          onDateChanged: (_) {},
          onRefresh: () async {},
          onOpenSettings: () {},
          onCustomize: () {},
          onOpenWorkoutPlan: () {},
          onLogMeal: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Nutrition unavailable'), findsNothing);
    expect(find.text('Collapsed'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Progress unavailable')).dy,
      lessThan(tester.getTopLeft(find.text('Workout unavailable')).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('future date has a return action and reflows at 2x text', (
    tester,
  ) async {
    var selected = DateTime(2026, 8, 8);
    await tester.pumpWidget(
      _app(
        mediaQuery: const MediaQueryData(
          size: Size(320, 720),
          textScaler: TextScaler.linear(2),
          disableAnimations: true,
        ),
        overrides: [
          dashboardPersonalizationControllerProvider.overrideWith(
            (ref) => personalization,
          ),
          todaySurfaceSnapshotProvider.overrideWith(
            (ref, date) async => _unavailableSnapshot(date),
          ),
        ],
        child: TodayDailyActionSurface(
          selectedDate: selected,
          now: DateTime(2026, 8, 7),
          userName: 'Ari',
          streakCount: 4,
          onDateChanged: (date) => selected = date,
          onRefresh: () async {},
          onOpenSettings: () {},
          onCustomize: () {},
          onOpenWorkoutPlan: () {},
          onLogMeal: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final action = find.bySemanticsLabel('Return to today');
    expect(action, findsOneWidget);
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(selected, DateTime(2026, 8, 7));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('date and next-action policies preserve boundaries', () {
    final today = DateTime(2026, 8, 7);
    expect(
      todayDateRelation(today.subtract(const Duration(days: 1)), today),
      TodayDateRelation.past,
    );
    expect(todayDateRelation(today, today), TodayDateRelation.today);
    expect(
      todayDateRelation(today.add(const Duration(days: 1)), today),
      TodayDateRelation.future,
    );
    expect(
      chooseTodayNextAction(dateRelation: TodayDateRelation.future).action,
      TodayNextAction.returnToToday,
    );
    expect(
      chooseTodayNextAction(dateRelation: TodayDateRelation.today).action,
      TodayNextAction.openWorkoutPlan,
    );
  });
}

class _SeededPersonalizationController
    extends DashboardPersonalizationController {
  _SeededPersonalizationController({
    required super.repository,
    required List<DashboardModuleLayoutItem> layout,
  }) : _layout = layout,
       super(userId: 'local-nutrition-user');

  final List<DashboardModuleLayoutItem> _layout;

  @override
  Future<void> load() async {
    state = DashboardPersonalizationState(
      status: DashboardPersonalizationStatus.ready,
      layout: List.unmodifiable(_layout),
    );
  }
}

TodaySurfaceSnapshot _unavailableSnapshot(DateTime selectedDate) {
  return TodaySurfaceSnapshot(
    selectedDate: selectedDate,
    localDate: todaySurfaceDateKey(selectedDate),
    timezoneId: 'UTC',
    calendar: const TodayDomainRead.unavailable('Calendar offline'),
    progress: const TodayDomainRead.unavailable('Activity offline'),
    nutrition: const TodayDomainRead.unavailable('Nutrition offline'),
  );
}

Widget _app({
  required List<Override> overrides,
  required Widget child,
  MediaQueryData? mediaQuery,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MediaQuery(
      data: mediaQuery ?? const MediaQueryData(size: Size(430, 900)),
      child: MaterialApp(theme: AppTheme.lightTheme, home: child),
    ),
  );
}
