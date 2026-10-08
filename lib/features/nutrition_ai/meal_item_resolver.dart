import '../../core/typed_quantities.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../../data/services/food_name_spelling.dart';

/// How an AI-parsed food name relates to the local catalogue.
enum CatalogMatchState {
  /// One catalogue food clearly matches; nutrition comes from it.
  resolved,

  /// Several plausible foods; the user must pick before logging.
  needsChoice,

  /// Nothing plausible; the item can only be logged as an AI estimate.
  unmatched,
}

class ScoredFoodOption {
  final NutritionFoodOption option;
  final double score;

  const ScoredFoodOption(this.option, this.score);
}

class CatalogMatch {
  final CatalogMatchState state;

  /// The chosen food when [state] is [CatalogMatchState.resolved].
  final NutritionFoodOption? option;

  /// Best-first candidates when [state] is [CatalogMatchState.needsChoice].
  final List<NutritionFoodOption> choices;

  const CatalogMatch.resolved(NutritionFoodOption this.option)
    : state = CatalogMatchState.resolved,
      choices = const [];

  const CatalogMatch.needsChoice(this.choices)
    : state = CatalogMatchState.needsChoice,
      option = null;

  const CatalogMatch.unmatched()
    : state = CatalogMatchState.unmatched,
      option = null,
      choices = const [];
}

/// Maps AI-parsed food names onto the curated catalogue.
///
/// The AI only names the food; nutrition must come from the catalogue
/// whenever a match is trustworthy. Catalogue search is a plain substring
/// match sorted alphabetically, so taking its first result silently turned
/// "dal" into whichever dal sorts first. This ranks candidates instead and
/// only auto-selects a clear winner; anything close goes to the user.
class MealItemResolver {
  MealItemResolver({required this.search});

  final Future<List<NutritionFoodOption>> Function(String query) search;

  static const double _resolveThreshold = 0.9;
  static const double _clearLead = 0.1;
  static const double _choiceThreshold = 0.45;
  static const int _maxChoices = 3;
  static const int _maxTokenQueries = 3;

  /// Size/preparation variants ("Samosa (1 piece) (Mini size)") rank below
  /// their base dish by more than the auto-resolve lead: someone who says
  /// "samosa" means the plain one, and names a variant when they mean it.
  static const double _variantPenalty = 0.15;

  /// Generic names that mean one specific catalogue food in everyday use,
  /// tuned with the eval (tool/ai_eval). Without these, "roti" ranked
  /// "Rumali Roti" first, and the catalogue's near-duplicates (two dal
  /// tadkas, two rajmas, two choles) always forced a choice. Keys are
  /// normalised (lower-case, singular).
  static const Map<String, String> genericDefaults = {
    'roti': _chapati,
    'chapati': _chapati,
    'chapatti': _chapati,
    'phulka': _chapati,
    'rice': _rice,
    'chawal': _rice,
    'steamed rice': _rice,
    'cooked rice': _rice,
    'plain rice': _rice,
    'white rice': _rice,
    'chai': _chai,
    'tea': _chai,
    'masala chai': _chai,
    'dahi': _curd,
    'curd': _curd,
    'plain curd': _curd,
    'yogurt': _curd,
    'naan': 'Plain Naan',
    'paneer': 'Amul Fresh Paneer (Raw)',
    'raw paneer': 'Amul Fresh Paneer (Raw)',
    // Plain "dal" in an everyday meal is the yellow toor dal tadka (audit
    // C-06: "1 katori dal" offered Dal Makhani, Urad and Dal Fry instead).
    'dal': _dalTadka,
    'daal': _dalTadka,
    'dal tadka': _dalTadka,
    'yellow dal tadka': _dalTadka,
    'yellow dal': _dalTadka,
    'rajma': _rajma,
    'rajma masala': _rajma,
    'rajma curry': _rajma,
    'chole': _chole,
    'chole masala': _chole,
    'chana masala': _chole,
    'bhindi masala': _bhindi,
    'bhindi': _bhindi,
    'bhindi sabji': _bhindi,
    'dosa': 'Plain Dosa with Chutney',
    'plain dosa': 'Plain Dosa with Chutney',
    'lassi': 'Masala Lassi (Sweet)',
    'sweet lassi': 'Masala Lassi (Sweet)',
    'sprout salad': 'Sprouted Moong Salad',
    'moong sprout salad': 'Sprouted Moong Salad',
    'sprouted moong salad': 'Sprouted Moong Salad',
    // Names and spellings of duplicates merged on 2026-10-03
    // (kRetiredCatalogueFoods), so they still land on the kept food.
    'matar paneer': _matarPaneer,
    'mattar paneer': _matarPaneer,
    'paneer matar': _matarPaneer,
    'paneer mattar': _matarPaneer,
    'sambhar': 'Sambar',
    'south indian sambhar': 'Sambar',
    'punjabi kadhi pakora': 'Kadhi Pakora',
    'mix veg': _mixVeg,
    'mixed veg': _mixVeg,
    'mixed veg sabji': _mixVeg,
    'mix veg sabji': _mixVeg,
    'dum aloo punjabi': 'Dum Aloo',
    'torai': _torai,
    'torai curry': _torai,
    'torai ki sabji': _torai,
    'aloo methi dry': 'Aloo Methi',
    'aloo palak dry': 'Aloo Palak',
    'french bean poriyal': 'Beans Poriyal',
    'bean poriyal': 'Beans Poriyal',
    'raw banana fry': _rawBanana,
    'kacha kela fry': _rawBanana,
    'boiled egg': _boiledEggs,
    'hard boiled egg': _boiledEggs,
    'dhokla': _dhokla,
    'khaman dhokla': _dhokla,
    'aloo gobi': _alooGobi,
    'aloo gobi sabji': _alooGobi,
    'aloo gobi dry sabji': _alooGobi,
  };

