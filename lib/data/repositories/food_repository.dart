import 'dart:convert' show jsonDecode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/di/providers.dart';
import '../../core/utils/app_logger.dart';
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
    
    // Search by name or hindi name containing the query with null protection
    return (await (_db.select(_db.foodItems)
          ..where((tbl) => 
            tbl.name.lower().contains(cleanQuery) | 
            (tbl.nameHindi.isNotNull() & tbl.nameHindi.lower().contains(cleanQuery))
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
        if (diff < 15 && lastEntry.mealGroupId != null && lastEntry.mealGroupId!.isNotEmpty) {
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

  // 8. Update an existing food log entry
  Future<bool> updateFoodLog({
    required int id,
    required String name,
    required int calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double servingLogged,
  }) async {
    final count = await (_db.update(_db.foodLogs)..where((t) => t.id.equals(id))).write(
      FoodLogsCompanion(
        name: Value(name),
        calories: Value(calories),
        proteinG: Value(proteinG),
        carbsG: Value(carbsG),
        fatG: Value(fatG),
        servingLogged: Value(servingLogged),
      ),
    );
    return count > 0;
  }

  // 9. Copy meal group entries to target date / meal type
  Future<void> copyMealGroup({
    required String groupId,
    required DateTime targetDate,
    required String targetMealType,
  }) async {
    final logs = await (_db.select(_db.foodLogs)..where((t) => t.mealGroupId.equals(groupId))).get();
    if (logs.isEmpty) return;

    final newGroupId = const Uuid().v4();
    final companions = logs.map((l) => FoodLogsCompanion.insert(
      foodItemId: Value(l.foodItemId),
      name: l.name,
      calories: l.calories,
      proteinG: l.proteinG,
      carbsG: l.carbsG,
      fatG: l.fatG,
      servingLogged: l.servingLogged,
      servingUnit: l.servingUnit,
      mealType: targetMealType,
      loggedAt: Value(targetDate),
      mealGroupId: Value(newGroupId),
      uuid: Value(const Uuid().v4()),
    )).toList();

    await _db.batch((b) => b.insertAll(_db.foodLogs, companions));
  }

  // ---------------------------------------------------------------------------
  // Meal templates (saved multi-item meals for one-tap re-logging)
  // ---------------------------------------------------------------------------

  /// Save a list of food logs as a reusable named template.
  Future<int> saveMealTemplate({
    required String name,
    required String defaultMealType,
    required List<FoodLog> items,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Template name cannot be empty');
    }
    if (items.isEmpty) {
      throw ArgumentError('Cannot save an empty meal template');
    }

    return _db.transaction(() async {
      final templateId = await _db.into(_db.mealTemplates).insert(
            MealTemplatesCompanion.insert(
              name: name.trim(),
              defaultMealType: Value(defaultMealType),
            ),
          );

      final companions = items
          .map(
            (item) => MealTemplateItemsCompanion.insert(
              templateId: templateId,
              name: item.name,
              calories: item.calories,
              proteinG: item.proteinG,
              carbsG: item.carbsG,
              fatG: item.fatG,
              servingLogged: item.servingLogged,
              servingUnit: item.servingUnit,
            ),
          )
          .toList();

      await _db.batch((b) => b.insertAll(_db.mealTemplateItems, companions));
      return templateId;
    });
  }

  /// Save current meal-type logs for a given day as a template.
  Future<int> saveMealTemplateFromDay({
    required String name,
    required String mealType,
    required DateTime day,
  }) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final logs = await (_db.select(_db.foodLogs)
          ..where(
            (t) =>
                t.mealType.equals(mealType) &
                t.loggedAt.isBetweenValues(startOfDay, endOfDay),
          ))
        .get();
    return saveMealTemplate(
      name: name,
      defaultMealType: mealType,
      items: logs,
    );
  }

  Future<List<MealTemplate>> getAllMealTemplates() async {
    return (_db.select(_db.mealTemplates)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Stream<List<MealTemplate>> watchMealTemplates() {
    return (_db.select(_db.mealTemplates)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<MealTemplateItem>> getMealTemplateItems(int templateId) async {
    return (_db.select(_db.mealTemplateItems)
          ..where((t) => t.templateId.equals(templateId)))
        .get();
  }

  Future<MealTemplateWithItems?> getMealTemplateWithItems(int templateId) async {
    final template = await (_db.select(_db.mealTemplates)
          ..where((t) => t.id.equals(templateId)))
        .getSingleOrNull();
    if (template == null) return null;
    final items = await getMealTemplateItems(templateId);
    return MealTemplateWithItems(template: template, items: items);
  }

  /// Log every item from a template into the target meal/day as one group.
  Future<void> logFromMealTemplate({
    required int templateId,
    required String mealType,
    DateTime? loggedAt,
  }) async {
    final items = await getMealTemplateItems(templateId);
    if (items.isEmpty) return;

    final when = loggedAt ?? DateTime.now();
    final groupId = 'template_${templateId}_${when.millisecondsSinceEpoch}';

    final companions = items
        .map(
          (item) => FoodLogsCompanion.insert(
            name: item.name,
            calories: item.calories,
            proteinG: item.proteinG,
            carbsG: item.carbsG,
            fatG: item.fatG,
            servingLogged: item.servingLogged,
            servingUnit: item.servingUnit,
            mealType: mealType,
            loggedAt: Value(when),
            mealGroupId: Value(groupId),
            uuid: Value(const Uuid().v4()),
          ),
        )
        .toList();

    await _db.batch((b) => b.insertAll(_db.foodLogs, companions));
  }

  Future<int> deleteMealTemplate(int templateId) async {
    return _db.transaction(() async {
      await (_db.delete(_db.mealTemplateItems)
            ..where((t) => t.templateId.equals(templateId)))
          .go();
      return (_db.delete(_db.mealTemplates)
            ..where((t) => t.id.equals(templateId)))
          .go();
    });
  }

  Future<int> renameMealTemplate(int templateId, String newName) async {
    if (newName.trim().isEmpty) return 0;
    return (_db.update(_db.mealTemplates)..where((t) => t.id.equals(templateId)))
        .write(MealTemplatesCompanion(name: Value(newName.trim())));
  }

  Future<List<FoodItem>> getRecentFoods(int limit) async {
    final query = 'SELECT name, food_item_id, calories, protein_g, carbs_g, fat_g, serving_unit, COUNT(*) as log_count '
        'FROM food_logs '
        'GROUP BY name '
        'ORDER BY log_count DESC, max(logged_at) DESC '
        'LIMIT ?';
    final rows = await _db.customSelect(query, variables: [Variable.withInt(limit)]).get();

    return rows.map((row) {
      final name = row.read<String>('name');
      final foodItemId = row.readNullable<int>('food_item_id');
      final calories = row.read<int>('calories');
      final protein = row.read<double>('protein_g');
      final carbs = row.read<double>('carbs_g');
      final fat = row.read<double>('fat_g');
      final unit = row.read<String>('serving_unit');

      return FoodItem(
        id: foodItemId ?? -1,
        name: name,
        nameHindi: null,
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        fiberG: null,
        servingSize: 1.0,
        servingUnit: unit,
        category: 'Recent',
        isCustom: false,
      );
    }).toList();
  }

  /// Import a regional food pack from a JSON asset path, tagging them with regionPack.
  Future<void> importRegionalPack({
    required String packId,
    required String assetPath,
  }) async {
    try {
      final jsonStr = await rootBundle.loadString(assetPath);
      final List<dynamic> list = jsonDecode(jsonStr);

      await _db.transaction(() async {
        // First delete any existing items from this regional pack to avoid duplicates
        await (_db.delete(_db.foodItems)..where((t) => t.regionPack.equals(packId))).go();

        final toInsert = list.map((raw) {
          return FoodItemsCompanion.insert(
            name: raw['name'] as String,
            nameHindi: Value(raw['name_hindi'] as String?),
            calories: raw['calories'] as int,
            proteinG: (raw['protein_g'] as num).toDouble(),
            carbsG: (raw['carbs_g'] as num).toDouble(),
            fatG: (raw['fat_g'] as num).toDouble(),
            fiberG: Value((raw['fiber_g'] as num?)?.toDouble() ?? 0.0),
            servingSize: (raw['serving_size'] as num).toDouble(),
            servingUnit: raw['serving_unit'] as String,
            category: raw['category'] as String,
            regionPack: Value(packId),
          );
        }).toList();

        await _db.batch((b) => b.insertAll(_db.foodItems, toInsert));
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to import regional food pack: $packId', e, stackTrace, 'FoodRepository');
      rethrow;
    }
  }

  /// Remove a regional pack (delete from DB)
  Future<void> removeRegionalPack(String packId) async {
    await (_db.delete(_db.foodItems)..where((t) => t.regionPack.equals(packId))).go();
  }

  /// Check if a regional pack is loaded (has items in DB)
  Future<bool> isRegionalPackLoaded(String packId) async {
    final query = _db.select(_db.foodItems)
      ..where((t) => t.regionPack.equals(packId))
      ..limit(1);
    final results = await query.get();
    return results.isNotEmpty;
  }

  // ────────────────────────────────────────
  // Meal Templates API
  // ────────────────────────────────────────

  /// Get all saved meal templates with their items
  Future<List<MealTemplateWithItems>> getMealTemplates() async {
    final templates = await _db.select(_db.mealTemplates).get();
    final List<MealTemplateWithItems> result = [];

    for (final template in templates) {
      final items = await (_db.select(_db.mealTemplateItems)
            ..where((t) => t.templateId.equals(template.id)))
          .get();
      result.add(MealTemplateWithItems(template: template, items: items));
    }
    return result;
  }

  /// Create a new meal template with items
  Future<int> createMealTemplate({
    required String name,
    required String defaultMealType,
    required List<MealTemplateItemInput> items,
  }) async {
    return await _db.transaction(() async {
      final templateId = await _db.into(_db.mealTemplates).insert(
            MealTemplatesCompanion.insert(
              name: name,
              defaultMealType: Value(defaultMealType),
            ),
          );

      for (final item in items) {
        await _db.into(_db.mealTemplateItems).insert(
              MealTemplateItemsCompanion.insert(
                templateId: templateId,
                name: item.name,
                calories: item.calories,
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG,
                servingLogged: item.servingLogged,
                servingUnit: item.servingUnit,
              ),
            );
      }
      return templateId;
    });
  }


  /// Batch log all items from a template into food logs
  Future<List<int>> logMealTemplate({
    required int templateId,
    required String targetMealType,
    DateTime? targetDate,
  }) async {
    final templateItems = await (_db.select(_db.mealTemplateItems)
          ..where((t) => t.templateId.equals(templateId)))
        .get();

    if (templateItems.isEmpty) return [];

    final logDate = targetDate ?? DateTime.now();
    final mealGroupId = const Uuid().v4();
    final List<int> logIds = [];

    for (final item in templateItems) {
      final id = await logFoodEntry(
        name: item.name,
        calories: item.calories,
        proteinG: item.proteinG,
        carbsG: item.carbsG,
        fatG: item.fatG,
        servingLogged: item.servingLogged,
        servingUnit: item.servingUnit,
        mealType: targetMealType,
        mealGroupId: mealGroupId,
      );
      logIds.add(id);
    }
    return logIds;
  }
}

class MealTemplateItemInput {
  final String name;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double servingLogged;
  final String servingUnit;

  const MealTemplateItemInput({
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.servingLogged,
    required this.servingUnit,
  });
}

class MealTemplateWithItems {
  final MealTemplate template;
  final List<MealTemplateItem> items;

  const MealTemplateWithItems({
    required this.template,
    required this.items,
  });

  int get totalCalories => items.fold(0, (sum, i) => sum + i.calories);

  double get totalProteinG =>
      items.fold(0.0, (sum, i) => sum + i.proteinG);

  double get totalCarbsG => items.fold(0.0, (sum, i) => sum + i.carbsG);

  double get totalFatG => items.fold(0.0, (sum, i) => sum + i.fatG);
}

