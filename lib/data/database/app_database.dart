import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/food_tables.dart';
import 'tables/user_tables.dart';
import 'tables/workout_tables.dart';
import 'tables/settings_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  FoodItems,
  FoodLogs,
  Exercises,
  WorkoutSessions,
  WorkoutSets,
  BodyMeasurements,
  WorkoutRoutines,
  RoutineDays,
  RoutineExercises,
  WorkoutDrafts,
  UserProfiles,
  MealTemplates,
  MealTemplateItems,
  UserSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.memory() : super(NativeDatabase.memory());

  /// Schema v12: idempotent exercise seed via upsert-by-name.
  /// Earlier versions used a raw insertAll in the migration which silently
  /// failed on existing rows (UNIQUE constraint swallowed by catch), leaving
  /// the exercise library empty for installs upgrading from < 11.
  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(foodLogs, foodLogs.mealGroupId);
          }
          if (from < 3) {
            await m.addColumn(workoutSets, workoutSets.rpe);
            await m.addColumn(workoutSets, workoutSets.isWarmUp);
            await m.addColumn(workoutSets, workoutSets.setNotes);
            await m.createTable(workoutDrafts);
          }
          if (from < 4) {
            await m.addColumn(foodLogs, foodLogs.uuid);
            await m.addColumn(workoutSessions, workoutSessions.uuid);
            await m.addColumn(workoutSets, workoutSets.uuid);
          }
          if (from < 5) {
            await m.createTable(userProfiles);
          }
          if (from < 6) {
            await m.createTable(mealTemplates);
            await m.createTable(mealTemplateItems);
            await m.addColumn(workoutSets, workoutSets.setType);
          }
          if (from < 7) {
            // Upsert improved offline food catalog without wiping custom foods
            // or breaking existing food_logs foreign keys for matched names.
            await upsertSeededFoodsFromAsset();
          }
          if (from < 8) {
            await m.addColumn(foodItems, foodItems.brand);
            await m.addColumn(foodItems, foodItems.regionPack);
          }
          if (from < 9) {
            await m.addColumn(workoutSets, workoutSets.durationSeconds);
            await m.addColumn(workoutSets, workoutSets.distanceKm);
            await m.addColumn(workoutSets, workoutSets.inclinePercentage);
          }
          if (from < 10) {
            await m.createTable(userSettings);
          }
          if (from < 11) {
            await upsertSeededFoodsFromAsset();
            await seedExercisesFromAsset();
          }
          if (from < 12) {
            // Idempotent re-seed of exercises so upgrades that previously
            // swallowed a UNIQUE-constraint failure now populate the library.
            await upsertSeededExercisesFromAsset();
          }
        },


        onCreate: (m) async {
          await m.createAll();
          await seedFoodsFromAsset();
          await seedExercisesFromAsset();
        },
      );

  /// Full seed used on first install.
  Future<void> seedFoodsFromAsset() async {
    try {
      final companions = await _loadFoodCompanionsFromAsset();
      if (companions.isEmpty) return;
      await batch((b) => b.insertAll(foodItems, companions));
    } catch (_) {
      // Seed failures are non-fatal; app still runs with empty catalog.
    }
  }

  /// Upsert by name for non-custom rows; insert brand-new catalog items.
  Future<void> upsertSeededFoodsFromAsset() async {
    try {
      final foodsList = await _loadFoodJsonList();
      if (foodsList.isEmpty) return;

      final existing = await select(foodItems).get();
      final byName = <String, FoodItem>{
        for (final item in existing.where((e) => !e.isCustom)) item.name: item,
      };

      final toInsert = <FoodItemsCompanion>[];
      await transaction(() async {
        for (final raw in foodsList) {
          final name = raw['name'] as String;
          final companionValues = FoodItemsCompanion(
            name: Value(name),
            nameHindi: Value(raw['name_hindi'] as String?),
            calories: Value(raw['calories'] as int),
            proteinG: Value((raw['protein_g'] as num).toDouble()),
            carbsG: Value((raw['carbs_g'] as num).toDouble()),
            fatG: Value((raw['fat_g'] as num).toDouble()),
            fiberG: Value((raw['fiber_g'] as num?)?.toDouble() ?? 0.0),
            servingSize: Value((raw['serving_size'] as num).toDouble()),
            servingUnit: Value(raw['serving_unit'] as String),
            category: Value(raw['category'] as String),
            isCustom: const Value(false),
          );

          final match = byName[name];
          if (match != null) {
            await (update(foodItems)..where((t) => t.id.equals(match.id)))
                .write(companionValues);
          } else {
            toInsert.add(FoodItemsCompanion.insert(
              name: name,
              nameHindi: Value(raw['name_hindi'] as String?),
              calories: raw['calories'] as int,
              proteinG: (raw['protein_g'] as num).toDouble(),
              carbsG: (raw['carbs_g'] as num).toDouble(),
              fatG: (raw['fat_g'] as num).toDouble(),
              fiberG: Value((raw['fiber_g'] as num?)?.toDouble() ?? 0.0),
              servingSize: (raw['serving_size'] as num).toDouble(),
              servingUnit: raw['serving_unit'] as String,
              category: raw['category'] as String,
            ));
          }
        }
        if (toInsert.isNotEmpty) {
          await batch((b) => b.insertAll(foodItems, toInsert));
        }
      });
    } catch (_) {
      // Non-fatal; user keeps prior catalog.
    }
  }

  Future<void> seedExercisesFromAsset() async {
    await upsertSeededExercisesFromAsset();
  }

  /// Idempotent exercise seed: updates existing rows by name, inserts new ones.
  /// Fixes the empty-exercise-library bug where a prior migration's raw
  /// insertAll failed silently on UNIQUE constraints.
  Future<void> upsertSeededExercisesFromAsset() async {
    try {
      final exercisesJson =
          await rootBundle.loadString('assets/data/exercises.json');
      final List<dynamic> exercisesList = jsonDecode(exercisesJson);
      if (exercisesList.isEmpty) return;

      final existing = await select(exercises).get();
      final byName = <String, Exercise>{
        for (final item in existing) item.name: item,
      };

      final toInsert = <ExercisesCompanion>[];
      await transaction(() async {
        for (final raw in exercisesList) {
          final name = raw['name'] as String;
          final companionValues = ExercisesCompanion(
            name: Value(name),
            muscleGroups:
                Value((raw['muscle_groups'] as List).join(',')),
            equipment: Value(raw['equipment'] as String),
            difficulty: Value(raw['difficulty'] as String),
            formCues: Value((raw['form_cues'] as List).join('\n')),
            commonMistakes:
                Value((raw['common_mistakes'] as List).join('\n')),
            youtubeId: Value(raw['youtube_id'] as String?),
          );

          final match = byName[name];
          if (match != null) {
            await (update(exercises)..where((t) => t.id.equals(match.id)))
                .write(companionValues);
          } else {
            toInsert.add(ExercisesCompanion.insert(
              name: name,
              muscleGroups: (raw['muscle_groups'] as List).join(','),
              equipment: raw['equipment'] as String,
              difficulty: raw['difficulty'] as String,
              formCues: (raw['form_cues'] as List).join('\n'),
              commonMistakes: (raw['common_mistakes'] as List).join('\n'),
              youtubeId: Value(raw['youtube_id'] as String?),
            ));
          }
        }
        if (toInsert.isNotEmpty) {
          await batch((b) => b.insertAll(exercises, toInsert));
        }
      });
    } catch (_) {
      // Non-fatal; user keeps prior exercise catalog.
    }
  }

  Future<List<dynamic>> _loadFoodJsonList() async {
    final foodsJson =
        await rootBundle.loadString('assets/data/indian_foods.json');
    final decoded = jsonDecode(foodsJson);
    if (decoded is List) return decoded;
    return const [];
  }

  Future<List<FoodItemsCompanion>> _loadFoodCompanionsFromAsset() async {
    final foodsList = await _loadFoodJsonList();
    return foodsList.map((item) {
      return FoodItemsCompanion.insert(
        name: item['name'],
        nameHindi: Value(item['name_hindi']),
        calories: item['calories'],
        proteinG: (item['protein_g'] as num).toDouble(),
        carbsG: (item['carbs_g'] as num).toDouble(),
        fatG: (item['fat_g'] as num).toDouble(),
        fiberG: Value((item['fiber_g'] as num?)?.toDouble() ?? 0.0),
        servingSize: (item['serving_size'] as num).toDouble(),
        servingUnit: item['serving_unit'],
        category: item['category'],
      );
    }).toList();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'indifit.db'));
    return NativeDatabase.createInBackground(file);
  });
}
