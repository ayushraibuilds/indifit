import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/presentation/today_onboarding_handoff.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_progress_read_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/dashboard_personalization_repository.dart';
import 'package:indifit/data/repositories/nutrition_target_authority.dart';
import 'package:indifit/features/coaching/coaching_providers.dart';
import 'package:indifit/features/dashboard/dashboard_module_registry.dart';
import 'package:indifit/features/dashboard/dashboard_personalization_controller.dart';
import 'package:indifit/features/dashboard/today_daily_action_surface.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/dashboard/today_week_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T1: one-block header, week strip, one-line banners and the training row.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  final today = DateTime(2026, 10, 12);

  group('Gate: ring and macros above the fold on iPhone 17', () {
    for (final themeMode in [ThemeMode.dark, ThemeMode.light]) {
      for (final scale in [1.0, 1.35]) {
        testWidgets('${themeMode.name}, ${scale}x text, targets banner on', (
          tester,
        ) async {
          _iPhone17(tester, textScale: scale);
          SharedPreferences.setMockInitialValues({
            todayOnboardingHandoffPendingKey: true,
          });
          await tester.pumpWidget(
            _app(
              database: database,
              selectedDate: today,
              themeMode: themeMode,
              withTabBar: true,
            ),
          );
          await _settle(tester);

          expect(find.byKey(const ValueKey('today_targets_ready')), findsOne);
          final fold = tester.getTopLeft(find.byType(NavigationBar)).dy;
          final ring = tester.getRect(
            find.byKey(const Key('today_calorie_ring')),
          );
          expect(ring.bottom, lessThanOrEqualTo(fold), reason: 'ring');
          for (final label in ['Protein', 'Carbs', 'Fat', 'Fiber']) {
            final bottom = tester.getBottomLeft(find.text(label).first).dy;
            expect(bottom, lessThanOrEqualTo(fold), reason: label);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('week strip shows the last seven days and switches day', (
    tester,
  ) async {
    _iPhone17(tester);
    DateTime? picked;
    await tester.pumpWidget(
      _app(
        database: database,
        selectedDate: today,
        onDateChanged: (date) => picked = date,
      ),
    );
    await _settle(tester);

    for (var day = 6; day <= 12; day++) {
      expect(find.byKey(ValueKey('today-week-day-$day')), findsOne);
    }
    expect(find.byKey(const ValueKey('today-week-day-5')), findsNothing);
    expect(find.byKey(const ValueKey('dashboard-date-bar-row')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('today-week-day-9')));
    expect(picked, DateTime(2026, 10, 9));
    expect(
      find.bySemanticsLabel(RegExp(r'^Today, Monday 12 October')),
      findsOne,
    );
  });

  testWidgets('past day shows its date with a way back to today', (
    tester,
  ) async {
    _iPhone17(tester);
    DateTime? picked;
    final past = DateTime(2026, 10, 9);
    await tester.pumpWidget(
      _app(
        database: database,
        selectedDate: past,
        now: today,
        onDateChanged: (date) => picked = date,
      ),
    );
    await _settle(tester);

    expect(find.text('Past day · Friday, 9 October'), findsOne);
    await tester.tap(find.byKey(const ValueKey('today-header-go-today')));
    expect(picked, today);
  });

  testWidgets('streak chip keeps its place before the streak loads', (
    tester,
  ) async {
    _iPhone17(tester);
    await tester.pumpWidget(
      _app(database: database, selectedDate: today, streakLoaded: false),
    );
    await _settle(tester);
    final before = tester.getRect(find.byType(TodayStreakChip));
    final greetingBefore = tester.getRect(find.textContaining('Maya'));
    expect(find.bySemanticsLabel(RegExp('days logged')), findsNothing);

    await tester.pumpWidget(_app(database: database, selectedDate: today));
    await _settle(tester);
    expect(tester.getRect(find.byType(TodayStreakChip)), before);
    expect(tester.getRect(find.textContaining('Maya')), greetingBefore);
    expect(find.bySemanticsLabel('5 days logged in a row'), findsOne);
    expect(find.text('5'), findsOne);
  });

  testWidgets('training row: no plan opens the plan library', (tester) async {
    _iPhone17(tester);
    var chose = 0;
    var plan = 0;
    await tester.pumpWidget(
      _app(
        database: database,
        selectedDate: today,
        onChooseTrainingPlan: () => chose++,
        onOpenWorkoutPlan: () => plan++,
      ),
    );
    await _settle(tester);

    final row = find.byKey(const ValueKey('today-training-row'));
    await tester.scrollUntilVisible(row, 200);
    expect(find.text('Choose a plan'), findsOne);
    await tester.tap(row);
    expect((chose, plan), (1, 0));
  });

  testWidgets('training row: a plan with nothing today is a rest day', (
    tester,
  ) async {
    _iPhone17(tester);
    var plan = 0;
    await tester.pumpWidget(
      _app(
        database: database,
        selectedDate: today,
        activeProgramVersionId: 'plan-v1',
        onOpenWorkoutPlan: () => plan++,
      ),
    );
    await _settle(tester);

    final row = find.byKey(const ValueKey('today-training-row'));
    await tester.scrollUntilVisible(row, 200);
    expect(find.text('Rest day'), findsOne);
    await tester.tap(row);
    expect(plan, 1);
  });

  testWidgets('training row stays off past days', (tester) async {
    _iPhone17(tester);
    await tester.pumpWidget(
      _app(database: database, selectedDate: DateTime(2026, 10, 9), now: today),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('today-training-row')), findsNothing);
  });

  test('week window ends today unless the day is outside it', () {
    expect(todayWeekEnd(selected: DateTime(2026, 10, 7), today: today), today);
    expect(
      todayWeekEnd(selected: DateTime(2026, 10, 1), today: today),
      DateTime(2026, 10, 1),
    );
    expect(
      todayWeekEnd(selected: DateTime(2026, 10, 20), today: today),
      DateTime(2026, 10, 20),
    );
    expect(todayWeekDates(today).first, DateTime(2026, 10, 6));
  });

  test('a day over target fills the mini ring; no target has no share', () {
    final over = TodayWeekDay(
      date: today,
      logged: true,
      kcal: 3000,
      targetKcal: 2000,
    );
    final noTarget = TodayWeekDay(date: today, logged: true, kcal: 500);
    expect(over.progress, 1);
    expect(noTarget.progress, isNull);
  });
}

void _iPhone17(WidgetTester tester, {double textScale = 1}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 2));
}

Widget _app({
  required AppDatabase database,
  required DateTime selectedDate,
  DateTime? now,
  ThemeMode themeMode = ThemeMode.dark,
  bool withTabBar = false,
  bool streakLoaded = true,
  String? activeProgramVersionId,
  ValueChanged<DateTime>? onDateChanged,
  VoidCallback? onChooseTrainingPlan,
  VoidCallback? onOpenWorkoutPlan,
}) {
  final reference = now ?? selectedDate;
  final key = _key(selectedDate);
  final snapshot = TodaySurfaceSnapshot(
    selectedDate: selectedDate,
    localDate: key,
    timezoneId: 'Asia/Kolkata',
    calendar: TodayDomainRead.available(
      CalendarReadSnapshot(
        rangeOccurrences: const [],
        overdueOccurrences: const [],
        activeProgramVersionId: activeProgramVersionId,
        activeProgramName: activeProgramVersionId == null ? null : 'Plan',
      ),
    ),
    progress: TodayDomainRead.available(
      B02ProgressReadModel(
        query: B02ProgressQuery(
          startLocalDate: key,
          endLocalDate: key,
          timezoneId: 'Asia/Kolkata',
        ),
        activityHistory: const [],
        groupHistory: null,
        targetEvidence: null,
        muscleVolume: null,
      ),
    ),
    nutrition: TodayDomainRead.available(_daily(key)),
    targets: TodayDomainRead.available(_targets(key)),
  );
  final weekEnd = todayWeekEnd(selected: selectedDate, today: reference);
  final surface = TodayDailyActionSurface(
    selectedDate: selectedDate,
    now: reference,
    userName: 'Maya',
    streakCount: 5,
    streakLoaded: streakLoaded,
    onDateChanged: onDateChanged ?? (_) {},
    onRefresh: () async {},
    onOpenSettings: () {},
    onCustomize: () {},
    onOpenWorkoutPlan: onOpenWorkoutPlan ?? () {},
    onLogMeal: () {},
    onChooseTrainingPlan: onChooseTrainingPlan,
  );
  return ProviderScope(
    overrides: [
      b04ProductionRecommendationContextProvider.overrideWith(
        (ref) async => throw StateError('No recommendations in this fixture.'),
      ),
      dashboardPersonalizationControllerProvider.overrideWith(
        (ref) => DashboardPersonalizationController(
          repository: DashboardPersonalizationRepository(
            database: database,
            registry: standardDashboardModuleRegistry,
          ),
          userId: 'local-nutrition-user',
        ),
      ),
      todaySurfaceSnapshotProvider(
        selectedDate,
      ).overrideWith((ref) async => snapshot),
      todayWeekDaysProvider(weekEnd).overrideWith(
        (ref) async => {
          for (final date in todayWeekDates(weekEnd))
            _key(date): TodayWeekDay(
              date: date,
              logged: date.day.isEven,
              kcal: date.day.isEven ? 1800 : 0,
              targetKcal: 2546,
            ),
        },
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Scaffold(
        body: surface,
        bottomNavigationBar: withTabBar
            ? NavigationBar(
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.today),
                    label: 'Today',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.fitness_center),
                    label: 'Training',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.restaurant),
                    label: 'Food',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights),
                    label: 'Progress',
                  ),
                ],
              )
            : null,
      ),
    ),
  );
}

