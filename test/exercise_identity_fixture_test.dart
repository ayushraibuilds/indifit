import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseCatalogManifest manifest;
  late ExerciseIdentityLookup lookup;

  setUp(() {
    manifest = ExerciseCatalogManifest.loadFromAssetFileSync(
      'assets/data/exercises.json',
    );
    lookup = ExerciseIdentityLookup(manifest);
  });

  group('B01-01 Exercise Identity Fixture Tests (Remediated)', () {
    test('1. Golden UUID mapping for bundled exercises', () {
      expect(manifest.totalEntries, equals(140));

      final bench = manifest.getByNormalizedName('flat barbell bench press');
      expect(bench, isNotNull);
      expect(bench!.uuid, equals('089ec703-a25e-5b12-a39a-78b17ee33742'));

      final squat = manifest.getByNormalizedName('barbell squat');
      expect(squat, isNotNull);
      expect(squat!.uuid, equals('d3b5ab04-74f6-5155-9621-50238644eeda'));

      final deadlift = manifest.getByNormalizedName('barbell deadlift');
      expect(deadlift, isNotNull);
      expect(deadlift!.uuid, equals('b102bfa4-6cc5-5e60-accb-82a1ae39b8bc'));
    });

    test(
      '2. Explicit manifest UUID preserves a cosmetic display-name change',
      () {
        final jsonPayload = [
          {
            'uuid': '089ec703-a25e-5b12-a39a-78b17ee33742',
            'name': 'Barbell Bench Press (Flat Cosmetic Rename)',
            'muscle_groups': 'Chest',
            'equipment': 'Barbell',
            'difficulty': 'Intermediate',
          },
        ];

        final customManifest = ExerciseCatalogManifest.fromJsonList(
          jsonPayload,
        );
        final entryByUuid = customManifest.getByUuid(
          '089ec703-a25e-5b12-a39a-78b17ee33742',
        );

        expect(entryByUuid, isNotNull);
        expect(
          entryByUuid!.uuid,
          equals('089ec703-a25e-5b12-a39a-78b17ee33742'),
        );
        expect(
          entryByUuid.name,
          equals('Barbell Bench Press (Flat Cosmetic Rename)'),
        );
      },
    );

    test(
      '3. Unregistered catalogue rename fails rather than minting an ID',
      () {
        expect(
          () => ExerciseCatalogManifest.fromJsonList([
            {
              'name': 'Barbell Bench Press (Flat Cosmetic Rename)',
              'muscle_groups': 'Chest',
              'equipment': 'Barbell',
              'difficulty': 'Intermediate',
            },
          ]),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('4. Manifest reordering preserves UUIDs', () {
      final item1 = {
        'uuid': '11111111-1111-1111-1111-111111111111',
        'name': 'Exercise Alpha',
      };
      final item2 = {
        'uuid': '22222222-2222-2222-2222-222222222222',
        'name': 'Exercise Beta',
      };

      final manifestOrderA = ExerciseCatalogManifest.fromJsonList([
        item1,
        item2,
      ]);
      final manifestOrderB = ExerciseCatalogManifest.fromJsonList([
        item2,
        item1,
      ]);

      expect(
        manifestOrderA.getByUuid('11111111-1111-1111-1111-111111111111')!.name,
        equals('Exercise Alpha'),
      );
      expect(
        manifestOrderB.getByUuid('11111111-1111-1111-1111-111111111111')!.name,
        equals('Exercise Alpha'),
      );
    });

    test('5. UUID uniqueness', () {
      final uuidSet = <String>{};
      for (final entry in manifest.allEntries) {
        expect(
          uuidSet.contains(entry.uuid),
          isFalse,
          reason: 'Duplicate UUID: ${entry.uuid}',
        );
        uuidSet.add(entry.uuid);
      }
      expect(uuidSet.length, equals(140));
    });

    test('6. Duplicate UUID rejection', () {
      final duplicateUuidJson = [
        {
          'uuid': '089ec703-a25e-5b12-a39a-78b17ee33742',
          'name': 'Exercise One',
        },
        {
          'uuid': '089ec703-a25e-5b12-a39a-78b17ee33742',
          'name': 'Exercise Two',
        },
      ];

      expect(
        () => ExerciseCatalogManifest.fromJsonList(duplicateUuidJson),
        throwsA(isA<StateError>()),
      );
    });

    test('7. Approved one-to-one alias resolution', () {
      lookup.validateFixtures();

      final res1 = lookup.lookup('push-ups');
      expect(res1.status, equals(ExerciseLookupStatus.resolved));
      expect(res1.canonicalName, equals('Push-Ups'));
      expect(res1.canonicalUuid, isNotNull);

      final res2 = lookup.lookup('seated dumbbell press');
      expect(res2.status, equals(ExerciseLookupStatus.resolved));
      expect(res2.canonicalName, equals('Seated Dumbbell Shoulder Press'));

      final res3 = lookup.lookup('incline dumbbell press');
      expect(res3.status, equals(ExerciseLookupStatus.resolved));
      expect(res3.canonicalName, equals('Incline Dumbbell Bench Press'));
    });

    test('8. Generic "dumbbell curls" remains ambiguous', () {
      final res1 = lookup.lookup('dumbbell curls');
      expect(res1.status, equals(ExerciseLookupStatus.ambiguous));
      expect(res1.canonicalUuid, isNull);

      final res2 = lookup.lookup('dumbbell curl');
      expect(res2.status, equals(ExerciseLookupStatus.ambiguous));
      expect(res2.canonicalUuid, isNull);
    });

    test('9. Generic ambiguous names do not resolve', () {
      final ambiguousNames = [
        'squats',
        'leg curl machine',
        'dumbbell bench press',
        'dips',
        'tricep dips',
        'row',
      ];

      for (final name in ambiguousNames) {
        final res = lookup.lookup(name);
        expect(
          res.status,
          equals(ExerciseLookupStatus.ambiguous),
          reason: 'Expected "$name" to be marked ambiguous',
        );
        expect(res.canonicalUuid, isNull);
      }
    });

    test('10. Alias collision with multiple candidates is rejected', () {
      final collisionLookup = ExerciseIdentityLookup(
        manifest,
        approvedAliases: const [
          ApprovedExerciseAlias('bench variant', 'Push-Ups'),
          ApprovedExerciseAlias(' Bench   Variant ', 'Barbell Squat'),
        ],
      );

      expect(collisionLookup.validateFixtures, throwsA(isA<StateError>()));
    });

    test('11. Technique variants remain separate', () {
      final standard = lookup.lookup('Flat Barbell Bench Press (Standard)');
      final pause = lookup.lookup('Pause Flat Barbell Bench Press');
      final slow = lookup.lookup('Slow Eccentric Flat Barbell Bench Press');
      final base = lookup.lookup('Flat Barbell Bench Press');

      expect(standard.status, equals(ExerciseLookupStatus.resolved));
      expect(pause.status, equals(ExerciseLookupStatus.resolved));
      expect(slow.status, equals(ExerciseLookupStatus.resolved));
      expect(base.status, equals(ExerciseLookupStatus.resolved));

      final ids = {
        standard.canonicalUuid,
        pause.canonicalUuid,
        slow.canonicalUuid,
        base.canonicalUuid,
      };
      expect(ids.length, equals(4));
    });

    test('12. Equipment variants remain separate where required', () {
      final barbellPress = lookup.lookup('Overhead Barbell Press');
      final dumbbellPress = lookup.lookup('Seated Dumbbell Shoulder Press');

      expect(barbellPress.status, equals(ExerciseLookupStatus.resolved));
      expect(dumbbellPress.status, equals(ExerciseLookupStatus.resolved));
      expect(
        barbellPress.canonicalUuid,
        isNot(equals(dumbbellPress.canonicalUuid)),
      );
    });

    test(
      '13. Unknown/custom exercises remain unresolved and preserve their original identity/name',
      () {
        const customName = 'My Custom Calisthenics Exercise 2026';
        final res = lookup.lookup(customName);

        expect(res.status, equals(ExerciseLookupStatus.unresolved));
        expect(res.canonicalUuid, isNull);
        expect(res.canonicalName, isNull);
        expect(res.originalName, equals(customName));
      },
    );

    test('14. Manifest-version validation', () {
      final invalidVersionJson = {
        'version': 99,
        'exercises': [
          {'name': 'Test Exercise'},
        ],
      };

      expect(
        () => ExerciseCatalogManifest.fromJson(invalidVersionJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('15. Malformed manifest rejection', () {
      final emptyNameJson = [
        {'name': '   '},
      ];

      expect(
        () => ExerciseCatalogManifest.fromJsonList(emptyNameJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('16. No fuzzy or substring resolution', () {
      final res1 = lookup.lookup('Bench');
      expect(res1.status, isNot(equals(ExerciseLookupStatus.resolved)));

      final res2 = lookup.lookup('Flat Barbell Bench');
      expect(res2.status, equals(ExerciseLookupStatus.unresolved));

      final res3 = lookup.lookup('Pressing');
      expect(res3.status, equals(ExerciseLookupStatus.unresolved));
    });
  });
}
