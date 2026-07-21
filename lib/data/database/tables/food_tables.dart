import 'package:drift/drift.dart';

class FoodItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get nameHindi => text().nullable()();
  IntColumn get calories => integer()();
  RealColumn get proteinG => real()();
  RealColumn get carbsG => real()();
  RealColumn get fatG => real()();
  RealColumn get fiberG => real().nullable()();
  RealColumn get servingSize => real()();
  TextColumn get servingUnit => text()();
  TextColumn get category => text()(); // "roti", "rice", "dal", "sabzi", "snack", "drink", etc.
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get brand => text().nullable()();
  TextColumn get regionPack => text().nullable()();
}

class FoodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get foodItemId => integer().nullable().references(FoodItems, #id)();
  TextColumn get name => text()();
  IntColumn get calories => integer()();
  RealColumn get proteinG => real()();
  RealColumn get carbsG => real()();
  RealColumn get fatG => real()();
  RealColumn get servingLogged => real()();
  TextColumn get servingUnit => text()();
  TextColumn get mealType => text()(); // "breakfast", "lunch", "dinner", "snack"
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get mealGroupId => text().nullable()();
  TextColumn get uuid => text().nullable()();
}

class MealTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get defaultMealType => text().withDefault(const Constant('breakfast'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class MealTemplateItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateId => integer().references(MealTemplates, #id)();
  TextColumn get name => text()();
  IntColumn get calories => integer()();
  RealColumn get proteinG => real()();
  RealColumn get carbsG => real()();
  RealColumn get fatG => real()();
  RealColumn get servingLogged => real()();
  TextColumn get servingUnit => text()();
}