  static const _chapati = 'Whole Wheat Roti / Chapati';
  static const _rice = 'Basmati White Rice (Cooked)';
  static const _chai = 'Masala Chai (with milk & sugar)';
  static const _curd = 'Plain Curd / Dahi (Cow Milk)';
  static const _dalTadka = 'Toor Dal / Yellow Dal Tadka';
  static const _rajma = 'Rajma Masala (Red Kidney Beans)';
  static const _chole = 'Chole Masala (Chickpea Curry)';
  static const _bhindi = 'Bhindi Masala (Okra)';
  static const _matarPaneer = 'Mattar Paneer';
  static const _mixVeg = 'Mix Vegetable Sabji';
  static const _torai = 'Torai Ki Sabji (Ridge Gourd)';
  static const _rawBanana = 'Raw Banana Stir Fry';
  static const _dhokla = 'Dhokla (2 pieces)';
  static const _boiledEggs = 'Boiled Eggs (2 pieces)';
  // Spelled "Gobbi" in the catalogue; the name is part of its identity key.
  static const _alooGobi = 'Aloo Gobbi (Dry Sabji)';

  Future<CatalogMatch> resolve(String foodName) async {
    final normalized = normalize(foodName);
    if (normalized.isEmpty) return const CatalogMatch.unmatched();

    final candidates = <String, NutritionFoodOption>{};
    void collect(List<NutritionFoodOption> options) {
      for (final option in options) {
        candidates.putIfAbsent(option.id, () => option);
      }
    }

    final preferred = genericDefaults[normalized];
    if (preferred != null) {
      final target = normalize(preferred);
      for (final option in await search(preferred)) {
        if (normalize(option.displayName) == target) {
          return CatalogMatch.resolved(option);
        }
      }
    }
    collect(await search(normalized));
    if (candidates.isEmpty) {
      // "Dal tadka with jeera" won't substring-match "Yellow Dal Tadka";
      // fall back to the most distinctive words, longest first.
      final tokens = _tokens(normalized).where((t) => t.length >= 3).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final token in tokens.take(_maxTokenQueries)) {
        collect(await search(token));
      }
    }

