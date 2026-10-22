import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/di/providers.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/typed_quantities.dart';
import '../../data/repositories/nutrition_recipe_log_coordinator.dart';
import '../../data/repositories/nutrition_recipe_repository.dart';

/// The milk in My chai: catalogue foods measured per 100 ml (pack 6,
/// usda-ingredients-v1).
enum MyChaiMilk {
  fullCream('full_cream', 'Full cream', 'food-usda-0302'),
  toned('toned', 'Toned', 'food-usda-0303'),
  doubleToned('double_toned', 'Double toned', 'food-usda-0304'),
  skimmed('skimmed', 'Skimmed', 'food-usda-0305');

  const MyChaiMilk(this.stableId, this.label, this.foodId);

  final String stableId;
  final String label;
  final String foodId;

  static MyChaiMilk? fromStableId(String? id) {
    for (final milk in values) {
      if (milk.stableId == id) return milk;
    }
    return null;
  }
}

/// How much of the cup is milk; the rest is tea water, which the catalogue
/// counts as nothing (food-usda-0100 does the same). [none] is black tea:
/// its facts are just the sugar (R-10).
enum MyChaiMilkShare {
  none('none', 'No milk (black tea)', 0, 1),
  third('third', '⅓ milk', 1, 3),
  half('half', '½ milk', 1, 2),
  all('all', 'All milk', 1, 1);

  const MyChaiMilkShare(this.stableId, this.label, this.numerator, this.of);

  final String stableId;
  final String label;
  final int numerator;
  final int of;

  static MyChaiMilkShare? fromStableId(String? id) {
    for (final share in values) {
      if (share.stableId == id) return share;
    }
    return null;
  }
}

/// The catalogue sugar (food-usda-0301) and SR Legacy's own teaspoon.
const String kMyChaiSugarFoodId = 'food-usda-0301';
const double kSugarGramsPerTeaspoon = 4.2;

const List<double> kMyChaiSugarChoices = [0, 0.5, 1, 1.5, 2, 3];
const List<int> kMyChaiCupChoicesMillilitres = [100, 150, 200, 250];

/// The recipe "My chai" logs: set once in Household measures (UF-2).
class MyChaiSettings {
  const MyChaiSettings({
    required this.milk,
    required this.milkShare,
    required this.sugarTeaspoons,
    required this.cupMillilitres,
  });

  static const defaults = MyChaiSettings(
    milk: MyChaiMilk.toned,
    milkShare: MyChaiMilkShare.half,
    sugarTeaspoons: 1,
    cupMillilitres: 150,
  );

  final MyChaiMilk milk;
  final MyChaiMilkShare milkShare;
  final double sugarTeaspoons;
  final int cupMillilitres;

  double get milkMillilitres =>
      cupMillilitres * milkShare.numerator / milkShare.of;

  double get sugarGrams => sugarTeaspoons * kSugarGramsPerTeaspoon;

  /// Black tea: nothing from an animal, so it fits a vegan diet.
  bool get hasMilk => milkShare != MyChaiMilkShare.none;

  /// "75 ml toned milk + 1 tsp sugar (4.2 g), topped up with tea to 150 ml".
  String get recipeLine {
    if (!hasMilk) {
      final sugar = sugarTeaspoons == 0
          ? 'no sugar'
          : '${_number(sugarTeaspoons)} tsp sugar (${_number(sugarGrams)} g)';
      return 'Black tea, $cupMillilitres ml, $sugar';
    }
    final milkPart =
        '${_number(milkMillilitres)} ml ${milk.label.toLowerCase()} milk';
    final sugarPart = sugarTeaspoons == 0
        ? 'no sugar'
        : '${_number(sugarTeaspoons)} tsp sugar (${_number(sugarGrams)} g)';
    final tea = milkShare == MyChaiMilkShare.all
        ? 'brewed in the milk'
        : 'topped up with tea to $cupMillilitres ml';
    return '$milkPart + $sugarPart, $tea';
  }

  MyChaiSettings copyWith({
    MyChaiMilk? milk,
    MyChaiMilkShare? milkShare,
    double? sugarTeaspoons,
    int? cupMillilitres,
  }) => MyChaiSettings(
    milk: milk ?? this.milk,
    milkShare: milkShare ?? this.milkShare,
    sugarTeaspoons: sugarTeaspoons ?? this.sugarTeaspoons,
    cupMillilitres: cupMillilitres ?? this.cupMillilitres,
  );

