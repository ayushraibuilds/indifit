import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:indifit/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drift DB Schema Migration Integration Tests', () {
    test('AppDatabase schema version 10 initializes and supports CRUD operations', () async {
      final db = AppDatabase.memory();

      expect(db.schemaVersion, 11);



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

      // Verify brand & regionPack columns (added in v8)
      final foodId = await db.into(db.foodItems).insert(
        FoodItemsCompanion.insert(
          name: 'Test Paneer',
          calories: 300,
          proteinG: 20.0,
          carbsG: 5.0,
          fatG: 22.0,
          servingSize: 100.0,
          servingUnit: 'g',
          category: 'dairy',
          brand: const Value('Amul'),
          regionPack: const Value('gujarati'),
        ),
      );

      final insertedFood = await (db.select(db.foodItems)..where((t) => t.id.equals(foodId))).getSingle();
      expect(insertedFood.brand, 'Amul');
      expect(insertedFood.regionPack, 'gujarati');

      // Verify durationSeconds, distanceKm, inclinePercentage columns (added in v9)
      final sessionId = await db.into(db.workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          name: 'Test Session',
          totalVolume: 0.0,
          durationSeconds: 300,
          estimatedCalories: 100,
        ),
      );

      final setId = await db.into(db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseName: 'Treadmill Run',
          weight: 0.0,
          reps: 0,
          setNumber: 1,
          durationSeconds: const Value(600),
          distanceKm: const Value(1.5),
          inclinePercentage: const Value(2.5),
        ),
      );

      final insertedSet = await (db.select(db.workoutSets)..where((t) => t.id.equals(setId))).getSingle();
      expect(insertedSet.durationSeconds, 600);
      expect(insertedSet.distanceKm, 1.5);
      expect(insertedSet.inclinePercentage, 2.5);

      await db.close();
    });
  });
}
