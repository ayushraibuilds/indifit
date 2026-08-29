import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/repositories/b02_progress_read_repository.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/nutrition_goal_repository.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/nutrition_target_authority.dart';
import 'package:indifit/data/repositories/progress_dashboard_read_repository.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late LocalScheduleDateService dates;

  setUp(() {
    database = AppDatabase.memory();
    dates = LocalScheduleDateService(
      nowUtc: () => DateTime.utc(2026, 8, 6, 12),
    );
  });

  tearDown(() => database.close());

  test(
    'resolves historical targets by local date without current leakage',
    () async {
      final profileId = await _insertProfile(database);
      final goals = NutritionGoalRepository(database: database, dates: dates);
      await goals.recordUserSetGoal(
        NutritionGoalCommand(
          userId: profileId.toString(),
          goalType: NutritionGoalType.maintenance,
          calorieTargetKcal: 2100,
          proteinTargetG: 140,
          carbsTargetG: 220,
          fatTargetG: 65,
          effectiveFromLocalDate: '2026-08-01',
          timezoneId: 'Asia/Kolkata',
          commandId: 'r08a1-initial',
        ),
      );
      await goals.recordUserSetGoal(
        NutritionGoalCommand(
          userId: profileId.toString(),
          goalType: NutritionGoalType.loss,
          calorieTargetKcal: 1800,
          proteinTargetG: 150,
          carbsTargetG: 180,
          fatTargetG: 60,
          effectiveFromLocalDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
          commandId: 'r08a1-change',
        ),
      );
      final authority = NutritionTargetAuthority(goals: goals, dates: dates);

      final beforeHistory = await authority.resolve(
        const NutritionTargetDateQuery(
          localDate: '2026-07-31',
          timezoneId: 'Asia/Kolkata',
        ),
      );
      final historical = await authority.resolve(
        const NutritionTargetDateQuery(
          localDate: '2026-08-05',
          timezoneId: 'Asia/Kolkata',
        ),
      );
      final changed = await authority.resolve(
        const NutritionTargetDateQuery(
          localDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
        ),
      );

      expect(beforeHistory.goalVersion, isNull);
      expect(historical.calorieTargetKcal, 2100);
      expect(historical.proteinTargetG, 140);
      expect(changed.calorieTargetKcal, 1800);
      expect(changed.proteinTargetG, 150);
      expect(changed.goalVersionId, isNot(historical.goalVersionId));
    },
  );

  test(
    'goal-version writes invalidate the shared Riverpod date resolver',
    () async {
      final profileId = await _insertProfile(database);
      final goals = NutritionGoalRepository(database: database, dates: dates);
      await goals.recordUserSetGoal(
        NutritionGoalCommand(
          userId: profileId.toString(),
          goalType: NutritionGoalType.maintenance,
          calorieTargetKcal: 2000,
          proteinTargetG: 130,
          carbsTargetG: 220,
          fatTargetG: 60,
          effectiveFromLocalDate: '2026-08-01',
          timezoneId: 'Asia/Kolkata',
          commandId: 'r08a1-provider-initial',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          localScheduleDateServiceProvider.overrideWithValue(dates),
        ],
      );
      addTearDown(container.dispose);

      const query = NutritionTargetDateQuery(
        localDate: '2026-08-06',
        timezoneId: 'Asia/Kolkata',
      );
      final provider = nutritionTargetsForDateProvider(query);
      final changed = Completer<NutritionTargetsForDate>();
      final subscription = container.listen(provider, (_, next) {
        final value = next.valueOrNull;
        if (value?.calorieTargetKcal == 2300 && !changed.isCompleted) {
          changed.complete(value!);
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);

      final initial = await container.read(provider.future);
      expect(initial.calorieTargetKcal, 2000);

      await goals.recordUserSetGoal(
        NutritionGoalCommand(
          userId: profileId.toString(),
          goalType: NutritionGoalType.gain,
          calorieTargetKcal: 2300,
          proteinTargetG: 150,
          carbsTargetG: 260,
          fatTargetG: 70,
          effectiveFromLocalDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
          commandId: 'r08a1-provider-change',
        ),
      );

      expect(
        (await changed.future.timeout(
          const Duration(seconds: 2),
        )).proteinTargetG,
        150,
      );
    },
  );

  test(
    'primary-profile changes invalidate the shared Riverpod date resolver',
    () async {
      final firstProfileId = await _insertProfile(database);
      final secondProfileId = await _insertProfile(database);
      final goals = NutritionGoalRepository(database: database, dates: dates);
      for (final entry in [
        (firstProfileId, 2000, 'r08a1-profile-first'),
        (secondProfileId, 2400, 'r08a1-profile-second'),
      ]) {
        await goals.recordUserSetGoal(
          NutritionGoalCommand(
            userId: entry.$1.toString(),
            goalType: NutritionGoalType.maintenance,
            calorieTargetKcal: entry.$2,
            proteinTargetG: 140,
            carbsTargetG: 220,
            fatTargetG: 65,
            effectiveFromLocalDate: '2026-08-01',
            timezoneId: 'Asia/Kolkata',
            commandId: entry.$3,
          ),
        );
      }
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          localScheduleDateServiceProvider.overrideWithValue(dates),
        ],
      );
      addTearDown(container.dispose);

      const query = NutritionTargetDateQuery(
        localDate: '2026-08-06',
        timezoneId: 'Asia/Kolkata',
      );
      final provider = nutritionTargetsForDateProvider(query);
      final changed = Completer<NutritionTargetsForDate>();
      final subscription = container.listen(provider, (_, next) {
        final value = next.valueOrNull;
        if (value?.calorieTargetKcal == 2400 && !changed.isCompleted) {
          changed.complete(value!);
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);

      expect((await container.read(provider.future)).calorieTargetKcal, 2000);

      await (database.delete(
        database.userProfiles,
      )..where((row) => row.id.equals(firstProfileId))).go();

      expect(
        (await changed.future.timeout(
          const Duration(seconds: 2),
        )).goalVersion?.userId,
        secondProfileId.toString(),
      );
    },
  );

  test(
    'Today, Food, and Progress expose identical targets for one date',
    () async {
      final profileId = await _insertProfile(database);
      final goals = NutritionGoalRepository(database: database, dates: dates);
      await goals.recordUserSetGoal(
        NutritionGoalCommand(
          userId: profileId.toString(),
          goalType: NutritionGoalType.maintenance,
          calorieTargetKcal: 2100,
          proteinTargetG: 140,
          carbsTargetG: 220,
          fatTargetG: 65,
          effectiveFromLocalDate: '2026-08-01',
          timezoneId: 'Asia/Kolkata',
          commandId: 'r08a1-cross-initial',
        ),
      );
      await goals.recordUserSetGoal(
        NutritionGoalCommand(
          userId: profileId.toString(),
          goalType: NutritionGoalType.loss,
          calorieTargetKcal: 2300,
          proteinTargetG: 155,
          carbsTargetG: 240,
          fatTargetG: 70,
          effectiveFromLocalDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
          commandId: 'r08a1-cross-change',
        ),
      );
      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      final nutrition = NutritionReadModelRepository(
        db: database,
        registry: registry,
      );
      final authority = NutritionTargetAuthority(goals: goals, dates: dates);
      const localDate = '2026-08-06';
      const timezoneId = 'Asia/Kolkata';

      final today = await TodaySurfaceReadRepository(
        calendar: CalendarReadRepository(database, dates: dates),
        progress: B02ProgressReadRepository(database, civilDates: dates),
        nutrition: () async => nutrition,
        targets: authority,
        dates: dates,
      ).read(selectedDate: DateTime(2026, 8, 6), timezoneId: timezoneId);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          nutritionRegistryProvider.overrideWith((_) async => registry),
          localTimezoneServiceProvider.overrideWithValue(
            LocalTimezoneService(read: () async => timezoneId, dates: dates),
          ),
        ],
      );
      addTearDown(container.dispose);
      final food = await container.read(
        foodDiaryReadModelProvider(DateTime(2026, 8, 6)).future,
      );

      final progress = await ProgressDashboardReadRepository(
        database,
        dates: dates,
        nutrition: nutrition,
        nutritionTargets: authority,
      ).read(nowUtc: DateTime.utc(2026, 8, 6, 8), timezoneId: timezoneId);
      final progressDay = progress.nutritionSummary!.days.singleWhere(
        (day) => day.localDate == localDate,
      );

      final todayTargets = today.targets!.value!;
      final foodTargets = food.targets.value!;
      final todayPresentation = TodayNutritionPresentation.from(
        today.nutrition,
        loading: false,
        targetRead: today.targets,
      );
      final foodPresentation = TodayNutritionPresentation.from(
        TodayDomainRead.available(food.daily),
        loading: false,
        targetRead: food.targets,
      );

      expect(todayTargets.goalVersionId, foodTargets.goalVersionId);
      expect(todayTargets.calorieTargetKcal, progressDay.calorieTargetKcal);
      expect(foodTargets.calorieTargetKcal, progressDay.calorieTargetKcal);
      expect(todayTargets.proteinTargetG, progressDay.proteinTargetG);
      expect(foodTargets.proteinTargetG, progressDay.proteinTargetG);
      expect(todayPresentation.calories!.targetValue, 2300);
      expect(foodPresentation.calories!.targetValue, 2300);
    },
  );

  test(
    'Food keeps daily history when target timezone resolution is unavailable',
    () async {
      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          nutritionRegistryProvider.overrideWith((_) async => registry),
          localTimezoneServiceProvider.overrideWithValue(
            LocalTimezoneService(read: () async => ''),
          ),
        ],
      );
      addTearDown(container.dispose);

      final food = await container.read(
        foodDiaryReadModelProvider(DateTime(2026, 8, 6)).future,
      );

      expect(food.daily, isNotNull);
      expect(food.targets.isAvailable, isFalse);
    },
  );
}

Future<int> _insertProfile(AppDatabase database) =>
    database.into(database.userProfiles).insert(UserProfilesCompanion.insert());
