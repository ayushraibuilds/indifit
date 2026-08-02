import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b03_nutrition_fixture_matrix.dart';

void main() {
  group('B03-01 nutrition contract fixture matrix', () {
    test('current matrix is versioned, deterministic, and complete', () {
      final matrix = B03NutritionFixtureMatrix.current;

      matrix.validate();

      expect(matrix.version, kB03NutritionFixtureContractVersion);
      expect(matrix.contracts.fixtures, hasLength(29 * 3));
      expect(
        b03ContractReferences.map((reference) => reference.id).toSet(),
        hasLength(29),
      );
      expect(matrix.identities, hasLength(6));
      expect(matrix.quantities, hasLength(7));
      expect(matrix.nutrients, hasLength(6));
      expect(matrix.preparations, hasLength(3));
      expect(matrix.estimates, hasLength(3));
      expect(matrix.constraints, hasLength(8));
      expect(matrix.legacy, hasLength(4));
      expect(matrix.backups, hasLength(4));
    });

    test('fixture entry reordering does not alter contract identities', () {
      final json = B03ContractFixtureDocument.current.toJson();
      final fixtures = List<dynamic>.from(json['fixtures'] as List<dynamic>);
      json['fixtures'] = fixtures.reversed.toList();

      final reordered = B03ContractFixtureDocument.fromJson(json);
      final originalById = {
        for (final fixture in B03ContractFixtureDocument.current.fixtures)
          fixture.id: fixture.referenceId,
      };
      final reorderedById = {
        for (final fixture in reordered.fixtures)
          fixture.id: fixture.referenceId,
      };

      expect(reorderedById, equals(originalById));
    });

    test('unsupported contract versions fail before loading', () {
      final json = B03ContractFixtureDocument.current.toJson();
      json['version'] = 99;

      expect(
        () => B03ContractFixtureDocument.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('duplicate fixture IDs fail validation', () {
      final json = B03ContractFixtureDocument.current.toJson();
      final fixtures = List<Map<String, dynamic>>.from(
        (json['fixtures'] as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      fixtures[1]['id'] = fixtures[0]['id'];
      json['fixtures'] = fixtures;

      expect(
        () => B03ContractFixtureDocument.fromJson(json),
        throwsA(isA<StateError>()),
      );
    });

    test('unknown references fail validation', () {
      final json = B03ContractFixtureDocument.current.toJson();
      final fixtures = List<Map<String, dynamic>>.from(
        (json['fixtures'] as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      fixtures[0]['reference_id'] = 'B03-D99';
      json['fixtures'] = fixtures;

      expect(
        () => B03ContractFixtureDocument.fromJson(json),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'identity fixtures preserve canonical, alias, ambiguous, and unknown states',
      () {
        final identities = B03NutritionFixtureMatrix.current.identities;
        final canonical = identities.singleWhere(
          (item) =>
              item.status == B03FixtureIdentityStatus.canonical &&
              item.stableId == 'food-seed-0001',
        );
        final alias = identities.singleWhere(
          (item) => item.status == B03FixtureIdentityStatus.approvedAlias,
        );
        final ambiguous = identities.singleWhere(
          (item) => item.status == B03FixtureIdentityStatus.ambiguous,
        );
        final unresolved = identities.singleWhere(
          (item) => item.status == B03FixtureIdentityStatus.unresolved,
        );

        expect(canonical.stableId, isNotNull);
        expect(alias.stableId, canonical.stableId);
        expect(ambiguous.stableId, isNull);
        expect(unresolved.stableId, isNull);
        expect(unresolved.displayName, isNotEmpty);
      },
    );

    test(
      'duplicate canonical stable IDs fail while approved aliases may share one',
      () {
        final current = B03NutritionFixtureMatrix.current;
        final invalid = B03NutritionFixtureMatrix(
          version: current.version,
          contracts: current.contracts,
          identities: [
            ...current.identities,
            const B03IdentityFixture(
              id: 'identity-duplicate-canonical',
              displayName: 'Another canonical fixture',
              stableId: 'food-seed-0001',
              status: B03FixtureIdentityStatus.canonical,
              source: B03FixtureSource.bundled,
            ),
          ],
          quantities: current.quantities,
          nutrients: current.nutrients,
          preparations: current.preparations,
          estimates: current.estimates,
          constraints: current.constraints,
          legacy: current.legacy,
          backups: current.backups,
        );

        expect(invalid.validate, throwsA(isA<StateError>()));
      },
    );

    test(
      'quantity fixtures distinguish count, volume, serving, and unavailable conversion',
      () {
        final quantities = B03NutritionFixtureMatrix.current.quantities;
        final halfRoti = quantities.singleWhere(
          (item) => item.id == 'quantity-half-roti-count',
        );
        final milk = quantities.singleWhere(
          (item) => item.id == 'quantity-glass-milk-volume',
        );
        final katori = quantities.singleWhere(
          (item) => item.id == 'quantity-katori-rice-no-density',
        );
        final negative = quantities.singleWhere(
          (item) => item.id == 'quantity-invalid-negative',
        );

        expect(halfRoti.dimension, B03FixtureQuantityDimension.count);
        expect(halfRoti.value, 0.5);
        expect(milk.dimension, B03FixtureQuantityDimension.volume);
        expect(katori.availability, B03FixtureAvailability.unavailable);
        expect(negative.caseKind, B03FixtureCaseKind.invalid);
      },
    );

    test(
      'nutrient fixtures preserve missing, known-zero, estimated, and legacy states',
      () {
        final nutrients = B03NutritionFixtureMatrix.current.nutrients;
        final knownZero = nutrients.singleWhere(
          (item) => item.status == B03FixtureNutrientStatus.knownZero,
        );
        final missing = nutrients.singleWhere(
          (item) => item.status == B03FixtureNutrientStatus.missing,
        );
        final estimated = nutrients.singleWhere(
          (item) => item.status == B03FixtureNutrientStatus.estimated,
        );
        final legacy = nutrients.singleWhere(
          (item) => item.status == B03FixtureNutrientStatus.legacy,
        );

        expect(knownZero.point, 0);
        expect(missing.point, isNull);
        expect(estimated.lower, lessThan(estimated.point!));
        expect(estimated.upper, greaterThan(estimated.point!));
        expect(legacy.source, B03FixtureSource.legacy);
      },
    );

    test(
      'preparation fixtures keep reverse conversion unavailable without evidence',
      () {
        final reverse = B03NutritionFixtureMatrix.current.preparations
            .singleWhere(
              (item) => item.id == 'preparation-cooked-to-raw-unsupported',
            );

        expect(reverse.directional, isTrue);
        expect(reverse.reviewed, isFalse);
        expect(reverse.availability, B03FixtureAvailability.unavailable);
        expect(reverse.ruleVersion, isNull);
      },
    );

    test(
      'estimate fixtures preserve uncertainty, correction lineage, and image minimization',
      () {
        for (final estimate in B03NutritionFixtureMatrix.current.estimates) {
          expect(estimate.storesImage, isFalse);
          expect(estimate.correctionCreatesNewRecord, isTrue);
        }
        final offline = B03NutritionFixtureMatrix.current.estimates.singleWhere(
          (item) => item.id == 'estimate-offline-manual-unknown',
        );
        expect(offline.status, 'manual-or-unknown');
        expect(offline.hasBounds, isFalse);
      },
    );

    test(
      'all eight constraint types are represented with cautious outcomes',
      () {
        final constraints = B03NutritionFixtureMatrix.current.constraints;

        expect(
          constraints.map((item) => item.type).toSet(),
          containsAll(B03ConstraintType.values),
        );
        expect(
          constraints
              .singleWhere(
                (item) => item.id == 'constraint-intolerance-insufficient',
              )
              .expectedResult,
          B03ConstraintResult.insufficientInformation,
        );
        expect(
          constraints
              .singleWhere(
                (item) => item.id == 'constraint-religious-override-visible',
              )
              .userOverride,
          isTrue,
        );
      },
    );

    test(
      'legacy and backup fixtures preserve old meaning and fail future versions closed',
      () {
        final matrix = B03NutritionFixtureMatrix.current;
        final legacyLog = matrix.legacy.singleWhere(
          (item) => item.entity == 'FoodLogs',
        );
        final future = matrix.backups.singleWhere((item) => item.version == 8);

        expect(legacyLog.copiedValuesRemainAuthoritative, isTrue);
        expect(legacyLog.canonicalMappingProven, isFalse);
        expect(future.expectedImport, isFalse);
        expect(future.expectedZeroMutationOnFailure, isTrue);
      },
    );
  });
}
