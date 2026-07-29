import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixtures/backup_v5_fixtures.dart';

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

  group('B01-02 Backup V5 Fixtures & Restore Transaction Tests', () {
    test(
      'Valid Backup v5 fixture parses and restores to database and preferences',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final backup = BackupV5Fixtures.validBackupV5Object();

        await backup.restoreToDatabase(db, prefs);

        final routines = await db.select(db.workoutRoutines).get();
        expect(routines.length, equals(1));
        expect(routines.first.name, equals('Upper Body Split'));

        final sessions = await db.select(db.workoutSessions).get();
        expect(sessions.length, equals(1));
        expect(sessions.first.name, equals('Push Session'));

        final sets = await db.select(db.workoutSets).get();
        expect(sets.length, equals(1));
        expect(sets.first.exerciseName, equals('Flat Barbell Bench Press'));

        expect(prefs.getInt('water_logged'), equals(6));
        expect(prefs.getInt('user_streak_count'), equals(10));
      },
    );

    test(
      'Unsupported backup version fixture throws FormatException on fromJson',
      () {
        final unsupportedMap = BackupV5Fixtures.unsupportedVersionBackupMap();
        expect(
          () => BackupData.fromJson(unsupportedMap),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('Corrupt schema fixture throws error during deserialization', () {
      final corruptMap = BackupV5Fixtures.corruptSchemaBackupMap();
      expect(() => BackupData.fromJson(corruptMap), throwsA(isA<Object>()));
    });

    test(
      'Orphaned sets backup fixture fails prevalidation and preserves existing database',
      () async {
        await db
            .into(db.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                age: const Value(30),
                calorieGoal: const Value(2200),
              ),
            );

        final orphanMap = BackupV5Fixtures.orphanedSetsBackupV5Map();
        final orphanBackup = BackupData.fromJson(orphanMap);
        final prefs = await SharedPreferences.getInstance();

        expect(
          () => orphanBackup.restoreToDatabase(db, prefs),
          throwsA(isA<FormatException>()),
        );

        final profiles = await db.select(db.userProfiles).get();
        expect(profiles.length, equals(1));
        expect(profiles.first.calorieGoal, equals(2200));
      },
    );

    test(
      'Pre-mutation validation failure preserves existing database data byte-for-byte',
      () async {
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

        final malformedPayload = {'version': 99, 'schema_version': 13};

        final prefs = await SharedPreferences.getInstance();

        expect(
          () => BackupData.fromJson(malformedPayload),
          throwsA(isA<FormatException>()),
        );

        final postLogs = await db.select(db.foodLogs).get();
        expect(postLogs.length, equals(1));
        expect(postLogs.first.name, equals('Original Pre-existing Apple'));
        expect(prefs.getInt('water_logged'), equals(2));
      },
    );

    test(
      'Injected transaction failure rolls back 100% of database writes',
      () async {
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

        try {
          await db.transaction(() async {
            await db.delete(db.foodLogs).go();
            await db.delete(db.userProfiles).go();
            throw Exception('Simulated Database Transaction Failure');
          });
        } catch (e) {
          expect(
            e.toString(),
            contains('Simulated Database Transaction Failure'),
          );
        }

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
      'ID collisions do not overwrite seeded catalog items and remap references',
      () async {
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
          dailyHydrations: const [],
          healthProvenances: const [],
          achievementUnlocks: const [],
        );

        final prefs = await SharedPreferences.getInstance();
        await backup.restoreToDatabase(db, prefs);

        final postFoods = await db.select(db.foodItems).get();
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
      'SettingsController.performRestore throws StateError on concurrent restore',
      () async {
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final controller = container.read(settingsControllerProvider.notifier);
        final validData = BackupV5Fixtures.validBackupV5Map();

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
