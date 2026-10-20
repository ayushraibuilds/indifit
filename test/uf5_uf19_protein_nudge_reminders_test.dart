import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/presentation/diet_preference_presentation.dart';
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
          food('Masoor dal', 8.2, 115, history: true),
          food(
            'Low fat paneer',
            22,
            160,
            category: 'Paneer & Dairy',
            history: true,
          ),
          food('Sprouts', 9, 140),
        ],
        diet: 'veg',
        remainingKcal: 600,
      );
      expect(picked.map((s) => s.name), [
        'Low fat paneer',
        'Masoor dal',
        'Soya curry',
      ]);
      expect(picked.first.line, 'Low fat paneer (1 katori) = 22 g');
    });

    test('R-4: only dense foods pass the protein floor', () {
      final candidates = [
        food('Poha', 4, 250, history: true),
        food('3 Roti', 9, 300, history: true),
        food('Full Cream Milk', 7, 150, history: true),
        // Dense, but too little in the amount offered.
        food('Egg white bite', 7.9, 50, category: 'Healthy & Salads'),
        // Just on the per-serving line, above the density line.
        food('Masoor dal', 8, 125),
      ];
      expect(
        ProteinNudge.pick(
          candidates,
          diet: 'non-veg',
          remainingKcal: 1000,
        ).map((s) => s.name),
        ['Masoor dal'],
      );
      // Nothing passes: no suggestions, so the card hides.
      expect(
        ProteinNudge.pick(
          candidates.take(3),
          diet: 'non-veg',
          remainingKcal: 1000,
        ),
        isEmpty,
      );
    });

    test('R-4: whey only for someone who has logged it', () {
      final whey = food('Whey Protein', 24, 120, category: null);
      final wheyLogged = food(
        'Whey Protein',
        24,
        120,
        category: null,
        history: true,
      );
      expect(
        ProteinNudge.pick([whey], diet: 'non-veg', remainingKcal: 1000),
        isEmpty,
      );
      expect(
        ProteinNudge.pick(
          [wheyLogged],
          diet: 'non-veg',
          remainingKcal: 1000,
        ).map((s) => s.name),
        ['Whey Protein'],
      );
    });

    test('R-4: the amount is not repeated when the name has it', () {
      ProteinSuggestion named(String name, String amount) => ProteinSuggestion(
        foodId: name,
        name: name,
        quantity: Quantity.fromNum(amount: 1, unit: QuantityUnit.piece),
        amountLabel: amount,
        proteinGrams: 8,
        kcal: 120,
        fromHistory: true,
      );
      expect(
        named('Full Cream Milk (1 Glass)', '1 glass').line,
        'Full Cream Milk (1 Glass) = 8 g',
      );
      expect(
        named('Boiled Eggs (2 pieces)', '2 pieces').line,
        'Boiled Eggs (2 pieces) = 8 g',
      );
      expect(
        named('Full Cream Milk (1 Glass)', '2 glass').line,
        'Full Cream Milk (1 Glass) (2 glass) = 8 g',
      );
      expect(
        named('Lassi (11 glass)', '1 glass').line,
        'Lassi (11 glass) (1 glass) = 8 g',
      );
      expect(
        named('Paneer Bhurji', '1 katori').line,
        'Paneer Bhurji (1 katori) = 8 g',
      );
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

    test('R-3: every diet, by its persisted values and aliases', () {
      final candidates = [
        food('Chicken Breast (Cooked)', 31, 165, category: 'Non-Veg'),
        food('Egg White Salad', 16, 110, category: 'Healthy & Salads'),
        food('Low Fat Paneer', 22, 160, category: 'Paneer & Dairy'),
        food('Aloo Soya Curry', 12, 150),
        food('Masoor Dal', 8.2, 115, category: 'Dals & Legumes'),
        food('Roasted Chana', 10, 150, category: 'Pulses & Legumes'),
        // The catalogue can't place it: only unrestricted diets get it.
        food('Tofu', 16, 150, category: null),
      ];
      const expected = {
        'veg': {
          'Low Fat Paneer',
          'Aloo Soya Curry',
          'Masoor Dal',
          'Roasted Chana',
        },
        'eggetarian': {
          'Egg White Salad',
          'Low Fat Paneer',
          'Aloo Soya Curry',
          'Masoor Dal',
          'Roasted Chana',
        },
        'non_veg': {
          'Chicken Breast (Cooked)',
          'Egg White Salad',
          'Low Fat Paneer',
          'Aloo Soya Curry',
          'Masoor Dal',
          'Roasted Chana',
          'Tofu',
        },
        'vegan': {'Aloo Soya Curry', 'Masoor Dal', 'Roasted Chana'},
        // Vegetarian without onion, garlic or roots (aloo).
        'jain': {'Low Fat Paneer', 'Masoor Dal', 'Roasted Chana'},
      };
      expect(
        DietPreferencePresentation.options.map((o) => o.uiValue).toSet(),
        expected.keys.toSet(),
      );
      for (final option in DietPreferencePresentation.options) {
        for (final value in {
          option.uiValue,
          option.preferredPersistedValue,
          ...option.persistedAliases,
        }) {
          final fits = {
            for (final c in candidates)
              if (dietFit(value, name: c.name, category: c.category) ==
                  DietFit.fits)
                c.name,
          };
          expect(fits, expected[option.uiValue], reason: value);
        }
      }
      // An unknown value is treated as vegetarian.
      expect(
        dietFit('pescatarian', name: 'Chicken Breast', category: 'Non-Veg'),
        DietFit.conflicts,
      );
    });

    test('R-3: Jain leaves out onion, garlic and roots by name', () {
      for (final name in [
        'Onion Pakora',
        'Garlic Naan',
        'Aloo Paratha',
        'Gajar Halwa',
        'Mooli Paratha',
        'Beetroot Raita',
        'Adrak Chai',
        'Sweet Potato Chaat',
        'Egg Curry',
      ]) {
        expect(
          dietFit('jain', name: name, category: 'Vegetables & Sabjis'),
          DietFit.conflicts,
          reason: name,
        );
      }
      expect(
        dietFit('jain', name: 'Moong Dal Chilka', category: null),
        DietFit.unknown,
      );
    });

    test('R-4: the staple fallback per diet', () {
      final staples = [
        food('Low Fat Paneer', 22, 160, category: 'Paneer & Dairy'),
        food('Masoor Dal', 8.2, 115, category: 'Dals & Legumes'),
        food('Greek Yogurt', 9, 95, category: 'Paneer & Dairy'),
        food('Roasted Chana', 10, 150, category: 'Pulses & Legumes'),
        food('Boiled Eggs (2 pieces)', 13, 155, category: 'Non-Veg'),
        food('Chicken Breast (Cooked)', 31, 165, category: 'Non-Veg'),
      ];
      List<String> pick(String diet, {Set<String> conflicts = const {}}) =>
          ProteinNudge.pick(
            staples,
            diet: diet,
            remainingKcal: 1000,
            conflictingFoodIds: conflicts,
          ).map((s) => s.name).toList();
      expect(pick('veg'), ['Low Fat Paneer', 'Greek Yogurt', 'Masoor Dal']);
      expect(pick('jain'), ['Low Fat Paneer', 'Greek Yogurt', 'Masoor Dal']);
      expect(pick('eggetarian'), [
        'Low Fat Paneer',
        'Greek Yogurt',
        'Boiled Eggs (2 pieces)',
      ]);
      expect(pick('non-veg'), [
        'Chicken Breast (Cooked)',
        'Low Fat Paneer',
        'Greek Yogurt',
      ]);
      expect(pick('vegan'), ['Masoor Dal', 'Roasted Chana']);
      expect(pick('veg', conflicts: {'Low Fat Paneer'}), [
        'Greek Yogurt',
        'Masoor Dal',
        'Roasted Chana',
      ]);
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
    var suggestions = [suggestion];
    setUp(() => suggestions = [suggestion]);

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
              (ref, args) async => suggestions,
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

    testWidgets('hides when no suggestion passes the floor', (tester) async {
      suggestions = const [];
      await pump(tester, DateTime.now().copyWith(hour: 19), 78);
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
