import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late EquipmentProfileRepository equipment;
  late ExercisePreferenceRepository preferences;

  setUp(() async {
    db = AppDatabase.memory();
    equipment = EquipmentProfileRepository(db);
    preferences = ExercisePreferenceRepository(db);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('exercise-bench-v1'),
            name: 'Flat Barbell Bench Press',
            muscleGroups: 'Chest',
            equipment: 'Barbell, Bench',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );
  });

  tearDown(() => db.close());

  group('B01-07 equipment profiles', () {
    test(
      'uses fixture-owned codes, increments, and implicit bodyweight',
      () async {
        final profileId = await equipment.createProfile(
          name: 'Home',
          defaultWeightIncrementKg: 2.5,
          items: const [
            EquipmentProfileItemInput(
              equipmentCode: 'dumbbell',
              weightIncrementKg: 2.5,
            ),
            EquipmentProfileItemInput(equipmentCode: 'bench'),
          ],
        );
        final profile = await equipment.getProfile(profileId);
        expect(profile!.items.map((item) => item.equipmentCode), [
          'bench',
          'dumbbell',
        ]);
        expect(
          await equipment.isEquipmentAvailable(
            profileId: profileId,
            equipmentCode: 'bodyweight',
          ),
          isTrue,
        );
        expect(
          await equipment.isEquipmentAvailable(
            profileId: profileId,
            equipmentCode: 'barbell',
          ),
          isFalse,
        );
        await expectLater(
          equipment.createProfile(
            name: 'Invalid code',
            items: const [
              EquipmentProfileItemInput(equipmentCode: 'smith_machine'),
            ],
          ),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          equipment.createProfile(
            name: 'Invalid bodyweight item',
            items: const [
              EquipmentProfileItemInput(equipmentCode: 'bodyweight'),
            ],
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'has explicit compatible, incompatible, and unknown outcomes',
      () async {
        final profileId = await equipment.createProfile(
          name: 'Cable only',
          items: const [EquipmentProfileItemInput(equipmentCode: 'cable')],
        );
        final compatible = await equipment.checkCompatibility(
          profileId: profileId,
          exerciseEquipmentRequirement: 'Cable',
        );
        final incompatible = await equipment.checkCompatibility(
          profileId: profileId,
          exerciseEquipmentRequirement: 'Barbell, Bench',
        );
        final unknown = await equipment.checkCompatibility(
          profileId: profileId,
          exerciseEquipmentRequirement: 'Alien machine',
        );
        expect(compatible.status, EquipmentCompatibilityStatus.compatible);
        expect(incompatible.status, EquipmentCompatibilityStatus.incompatible);
        expect(incompatible.unavailableEquipmentCodes, ['barbell', 'bench']);
        expect(unknown.status, EquipmentCompatibilityStatus.unknown);
      },
    );

    test('stores the sole default profile in training plan settings', () async {
      final first = await equipment.createProfile(name: 'Commercial Gym');
      final second = await equipment.createProfile(name: 'Garage Gym');
      await equipment.setDefaultProfileId(first);
      await equipment.setDefaultProfileId(second);
      expect(await equipment.getDefaultProfileId(), second);
      await expectLater(
        equipment.archiveProfile(second),
        throwsA(isA<StateError>()),
      );
      await equipment.clearDefaultProfile();
      await equipment.archiveProfile(second);
      expect(
        (await equipment.getProfileById(second))!.archivedAtUtc,
        isNotNull,
      );
    });

    test('does not archive a profile used by active travel', () async {
      final profile = await equipment.createProfile(name: 'Travel');
      await db
          .into(db.travelContexts)
          .insert(
            TravelContextsCompanion.insert(
              id: 'travel-1',
              startLocalDate: '2026-08-01',
              endLocalDate: '2026-08-07',
              timezoneId: 'Asia/Kolkata',
              equipmentProfileId: profile,
              status: const Value('active'),
              createdAtUtc: DateTime.utc(2026, 8, 1),
            ),
          );
      await expectLater(
        equipment.archiveProfile(profile),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('B01-07 exercise preference aggregate', () {
    test(
      'persists ordered setup values, personal cues, and a general note',
      () async {
        await preferences.savePreference(
          stableId: 'exercise-bench-v1',
          generalNote: 'Seat position 4',
          setupValues: const [
            SetupValueInput(ordinal: 0, label: 'Bench pin', value: '4'),
            SetupValueInput(ordinal: 1, label: 'Safety arm', value: '6'),
          ],
          personalCues: const ['Bend the bar', 'Touch lower sternum'],
        );
        final saved = await preferences.getPreference(
          stableId: 'exercise-bench-v1',
        );
        expect(saved!.preference.generalNote, 'Seat position 4');
        expect(saved.setupValues.map((value) => value.label), [
          'Bench pin',
          'Safety arm',
        ]);
        expect(saved.personalCues.map((cue) => cue.cueText), [
          'Bend the bar',
          'Touch lower sternum',
        ]);

        await preferences.savePreference(
          stableId: 'exercise-bench-v1',
          personalCues: const ['New first cue'],
        );
        final reordered = await preferences.getPreference(
          stableId: 'exercise-bench-v1',
        );
        expect(reordered!.preference.generalNote, 'Seat position 4');
        expect(reordered.setupValues.map((value) => value.label), [
          'Bench pin',
          'Safety arm',
        ]);
        expect(reordered.personalCues.single.cueText, 'New first cue');
      },
    );

    test(
      'preserves an unresolved raw fallback only when explicitly requested',
      () async {
        await expectLater(
          preferences.savePreference(rawName: 'Pike Push-ups'),
          throwsA(isA<ArgumentError>()),
        );
        await preferences.savePreference(
          rawName: ' Pike   Push-ups ',
          allowUnresolvedRawFallback: true,
          personalCues: const ['Look at toes'],
        );
        final saved = await preferences.getPreference(rawName: 'pike push-ups');
        expect(saved!.preference.exerciseId, isNull);
        expect(saved.preference.exerciseNameFallback, 'Pike   Push-ups');
        expect(saved.personalCues.single.cueText, 'Look at toes');
      },
    );

    test(
      'rejects invalid children and never changes template or history tables',
      () async {
        await expectLater(
          preferences.savePreference(
            stableId: 'exercise-bench-v1',
            setupValues: const [
              SetupValueInput(ordinal: 1, label: 'Pin', value: '4'),
            ],
          ),
          throwsA(isA<ArgumentError>()),
        );
        expect(await db.select(db.exercisePrescriptions).get(), isEmpty);
        expect(await db.select(db.workoutSets).get(), isEmpty);
      },
    );
  });
}
