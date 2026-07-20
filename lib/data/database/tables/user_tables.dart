import 'package:drift/drift.dart';

class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get age => integer().withDefault(const Constant(25))();
  RealColumn get height => real().withDefault(const Constant(170.0))();
  RealColumn get weight => real().withDefault(const Constant(70.0))();
  TextColumn get sex => text().withDefault(const Constant('male'))();
  TextColumn get activityLevel => text().withDefault(const Constant('moderate'))();
  TextColumn get goal => text().withDefault(const Constant('maintain'))();
  TextColumn get dietPreference => text().withDefault(const Constant('balanced'))();
  IntColumn get calorieGoal => integer().withDefault(const Constant(2000))();
  RealColumn get proteinGoal => real().withDefault(const Constant(140.0))();
  RealColumn get carbsGoal => real().withDefault(const Constant(220.0))();
  RealColumn get fatGoal => real().withDefault(const Constant(60.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
