import 'package:drift/drift.dart';

class DailyHydrations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateString => text().unique()(); // Format: YYYY-MM-DD
  IntColumn get totalMl => integer()();
  IntColumn get goalMl => integer()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
