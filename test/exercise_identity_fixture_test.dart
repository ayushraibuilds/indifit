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

  group('B01-01 Exercise Identity Fixture Tests', () {
    test(
      '1. Every bundled catalogue exercise receives exactly one stable UUID',
      () {
        expect(manifest.totalEntries, equals(140));
        for (final entry in manifest.allEntries) {
          expect(entry.uuid, isNotNull);
          expect(entry.uuid.length, equals(36));
          expect(entry.name, isNotEmpty);
        }
      },
    );

    test('2. Repeated fixture loading produces identical mappings', () {
      final secondManifest = ExerciseCatalogManifest.loadFromAssetFileSync(
        'assets/data/exercises.json',
      );
      expect(secondManifest.totalEntries, equals(manifest.totalEntries));

      for (final entry in manifest.allEntries) {
        final secondEntry = secondManifest.getByNormalizedName(
          entry.normalizedName,
        );
        expect(secondEntry, isNotNull);
        expect(secondEntry!.uuid, equals(entry.uuid));
        expect(secondEntry.name, equals(entry.name));
      }
    });

    test('3. Canonical exercise UUIDs are unique', () {
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

    test('4. Canonical normalized names are unique where required', () {
      final nameSet = <String>{};
      for (final entry in manifest.allEntries) {
        expect(
          nameSet.contains(entry.normalizedName),
          isFalse,
          reason: 'Duplicate normalized name: ${entry.normalizedName}',
        );
        nameSet.add(entry.normalizedName);
      }
      expect(nameSet.length, equals(140));
    });

    test('5. Approved aliases resolve correctly', () {
      lookup.validateFixtures();

      final res1 = lookup.lookup('push-ups');
      expect(res1.status, equals(ExerciseLookupStatus.resolved));
      expect(res1.canonicalName, equals('Push-Ups'));
      expect(res1.canonicalUuid, isNotNull);

      final res2 = lookup.lookup('dumbbell shoulder press');
      expect(res2.status, equals(ExerciseLookupStatus.resolved));
      expect(res2.canonicalName, equals('Seated Dumbbell Shoulder Press'));

      final res3 = lookup.lookup('incline dumbbell press');
      expect(res3.status, equals(ExerciseLookupStatus.resolved));
      expect(res3.canonicalName, equals('Incline Dumbbell Bench Press'));
    });

    test('6. Alias collisions fail validation', () {
      // Create malformed list with duplicate normalized names
      final malformedJson = [
        {
          'name': 'Bench Press',
          'muscle_groups': 'Chest',
          'equipment': 'Barbell',
          'difficulty': 'Intermediate',
        },
        {
          'name': 'BENCH PRESS',
          'muscle_groups': 'Chest',
          'equipment': 'Barbell',
          'difficulty': 'Intermediate',
        },
      ];

      expect(
        () => ExerciseCatalogManifest.fromJsonList(malformedJson),
        throwsA(isA<StateError>()),
      );
    });

    test('7. Ambiguous names do not resolve', () {
      final res1 = lookup.lookup('leg curl machine');
      expect(res1.status, equals(ExerciseLookupStatus.ambiguous));
      expect(res1.canonicalUuid, isNull);

      final res2 = lookup.lookup('dumbbell bench press');
      expect(res2.status, equals(ExerciseLookupStatus.ambiguous));
      expect(res2.canonicalUuid, isNull);

      final res3 = lookup.lookup('squats');
      expect(res3.status, equals(ExerciseLookupStatus.ambiguous));
      expect(res3.canonicalUuid, isNull);
    });

    test(
      '8. Technique variants remain separate unless explicitly approved',
      () {
        final standard = lookup.lookup('Flat Barbell Bench Press (Standard)');
        final pause = lookup.lookup('Pause Flat Barbell Bench Press');
        final slow = lookup.lookup('Slow Eccentric Flat Barbell Bench Press');
        final base = lookup.lookup('Flat Barbell Bench Press');

        expect(standard.status, equals(ExerciseLookupStatus.resolved));
        expect(pause.status, equals(ExerciseLookupStatus.resolved));
        expect(slow.status, equals(ExerciseLookupStatus.resolved));
        expect(base.status, equals(ExerciseLookupStatus.resolved));

        // Assert that all 4 variants have distinct UUIDs
        final ids = {
          standard.canonicalUuid,
          pause.canonicalUuid,
          slow.canonicalUuid,
          base.canonicalUuid,
        };
        expect(ids.length, equals(4));
      },
    );

    test('9. Equipment variants remain separate where required', () {
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
      '10. Unknown custom exercise names remain unresolved and preserved',
      () {
        final customName = 'My Custom Overhead Cable Extensions 2026';
        final res = lookup.lookup(customName);

        expect(res.status, equals(ExerciseLookupStatus.unresolved));
        expect(res.canonicalUuid, isNull);
        expect(res.canonicalName, isNull);
        expect(res.originalName, equals(customName));
      },
    );

    test('11. No mapping relies on fuzzy or substring matching', () {
      // Substring searches like "Bench", "Press", "Curl" must NOT partially match catalog items
      final res1 = lookup.lookup('Bench');
      expect(res1.status, isNot(equals(ExerciseLookupStatus.resolved)));

      final res2 = lookup.lookup('Flat Barbell Bench');
      expect(res2.status, equals(ExerciseLookupStatus.unresolved));

      final res3 = lookup.lookup('Pressing');
      expect(res3.status, equals(ExerciseLookupStatus.unresolved));
    });

    test('15. Fixture parsing rejects malformed entries', () {
      final emptyNameJson = [
        {
          'name': '   ',
          'muscle_groups': 'Chest',
          'equipment': 'Barbell',
          'difficulty': 'Intermediate',
        },
      ];

      expect(
        () => ExerciseCatalogManifest.fromJsonList(emptyNameJson),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
