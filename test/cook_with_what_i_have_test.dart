import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/plus/plus_gate.dart';
import 'package:indifit/features/dashboard/cook_with_what_i_have.dart';
import 'package:indifit/features/dashboard/what_can_i_eat.dart';
import 'package:indifit/features/dashboard/widgets/what_can_i_eat_sheet.dart';
import 'package:indifit/features/nutrition/nutrition_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';

/// "Cook with what I have" (TF-2 C): key-ingredient matching, no AI (D4).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final vocabulary = IngredientVocabulary.fromJson(
    jsonDecode(File('assets/catalog/key_ingredients.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  const kadaiPaneer = CookDish(
    id: 'kadai',
    name: 'Kadai Paneer',
    category: 'Paneer & Dairy',
    keyIngredients: ['paneer', 'capsicum', 'onion', 'tomato'],
  );
  const mattarPaneer = CookDish(
    id: 'mattar',
    name: 'Mattar Paneer',
    category: 'Paneer & Dairy',
    keyIngredients: ['paneer', 'peas', 'onion', 'tomato'],
  );
  const paneerTikka = CookDish(
    id: 'tikka',
    name: 'Paneer Tikka (5 pcs)',
    category: 'Paneer & Dairy',
    keyIngredients: ['paneer', 'curd'],
  );
  const shimlaMirchAloo = CookDish(
    id: 'shimla',
    name: 'Shimla Mirch Aloo',
    category: 'Vegetables & Sabjis',
    keyIngredients: ['capsicum', 'potato'],
  );
  const chickenTikka = CookDish(
    id: 'chicken',
    name: 'Chicken Tikka (6 pcs)',
    category: 'Non-Veg',
    keyIngredients: ['chicken', 'curd'],
  );
  const dishes = [
    kadaiPaneer,
    mattarPaneer,
    paneerTikka,
    shimlaMirchAloo,
    chickenTikka,
  ];

  group('vocabulary', () {
    test('Hindi and Hinglish names normalise to one word', () {
      final parsed = vocabulary.parse('Paneer, shimla mirch aur pyaz');
      expect(parsed.words, {'paneer', 'capsicum', 'onion'});
      expect(parsed.unknown, isEmpty);
      expect(vocabulary.parse('2 tomatoes').words, {'tomato'});
      expect(vocabulary.parse('kuttu ka atta').words, {'kuttu atta'});
    });

    test('words outside the vocabulary are reported', () {
      final parsed = vocabulary.parse('paneer and dragonfruit');
      expect(parsed.words, {'paneer'});
      expect(parsed.unknown, ['dragonfruit']);
    });
  });

  group('ranking', () {
    test('dishes rank by the share of key ingredients you have', () {
      final ranked = CookWithWhatIHave.rank(dishes, {
        'paneer',
        'capsicum',
        'onion',
        'curd',
      }, diet: 'veg');
      expect(ranked.map((m) => m.dish.id), [
        'tikka', // 2 of 2
        'kadai', // 3 of 4
        'mattar', // 2 of 4
        'shimla', // 1 of 2
      ]);
    });

    test('the label counts what you have and names what is missing', () {
      final ranked = CookWithWhatIHave.rank(
        [kadaiPaneer, paneerTikka],
        {'paneer', 'capsicum', 'onion', 'curd'},
        diet: 'veg',
      );
      expect(ranked[0].label, 'You have all 2');
      expect(ranked[1].label, 'You have 3 of 4 · missing tomato');
    });

    test('diet and Jain filter dishes, key ingredients included', () {
      const have = {'paneer', 'capsicum', 'potato', 'curd', 'chicken'};
      expect(
        CookWithWhatIHave.rank(dishes, have, diet: 'veg').map((m) => m.dish.id),
        isNot(contains('chicken')),
      );
      expect(
        CookWithWhatIHave.rank(
          dishes,
          have,
          diet: 'non-veg',
        ).map((m) => m.dish.id),
        contains('chicken'),
      );
      // Jain: no onion (Kadai, Mattar) and no potato (Shimla Mirch Aloo),
      // though only the key ingredients say so.
      expect(
        CookWithWhatIHave.rank(
          dishes,
          have,
          diet: 'jain',
        ).map((m) => m.dish.id),
        ['tikka'],
      );
    });

    test('a dish with a constraint conflict is left out', () {
      expect(
        CookWithWhatIHave.rank(
          dishes,
          {'paneer', 'curd'},
          diet: 'veg',
          conflicts: {'tikka'},
        ).map((m) => m.dish.id),
        isNot(contains('tikka')),
      );
    });

    test('saved recipes whose ingredients you have come first', () {
      const recipes = [
        CookRecipe(id: 'r1', name: 'My Paneer', words: {'paneer', 'tomato'}),
        CookRecipe(id: 'r2', name: 'My Chole', words: {'chickpeas', 'onion'}),
        // Only pantry foods: nothing to match.
        CookRecipe(id: 'r3', name: 'Masala water', words: {}),
      ];
      expect(
        CookWithWhatIHave.recipesFor(recipes, {
          'paneer',
          'tomato',
          'onion',
        }).map((r) => r.id),
        ['r1'],
      );
    });

    test('pack 8 dishes match a typical fridge', () {
      final pack =
          jsonDecode(
                utf8.decode(
                  gzip.decode(
                    File('assets/catalog/pack-8.json.gz').readAsBytesSync(),
                  ),
                ),
              )
              as Map<String, dynamic>;
      final packDishes = [
        for (final raw in pack['foods'] as List)
          if (raw case {
            'id': final String id,
            'display_name': final String name,
            'key_ingredients': final List<dynamic> words,
          })
            CookDish(
              id: id,
              name: name,
              category: raw['category'] as String?,
              keyIngredients: words.cast<String>(),
            ),
      ];
      final ranked = CookWithWhatIHave.rank(
        packDishes,
        vocabulary.parse('paneer shimla mirch pyaz tamatar').words,
        diet: 'veg',
      );
      expect(ranked.first.dish.name, 'Kadai Paneer');
      expect(ranked.first.label, 'You have all 4');
    });
  });

  test('results carry the catalogue kcal and protein per serving', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await RealCatalogue.open();
    addTearDown(c.close);
    final container = ProviderContainer(overrides: loggedRecordsOverrides(c));
    addTearDown(container.dispose);
    final results = cookResultsProvider(
      cookHaveKey({'paneer', 'capsicum', 'onion', 'tomato'}),
    );
    final keep = container.listen(results, (_, _) {});
    addTearDown(keep.close);
    final rows = await container.read(results.future);
    final kadai = rows.first;
    expect(kadai.name, 'Kadai Paneer');
    expect(kadai.detail, 'You have all 4');
    final option = (await c.catalog.getOption(kadai.id))!;
    final foods = await container.read(
      nutritionFoodLoggingCoordinatorProvider.future,
    );
    final facts = (await foods.preview(
      option: option,
      quantity: option.defaultLoggingQuantity,
    )).calculation.facts;
    expect(kadai.kcal, facts['energy']!.point!.value.asDouble);
    expect(kadai.proteinGrams, facts['protein']!.point!.value.asDouble);
  });

  group('Plus flag', () {
    Future<void> pumpSheet(WidgetTester tester, {required bool plus}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [plusEnabledProvider.overrideWithValue(plus)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => WhatCanIEatSheet(
                  plan: const WhatCanIEatPlan.noTargets(),
                  day: DateTime(2026, 10, 27),
                  hostContext: context,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the link is hidden with the flag off', (tester) async {
      await pumpSheet(tester, plus: false);
      expect(find.text('Cook with what I have'), findsNothing);
    });

    testWidgets('the link shows with Plus on', (tester) async {
      await pumpSheet(tester, plus: true);
      expect(find.text('Cook with what I have'), findsOneWidget);
    });
  });
}
