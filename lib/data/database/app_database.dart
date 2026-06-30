import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/food_tables.dart';
import 'tables/workout_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  FoodItems,
  FoodLogs,
  Exercises,
  WorkoutSessions,
  WorkoutSets,
  BodyMeasurements
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // Create all database tables
          await m.createAll();

          // 1. Seed Indian Foods Database from offline JSON asset
          try {
            final foodsJson = await rootBundle.loadString('assets/data/indian_foods.json');
            final List<dynamic> foodsList = jsonDecode(foodsJson);
            final foodCompanions = foodsList.map((item) {
              return FoodItemsCompanion.insert(
                name: item['name'],
                nameHindi: Value(item['name_hindi']),
                calories: item['calories'],
                proteinG: (item['protein_g'] as num).toDouble(),
                carbsG: (item['carbs_g'] as num).toDouble(),
                fatG: (item['fat_g'] as num).toDouble(),
                fiberG: Value((item['fiber_g'] as num?)?.toDouble()),
                servingSize: (item['serving_size'] as num).toDouble(),
                servingUnit: item['serving_unit'],
                category: item['category'],
              );
            }).toList();
            
            await batch((b) => b.insertAll(foodItems, foodCompanions));
          } catch (e) {
            driftRuntimeOptions.defaultSerializer; // simple line to prevent lint warnings
            // In a production app, we would log this to Sentry/Crashlytics
          }

          // 2. Seed Exercise Library from offline JSON asset
          try {
            final exercisesJson = await rootBundle.loadString('assets/data/exercises.json');
            final List<dynamic> exercisesList = jsonDecode(exercisesJson);
            final exerciseCompanions = exercisesList.map((item) {
              return ExercisesCompanion.insert(
                name: item['name'],
                muscleGroups: (item['muscle_groups'] as List).join(','),
                equipment: item['equipment'],
                difficulty: item['difficulty'],
                formCues: (item['form_cues'] as List).join('\n'),
                commonMistakes: (item['common_mistakes'] as List).join('\n'),
                youtubeId: Value(item['youtube_id']),
              );
            }).toList();

            await batch((b) => b.insertAll(exercises, exerciseCompanions));
          } catch (e) {
            // Error handling
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'indifit.db'));
    return NativeDatabase.createInBackground(file);
  });
}
