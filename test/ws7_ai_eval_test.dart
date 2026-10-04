import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/features/nutrition_ai/meal_item_resolver.dart';
import 'package:indifit/features/nutrition_ai/natural_language_meal_service.dart';

import '../tool/ai_eval/ai_eval_data_check.dart';
import '../tool/ai_eval/ai_eval_scoring.dart';

NutritionFoodOption _food(String name) => NutritionFoodOption(
  id: 'food:$name',
  displayName: name,
  baseQuantity: Quantity.fromNum(amount: 1, unit: QuantityUnit.piece),
  facts: const {},
  sourceType: 'test',
  sourceReference: null,
  preparationId: null,
);

DecomposedFoodItem _predicted(
  String name, {
  NutritionFoodOption? match,
  List<NutritionFoodOption> choices = const [],
  double amount = 1,
  int kcal = 100,
  String? portionNote,
}) => DecomposedFoodItem(
  rawSegment: name,
  foodName: name,
  quantityAmount: amount,
  quantityUnit: 'piece',
  estimatedCalories: kcal,
  estimatedProtein: 0,
  estimatedCarbs: 0,
  estimatedFat: 0,
  matchedCatalogOption: match,
  catalogChoices: choices,
  portionNote: portionNote,
);

Future<double?> _kcal100(String name, double amount) async => 100 * amount;

