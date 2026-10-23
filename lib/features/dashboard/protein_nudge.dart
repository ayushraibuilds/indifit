import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/di/providers.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/typed_quantities.dart';
import '../../core/utils/app_logger.dart';
import '../../data/database/app_database.dart';
import 'weigh_in_reminder.dart';

/// The protein nudge on Today (UF-5): after 17:00, when a protein target
/// exists and at least 20 g of it is left, up to three foods that close the
/// gap. Never a notification.
abstract final class ProteinNudge {
  static const firstHour = 17;
  static const minimumGapGrams = 20.0;
  static const maxSuggestions = 3;

  /// How far back the person's own foods are read.
  static const historyWindow = Duration(days: 30);

  /// A suggestion needs at least this much protein per 100 kcal (R-4)...
  static const minProteinPer100Kcal = 6.0;

  /// ...and at least this much in the amount offered.
  static const minProteinPerServing = 8.0;

  /// Catalogue staples offered after the person's own foods, by name. Each
  /// still has to fit the diet and pass the floor at its default amount.
  static const staples = [
    'Paneer Bhurji',
    'Low Fat Paneer',
    'Masoor Dal / Red Lentil Soup',
    'Moong Dal Chilka (Cooked)',
    'Plain Curd / Dahi (Cow Milk)',
    'Greek Yogurt (Plain)',
    'Roasted Chana (with skin)',
    'Soybean Chunks Curry',
    'Sprouted Moong Salad / Sabji',
    'Boiled Eggs (2 pieces)',
    'Egg White Salad',
    'Chicken Breast (Cooked)',
  ];

  /// Whether [candidate] is dense enough to be worth suggesting.
  static bool meetsFloor(ProteinSuggestion candidate) =>
      candidate.proteinGrams >= minProteinPerServing &&
      candidate.proteinGrams * 100 >= minProteinPer100Kcal * candidate.kcal;

  static bool shouldShow({
    required DateTime localNow,
    required double? proteinTarget,
    required double? proteinEaten,
    required String? dismissedDate,
    required String todayLocalDate,
  }) {
    if (localNow.hour < firstHour) return false;
    if (proteinTarget == null || proteinTarget <= 0) return false;
    if (dismissedDate == todayLocalDate) return false;
    return proteinTarget - (proteinEaten ?? 0) >= minimumGapGrams;
  }

  /// Up to [limit] suggestions: the person's own foods first, then staples,
  /// each group by protein per kcal. Every one passes [meetsFloor], fits the
  /// diet, has no known constraint conflict and fits [remainingKcal]. Whey
  /// is only offered to someone who has logged it. Empty hides the card.
  /// "What can I eat?" (TF-2 A) uses the same rules with a longer list.
  static List<ProteinSuggestion> pick(
    Iterable<ProteinSuggestion> candidates, {
    required String diet,
    required double? remainingKcal,
    Set<String> conflictingFoodIds = const {},
    int limit = maxSuggestions,
  }) {
    final seen = <String>{};
    final fitting = <ProteinSuggestion>[];
    for (final candidate in candidates) {
      if (!seen.add(candidate.foodId)) continue;
      if (candidate.proteinGrams <= 0 || candidate.kcal <= 0) continue;
      if (!meetsFloor(candidate)) continue;
      if (!candidate.fromHistory && _whey.hasMatch(candidate.name)) continue;
      if (remainingKcal == null || candidate.kcal > remainingKcal) continue;
      if (conflictingFoodIds.contains(candidate.foodId)) continue;
      if (dietFit(diet, name: candidate.name, category: candidate.category) !=
          DietFit.fits) {
        continue;
      }
      fitting.add(candidate);
    }
    int byDensity(ProteinSuggestion a, ProteinSuggestion b) =>
        b.proteinPerKcal.compareTo(a.proteinPerKcal);
    final own = fitting.where((c) => c.fromHistory).toList()..sort(byDensity);
    final staples = fitting.where((c) => !c.fromHistory).toList()
      ..sort(byDensity);
    return [...own, ...staples].take(limit).toList(growable: false);
  }

  /// "You're 42 g short of protein."
  static String headline(double gapGrams) =>
      "You're ${gapGrams.round()} g short of protein.";
}

/// One food that would close part of the protein gap, with its facts for
/// the amount offered.
class ProteinSuggestion {
  const ProteinSuggestion({
    required this.foodId,
    required this.name,
    required this.quantity,
    required this.amountLabel,
    required this.proteinGrams,
    required this.kcal,
    required this.fromHistory,
    this.category,
  });

  final String foodId;
  final String name;
  final Quantity quantity;

  /// "1 katori".
  final String amountLabel;
  final double proteinGrams;
  final double kcal;
  final bool fromHistory;

