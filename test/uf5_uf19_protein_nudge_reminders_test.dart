import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/services/notification_service.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/dashboard/protein_nudge.dart';
import 'package:indifit/features/dashboard/weigh_in_reminder.dart';
import 'package:indifit/features/dashboard/widgets/today_protein_nudge_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/real_catalogue.dart';

/// UF-5 protein nudge and UF-19 context reminders.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('when the nudge shows', () {
    bool show({
      int hour = 18,
      double? target = 120,
      double? eaten = 78,
      String? dismissed,
    }) => ProteinNudge.shouldShow(
      localNow: DateTime(2026, 10, 19, hour),
      proteinTarget: target,
      proteinEaten: eaten,
      dismissedDate: dismissed,
      todayLocalDate: '2026-10-19',
    );

    test('after 17:00 with 20 g or more left', () {
      expect(show(), isTrue);
      expect(show(hour: 17), isTrue);
      expect(show(hour: 16), isFalse);
      expect(show(eaten: 100), isTrue); // exactly 20 g left
      expect(show(eaten: 100.5), isFalse);
    });

    test('never without a protein target, or after "Not today"', () {
      expect(show(target: null), isFalse);
      expect(show(target: 0), isFalse);
      expect(show(dismissed: '2026-10-19'), isFalse);
      expect(show(dismissed: '2026-10-18'), isTrue);
    });

    test('the headline names the gap', () {
      expect(ProteinNudge.headline(42.3), "You're 42 g short of protein.");
    });
  });

  group('picking suggestions', () {
    ProteinSuggestion food(
      String name,
      double protein,
      double kcal, {
      String? category = 'Vegetables & Sabjis',
      bool history = false,
    }) => ProteinSuggestion(
      foodId: name,
      name: name,
      quantity: Quantity.fromNum(amount: 1, unit: QuantityUnit.piece),
      amountLabel: '1 katori',
      proteinGrams: protein,
      kcal: kcal,
      fromHistory: history,
      category: category,
    );

    test("the person's own foods first, each group by protein per kcal", () {
      final picked = ProteinNudge.pick(
        [
          food('Soya curry', 16, 200),
          food('Dal', 8, 170, history: true),
          food(
            'Paneer bhurji',
            16,
            290,
            category: 'Paneer & Dairy',
            history: true,
          ),
          food('Sprouts', 9, 140),
        ],
        diet: 'veg',
        remainingKcal: 600,
      );
      expect(picked.map((s) => s.name), ['Paneer bhurji', 'Dal', 'Soya curry']);
      expect(picked.first.line, 'Paneer bhurji (1 katori) = 16 g');
    });

    test('kcal must fit what is left', () {
      final picked = ProteinNudge.pick(
        [food('Soya curry', 16, 200), food('Sprouts', 9, 140)],
        diet: 'veg',
        remainingKcal: 150,
      );
      expect(picked.map((s) => s.name), ['Sprouts']);
      expect(
        ProteinNudge.pick(
          [food('Sprouts', 9, 140)],
          diet: 'veg',
          remainingKcal: null,
        ),
        isEmpty,
      );
    });

    test('diet and constraints filter', () {
      final candidates = [
        food('Chicken Korma', 24, 340, category: 'Non-Veg'),
        food('Egg White Salad', 16, 110, category: 'Healthy & Salads'),
        food('Paneer Bhurji', 16, 290, category: 'Paneer & Dairy'),
        food('Masoor Dal', 8, 115, category: 'Dals & Legumes'),
        food('Whey', 24, 120, category: null),
      ];
      List<String> pick(String diet, {Set<String> conflicts = const {}}) =>
          ProteinNudge.pick(
            candidates,
            diet: diet,
            remainingKcal: 1000,
            conflictingFoodIds: conflicts,
          ).map((s) => s.name).toList();
      // Veg: no meat or egg, and nothing the catalogue can't place.
      expect(pick('veg'), ['Masoor Dal', 'Paneer Bhurji']);
      expect(pick('eggetarian'), [
        'Egg White Salad',
        'Masoor Dal',
        'Paneer Bhurji',
      ]);
      expect(pick('vegan'), ['Masoor Dal']);
      // Unrestricted diets take the densest first: whey, then egg whites.
      expect(pick('non-veg').first, 'Whey');
      expect(pick('non-veg'), hasLength(3));
      expect(pick('veg', conflicts: {'Paneer Bhurji'}), ['Masoor Dal']);
    });

    test('the staples are catalogue foods', () async {
      final c = await RealCatalogue.open();
      addTearDown(c.close);
      for (final name in ProteinNudge.staples) {
        expect(await c.foodId(name), isNotEmpty, reason: name);
      }
      expect(
        await catalogueCategory(c.db, await c.foodId('Paneer Bhurji')),
        'Paneer & Dairy',
      );
    });
  });

  test('"Not today" round-trips through a backup and restore', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final prefs = await SharedPreferences.getInstance();
    await dismissProteinNudge(prefs, '2026-10-19');
    final restored = BackupData.fromJson(
      (await BackupData.createFromDatabase(db, prefs)).toJson(),
    );
    SharedPreferences.setMockInitialValues({});
    final fresh = await SharedPreferences.getInstance();
    await restored.restoreToDatabase(db, fresh);
    expect(
      fresh.getString(AppPreferenceKeys.prefProteinNudgeDismissedDate),
      '2026-10-19',
    );
  });

  group('context reminders', () {
    test('the meal reminder names the usual meal', () {
      expect(NotificationService.mealReminderText('lunch', 'Dal + Rice'), (
        'Your usual Dal + Rice?',
        'Tap to log your usual lunch: Dal + Rice.',
      ));
      expect(NotificationService.mealReminderText('dinner', null), (
        '🍽️ Log your dinner',
        'Open IndiFit to search and log your dinner.',
      ));
      expect(NotificationService.mealReminderText('lunch', null), (
        '🍱 Log your lunch',
        'Open IndiFit to search and log your lunch.',
      ));
    });

    test('a meal already logged today skips today', () {
      expect(
        NotificationService.skipMealReminderToday(
          meal: 'lunch',
          loggedMealCategories: {'lunch', 'snack'},
        ),
        isTrue,
      );
      expect(
        NotificationService.skipMealReminderToday(
          meal: 'dinner',
          loggedMealCategories: {'lunch', 'snack'},
        ),
        isFalse,
      );
    });
  });

  group('the Today card', () {
    final suggestion = ProteinSuggestion(
      foodId: 'food-paneer',
      name: 'Paneer Bhurji',
      quantity: Quantity.fromNum(amount: 1, unit: QuantityUnit.piece),
      amountLabel: '1 katori',
      proteinGrams: 16,
      kcal: 290,
      fromHistory: true,
    );

    Future<void> pump(WidgetTester tester, DateTime now, double eaten) async {
      final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            localTimezoneServiceProvider.overrideWithValue(
              LocalTimezoneService(read: () async => 'Asia/Kolkata'),
            ),
            weighInClockProvider.overrideWithValue(() => now),
            proteinSuggestionsProvider.overrideWith(
              (ref, args) async => [suggestion],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TodayProteinNudgeCard(
                proteinTarget: 120,
                proteinEaten: eaten,
                kcalTarget: 2000,
                kcalEaten: 1400,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
    }

    testWidgets('shows the gap and suggestions in the evening', (tester) async {
      await pump(tester, DateTime.now().copyWith(hour: 19), 78);
      expect(find.text("You're 42 g short of protein."), findsOneWidget);
      expect(find.text('Paneer Bhurji (1 katori) = 16 g'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      await tester.tap(find.text('Not today'));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(find.byKey(const Key('today_protein_nudge')), findsNothing);
    });

    testWidgets('stays away before 17:00 or with under 20 g left', (
      tester,
    ) async {
      await pump(tester, DateTime.now().copyWith(hour: 16), 78);
      expect(find.byKey(const Key('today_protein_nudge')), findsNothing);
      await pump(tester, DateTime.now().copyWith(hour: 19), 105);
      expect(find.byKey(const Key('today_protein_nudge')), findsNothing);
    });
  });
}
