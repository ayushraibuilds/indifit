import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/typed_quantities.dart';
import '../../core/utils/app_logger.dart';
import '../../data/catalog/catalog_pack.dart';
import '../../data/repositories/nutrition_recipe_log_coordinator.dart';
import 'protein_nudge.dart';

/// The ingredient words of pack 8 (assets/catalog/key_ingredients.json):
/// each canonical word with its other names, Hindi and Hinglish included.
class IngredientVocabulary {
  IngredientVocabulary(Map<String, List<String>> vocabulary)
    : _names = {
        for (final entry in vocabulary.entries) ...{
          entry.key: entry.key,
          for (final name in entry.value) name: entry.key,
        },
      },
      words = vocabulary.keys.toSet();

  /// Canonical words.
  final Set<String> words;
  final Map<String, String> _names;

  static const _longestName = 4;
  static const _fillers = {
    'and',
    'aur',
    'with',
    'some',
    'a',
    'an',
    'the',
    'of',
    'i',
    'have',
    'got',
    'hai',
    'hain',
    'thoda',
    'thodi',
    'bhi',
    'or',
    'fresh',
  };

  static IngredientVocabulary fromJson(Map<String, dynamic> json) =>
      IngredientVocabulary({
        for (final entry
            in (json['vocabulary'] as Map<String, dynamic>).entries)
          entry.key: (entry.value as List).cast<String>(),
      });

  /// The canonical word for one name, or null.
  String? wordFor(String name) {
    final key = name.trim().toLowerCase();
    return _names[key] ??
        (key.length > 3 && key.endsWith('s')
            ? _names[key.substring(0, key.length - 1)]
            : null);
  }

  /// Typed or spoken text -> canonical words, longest names first ("shimla
  /// mirch" before "mirch"), and the words no name matched.
  ({Set<String> words, List<String> unknown}) parse(String text) {
    final tokens = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{M}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final found = <String>{};
    final unknown = <String>[];
    var i = 0;
    while (i < tokens.length) {
      String? word;
      var used = 1;
      for (var n = _longestName; n >= 1 && word == null; n--) {
        if (i + n > tokens.length) continue;
        word = wordFor(tokens.sublist(i, i + n).join(' '));
        if (word != null) used = n;
      }
      if (word != null) {
        found.add(word);
      } else if (!_fillers.contains(tokens[i])) {
        unknown.add(tokens[i]);
      }
      i += used;
    }
    return (words: found, unknown: unknown);
  }
}

/// A catalogue dish and its key ingredients (pack 8).
class CookDish {
  const CookDish({
    required this.id,
    required this.name,
    required this.keyIngredients,
    this.category,
  });

  final String id;
  final String name;
  final String? category;
  final List<String> keyIngredients;
}

/// A dish against what you have.
class CookMatch {
  const CookMatch({required this.dish, required this.have});

  final CookDish dish;
  final List<String> have;

  List<String> get missing =>
      dish.keyIngredients.where((w) => !have.contains(w)).toList();

  double get share => have.length / dish.keyIngredients.length;

  /// "You have 3 of 4 · missing tomato"; "You have all 3".
  String get label {
    final total = dish.keyIngredients.length;
    final left = missing;
    return left.isEmpty
        ? 'You have all $total'
        : 'You have ${have.length} of $total · missing ${left.join(', ')}';
  }
}

/// A saved recipe and the ingredient words its foods name.
class CookRecipe {
  const CookRecipe({
    required this.id,
    required this.name,
    required this.words,
    this.versionId,
  });

  final String id;
  final String name;
  final String? versionId;
  final Set<String> words;

  /// Every ingredient word is in [have]. Foods that name no word (salt, oil,
  /// a spice) are pantry staples and don't count.
  bool coveredBy(Set<String> have) =>
      words.isNotEmpty && have.containsAll(words);
}

/// "Cook with what I have" (TF-2 C, Plus): deterministic key-ingredient
/// matching (D4), no AI. Saved recipes you can make come first, then
/// catalogue dishes by the share of their key ingredients you have.
abstract final class CookWithWhatIHave {
  static const maxDishes = 20;

  /// Ingredients offered as chips before anything is typed.
  static const commonIngredients = [
    'paneer',
    'potato',
    'onion',
    'tomato',
    'capsicum',
    'spinach',
    'peas',
    'cauliflower',
    'curd',
    'besan',
    'rice',
    'atta',
    'egg',
    'chicken',
    'toor dal',
    'moong',
  ];