    return decide(rank(foodName, candidates.values));
  }

  /// Picks the outcome from a best-first ranking.
  static CatalogMatch decide(List<ScoredFoodOption> ranked) {
    if (ranked.isEmpty || ranked.first.score < _choiceThreshold) {
      return const CatalogMatch.unmatched();
    }
    final top = ranked.first;
    final runnerUp = ranked.length > 1 ? ranked[1].score : 0.0;
    if (top.score >= _resolveThreshold && top.score - runnerUp >= _clearLead) {
      return CatalogMatch.resolved(top.option);
    }
    // A size or oil variant ("Suji Upma (Double healthy bowl)") only crowds
    // the list when its base dish is offered too: the amount already says
    // how much. It stays when it is the best match, because then it was
    // named.
    final offered = {for (final s in ranked) s.option.id};
    final names = {for (final s in ranked) normalize(s.option.displayName)};
    bool crowds(ScoredFoodOption s) {
      if (identical(s, top)) return false;
      final base = s.option.variantOfFoodId;
      if (base != null) return offered.contains(base);
      return _isVariantOfAnother(s.option.displayName, names);
    }

    return CatalogMatch.needsChoice(
      ranked
          .where((s) => s.score >= _choiceThreshold && !crowds(s))
          .take(_maxChoices)
          .map((s) => s.option)
          .toList(growable: false),
    );
  }

  /// Ranks [candidates] against [foodName], best first.
  static List<ScoredFoodOption> rank(
    String foodName,
    Iterable<NutritionFoodOption> candidates,
  ) {
    final query = normalize(foodName);
    final queryTokens = _tokens(query).toSet();
    final preferred = genericDefaults[query];
    final preferredName = preferred == null ? null : normalize(preferred);
    final names = {
      for (final option in candidates) normalize(option.displayName),
    };
    final scored = [
      for (final option in candidates)
        ScoredFoodOption(
          option,
          normalize(option.displayName) == preferredName
              ? 1.0
              : _score(query, queryTokens, option.displayName) -
                    (_isVariantOfAnother(option.displayName, names)
                        ? _variantPenalty
                        : 0.0),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// "Rumali Roti (Mini)" is a variant when "Rumali Roti" is also a
  /// candidate; "Tandoori Roti (Wheat)" with no plain entry is not.
  static bool _isVariantOfAnother(String name, Set<String> candidateNames) {
    final base = _withoutTrailingGroup(name);
    return base != name && candidateNames.contains(normalize(base));
  }

  /// Drops a trailing parenthesised group, nested ones included:
  /// "Butter Chicken (Murgh Makhani) (Diet prep (Low oil))" ->
  /// "Butter Chicken (Murgh Makhani)".
  static String _withoutTrailingGroup(String name) {
    final trimmed = name.trimRight();
    if (!trimmed.endsWith(')')) return name;
    var depth = 0;
    for (var i = trimmed.length - 1; i >= 0; i--) {
      if (trimmed[i] == ')') depth++;
      if (trimmed[i] == '(') depth--;
      if (depth == 0) return trimmed.substring(0, i).trimRight();
    }
    return name;
  }

  static double _score(String query, Set<String> queryTokens, String name) {
    final full = normalize(name);
    if (full == query) return 1.0;

    // "Whole Wheat Roti / Chapati (Tawa)" also answers to "chapati" and
    // "whole wheat roti".
    final alternatives = name
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .split('/')
        .map(normalize)
        .where((alt) => alt.isNotEmpty);
    if (alternatives.contains(query)) return 0.95;

    final nameTokens = _tokens(full).toSet();
    if (queryTokens.isEmpty || nameTokens.isEmpty) return 0.0;
    final shared = queryTokens.intersection(nameTokens).length;
    if (shared == queryTokens.length) {
      // Every query word is present; prefer names with fewer extra words.
      return 0.6 + 0.3 * (queryTokens.length / nameTokens.length);
    }
    // Partial overlap ("dal tadka with jeera" vs "Yellow Dal Tadka") can
    // reach the choice list but never the auto-resolve threshold.
    final smaller = queryTokens.length < nameTokens.length
        ? queryTokens.length
        : nameTokens.length;
    return 0.7 * shared / smaller;
  }

  /// Lowercases, drops punctuation and parentheses, folds simple plurals
  /// ("2 rotis" and "Roti" compare equal) and everyday spellings ("sabzi"
  /// and "Sabji" compare equal).
  static String normalize(String input) => _tokens(
    foldFoodSpellings(
      input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' '),
    ),
  ).join(' ');

  static List<String> _tokens(String input) => input
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty && !_fillerWords.contains(token))
      .map(_singular)
      .toList(growable: false);

  static const _fillerWords = {'with', 'and', 'of', 'the', 'a', 'aur', 'ke'};

  static String _singular(String token) =>
      token.length > 3 && token.endsWith('s') && !token.endsWith('ss')
      ? token.substring(0, token.length - 1)
      : token;
}