void main() {
  // The database seeds the food catalogue from assets via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI eval dataset', () {
    final meals = MealCase.load('tool/ai_eval/meals.jsonl');

    test('has at least 60 meals with unique ids and positive amounts', () {
      expect(meals.length, greaterThanOrEqualTo(60));
      expect(meals.map((m) => m.id).toSet().length, meals.length);
      for (final meal in meals) {
        expect(meal.items, isNotEmpty, reason: meal.id);
        for (final item in meal.items) {
          expect(item.amount, greaterThan(0), reason: meal.id);
          expect(item.foods, isNotEmpty, reason: meal.id);
        }
      }
    });

    test(
      'every expected and default food exists in the catalogue with calories',
      () async {
        final db = AppDatabase.memory();
        addTearDown(db.close);
        final catalog = NutritionFoodCatalogRepository(
          db: db,
          registry: NutrientRegistry.fromAssetFileSync(
            'assets/data/nutrient_registry.json',
          ),
        );
        final missing = <String>[];
        for (final name in {
          for (final meal in meals)
            for (final item in meal.items) ...item.foods,
          // The resolver's everyday defaults must point at real foods too.
          ...MealItemResolver.genericDefaults.values,
        }) {
          final found = (await catalog.search(query: name)).any(
            (o) => o.displayName == name && o.facts['energy']?.point != null,
          );
          if (!found) missing.add(name);
        }
        expect(missing, isEmpty);
      },
    );
  });

  group('AI eval scoring', () {
    final roti = _food('Whole Wheat Roti / Chapati');
    final dal = _food('Yellow Dal Tadka');
    final meal = MealCase(
      id: 't1',
      text: '2 roti and dal',
      tags: const [],
      items: const [
        ExpectedItem(foods: ['Whole Wheat Roti / Chapati'], amount: 2),
        ExpectedItem(foods: ['Yellow Dal Tadka', 'Dal Fry'], amount: 1),
      ],
    );

    test('a correct auto-match with the right amount scores fully', () async {
      final score = await scoreMeal(meal, [
        _predicted('Roti', match: roti, amount: 2, kcal: 200),
        _predicted('Dal Tadka', match: dal, amount: 1, kcal: 100),
      ], _kcal100);

      expect(
        score.items.map((i) => i.outcome),
        everyElement(ItemOutcome.correct),
      );
      expect(score.items.every((i) => i.amountCorrect), isTrue);
      expect(score.kcalAbsolutePercentError, 0);
      expect(EvalSummary([score]).barFailures, isEmpty);
    });

    test('a reset amount is not counted as right', () async {
      final score = await scoreMeal(meal, [
        _predicted('Roti', match: roti, amount: 2),
        _predicted('Dal', match: dal, portionNote: 'Set the amount'),
      ], _kcal100);

      expect(score.items[1].outcome, ItemOutcome.correct);
      expect(score.items[1].amountCorrect, isFalse);
    });

    test('offered, wrong, estimate-only and missed are told apart', () async {
      final score = await scoreMeal(meal, [
        _predicted('Roti', choices: [_food('Rumali Roti'), roti]),
        _predicted('Dal Makhani', match: _food('Dal Makhani')),
      ], _kcal100);

      final outcomes = {
        for (final i in score.items) i.expected.foods.first: i.outcome,
      };
      expect(outcomes['Whole Wheat Roti / Chapati'], ItemOutcome.offered);
      expect(outcomes['Yellow Dal Tadka'], ItemOutcome.wrongAutoMatch);

      final missed = await scoreMeal(meal, [_predicted('Tadka dal')], _kcal100);
      expect(
        missed.items.map((i) => i.outcome),
        containsAll([ItemOutcome.detectedOnly, ItemOutcome.missed]),
      );
    });

    test('silent wrong matches fail the bar even with full recall', () async {
      final score = await scoreMeal(meal, [
        _predicted('Roti', match: roti, amount: 2),
        _predicted('Dal', match: _food('Dal Makhani')),
      ], _kcal100);

      final summary = EvalSummary([score]);
      expect(summary.itemRecall, 1);
      expect(summary.barFailures, isNotEmpty);
    });

    test('label fields within 1 % count, and absent stays null', () {
      const label = LabelCase(
        image: 'x.jpg',
        basis: 'per_100g',
        fields: {'calories': 454, 'protein': 6.9, 'trans_fat': null},
      );
      final score = scoreLabel(label, {
        'basis': 'per_100g',
        'nutrients': {
          'calories': {'value': 455},
          'protein': {'value': 7.5},
          'trans_fat': {'value': null},
        },
      });

      expect(score.total, 4);
      expect(score.correct, 3);
      expect(score.misses.single, startsWith('protein'));
    });
  });

  group('AI eval label and photo data', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('indifit_eval_data');
      Directory('${dir.path}/labels').createSync();
      Directory('${dir.path}/photos').createSync();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    void writeCases(String sub, Object cases) => File(
      '${dir.path}/$sub/cases.json',
    ).writeAsStringSync(jsonEncode(cases));

    void writeJpeg(String path, {int width = 64, bool gps = false}) {
      final image = img.Image(width: width, height: 32);
      if (gps) {
        image.exif.gpsIfd
          ..gpsLatitudeRef = 'N'
          ..gpsLatitude = 28.6
          ..gpsLongitudeRef = 'E'
          ..gpsLongitude = 77.2;
      }
      File('${dir.path}/$path').writeAsBytesSync(img.encodeJpg(image));
    }

    test('the committed label and photo data is usable', () {
      expect(checkEvalData('tool/ai_eval'), isEmpty);
    });

    test('accepts well-formed cases', () {
      writeJpeg('labels/parle-g.jpg');
      writeJpeg('photos/thali.jpg');
      writeCases('labels', [
        {
          'image': 'parle-g.jpg',
          'basis': 'per_100g',
          'fields': {'calories': 454, 'protein': 6.9, 'trans_fat': null},
        },
      ]);
      writeCases('photos', [
        {'image': 'thali.jpg', 'kcal': 650},
      ]);
      expect(checkEvalData(dir.path), isEmpty);
    });

    test('rejects cases that would break or skew a paid run', () {
      writeJpeg('labels/big.jpg', width: 2049);
      writeJpeg('labels/located.jpg', gps: true);
      writeJpeg('photos/big.jpg', width: 1025);
      writeCases('labels', [
        {
          'image': 'missing.jpg',
          'basis': 'per_100g',
          'fields': {'fat': 1},
        },
        {
          'image': 'big.jpg',
          'basis': 'per_pack',
          'fields': {'kcal': 1},
        },
        {'image': 'located.jpg', 'basis': 'per_serving', 'fields': {}},
      ]);
      writeCases('photos', [
        {'image': 'big.jpg', 'kcal': 0},
      ]);

      final problems = checkEvalData(dir.path).join('\n');
      expect(problems, contains('missing.jpg): image file not found'));
      expect(problems, contains('"basis" must be'));
      expect(problems, contains('unknown field "kcal"'));
      expect(problems, contains('2049×32 px is larger than the app sends'));
      expect(problems, contains('carries GPS location'));
      expect(problems, contains('"fields" must list'));
      expect(problems, contains('1025×32 px is larger than the app sends'));
      expect(problems, contains('"kcal" must be a number > 0'));
    });
  });
}