  static List<CookRecipe> recipesFor(
    Iterable<CookRecipe> recipes,
    Set<String> have,
  ) =>
      recipes.where((recipe) => recipe.coveredBy(have)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Dishes with at least one key ingredient in [have] that fit [diet]
  /// (Jain included: a dish's name and key ingredients both count) and
  /// aren't in [conflicts], best share first.
  static List<CookMatch> rank(
    Iterable<CookDish> dishes,
    Set<String> have, {
    required String diet,
    Set<String> conflicts = const {},
    int limit = maxDishes,
  }) {
    final matches = <CookMatch>[];
    for (final dish in dishes) {
      if (dish.keyIngredients.isEmpty || conflicts.contains(dish.id)) continue;
      final has = dish.keyIngredients.where(have.contains).toList();
      if (has.isEmpty) continue;
      final described = '${dish.name} ${dish.keyIngredients.join(' ')}';
      if (dietFit(diet, name: described, category: dish.category) !=
          DietFit.fits) {
        continue;
      }
      matches.add(CookMatch(dish: dish, have: has));
    }
    matches.sort((a, b) {
      final share = b.share.compareTo(a.share);
      if (share != 0) return share;
      final count = b.have.length.compareTo(a.have.length);
      if (count != 0) return count;
      return a.dish.name.compareTo(b.dish.name);
    });
    return matches.take(limit).toList();
  }
}

final ingredientVocabularyProvider = FutureProvider<IngredientVocabulary>((
  ref,
) async {
  final text = await rootBundle.loadString(
    '${kBundledCatalogAssetDirectory}key_ingredients.json',
  );
  return IngredientVocabulary.fromJson(
    jsonDecode(text) as Map<String, dynamic>,
  );
});

/// The bundled pack's dishes with key ingredients: active dishes, no
/// variants (a variant is its dish).
final cookDishesProvider = FutureProvider<List<CookDish>>((ref) async {
  final manifest = CatalogPackManifest.parse(
    jsonDecode(await rootBundle.loadString(kBundledCatalogManifestAsset)),
  );
  final entry = manifest.fullPack(kBundledCatalogPackVersion);
  final bytes = await rootBundle.load(
    '$kBundledCatalogAssetDirectory${entry.url}',
  );
  final pack =
      jsonDecode(utf8.decode(gzip.decode(bytes.buffer.asUint8List())))
          as Map<String, dynamic>;
  final retired = {
    for (final entry in (pack['retire'] as List? ?? const []))
      (entry as Map<String, dynamic>)['id'] as String,
  };
  return [
    for (final raw in pack['foods'] as List)
      if (raw case {
        'id': final String id,
        'display_name': final String name,
        'key_ingredients': final List<dynamic> words,
      } when !retired.contains(id) && raw['variant_of'] == null)
        CookDish(
          id: id,
          name: name,
          category: raw['category'] as String?,
          keyIngredients: words.cast<String>(),
        ),
  ];
});

/// The user's saved recipes, each with the ingredient words its foods name.
final cookRecipesProvider = FutureProvider.autoDispose<List<CookRecipe>>((
  ref,
) async {
  final vocabulary = await ref.watch(ingredientVocabularyProvider.future);
  final recipes = ref.watch(nutritionRecipeRepositoryProvider);
  final catalog = await ref.watch(
    nutritionFoodCatalogRepositoryProvider.future,
  );
  final out = <CookRecipe>[];
  for (final recipe in await recipes.listRecipes(
    userId: kLocalNutritionUserScopeId,
  )) {
    final versionId = recipe.currentVersionId;
    if (versionId == null) continue;
    final version = await recipes.getVersion(versionId);
    if (version == null) continue;
    final words = <String>{};
    for (final ingredient in version.ingredients) {
      final option = await catalog.getOption(ingredient.foodId);
      if (option == null) continue;
      words.addAll(vocabulary.parse(option.displayName).words);
    }
    out.add(
      CookRecipe(
        id: recipe.id,
        name: recipe.name,
        versionId: versionId,
        words: words,
      ),
    );
  }
  return out;
});

/// A stable family key for a set of ingredient words.
String cookHaveKey(Set<String> have) => (have.toList()..sort()).join('|');

/// One result row: kcal and protein per default serving, from the catalogue
/// (a saved recipe: per serving, or the whole recipe without one).
class CookResult {
  const CookResult({
    required this.id,
    required this.name,
    required this.detail,
    required this.kcal,
    required this.proteinGrams,
    required this.amountLabel,
    this.quantity,
    this.isRecipe = false,
  });

