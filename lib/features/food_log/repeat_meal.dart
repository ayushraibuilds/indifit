import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/nutrition_thali.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/typed_quantities.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../../data/repositories/nutrition_food_logging_coordinator.dart';
import '../../data/repositories/nutrition_recipe_log_coordinator.dart';
import '../../data/repositories/nutrition_thali_repository.dart';
import 'widgets/food_diary_widgets.dart';

/// Items from [records] that can be logged again as they are: single
/// catalogue foods. Thalis and recipes are repeated whole (see [planRepeat]).
List<NutritionHistoricalReadItem> repeatableMealItems(
  Iterable<NutritionHistoricalReadRecord> records,
) => [
  for (final record in records)
    for (final item in record.items)
      if (item.foodId != null && item.originSourceType == 'direct_food') item,
];

/// The records of [day] that belong to [mealType] (diary meal ids).
List<NutritionHistoricalReadRecord> recordsForMeal(
  Iterable<NutritionHistoricalReadRecord> records,
  String mealType,
) => records
    .where((record) => foodDiaryMealType(record.mealCategory) == mealType)
    .toList(growable: false);

/// A recipe log to repeat: the same recipe version and amount.
class RepeatRecipe {
  final String recipeId;
  final String recipeVersionId;
  final NutritionRecipeLogAmount amount;
  final String? label;

  const RepeatRecipe({
    required this.recipeId,
    required this.recipeVersionId,
    required this.amount,
    this.label,
  });
}

/// A thali log to repeat: the same thali, if it is still at [version].
class RepeatThali {
  final String thaliId;
  final int? version;
  final List<String> itemLabels;

  const RepeatThali({
    required this.thaliId,
    required this.version,
    required this.itemLabels,
  });
}

/// What "Repeat yesterday" would log from a meal's records.
class RepeatPlan {
  final List<NutritionHistoricalReadItem> foods;
  final List<RepeatThali> thalis;
  final List<RepeatRecipe> recipes;

  const RepeatPlan({
    required this.foods,
    required this.thalis,
    required this.recipes,
  });

  bool get isEmpty => foods.isEmpty && thalis.isEmpty && recipes.isEmpty;

  /// Names for the card: foods, each thali's items, recipes.
  List<String> get names => [
    for (final food in foods)
      if (food.displayLabel?.trim().isNotEmpty == true)
        food.displayLabel!.trim(),
    for (final thali in thalis) ...thali.itemLabels,
    for (final recipe in recipes)
      if (recipe.label?.trim().isNotEmpty == true) recipe.label!.trim(),
  ];

  /// Entries the plan logs: each food, each thali and each recipe once.
  int get entryCount => foods.length + thalis.length + recipes.length;
}

/// Plans a repeat of [records]: single foods as before, plus whole thalis
/// and recipes, which are logged again through their own flows so they stay
/// one thali or one recipe in the diary. Estimates and quick-adds are left
/// out: there is nothing exact to repeat.
RepeatPlan planRepeat(Iterable<NutritionHistoricalReadRecord> records) {
  final thalis = <RepeatThali>[];
  final recipes = <RepeatRecipe>[];
  final rest = <NutritionHistoricalReadRecord>[];
  for (final record in records) {
    final snapshot = record is NutritionCanonicalSnapshotReadModel
        ? record.snapshot
        : null;
    if (snapshot != null &&
        snapshot.sourceType == 'thali' &&
        snapshot.thaliId != null) {
      thalis.add(
        RepeatThali(
          thaliId: snapshot.thaliId!,
          version: _thaliVersion(snapshot),
          itemLabels: [
            for (final item in snapshot.items)
              if (item.displayLabel?.trim().isNotEmpty == true)
                item.displayLabel!.trim(),
          ],
        ),
      );
      continue;
    }
    final recipe = snapshot == null || snapshot.sourceType != 'recipe'
        ? null
        : _repeatRecipe(snapshot);
    if (recipe != null) {
      recipes.add(recipe);
      continue;
    }
    rest.add(record);
  }
  return RepeatPlan(
    foods: repeatableMealItems(rest),
    thalis: thalis,
    recipes: recipes,
  );
}

