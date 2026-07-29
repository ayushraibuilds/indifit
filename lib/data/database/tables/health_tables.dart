import 'package:drift/drift.dart';
import 'workout_tables.dart';

class HealthProvenances extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider => text()(); // "health_connect", "health_kit"
  TextColumn get externalId => text().nullable().unique()();
  TextColumn get sourceName =>
      text()(); // "Google Fit", "Apple Health", "IndiFit"
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get localSessionId =>
      integer().nullable().references(WorkoutSessions, #id)();
  TextColumn get fingerprint => text().unique()();
}
