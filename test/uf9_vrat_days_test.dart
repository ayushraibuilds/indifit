import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/utils/streak_calculator.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/streak_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/dashboard/widgets/today_header_widgets.dart';
import 'package:indifit/features/food_log/food_staple_suggestions.dart';
import 'package:indifit/features/food_log/thali/thali_presets.dart';
import 'package:indifit/features/vrat/vrat_day_sheet.dart';
import 'package:indifit/features/vrat/vrat_days.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/real_catalogue.dart';

/// UF-9: vrat / festival days. Marked by the user; excused from the streak
/// (never breaks it, never adds to it); vrat foods on search and the thali
/// quick start; targets unchanged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('marking days', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a range covers every day, in either order, across months', () {
      expect(VratDays.range(DateTime(2026, 10, 12)), ['2026-10-12']);
      final navratri = VratDays.range(
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 12),
      );
      expect(navratri, hasLength(9));
      expect(navratri.first, '2026-10-12');
      expect(navratri.last, '2026-10-20');
      expect(VratDays.range(DateTime(2026, 10, 30), DateTime(2026, 11, 2)), [
        '2026-10-30',
        '2026-10-31',
        '2026-11-01',
        '2026-11-02',
      ]);
    });

    test('a range is capped at 31 days', () {
      expect(
        VratDays.range(DateTime(2026, 1, 1), DateTime(2026, 12, 31)),
        hasLength(VratDays.maxRangeDays),
      );
    });

    test('mark, unmark and ranges are stored locally', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = VratDaysController(prefs);
      expect(controller.state, isEmpty);

      await controller.mark(DateTime(2026, 10, 12), DateTime(2026, 10, 20));
      expect(controller.state, hasLength(9));
      expect(controller.isMarked(DateTime(2026, 10, 15, 18)), isTrue);

      await controller.unmark(DateTime(2026, 10, 15));
      expect(controller.isMarked(DateTime(2026, 10, 15)), isFalse);
      expect(prefs.getStringList(AppPreferenceKeys.prefVratDays), hasLength(8));
      // Read back by a new controller (next launch).
      expect(VratDaysController(prefs).state, controller.state);

      await controller.unmark(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(controller.state, isEmpty);
      expect(prefs.containsKey(AppPreferenceKeys.prefVratDays), isFalse);
    });

    test('unreadable stored values are ignored', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.prefVratDays: ['2026-10-12', 'nonsense'],
      });
      final prefs = await SharedPreferences.getInstance();
      expect(VratDays.read(prefs), {'2026-10-12'});
    });
  });

  group('vrat foods', () {
    test('search starter chips switch to vrat foods', () {
      for (final meal in ['breakfast', 'lunch', 'snack', null]) {
        expect(
          foodStapleSuggestions(mealType: meal, diet: 'veg', vratDay: true),
          ['Sabudana', 'Makhana', 'Fruit', 'Curd', 'Peanuts'],
        );
      }
      expect(
        foodStapleSuggestions(diet: 'vegan', vratDay: true),
        isNot(contains('Curd')),
      );
      expect(foodStapleSuggestions(diet: 'veg'), contains('Roti'));
    });

    test('the Vrat Thali leads the quick start only on a vrat day', () {
      expect(ThaliPresets.forDay(vratDay: true).first, ThaliPresets.vratThali);
      expect(
        ThaliPresets.forDay(vratDay: false),
        isNot(contains(ThaliPresets.vratThali)),
      );
      expect(ThaliPresets.all, isNot(contains(ThaliPresets.vratThali)));
    });

    group('against the bundled catalogue', () {
      late RealCatalogue catalogue;
      setUp(() async => catalogue = await RealCatalogue.open());
      tearDown(() => catalogue.close());

      test('required items resolve by sourceRef and by id', () async {
        for (final def in ThaliPresets.vratThali.items) {
          final bySource = await catalogue.thali.findFoodBySourceRef(
            def.foodSourceRef,
          );
          if (def.optional) {
            // Pack 8 foods: absent from older packs, else the stated id.
            if (bySource != null) expect(bySource.id, def.foodId);
            continue;
          }
          expect(bySource, isNotNull, reason: def.displayName);
          if (def.foodId != null) {
            final byId = await catalogue.thali.findFoodById(def.foodId!);
            expect(byId?.id, bySource!.id, reason: def.displayName);
          }
          final quantity = await catalogue.thali.ownUnitQuantity(
            bySource!.id,
            def.amount,
          );
          expect(quantity, isNotNull, reason: def.displayName);
        }
      });

      test('every search chip finds a food', () async {
        for (final chip in foodStapleSuggestions(vratDay: true)) {
          expect(
            await catalogue.catalog.search(query: chip),
            isNotEmpty,
            reason: chip,
          );
        }
      });
    });
  });

  group('streak across excused days', () {
    int streak(
      Set<String> active, {
      Set<String> excused = const {},
      int freezes = 0,
      String today = '2026-10-10',
    }) => StreakCalculator.calculateStreak(
      active,
      excusedDays: excused,
      streakFreezeCount: freezes,
      referenceLocalDate: today,
    );

    test('an excused day between active days neither breaks nor adds', () {
      final active = {'2026-10-08', '2026-10-10'};
      expect(streak(active), 1);
      expect(streak(active, excused: {'2026-10-09'}), 2);
    });

    test('a run of excused days (Navratri) adds nothing', () {
      final excused = {
        for (var d = 2; d <= 9; d++) '2026-10-${d.toString().padLeft(2, '0')}',
      };
      expect(streak({'2026-10-01', '2026-10-10'}, excused: excused), 2);
    });

    test('before: excused yesterday keeps a run when today is unlogged', () {
      expect(streak({'2026-10-07', '2026-10-08'}, excused: {'2026-10-09'}), 2);
    });

    test('during: today excused and unlogged keeps the run', () {
      expect(streak({'2026-10-08', '2026-10-09'}, excused: {'2026-10-10'}), 2);
    });

    test('an excused day that was also active counts once', () {
      expect(streak({'2026-10-09', '2026-10-10'}, excused: {'2026-10-10'}), 2);
    });

    test('after: a missed day after an excused day still breaks it', () {
      expect(streak({'2026-10-07', '2026-10-10'}, excused: {'2026-10-08'}), 1);
    });

    test('excused days alone are no streak', () {
      expect(streak({'2026-09-01'}, excused: {'2026-10-09', '2026-10-10'}), 0);
    });

    test('a freeze still covers only missed days, not excused ones', () {
      // 7 active, 8 excused, 9 missed, 10 active: one freeze bridges the
      // 9th; the 8th adds nothing.
      expect(
        streak(
          {'2026-10-07', '2026-10-10'},
          excused: {'2026-10-08'},
          freezes: 1,
        ),
        3,
      );
      // Unused freezes never add days, excused or not.
      expect(streak({'2026-10-10'}, excused: {'2026-10-09'}, freezes: 3), 1);
    });

    test('the streak repository reads marked days', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.streakFreezesCount: 0,
      });
      for (final day in [1, 3]) {
        await db
            .into(db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                name: 'Day $day',
                totalVolume: 0,
                durationSeconds: 1800,
                estimatedCalories: 0,
                completedAt: Value(DateTime(2026, 10, day, 9)),
              ),
            );
      }
      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      final repository = StreakRepository(
        nutrition: () async =>
            NutritionReadModelRepository(db: db, registry: registry),
        workouts: WorkoutRepository(db),
        preferences: SharedPreferences.getInstance,
        now: () => DateTime(2026, 10, 3, 12),
      );
      expect(await repository.currentStreak(), 1);
      final prefs = await SharedPreferences.getInstance();
      await VratDaysController(prefs).mark(DateTime(2026, 10, 2));
      expect(await repository.currentStreak(), 2);
    });
  });

  test('backup round-trip keeps vrat days', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final prefs = await SharedPreferences.getInstance();
    await VratDaysController(
      prefs,
    ).mark(DateTime(2026, 10, 12), DateTime(2026, 10, 14));

    final backup = await BackupData.createFromDatabase(db, prefs);
    final restored = BackupData.fromJson(backup.toJson());
    expect(restored.userPreferences[AppPreferenceKeys.prefVratDays], [
      '2026-10-12',
      '2026-10-13',
      '2026-10-14',
    ]);

    await prefs.clear();
    final target = AppDatabase.memory();
    addTearDown(target.close);
    await restored.restoreToDatabase(target, prefs);
    expect(VratDays.read(prefs), {'2026-10-12', '2026-10-13', '2026-10-14'});
  });

  group('Today', () {
    testWidgets('the … menu marks the day and shows the chip', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final day = DateTime(2026, 10, 12, 9);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TodayHeader(
                  userName: 'Asha',
                  streakCount: 3,
                  selectedDate: day,
                  referenceNow: day,
                  onOpenSettings: () {},
                  onOpenAppearance: () {},
                  onOpenMore: () => showVratDaySheet(context, day: day),
                  dayChip: watchIsVratDay(ref, day)
                      ? const VratDayChip()
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Vrat day'), findsNothing);

      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      expect(find.text(VratDaySheet.explainer), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('vrat-toggle-day')));
      await tester.pumpAndSettle();

      expect(find.text('Vrat day'), findsOneWidget);
      expect(VratDays.read(prefs), {'2026-10-12'});

      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unmark Monday 12 October'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('vrat-toggle-day')));
      await tester.pumpAndSettle();
      expect(find.text('Vrat day'), findsNothing);
      expect(VratDays.read(prefs), isEmpty);
    });

    testWidgets('no … button unless one is wired', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TodayHeader(
              userName: 'Asha',
              streakCount: 3,
              selectedDate: DateTime(2026, 10, 12),
              referenceNow: DateTime(2026, 10, 12),
              onOpenSettings: () {},
              onOpenAppearance: () {},
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('More'), findsNothing);
    });
  });
}