Map<String, dynamic>? _requestEvidence(NutritionConsumptionSnapshot snapshot) {
  final evidence = snapshot.lineage.evidence['request_evidence'];
  return evidence is Map ? Map<String, dynamic>.from(evidence) : null;
}

int? _thaliVersion(NutritionConsumptionSnapshot snapshot) {
  final version = _requestEvidence(snapshot)?['thali_version'];
  return version is num ? version.toInt() : null;
}

RepeatRecipe? _repeatRecipe(NutritionConsumptionSnapshot snapshot) {
  final evidence = _requestEvidence(snapshot);
  final recipeId = evidence?['recipe_id'];
  final versionId = evidence?['recipe_version_id'] ?? snapshot.recipeVersionId;
  final amount = _recipeAmount(evidence?['amount']);
  if (recipeId is! String || versionId is! String || amount == null) {
    return null;
  }
  return RepeatRecipe(
    recipeId: recipeId,
    recipeVersionId: versionId,
    amount: amount,
    label: snapshot.items.isEmpty ? null : snapshot.items.first.displayLabel,
  );
}

NutritionRecipeLogAmount? _recipeAmount(Object? json) {
  if (json is! Map) return null;
  final value = json['value'];
  try {
    return switch (json['kind']) {
      'whole_recipe' => NutritionRecipeLogAmount.wholeRecipe(),
      'declared_serving' => NutritionRecipeLogAmount.declaredServing(),
      'fraction' when value != null => NutritionRecipeLogAmount.fraction(value),
      'scalar' when value != null => NutritionRecipeLogAmount.scalar(value),
      _ => null,
    };
  } on NutritionRecipeLogError {
    return null;
  }
}

/// How a repeat went: entries logged, and thalis or recipes left out because
/// they changed or were removed since they were logged.
class RepeatOutcome {
  final int foods;
  final int thalis;
  final int recipes;
  final int skipped;

  const RepeatOutcome({
    this.foods = 0,
    this.thalis = 0,
    this.recipes = 0,
    this.skipped = 0,
  });

  int get logged => foods + thalis + recipes;

  /// "2 foods and 1 thali".
  String get loggedLabel {
    String count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
    final parts = [
      if (foods > 0) count(foods, 'food'),
      if (thalis > 0) count(thalis, 'thali'),
      if (recipes > 0) count(recipes, 'recipe'),
    ];
    return switch (parts.length) {
      0 => 'nothing',
      1 => parts.single,
      _ => '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}',
    };
  }

  /// Appended to the confirmation when something was left out.
  String? get skippedNote => skipped == 0
      ? null
      : '$skipped changed since yesterday and ${skipped == 1 ? 'was' : 'were'} '
            'not repeated';
}