/// What a catalogue food's nutrition is per, e.g. "katori" or "100 g".
String catalogBasisLabel(NutritionFoodOption option) {
  final label = option.servingUnitLabel?.trim();
  if (label != null && label.isNotEmpty) return label;
  final base = option.baseQuantity;
  final unit = switch (base.unit) {
    QuantityUnit.gram => 'g',
    QuantityUnit.millilitre => 'ml',
    QuantityUnit.piece => 'piece',
    _ => 'serving',
  };
  return '${base.amount} $unit';
}

/// How many pieces one serving of [option] holds, from the catalogue's
/// naming convention ("Boiled Eggs (2 pieces)", "Paneer Tikka (5 pcs)"), or
/// null when the name doesn't say.
int? piecesPerServing(NutritionFoodOption option) {
  final match = _piecesInName.firstMatch(option.displayName);
  return match == null ? null : int.parse(match.group(1)!);
}

final _piecesInName = RegExp(
  r'\((\d+)\s*(?:pieces?|pcs?)\)',
  caseSensitive: false,
);

/// The quantity to log for an AI-parsed amount against a catalogue food.
class PortionMapping {
  final Quantity quantity;

  /// True when the AI's unit could not be converted to this food's unit; the
  /// quantity is then one serving and the user must set the amount.
  final bool needsReview;
  final String? reviewReason;

  const PortionMapping._(this.quantity)
    : needsReview = false,
      reviewReason = null;

  const PortionMapping._review(this.quantity, String this.reviewReason)
    : needsReview = true;

  /// Converts only when the units genuinely agree. Applying the AI's number
  /// to the food's base unit logged "2 rotis" against a per-100 g food as
  /// 2 g, and "150 g rice" against a katori serving as 150 katori.
  static PortionMapping map({
    required double amount,
    required String unit,
    required NutritionFoodOption option,
  }) {
    final base = option.baseQuantity;
    final aiKind = _unitKind(unit);
    final described = '${_formatAmount(amount)} $unit'.trim();

    if (!amount.isFinite || amount <= 0) {
      return PortionMapping._review(
        base,
        'Set the amount: the AI did not give a usable quantity.',
      );
    }

    // "4 eggs" against "Boiled Eggs (2 pieces)", whose serving is two eggs:
    // log 2 servings rather than resetting the amount.
    final pieces = piecesPerServing(option);
    if (base.unit == QuantityUnit.serving &&
        aiKind == _UnitKind.piece &&
        pieces != null &&
        pieces > 1) {
      return PortionMapping._(
        Quantity.fromNum(
          amount: amount / pieces,
          unit: base.unit,
          context: base.context,
        ),
      );
    }

    final converted = _viaCatalogueMeasure(amount, unit, aiKind, option);
    if (converted != null) return PortionMapping._(converted);

    final matches = switch (base.unit) {
      QuantityUnit.gram => aiKind == _UnitKind.mass,
      QuantityUnit.millilitre => aiKind == _UnitKind.volume,
      QuantityUnit.piece => aiKind == _UnitKind.piece,
      QuantityUnit.serving =>
        aiKind == _UnitKind.serving ||
            _sameServing(unit, option.servingUnitLabel),
      _ => false,
    };
    if (matches) {
      // Keep the base quantity's context: a serving quantity is only valid
      // with its serving definition reference.
      return PortionMapping._(
        Quantity.fromNum(
          amount: amount,
          unit: base.unit,
          context: base.context,
        ),
      );
    }

    final target = option.servingUnitLabel ?? _baseLabel(base.unit);
    return PortionMapping._review(
      base,
      'Set the amount: "$described" doesn\'t convert to this food\'s '
      '$target measure.',
    );
  }

  /// Household vessels in katori: the app's katori is 150 g and its bowl
  /// 300 g (`food_catalog_service.dart`; the packs' gram rules), and a plate
  /// of rice, poha or biryani is two katori (roadmap P1-4).
  static const Map<String, double> _katoriPerVessel = {
    'katori': 1,
    'bowl': 2,
    'plate': 2,
  };
  static const double _gramsPerKatori = 150;

