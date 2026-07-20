import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:indifit/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drift DB Schema Migration Integration Tests', () {
    test('AppDatabase schema version 6 initializes and supports CRUD operations', () async {
      final db = AppDatabase.memory();

      expect(db.schemaVersion, 6);

      // Verify UserProfiles table CRUD (added in v5)
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          calorieGoal: const Value(2200),
          proteinGoal: const Value(160.0),
          carbsGoal: const Value(220.0),
          fatGoal: const Value(70.0),
        ),
      );

      final profiles = await db.select(db.userProfiles).get();
      expect(profiles.length, 1);
      expect(profiles.first.calorieGoal, 2200);

      // Verify MealTemplates table CRUD (added in v6)
      final templateId = await db.into(db.mealTemplates).insert(
        MealTemplatesCompanion.insert(
          name: 'High Protein Oats',
          defaultMealType: const Value('breakfast'),
        ),
      );

      expect(templateId, greaterThan(0));

      final templates = await db.select(db.mealTemplates).get();
      expect(templates.length, 1);
      expect(templates.first.name, 'High Protein Oats');

      await db.close();
    });
  });
}
