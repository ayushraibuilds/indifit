import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/models/progress_dashboard_models.dart';
import 'package:indifit/data/repositories/nutrition_goal_repository.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/nutrition_target_authority.dart';
import 'package:indifit/data/repositories/progress_dashboard_read_repository.dart';
import 'package:indifit/features/progress/progress_dashboard_controller.dart';
import 'package:indifit/features/progress/progress_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late LocalScheduleDateService dates;

  setUp(() {
    database = AppDatabase.memory();
    dates = LocalScheduleDateService(
      nowUtc: () => DateTime.utc(2026, 8, 9, 12),
    );
  });

  tearDown(() => database.close());

  test(
    'Progress projects the current B04 goal without leaking it into history',
    () async {
      final profileId = await _insertProfile(database);
      final goals = NutritionGoalRepository(database: database, dates: dates);
      await _recordGoal(
        goals,
        userId: profileId,
        goalType: NutritionGoalType.maintenance,
        calories: 2200,
        protein: 140,
        effectiveFrom: '2026-08-01',
        commandId: 'r08f5-initial',
      );
      await _recordGoal(
        goals,
        userId: profileId,
        goalType: NutritionGoalType.loss,
        calories: 1800,
        protein: 150,
        effectiveFrom: '2026-08-06',
        commandId: 'r08f5-current',
      );

      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      final snapshot = await ProgressDashboardReadRepository(
        database,
        dates: dates,
        nutrition: NutritionReadModelRepository(
          db: database,
          registry: registry,
        ),
        nutritionTargets: NutritionTargetAuthority(goals: goals, dates: dates),
      ).read(nowUtc: DateTime.utc(2026, 8, 6, 8), timezoneId: 'Asia/Kolkata');

      final summary = snapshot.nutritionSummary!;
      expect(summary.targetGoalType, NutritionGoalType.loss);
      expect(summary.targetCaloriesKcal, 1800);
      expect(summary.targetProteinG, 150);
      expect(
        summary.days
            .singleWhere((day) => day.localDate == '2026-08-05')
            .calorieTargetKcal,
        2200,
      );
      expect(
        summary.days
            .singleWhere((day) => day.localDate == '2026-08-06')
            .calorieTargetKcal,
        1800,
      );
      expect(snapshot.weightGoal, isNull);
    },
  );

  test(
    'Progress snapshot invalidates after an established target version write',
    () async {
      final profileId = await _insertProfile(database);
      final goals = NutritionGoalRepository(database: database, dates: dates);
      await _recordGoal(
        goals,
        userId: profileId,
        goalType: NutritionGoalType.maintenance,
        calories: 2200,
        protein: 140,
        effectiveFrom: '2026-01-01',
        commandId: 'r08f5-invalidation-initial',
      );
      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          localScheduleDateServiceProvider.overrideWithValue(dates),
          localTimezoneServiceProvider.overrideWithValue(
            LocalTimezoneService(
              read: () async => 'Asia/Kolkata',
              dates: dates,
            ),
          ),
          nutritionRegistryProvider.overrideWith((_) async => registry),
          nutritionReadModelRepositoryProvider.overrideWith(
            (_) async =>
                NutritionReadModelRepository(db: database, registry: registry),
          ),
        ],
      );
      addTearDown(container.dispose);

      final changed = Completer<ProgressDashboardSnapshot>();
      final subscription = container.listen(progressDashboardSnapshotProvider, (
        _,
        next,
      ) {
        final snapshot = next.valueOrNull;
        if (snapshot?.nutritionSummary?.targetGoalType ==
                NutritionGoalType.gain &&
            !changed.isCompleted) {
          changed.complete(snapshot!);
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);

      final initial = await container.read(
        progressDashboardSnapshotProvider.future,
      );
      expect(
        initial.nutritionSummary?.targetGoalType,
        NutritionGoalType.maintenance,
      );

      await _recordGoal(
        goals,
        userId: profileId,
        goalType: NutritionGoalType.gain,
        calories: 2500,
        protein: 160,
        effectiveFrom: '2026-01-02',
        commandId: 'r08f5-invalidation-current',
      );

      final refreshed = await changed.future.timeout(
        const Duration(seconds: 2),
      );
      expect(refreshed.nutritionSummary?.targetCaloriesKcal, 2500);
      expect(refreshed.nutritionSummary?.targetProteinG, 160);
    },
  );

  testWidgets('Progress presents factual target context and routes to owner', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final observer = _RecordingNavigatorObserver();
    await _pump(
      tester,
      _snapshot(
        targetCalories: 2200,
        targetProtein: 140,
        targetGoalType: NutritionGoalType.gain,
      ),
      database: database,
      dates: dates,
      observer: observer,
    );

    expect(find.text('Today’s nutrition target'), findsOneWidget);
    expect(find.text('2,200 kcal · 140 g protein'), findsOneWidget);
    expect(find.text('Fitness goal: Build muscle'), findsOneWidget);
    expect(find.text('Nutrition strategy: Calorie surplus'), findsOneWidget);
    expect(find.textContaining('Weight gain'), findsNothing);
    expect(find.text('View nutrition targets'), findsOneWidget);
    expect(find.textContaining('kg to goal'), findsNothing);
    expect(find.textContaining('on track'), findsNothing);
    expect(tester.takeException(), isNull);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final targetAction = find.widgetWithText(
      TextButton,
      'View nutrition targets',
    );
    await tester.ensureVisible(targetAction);
    await tester.tap(targetAction);
    expect(observer.pushCount, 2);
    navigator.pop();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Progress states absent current targets without historical leakage',
    (tester) async {
      _setViewport(tester, const Size(320, 568));
      await _pump(
        tester,
        _snapshot(historicalCalories: 2200, historicalProtein: 140),
        database: database,
        dates: dates,
        textScale: 2,
      );

      expect(find.text('Today’s nutrition target'), findsOneWidget);
      expect(find.text('No nutrition target saved for today.'), findsOneWidget);
      expect(find.text('Set nutrition target'), findsOneWidget);
      expect(find.text('2,200 kcal · 140 g protein'), findsNothing);
      expect(find.textContaining('Nutrition strategy:'), findsNothing);
      expect(find.textContaining('Fitness goal:'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<int> _insertProfile(AppDatabase database) =>
    database.into(database.userProfiles).insert(UserProfilesCompanion.insert());

Future<void> _recordGoal(
  NutritionGoalRepository goals, {
  required int userId,
  required NutritionGoalType goalType,
  required int calories,
  required double protein,
  required String effectiveFrom,
  required String commandId,
}) async {
  await goals.recordUserSetGoal(
    NutritionGoalCommand(
      userId: userId.toString(),
      goalType: goalType,
      calorieTargetKcal: calories,
      proteinTargetG: protein,
      carbsTargetG: 250,
      fatTargetG: 70,
      effectiveFromLocalDate: effectiveFrom,
      timezoneId: 'Asia/Kolkata',
      commandId: commandId,
    ),
  );
}

ProgressDashboardSnapshot _snapshot({
  double? targetCalories,
  double? targetProtein,
  NutritionGoalType? targetGoalType,
  double? historicalCalories,
  double? historicalProtein,
}) => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 9, 12),
  timezoneId: 'Asia/Kolkata',
  todayLocalDate: '2026-08-09',
  measurements: const [],
  workouts: const [],
  strengthSets: const [],
  muscleBalance: null,
  unavailableSections: const {},
  nutritionSummary: ProgressNutritionSummary(
    days: [
      ProgressNutritionDaySummary(
        localDate: '2026-08-08',
        dayLabel: 'Sat',
        isToday: false,
        caloriesKcal: historicalCalories ?? 2100,
        calorieTargetKcal: historicalCalories,
        proteinG: historicalProtein ?? 135,
        proteinTargetG: historicalProtein,
        hasFoodLog: true,
        isProteinTargetMet:
            historicalProtein != null && historicalProtein >= 140,
        isNutrientIncomplete: false,
      ),
      const ProgressNutritionDaySummary(
        localDate: '2026-08-09',
        dayLabel: 'Sun',
        isToday: true,
        hasFoodLog: false,
        isProteinTargetMet: false,
        isNutrientIncomplete: false,
      ),
    ],
    loggedDaysCount: 1,
    calorieEvidenceDaysCount: 1,
    proteinEvidenceDaysCount: 1,
    proteinTargetMetDaysCount: 0,
    averageCaloriesKcal: 2100,
    averageProteinG: 135,
    targetCaloriesKcal: targetCalories,
    targetProteinG: targetProtein,
    targetGoalType: targetGoalType,
    hasTarget: historicalCalories != null || targetCalories != null,
  ),
);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  ProgressDashboardSnapshot snapshot, {
  required AppDatabase database,
  required LocalScheduleDateService dates,
  NavigatorObserver? observer,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        localScheduleDateServiceProvider.overrideWithValue(dates),
        localTimezoneServiceProvider.overrideWithValue(
          LocalTimezoneService(read: () async => 'Asia/Kolkata', dates: dates),
        ),
        userProfileProvider.overrideWith((ref) => _GoalProfileNotifier()),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        navigatorObservers: observer == null
            ? const <NavigatorObserver>[]
            : [observer],
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
            size: const Size(390, 844),
          ),
          child: ProgressScreen(preview: snapshot),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _GoalProfileNotifier extends UserProfileNotifier {
  _GoalProfileNotifier() : super() {
    state = const UserProfileState(
      isLoaded: true,
      hasProfile: true,
      calorieGoal: 2400,
      proteinGoal: 160,
      carbsGoal: 280,
      fatGoal: 75,
      currentWeight: 80,
      userGoal: 'gain',
    );
  }

  @override
  Future<void> loadProfile() async {}
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  var pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}