  /// Converts with the installed catalogue's own measure (CAT-4, CAT-12):
  /// vessels into the food's vessel ("1 bowl dal" is 2 katori), grams into
  /// servings through the serving's gram weight ("150 g rice" is 1 katori),
  /// and a vessel of a per-100 g dish into grams ("1 katori curd" is 150 g).
  /// Null when the measure can't say, so the caller asks the user.
  static Quantity? _viaCatalogueMeasure(
    double amount,
    String unit,
    _UnitKind aiKind,
    NutritionFoodOption option,
  ) {
    final measure = option.measure;
    if (measure == null) return null;
    final base = option.baseQuantity;
    final aiUnit = MealItemResolver.normalize(unit);
    // In standard katori. "Katori" is the person's own katori once they've
    // said its size; the bowl and plate stay the app's fixed sizes.
    final vessel = _katoriPerVessel[aiUnit];
    final aiKatori = vessel == null
        ? null
        : aiUnit == 'katori'
        ? measure.katoriScale
        : vessel;

    if (base.unit == QuantityUnit.gram) {
      // Only a base dish: per-100 g variants are dry snacks or mini rice
      // rows, where a cooked dish's 150 g katori would be wrong.
      if (aiKatori != null && option.variantOfFoodId == null) {
        return _grams(amount * aiKatori * _gramsPerKatori);
      }
      final grams = measure.gramsPerServing?.asDouble;
      if (aiKind == _UnitKind.serving && grams != null) {
        return _grams(amount * grams);
      }
      return null;
    }
    if (base.unit != QuantityUnit.serving) return null;

    double? servings;
    final unitsPerServing = measure.unitsPerServing?.asDouble;
    final foodUnit = measure.unit;
    final gramsPerServing = measure.gramsPerServing?.asDouble;
    if (aiKind == _UnitKind.mass && gramsPerServing != null) {
      servings = amount / gramsPerServing;
    } else if (foodUnit != null && unitsPerServing != null) {
      final foodKatori = _katoriPerVessel[foodUnit];
      if (aiKatori != null && foodKatori != null) {
        // The measure counts katori foods in the person's katori; back to
        // standard katori so every vessel compares on one scale.
        final standardUnits = foodUnit == 'katori'
            ? unitsPerServing * measure.katoriScale
            : unitsPerServing;
        servings = amount * aiKatori / foodKatori / standardUnits;
      } else if (aiKind == _UnitKind.piece && foodUnit == 'piece') {
        servings = amount / unitsPerServing;
      } else if (aiKind == _UnitKind.household && aiUnit == foodUnit) {
        // Same vessel the catalogue counts in: glass, cup.
        servings = amount / unitsPerServing;
      }
    }
    if (servings == null || !servings.isFinite || servings <= 0) return null;
    return Quantity.fromNum(
      amount: _round(servings),
      unit: base.unit,
      context: base.context,
    );
  }

  static Quantity _grams(double grams) =>
      Quantity.fromNum(amount: _round(grams), unit: QuantityUnit.gram);

  /// Two decimals: enough for a third of a katori, and no float noise
  /// ("0.30000000000000004") reaching the review card.
  static double _round(double value) => (value * 100).roundToDouble() / 100;

  static bool _sameServing(String aiUnit, String? servingLabel) {
    if (servingLabel == null) return false;
    final ai = _unitKind(aiUnit);
    final label = _unitKind(servingLabel);
    if (ai == _UnitKind.piece && label == _UnitKind.piece) return true;
    return ai == _UnitKind.household &&
        MealItemResolver.normalize(aiUnit) ==
            MealItemResolver.normalize(servingLabel);
  }

  static _UnitKind _unitKind(String unit) {
    final u = MealItemResolver.normalize(unit);
    if (const {'g', 'gm', 'gram', 'gr'}.contains(u)) return _UnitKind.mass;
    if (const {'ml', 'millilitre', 'milliliter'}.contains(u)) {
      return _UnitKind.volume;
    }
    if (const {'serving', 'portion'}.contains(u)) return _UnitKind.serving;
    if (const {
      'piece',
      'pc',
      'pcs',
      'roti',
      'chapati',
      'phulka',
      'paratha',
      'puri',
      'idli',
      'dosa',
      'egg',
      'slice',
      'nos',
      'no',
    }.contains(u)) {
      return _UnitKind.piece;
    }
    return _UnitKind.household;
  }

  static String _baseLabel(QuantityUnit unit) => switch (unit) {
    QuantityUnit.gram => 'gram',
    QuantityUnit.millilitre => 'millilitre',
    QuantityUnit.piece => 'piece',
    _ => 'serving',
  };

  static String _formatAmount(double amount) => amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toString();
}

enum _UnitKind { mass, volume, piece, serving, household }