  /// The catalogue category ("Non-Veg", "Paneer & Dairy"), when known.
  final String? category;

  double get proteinPerKcal => proteinGrams / kcal;

  /// "Paneer Bhurji (1 katori) = 16 g"; "Full Cream Milk (1 Glass) = 7 g"
  /// when the name already says the amount.
  String get line {
    final amount = _sayableAmount(amountLabel);
    final named =
        amount.isEmpty || ' ${_sayableAmount(name)} '.contains(' $amount ');
    return '${named ? name : '$name ($amountLabel)'} = '
        '${proteinGrams.round()} g';
  }
}

/// [text] lowercased, with only letters, digits and single spaces: "1 Glass"
/// and "(1 glass)" both say "1 glass".
String _sayableAmount(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]+'), ' ').trim();

enum DietFit { fits, conflicts, unknown }

final _meat = RegExp(
  r'\b(chicken|mutton|lamb|fish|prawns?|shrimp|keema|meat|beef|pork|crab|'
  r'tuna|salmon|seekh|tikka kebab)\b',
  caseSensitive: false,
);
final _egg = RegExp(
  r'\b(eggs?|omelett?e|anda|bhurji egg)\b',
  caseSensitive: false,
);
final _whey = RegExp(r'\bwhey\b', caseSensitive: false);
// Jain food leaves out onion, garlic and roots; matched by name.
final _jainExcluded = RegExp(
  r'\b(onions?|pyaa?z|kanda|garlic|lehsun|lahsun|potato(es)?|aloo|alu|'
  r'carrots?|gajar|radish|mooli|beet(root)?s?|ginger|adrak|turnips?|'
  r'shalgam|yams?|suran|jimikand|arbi|colocasia|sweet potato(es)?|'
  r'shakarkandi?|tapioca|sabudana|samosa|vada pav|pav bhaji|bharta)\b',
  caseSensitive: false,
);
final _dairy = RegExp(
  r'\b(paneer|milk|curd|dahi|ghee|butter|cheese|whey|lassi|raita|kheer|'
  r'khoa|malai|makhani|cream|chhena|yogurt|yoghurt)\b',
  caseSensitive: false,
);
const _plantCategories = {
  'Dals & Legumes',
  'Pulses & Legumes',
  'Healthy & Salads',
  'Vegetables & Sabji',
  'Vegetables & Sabjis',
  'Fruits',
  'Nuts & Seeds',
};

/// Whether a food fits [diet], from what the catalogue knows: its category
/// and its name. A food the catalogue can't place is [DietFit.unknown] and
/// is not suggested to anyone with a restriction.
DietFit dietFit(String diet, {required String name, String? category}) {
  final meat =
      category == 'Non-Veg' && !_egg.hasMatch(name) || _meat.hasMatch(name);
  final egg = _egg.hasMatch(name);
  final dairy =
      _dairy.hasMatch(name) ||
      category == 'Paneer & Dairy' ||
      category == 'Dairy';
  switch (diet.trim().toLowerCase()) {
    case 'veg' || 'vegetarian':
      if (meat || egg) return DietFit.conflicts;
      return category == null ? DietFit.unknown : DietFit.fits;
    case 'jain':
      // Vegetarian, without onion, garlic or roots. Dishes are matched by
      // name only, so a food the catalogue can't place is never offered.
      if (meat || egg || _jainExcluded.hasMatch(name)) {
        return DietFit.conflicts;
      }
      return category == null ? DietFit.unknown : DietFit.fits;
    case 'eggetarian':
      if (meat) return DietFit.conflicts;
      return category == null && !egg ? DietFit.unknown : DietFit.fits;
    case 'vegan':
      if (meat || egg || dairy) return DietFit.conflicts;
      return _plantCategories.contains(category)
          ? DietFit.fits
          : DietFit.unknown;
    case 'non-veg' || 'non_veg' || 'nonveg':
      return DietFit.fits;
    default:
      // An unknown diet value is treated as the strictest common one.
      return dietFit('veg', name: name, category: category);
  }
}

/// The catalogue category of [foodId], from the seed row it maps to.
Future<String?> catalogueCategory(AppDatabase db, String foodId) async {
  final row = await db
      .customSelect(
        'SELECT i.category AS category FROM nutrition_legacy_food_mappings m '
        'JOIN food_items i ON i.id = m.legacy_food_item_id '
        'WHERE m.food_id = ? LIMIT 1',
        variables: [Variable.withString(foodId)],
      )
      .getSingleOrNull();
  final category = row?.read<String?>('category')?.trim();
  return category == null || category.isEmpty ? null : category;
}

/// Bumped by "Not today" and after an add.
final proteinNudgeRevisionProvider = StateProvider<int>((ref) => 0);

