import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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
    String? mealGroupId,
  }) async {
    String resolvedGroupId = mealGroupId ?? '';
    
    if (resolvedGroupId.isEmpty) {
      // Check the latest logged entry of this type to see if we can group them
      final lastQuery = _db.select(_db.foodLogs)
        ..where((tbl) => tbl.mealType.equals(mealType))
        ..orderBy([(tbl) => OrderingTerm(expression: tbl.loggedAt, mode: OrderingMode.desc)])
        ..limit(1);
      final lastEntries = await lastQuery.get();
      
      final now = DateTime.now();
      if (lastEntries.isNotEmpty) {
        final lastEntry = lastEntries.first;
        final diff = now.difference(lastEntry.loggedAt).inMinutes.abs();
        if (diff < 2 && lastEntry.mealGroupId != null && lastEntry.mealGroupId!.isNotEmpty) {
          resolvedGroupId = lastEntry.mealGroupId!;
        }
      }
      
      if (resolvedGroupId.isEmpty) {
        resolvedGroupId = '${mealType}_${now.millisecondsSinceEpoch}_${now.microsecond}';
      }
    }

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
      mealGroupId: Value(resolvedGroupId),
      uuid: Value(const Uuid().v4()),
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

    final lastEntry = lastEntries.first;
    final groupId = lastEntry.mealGroupId;
    
    if (groupId != null && groupId.isNotEmpty) {
      return await (_db.select(_db.foodLogs)
        ..where((tbl) => tbl.mealGroupId.equals(groupId)))
        .get();
    } else {
      // Fallback: group by date boundary if no group ID is defined
      final lastLoggedDate = lastEntry.loggedAt;
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

  Future<double> getFiberForLog(FoodLog log) async {
    if (log.foodItemId == null) return 0.0;
    final item = await (_db.select(_db.foodItems)..where((tbl) => tbl.id.equals(log.foodItemId!))).getSingleOrNull();
    if (item == null || item.fiberG == null) return 0.0;
    final double scale = item.servingSize > 0 ? (log.servingLogged / item.servingSize) : 1.0;
    return item.fiberG! * scale;
  }

  Future<List<DateTime>> getAllLogDates() async {
    final logs = await _db.select(_db.foodLogs).get();
    return logs.map((l) => l.loggedAt).toList();
  }
}