  /// The saved chai, or null when it hasn't been set up.
  static MyChaiSettings? read(SharedPreferences prefs) {
    final milk = MyChaiMilk.fromStableId(
      prefs.getString(AppPreferenceKeys.prefMyChaiMilk),
    );
    final share = MyChaiMilkShare.fromStableId(
      prefs.getString(AppPreferenceKeys.prefMyChaiMilkShare),
    );
    final sugar = prefs.get(AppPreferenceKeys.prefMyChaiSugarTsp);
    final cup = prefs.get(AppPreferenceKeys.prefMyChaiCupMl);
    if (milk == null || share == null || sugar is! num || cup is! num) {
      return null;
    }
    if (sugar < 0 || cup <= 0) return null;
    if (share == MyChaiMilkShare.none && sugar == 0) return null;
    return MyChaiSettings(
      milk: milk,
      milkShare: share,
      sugarTeaspoons: sugar.toDouble(),
      cupMillilitres: cup.toInt(),
    );
  }

  Future<void> write(SharedPreferences prefs) async {
    await prefs.setString(AppPreferenceKeys.prefMyChaiMilk, milk.stableId);
    await prefs.setString(
      AppPreferenceKeys.prefMyChaiMilkShare,
      milkShare.stableId,
    );
    await prefs.setDouble(AppPreferenceKeys.prefMyChaiSugarTsp, sugarTeaspoons);
    await prefs.setInt(AppPreferenceKeys.prefMyChaiCupMl, cupMillilitres);
  }

  @override
  bool operator ==(Object other) =>
      other is MyChaiSettings &&
      other.milk == milk &&
      other.milkShare == milkShare &&
      other.sugarTeaspoons == sugarTeaspoons &&
      other.cupMillilitres == cupMillilitres;

  @override
  int get hashCode =>
      Object.hash(milk, milkShare, sugarTeaspoons, cupMillilitres);
}

String _number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

/// Recipe ids for My chai start with this; the rest is random, so a chai
/// deleted from saved recipes can be set up again.
const String kMyChaiRecipePrefix = 'my-chai::';
const String kMyChaiName = 'My chai';

/// Keeps the "My chai" recipe in step with [MyChaiSettings], and logs a cup.
/// The recipe calculator computes its facts from the catalogue milk and
/// sugar, so the logged chai is one item whose facts include the sugar.
class MyChaiRecipe {
  MyChaiRecipe({required this.recipes, required this.logging});

  final NutritionRecipeRepository recipes;
  final NutritionRecipeLogCoordinator logging;

  String _id(String kind) => '$kMyChaiRecipePrefix$kind::${const Uuid().v4()}';

  List<NutritionRecipeIngredientInput> _ingredients(MyChaiSettings chai) => [
    if (chai.hasMilk)
      NutritionRecipeIngredientInput.directFood(
        id: _id('milk'),
        foodId: chai.milk.foodId,
        quantity: Quantity.fromNum(
          amount: chai.milkMillilitres,
          unit: QuantityUnit.millilitre,
        ),
        position: 0,
      ),
    // Black tea always has sugar: My chai setup doesn't offer none.
    if (chai.sugarTeaspoons > 0)
      NutritionRecipeIngredientInput.directFood(
        id: _id('sugar'),
        foodId: kMyChaiSugarFoodId,
        quantity: Quantity.fromNum(
          amount: chai.sugarGrams,
          unit: QuantityUnit.gram,
        ),
        position: chai.hasMilk ? 1 : 0,
      ),
  ];

  Quantity _cup(MyChaiSettings chai) => Quantity.fromNum(
    amount: chai.cupMillilitres,
    unit: QuantityUnit.millilitre,
  );

  /// The live My chai recipe, if one exists.
  Future<NutritionRecipeModel?> find(String userId) async {
    final all = await recipes.listRecipes(
      userId: userId,
      includeArchived: true,
    );
    for (final recipe in all) {
      if (recipe.id.startsWith(kMyChaiRecipePrefix) &&
          recipe.lifecycle != NutritionRecipeLifecycle.deleted &&
          recipe.currentVersionId != null) {
        return recipe;
      }
    }
    return null;
  }

