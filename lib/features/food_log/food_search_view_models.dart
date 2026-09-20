
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/typed_quantities.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';


/// Food search view data (PV1-ENG-05D first pass).
///
/// Extracted verbatim from `food_search_screen.dart`; unchanged.

class CanonicalRecentFood {
  const CanonicalRecentFood({
    required this.option,
    required this.quantityLabel,
    required this.loggedAtUtc,
    this.frequencyCount = 1,
    this.historicalQuantity,
    this.historicalTransformationId,
    this.lastLoggedMealCategory,
  });

  final NutritionFoodOption option;
  final String quantityLabel;
  final DateTime loggedAtUtc;
  final int frequencyCount;
  final Quantity? historicalQuantity;
  final String? historicalTransformationId;
  final String? lastLoggedMealCategory;
}

class FoodAddUndoToken {
  const FoodAddUndoToken({
    required this.snapshotId,
    required this.localDate,
    required this.mealCategory,
  });

  final String snapshotId;
  final String localDate;
  final String mealCategory;
}

final canonicalRecentFoodsProvider =
    FutureProvider.autoDispose<List<CanonicalRecentFood>>((ref) async {
      try {
        // Avoid initializing the asset-backed canonical read stack when this
        // user has no canonical consumption at all. This is only an existence
        // gate; every displayed record still comes through the B03 read model.
        final database = ref.read(databaseProvider);
        final canonicalSnapshot =
            await (database.select(database.nutritionConsumptionSnapshots)
                  ..where(
                    (row) => row.userId.equals(kLocalNutritionUserScopeId),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (canonicalSnapshot == null) return const [];
        final history = await ref.read(
          nutritionReadModelRepositoryProvider.future,
        );
        final catalog = await ref.read(
          nutritionFoodCatalogRepositoryProvider.future,
        );
        final records = await history.listHistory(
          userId: kLocalNutritionUserScopeId,
        );
        final ordered = records.where((record) => !record.isLegacy).toList()
          ..sort((left, right) {
            final dateComp = right.loggedAtUtc.compareTo(left.loggedAtUtc);
            if (dateComp != 0) return dateComp;
            return right.stableId.compareTo(left.stableId);
          });
        final frequencyByFoodId = <String, int>{};
        for (final record in ordered) {
          for (final item in record.items) {
            final foodId = item.foodId;
            if (item.originSourceType == 'direct_food' &&
                foodId != null &&
                foodId.isNotEmpty) {
              frequencyByFoodId.update(
                foodId,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
            }
          }
        }
        final seenFoodIds = <String>{};
        final result = <CanonicalRecentFood>[];
        for (final record in ordered) {
          for (final item in record.items) {
            final foodId = item.foodId;
            if (item.originSourceType != 'direct_food' ||
                foodId == null ||
                foodId.isEmpty ||
                !seenFoodIds.add(foodId)) {
              continue;
            }
            final option = await catalog.getOption(foodId);
            if (option == null) continue;
            final historicalQuantity = item.quantity.isResolved
                ? item.quantity.quantity
                : null;
            final quantityLabel = historicalQuantity != null
                ? QuantityFormatter.format(historicalQuantity)
                : (item.quantity.storedAmount != null &&
                      item.quantity.storedUnit.isNotEmpty)
                ? '${item.quantity.storedAmount} ${item.quantity.storedUnit}'
                : '${option.baseQuantity.amount} ${option.baseQuantity.unit.name}';
            result.add(
              CanonicalRecentFood(
                option: option,
                quantityLabel: quantityLabel,
                loggedAtUtc: record.loggedAtUtc,
                frequencyCount: frequencyByFoodId[foodId] ?? 1,
                historicalQuantity: historicalQuantity,
                lastLoggedMealCategory: record.mealCategory,
              ),
            );
            if (result.length == 20) return result;
          }
        }
        return result;
      } catch (_) {
        // A canonical-history read must never make local/legacy Recent unusable.
        return const [];
      }
    });

enum CanonicalFoodAction { edit, copy, delete }

