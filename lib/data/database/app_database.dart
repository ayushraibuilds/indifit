import 'dart:io';
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'indifit.db'));
    return NativeDatabase.createInBackground(file);
  });
}
