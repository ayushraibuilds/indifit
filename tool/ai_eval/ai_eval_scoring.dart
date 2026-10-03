// Scoring for the WS7 AI evaluation harness (see tool/ai_eval/README.md).
//
// Pure Dart: the dataset checks and these metrics run in CI without calling
// the AI; only tool/ai_eval/run_eval_test.dart makes live requests.

import 'dart:convert';
import 'dart:io';

import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/features/nutrition_ai/meal_item_resolver.dart';
import 'package:indifit/features/nutrition_ai/natural_language_meal_service.dart';

/// Launch bar from docs/implementation/P0_REMEDIATION_PLAN.md (WS7 Phase 5),
/// plus a ceiling on silent wrong matches, the most harmful error.
abstract final class LaunchBar {
  static const itemRecall = 0.90;
  static const catalogMatch = 0.85;
  static const maxWrongAutoMatch = 0.03;
  static const labelFieldAccuracy = 0.95;
}

/// One expected food in a meal. [foods] lists acceptable catalogue names
/// (the catalogue has near-duplicates such as two dal tadkas); the first is
/// the reference for calories. [amount] counts the food's own catalogue
/// measure: pieces or servings, or grams for per-100 g foods.
class ExpectedItem {
  final List<String> foods;
  final double amount;

  const ExpectedItem({required this.foods, required this.amount});