  /// Publishes [chai] as the current My chai recipe and returns its id.
  Future<String> save(String userId, MyChaiSettings chai) async {
    final existing = await find(userId);
    if (existing == null) {
      final recipeId = '$kMyChaiRecipePrefix${const Uuid().v4()}';
      final draft = await recipes.createRecipe(
        userId: userId,
        recipeId: recipeId,
        versionId: _id('version'),
        name: kMyChaiName,
        description: chai.recipeLine,
        ingredients: _ingredients(chai),
        yieldQuantity: _cup(chai),
      );
      await recipes.publishDraft(
        recipeId: recipeId,
        draftVersionId: draft.version.id,
      );
      return recipeId;
    }
    if (existing.lifecycle == NutritionRecipeLifecycle.archived) {
      await recipes.restoreRecipe(existing.id);
    }
    final draft = await recipes.createSuccessorDraft(
      recipeId: existing.id,
      versionId: _id('version'),
    );
    await recipes.updateDraft(
      recipeId: existing.id,
      draftVersionId: draft.version.id,
      name: kMyChaiName,
      description: chai.recipeLine,
      yieldQuantity: _cup(chai),
      ingredients: _ingredients(chai),
    );
    await recipes.publishDraft(
      recipeId: existing.id,
      draftVersionId: draft.version.id,
    );
    return existing.id;
  }

  /// A cup of My chai as it would be logged.
  Future<NutritionRecipeLogPreview> preview(
    String userId,
    MyChaiSettings chai,
  ) async {
    final recipeId = (await find(userId))?.id ?? await save(userId, chai);
    return logging.preview(
      userId: userId,
      recipeId: recipeId,
      amount: NutritionRecipeLogAmount.wholeRecipe(),
    );
  }

  /// Logs one cup into [mealCategory].
  Future<NutritionConsumptionSnapshot> log({
    required String userId,
    required MyChaiSettings chai,
    required String mealCategory,
    required DateTime loggedAtUtc,
    required String localDate,
    required String timezoneId,
  }) async {
    final id = 'my-chai-log::${const Uuid().v4()}';
    return logging.finalize(
      userId: userId,
      preview: await preview(userId, chai),
      mealCategory: mealCategory,
      loggedAt: loggedAtUtc,
      localDate: localDate,
      timezoneId: timezoneId,
      consumptionId: id,
      commandId: id,
      allowPartial: true,
    );
  }
}

/// The saved My chai; null until it's set up.
final myChaiSettingsProvider = Provider<MyChaiSettings?>((ref) {
  final prefs = sharedPreferencesOrNull(
    () => ref.watch(sharedPreferencesProvider),
  );
  return prefs == null ? null : MyChaiSettings.read(prefs);
});

/// Whether "+ Chai" fits [diet] (R-10): a vegan isn't offered a milky cup,
/// only black tea.
bool myChaiFitsDiet(MyChaiSettings chai, String? diet) =>
    !chai.hasMilk || diet?.trim().toLowerCase() != 'vegan';

/// The My chai that "+ Chai" logs on Today and in search: the saved chai
/// when it fits the person's diet, else null.
final offeredMyChaiProvider = Provider<MyChaiSettings?>((ref) {
  final chai = ref.watch(myChaiSettingsProvider);
  if (chai == null) return null;
  String? diet;
  try {
    diet = ref.watch(userProfileProvider).dietPreference;
  } catch (_) {
    // Safe: without a profile the diet is unknown and the chai is offered.
  }
  return myChaiFitsDiet(chai, diet) ? chai : null;
});

final myChaiRecipeProvider = FutureProvider<MyChaiRecipe>(
  (ref) async => MyChaiRecipe(
    recipes: ref.watch(nutritionRecipeRepositoryProvider),
    logging: await ref.watch(nutritionRecipeLogCoordinatorProvider.future),
  ),
);

/// Logs a cup of My chai into [mealCategory] on [day] (today by default).
Future<NutritionConsumptionSnapshot> logMyChai(
  WidgetRef ref, {
  required MyChaiSettings chai,
  required String mealCategory,
  DateTime? day,
}) async {
  final dates = LocalScheduleDateService();
  final timezoneId = await ref
      .read(localTimezoneServiceProvider)
      .currentTimezoneId();
  final target = day ?? DateTime.now();
  final localDate = dates.localDateFor(target, timezoneId);
  final isToday = localDate == dates.localDateFor(DateTime.now(), timezoneId);
  final recipe = await ref.read(myChaiRecipeProvider.future);
  return recipe.log(
    userId: kLocalNutritionUserScopeId,
    chai: chai,
    mealCategory: mealCategory,
    loggedAtUtc: isToday
        ? DateTime.now().toUtc()
        : dates.instantForLocalDate(localDate, timezoneId),
    localDate: localDate,
    timezoneId: timezoneId,
  );
}