/// The day "Not today" was tapped.
Future<void> dismissProteinNudge(SharedPreferences prefs, String localDate) =>
    prefs.setString(AppPreferenceKeys.prefProteinNudgeDismissedDate, localDate);

/// Everything [ProteinNudge.pick] needs: the person's recent foods and the
/// staples with their facts, the ids with a constraint conflict, and the
/// diet.
typedef ProteinCandidates = ({
  List<ProteinSuggestion> candidates,
  Set<String> conflicts,
  String diet,
});

/// The candidates behind the protein nudge and "What can I eat?".
final proteinCandidatesProvider = FutureProvider.autoDispose<ProteinCandidates>(
  (ref) async {
    ref.watch(proteinNudgeRevisionProvider);
    final db = ref.watch(databaseProvider);
    final catalog = await ref.watch(
      nutritionFoodCatalogRepositoryProvider.future,
    );
    final foods = await ref.watch(
      nutritionFoodLoggingCoordinatorProvider.future,
    );
    final readModels = await ref.watch(
      nutritionReadModelRepositoryProvider.future,
    );
    final now = ref.watch(weighInClockProvider)().toUtc();
    final history = await readModels.listHistory(
      userId: kLocalNutritionUserScopeId,
      fromUtc: now.subtract(ProteinNudge.historyWindow),
      toUtc: now,
    );
    // Newest first: the amount offered is the one last logged.
    final ordered = history.toList()
      ..sort((a, b) => b.loggedAtUtc.compareTo(a.loggedAtUtc));
    final wanted = <(String, Quantity?, bool)>[];
    final seen = <String>{};
    for (final record in ordered) {
      for (final item in record.items) {
        final foodId = item.foodId;
        if (foodId == null || item.originSourceType != 'direct_food') {
          continue;
        }
        if (seen.add(foodId)) {
          wanted.add((foodId, item.quantity.quantity, true));
        }
      }
    }
    for (final name in ProteinNudge.staples) {
      final row = await db
          .customSelect(
            'SELECT id FROM nutrition_foods WHERE display_name = ? '
            "AND lifecycle = 'active' LIMIT 1",
            variables: [Variable.withString(name)],
          )
          .getSingleOrNull();
      final id = row?.read<String>('id');
      if (id != null && seen.add(id)) wanted.add((id, null, false));
    }

    final candidates = <ProteinSuggestion>[];
    for (final (foodId, logged, fromHistory) in wanted) {
      try {
        final option = await catalog.getOption(foodId);
        if (option == null || option.isAiEstimate) continue;
        final quantity = logged ?? option.defaultLoggingQuantity;
        final preview = await foods.preview(option: option, quantity: quantity);
        final facts = preview.calculation.facts;
        final protein = facts['protein']?.point?.value.asDouble;
        final kcal = facts['energy']?.point?.value.asDouble;
        if (protein == null || kcal == null) continue;
        candidates.add(
          ProteinSuggestion(
            foodId: foodId,
            name: option.displayName,
            quantity: quantity,
            amountLabel:
                option.measure?.pickedAmountLabel(quantity) ??
                QuantityFormatter.format(quantity),
            proteinGrams: protein,
            kcal: kcal,
            fromHistory: fromHistory,
            category: await catalogueCategory(db, foodId),
          ),
        );
      } on Object catch (error) {
        AppLogger.warning('Protein suggestion skipped: $error', 'Nudge');
      }
    }

    final conflicts = <String>{};
    final constraints = ref.watch(nutritionConstraintRepositoryProvider);
    for (final candidate in candidates) {
      final result = await constraints.evaluateFood(
        userId: kLocalNutritionUserScopeId,
        foodId: candidate.foodId,
      );
      if (result.outcome == NutritionConstraintOutcome.confirmedConflict ||
          result.outcome == NutritionConstraintOutcome.possibleConflict) {
        conflicts.add(candidate.foodId);
      }
    }
    String diet = 'veg';
    try {
      diet = ref.watch(userProfileProvider).dietPreference;
    } on Object {
      // Safe: without a profile, suggestions use the strictest default.
    }
    return (candidates: candidates, conflicts: conflicts, diet: diet);
  },
);

/// Suggestions for a [gap] of protein and [remainingKcal]; empty when none
/// fit.
final proteinSuggestionsProvider = FutureProvider.autoDispose
    .family<List<ProteinSuggestion>, ({double gap, double? remainingKcal})>((
      ref,
      args,
    ) async {
      final found = await ref.watch(proteinCandidatesProvider.future);
      return ProteinNudge.pick(
        found.candidates,
        diet: found.diet,
        remainingKcal: args.remainingKcal,
        conflictingFoodIds: found.conflicts,
      );
    });
