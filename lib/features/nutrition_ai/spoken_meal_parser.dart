import '../../core/typed_quantities.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../../data/services/food_query_amount.dart';
import '../../data/services/food_search_pipeline.dart';
import 'natural_language_meal_service.dart';

/// A spoken part's food: food search's top result, and the amount said.
class SpokenFoodMatch {
  const SpokenFoodMatch(this.option, this.amount);

  final NutritionFoodOption option;
  final FoodQueryAmount? amount;
}

typedef SpokenFoodLookup = Future<SpokenFoodMatch?> Function(String part);

/// What was said, as review-card items, and the parts no food matched.
class SpokenMealParse {
  const SpokenMealParse({
    required this.transcript,
    required this.items,
    required this.notFound,
  });

  final String transcript;
  final List<DecomposedFoodItem> items;
  final List<String> notFound;
}

/// Turns spoken words into food items on the phone, with no AI (D3,
/// TF-2 B): the transcript splits on aur / and / with / commas, each part
/// goes through food search's amount stripping and its top result, and
/// the catalogue gives the nutrition.
class SpokenMealParser {
  SpokenMealParser._();

  static final RegExp _separator = RegExp(
    r'\s*,\s*|\s+(?:and|aur|with|और)\s+|\s*\+\s*',
    caseSensitive: false,
  );

  /// Hindi number words said as amounts, Latin and Devanagari.
  static const Map<String, String> hindiNumbers = {
    'ek': '1',
    'do': '2',
    'teen': '3',
    'char': '4',
    'chaar': '4',
    'paanch': '5',
    'panch': '5',
    'aadha': '0.5',
    'adha': '0.5',
    'aadhi': '0.5',
    'dedh': '1.5',
    'dhai': '2.5',
    'एक': '1',
    'दो': '2',
    'तीन': '3',
    'चार': '4',
    'पांच': '5',
    'पाँच': '5',
    'आधा': '0.5',
    'आधी': '0.5',
    'डेढ़': '1.5',
    'ढाई': '2.5',
  };

  static const Set<String> _units = {
    'katori',
    'katoris',
    'bowl',
    'bowls',
    'cup',
    'cups',
    'glass',
    'glasses',
    'plate',
    'plates',
    'piece',
    'pieces',
    'slice',
    'slices',
    'spoon',
    'spoons',
    'tbsp',
    'tsp',
    'serving',
    'servings',
    'scoop',
    'scoops',
  };

  /// The parts of [transcript], each with its Hindi number words as digits.
  static List<String> split(String transcript) => [
    for (final part in transcript.trim().split(_separator))
      if (part.trim().isNotEmpty) normaliseNumbers(part.trim()),
  ];

  /// "do roti" -> "2 roti", "dal ek katori" -> "dal 1 katori". A number word
  /// counts only first, last or before a unit, so "Bhindi Do Pyaza" keeps
  /// its name.
  static String normaliseNumbers(String part) {
    final words = part.split(RegExp(r'\s+'));
    for (var i = 0; i < words.length; i++) {
      final digit = hindiNumbers[words[i].toLowerCase()];
      if (digit == null || words.length == 1) continue;
      final before =
          i + 1 < words.length && _units.contains(words[i + 1].toLowerCase());
      if (i == 0 || i == words.length - 1 || before) words[i] = digit;
    }
    return words.join(' ');
  }

  static Future<SpokenMealParse> parse(
    String transcript,
    SpokenFoodLookup lookup,
  ) async {
    final items = <DecomposedFoodItem>[];
    final notFound = <String>[];
    for (final part in split(transcript)) {
      final match = await lookup(part);
      if (match == null) {
        notFound.add(part);
        continue;
      }
      items.add(_item(part, match));
    }
    return SpokenMealParse(
      transcript: transcript.trim(),
      items: items,
      notFound: notFound,
    );
  }

  static DecomposedFoodItem _item(String part, SpokenFoodMatch match) {
    final option = match.option;
    final amount = match.amount;
    // A bare number counts the food in its own unit ("2 roti").
    final unit =
        amount?.unit ??
        option.measure?.unit ??
        (option.baseQuantity.unit == QuantityUnit.piece ? 'piece' : 'serving');
    return bindToCatalog(
      DecomposedFoodItem(
        rawSegment: part,
        foodName: option.displayName,
        quantityAmount: amount?.amount ?? 1,
        quantityUnit: unit,
        estimatedCalories: 0,
        estimatedProtein: 0,
        estimatedCarbs: 0,
        estimatedFat: 0,
        confidence: 'high',
      ),
      option,
    );
  }
}

/// Food search's top result for a spoken part (UR-52's pipeline), when the
/// catalogue has its nutrition.
SpokenFoodLookup spokenFoodLookup(
  FoodRepository foods,
  NutritionFoodCatalogRepository catalog,
) {
  final pipeline = FoodSearchPipeline(foods, optionFor: catalog.getOption);
  return (part) async {
    final (resolved, ranked) = await pipeline.search(part);
    if (ranked.isEmpty) return null;
    final candidate = ranked.first.candidate;
    final id =
        candidate.option?.id ??
        candidate.canonicalIdentityId ??
        (candidate.food == null
            ? null
            : (await catalog.ensureLegacyFood(candidate.food!)).id);
    if (id == null) return null;
    final option = await catalog.getOption(id);
    if (option == null || option.facts['energy']?.point == null) return null;
    return SpokenFoodMatch(option, resolved.amount);
  };
}