/// Logs [plan] into [mealCategory] on [localDate], each entry as a fresh
/// consumption. A thali edited or deleted since, or a recipe that's gone, is
/// skipped rather than approximated. Throws if logging fails part-way;
/// entries already logged stay logged.
Future<RepeatOutcome> logRepeatPlan({
  required RepeatPlan plan,
  required NutritionFoodLoggingCoordinator foods,
  required NutritionFoodCatalogRepository catalog,
  required NutritionThaliRepository thalis,
  required NutritionRecipeLogCoordinator recipes,
  required String userId,
  required String mealCategory,
  required DateTime loggedAtUtc,
  required String localDate,
  required String timezoneId,
}) async {
  String id() => 'copy-yesterday::${const Uuid().v4()}';
  var loggedFoods = 0;
  var loggedThalis = 0;
  var loggedRecipes = 0;
  var skipped = 0;

  for (final item in plan.foods) {
    final option = await catalog.getOption(item.foodId!);
    if (option == null) {
      skipped++;
      continue;
    }
    final quantity =
        item.quantity.quantity ??
        Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram);
    final preview = await foods.preview(option: option, quantity: quantity);
    await foods.finalize(
      userId: userId,
      preview: preview,
      mealCategory: mealCategory,
      loggedAt: loggedAtUtc,
      localDate: localDate,
      timezoneId: timezoneId,
      commandId: id(),
      consumptionId: id(),
    );
    loggedFoods++;
  }

  for (final repeat in plan.thalis) {
    final logged = await thalis.getDraft(
      userId: userId,
      thaliId: repeat.thaliId,
    );
    // Only the composition that was logged is repeated: a thali edited
    // since (or deleted) is skipped rather than approximated.
    if (logged == null ||
        repeat.version == null ||
        logged.currentVersion != repeat.version) {
      skipped++;
      continue;
    }
    // A logged thali's item ids belong to that log, so the repeat logs a
    // fresh copy of it and archives the copy: it is history, not a new
    // saved meal.
    final copy = await thalis.saveDraft(
      thalis.newDraft(
        userId: userId,
        name: logged.name,
        description: logged.description,
        items: [
          for (final item in logged.items)
            NutritionThaliItem(
              id: 'thali-item-v1-${const Uuid().v4()}',
              position: item.position,
              source: item.source,
              foodId: item.foodId,
              recipeVersionId: item.recipeVersionId,
              quantity: item.quantity,
              measureId: item.measureId,
              optional: item.optional,
              notes: item.notes,
              displayLabel: item.displayLabel,
            ),
        ],
      ),
    );
    final NutritionThaliPreview preview;
    try {
      preview = await thalis.preview(draft: copy);
    } on NutritionThaliError catch (error) {
      AppLogger.warning('Thali not repeated: $error', 'RepeatMeal');
      await thalis.deleteThali(userId: userId, thaliId: copy.id);
      skipped++;
      continue;
    }
    await thalis.finalize(
      preview: preview,
      mealCategory: mealCategory,
      loggedAt: loggedAtUtc,
      commandId: id(),
      consumptionId: id(),
      localDate: localDate,
      timezoneId: timezoneId,
      // The same thali was logged as it is, partial nutrition included.
      allowPartial: true,
    );
    await thalis.archiveThali(userId: userId, thaliId: copy.id);
    loggedThalis++;
  }

  for (final repeat in plan.recipes) {
    final NutritionRecipeLogPreview preview;
    try {
      preview = await recipes.preview(
        userId: userId,
        recipeId: repeat.recipeId,
        recipeVersionId: repeat.recipeVersionId,
        amount: repeat.amount,
      );
    } on NutritionRecipeLogError catch (error) {
      AppLogger.warning('Recipe not repeated: $error', 'RepeatMeal');
      skipped++;
      continue;
    }
    await recipes.finalize(
      userId: userId,
      preview: preview,
      mealCategory: mealCategory,
      loggedAt: loggedAtUtc,
      localDate: localDate,
      timezoneId: timezoneId,
      consumptionId: id(),
      commandId: id(),
      allowPartial: true,
    );
    loggedRecipes++;
  }
  return RepeatOutcome(
    foods: loggedFoods,
    thalis: loggedThalis,
    recipes: loggedRecipes,
    skipped: skipped,
  );
}

/// Repeats [records] into [mealType] on [targetDay] (see [logRepeatPlan]).
Future<RepeatOutcome> repeatMealRecords(
  WidgetRef ref, {
  required String mealType,
  required Iterable<NutritionHistoricalReadRecord> records,
  required DateTime targetDay,
}) async {
  final dates = LocalScheduleDateService();
  final timezoneId = await ref
      .read(localTimezoneServiceProvider)
      .currentTimezoneId();
  final localDate = dates.localDateFor(targetDay, timezoneId);
  final isToday = localDate == dates.localDateFor(DateTime.now(), timezoneId);
  return logRepeatPlan(
    plan: planRepeat(records),
    foods: await ref.read(nutritionFoodLoggingCoordinatorProvider.future),
    catalog: await ref.read(nutritionFoodCatalogRepositoryProvider.future),
    thalis: await ref.read(nutritionThaliRepositoryProvider.future),
    recipes: await ref.read(nutritionRecipeLogCoordinatorProvider.future),
    userId: kLocalNutritionUserScopeId,
    mealCategory: mealType,
    loggedAtUtc: isToday
        ? DateTime.now().toUtc()
        : dates.instantForLocalDate(localDate, timezoneId),
    localDate: localDate,
    timezoneId: timezoneId,
  );
}
