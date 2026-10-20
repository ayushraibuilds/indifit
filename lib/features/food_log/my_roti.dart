import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/di/providers.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import 'widgets/food_diary_widgets.dart';

/// "My roti" (UF-3): the roti someone makes, as a catalogue roti food. The
/// catalogue has no gram weights for rotis, so each size is one of its own
/// roti foods, named on the setup screen.
enum MyRoti {
  phulka('phulka', 'Phulka', 'food-seed-0567'),
  tawa('tawa', 'Tawa roti', 'food-seed-0564'),
  tandoori('tandoori', 'Tandoori roti', 'food-seed-0517');

  const MyRoti(this.stableId, this.label, this.foodId);

  final String stableId;
  final String label;

  /// Phulka: Whole Wheat Roti / Chapati (Mini); tawa: Whole Wheat Roti /
  /// Chapati; tandoori: Tandoori Roti (Wheat).
  final String foodId;

  static MyRoti? fromStableId(String? id) {
    for (final roti in values) {
      if (roti.stableId == id) return roti;
    }
    return null;
  }

  static MyRoti? read(SharedPreferences prefs) =>
      fromStableId(prefs.getString(AppPreferenceKeys.prefMyRoti));

  Future<void> write(SharedPreferences prefs) =>
      prefs.setString(AppPreferenceKeys.prefMyRoti, stableId);
}

/// The saved My roti; null until it's chosen.
final myRotiProvider = Provider<MyRoti?>((ref) {
  final prefs = sharedPreferencesOrNull(
    () => ref.watch(sharedPreferencesProvider),
  );
  return prefs == null ? null : MyRoti.read(prefs);
});

final _rotiWord = RegExp(
  r'\b(roti|chapati|chapathi|phulka|rotli|poli|bhakri)\b',
  caseSensitive: false,
);

/// Whether a logged item is a single roti: a catalogue food named like one,
/// not a plate that includes rotis ("Home Thali — 2 Roti + Dal").
bool isRotiFamilyItem(NutritionHistoricalReadItem item) {
  final label = item.displayLabel?.trim() ?? '';
  if (item.foodId == null || label.isEmpty) return false;
  if (label.contains('+') || label.toLowerCase().contains('thali')) {
    return false;
  }
  return _rotiWord.hasMatch(label);
}

/// The roti to add one more of in [mealType] (diary meal ids): the newest
/// roti-family item, whether it was logged alone, in a mixed meal or inside
/// a thali. Null when the meal has no roti.
NutritionHistoricalReadItem? rotiInMeal(
  Iterable<NutritionHistoricalReadRecord> records,
  String mealType,
) {
  final inMeal =
      records
          .where((record) => foodDiaryMealType(record.mealCategory) == mealType)
          .toList()
        ..sort((a, b) => a.loggedAtUtc.compareTo(b.loggedAtUtc));
  for (final record in inMeal.reversed) {
    for (final item in record.items.reversed) {
      if (isRotiFamilyItem(item)) return item;
    }
  }
  return null;
}

/// Logs one catalogue serving of [foodId] (one piece for a roti) into
/// [mealCategory] on [day]. Null when the food is no longer in the catalogue.
Future<NutritionConsumptionSnapshot?> logOneCatalogueServing(
  WidgetRef ref, {
  required String foodId,
  required String mealCategory,
  required DateTime day,
}) async {
  final NutritionFoodCatalogRepository catalog = await ref.read(
    nutritionFoodCatalogRepositoryProvider.future,
  );
  final option = await catalog.getOption(foodId);
  if (option == null) return null;
  final foods = await ref.read(nutritionFoodLoggingCoordinatorProvider.future);
  final dates = LocalScheduleDateService();
  final timezoneId = await ref
      .read(localTimezoneServiceProvider)
      .currentTimezoneId();
  final localDate = dates.localDateFor(day, timezoneId);
  final isToday = localDate == dates.localDateFor(DateTime.now(), timezoneId);
  final id = 'one-more::${const Uuid().v4()}';
  return foods.finalize(
    userId: kLocalNutritionUserScopeId,
    preview: await foods.preview(
      option: option,
      quantity: option.defaultLoggingQuantity,
    ),
    mealCategory: mealCategory,
    loggedAt: isToday
        ? DateTime.now().toUtc()
        : dates.instantForLocalDate(localDate, timezoneId),
    localDate: localDate,
    timezoneId: timezoneId,
    commandId: id,
    consumptionId: id,
  );
}
