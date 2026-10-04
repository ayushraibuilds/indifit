import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/typed_quantities.dart';
import 'widgets/food_diary_widgets.dart';

/// Items from [records] that can be logged again as they are: single
/// catalogue foods. Thali, recipe and estimate items need their own flows.
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

/// Logs the repeatable foods from [records] again into [mealType] on
/// [targetDay], each as a fresh consumption. Returns how many were logged.
/// Throws if logging fails part-way; foods already logged stay logged.
Future<int> repeatMealRecords(
  WidgetRef ref, {
  required String mealType,
  required Iterable<NutritionHistoricalReadRecord> records,
  required DateTime targetDay,
}) async {
  final coordinator = await ref.read(
    nutritionFoodLoggingCoordinatorProvider.future,
  );
  final catalog = await ref.read(nutritionFoodCatalogRepositoryProvider.future);
  final dates = LocalScheduleDateService();
  final timezoneId = await ref
      .read(localTimezoneServiceProvider)
      .currentTimezoneId();
  final localDate = dates.localDateFor(targetDay, timezoneId);
  final isToday = localDate == dates.localDateFor(DateTime.now(), timezoneId);
  final loggedAtUtc = isToday
      ? DateTime.now().toUtc()
      : dates.instantForLocalDate(localDate, timezoneId);

  var copied = 0;
  for (final item in repeatableMealItems(records)) {
    final option = await catalog.getOption(item.foodId!);
    if (option == null) continue;
    final quantity =
        item.quantity.quantity ??
        Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram);
    final preview = await coordinator.preview(
      option: option,
      quantity: quantity,
    );
    await coordinator.finalize(
      userId: kLocalNutritionUserScopeId,
      preview: preview,
      mealCategory: mealType,
      loggedAt: loggedAtUtc,
      localDate: localDate,
      timezoneId: timezoneId,
      commandId: 'copy-yesterday::${const Uuid().v4()}',
      consumptionId: 'copy-yesterday::${const Uuid().v4()}',
    );
    copied++;
  }
  return copied;
}
