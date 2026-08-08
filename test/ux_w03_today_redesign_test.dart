import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/dashboard_personalization_repository.dart';
import 'package:indifit/features/dashboard/dashboard_module_registry.dart';
import 'package:indifit/features/dashboard/dashboard_personalization_controller.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
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

  test('Today presentation keeps ranges honest and never invents zero', () {
    final presentation = TodayNutritionPresentation.from(
      TodayDomainRead.available(_dailyWithFacts()),
      loading: false,
    );

    expect(presentation.state, TodayPresentationState.ready);
    expect(presentation.calories?.value, '1200–1500');
    expect(presentation.calories?.unit, 'kcal');
    expect(presentation.macros.map((item) => item.label), [
      'Protein',
      'Carbohydrates',
      'Fat',
    ]);
    expect(presentation.macros.map((item) => item.value), isNot(contains('0')));
  });

  test('Today empty and unavailable states remain distinct', () {
    final empty = TodayNutritionPresentation.from(
      TodayDomainRead.available(_dailyWithFacts(records: const [])),
      loading: false,
    );
    final unavailable = TodayNutritionPresentation.from(
      const TodayDomainRead.unavailable('source failed'),
      loading: false,
    );

    expect(empty.state, TodayPresentationState.empty);
    expect(empty.headline, 'Your nutrition starts here');
    expect(unavailable.state, TodayPresentationState.unavailable);
    expect(unavailable.detail, isNot(contains('source failed')));
  });

  test(
    'focus policy chooses a useful consumer action without domain reads',
    () {
      expect(
        todayFocusPresentation(dateRelation: TodayDateRelation.future).action,
        TodayNextAction.returnToToday,
      );
      expect(
        todayFocusPresentation(dateRelation: TodayDateRelation.today).action,
        TodayNextAction.logMeal,
      );
    },
  );

  testWidgets(
    'Today reflows at phone widths, large text, themes and reduced motion',
    (tester) async {
      for (final brightness in Brightness.values) {
        for (final size in const [Size(320, 568), Size(390, 844)]) {
          for (final scale in const [1.0, 2.0]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(
              _todayApp(
                theme: brightness == Brightness.dark
                    ? AppTheme.darkTheme
                    : AppTheme.lightTheme,
                textScale: scale,
                disableAnimations: true,
                personalization: personalization,
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            final exception = tester.takeException();
            expect(exception, isNull);
            expect(find.text('Start with one small win'), findsOneWidget);
          }
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets('Today dark golden benchmark', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      _todayApp(
        theme: AppTheme.darkTheme,
        textScale: 1,
        disableAnimations: true,
        personalization: personalization,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TodayDailyActionSurface), findsOneWidget);
    await expectLater(
      find.byType(TodayDailyActionSurface),
      matchesGoldenFile('goldens/ux_w03_today_dark.png'),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Today light golden benchmark', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      _todayApp(
        theme: AppTheme.lightTheme,
        textScale: 1,
        disableAnimations: true,
        personalization: personalization,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(TodayDailyActionSurface),
      matchesGoldenFile('goldens/ux_w03_today_light.png'),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _todayApp({
  required ThemeData theme,
  required double textScale,
  required bool disableAnimations,
  required DashboardPersonalizationController personalization,
}) {
  return ProviderScope(
    overrides: [
      dashboardPersonalizationControllerProvider.overrideWith(
        (ref) => personalization,
      ),
      todaySurfaceSnapshotProvider.overrideWith(
        (ref, date) async => TodaySurfaceSnapshot(
          selectedDate: date,
          localDate: todaySurfaceDateKey(date),
          timezoneId: 'Asia/Kolkata',
          calendar: const TodayDomainRead.unavailable('offline'),
          progress: const TodayDomainRead.unavailable('offline'),
          nutrition: const TodayDomainRead.unavailable('offline'),
        ),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp(
        theme: theme,
        home: TodayDailyActionSurface(
          selectedDate: DateTime(2026, 8, 7),
          now: DateTime(2026, 8, 8, 10),
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
}

NutritionDailyReadModel _dailyWithFacts({
  List<NutritionHistoricalReadRecord> records = const [_TestRecord()],
}) {
  final facts = <String, NutrientFact>{
    'energy': NutrientFact.estimated(
      nutrientId: 'energy',
      point: _amount(1350, NutrientUnit.kilocalorie),
      lower: _amount(1200, NutrientUnit.kilocalorie),
      upper: _amount(1500, NutrientUnit.kilocalorie),
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: NutrientSourceType.userEntered,
    ),
    'protein': NutrientFact.known(
      nutrientId: 'protein',
      point: _amount(72, NutrientUnit.gram),
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: NutrientSourceType.userEntered,
    ),
    'carbohydrate': NutrientFact.known(
      nutrientId: 'carbohydrate',
      point: _amount(160, NutrientUnit.gram),
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: NutrientSourceType.userEntered,
    ),
    'fat': NutrientFact.known(
      nutrientId: 'fat',
      point: _amount(45, NutrientUnit.gram),
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: NutrientSourceType.userEntered,
    ),
  };
  return NutritionDailyReadModel(
    userId: 'local-nutrition-user',
    localDate: '2026-08-07',
    records: records,
    recordIds: const ['record'],
    totals: NutrientAggregationResult(
      facts: facts,
      completeness: NutrientCompleteness(
        state: NutrientCompletenessState.complete,
        requestedNutrientIds: facts.keys,
        availableNutrientIds: facts.keys,
        missingNutrientIds: const [],
        estimatedNutrientIds: const ['energy'],
        notApplicableNutrientIds: const [],
        partiallyKnownNutrientIds: const [],
      ),
      sourceLineage: const {},
      factVersionLineage: const {},
    ),
    sourceCounts: const {},
    issues: const [],
  );
}

NutrientAmount _amount(num value, NutrientUnit unit) =>
    NutrientAmount(value: QuantityAmount.fromNum(value), unit: unit);

class _TestRecord implements NutritionHistoricalReadRecord {
  const _TestRecord();

  @override
  String get stableId => 'record';
  @override
  String get userId => 'local-nutrition-user';
  @override
  String get sourceType => 'test';
  @override
  DateTime get loggedAtUtc => DateTime.utc(2026, 8, 7, 8);
  @override
  String get localDate => '2026-08-07';
  @override
  String get mealCategory => 'breakfast';
  @override
  String? get mealGroupId => null;
  @override
  String get displayLabel => 'Breakfast';
  @override
  NutrientCompleteness get completeness => NutrientCompleteness(
    state: NutrientCompletenessState.complete,
    requestedNutrientIds: const [],
    availableNutrientIds: const [],
    missingNutrientIds: const [],
    estimatedNutrientIds: const [],
    notApplicableNutrientIds: const [],
    partiallyKnownNutrientIds: const [],
  );
  @override
  NutrientAggregationResult get totals => NutrientAggregationResult(
    facts: {},
    completeness: NutrientCompleteness(
      state: NutrientCompletenessState.complete,
      requestedNutrientIds: [],
      availableNutrientIds: [],
      missingNutrientIds: [],
      estimatedNutrientIds: [],
      notApplicableNutrientIds: [],
      partiallyKnownNutrientIds: [],
    ),
    sourceLineage: {},
    factVersionLineage: {},
  );
  @override
  List<NutritionHistoricalReadItem> get items => const [];
  @override
  List<NutritionCompatibilityIssue> get issues => const [];
  @override
  bool get isLegacy => false;
}
