import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_progress_read_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/dashboard_personalization_repository.dart';
import 'package:indifit/data/repositories/nutrition_target_authority.dart';
import 'package:indifit/features/dashboard/dashboard_module_registry.dart';
import 'package:indifit/features/dashboard/dashboard_personalization_controller.dart';
import 'package:indifit/features/dashboard/today_daily_action_surface.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets(
    'current-date hero shows nutrition actions but gates Meal Ideas without a B04 card',
    (tester) async {
      final selectedDate = DateTime(2026, 8, 10);
      final daily = _createNutritionDaily(
        localDate: '2026-08-10',
        energyKcal: 1500,
        proteinG: 120,
        carbsG: 180,
        fatG: 50,
        fiberG: 25,
      );
      final target = _createTargetsForDate(
        localDate: '2026-08-10',
        calorieKcal: 2000,
        proteinG: 150,
        carbsG: 200,
        fatG: 65,
      );

      await tester.pumpWidget(
        _buildApp(
          database: database,
          selectedDate: selectedDate,
          now: selectedDate,
          snapshot: _createSnapshot(
            selectedDate: selectedDate,
            nutrition: daily,
            targets: target,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Calorie ring details
      expect(find.text('1,500'), findsOneWidget);
      expect(find.text('of 2,000 kcal'), findsOneWidget);
      expect(find.text('500 left'), findsOneWidget);

      // Macro comparisons
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('120 / 150 g'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('180 / 200 g'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('50 / 65 g'), findsOneWidget);
      expect(find.text('Fiber'), findsOneWidget);
      expect(find.text('25 g'), findsOneWidget);

      // Semantics check
      expect(find.bySemanticsLabel(RegExp(r'Protein: 120 / 150 g')), findsOneWidget);

      // Action buttons
      expect(find.text('Log food'), findsOneWidget);
      expect(find.text('What can I eat?'), findsNothing);
      expect(find.text('View targets'), findsOneWidget);
      expect(find.text('Set a target'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'current-date hero without target shows consumed facts, No daily target set notice, Log food, and Set a target',
    (tester) async {
      final selectedDate = DateTime(2026, 8, 10);
      final daily = _createNutritionDaily(
        localDate: '2026-08-10',
        energyKcal: 650,
        proteinG: 40,
        carbsG: 80,
        fatG: 20,
        fiberG: 10,
      );

      await tester.pumpWidget(
        _buildApp(
          database: database,
          selectedDate: selectedDate,
          now: selectedDate,
          snapshot: _createSnapshot(
            selectedDate: selectedDate,
            nutrition: daily,
            targets: null,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('650'), findsOneWidget);
      expect(find.text('kcal logged'), findsOneWidget);
      expect(find.text('Calories logged'), findsOneWidget);
      expect(find.text('No daily target set'), findsOneWidget);

      // Macro factual values without broken progress bars
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('40 g'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('80 g'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('20 g'), findsOneWidget);
      expect(find.text('Fiber'), findsOneWidget);
      expect(find.text('10 g'), findsOneWidget);

      // Action buttons
      expect(find.text('Log food'), findsOneWidget);
      expect(find.text('What can I eat?'), findsNothing);
      expect(find.text('Set a target'), findsOneWidget);
      expect(find.text('View targets'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'historical past date hero shows truthful facts and GATES OUT What can I eat?',
    (tester) async {
      final selectedDate = DateTime(2026, 8, 8);
      final now = DateTime(2026, 8, 10);
      final daily = _createNutritionDaily(
        localDate: '2026-08-08',
        energyKcal: 1800,
        proteinG: 130,
        carbsG: 210,
        fatG: 55,
        fiberG: 20,
      );
      final target = _createTargetsForDate(
        localDate: '2026-08-08',
        calorieKcal: 2000,
        proteinG: 150,
        carbsG: 200,
        fatG: 65,
      );

      await tester.pumpWidget(
        _buildApp(
          database: database,
          selectedDate: selectedDate,
          now: now,
          snapshot: _createSnapshot(
            selectedDate: selectedDate,
            nutrition: daily,
            targets: target,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('1,800'), findsOneWidget);
      expect(find.text('of 2,000 kcal'), findsOneWidget);
      expect(find.text('200 left'), findsOneWidget);

      expect(find.text('Log food'), findsOneWidget);
      expect(find.text('View targets'), findsOneWidget);
      // Gated out on past date
      expect(find.text('What can I eat?'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'future date hero shows truthful future day target and GATES OUT What can I eat?',
    (tester) async {
      final selectedDate = DateTime(2026, 8, 15);
      final now = DateTime(2026, 8, 10);
      final daily = _createEmptyNutritionDaily(localDate: '2026-08-15');
      final target = _createTargetsForDate(
        localDate: '2026-08-15',
        calorieKcal: 2200,
        proteinG: 160,
        carbsG: 240,
        fatG: 70,
      );

      await tester.pumpWidget(
        _buildApp(
          database: database,
          selectedDate: selectedDate,
          now: now,
          snapshot: _createSnapshot(
            selectedDate: selectedDate,
            nutrition: daily,
            targets: target,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('of 2,200 kcal'), findsOneWidget);
      expect(find.text('2,200 left'), findsOneWidget);

      expect(find.text('Log food'), findsOneWidget);
      expect(find.text('View targets'), findsOneWidget);
      // Gated out on future date
      expect(find.text('What can I eat?'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'over-target hero displays factual overage without moralizing score',
    (tester) async {
      final selectedDate = DateTime(2026, 8, 10);
      final daily = _createNutritionDaily(
        localDate: '2026-08-10',
        energyKcal: 2350,
        proteinG: 165,
        carbsG: 280,
        fatG: 80,
        fiberG: 30,
      );
      final target = _createTargetsForDate(
        localDate: '2026-08-10',
        calorieKcal: 2000,
        proteinG: 150,
        carbsG: 200,
        fatG: 65,
      );

      await tester.pumpWidget(
        _buildApp(
          database: database,
          selectedDate: selectedDate,
          now: selectedDate,
          snapshot: _createSnapshot(
            selectedDate: selectedDate,
            nutrition: daily,
            targets: target,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('2,350'), findsOneWidget);
      expect(find.text('of 2,000 kcal'), findsOneWidget);
      expect(find.text('350 over'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'incomplete nutrition renders single concise notice and fail-safe macro facts',
    (tester) async {
      final selectedDate = DateTime(2026, 8, 10);
      final daily = _createIncompleteNutritionDaily(localDate: '2026-08-10');

      await tester.pumpWidget(
        _buildApp(
          database: database,
          selectedDate: selectedDate,
          now: selectedDate,
          snapshot: _createSnapshot(
            selectedDate: selectedDate,
            nutrition: daily,
            targets: null,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Some nutrition details are incomplete'),
        findsOneWidget,
      );
      expect(find.text('No daily target set'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('loading and unavailable nutrition states behave cleanly', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 8, 10);

    // 1. Loading state
    await tester.pumpWidget(
      _buildApp(
        database: database,
        selectedDate: selectedDate,
        now: selectedDate,
        isLoading: true,
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Preparing nutrition'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    // 2. Unavailable state
    var readCount = 0;
    await tester.pumpWidget(
      _buildApp(
        database: database,
        selectedDate: selectedDate,
        now: selectedDate,
        onReadSnapshot: () {
          readCount++;
          return _createUnavailableSnapshot(selectedDate: selectedDate);
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Nutrition unavailable'), findsOneWidget);
    expect(
      find.text('Try again to load your meals and nutrition.'),
      findsOneWidget,
    );

    // Verify retry button invalidates provider and reads again
    final initialReads = readCount;
    await tester.tap(find.text('Try again').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(readCount, greaterThan(initialReads));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'available nutrition actions trigger Log food and Target navigation',
    (tester) async {
      final selectedDate = DateTime(2026, 8, 10);
      var logFoodCalled = false;
      var targetsCalled = false;

      final daily = _createNutritionDaily(
        localDate: '2026-08-10',
        energyKcal: 1200,
        proteinG: 90,
        carbsG: 140,
        fatG: 40,
        fiberG: 18,
      );
      final target = _createTargetsForDate(
        localDate: '2026-08-10',
        calorieKcal: 2000,
        proteinG: 150,
        carbsG: 200,
        fatG: 65,
      );

      await tester.pumpWidget(
        _buildApp(
          database: database,
          selectedDate: selectedDate,
          now: selectedDate,
          snapshot: _createSnapshot(
            selectedDate: selectedDate,
            nutrition: daily,
            targets: target,
          ),
          onLogMeal: () => logFoodCalled = true,
          onOpenFoodGuidance: () {},
          onOpenNutritionTargets: () => targetsCalled = true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Log food'));
      await tester.pump();
      expect(logFoodCalled, isTrue);

      expect(find.text('What can I eat?'), findsNothing);

      await tester.tap(find.text('View targets'));
      await tester.pump();
      expect(targetsCalled, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'hero renders cleanly without overflow at 320pt width and 2.0x text scaling in dark theme',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final selectedDate = DateTime(2026, 8, 10);
      final daily = _createNutritionDaily(
        localDate: '2026-08-10',
        energyKcal: 1750,
        proteinG: 140,
        carbsG: 190,
        fatG: 60,
        fiberG: 22,
      );
      final target = _createTargetsForDate(
        localDate: '2026-08-10',
        calorieKcal: 2000,
        proteinG: 150,
        carbsG: 200,
        fatG: 65,
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
            disableAnimations: true,
          ),
          child: _buildApp(
            database: database,
            themeMode: ThemeMode.dark,
            selectedDate: selectedDate,
            now: selectedDate,
            snapshot: _createSnapshot(
              selectedDate: selectedDate,
              nutrition: daily,
              targets: target,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Nutrition'), findsOneWidget);
      expect(find.text('1,750'), findsOneWidget);
      expect(find.text('Log food'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

// -----------------------------------------------------------------------------
// Test Helpers & Fixtures
// -----------------------------------------------------------------------------

Widget _buildApp({
  required AppDatabase database,
  required DateTime selectedDate,
  DateTime? now,
  TodaySurfaceSnapshot? snapshot,
  TodaySurfaceSnapshot Function()? onReadSnapshot,
  bool isLoading = false,
  ThemeMode themeMode = ThemeMode.light,
  VoidCallback? onLogMeal,
  VoidCallback? onOpenFoodGuidance,
  VoidCallback? onOpenNutritionTargets,
  Future<void> Function()? onRefresh,
}) {
  return ProviderScope(
    overrides: [
      dashboardPersonalizationControllerProvider.overrideWith(
        (ref) => DashboardPersonalizationController(
          repository: DashboardPersonalizationRepository(
            database: database,
            registry: standardDashboardModuleRegistry,
          ),
          userId: 'local-nutrition-user',
        ),
      ),
      if (isLoading)
        todaySurfaceSnapshotProvider(selectedDate).overrideWith(
          (ref) => Completer<TodaySurfaceSnapshot>().future,
        )
      else if (onReadSnapshot != null)
        todaySurfaceSnapshotProvider(selectedDate).overrideWith(
          (ref) async => onReadSnapshot(),
        )
      else if (snapshot != null)
        todaySurfaceSnapshotProvider(selectedDate).overrideWith(
          (ref) async => snapshot,
        ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Scaffold(
        body: TodayDailyActionSurface(
          selectedDate: selectedDate,
          now: now ?? selectedDate,
          userName: 'Maya',
          streakCount: 5,
          onDateChanged: (_) {},
          onRefresh: onRefresh ?? () async {},
          onOpenSettings: () {},
          onCustomize: () {},
          onOpenWorkoutPlan: () {},
          onLogMeal: onLogMeal ?? () {},
          onOpenFoodGuidance: onOpenFoodGuidance,
          onOpenNutritionTargets: onOpenNutritionTargets,
        ),
      ),
    ),
  );
}

TodaySurfaceSnapshot _createSnapshot({
  required DateTime selectedDate,
  required NutritionDailyReadModel nutrition,
  required NutritionTargetsForDate? targets,
}) {
  final localDate =
      '${selectedDate.year.toString().padLeft(4, '0')}-'
      '${selectedDate.month.toString().padLeft(2, '0')}-'
      '${selectedDate.day.toString().padLeft(2, '0')}';
  return TodaySurfaceSnapshot(
    selectedDate: selectedDate,
    localDate: localDate,
    timezoneId: 'Asia/Kolkata',
    calendar: const TodayDomainRead.available(
      CalendarReadSnapshot(
        rangeOccurrences: [],
        overdueOccurrences: [],
        activeProgramVersionId: null,
        activeProgramName: null,
      ),
    ),
    progress: const TodayDomainRead.available(
      B02ProgressReadModel(
        query: B02ProgressQuery(
          startLocalDate: '2026-08-03',
          endLocalDate: '2026-08-10',
          timezoneId: 'Asia/Kolkata',
        ),
        activityHistory: [],
        groupHistory: null,
        targetEvidence: null,
        muscleVolume: null,
      ),
    ),
    nutrition: TodayDomainRead.available(nutrition),
    targets: TodayDomainRead.available(targets),
  );
}

TodaySurfaceSnapshot _createUnavailableSnapshot({
  required DateTime selectedDate,
}) {
  final localDate =
      '${selectedDate.year.toString().padLeft(4, '0')}-'
      '${selectedDate.month.toString().padLeft(2, '0')}-'
      '${selectedDate.day.toString().padLeft(2, '0')}';
  return TodaySurfaceSnapshot(
    selectedDate: selectedDate,
    localDate: localDate,
    timezoneId: 'Asia/Kolkata',
    calendar: const TodayDomainRead.unavailable('Calendar unavailable'),
    progress: const TodayDomainRead.unavailable('Progress unavailable'),
    nutrition: const TodayDomainRead.unavailable('Nutrition unavailable'),
    targets: const TodayDomainRead.unavailable('Targets unavailable'),
  );
}

NutritionTargetsForDate _createTargetsForDate({
  required String localDate,
  required double calorieKcal,
  required double proteinG,
  required double carbsG,
  required double fatG,
}) {
  return NutritionTargetsForDate(
    localDate: localDate,
    timezoneId: 'Asia/Kolkata',
    goalVersion: NutritionGoalVersionReadModel(
      id: 'goal-1',
      userId: 'local-nutrition-user',
      versionNumber: 1,
      goalType: NutritionGoalType.custom,
      source: NutritionGoalSource.userSet,
      calorieTargetKcal: calorieKcal.round(),
      proteinTargetG: proteinG,
      carbsTargetG: carbsG,
      fatTargetG: fatG,
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
      createdAtUtc: DateTime.utc(2026, 8, 1),
    ),
  );
}

NutritionDailyReadModel _createNutritionDaily({
  required String localDate,
  required double energyKcal,
  required double proteinG,
  required double carbsG,
  required double fatG,
  required double fiberG,
}) {
  final facts = <String, NutrientFact>{
    'energy': _known('energy', energyKcal, NutrientUnit.kilocalorie),
    'protein': _known('protein', proteinG, NutrientUnit.gram),
    'carbohydrate': _known('carbohydrate', carbsG, NutrientUnit.gram),
    'fat': _known('fat', fatG, NutrientUnit.gram),
    'fibre': _known('fibre', fiberG, NutrientUnit.gram),
  };

  final record = _FixtureRecord(
    stableId: 'rec-1',
    mealCategory: 'breakfast',
    displayLabel: 'Breakfast',
    calories: energyKcal,
  );

  return NutritionDailyReadModel(
    userId: 'local-nutrition-user',
    localDate: localDate,
    records: [record],
    recordIds: [record.stableId],
    totals: _makeAggregation(facts),
    sourceCounts: const {},
    issues: const [],
  );
}

NutritionDailyReadModel _createEmptyNutritionDaily({required String localDate}) {
  return NutritionDailyReadModel(
    userId: 'local-nutrition-user',
    localDate: localDate,
    records: const [],
    recordIds: const [],
    totals: _makeAggregation(const {}),
    sourceCounts: const {},
    issues: const [],
  );
}

NutritionDailyReadModel _createIncompleteNutritionDaily({
  required String localDate,
}) {
  final facts = <String, NutrientFact>{
    'energy': _known('energy', 300, NutrientUnit.kilocalorie),
  };

  final record = _FixtureRecord(
    stableId: 'rec-inc-1',
    mealCategory: 'snack',
    displayLabel: 'Snack',
    calories: 300,
  );

  return NutritionDailyReadModel(
    userId: 'local-nutrition-user',
    localDate: localDate,
    records: [record],
    recordIds: [record.stableId],
    totals: _makeAggregation(
      facts,
      missingNutrientIds: const ['protein', 'carbohydrate', 'fat', 'fibre'],
    ),
    sourceCounts: const {},
    issues: const [],
  );
}

NutrientFact _known(String id, num amount, NutrientUnit unit) =>
    NutrientFact.known(
      nutrientId: id,
      point: _amount(amount, unit),
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: NutrientSourceType.userEntered,
    );

NutrientAmount _amount(num value, NutrientUnit unit) =>
    NutrientAmount(value: QuantityAmount.fromNum(value), unit: unit);

NutrientAggregationResult _makeAggregation(
  Map<String, NutrientFact> facts, {
  List<String> missingNutrientIds = const [],
}) {
  final available = facts.entries
      .where((e) => e.value.isAvailable)
      .map((e) => e.key)
      .toList();
  final estimated = facts.entries
      .where((e) => e.value.status == NutrientFactStatus.estimated)
      .map((e) => e.key)
      .toList();
  return NutrientAggregationResult(
    facts: facts,
    completeness: NutrientCompleteness(
      state: missingNutrientIds.isEmpty
          ? (available.isEmpty
              ? NutrientCompletenessState.complete
              : NutrientCompletenessState.complete)
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
  DateTime get loggedAtUtc => DateTime.utc(2026, 8, 10, 8);
  @override
  String get localDate => '2026-08-10';
  @override
  String? get mealGroupId => null;
  @override
  NutrientCompleteness get completeness => _makeAggregation({
    'energy': _known('energy', calories, NutrientUnit.kilocalorie),
  }).completeness;
  @override
  NutrientAggregationResult get totals => _makeAggregation({
    'energy': _known('energy', calories, NutrientUnit.kilocalorie),
  });
  @override
  List<NutritionHistoricalReadItem> get items => const [];
  @override
  List<NutritionCompatibilityIssue> get issues => const [];
  @override
  bool get isLegacy => false;
}
