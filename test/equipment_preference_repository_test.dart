import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late EquipmentRepository equipRepo;
  late ExercisePreferenceRepository prefRepo;

  setUp(() {
    db = AppDatabase.memory();
    equipRepo = EquipmentRepository(db);
    prefRepo = ExercisePreferenceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('B01-07 Equipment & Exercise Preference Repository Tests', () {
    test('1. Creates equipment profile and checks item availability', () async {
      final profileId = await equipRepo.createProfile(
        name: 'Home Dumbbell Setup',
        defaultWeightIncrementKg: 2.5,
        items: [
          const EquipmentProfileItemInput(
            equipmentCode: 'dumbbell',
            isAvailable: true,
            weightIncrementKg: 2.5,
          ),
          const EquipmentProfileItemInput(
            equipmentCode: 'barbell',
            isAvailable: false,
          ),
        ],
      );

      final profile = await equipRepo.getProfileById(profileId);
      expect(profile, isNotNull);
      expect(profile!.name, equals('Home Dumbbell Setup'));

      final items = await equipRepo.getItemsForProfile(profileId);
      expect(items.length, equals(2));

      // Check equipment availability
      expect(
        await equipRepo.isEquipmentAvailable(
          profileId: profileId,
          equipmentCode: 'dumbbell',
        ),
        isTrue,
      );
      expect(
        await equipRepo.isEquipmentAvailable(
          profileId: profileId,
          equipmentCode: 'barbell',
        ),
        isFalse,
      );

      // Bodyweight is always available implicitly
      expect(
        await equipRepo.isEquipmentAvailable(
          profileId: profileId,
          equipmentCode: 'bodyweight',
        ),
        isTrue,
      );
    });

    test(
      '2. Default equipment profile configuration in TrainingPlanSettings',
      () async {
        final p1Id = await equipRepo.createProfile(name: 'Commercial Gym');
        final p2Id = await equipRepo.createProfile(name: 'Garage Gym');

        expect(await equipRepo.getDefaultProfileId(), isNull);

        await equipRepo.setDefaultProfileId(p1Id);
        expect(await equipRepo.getDefaultProfileId(), equals(p1Id));

        await equipRepo.setDefaultProfileId(p2Id);
        expect(await equipRepo.getDefaultProfileId(), equals(p2Id));
      },
    );

    test(
      '3. Archiving default equipment profile or profile in active travel throws StateError',
      () async {
        final pId = await equipRepo.createProfile(name: 'Travel Gym Profile');
        await equipRepo.setDefaultProfileId(pId);

        // Cannot archive default profile
        expect(() => equipRepo.archiveProfile(pId), throwsA(isA<StateError>()));

        // Change default profile to another
        final otherId = await equipRepo.createProfile(name: 'Home Profile');
        await equipRepo.setDefaultProfileId(otherId);

        // Add active travel context using pId
        await db
            .into(db.travelContexts)
            .insert(
              TravelContextsCompanion.insert(
                id: 'travel-1',
                startLocalDate: '2026-08-01',
                endLocalDate: '2026-08-07',
                timezoneId: 'Asia/Kolkata',
                equipmentProfileId: pId,
                status: const Value('active'),
                createdAtUtc: DateTime.now().toUtc(),
              ),
            );

        // Cannot archive profile used in active travel context
        expect(() => equipRepo.archiveProfile(pId), throwsA(isA<StateError>()));
      },
    );

    test(
      '4. Exercise preference aggregate lookup by stableId or rawName fallback',
      () async {
        // Seed exercise in database with stable ID
        await db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(
                stableId: const Value('ex-bench-press-uuid'),
                name: 'Barbell Bench Press',
                muscleGroups: 'Chest',
                equipment: 'Barbell',
                difficulty: 'Intermediate',
                formCues: 'Arch upper back',
                commonMistakes: 'Bouncing bar off chest',
              ),
            );

        final prefId1 = await prefRepo.savePreference(
          stableId: 'ex-bench-press-uuid',
          generalNote: 'Arch shoulders, drive through heels',
          setupValues: [
            const SetupValueInput(
              ordinal: 0,
              label: 'Bench Pin Height',
              value: '4',
            ),
          ],
          personalCues: ['Bend the bar', 'Touch lower sternum'],
        );

        final aggregate1 = await prefRepo.getPreference(
          stableId: 'ex-bench-press-uuid',
        );
        expect(aggregate1, isNotNull);
        expect(aggregate1!.preference.id, equals(prefId1));
        expect(
          aggregate1.preference.generalNote,
          equals('Arch shoulders, drive through heels'),
        );
        expect(aggregate1.setupValues.length, equals(1));
        expect(aggregate1.setupValues.first.label, equals('Bench Pin Height'));
        expect(aggregate1.personalCues.length, equals(2));
        expect(aggregate1.personalCues.first.cueText, equals('Bend the bar'));

        // Raw name fallback lookup for uncatalogued custom exercise
        final prefId2 = await prefRepo.savePreference(
          rawName: 'Pike Push-ups',
          generalNote: 'Elevate feet on bench',
          personalCues: ['Look at toes'],
        );

        final aggregate2 = await prefRepo.getPreference(
          rawName: 'Pike Push-ups',
        );
        expect(aggregate2, isNotNull);
        expect(aggregate2!.preference.id, equals(prefId2));
        expect(
          aggregate2.preference.identityKey,
          equals('raw_name:pike push-ups'),
        );
        expect(aggregate2.personalCues.single.cueText, equals('Look at toes'));
      },
    );
  });
}
