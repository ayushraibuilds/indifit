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
      'decision evidence matrix is explicit and references accepted decisions',
      () {
        final referenceIds = b03ContractReferences
            .map((reference) => reference.id)
            .toSet();
        final testNames = b03DecisionEvidenceMatrix
            .map((evidence) => evidence.testName)
            .toList();

        expect(b03DecisionEvidenceMatrix, isNotEmpty);
        expect(testNames.toSet(), hasLength(testNames.length));
        for (final evidence in b03DecisionEvidenceMatrix) {
          expect(referenceIds, contains(evidence.decisionId));
          expect(evidence.fixtureScenario, isNotEmpty);
          expect(evidence.assertion, isNotEmpty);
          expect(evidence.expectedOutcome, isIn(['pass', 'reject', 'unknown']));
        }
      },
    );

    test('decision D01 identity stability and ambiguity', () {
      final identities = B03NutritionFixtureMatrix.current.identities;
      final canonical = identities.singleWhere(
        (item) => item.id == 'identity-canonical-roti',
      );
      final alias = identities.singleWhere(
        (item) => item.id == 'identity-approved-alias-fixture',
      );
      final ambiguous = identities.singleWhere(
        (item) => item.id == 'identity-regional-overlap-ambiguous',
      );
      final custom = identities.singleWhere(
        (item) => item.id == 'identity-custom-unresolved',
      );

      expect(alias.stableId, canonical.stableId);
      expect(ambiguous.status, B03FixtureIdentityStatus.ambiguous);
      expect(ambiguous.stableId, isNull);
      expect(custom.stableId, isNull);
    });

    test('decision D02 exact identity resolution', () {
      final identities = B03NutritionFixtureMatrix.current.identities;
      final explicitAlias = identities.singleWhere(
        (item) => item.alias == 'fixture-approved-roti-alias',
      );
      final generic = identities.singleWhere(
        (item) => item.id == 'identity-regional-overlap-ambiguous',
      );

      expect(explicitAlias.stableId, 'food-seed-0001');
      expect(generic.stableId, isNull);
    });

    test('decision D04 dimensional quantity safety', () {
      final quantities = B03NutritionFixtureMatrix.current.quantities;
      final milk = quantities.singleWhere(
        (item) => item.id == 'quantity-glass-milk-volume',
      );
      final rice = quantities.singleWhere(
        (item) => item.id == 'quantity-katori-rice-no-density',
      );
      final negative = quantities.singleWhere(
        (item) => item.id == 'quantity-invalid-negative',
      );

      expect(milk.dimension, B03FixtureQuantityDimension.volume);
      expect(rice.availability, B03FixtureAvailability.unavailable);
      expect(negative.caseKind, B03FixtureCaseKind.invalid);
    });

    test('decision D07 immutable history correction lineage', () {
      final fixture = b03ImmutableHistoryFixtures.singleWhere(
        (item) => item.id == 'b03-history-correction-001',
      );

      expect(fixture.originalSnapshotId, isNot(fixture.correctionSnapshotId));
      expect(fixture.originalRetained, isTrue);
      expect(fixture.effectiveSnapshotId, fixture.correctionSnapshotId);
      expect(fixture.originalAmount, isNot(fixture.correctedAmount));
    });

    test('decision D08 reviewed transformation provenance', () {
      final preparations = B03NutritionFixtureMatrix.current.preparations;
      final reviewed = preparations.singleWhere(
        (item) => item.id == 'preparation-raw-to-cooked-reviewed',
      );
      final unreviewed = preparations.singleWhere(
        (item) => item.id == 'preparation-cooked-to-raw-unsupported',
      );

      expect(reviewed.reviewed, isTrue);
      expect(reviewed.availability, isNot(B03FixtureAvailability.unavailable));
      expect(unreviewed.reviewed, isFalse);
      expect(unreviewed.availability, B03FixtureAvailability.unavailable);
      expect(unreviewed.ruleVersion, isNull);
    });

    test('decision D10 nutrient zero unknown and range states', () {
      final nutrients = B03NutritionFixtureMatrix.current.nutrients;
      final zero = nutrients.singleWhere(
        (item) => item.id == 'nutrient-known-zero-sodium',
      );
      final unknown = nutrients.singleWhere(
        (item) => item.id == 'nutrient-missing-fibre',
      );
      final range = nutrients.singleWhere(
        (item) => item.id == 'nutrient-estimated-protein-bounds',
      );

      expect(zero.point, 0);
      expect(zero.lower, 0);
      expect(zero.upper, 0);
      expect(unknown.point, isNull);
      expect(range.lower, lessThan(range.point!));
      expect(range.point, lessThan(range.upper!));
    });

    test('decision D11 estimate provenance separation', () {
      final estimates = B03NutritionFixtureMatrix.current.estimates;
      final ai = estimates.singleWhere(
        (item) => item.id == 'estimate-ai-range-no-image-retention',
      );
      final offline = estimates.singleWhere(
        (item) => item.id == 'estimate-offline-manual-unknown',
      );

      expect(ai.source, B03FixtureSource.ai);
      expect(ai.hasBounds, isTrue);
      expect(ai.storesImage, isFalse);
      expect(ai.correctionCreatesNewRecord, isTrue);
      expect(offline.status, 'manual-or-unknown');
      expect(offline.hasBounds, isFalse);
      expect(offline.storesImage, isFalse);
    });

    test('decision D18 no name-based durable resolution', () {
      final identities = B03NutritionFixtureMatrix.current.identities;
      expect(
        identities
            .singleWhere(
              (item) => item.id == 'identity-regional-overlap-ambiguous',
            )
            .stableId,
        isNull,
      );
      expect(
        identities
            .singleWhere((item) => item.id == 'identity-legacy-text-only')
            .stableId,
        isNull,
      );
    });

    test(
      'product default PD03 keeps legacy evidence separate from recipes',
      () {
        final legacy = B03NutritionFixtureMatrix.current.legacy.singleWhere(
          (item) => item.entity == 'MealTemplates',
        );

        expect(legacy.copiedValuesRemainAuthoritative, isTrue);
        expect(legacy.canonicalMappingProven, isFalse);
        expect(legacy.canonicalStableId, isNull);
      },
    );

    test('product default PD04 appends corrections', () {
      final fixture = b03ImmutableHistoryFixtures.single;
      expect(fixture.originalRetained, isTrue);
      expect(fixture.effectiveSnapshotId, fixture.correctionSnapshotId);
    });

    test('product default PD05 preserves stored local history context', () {
      final evidence = b03DecisionEvidenceMatrix.singleWhere(
        (item) => item.decisionId == 'B03-PD05',
      );

      expect(evidence.fixtureScenario, contains('frozen local date'));
      expect(evidence.assertion, contains('stored local date'));
    });

    test('product default PD07 keeps vessel calibration volume-only', () {
      final evidence = b03DecisionEvidenceMatrix.singleWhere(
        (item) => item.decisionId == 'B03-PD07',
      );

      expect(evidence.assertion, contains('volume only'));
      expect(evidence.assertion, contains('never food mass'));
    });

    test('product default PD08 keeps offline estimates non-exact', () {
      final offline = B03NutritionFixtureMatrix.current.estimates.singleWhere(
        (item) => item.id == 'estimate-offline-manual-unknown',
      );

      expect(offline.status, 'manual-or-unknown');
      expect(offline.hasBounds, isFalse);
    });

    test('decision D16 names one bounded-context owner', () {
      final evidence = b03DecisionEvidenceMatrix.singleWhere(
        (item) => item.decisionId == 'B03-D16',
      );

      expect(evidence.assertion, contains('one owner'));
      expect(evidence.expectedOutcome, 'pass');
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
