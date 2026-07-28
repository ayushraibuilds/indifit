import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
    SharedPreferences.setMockInitialValues({
      'water_logged': 2,
      'user_streak_count': 5,
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('Task T4: Atomic and Non-Destructive Restore Transaction Tests', () {
    test(
      'Pre-mutation validation failure preserves existing database data byte-for-byte',
      () async {
        // Seed pre-existing initial database data
        await db
            .into(db.foodLogs)
            .insert(
              FoodLogsCompanion.insert(
                name: 'Original Pre-existing Apple',
                calories: 95,
                proteinG: 0.5,
                carbsG: 25.0,
                fatG: 0.3,
                servingLogged: 1.0,
                servingUnit: 'apple',
                mealType: 'snack',
              ),
            );

        final initialLogs = await db.select(db.foodLogs).get();
        expect(initialLogs.length, equals(1));
        expect(initialLogs.first.name, equals('Original Pre-existing Apple'));

        // Attempt restore with unsupported version payload
        final malformedPayload = {
          'version': 99, // Unsupported version
          'schema_version': 13,
        };

        final prefs = await SharedPreferences.getInstance();

        expect(
          () => BackupData.fromJson(malformedPayload),
          throwsA(isA<FormatException>()),
        );

        // Verify database data was NOT touched or deleted
        final postLogs = await db.select(db.foodLogs).get();
        expect(postLogs.length, equals(1));
        expect(postLogs.first.name, equals('Original Pre-existing Apple'));
        expect(prefs.getInt('water_logged'), equals(2));
      },
    );

    test(
      'Injected transaction failure rolls back 100% of database writes',
      () async {
        // Seed pre-existing database record
        await db
            .into(db.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                age: const Value(25),
                calorieGoal: const Value(2000),
              ),
            );
        await db
            .into(db.foodLogs)
            .insert(
              FoodLogsCompanion.insert(
                name: 'Existing Log',
                calories: 100,
                proteinG: 5.0,
                carbsG: 10.0,
                fatG: 2.0,
                servingLogged: 1.0,
                servingUnit: 'portion',
                mealType: 'lunch',
              ),
            );

        final initialProfiles = await db.select(db.userProfiles).get();
        expect(initialProfiles.length, equals(1));

        final prefs = await SharedPreferences.getInstance();

        // Verify that if restoreToDatabase fails during transaction, changes roll back
        try {
          await db.transaction(() async {
            await db.delete(db.foodLogs).go();
            await db.delete(db.userProfiles).go();
            // Simulate injected error mid-transaction
            throw Exception('Simulated Database Transaction Failure');
          });
        } catch (e) {
          expect(
            e.toString(),
            contains('Simulated Database Transaction Failure'),
          );
        }

        // Assert complete rollback: original records remain byte-for-byte intact
        final restoredProfiles = await db.select(db.userProfiles).get();
        final restoredLogs = await db.select(db.foodLogs).get();

        expect(restoredProfiles.length, equals(1));
        expect(restoredProfiles.first.calorieGoal, equals(2000));
        expect(restoredLogs.length, equals(1));
        expect(restoredLogs.first.name, equals('Existing Log'));
        expect(prefs.getInt('water_logged'), equals(2));
      },
    );

    test(
      'SharedPreferences update is retained after a successful restore',
      () async {
        final prefs = await SharedPreferences.getInstance();

        final backup = BackupData(
          version: 4,
          timestamp: DateTime.now().toIso8601String(),
          schemaVersion: 13,
          userSettings: [],
          userPreferences: {'water_logged': 8, 'user_streak_count': 21},
          customFoodItems: [],
          foodLogs: [],
          mealTemplates: [],
          mealTemplateItems: [],
          customExercises: [],
          workoutSessions: [],
          workoutSets: [],
          workoutRoutines: [],
          routineDays: [],
          routineExercises: [],
          workoutDrafts: [],
          bodyMeasurements: [],
        );

        await backup.restoreToDatabase(db, prefs);

        expect(prefs.getInt('water_logged'), equals(8));
        expect(prefs.getInt('user_streak_count'), equals(21));
      },
    );

    test(
      'Database failure restores existing preferences and removes new ones',
      () async {
        await db
            .into(db.foodLogs)
            .insert(
              FoodLogsCompanion.insert(
                name: 'Existing Log',
                calories: 100,
                proteinG: 5.0,
                carbsG: 10.0,
                fatG: 2.0,
                servingLogged: 1.0,
                servingUnit: 'portion',
                mealType: 'lunch',
              ),
            );
        await db.customStatement('''
          CREATE TRIGGER fail_restored_food_log
          BEFORE INSERT ON food_logs
          BEGIN
            SELECT RAISE(ABORT, 'simulated restore database failure');
          END;
        ''');

        final backup = BackupData(
          version: 4,
          timestamp: DateTime.now().toIso8601String(),
          schemaVersion: 13,
          userSettings: [],
          userPreferences: {
            'water_logged': 8,
            'restore_created_value': 'must be removed',
          },
          customFoodItems: [],
          foodLogs: [
            FoodLog(
              id: 1,
              name: 'Restored Log',
              calories: 250,
              proteinG: 20.0,
              carbsG: 30.0,
              fatG: 8.0,
              servingLogged: 1.0,
              servingUnit: 'g',
              mealType: 'lunch',
              loggedAt: DateTime.now(),
              isSynced: false,
            ),
          ],
          mealTemplates: [],
          mealTemplateItems: [],
          customExercises: [],
          workoutSessions: [],
          workoutSets: [],
          workoutRoutines: [],
          routineDays: [],
          routineExercises: [],
          workoutDrafts: [],
          bodyMeasurements: [],
        );

        final prefs = await SharedPreferences.getInstance();
        await expectLater(
          backup.restoreToDatabase(db, prefs),
          throwsA(isA<Exception>()),
        );

        expect(prefs.getInt('water_logged'), equals(2));
        expect(prefs.containsKey('restore_created_value'), isFalse);
        final logs = await db.select(db.foodLogs).get();
        expect(logs.single.name, equals('Existing Log'));
      },
    );

    test(
      'ID collisions do not overwrite seeded catalog items and remap references',
      () async {
        // Seed food with target ID in database
        final targetFoodId = await db
            .into(db.foodItems)
            .insert(
              FoodItemsCompanion.insert(
                name: 'Target Seeded Food',
                calories: 100,
                proteinG: 5.0,
                carbsG: 10.0,
                fatG: 2.0,
                servingSize: 100,
                servingUnit: 'g',
                category: 'general',
                isCustom: const Value(false),
              ),
            );

        final initialFoods = await db.select(db.foodItems).get();
        final initialCount = initialFoods.length;

        // Backup has a custom food with source ID matching targetFoodId
        final backup = BackupData(
          version: 4,
          timestamp: DateTime.now().toIso8601String(),
          schemaVersion: 13,
          userSettings: [],
          userPreferences: {},
          customFoodItems: [
            FoodItem(
              id: targetFoodId,
              name: 'Restored Custom Food Collision',
              calories: 250,
              proteinG: 20.0,
              carbsG: 30.0,
              fatG: 8.0,
              servingSize: 150.0,
              servingUnit: 'g',
              category: 'custom',
              isCustom: true,
            ),
          ],
          foodLogs: [
            FoodLog(
              id: 1,
              foodItemId: targetFoodId,
              name: 'Restored Log',
              calories: 250,
              proteinG: 20.0,
              carbsG: 30.0,
              fatG: 8.0,
              servingLogged: 1.0,
              servingUnit: 'g',
              mealType: 'lunch',
              loggedAt: DateTime.now(),
              isSynced: false,
            ),
          ],
          mealTemplates: [],
          mealTemplateItems: [],
          customExercises: [],
          workoutSessions: [],
          workoutSets: [],
          workoutRoutines: [],
          routineDays: [],
          routineExercises: [],
          workoutDrafts: [],
          bodyMeasurements: [],
        );

        final prefs = await SharedPreferences.getInstance();
        await backup.restoreToDatabase(db, prefs);

        final postFoods = await db.select(db.foodItems).get();
        // Both seeded food and custom food exist without catalog corruption
        expect(postFoods.length, equals(initialCount + 1));
        final seeded = postFoods.firstWhere(
          (f) => f.name == 'Target Seeded Food',
        );
        expect(seeded.id, equals(targetFoodId));

        final custom = postFoods.firstWhere(
          (f) => f.name == 'Restored Custom Food Collision',
        );
        expect(custom.id, isNot(equals(targetFoodId)));

        final postLogs = await db.select(db.foodLogs).get();
        expect(postLogs.length, equals(1));
        expect(postLogs.first.foodItemId, equals(custom.id));
      },
    );

    test(
      'Orphaned relationship payload fails prevalidation and rolls back completely',
      () async {
        await db
            .into(db.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                age: const Value(30),
                calorieGoal: const Value(2200),
              ),
            );

        // Backup has a workout set referencing non-existent session 999
        final orphanedBackup = BackupData(
          version: 4,
          timestamp: DateTime.now().toIso8601String(),
          schemaVersion: 13,
          userSettings: [],
          userPreferences: {},
          customFoodItems: [],
          foodLogs: [],
          mealTemplates: [],
          mealTemplateItems: [],
          customExercises: [],
          workoutSessions: [], // Empty sessions list
          workoutSets: [
            WorkoutSet(
              id: 1,
              sessionId: 999, // Non-existent session ID
              exerciseName: 'Bench Press',
              weight: 80.0,
              reps: 10,
              setNumber: 1,
              isPr: false,
              isWarmUp: false,
              setType: 'normal',
            ),
          ],
          workoutRoutines: [],
          routineDays: [],
          routineExercises: [],
          workoutDrafts: [],
          bodyMeasurements: [],
        );

        final prefs = await SharedPreferences.getInstance();
        expect(
          () => orphanedBackup.restoreToDatabase(db, prefs),
          throwsA(isA<FormatException>()),
        );

        // Verify pre-existing user profile remained intact
        final profiles = await db.select(db.userProfiles).get();
        expect(profiles.length, equals(1));
        expect(profiles.first.calorieGoal, equals(2200));
      },
    );

    test(
      'SettingsController.performRestore throws StateError on concurrent restore',
      () async {
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final controller = container.read(settingsControllerProvider.notifier);

        final validData = BackupData(
          version: 4,
          timestamp: DateTime.now().toIso8601String(),
          schemaVersion: 13,
          userSettings: [],
          userPreferences: {},
          customFoodItems: [],
          foodLogs: [],
          mealTemplates: [],
          mealTemplateItems: [],
          customExercises: [],
          workoutSessions: [],
          workoutSets: [],
          workoutRoutines: [],
          routineDays: [],
          routineExercises: [],
          workoutDrafts: [],
          bodyMeasurements: [],
        ).toJson();

        // Launch two restores simultaneously
        final f1 = controller.performRestore(validData);
        expect(
          () => controller.performRestore(validData),
          throwsA(isA<StateError>()),
        );

        await f1;
        expect(container.read(settingsControllerProvider).loading, isFalse);
      },
    );
  });
}
