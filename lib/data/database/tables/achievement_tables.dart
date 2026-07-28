import 'package:drift/drift.dart';

class AchievementUnlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get achievementId => text().unique()();
  DateTimeColumn get unlockedAt => dateTime().withDefault(currentDateAndTime)();
}
