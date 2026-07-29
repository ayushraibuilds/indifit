import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/equipment_fixtures.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseCatalogManifest catalogManifest;

  setUp(() {
    catalogManifest = ExerciseCatalogManifest.loadFromAssetFileSync(
      'assets/data/exercises.json',
    );
  });

  group('B01-01 Equipment Fixture Tests', () {
    test('12. Canonical equipment identifiers are unique', () {
      final ids = <String>{};
      for (final item in CanonicalEquipmentItem.values) {
        expect(
          ids.contains(item.id),
          isFalse,
          reason: 'Duplicate equipment ID: ${item.id}',
        );
        ids.add(item.id);
      }
      expect(ids.length, equals(CanonicalEquipmentItem.values.length));
    });

    test('13. Equipment aliases cannot point to multiple items', () {
      EquipmentNormalizer.validateFixtures();

      for (final entry in EquipmentNormalizer.aliasMap.entries) {
        final res = EquipmentNormalizer.parseEquipmentString(entry.key);
        expect(res.status, equals(EquipmentLookupStatus.resolved));
        expect(res.canonicalItems.length, equals(1));
        expect(res.canonicalItems.first, equals(entry.value));
      }
    });

    test(
      '14. Every catalogue equipment value is mapped or explicitly marked unresolved',
      () {
        final catalogEquipments = <String>{};
        for (final entry in catalogManifest.allEntries) {
          catalogEquipments.add(entry.equipment);
        }

        // Catalog contains: "Barbell", "Dumbbells", "Machine", "Cables", "Bodyweight"
        for (final eqString in catalogEquipments) {
          final res = EquipmentNormalizer.parseEquipmentString(eqString);
          expect(
            res.status,
            equals(EquipmentLookupStatus.resolved),
            reason: 'Unmapped catalog equipment string: "$eqString"',
          );
          expect(res.canonicalItems, isNotEmpty);
        }
      },
    );

    test('Parses combined equipment strings correctly', () {
      final combined = EquipmentNormalizer.parseEquipmentString(
        'Barbell, Bench',
      );
      expect(combined.status, equals(EquipmentLookupStatus.resolved));
      expect(
        combined.canonicalItems,
        containsAll([
          CanonicalEquipmentItem.barbell,
          CanonicalEquipmentItem.bench,
        ]),
      );

      final combined2 = EquipmentNormalizer.parseEquipmentString(
        'Dumbbells / Cable',
      );
      expect(combined2.status, equals(EquipmentLookupStatus.resolved));
      expect(
        combined2.canonicalItems,
        containsAll([
          CanonicalEquipmentItem.dumbbell,
          CanonicalEquipmentItem.cable,
        ]),
      );
    });

    test('Preserves unresolved equipment strings without silent coercion', () {
      final unknown = EquipmentNormalizer.parseEquipmentString(
        'Anti-gravity Chamber',
      );
      expect(unknown.status, equals(EquipmentLookupStatus.unresolved));
      expect(unknown.canonicalItems, isEmpty);
      expect(unknown.originalString, equals('Anti-gravity Chamber'));
    });

    test('Parses legacy UserProfiles.equipmentAccess categories correctly', () {
      final fullGym = EquipmentNormalizer.parseLegacyCategory('full_gym');
      expect(fullGym.status, equals(EquipmentLookupStatus.resolved));
      expect(
        fullGym.canonicalItems,
        containsAll([
          CanonicalEquipmentItem.barbell,
          CanonicalEquipmentItem.dumbbell,
          CanonicalEquipmentItem.cable,
          CanonicalEquipmentItem.machine,
          CanonicalEquipmentItem.bodyweight,
          CanonicalEquipmentItem.bench,
          CanonicalEquipmentItem.rack,
        ]),
      );

      final dumbbells = EquipmentNormalizer.parseLegacyCategory('dumbbells');
      expect(dumbbells.status, equals(EquipmentLookupStatus.resolved));
      expect(
        dumbbells.canonicalItems,
        containsAll([
          CanonicalEquipmentItem.dumbbell,
          CanonicalEquipmentItem.bodyweight,
          CanonicalEquipmentItem.bench,
        ]),
      );

      final bodyweight = EquipmentNormalizer.parseLegacyCategory('bodyweight');
      expect(bodyweight.status, equals(EquipmentLookupStatus.resolved));
      expect(
        bodyweight.canonicalItems,
        equals([CanonicalEquipmentItem.bodyweight]),
      );

      final unknownCategory = EquipmentNormalizer.parseLegacyCategory(
        'space_station',
      );
      expect(unknownCategory.status, equals(EquipmentLookupStatus.unresolved));
      expect(unknownCategory.canonicalItems, isEmpty);
    });
  });
}
