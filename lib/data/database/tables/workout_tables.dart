import 'package:drift/drift.dart';

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get muscleGroups => text()(); // Store as comma-separated values, e.g., "Chest,Triceps"
  TextColumn get equipment => text()(); // "Barbell", "Dumbbell", "Cable", "Bodyweight"
  TextColumn get difficulty => text()(); // "Beginner", "Intermediate", "Advanced"
  TextColumn get formCues => text()(); // Store as newline-separated text
  TextColumn get commonMistakes => text()(); // Store as newline-separated text
  TextColumn get youtubeId => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // e.g., "Chest & Shoulders"
  RealColumn get totalVolume => real()(); // total weight lifted (kg)
  IntColumn get durationSeconds => integer()();
  IntColumn get estimatedCalories => integer()();
  DateTimeColumn get completedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(WorkoutSessions, #id)();
  TextColumn get exerciseName => text()();
  RealColumn get weight => real()(); // in kg
  IntColumn get reps => integer()();
  IntColumn get setNumber => integer()();
  BoolColumn get isPr => boolean().withDefault(const Constant(false))();
}

class BodyMeasurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get weight => real().nullable()(); // in kg
  RealColumn get waist => real().nullable()(); // in cm
  RealColumn get chest => real().nullable()(); // in cm
  RealColumn get arms => real().nullable()(); // in cm
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}
