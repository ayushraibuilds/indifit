import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../database/app_database.dart';

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return FoodRepository(db);
});

class FoodRepository {
  final AppDatabase _db;

  FoodRepository(this._db);

  // 1. Search food items locally with simple fuzzy / contains query
  Future<List<FoodItem>> searchFoodLocal(String query) async {
    if (query.trim().isEmpty) return [];

    final cleanQuery = query.toLowerCase().trim();
    
    // Search by name or hindi name containing the query
    return (await (_db.select(_db.foodItems)
          ..where((tbl) => 
            tbl.name.lower().contains(cleanQuery) | 
            tbl.nameHindi.lower().contains(cleanQuery)
          ))
        .get());
  }

  // 2. Insert new custom food item
  Future<int> insertCustomFood(FoodItemsCompanion companion) async {
    return await _db.into(_db.foodItems).insert(companion);
  }

  // 3. Log a food meal entry
  Future<int> logFoodEntry({
    required String name,
    required int calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double servingLogged,
    required String servingUnit,
    required String mealType,
    int? foodItemId,
  }) async {
    final companion = FoodLogsCompanion.insert(
      foodItemId: Value(foodItemId),
      name: name,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      servingLogged: servingLogged,
      servingUnit: servingUnit,
      mealType: mealType,
    );
    return await _db.into(_db.foodLogs).insert(companion);
  }

  // 4. Watch all food logs for a specific day
  Stream<List<FoodLog>> watchLogsForDay(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return (_db.select(_db.foodLogs)
          ..where((tbl) => tbl.loggedAt.isBetweenValues(startOfDay, endOfDay))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.loggedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  // 5. Delete logged entry
  Future<int> deleteLogEntry(int id) async {
    return await (_db.delete(_db.foodLogs)..where((tbl) => tbl.id.equals(id))).go();
  }

  // 6. Get unsynced logs
  Future<List<FoodLog>> getUnsyncedLogs() async {
    return await (_db.select(_db.foodLogs)..where((tbl) => tbl.isSynced.equals(false))).get();
  }

  // 7. Get all items logged for the last occurrence of a meal type
  Future<List<FoodLog>> getLastLoggedMeal(String mealType) async {
    final query = _db.select(_db.foodLogs)
      ..where((tbl) => tbl.mealType.equals(mealType))
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.loggedAt, mode: OrderingMode.desc)])
      ..limit(1);
    
    final lastEntries = await query.get();
    if (lastEntries.isEmpty) return [];

    final lastLoggedDate = lastEntries.first.loggedAt;
    final startOfDay = DateTime(lastLoggedDate.year, lastLoggedDate.month, lastLoggedDate.day);
    final endOfDay = DateTime(lastLoggedDate.year, lastLoggedDate.month, lastLoggedDate.day, 23, 59, 59);

    return await (_db.select(_db.foodLogs)
      ..where((tbl) => 
        tbl.mealType.equals(mealType) & 
        tbl.loggedAt.isBetweenValues(startOfDay, endOfDay)
      ))
      .get();
  }
}
