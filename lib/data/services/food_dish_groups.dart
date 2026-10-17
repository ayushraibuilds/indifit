import 'nutrition_food_search_ranking.dart';

/// Which way a dish variant differs from its dish (UR-05, UF-4).
enum DishVariantAxis { size, oil }

/// One chip in the portion sheet: a size or oil choice for a dish.
class DishVariantChip {
  const DishVariantChip({
    required this.axis,
    required this.label,
    required this.order,
  });

  final DishVariantAxis axis;

  /// What the chip says: "Mini", "Double", "Low oil", "Dhaba / extra ghee".
  final String label;

  /// Left-to-right position within its row.
  final int order;
}

/// Catalogue size and oil variants as one dish (UR-05, UF-4).
///
/// The pack names every variant "dish (label)" and links it to its dish
/// with `variant_of`. Search shows one row per dish; the portion sheet offers
/// the variants as chips: size (Mini · Regular · Double · Jumbo) and oil
/// (Low oil · Home · Dhaba / extra ghee), only those the dish has.
abstract final class FoodDishGroups {
  /// The chip the dish itself stands for on each axis.
  static const regular = DishVariantChip(
    axis: DishVariantAxis.size,
    label: 'Regular',
    order: 2,
  );
  static const home = DishVariantChip(
    axis: DishVariantAxis.oil,
    label: 'Home',
    order: 1,
  );

  /// Pack variant label -> chip. Labels not listed here (none in pack 5)
  /// get no chip, so the variant stays reachable only by searching its name.
  static const Map<String, DishVariantChip> _chips = {
    'Mini': DishVariantChip(
      axis: DishVariantAxis.size,
      label: 'Mini',
      order: 0,
    ),
    'Mini size': DishVariantChip(
      axis: DishVariantAxis.size,
      label: 'Mini',
      order: 0,
    ),
    'Small side bowl': DishVariantChip(
      axis: DishVariantAxis.size,
      label: 'Small',
      order: 0,
    ),
    'Half plate': DishVariantChip(
      axis: DishVariantAxis.size,
      label: 'Half',
      order: 1,
    ),
    'Double': DishVariantChip(
      axis: DishVariantAxis.size,
      label: 'Double',
      order: 3,
    ),
    'Double serving': DishVariantChip(
      axis: DishVariantAxis.size,
      label: 'Double',
      order: 3,
    ),
    'Double healthy bowl': DishVariantChip(
      axis: DishVariantAxis.size,
      label: 'Double',
      order: 3,
    ),
    'Jumbo / Large': DishVariantChip(
      axis: DishVariantAxis.size,
      label: 'Jumbo',
      order: 4,
    ),
    'Large cup / Tall Glass': DishVariantChip(
      axis: DishVariantAxis.size,
      label: 'Large',
      order: 4,
    ),
    'Low Oil cooking': DishVariantChip(
      axis: DishVariantAxis.oil,
      label: 'Low oil',
      order: 0,
    ),
    'Low Oil / Diet version': DishVariantChip(
      axis: DishVariantAxis.oil,
      label: 'Low oil',
      order: 0,
    ),
    'Diet prep (Low oil / breast only)': DishVariantChip(
      axis: DishVariantAxis.oil,
      label: 'Low oil',
      order: 0,
    ),
    'Dhaba Style (High oil)': DishVariantChip(
      axis: DishVariantAxis.oil,
      label: 'Dhaba / extra ghee',
      order: 2,
    ),
    'Premium ghee / extra oil': DishVariantChip(
      axis: DishVariantAxis.oil,
      label: 'Dhaba / extra ghee',
      order: 2,
    ),
    'Extra Butter / Ghee': DishVariantChip(
      axis: DishVariantAxis.oil,
      label: 'Dhaba / extra ghee',
      order: 2,
    ),
  };

  /// Words in a label that don't name the variant on their own.
  static const Set<String> _genericLabelWords = {
    'style',
    'cooking',
    'version',
    'serving',
    'size',
    'bowl',
    'healthy',
    'side',
    'prep',
    'only',
    'extra',
    'premium',
    'plate',
    'cup',
    'glass',
    'diet',
    'breast',
  };

  /// The label of [variantName] relative to [baseName]: "Poha (Flattened
  /// Rice) (Double healthy bowl)" of "Poha (Flattened Rice)" is "Double
  /// healthy bowl". Null when the name doesn't follow the pattern.
  static String? labelOf(String variantName, String baseName) {
    final prefix = '$baseName (';
    if (!variantName.startsWith(prefix) || !variantName.endsWith(')')) {
      return null;
    }
    final label = variantName
        .substring(prefix.length, variantName.length - 1)
        .trim();
    return label.isEmpty ? null : label;
  }