  final String id;
  final String name;

  /// "You have 3 of 4 · missing tomato", or "You have everything" for a
  /// recipe.
  final String detail;
  final double? kcal;
  final double? proteinGrams;
  final String amountLabel;
  final Quantity? quantity;
  final bool isRecipe;
}

/// Results for the ingredients in [cookHaveKey] form.
final cookResultsProvider = FutureProvider.autoDispose
    .family<List<CookResult>, String>((ref, key) async {
      final have = key.isEmpty ? <String>{} : key.split('|').toSet();
      if (have.isEmpty) return const [];
      final dishes = await ref.watch(cookDishesProvider.future);
      final recipes = await ref.watch(cookRecipesProvider.future);
      final catalog = await ref.watch(
        nutritionFoodCatalogRepositoryProvider.future,
      );
      final foods = await ref.watch(
        nutritionFoodLoggingCoordinatorProvider.future,
      );
      String diet = 'veg';
      try {
        diet = ref.watch(userProfileProvider).dietPreference;
      } on Object {
        // Safe: without a profile, the strictest default.
      }
      // Constraints are checked for the dishes that could show.
      final candidates = CookWithWhatIHave.rank(
        dishes,
        have,
        diet: diet,
        limit: CookWithWhatIHave.maxDishes * 2,
      );
      final constraints = ref.watch(nutritionConstraintRepositoryProvider);
      final conflicts = <String>{};
      for (final match in candidates) {
        final result = await constraints.evaluateFood(
          userId: kLocalNutritionUserScopeId,
          foodId: match.dish.id,
        );
        if (result.outcome == NutritionConstraintOutcome.confirmedConflict ||
            result.outcome == NutritionConstraintOutcome.possibleConflict) {
          conflicts.add(match.dish.id);
        }
      }
      final results = <CookResult>[];
      final coordinator = await ref.watch(
        nutritionRecipeLogCoordinatorProvider.future,
      );
      for (final recipe in CookWithWhatIHave.recipesFor(recipes, have)) {
        double? kcal;
        double? protein;
        var amount = '1 serving';
        try {
          final version = await ref
              .read(nutritionRecipeRepositoryProvider)
              .getVersion(recipe.versionId!);
          final perServing = version?.servingDefinition != null;
          amount = perServing ? '1 serving' : 'Whole recipe';
          final preview = await coordinator.preview(
            userId: kLocalNutritionUserScopeId,
            recipeId: recipe.id,
            recipeVersionId: recipe.versionId,
            amount: perServing
                ? NutritionRecipeLogAmount.declaredServing()
                : NutritionRecipeLogAmount.wholeRecipe(),
          );
          final facts = preview.calculation.facts;
          kcal = facts['energy']?.point?.value.asDouble;
          protein = facts['protein']?.point?.value.asDouble;
        } on Object catch (error) {
          AppLogger.warning('Cook recipe preview skipped: $error', 'Cook');
        }
        results.add(
          CookResult(
            id: recipe.id,
            name: recipe.name,
            detail: 'You have everything',
            kcal: kcal,
            proteinGrams: protein,
            amountLabel: amount,
            isRecipe: true,
          ),
        );
      }
      for (final match
          in candidates
              .where((m) => !conflicts.contains(m.dish.id))
              .take(CookWithWhatIHave.maxDishes)) {
        try {
          final option = await catalog.getOption(match.dish.id);
          if (option == null || option.isAiEstimate) continue;
          final quantity = option.defaultLoggingQuantity;
          final preview = await foods.preview(
            option: option,
            quantity: quantity,
          );
          final facts = preview.calculation.facts;
          final kcal = facts['energy']?.point?.value.asDouble;
          if (kcal == null) continue;
          results.add(
            CookResult(
              id: match.dish.id,
              name: option.displayName,
              detail: match.label,
              kcal: kcal,
              proteinGrams: facts['protein']?.point?.value.asDouble,
              amountLabel:
                  option.measure?.pickedAmountLabel(quantity) ??
                  QuantityFormatter.format(quantity),
              quantity: quantity,
            ),
          );
        } on Object catch (error) {
          AppLogger.warning('Cook dish skipped: $error', 'Cook');
        }
      }
      return results;
    });
