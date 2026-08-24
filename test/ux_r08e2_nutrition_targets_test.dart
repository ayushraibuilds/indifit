import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/repositories/nutrition_goal_repository.dart';
import 'package:indifit/data/repositories/nutrition_target_authority.dart';
import 'package:indifit/features/coaching/b04_production_surface_controller.dart';
import 'package:indifit/features/settings/nutrition_targets_hub_screen.dart';

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

  testWidgets('presents the exact current target and only supported values', (
    tester,
  ) async {
    late int profileId;
    late NutritionTargetsForDate currentTarget;
    late NutritionGoalVersionReadModel currentGoal;
    await tester.runAsync(() async {
      profileId = await _insertProfile(database);
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
        ),
      );
      currentGoal = (await goals.activeGoal(
        userId: profileId.toString(),
        localDate: '2026-08-06',
        timezoneId: 'Asia/Kolkata',
      ))!;
      currentTarget = NutritionTargetsForDate(
        localDate: '2026-08-06',
        timezoneId: 'Asia/Kolkata',
        goalVersion: currentGoal,
      );
    });

    await tester.pumpWidget(
      _app(
        database,
        dates,
        targetsByDate: {'2026-08-06': currentTarget},
        history: [currentGoal],
      ),
    );
    await _pumpForAsyncState(tester);

    expect(find.text('Today’s target'), findsOneWidget);
    expect(find.text('2,100 kcal'), findsNothing);
    expect(find.text('2100 kcal'), findsOneWidget);
    expect(find.text('140 g'), findsOneWidget);
    expect(find.text('220 g'), findsOneWidget);
    expect(find.text('65 g'), findsOneWidget);
    expect(find.textContaining('Set by you'), findsWidgets);
    expect(find.text('Fiber'), findsNothing);
    expect(find.text('Sodium'), findsNothing);
    expect(find.text('Calculated percentage'), findsNothing);
    expect(find.text('Save today’s targets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'date navigation reads history without making earlier dates editable',
    (tester) async {
      late Map<String, NutritionTargetsForDate> targets;
      late List<NutritionGoalVersionReadModel> history;
      await tester.runAsync(() async {
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
            commandId: 'r08e2-history-before',
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
            commandId: 'r08e2-history-current',
          ),
        );
        final earlier = (await goals.activeGoal(
          userId: profileId.toString(),
          localDate: '2026-08-05',
          timezoneId: 'Asia/Kolkata',
        ))!;
        final current = (await goals.activeGoal(
          userId: profileId.toString(),
          localDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
        ))!;
        targets = {
          '2026-08-05': NutritionTargetsForDate(
            localDate: '2026-08-05',
            timezoneId: 'Asia/Kolkata',
            goalVersion: earlier,
          ),
          '2026-08-06': NutritionTargetsForDate(
            localDate: '2026-08-06',
            timezoneId: 'Asia/Kolkata',
            goalVersion: current,
          ),
          '2026-08-07': NutritionTargetsForDate(
            localDate: '2026-08-07',
            timezoneId: 'Asia/Kolkata',
            goalVersion: current,
          ),
        };
        history = await goals.listVersions(userId: profileId.toString());
      });

      await tester.pumpWidget(
        _app(database, dates, targetsByDate: targets, history: history),
      );
      await _pumpForAsyncState(tester);
      expect(find.text('1800 kcal'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous day'));
      await _pumpForAsyncState(tester);

      expect(find.text('Target for Yesterday'), findsOneWidget);
      expect(find.text('2100 kcal'), findsOneWidget);
      expect(
        find.textContaining('Earlier target versions are read-only'),
        findsOneWidget,
      );
      expect(find.text('Save today’s targets'), findsNothing);
      expect(find.text('1800 kcal'), findsNothing);

      await tester.tap(find.byTooltip('Next day'));
      await _pumpForAsyncState(tester);
      await tester.tap(find.byTooltip('Next day'));
      await _pumpForAsyncState(tester);

      expect(find.text('Target for Tomorrow'), findsOneWidget);
      expect(
        find.textContaining('Future target dates are read-only'),
        findsOneWidget,
      );
      expect(find.text('Save today’s targets'), findsNothing);
    },
  );

  testWidgets(
    'saving today dispatches the versioned command and canonical read updates',
    (tester) async {
      late int profileId;
      late NutritionGoalRepository goals;
      late NutritionGoalVersionReadModel currentGoal;
      await tester.runAsync(() async {
        profileId = await _insertProfile(database);
        goals = NutritionGoalRepository(database: database, dates: dates);
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
            commandId: 'r08e2-save-before',
          ),
        );
        currentGoal = (await goals.activeGoal(
          userId: profileId.toString(),
          localDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
        ))!;
      });
      final recording = _RecordingNutritionGoalRepository(
        database,
        dates,
        currentGoal,
      );

      await tester.pumpWidget(
        _app(
          database,
          dates,
          goalsOverride: recording,
          targetsByDate: {
            '2026-08-06': NutritionTargetsForDate(
              localDate: '2026-08-06',
              timezoneId: 'Asia/Kolkata',
              goalVersion: currentGoal,
            ),
          },
          history: [currentGoal],
        ),
      );
      await _pumpForAsyncState(tester);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4));
      await tester.enterText(fields.at(0), '2300');
      await tester.ensureVisible(find.text('Save today’s targets'));
      await tester.tap(find.text('Save today’s targets'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await _pumpForAsyncState(tester);

      expect(
        find.text('Saved for today. Earlier dates keep their saved target.'),
        findsOneWidget,
      );
      final command = recording.lastUserSetCommand;
      expect(command, isNotNull);
      expect(command!.userId, profileId.toString());
      expect(command.effectiveFromLocalDate, '2026-08-06');
      expect(command.calorieTargetKcal, 2300);
      expect(command.source, NutritionGoalSource.userSet);
      await tester.runAsync(() => goals.recordUserSetGoal(command));
      final history = (await tester.runAsync(
        () => goals.listVersions(userId: profileId.toString()),
      ))!;
      expect(history, hasLength(2));
      expect(history.last.calorieTargetKcal, 2300);
      expect(history.last.source, NutritionGoalSource.userSet);
      final current = (await tester.runAsync(
        () => NutritionTargetAuthority(goals: goals, dates: dates).resolve(
          const NutritionTargetDateQuery(
            localDate: '2026-08-06',
            timezoneId: 'Asia/Kolkata',
          ),
        ),
      ))!;
      expect(current.calorieTargetKcal, 2300);
    },
  );

  test(
    'hub history follows canonical writes without a second refresh',
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
          commandId: 'r08e2-invalidation-before',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          localScheduleDateServiceProvider.overrideWithValue(dates),
        ],
      );
      addTearDown(container.dispose);

      final provider = nutritionGoalHistoryProvider(profileId.toString());
      final changed = Completer<List<NutritionGoalVersionReadModel>>();
      final subscription = container.listen(provider, (_, next) {
        final value = next.valueOrNull;
        if (value?.length == 2 && !changed.isCompleted) {
          changed.complete(value!);
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);

      expect((await container.read(provider.future)), hasLength(1));
      await goals.recordManualOverride(
        NutritionGoalCommand(
          userId: profileId.toString(),
          goalType: NutritionGoalType.maintenance,
          calorieTargetKcal: 2250,
          proteinTargetG: 145,
          carbsTargetG: 230,
          fatTargetG: 70,
          effectiveFromLocalDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
          commandId: 'r08e2-invalidation-change',
        ),
      );

      final history = await changed.future.timeout(const Duration(seconds: 2));
      expect(history.last.source, NutritionGoalSource.override);
      expect(history.last.calorieTargetKcal, 2250);
      expect(
        (await container.read(
          nutritionTargetsForDateProvider(
            const NutritionTargetDateQuery(
              localDate: '2026-08-06',
              timezoneId: 'Asia/Kolkata',
            ),
          ).future,
        )).calorieTargetKcal,
        2250,
      );
    },
  );

  testWidgets('no target is explicit and failed saves retain entered values', (
    tester,
  ) async {
    final profileId = (await tester.runAsync(() => _insertProfile(database)))!;
    final failing = _FailingNutritionGoalRepository(database, dates);
    await tester.pumpWidget(
      _app(
        database,
        dates,
        goalsOverride: failing,
        targetsByDate: {
          '2026-08-06': const NutritionTargetsForDate(
            localDate: '2026-08-06',
            timezoneId: 'Asia/Kolkata',
            goalVersion: null,
          ),
        },
        history: const [],
      ),
    );
    await _pumpForAsyncState(tester);

    expect(find.text('No target set for today'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '2000');
    await tester.enterText(fields.at(1), '130');
    await tester.ensureVisible(find.text('Save today’s targets'));
    await tester.tap(find.text('Save today’s targets'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await _pumpForAsyncState(tester);

    expect(
      find.text(
        'That change could not be saved. Your entered values are still here.',
      ),
      findsOneWidget,
    );
    expect(
      (fields.at(0).evaluate().single.widget as TextField).controller!.text,
      '2000',
    );
    expect(
      (fields.at(1).evaluate().single.widget as TextField).controller!.text,
      '130',
    );
    expect(profileId, isPositive);
  });

  testWidgets('fails closed when the target context is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          b04ProductionUserContextProvider.overrideWith(
            (ref) async => throw StateError('profile unavailable'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NutritionTargetsHubScreen(),
        ),
      ),
    );
    await _pumpForAsyncState(tester);

    expect(find.text('Nutrition targets unavailable'), findsOneWidget);
    expect(find.text('Save today’s targets'), findsNothing);
    expect(find.text('0 kcal'), findsNothing);
  });

  testWidgets(
    'stays usable at narrow width and elevated text scale in both themes',
    (tester) async {
      late int profileId;
      late NutritionGoalVersionReadModel currentGoal;
      await tester.runAsync(() async {
        profileId = await _insertProfile(database);
        await NutritionGoalRepository(
          database: database,
          dates: dates,
        ).recordUserSetGoal(
          NutritionGoalCommand(
            userId: profileId.toString(),
            goalType: NutritionGoalType.maintenance,
            calorieTargetKcal: 2100,
            proteinTargetG: 140,
            carbsTargetG: 220,
            fatTargetG: 65,
            effectiveFromLocalDate: '2026-08-01',
            timezoneId: 'Asia/Kolkata',
          ),
        );
        currentGoal =
            (await NutritionGoalRepository(
              database: database,
              dates: dates,
            ).activeGoal(
              userId: profileId.toString(),
              localDate: '2026-08-06',
              timezoneId: 'Asia/Kolkata',
            ))!;
      });

      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      final media = MediaQueryData.fromView(
        tester.view,
      ).copyWith(textScaler: const TextScaler.linear(2));

      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              localScheduleDateServiceProvider.overrideWithValue(dates),
              b04ProductionUserContextProvider.overrideWith(
                (ref) async => const B04ProductionUserContext(
                  userId: '1',
                  localDate: '2026-08-06',
                  timezoneId: 'Asia/Kolkata',
                ),
              ),
              nutritionTargetsForDateProvider(
                const NutritionTargetDateQuery(
                  localDate: '2026-08-06',
                  timezoneId: 'Asia/Kolkata',
                ),
              ).overrideWith(
                (ref) async => NutritionTargetsForDate(
                  localDate: '2026-08-06',
                  timezoneId: 'Asia/Kolkata',
                  goalVersion: currentGoal,
                ),
              ),
              nutritionGoalHistoryProvider(
                '1',
              ).overrideWith((ref) async => [currentGoal]),
            ],
            child: MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: media,
                child: const NutritionTargetsHubScreen(),
              ),
            ),
          ),
        );
        await _pumpForAsyncState(tester);
        expect(find.text('Today’s target'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

Widget _app(
  AppDatabase database,
  LocalScheduleDateService dates, {
  NutritionGoalRepository? goalsOverride,
  Map<String, NutritionTargetsForDate>? targetsByDate,
  List<NutritionGoalVersionReadModel>? history,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(database),
    localScheduleDateServiceProvider.overrideWithValue(dates),
    b04ProductionUserContextProvider.overrideWith(
      (ref) async => const B04ProductionUserContext(
        userId: '1',
        localDate: '2026-08-06',
        timezoneId: 'Asia/Kolkata',
      ),
    ),
    if (goalsOverride != null)
      nutritionGoalRepositoryProvider.overrideWithValue(goalsOverride),
    if (targetsByDate != null)
      nutritionTargetsForDateProvider.overrideWith((ref, query) async {
        final target = targetsByDate[query.localDate];
        if (target == null) {
          throw StateError('No test target for ${query.localDate}');
        }
        return target;
      }),
    if (history != null)
      nutritionGoalHistoryProvider.overrideWith((ref, userId) async => history),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    home: const NutritionTargetsHubScreen(),
  ),
);

Future<void> _pumpForAsyncState(WidgetTester tester) async {
  for (var index = 0; index < 12; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<int> _insertProfile(AppDatabase database) =>
    database.into(database.userProfiles).insert(UserProfilesCompanion.insert());

class _FailingNutritionGoalRepository extends NutritionGoalRepository {
  _FailingNutritionGoalRepository(
    AppDatabase database,
    LocalScheduleDateService dates,
  ) : super(database: database, dates: dates);

  @override
  Future<NutritionGoalVersionReadModel> recordUserSetGoal(
    NutritionGoalCommand command,
  ) => throw StateError('durable write failed');
}

class _RecordingNutritionGoalRepository extends NutritionGoalRepository {
  final NutritionGoalVersionReadModel result;
  NutritionGoalCommand? lastUserSetCommand;

  _RecordingNutritionGoalRepository(
    AppDatabase database,
    LocalScheduleDateService dates,
    this.result,
  ) : super(database: database, dates: dates);

  @override
  Future<NutritionGoalVersionReadModel> recordUserSetGoal(
    NutritionGoalCommand command,
  ) async {
    lastUserSetCommand = command;
    return result;
  }
}
