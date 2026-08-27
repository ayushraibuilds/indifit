import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_progress_read_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/dashboard_personalization_repository.dart';
import 'package:indifit/data/repositories/nutrition_goal_repository.dart';
import 'package:indifit/features/dashboard/dashboard_module_registry.dart';
import 'package:indifit/features/dashboard/dashboard_personalization_controller.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_daily_action_surface.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _refreshSnapshotProvider = StateProvider<TodaySurfaceSnapshot>(
  (ref) => _snapshot(DateTime(2026, 8, 9)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // R07F-0: Outfit is bundled; no runtime font fetching configuration.

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

  tearDown(() async => database.close());

  test('nutrition presentation preserves target, range, and missing facts', () {
    final withRange = TodayNutritionPresentation.from(
      TodayDomainRead.available(
        _nutrition(
          facts: {
            'energy': _estimatedRange(
              'energy',
              1350,
              1200,
              1500,
              NutrientUnit.kilocalorie,
            ),
            'protein': _known('protein', 118, NutrientUnit.gram),
            'carbohydrate': _known('carbohydrate', 192, NutrientUnit.gram),
            'fat': _known('fat', 58, NutrientUnit.gram),
            'fibre': _known('fibre', 21, NutrientUnit.gram),
          },
          records: _mealRecords(),
        ),
      ),
      loading: false,
      goal: TodayDomainRead.available(_goal()),
    );

    expect(withRange.calories?.value, '1,200–1,500');
    expect(withRange.calories?.isRange, isTrue);
    expect(withRange.calories?.targetValue, 2200);
    expect(withRange.macros.map((metric) => metric.label), [
      'Protein',
      'Carbs',
      'Fat',
      'Fiber',
    ]);
    expect(withRange.macros.last.targetValue, isNull);
    expect(withRange.macros.last.nutrientId, 'fibre');
    expect(withRange.macros.last.value, '21');
    expect(withRange.macros.last.isAvailable, isTrue);

    final partial = TodayNutritionPresentation.from(
      TodayDomainRead.available(_partialNutrition()),
      loading: false,
      goal: TodayDomainRead.available(_goal()),
    );
    final protein = partial.macros.first;
    expect(protein.isAvailable, isFalse);
    expect(protein.value, '—');
    expect(partial.hasIncompleteNutrition, isTrue);
    expect(partial.headline, 'Some nutrition details are incomplete');

    final noTarget = TodayNutritionPresentation.from(
      TodayDomainRead.available(_populatedNutrition()),
      loading: false,
      goal: const TodayDomainRead<NutritionGoalVersionReadModel?>.available(
        null,
      ),
    );
    expect(noTarget.hasAcceptedCalorieTarget, isFalse);
    expect(noTarget.calories?.targetValue, isNull);
  });

  test('Today reads the accepted B04 target under its profile owner', () async {
    final profileId = await database
        .into(database.userProfiles)
        .insert(UserProfilesCompanion.insert());
    await NutritionGoalRepository(database: database).recordUserSetGoal(
      NutritionGoalCommand(
        userId: profileId.toString(),
        goalType: NutritionGoalType.custom,
        calorieTargetKcal: 2200,
        proteinTargetG: 150,
        carbsTargetG: 250,
        fatTargetG: 70,
        effectiveFromLocalDate: '2026-08-09',
        timezoneId: 'Asia/Kolkata',
      ),
    );
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        nutritionRegistryProvider.overrideWith((ref) async => registry),
        localTimezoneServiceProvider.overrideWithValue(
          LocalTimezoneService(read: () async => 'Asia/Kolkata'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final beforeEffectiveDate = await container.read(
      todaySurfaceSnapshotProvider(DateTime(2026, 8, 8)).future,
    );
    final snapshot = await container.read(
      todaySurfaceSnapshotProvider(DateTime(2026, 8, 9)).future,
    );
    final presentation = TodayNutritionPresentation.from(
      snapshot.nutrition,
      loading: false,
      goal: snapshot.goal,
    );

    expect(beforeEffectiveDate.goal.value, isNull);
    expect(snapshot.goal.value?.userId, profileId.toString());
    expect(presentation.calories?.targetValue, 2200);
    expect(presentation.hasAcceptedCalorieTarget, isTrue);
  });

  test(
    'scheduled occurrence remains identity-owned and does not start in history',
    () {
      final item = _scheduledWorkout();
      final snapshot = _snapshot(
        DateTime(2026, 8, 9),
        calendar: CalendarReadSnapshot(
          rangeOccurrences: [item],
          overdueOccurrences: const [],
          activeProgramVersionId: item.version.id,
          activeProgramName: item.program.name,
        ),
      );

      final today = todayFocusPresentation(
        dateRelation: TodayDateRelation.today,
        snapshot: snapshot,
      );
      final past = todayFocusPresentation(
        dateRelation: TodayDateRelation.past,
        snapshot: snapshot,
      );
      expect(today.action, TodayNextAction.startWorkout);
      expect(today.workout, same(item));
      expect(past.action, TodayNextAction.openWorkoutPlan);
    },
  );

  testWidgets('meal quick-add preserves the selected meal and date', (
    tester,
  ) async {
    String? openedMeal;
    await tester.pumpWidget(
      _todayApp(
        theme: AppTheme.darkTheme,
        personalization: personalization,
        snapshot: _snapshot(DateTime(2026, 8, 9)),
        selectedDate: DateTime(2026, 8, 9),
        onLogMealForMeal: (meal) async => openedMeal = meal,
      ),
    );
    await _settleToday(tester);

    await tester.ensureVisible(find.bySemanticsLabel('Add Lunch'));
    await tester.tap(find.bySemanticsLabel('Add Lunch'));
    expect(openedMeal, 'lunch');
    expect(tester.takeException(), isNull);
  });

  testWidgets('scheduled next-up starts the exact B01 occurrence', (
    tester,
  ) async {
    final item = _scheduledWorkout();
    CalendarOccurrenceReadItem? started;
    await tester.pumpWidget(
      _todayApp(
        theme: AppTheme.darkTheme,
        personalization: personalization,
        snapshot: _snapshot(
          DateTime(2026, 8, 9),
          calendar: CalendarReadSnapshot(
            rangeOccurrences: [item],
            overdueOccurrences: const [],
            activeProgramVersionId: item.version.id,
            activeProgramName: item.program.name,
          ),
        ),
        onStartWorkout: (value) async => started = value,
      ),
    );
    await _settleToday(tester);

    final start = find.bySemanticsLabel('Start workout');
    await tester.ensureVisible(start);
    await tester.tap(start);
    expect(started, same(item));
  });

  testWidgets('Next Up does not duplicate a non-startable workout CTA', (
    tester,
  ) async {
    final item = _scheduledWorkout(status: 'completed');
    await tester.pumpWidget(
      _todayApp(
        theme: AppTheme.darkTheme,
        personalization: personalization,
        snapshot: _snapshot(
          DateTime(2026, 8, 9),
          calendar: CalendarReadSnapshot(
            rangeOccurrences: [item],
            overdueOccurrences: const [],
            activeProgramVersionId: item.version.id,
            activeProgramName: item.program.name,
          ),
        ),
      ),
    );
    await _settleToday(tester);

    expect(find.bySemanticsLabel('View workout'), findsOneWidget);
  });

  testWidgets('Next Up hides when there is no canonical next action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _todayApp(
        theme: AppTheme.darkTheme,
        personalization: personalization,
        snapshot: _populatedSnapshot(DateTime(2026, 8, 9)),
      ),
    );
    await _settleToday(tester);

    expect(find.bySemanticsLabel('Choose workout'), findsNothing);
  });

  testWidgets('meal source refresh redraws subtotal, ring, and macros', (
    tester,
  ) async {
    String? openedMeal;
    final container = ProviderContainer(
      overrides: [
        dashboardPersonalizationControllerProvider.overrideWith(
          (ref) => personalization,
        ),
        todaySurfaceSnapshotProvider.overrideWith(
          (ref, date) async => ref.watch(_refreshSnapshotProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(_refreshSnapshotProvider.notifier).state = _snapshot(
      DateTime(2026, 8, 9),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _todaySurface(
          theme: AppTheme.darkTheme,
          selectedDate: DateTime(2026, 8, 9),
          onLogMealForMeal: (meal) async => openedMeal = meal,
        ),
      ),
    );
    await _settleToday(tester);
    final addBreakfast = find.bySemanticsLabel('Add Breakfast');
    await tester.ensureVisible(addBreakfast);
    await tester.tap(addBreakfast);
    expect(openedMeal, 'breakfast');

    container.read(_refreshSnapshotProvider.notifier).state =
        _populatedSnapshot(DateTime(2026, 8, 9));
    await _settleToday(tester);
    expect(find.bySemanticsLabel(RegExp(r'Calories.*1,840')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Breakfast.*420')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Protein:.*118.*150')), findsOneWidget);
  });

  testWidgets(
    'future selection shows planning state rather than current start state',
    (tester) async {
      final item = _scheduledWorkout();
      await tester.pumpWidget(
        _todayApp(
          theme: AppTheme.darkTheme,
          personalization: personalization,
          selectedDate: DateTime(2026, 8, 10),
          now: DateTime(2026, 8, 9, 18),
          snapshot: _snapshot(
            DateTime(2026, 8, 10),
            calendar: CalendarReadSnapshot(
              rangeOccurrences: [item],
              overdueOccurrences: const [],
              activeProgramVersionId: item.version.id,
              activeProgramName: item.program.name,
            ),
          ),
        ),
      );
      await _settleToday(tester);

      expect(find.text('Plan ahead'), findsOneWidget);
      expect(find.bySemanticsLabel('Start workout'), findsNothing);
      expect(find.bySemanticsLabel('Today'), findsOneWidget);
    },
  );

  testWidgets('Today renders dark empty/new-user state', (tester) async {
    await _goldenToday(
      tester,
      personalization: personalization,
      theme: AppTheme.darkTheme,
      snapshot: _snapshot(DateTime(2026, 8, 9)),
      file: 'goldens/ux_r02_today_dark_empty.png',
    );
  });

  testWidgets('Today renders dark populated nutrition state', (tester) async {
    await _goldenToday(
      tester,
      personalization: personalization,
      theme: AppTheme.darkTheme,
      snapshot: _populatedSnapshot(DateTime(2026, 8, 9)),
      file: 'goldens/ux_r02_today_dark_populated.png',
    );
  });

  testWidgets('Today renders dark over-target nutrition state', (tester) async {
    await _goldenToday(
      tester,
      personalization: personalization,
      theme: AppTheme.darkTheme,
      snapshot: _overTargetSnapshot(DateTime(2026, 8, 9)),
      file: 'goldens/ux_r02_today_dark_over_target.png',
    );
  });

  testWidgets('Today renders dark partial nutrition state without false zero', (
    tester,
  ) async {
    await _goldenToday(
      tester,
      personalization: personalization,
      theme: AppTheme.darkTheme,
      snapshot: _partialSnapshot(DateTime(2026, 8, 9)),
      file: 'goldens/ux_r02_today_dark_partial.png',
    );
  });

  testWidgets('Today renders light populated nutrition state', (tester) async {
    await _goldenToday(
      tester,
      personalization: personalization,
      theme: AppTheme.lightTheme,
      snapshot: _populatedSnapshot(DateTime(2026, 8, 9)),
      file: 'goldens/ux_r02_today_light_populated.png',
    );
  });

  testWidgets('Today remains compact at 320 points', (tester) async {
    await _goldenToday(
      tester,
      personalization: personalization,
      theme: AppTheme.darkTheme,
      snapshot: _populatedSnapshot(DateTime(2026, 8, 9)),
      size: const Size(320, 568),
      file: 'goldens/ux_r02_today_dark_320.png',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today remains usable at 2x text with reduced motion', (
    tester,
  ) async {
    await _goldenToday(
      tester,
      personalization: personalization,
      theme: AppTheme.darkTheme,
      snapshot: _populatedSnapshot(DateTime(2026, 8, 9)),
      textScale: 2,
      disableAnimations: true,
      file: 'goldens/ux_r02_today_dark_2x.png',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today has no layout errors at 1.5x text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _todayApp(
        theme: AppTheme.lightTheme,
        personalization: personalization,
        snapshot: _populatedSnapshot(DateTime(2026, 8, 9)),
        textScale: 1.5,
        disableAnimations: true,
      ),
    );
    await _settleToday(tester);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _goldenToday(
  WidgetTester tester, {
  required DashboardPersonalizationController personalization,
  required ThemeData theme,
  required TodaySurfaceSnapshot snapshot,
  required String file,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _todayApp(
      theme: theme,
      personalization: personalization,
      snapshot: snapshot,
      selectedDate: snapshot.selectedDate,
      textScale: textScale,
      disableAnimations: disableAnimations,
    ),
  );
  await _settleToday(tester);
  await expectLater(
    find.byType(TodayDailyActionSurface),
    matchesGoldenFile(file),
  );
}

Future<void> _settleToday(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _todayApp({
  Key? key,
  required ThemeData theme,
  required DashboardPersonalizationController personalization,
  required TodaySurfaceSnapshot snapshot,
  DateTime? selectedDate,
  DateTime? now,
  double textScale = 1,
  bool disableAnimations = true,
  Future<void> Function(String mealType)? onLogMealForMeal,
  Future<void> Function(CalendarOccurrenceReadItem item)? onStartWorkout,
}) {
  final selected = selectedDate ?? snapshot.selectedDate;
  return ProviderScope(
    key: key,
    overrides: [
      dashboardPersonalizationControllerProvider.overrideWith(
        (ref) => personalization,
      ),
      todaySurfaceSnapshotProvider.overrideWith((ref, date) async => snapshot),
    ],
    child: _todaySurface(
      theme: theme,
      selectedDate: selected,
      now: now,
      textScale: textScale,
      disableAnimations: disableAnimations,
      onLogMealForMeal: onLogMealForMeal,
      onStartWorkout: onStartWorkout,
    ),
  );
}

Widget _todaySurface({
  required ThemeData theme,
  required DateTime selectedDate,
  DateTime? now,
  double textScale = 1,
  bool disableAnimations = true,
  Future<void> Function(String mealType)? onLogMealForMeal,
  Future<void> Function(CalendarOccurrenceReadItem item)? onStartWorkout,
}) => MediaQuery(
  data: MediaQueryData(
    textScaler: TextScaler.linear(textScale),
    disableAnimations: disableAnimations,
  ),
  child: MaterialApp(
    theme: theme,
    home: TodayDailyActionSurface(
      selectedDate: selectedDate,
      now: now ?? DateTime(2026, 8, 9, 18),
      userName: 'Ari',
      streakCount: 3,
      onDateChanged: (_) {},
      onRefresh: () async {},
      onOpenSettings: () {},
      onCustomize: () {},
      onOpenWorkoutPlan: () {},
      onLogMeal: () {},
      onLogMealForMeal: onLogMealForMeal,
      onStartWorkout: onStartWorkout,
    ),
  ),
);

TodaySurfaceSnapshot _snapshot(
  DateTime date, {
  NutritionDailyReadModel? nutrition,
  CalendarReadSnapshot? calendar,
  B02ProgressReadModel? progress,
  NutritionGoalVersionReadModel? goal,
}) => TodaySurfaceSnapshot(
  selectedDate: date,
  localDate: todaySurfaceDateKey(date),
  timezoneId: 'Asia/Kolkata',
  calendar: TodayDomainRead.available(
    calendar ??
        const CalendarReadSnapshot(
          rangeOccurrences: [],
          overdueOccurrences: [],
          activeProgramVersionId: null,
          activeProgramName: null,
        ),
  ),
  progress: TodayDomainRead.available(progress ?? _emptyProgress()),
  nutrition: TodayDomainRead.available(nutrition ?? _emptyNutrition()),
  goal: TodayDomainRead.available(goal),
);

TodaySurfaceSnapshot _populatedSnapshot(DateTime date) => _snapshot(
  date,
  nutrition: _populatedNutrition(),
  progress: _progressWithActivity(),
  goal: _goal(),
);

TodaySurfaceSnapshot _overTargetSnapshot(DateTime date) => _snapshot(
  date,
  nutrition: _overTargetNutrition(),
  progress: _progressWithActivity(),
  goal: _goal(),
);

TodaySurfaceSnapshot _partialSnapshot(DateTime date) => _snapshot(
  date,
  nutrition: _partialNutrition(),
  progress: _progressWithActivity(),
  goal: _goal(),
);

NutritionGoalVersionReadModel _goal() => NutritionGoalVersionReadModel(
  id: 'goal-r02',
  userId: 'local-nutrition-user',
  versionNumber: 1,
  goalType: NutritionGoalType.custom,
  source: NutritionGoalSource.userSet,
  calorieTargetKcal: 2200,
  proteinTargetG: 150,
  carbsTargetG: 250,
  fatTargetG: 70,
  policyVersion: null,
  calculationVersion: null,
  algorithmVersion: null,
  effectiveFromLocalDate: '2026-08-01',
  effectiveToLocalDate: null,
  timezoneId: 'Asia/Kolkata',
  supersedesGoalVersionId: null,
  evidenceFingerprint: null,
  exactResultNumerator: null,
  exactResultDenominator: null,
  normalizedMaintenanceKcal: null,
  createdAtUtc: DateTime.utc(2026, 8, 1),
);

NutritionDailyReadModel _emptyNutrition() =>
    _nutrition(facts: const {}, records: const []);

NutritionDailyReadModel _populatedNutrition() => _nutrition(
  facts: {
    'energy': _known('energy', 1840, NutrientUnit.kilocalorie),
    'protein': _known('protein', 118, NutrientUnit.gram),
    'carbohydrate': _known('carbohydrate', 192, NutrientUnit.gram),
    'fat': _known('fat', 58, NutrientUnit.gram),
    'fibre': _known('fibre', 21, NutrientUnit.gram),
  },
  records: _mealRecords(),
);

NutritionDailyReadModel _overTargetNutrition() => _nutrition(
  facts: {
    'energy': _known('energy', 2265, NutrientUnit.kilocalorie),
    'protein': _known('protein', 160, NutrientUnit.gram),
    'carbohydrate': _known('carbohydrate', 278, NutrientUnit.gram),
    'fat': _known('fat', 74, NutrientUnit.gram),
    'fibre': _known('fibre', 28, NutrientUnit.gram),
  },
  records: const [
    _FixtureRecord(
      stableId: 'breakfast-over',
      mealCategory: 'breakfast',
      displayLabel: 'Breakfast',
      calories: 420,
    ),
    _FixtureRecord(
      stableId: 'lunch-over',
      mealCategory: 'lunch',
      displayLabel: 'Lunch',
      calories: 785,
    ),
    _FixtureRecord(
      stableId: 'dinner-over',
      mealCategory: 'dinner',
      displayLabel: 'Dinner',
      calories: 720,
    ),
    _FixtureRecord(
      stableId: 'snack-over',
      mealCategory: 'snack',
      displayLabel: 'Snacks',
      calories: 340,
    ),
  ],
);

NutritionDailyReadModel _partialNutrition() => _nutrition(
  facts: {
    'energy': _known('energy', 1840, NutrientUnit.kilocalorie),
    'carbohydrate': _known('carbohydrate', 192, NutrientUnit.gram),
    'fat': _known('fat', 58, NutrientUnit.gram),
    'fibre': _known('fibre', 21, NutrientUnit.gram),
  },
  records: _mealRecords(),
  missingNutrientIds: const ['protein'],
);

List<NutritionHistoricalReadRecord> _mealRecords() => const [
  _FixtureRecord(
    stableId: 'breakfast',
    mealCategory: 'breakfast',
    displayLabel: 'Breakfast',
    calories: 420,
  ),
  _FixtureRecord(
    stableId: 'lunch',
    mealCategory: 'lunch',
    displayLabel: 'Lunch',
    calories: 680,
  ),
  _FixtureRecord(
    stableId: 'dinner',
    mealCategory: 'dinner',
    displayLabel: 'Dinner',
    calories: 560,
  ),
  _FixtureRecord(
    stableId: 'snack',
    mealCategory: 'snack',
    displayLabel: 'Snacks',
    calories: 180,
  ),
];

NutritionDailyReadModel _nutrition({
  required Map<String, NutrientFact> facts,
  required List<NutritionHistoricalReadRecord> records,
  List<String> missingNutrientIds = const [],
}) => NutritionDailyReadModel(
  userId: 'local-nutrition-user',
  localDate: '2026-08-09',
  records: records,
  recordIds: [for (final record in records) record.stableId],
  totals: _aggregation(facts, missingNutrientIds: missingNutrientIds),
  sourceCounts: const {},
  issues: const [],
);

NutrientAggregationResult _aggregation(
  Map<String, NutrientFact> facts, {
  List<String> missingNutrientIds = const [],
}) {
  final available = facts.entries
      .where((entry) => entry.value.isAvailable)
      .map((entry) => entry.key)
      .toList();
  final estimated = facts.entries
      .where((entry) => entry.value.status == NutrientFactStatus.estimated)
      .map((entry) => entry.key)
      .toList();
  return NutrientAggregationResult(
    facts: facts,
    completeness: NutrientCompleteness(
      state: missingNutrientIds.isEmpty
          ? NutrientCompletenessState.complete
          : NutrientCompletenessState.partial,
      requestedNutrientIds: [...facts.keys, ...missingNutrientIds],
      availableNutrientIds: available,
      missingNutrientIds: missingNutrientIds,
      estimatedNutrientIds: estimated,
      notApplicableNutrientIds: const [],
      partiallyKnownNutrientIds: const [],
    ),
    sourceLineage: const {},
    factVersionLineage: const {},
  );
}

NutrientFact _known(String id, num amount, NutrientUnit unit) =>
    NutrientFact.known(
      nutrientId: id,
      point: _amount(amount, unit),
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: NutrientSourceType.userEntered,
    );

NutrientFact _estimatedRange(
  String id,
  num point,
  num lower,
  num upper,
  NutrientUnit unit,
) => NutrientFact.estimated(
  nutrientId: id,
  point: _amount(point, unit),
  lower: _amount(lower, unit),
  upper: _amount(upper, unit),
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: NutrientSourceType.userEntered,
);

NutrientAmount _amount(num value, NutrientUnit unit) =>
    NutrientAmount(value: QuantityAmount.fromNum(value), unit: unit);

B02ProgressReadModel _emptyProgress() => const B02ProgressReadModel(
  query: B02ProgressQuery(
    startLocalDate: '2026-08-03',
    endLocalDate: '2026-08-09',
    timezoneId: 'Asia/Kolkata',
  ),
  activityHistory: [],
  groupHistory: null,
  targetEvidence: null,
  muscleVolume: null,
);

B02ProgressReadModel _progressWithActivity() => B02ProgressReadModel(
  query: const B02ProgressQuery(
    startLocalDate: '2026-08-03',
    endLocalDate: '2026-08-09',
    timezoneId: 'Asia/Kolkata',
  ),
  activityHistory: [
    B02ProgressActivityRecord(
      sessionId: 1,
      name: 'Push session',
      activityType: B02ActivityType.strength,
      recordKind: B02HistoryRecordKind.canonical,
      completedAtUtc: DateTime.utc(2026, 8, 8, 9),
      durationSeconds: 2700,
      source: B02ActivitySource.manual,
      legacySetCount: 0,
      performedExerciseCount: 5,
      performedGroupCount: 0,
      cardioIntervalCount: 0,
      hasCardioDetail: false,
      hasMobilityDetail: false,
      cardioDetail: null,
      mobilityDetail: null,
    ),
  ],
  groupHistory: null,
  targetEvidence: null,
  muscleVolume: null,
);

class _FixtureRecord implements NutritionHistoricalReadRecord {
  const _FixtureRecord({
    required this.stableId,
    required this.mealCategory,
    required this.displayLabel,
    required this.calories,
  });

  @override
  final String stableId;
  @override
  final String mealCategory;
  @override
  final String displayLabel;
  final double calories;

  @override
  String get userId => 'local-nutrition-user';
  @override
  String get sourceType => 'test';
  @override
  DateTime get loggedAtUtc => DateTime.utc(2026, 8, 9, 8);
  @override
  String get localDate => '2026-08-09';
  @override
  String? get mealGroupId => null;
  @override
  NutrientCompleteness get completeness => _aggregation({
    'energy': _known('energy', calories, NutrientUnit.kilocalorie),
  }).completeness;
  @override
  NutrientAggregationResult get totals => _aggregation({
    'energy': _known('energy', calories, NutrientUnit.kilocalorie),
  });
  @override
  List<NutritionHistoricalReadItem> get items => const [];
  @override
  List<NutritionCompatibilityIssue> get issues => const [];
  @override
  bool get isLegacy => false;
}

CalendarOccurrenceReadItem _scheduledWorkout({String status = 'planned'}) {
  final created = DateTime.utc(2026, 8, 1);
  return CalendarOccurrenceReadItem(
    occurrence: ScheduledSessionOccurrence(
      id: 'r02-occurrence',
      programVersionId: 'r02-version',
      sessionTemplateId: 'r02-template',
      programBlockOrdinal: 0,
      programWeekOrdinal: 0,
      sessionOrdinal: 0,
      repeatOrdinal: 0,
      originalLocalDate: '2026-08-09',
      originalTimezoneId: 'Asia/Kolkata',
      effectiveLocalDate: '2026-08-09',
      effectiveTimezoneId: 'Asia/Kolkata',
      status: status,
      progressionDisposition: 'pending',
      createdAtUtc: created,
    ),
    template: SessionTemplate(
      id: 'r02-template',
      programWeekId: 'r02-week',
      ordinal: 0,
      name: 'Push day',
      plannedWeekday: DateTime.sunday,
      activityType: 'strength',
    ),
    week: const ProgramWeek(
      id: 'r02-week',
      programVersionId: 'r02-version',
      programBlockId: 'r02-block',
      ordinalInBlock: 0,
      programWeekOrdinal: 0,
      isDeload: false,
    ),
    block: const ProgramBlock(
      id: 'r02-block',
      programVersionId: 'r02-version',
      ordinal: 0,
      name: 'Foundation',
    ),
    version: ProgramVersion(
      id: 'r02-version',
      programId: 'r02-program',
      versionNumber: 1,
      status: 'published',
      origin: 'authoring',
      createdAtUtc: created,
    ),
    program: Program(
      id: 'r02-program',
      name: 'Strength plan',
      createdAtUtc: created,
    ),
    prescriptions: const [
      ExercisePrescription(
        id: 'r02-prescription-1',
        sessionTemplateId: 'r02-template',
        ordinal: 0,
        exerciseNameSnapshot: 'Bench press',
        plannedSets: 3,
        repsRange: '8–10',
      ),
      ExercisePrescription(
        id: 'r02-prescription-2',
        sessionTemplateId: 'r02-template',
        ordinal: 1,
        exerciseNameSnapshot: 'Shoulder press',
        plannedSets: 3,
        repsRange: '8–10',
      ),
    ],
    isOverdue: false,
    isDeload: false,
    isNextRequired: true,
  );
}
