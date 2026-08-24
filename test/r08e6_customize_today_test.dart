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
import 'package:indifit/features/dashboard/widgets/dashboard_module_customization_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DashboardPersonalizationController personalization;

  setUp(() async {
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

  testWidgets('Customize Today uses consumer labels and exposes reset', (
    tester,
  ) async {
    await tester.runAsync(
      () => personalization.setVisible('today.workout', true),
    );
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _panelApp(
        personalization,
        theme: AppTheme.lightTheme,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pump();

    expect(find.text('Choose what appears on Today'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('today-customize-toggle-today.workout')),
      240,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.byKey(const ValueKey('today-customize-toggle-today.workout')),
      findsOneWidget,
    );
    expect(find.text('today.workout'), findsNothing);

    await tester.pumpWidget(
      _panelApp(
        personalization,
        theme: AppTheme.darkTheme,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Reset to defaults'),
      240,
      scrollable: find.byType(Scrollable),
    );
    final resetButton = find.widgetWithText(
      OutlinedButton,
      'Reset to defaults',
    );
    expect(tester.widget<OutlinedButton>(resetButton).onPressed, isNotNull);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('today-customize-toggle-today.workout')),
          )
          .value,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('supported visibility switches send existing module commands', (
    tester,
  ) async {
    String? changedModule;
    bool? changedVisibility;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: DashboardModuleCustomizationList(
              layout: standardDashboardModuleRegistry.normalize(const []),
              isSaving: false,
              onMove: (_, _) async {},
              onVisibilityChanged: (moduleId, isVisible) async {
                changedModule = moduleId;
                changedVisibility = isVisible;
              },
              onCollapsedChanged: (_, _) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('today-customize-toggle-today.workout')),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(
      find.byKey(const ValueKey('today-customize-toggle-today.workout')),
    );
    await tester.pump();

    expect(changedModule, 'today.workout');
    expect(changedVisibility, isTrue);
  });

  testWidgets('Today reacts to the shared visibility state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
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
            selectedDate: DateTime(2026, 8, 25),
            now: DateTime(2026, 8, 25, 18),
            userName: 'Ari',
            streakCount: 0,
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

    expect(find.text('Activity unavailable'), findsNothing);
    await tester.runAsync(
      () => personalization.setVisible('today.activity', true),
    );
    await tester.pump();
    expect(
      _item(personalization.state.layout, 'today.activity').isVisible,
      isTrue,
    );
    expect(find.text('Activity unavailable'), findsOneWidget);

    await tester.runAsync(
      () => personalization.setVisible('today.activity', false),
    );
    await tester.pump();
    expect(find.text('Activity unavailable'), findsNothing);
  });

  testWidgets('unsupported descriptors stay out of Customize Today', (
    tester,
  ) async {
    final registry = DashboardModuleRegistry([
      const DashboardModuleDescriptor(
        id: 'today.activity',
        defaultOrdinal: 0,
        label: 'Activity',
        customizationLabel: 'Activity',
        customizationDescription: 'See activity details.',
        showInCustomizeToday: true,
        eligibility: DashboardModuleEligibility.activity,
      ),
      const DashboardModuleDescriptor(
        id: 'today.internal_debug',
        defaultOrdinal: 1,
        label: 'Debug panel',
        customizationLabel: 'Debug panel',
        customizationDescription: 'Internal diagnostics.',
        eligibility: DashboardModuleEligibility.progress,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: DashboardModuleCustomizationList(
              layout: registry.normalize(const []),
              isSaving: false,
              onMove: (_, _) async {},
              onVisibilityChanged: (_, _) async {},
              onCollapsedChanged: (_, _) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Debug panel'), findsNothing);
    expect(find.text('Internal diagnostics.'), findsNothing);

    var resetCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: DashboardModuleCustomizationList(
              layout: standardDashboardModuleRegistry.normalize(const []),
              isSaving: false,
              onMove: (_, _) async {},
              onVisibilityChanged: (_, _) async {},
              onCollapsedChanged: (_, _) async {},
              onReset: () async => resetCalled = true,
              canReset: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Reset to defaults'),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset to defaults'));
    await tester.pump();
    expect(resetCalled, isTrue);
  });
}

Widget _panelApp(
  DashboardPersonalizationController controller, {
  required ThemeData theme,
  required TextScaler textScaler,
}) => ProviderScope(
  overrides: [
    dashboardPersonalizationControllerProvider.overrideWith(
      (ref) => controller,
    ),
  ],
  child: MediaQuery(
    data: MediaQueryData(textScaler: textScaler),
    child: MaterialApp(
      theme: theme,
      home: Scaffold(body: DashboardModuleCustomizationPanel()),
    ),
  ),
);

DashboardModuleLayoutItem _item(
  List<DashboardModuleLayoutItem> layout,
  String moduleId,
) => layout.singleWhere((item) => item.moduleId == moduleId);

TodaySurfaceSnapshot _unavailableSnapshot(DateTime date) =>
    TodaySurfaceSnapshot(
      selectedDate: date,
      localDate: todaySurfaceDateKey(date),
      timezoneId: 'Asia/Kolkata',
      calendar: const TodayDomainRead.unavailable('calendar unavailable'),
      progress: const TodayDomainRead.unavailable('progress unavailable'),
      nutrition: const TodayDomainRead.unavailable('nutrition unavailable'),
    );