  static DishVariantChip? chipFor(String label) => _chips[label];

  /// How many of [label]'s distinctive words the query names.
  static int _namedWords(String label, Set<String> queryTokens) {
    final words = NutritionFoodSearchVocabulary.normalize(
      label,
    ).split(' ').where((word) => word.isNotEmpty);
    return words
        .where((word) => !_genericLabelWords.contains(word))
        .where(queryTokens.contains)
        .length;
  }

  /// [ranked] with one row per dish, in ranked order.
  ///
  /// A dish's row is the dish itself unless the query names one of its
  /// variants ("double", "dhaba", "low oil", "mini"): then that variant.
  /// The row keeps the best score and match of the group, so a dish never
  /// drops because its variants matched better.
  static List<NutritionFoodSearchResult> collapse(
    String query,
    List<NutritionFoodSearchResult> ranked,
  ) {
    final queryTokens = NutritionFoodSearchVocabulary.normalize(
      query,
    ).split(' ').where((token) => token.isNotEmpty).toSet();
    final nameToKey = <String, String>{};
    for (final result in ranked) {
      final candidate = result.candidate;
      if (candidate.source == NutritionFoodSearchSource.remote) continue;
      if (candidate.variantOfFoodId == null) {
        nameToKey.putIfAbsent(candidate.displayName, () => _idOf(candidate));
      }
    }

    String? keyOf(NutritionFoodSearchCandidate candidate) {
      if (candidate.source == NutritionFoodSearchSource.remote) return null;
      final linked = candidate.variantOfFoodId;
      if (linked != null) return linked;
      // Before the catalogue links arrive, a name "<dish> (<label>)" whose
      // dish is also listed still groups with it.
      final open = candidate.displayName.lastIndexOf(' (');
      if (open > 0 && candidate.displayName.endsWith(')')) {
        final base = nameToKey[candidate.displayName.substring(0, open)];
        if (base != null) return base;
      }
      return _idOf(candidate);
    }

    final groups = <String, List<NutritionFoodSearchResult>>{};
    final order = <Object>[];
    for (final result in ranked) {
      final key = keyOf(result.candidate);
      if (key == null) {
        order.add(result);
        continue;
      }
      final members = groups[key];
      if (members == null) {
        groups[key] = [result];
        order.add(key);
      } else {
        members.add(result);
      }
    }

    NutritionFoodSearchResult pick(String key) {
      final members = groups[key]!;
      if (members.length == 1 &&
          members.single.candidate.variantOfFoodId == null) {
        return members.single;
      }
      final base = members
          .where(
            (member) =>
                member.candidate.variantOfFoodId == null &&
                (_idOf(member.candidate) == key ||
                    nameToKey[member.candidate.displayName] == key),
          )
          .firstOrNull;
      NutritionFoodSearchResult? named;
      var namedWords = 0;
      for (final member in members) {
        if (identical(member, base)) continue;
        final baseName = base?.candidate.displayName;
        final name = member.candidate.displayName;
        final label = baseName == null
            ? _lastBracket(name)
            : labelOf(name, baseName) ?? _lastBracket(name);
        if (label == null) continue;
        final words = _namedWords(label, queryTokens);
        if (words > namedWords) {
          named = member;
          namedWords = words;
        }
      }
      final chosen = named ?? base ?? members.first;
      final best = members.first; // ranked order: the best of the group
      if (identical(chosen, best)) return chosen;
      return NutritionFoodSearchResult(
        candidate: chosen.candidate,
        match: best.match,
        score: best.score,
      );
    }

    return [
      for (final entry in order)
        entry is String ? pick(entry) : entry as NutritionFoodSearchResult,
    ];
  }

  static String _idOf(NutritionFoodSearchCandidate candidate) =>
      candidate.canonicalIdentityId ?? candidate.id;

  static String? _lastBracket(String name) {
    if (!name.endsWith(')')) return null;
    var depth = 0;
    for (var i = name.length - 1; i >= 0; i--) {
      final char = name[i];
      if (char == ')') depth++;
      if (char == '(') depth--;
      if (depth == 0) {
        final label = name.substring(i + 1, name.length - 1).trim();
        return label.isEmpty ? null : label;
      }
    }
    return null;
  }
}