String _key(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

NutritionTargetsForDate _targets(String localDate) => NutritionTargetsForDate(
  localDate: localDate,
  timezoneId: 'Asia/Kolkata',
  goalVersion: NutritionGoalVersionReadModel(
    id: 'goal-1',
    userId: 'local-nutrition-user',
    versionNumber: 1,
    goalType: NutritionGoalType.custom,
    source: NutritionGoalSource.userSet,
    calorieTargetKcal: 2546,
    proteinTargetG: 112,
    carbsTargetG: 365,
    fatTargetG: 71,
    policyVersion: null,
    calculationVersion: null,
    algorithmVersion: null,
    effectiveFromLocalDate: localDate,
    effectiveToLocalDate: null,
    timezoneId: 'Asia/Kolkata',
    supersedesGoalVersionId: null,
    evidenceFingerprint: null,
    exactResultNumerator: null,
    exactResultDenominator: null,
    normalizedMaintenanceKcal: null,
    createdAtUtc: DateTime.utc(2026, 10, 1),
  ),
);

NutritionDailyReadModel _daily(String localDate) {
  final facts = <String, NutrientFact>{
    'energy': _known('energy', 345, NutrientUnit.kilocalorie),
    'protein': _known('protein', 9, NutrientUnit.gram),
    'carbohydrate': _known('carbohydrate', 42, NutrientUnit.gram),
    'fat': _known('fat', 16, NutrientUnit.gram),
    'fibre': _known('fibre', 1, NutrientUnit.gram),
  };
  final record = _FixtureRecord(localDate: localDate, calories: 345);
  return NutritionDailyReadModel(
    userId: 'local-nutrition-user',
    localDate: localDate,
    records: [record],
    recordIds: [record.stableId],
    totals: _aggregation(facts),
    sourceCounts: const {},
    issues: const [],
  );
}

NutrientFact _known(String id, num amount, NutrientUnit unit) =>
    NutrientFact.known(
      nutrientId: id,
      point: NutrientAmount(value: QuantityAmount.fromNum(amount), unit: unit),
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: NutrientSourceType.userEntered,
    );

NutrientAggregationResult _aggregation(Map<String, NutrientFact> facts) =>
    NutrientAggregationResult(
      facts: facts,
      completeness: NutrientCompleteness(
        state: NutrientCompletenessState.complete,
        requestedNutrientIds: facts.keys.toList(),
        availableNutrientIds: facts.keys.toList(),
        missingNutrientIds: const [],
        estimatedNutrientIds: const [],
        notApplicableNutrientIds: const [],
        partiallyKnownNutrientIds: const [],
      ),
      sourceLineage: const {},
      factVersionLineage: const {},
    );

class _FixtureRecord implements NutritionHistoricalReadRecord {
  const _FixtureRecord({required this.localDate, required this.calories});

  @override
  final String localDate;
  final double calories;

  @override
  String get stableId => 'rec-1';
  @override
  String get mealCategory => 'lunch';
  @override
  String get displayLabel => 'Gulab jamun';
  @override
  String get userId => 'local-nutrition-user';
  @override
  String get sourceType => 'test';
  @override
  DateTime get loggedAtUtc => DateTime.utc(2026, 10, 12, 8);
  @override
  String? get mealGroupId => null;
  @override
  NutrientCompleteness get completeness => totals.completeness;
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