  factory ExpectedItem.fromJson(Map<String, dynamic> json) {
    final food = json['food'];
    return ExpectedItem(
      foods: food is String ? [food] : List<String>.from(food as List),
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

class MealCase {
  final String id;
  final String text;
  final List<String> tags;
  final List<ExpectedItem> items;

  const MealCase({
    required this.id,
    required this.text,
    required this.tags,
    required this.items,
  });

  factory MealCase.fromJson(Map<String, dynamic> json) => MealCase(
    id: json['id'] as String,
    text: json['text'] as String,
    tags: List<String>.from((json['tags'] as List?) ?? const []),
    items: [
      for (final item in json['items'] as List)
        ExpectedItem.fromJson(item as Map<String, dynamic>),
    ],
  );

  static List<MealCase> load(String path) => [
    for (final line in File(path).readAsLinesSync())
      if (line.trim().isNotEmpty && !line.trimLeft().startsWith('//'))
        MealCase.fromJson(jsonDecode(line) as Map<String, dynamic>),
  ];
}

/// How one expected item fared.
enum ItemOutcome {
  /// Auto-matched to an acceptable catalogue food.
  correct,

  /// Not auto-matched, but an acceptable food is among the offered choices
  /// (one tap for the user).
  offered,

  /// Auto-matched to a food that isn't acceptable: a silent error.
  wrongAutoMatch,

  /// The AI produced an item for it, but no acceptable catalogue food was
  /// matched or offered (logged as an AI estimate, or the user must search).
  detectedOnly,

  /// No predicted item corresponds to it.
  missed,
}

class ItemScore {
  final ExpectedItem expected;
  final DecomposedFoodItem? predicted;
  final ItemOutcome outcome;

  /// Correct food, amount within 10 % and no "set the amount" note.
  final bool amountCorrect;

  const ItemScore(
    this.expected,
    this.predicted,
    this.outcome,
    this.amountCorrect,
  );
}

class MealScore {
  final MealCase meal;
  final List<ItemScore> items;
  final List<DecomposedFoodItem> extraPredictions;
  final double expectedKcal;
  final double predictedKcal;

  const MealScore({
    required this.meal,
    required this.items,
    required this.extraPredictions,
    required this.expectedKcal,
    required this.predictedKcal,
  });

  double get kcalAbsolutePercentError => expectedKcal == 0
      ? 0
      : (predictedKcal - expectedKcal).abs() / expectedKcal;
}

/// Calories of [amount] of the catalogue food named [name], as the app
/// would compute them; null when the food or its energy fact is missing.
typedef CatalogKcal = Future<double?> Function(String name, double amount);

/// Scores one meal. Predictions are matched to expected items greedily:
/// first by an acceptable bound food, then by an acceptable offered choice,
/// then by name similarity.
Future<MealScore> scoreMeal(
  MealCase meal,
  List<DecomposedFoodItem> predicted,
  CatalogKcal catalogKcal,
) async {
  final unused = [...predicted];
  final scores = <ItemScore>[];

  bool accepts(ExpectedItem e, NutritionFoodOption? option) =>
      option != null && e.foods.contains(option.displayName);

  DecomposedFoodItem? take(bool Function(DecomposedFoodItem) test) {
    for (final p in unused) {
      if (test(p)) {
        unused.remove(p);
        return p;
      }
    }
    return null;
  }

  final pending = <ExpectedItem>[];
  for (final e in meal.items) {
    final p = take((p) => accepts(e, p.matchedCatalogOption));
    if (p == null) {
      pending.add(e);
      continue;
    }
    final amountOk =
        p.portionNote == null &&
        (p.quantityAmount - e.amount).abs() <= 0.1 * e.amount;
    scores.add(ItemScore(e, p, ItemOutcome.correct, amountOk));
  }
  final stillPending = <ExpectedItem>[];
  for (final e in pending) {
    final p = take(
      (p) =>
          p.matchedCatalogOption == null &&
          p.catalogChoices.any((c) => e.foods.contains(c.displayName)),
    );
    if (p == null) {
      stillPending.add(e);
    } else {
      scores.add(ItemScore(e, p, ItemOutcome.offered, false));
    }
  }
  for (final e in stillPending) {
    final p = take((p) => _similar(p.foodName, e.foods));
    if (p == null) {
      scores.add(ItemScore(e, null, ItemOutcome.missed, false));
    } else if (p.matchedCatalogOption != null) {
      scores.add(ItemScore(e, p, ItemOutcome.wrongAutoMatch, false));
    } else {
      scores.add(ItemScore(e, p, ItemOutcome.detectedOnly, false));
    }
  }

  var expectedKcal = 0.0;
  for (final e in meal.items) {
    expectedKcal += await catalogKcal(e.foods.first, e.amount) ?? 0;
  }
  // What the review screen shows, which is what gets logged once any
  // pending choices are made.
  final predictedKcal = predicted.fold<double>(
    0,
    (sum, p) => sum + p.estimatedCalories,
  );

  return MealScore(
    meal: meal,
    items: scores,
    extraPredictions: unused,
    expectedKcal: expectedKcal,
    predictedKcal: predictedKcal,
  );
}

/// Shares a distinctive word with any acceptable name, ignoring generic
/// words, so "Dal" ~ "Toor Dal / Yellow Dal Tadka" but "Rice" !~ "Rice Kheer".
bool _similar(String predictedName, List<String> foods) {
  final words = MealItemResolver.normalize(predictedName).split(' ').toSet()
    ..removeAll(_genericWords);
  if (words.isEmpty) return false;
  for (final food in foods) {
    final foodWords = MealItemResolver.normalize(food).split(' ').toSet()
      ..removeAll(_genericWords);
    final shared = words.intersection(foodWords).length;
    if (shared > 0 && shared / words.length >= 0.5) return true;
  }
  return false;
}

const _genericWords = {
  'masala',
  'curry',
  'sabji',
  'dry',
  'plain',
  'fry',
  'style',
  'cooked',
  'piece',
  'pieces',
  'pc',
  'with',
  'indian',
  'north',
  'south',
};

/// Totals across meals.
class EvalSummary {
  final int meals;
  final int expectedItems;
  final int predictedItems;
  final Map<ItemOutcome, int> outcomes;
  final int amountCorrect;
  final List<double> kcalErrors;

  EvalSummary(List<MealScore> scores)
    : meals = scores.length,
      expectedItems = scores.fold(0, (n, s) => n + s.items.length),
      predictedItems = scores.fold(
        0,
        (n, s) =>
            n +
            s.extraPredictions.length +
            s.items.where((i) => i.predicted != null).length,
      ),
      outcomes = {
        for (final o in ItemOutcome.values)
          o: scores.fold(
            0,
            (n, s) => n + s.items.where((i) => i.outcome == o).length,
          ),
      },
      amountCorrect = scores.fold(
        0,
        (n, s) => n + s.items.where((i) => i.amountCorrect).length,
      ),
      kcalErrors = [for (final s in scores) s.kcalAbsolutePercentError]..sort();

  int _n(ItemOutcome o) => outcomes[o] ?? 0;
  int get _detected => expectedItems - _n(ItemOutcome.missed);

  double get itemRecall => expectedItems == 0 ? 0 : _detected / expectedItems;

  /// Predictions that correspond to an expected item.
  double get itemPrecision =>
      predictedItems == 0 ? 0 : _detected / predictedItems;

  /// Correct food auto-matched or offered as a choice.
  double get catalogMatch => expectedItems == 0
      ? 0
      : (_n(ItemOutcome.correct) + _n(ItemOutcome.offered)) / expectedItems;

  double get autoMatch =>
      expectedItems == 0 ? 0 : _n(ItemOutcome.correct) / expectedItems;

  double get wrongAutoMatch =>
      expectedItems == 0 ? 0 : _n(ItemOutcome.wrongAutoMatch) / expectedItems;

  double get amountAccuracy => _n(ItemOutcome.correct) == 0
      ? 0
      : amountCorrect / _n(ItemOutcome.correct);

  double get kcalMape => kcalErrors.isEmpty
      ? 0
      : kcalErrors.reduce((a, b) => a + b) / kcalErrors.length;

  double get kcalMedianApe =>
      kcalErrors.isEmpty ? 0 : kcalErrors[kcalErrors.length ~/ 2];

  /// Failures against [LaunchBar]; empty means the bar is met.
  List<String> get barFailures => [
    if (itemRecall < LaunchBar.itemRecall)
      'item recall ${pct(itemRecall)} < ${pct(LaunchBar.itemRecall)}',
    if (catalogMatch < LaunchBar.catalogMatch)
      'catalogue match ${pct(catalogMatch)} < ${pct(LaunchBar.catalogMatch)}',
    if (wrongAutoMatch > LaunchBar.maxWrongAutoMatch)
      'wrong auto-matches ${pct(wrongAutoMatch)} > '
          '${pct(LaunchBar.maxWrongAutoMatch)}',
  ];
}

/// One nutrition-label case: printed values on the label's main basis.
class LabelCase {
  final String image;
  final String basis;
  final Map<String, double?> fields;

  const LabelCase({
    required this.image,
    required this.basis,
    required this.fields,
  });

  factory LabelCase.fromJson(Map<String, dynamic> json) => LabelCase(
    image: json['image'] as String,
    basis: json['basis'] as String,
    fields: {
      for (final entry in (json['fields'] as Map<String, dynamic>).entries)
        entry.key: (entry.value as num?)?.toDouble(),
    },
  );
}

/// Fraction of [expected] fields the AI read correctly: within 1 % (or 0.1
/// absolute for small values), and null exactly when the label lacks it.
({int correct, int total, List<String> misses}) scoreLabel(
  LabelCase expected,
  Map<String, dynamic> response,
) {
  final nutrients =
      (response['nutrients'] as Map<String, dynamic>?) ?? const {};
  var correct = 0;
  final misses = <String>[];
  if (response['basis'] == expected.basis) {
    correct++;
  } else {
    misses.add('basis: ${response['basis']} != ${expected.basis}');
  }
  for (final entry in expected.fields.entries) {
    final raw = nutrients[entry.key];
    final got = raw is Map ? (raw['value'] as num?)?.toDouble() : null;
    final want = entry.value;
    final ok = want == null
        ? got == null
        : got != null &&
              ((got - want).abs() <= 0.01 * want.abs() ||
                  (got - want).abs() <= 0.1);
    if (ok) {
      correct++;
    } else {
      misses.add('${entry.key}: $got != $want');
    }
  }
  return (correct: correct, total: expected.fields.length + 1, misses: misses);
}

String pct(double value) => '${(value * 100).toStringAsFixed(1)}%';
