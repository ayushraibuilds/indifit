import 'dart:convert';
import 'dart:io';

/// Version of the B03 contract/fixture vocabulary.
///
/// This file is intentionally a fixture contract, not a nutrition domain
/// model. Later B03 tasks may consume these cases, but B03-01 does not add
/// persistence, calculation, identity resolution, or UI behavior.
const int kB03NutritionFixtureContractVersion = 1;

/// Version of the read-only catalogue audit shape.
const int kB03NutritionManifestAuditVersion = 1;

const String kB03NutritionManifestPath =
    'assets/data/nutrition_food_identity_manifest.json';

enum B03FixtureCaseKind { valid, invalid, unknown }

enum B03FixtureSource {
  bundled,
  regional,
  manufacturer,
  user,
  import,
  recipe,
  ai,
  photo,
  heuristic,
  legacy,
}

enum B03FixtureIdentityStatus {
  canonical,
  approvedAlias,
  ambiguous,
  unresolved,
  legacy,
}

enum B03FixtureQuantityDimension {
  mass,
  volume,
  count,
  serving,
  household,
  edibleFraction,
}

enum B03FixtureAvailability { exact, approximate, unavailable }

enum B03FixtureNutrientStatus {
  known,
  knownZero,
  missing,
  notApplicable,
  estimated,
  legacy,
}

enum B03ConstraintType {
  allergy,
  intolerance,
  religiousRestriction,
  ethicalPreference,
  dietaryPattern,
  tasteDislike,
  temporaryAvoidance,
  regionalPreference,
}

enum B03ConstraintResult {
  confirmedConflict,
  possibleConflict,
  noKnownConflict,
  insufficientInformation,
}

/// A single decision/default-to-fixture traceability row.
class B03ContractReference {
  final String id;
  final String description;
  final List<String> downstreamTasks;

  const B03ContractReference({
    required this.id,
    required this.description,
    required this.downstreamTasks,
  });
}

/// A deterministic valid/invalid/unknown case for one accepted contract.
class B03ContractFixture {
  final String id;
  final String referenceId;
  final B03FixtureCaseKind kind;
  final String expectedOutcome;
  final List<String> downstreamTasks;

  const B03ContractFixture({
    required this.id,
    required this.referenceId,
    required this.kind,
    required this.expectedOutcome,
    required this.downstreamTasks,
  });

  factory B03ContractFixture.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final referenceId = json['reference_id'];
    final kind = json['case'];
    final expectedOutcome = json['expected'];
    final rawTasks = json['downstream_tasks'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('B03 fixture ID must be a non-empty string.');
    }
    if (referenceId is! String || referenceId.trim().isEmpty) {
      throw const FormatException(
        'B03 fixture reference_id must be a non-empty string.',
      );
    }
    if (kind is! String) {
      throw const FormatException('B03 fixture case must be a string.');
    }
    if (expectedOutcome is! String || expectedOutcome.trim().isEmpty) {
      throw const FormatException(
        'B03 fixture expected outcome must be a non-empty string.',
      );
    }
    if (rawTasks is! List ||
        rawTasks.any((item) => item is! String || item.trim().isEmpty)) {
      throw const FormatException(
        'B03 fixture downstream_tasks must contain non-empty strings.',
      );
    }

    final parsedKind = switch (kind) {
      'valid' => B03FixtureCaseKind.valid,
      'invalid' => B03FixtureCaseKind.invalid,
      'unknown' => B03FixtureCaseKind.unknown,
      _ => throw FormatException('Unknown B03 fixture case: $kind'),
    };

    return B03ContractFixture(
      id: id,
      referenceId: referenceId,
      kind: parsedKind,
      expectedOutcome: expectedOutcome,
      downstreamTasks: List.unmodifiable(rawTasks.cast<String>()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference_id': referenceId,
    'case': kind.name,
    'expected': expectedOutcome,
    'downstream_tasks': downstreamTasks,
  };
}

/// Versioned, independently loadable contract-fixture document.
class B03ContractFixtureDocument {
  final int version;
  final List<B03ContractFixture> fixtures;

  const B03ContractFixtureDocument({
    required this.version,
    required this.fixtures,
  });

  static final current = B03ContractFixtureDocument(
    version: kB03NutritionFixtureContractVersion,
    fixtures: [
      for (final reference in b03ContractReferences)
        for (final kind in B03FixtureCaseKind.values)
          B03ContractFixture(
            id: '${reference.id.toLowerCase()}-${kind.name}',
            referenceId: reference.id,
            kind: kind,
            expectedOutcome: switch (kind) {
              B03FixtureCaseKind.valid => 'accepted-contract-shape',
              B03FixtureCaseKind.invalid => 'reject-before-mutation',
              B03FixtureCaseKind.unknown => 'preserve-unknown-or-unresolved',
            },
            downstreamTasks: reference.downstreamTasks,
          ),
    ],
  );

  factory B03ContractFixtureDocument.fromJson(dynamic payload) {
    if (payload is! Map) {
      throw const FormatException('B03 fixture document must be an object.');
    }
    final json = Map<String, dynamic>.from(payload);
    final version = json['version'];
    final rawFixtures = json['fixtures'];
    if (version is! int) {
      throw const FormatException('B03 fixture document version is required.');
    }
    if (version != kB03NutritionFixtureContractVersion) {
      throw FormatException(
        'Unsupported B03 fixture contract version: $version. '
        'Expected $kB03NutritionFixtureContractVersion.',
      );
    }
    if (rawFixtures is! List) {
      throw const FormatException(
        'B03 fixture document fixtures must be a list.',
      );
    }

    // Build locally and validate before returning so malformed input can never
    // expose a partially loaded fixture document.
    final fixtures = <B03ContractFixture>[];
    for (final item in rawFixtures) {
      if (item is! Map) {
        throw const FormatException('B03 fixture entry must be an object.');
      }
      fixtures.add(
        B03ContractFixture.fromJson(Map<String, dynamic>.from(item)),
      );
    }
    final document = B03ContractFixtureDocument(
      version: version,
      fixtures: List.unmodifiable(fixtures),
    );
    document.validate();
    return document;
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'fixtures': fixtures.map((fixture) => fixture.toJson()).toList(),
  };

  void validate() {
    if (version != kB03NutritionFixtureContractVersion) {
      throw StateError('Unsupported B03 fixture contract version: $version.');
    }
    _validateUniqueIds('contract fixture', fixtures.map((item) => item.id));

    final referencesById = {
      for (final reference in b03ContractReferences) reference.id: reference,
    };
    final knownTasks = b03KnownTaskIds;
    final coverage = <String, Set<B03FixtureCaseKind>>{};
    for (final fixture in fixtures) {
      final reference = referencesById[fixture.referenceId];
      if (reference == null) {
        throw StateError(
          'Fixture ${fixture.id} references unknown contract ${fixture.referenceId}.',
        );
      }
      if (fixture.expectedOutcome.trim().isEmpty ||
          fixture.downstreamTasks.isEmpty ||
          fixture.downstreamTasks.any((task) => !knownTasks.contains(task))) {
        throw StateError('Fixture ${fixture.id} has malformed traceability.');
      }
      if (!const {
        B03FixtureCaseKind.valid,
        B03FixtureCaseKind.invalid,
        B03FixtureCaseKind.unknown,
      }.contains(fixture.kind)) {
        throw StateError('Fixture ${fixture.id} has an invalid case kind.');
      }
      final kinds = coverage.putIfAbsent(
        fixture.referenceId,
        () => <B03FixtureCaseKind>{},
      );
      if (!kinds.add(fixture.kind)) {
        throw StateError(
          'Duplicate ${fixture.kind.name} case for ${fixture.referenceId}.',
        );
      }
      if (!fixture.downstreamTasks.toSet().containsAll(
        reference.downstreamTasks,
      )) {
        throw StateError(
          'Fixture ${fixture.id} omits a downstream task from ${reference.id}.',
        );
      }
    }
    for (final reference in b03ContractReferences) {
      final kinds = coverage[reference.id];
      if (kinds == null || !kinds.containsAll(B03FixtureCaseKind.values)) {
        throw StateError(
          'Incomplete valid/invalid/unknown coverage for ${reference.id}.',
        );
      }
    }
  }
}

/// The accepted B03 decisions and product defaults that must remain linked to
/// executable fixture cases.
const List<B03ContractReference> b03ContractReferences = [
  B03ContractReference(
    id: 'B03-D01',
    description:
        'Portable food/preparation identity is separate from recipes and logs.',
    downstreamTasks: ['B03-01', 'B03-03', 'B03-06A', 'B03-06B', 'B03-11A'],
  ),
  B03ContractReference(
    id: 'B03-D02',
    description: 'Exact narrow normalization with explicit ambiguity.',
    downstreamTasks: ['B03-01', 'B03-03'],
  ),
  B03ContractReference(
    id: 'B03-D03',
    description: 'Legacy rows remain readable without speculative mapping.',
    downstreamTasks: ['B03-01', 'B03-02', 'B03-06A', 'B03-11B'],
  ),
  B03ContractReference(
    id: 'B03-D04',
    description: 'Mass, volume, and count are canonical dimensions.',
    downstreamTasks: ['B03-01', 'B03-04', 'B03-05', 'B03-08'],
  ),
  B03ContractReference(
    id: 'B03-D05',
    description: 'Conversions are scoped, bounded, and provenance-bearing.',
    downstreamTasks: ['B03-01', 'B03-04', 'B03-05'],
  ),
  B03ContractReference(
    id: 'B03-D06',
    description:
        'Direct-food recipes use immutable versions; nested recipes defer.',
    downstreamTasks: ['B03-01', 'B03-07', 'B03-08'],
  ),
  B03ContractReference(
    id: 'B03-D07',
    description: 'Hybrid immutable snapshots are the historical authority.',
    downstreamTasks: ['B03-01', 'B03-11A', 'B03-11B'],
  ),
  B03ContractReference(
    id: 'B03-D08',
    description: 'Raw/cooked transformations are reviewed and directional.',
    downstreamTasks: ['B03-01', 'B03-09'],
  ),
  B03ContractReference(
    id: 'B03-D09',
    description: 'Household labels are contextual; vessels are volume-only.',
    downstreamTasks: ['B03-01', 'B03-10'],
  ),
  B03ContractReference(
    id: 'B03-D10',
    description: 'Nutrients carry typed status, basis, source, and bounds.',
    downstreamTasks: ['B03-01', 'B03-05', 'B03-08'],
  ),
  B03ContractReference(
    id: 'B03-D11',
    description:
        'Estimates retain per-nutrient uncertainty and correction lineage.',
    downstreamTasks: ['B03-01', 'B03-14'],
  ),
  B03ContractReference(
    id: 'B03-D12',
    description: 'Thalis use ordered composition and the shared calculator.',
    downstreamTasks: ['B03-01', 'B03-13'],
  ),
  B03ContractReference(
    id: 'B03-D13',
    description:
        'Protein distribution is descriptive; leucine is source-aware.',
    downstreamTasks: ['B03-01', 'B03-15'],
  ),
  B03ContractReference(
    id: 'B03-D14',
    description: 'Constraints use typed evidence and four cautious states.',
    downstreamTasks: ['B03-01', 'B03-16'],
  ),
  B03ContractReference(
    id: 'B03-D15',
    description:
        'v17/v8 migration and restore are transactional and legacy-preserving.',
    downstreamTasks: ['B03-01', 'B03-02', 'B03-06A', 'B03-06B'],
  ),
  B03ContractReference(
    id: 'B03-D16',
    description: 'Each bounded context has one owner and calculation path.',
    downstreamTasks: ['B03-01', 'B03-08', 'B03-13'],
  ),
  B03ContractReference(
    id: 'B03-D17',
    description:
        'Unknown, approximate, offline, correction, and error are first-class.',
    downstreamTasks: ['B03-01', 'B03-14', 'B03-17'],
  ),
  B03ContractReference(
    id: 'B03-D18',
    description: 'A reviewed versioned food-identity manifest is mandatory.',
    downstreamTasks: ['B03-01', 'B03-03'],
  ),
  B03ContractReference(
    id: 'B03-D19',
    description:
        'AI/photo privacy is minimized and offline fallback is manual/unknown.',
    downstreamTasks: ['B03-01', 'B03-14'],
  ),
  B03ContractReference(
    id: 'B03-PD01',
    description:
        'Seed and regional rows remain distinct until manifest review.',
    downstreamTasks: ['B03-01', 'B03-03'],
  ),
  B03ContractReference(
    id: 'B03-PD02',
    description:
        'Portion vocabulary is typed; unsupported conversion is visible.',
    downstreamTasks: ['B03-01', 'B03-04'],
  ),
  B03ContractReference(
    id: 'B03-PD03',
    description:
        'Meal templates remain legacy snapshots; recipes are separate.',
    downstreamTasks: ['B03-01', 'B03-02', 'B03-07', 'B03-11B'],
  ),
  B03ContractReference(
    id: 'B03-PD04',
    description: 'Corrections append lineage; referenced objects archive.',
    downstreamTasks: ['B03-01', 'B03-06B', 'B03-11A', 'B03-14'],
  ),
  B03ContractReference(
    id: 'B03-PD05',
    description: 'Meal boundaries use explicit groups and frozen local time.',
    downstreamTasks: ['B03-01', 'B03-11A', 'B03-15'],
  ),
  B03ContractReference(
    id: 'B03-PD06',
    description: 'Thali is free-form ordered composition.',
    downstreamTasks: ['B03-01', 'B03-13'],
  ),
  B03ContractReference(
    id: 'B03-PD07',
    description: 'Vessel calibration is volume-only.',
    downstreamTasks: ['B03-01', 'B03-10'],
  ),
  B03ContractReference(
    id: 'B03-PD08',
    description: 'Offline estimates are manual/unknown, not fixed mock points.',
    downstreamTasks: ['B03-01', 'B03-14'],
  ),
  B03ContractReference(
    id: 'B03-PD09',
    description: 'Protein/leucine output is descriptive and source-aware.',
    downstreamTasks: ['B03-01', 'B03-15'],
  ),
  B03ContractReference(
    id: 'B03-PD10',
    description:
        'User aliases are identity-only; unrestricted safety rules are deferred.',
    downstreamTasks: ['B03-01', 'B03-03', 'B03-16'],
  ),
];

const Set<String> b03KnownTaskIds = {
  'B03-01',
  'B03-02',
  'B03-03',
  'B03-04',
  'B03-05',
  'B03-06A',
  'B03-06B',
  'B03-07',
  'B03-08',
  'B03-09',
  'B03-10',
  'B03-11A',
  'B03-11B',
  'B03-12',
  'B03-13',
  'B03-14',
  'B03-15',
  'B03-16',
  'B03-17',
  'B03-18',
};

class B03IdentityFixture {
  final String id;
  final String displayName;
  final String? stableId;
  final B03FixtureIdentityStatus status;
  final B03FixtureSource source;
  final String? alias;
  final String? sourceRef;
  final String? providerNamespace;
  final String? externalId;

  const B03IdentityFixture({
    required this.id,
    required this.displayName,
    required this.stableId,
    required this.status,
    required this.source,
    this.alias,
    this.sourceRef,
    this.providerNamespace,
    this.externalId,
  });
}

class B03QuantityFixture {
  final String id;
  final B03FixtureCaseKind caseKind;
  final double value;
  final B03FixtureQuantityDimension dimension;
  final String unit;
  final B03FixtureAvailability availability;
  final B03FixtureSource source;

  const B03QuantityFixture({
    required this.id,
    required this.caseKind,
    required this.value,
    required this.dimension,
    required this.unit,
    required this.availability,
    required this.source,
  });
}

class B03NutrientFixture {
  final String id;
  final String nutrientKey;
  final B03FixtureNutrientStatus status;
  final double? point;
  final double? lower;
  final double? upper;
  final String basis;
  final B03FixtureSource source;

  const B03NutrientFixture({
    required this.id,
    required this.nutrientKey,
    required this.status,
    required this.point,
    required this.lower,
    required this.upper,
    required this.basis,
    required this.source,
  });
}

class B03PreparationFixture {
  final String id;
  final String sourceState;
  final String targetState;
  final String method;
  final B03FixtureAvailability availability;
  final bool directional;
  final bool reviewed;
  final String? ruleVersion;

  const B03PreparationFixture({
    required this.id,
    required this.sourceState,
    required this.targetState,
    required this.method,
    required this.availability,
    required this.directional,
    required this.reviewed,
    required this.ruleVersion,
  });
}

class B03EstimateFixture {
  final String id;
  final B03FixtureSource source;
  final bool hasBounds;
  final bool storesImage;
  final bool correctionCreatesNewRecord;
  final String confidence;
  final String status;

  const B03EstimateFixture({
    required this.id,
    required this.source,
    required this.hasBounds,
    required this.storesImage,
    required this.correctionCreatesNewRecord,
    required this.confidence,
    required this.status,
  });
}

class B03ConstraintFixture {
  final String id;
  final B03ConstraintType type;
  final bool compositionKnown;
  final B03ConstraintResult expectedResult;
  final bool userOverride;
  final String? evidenceRef;

  const B03ConstraintFixture({
    required this.id,
    required this.type,
    required this.compositionKnown,
    required this.expectedResult,
    required this.userOverride,
    required this.evidenceRef,
  });
}

class B03LegacyFixture {
  final String id;
  final String entity;
  final int sourceVersion;
  final String originalText;
  final bool copiedValuesRemainAuthoritative;
  final bool canonicalMappingProven;
  final String? canonicalStableId;

  const B03LegacyFixture({
    required this.id,
    required this.entity,
    required this.sourceVersion,
    required this.originalText,
    required this.copiedValuesRemainAuthoritative,
    required this.canonicalMappingProven,
    required this.canonicalStableId,
  });
}

class B03BackupFixture {
  final String id;
  final int version;
  final bool expectedImport;
  final bool preservesUnknown;
  final bool expectedZeroMutationOnFailure;

  const B03BackupFixture({
    required this.id,
    required this.version,
    required this.expectedImport,
    required this.preservesUnknown,
    required this.expectedZeroMutationOnFailure,
  });
}

/// Immutable B03-01 fixture matrix used by contract and audit tests.
class B03NutritionFixtureMatrix {
  final int version;
  final B03ContractFixtureDocument contracts;
  final List<B03IdentityFixture> identities;
  final List<B03QuantityFixture> quantities;
  final List<B03NutrientFixture> nutrients;
  final List<B03PreparationFixture> preparations;
  final List<B03EstimateFixture> estimates;
  final List<B03ConstraintFixture> constraints;
  final List<B03LegacyFixture> legacy;
  final List<B03BackupFixture> backups;

  const B03NutritionFixtureMatrix({
    required this.version,
    required this.contracts,
    required this.identities,
    required this.quantities,
    required this.nutrients,
    required this.preparations,
    required this.estimates,
    required this.constraints,
    required this.legacy,
    required this.backups,
  });

  static final current = B03NutritionFixtureMatrix(
    version: kB03NutritionFixtureContractVersion,
    contracts: B03ContractFixtureDocument.current,
    identities: const [
      B03IdentityFixture(
        id: 'identity-approved-alias-fixture',
        displayName: 'fixture-approved-roti-alias',
        stableId: 'food-seed-0001',
        status: B03FixtureIdentityStatus.approvedAlias,
        source: B03FixtureSource.bundled,
        alias: 'fixture-approved-roti-alias',
        sourceRef: 'fixture-only; not a catalogue alias',
      ),
      B03IdentityFixture(
        id: 'identity-canonical-roti',
        displayName: 'Whole Wheat Roti / Chapati',
        stableId: 'food-seed-0001',
        status: B03FixtureIdentityStatus.canonical,
        source: B03FixtureSource.bundled,
        sourceRef: 'assets/data/indian_foods.json#0',
      ),
      B03IdentityFixture(
        id: 'identity-custom-unresolved',
        displayName: 'My custom family recipe',
        stableId: null,
        status: B03FixtureIdentityStatus.unresolved,
        source: B03FixtureSource.user,
        sourceRef: 'user-input',
      ),
      B03IdentityFixture(
        id: 'identity-imported-provider',
        displayName: 'Imported product fixture',
        stableId: 'food-import-0001',
        status: B03FixtureIdentityStatus.canonical,
        source: B03FixtureSource.import,
        sourceRef: 'provider-import-fixture',
        providerNamespace: 'fixture-provider',
        externalId: 'fixture-product-0001',
      ),
      B03IdentityFixture(
        id: 'identity-legacy-text-only',
        displayName: 'Legacy copied food text',
        stableId: null,
        status: B03FixtureIdentityStatus.legacy,
        source: B03FixtureSource.legacy,
        sourceRef: 'FoodLogs#legacy-001',
      ),
      B03IdentityFixture(
        id: 'identity-regional-overlap-ambiguous',
        displayName: 'Dal Makhani',
        stableId: null,
        status: B03FixtureIdentityStatus.ambiguous,
        source: B03FixtureSource.regional,
        sourceRef: 'assets/data/regional/punjabi.json#1',
      ),
    ],
    quantities: const [
      B03QuantityFixture(
        id: 'quantity-banana-count-range',
        caseKind: B03FixtureCaseKind.valid,
        value: 1,
        dimension: B03FixtureQuantityDimension.count,
        unit: 'count',
        availability: B03FixtureAvailability.approximate,
        source: B03FixtureSource.bundled,
      ),
      B03QuantityFixture(
        id: 'quantity-glass-milk-volume',
        caseKind: B03FixtureCaseKind.valid,
        value: 240,
        dimension: B03FixtureQuantityDimension.volume,
        unit: 'ml',
        availability: B03FixtureAvailability.exact,
        source: B03FixtureSource.bundled,
      ),
      B03QuantityFixture(
        id: 'quantity-half-roti-count',
        caseKind: B03FixtureCaseKind.valid,
        value: 0.5,
        dimension: B03FixtureQuantityDimension.count,
        unit: 'count',
        availability: B03FixtureAvailability.exact,
        source: B03FixtureSource.user,
      ),
      B03QuantityFixture(
        id: 'quantity-invalid-negative',
        caseKind: B03FixtureCaseKind.invalid,
        value: -1,
        dimension: B03FixtureQuantityDimension.mass,
        unit: 'g',
        availability: B03FixtureAvailability.unavailable,
        source: B03FixtureSource.user,
      ),
      B03QuantityFixture(
        id: 'quantity-katori-rice-no-density',
        caseKind: B03FixtureCaseKind.unknown,
        value: 1,
        dimension: B03FixtureQuantityDimension.household,
        unit: 'katori',
        availability: B03FixtureAvailability.unavailable,
        source: B03FixtureSource.bundled,
      ),
      B03QuantityFixture(
        id: 'quantity-manufacturer-serving',
        caseKind: B03FixtureCaseKind.valid,
        value: 1,
        dimension: B03FixtureQuantityDimension.serving,
        unit: 'serving',
        availability: B03FixtureAvailability.exact,
        source: B03FixtureSource.manufacturer,
      ),
      B03QuantityFixture(
        id: 'quantity-unknown-household-conversion',
        caseKind: B03FixtureCaseKind.unknown,
        value: 1,
        dimension: B03FixtureQuantityDimension.household,
        unit: 'unknown-measure',
        availability: B03FixtureAvailability.unavailable,
        source: B03FixtureSource.user,
      ),
    ],
    nutrients: const [
      B03NutrientFixture(
        id: 'nutrient-known-energy',
        nutrientKey: 'energy',
        status: B03FixtureNutrientStatus.known,
        point: 100,
        lower: null,
        upper: null,
        basis: 'fixture-basis',
        source: B03FixtureSource.bundled,
      ),
      B03NutrientFixture(
        id: 'nutrient-known-zero-sodium',
        nutrientKey: 'sodium',
        status: B03FixtureNutrientStatus.knownZero,
        point: 0,
        lower: 0,
        upper: 0,
        basis: 'fixture-basis',
        source: B03FixtureSource.manufacturer,
      ),
      B03NutrientFixture(
        id: 'nutrient-missing-fibre',
        nutrientKey: 'fibre',
        status: B03FixtureNutrientStatus.missing,
        point: null,
        lower: null,
        upper: null,
        basis: 'fixture-basis',
        source: B03FixtureSource.import,
      ),
      B03NutrientFixture(
        id: 'nutrient-estimated-protein-bounds',
        nutrientKey: 'protein',
        status: B03FixtureNutrientStatus.estimated,
        point: 10,
        lower: 8,
        upper: 12,
        basis: 'fixture-basis',
        source: B03FixtureSource.ai,
      ),
      B03NutrientFixture(
        id: 'nutrient-not-applicable-leucine',
        nutrientKey: 'leucine',
        status: B03FixtureNutrientStatus.notApplicable,
        point: null,
        lower: null,
        upper: null,
        basis: 'fixture-basis',
        source: B03FixtureSource.bundled,
      ),
      B03NutrientFixture(
        id: 'nutrient-legacy-copied-macro',
        nutrientKey: 'legacy-macro',
        status: B03FixtureNutrientStatus.legacy,
        point: 42,
        lower: null,
        upper: null,
        basis: 'legacy-copied-value',
        source: B03FixtureSource.legacy,
      ),
    ],
    preparations: const [
      B03PreparationFixture(
        id: 'preparation-raw-to-cooked-reviewed',
        sourceState: 'raw',
        targetState: 'cooked',
        method: 'reviewed-fixture-method',
        availability: B03FixtureAvailability.approximate,
        directional: true,
        reviewed: true,
        ruleVersion: 'fixture-rule-v1',
      ),
      B03PreparationFixture(
        id: 'preparation-cooked-to-raw-unsupported',
        sourceState: 'cooked',
        targetState: 'raw',
        method: 'reverse-not-reviewed',
        availability: B03FixtureAvailability.unavailable,
        directional: true,
        reviewed: false,
        ruleVersion: null,
      ),
      B03PreparationFixture(
        id: 'preparation-unknown-oil-context',
        sourceState: 'prepared',
        targetState: 'prepared',
        method: 'oil-context-unknown',
        availability: B03FixtureAvailability.unavailable,
        directional: false,
        reviewed: false,
        ruleVersion: null,
      ),
    ],
    estimates: const [
      B03EstimateFixture(
        id: 'estimate-ai-range-no-image-retention',
        source: B03FixtureSource.ai,
        hasBounds: true,
        storesImage: false,
        correctionCreatesNewRecord: true,
        confidence: 'medium',
        status: 'estimated',
      ),
      B03EstimateFixture(
        id: 'estimate-offline-manual-unknown',
        source: B03FixtureSource.user,
        hasBounds: false,
        storesImage: false,
        correctionCreatesNewRecord: true,
        confidence: 'unknown',
        status: 'manual-or-unknown',
      ),
      B03EstimateFixture(
        id: 'estimate-unsupported-model-opaque',
        source: B03FixtureSource.ai,
        hasBounds: true,
        storesImage: false,
        correctionCreatesNewRecord: true,
        confidence: 'unknown',
        status: 'unsupported-opaque-no-execution',
      ),
    ],
    constraints: const [
      B03ConstraintFixture(
        id: 'constraint-allergy-confirmed',
        type: B03ConstraintType.allergy,
        compositionKnown: true,
        expectedResult: B03ConstraintResult.confirmedConflict,
        userOverride: false,
        evidenceRef: 'evidence-fixture-confirmed',
      ),
      B03ConstraintFixture(
        id: 'constraint-dietary-pattern-possible',
        type: B03ConstraintType.dietaryPattern,
        compositionKnown: true,
        expectedResult: B03ConstraintResult.possibleConflict,
        userOverride: false,
        evidenceRef: 'evidence-fixture-possible',
      ),
      B03ConstraintFixture(
        id: 'constraint-ethical-no-known',
        type: B03ConstraintType.ethicalPreference,
        compositionKnown: true,
        expectedResult: B03ConstraintResult.noKnownConflict,
        userOverride: false,
        evidenceRef: 'evidence-fixture-reviewed',
      ),
      B03ConstraintFixture(
        id: 'constraint-intolerance-insufficient',
        type: B03ConstraintType.intolerance,
        compositionKnown: false,
        expectedResult: B03ConstraintResult.insufficientInformation,
        userOverride: false,
        evidenceRef: null,
      ),
      B03ConstraintFixture(
        id: 'constraint-religious-override-visible',
        type: B03ConstraintType.religiousRestriction,
        compositionKnown: false,
        expectedResult: B03ConstraintResult.insufficientInformation,
        userOverride: true,
        evidenceRef: null,
      ),
      B03ConstraintFixture(
        id: 'constraint-taste-dislike',
        type: B03ConstraintType.tasteDislike,
        compositionKnown: true,
        expectedResult: B03ConstraintResult.confirmedConflict,
        userOverride: false,
        evidenceRef: 'evidence-fixture-dislike',
      ),
      B03ConstraintFixture(
        id: 'constraint-temporary-avoidance',
        type: B03ConstraintType.temporaryAvoidance,
        compositionKnown: true,
        expectedResult: B03ConstraintResult.possibleConflict,
        userOverride: false,
        evidenceRef: 'evidence-fixture-temporary',
      ),
      B03ConstraintFixture(
        id: 'constraint-regional-preference',
        type: B03ConstraintType.regionalPreference,
        compositionKnown: true,
        expectedResult: B03ConstraintResult.noKnownConflict,
        userOverride: false,
        evidenceRef: 'evidence-fixture-region',
      ),
    ],
    legacy: const [
      B03LegacyFixture(
        id: 'legacy-food-log-copied-value',
        entity: 'FoodLogs',
        sourceVersion: 16,
        originalText: 'Legacy copied food text',
        copiedValuesRemainAuthoritative: true,
        canonicalMappingProven: false,
        canonicalStableId: null,
      ),
      B03LegacyFixture(
        id: 'legacy-meal-template-name-only',
        entity: 'MealTemplates',
        sourceVersion: 16,
        originalText: 'Legacy named meal template',
        copiedValuesRemainAuthoritative: true,
        canonicalMappingProven: false,
        canonicalStableId: null,
      ),
      B03LegacyFixture(
        id: 'legacy-custom-food-provenance',
        entity: 'FoodItems',
        sourceVersion: 16,
        originalText: 'User custom food',
        copiedValuesRemainAuthoritative: true,
        canonicalMappingProven: true,
        canonicalStableId: 'food-user-0001',
      ),
      B03LegacyFixture(
        id: 'legacy-v7-backup-unknown',
        entity: 'Backup',
        sourceVersion: 7,
        originalText: 'Unknown legacy nutrition value',
        copiedValuesRemainAuthoritative: true,
        canonicalMappingProven: false,
        canonicalStableId: null,
      ),
    ],
    backups: const [
      B03BackupFixture(
        id: 'backup-v05-b03-sections-absent',
        version: 5,
        expectedImport: true,
        preservesUnknown: true,
        expectedZeroMutationOnFailure: true,
      ),
      B03BackupFixture(
        id: 'backup-v06-b03-sections-absent',
        version: 6,
        expectedImport: true,
        preservesUnknown: true,
        expectedZeroMutationOnFailure: true,
      ),
      B03BackupFixture(
        id: 'backup-v07-b03-sections-absent',
        version: 7,
        expectedImport: true,
        preservesUnknown: true,
        expectedZeroMutationOnFailure: true,
      ),
      B03BackupFixture(
        id: 'backup-v08-future-reject-before-mutation',
        version: 8,
        expectedImport: false,
        preservesUnknown: true,
        expectedZeroMutationOnFailure: true,
      ),
    ],
  );

  void validate() {
    if (version != kB03NutritionFixtureContractVersion) {
      throw StateError('Unsupported B03 fixture matrix version: $version.');
    }
    contracts.validate();
    _validateUniqueIds('identity', identities.map((item) => item.id));
    _validateUniqueIds('quantity', quantities.map((item) => item.id));
    _validateUniqueIds('nutrient', nutrients.map((item) => item.id));
    _validateUniqueIds('preparation', preparations.map((item) => item.id));
    _validateUniqueIds('estimate', estimates.map((item) => item.id));
    _validateUniqueIds('constraint', constraints.map((item) => item.id));
    _validateUniqueIds('legacy', legacy.map((item) => item.id));
    _validateUniqueIds('backup', backups.map((item) => item.id));

    _validateIdentities();
    _validateQuantities();
    _validateNutrients();
    _validatePreparations();
    _validateEstimates();
    _validateConstraints();
    _validateLegacy();
    _validateBackups();
  }

  void _validateIdentities() {
    final stableOwners = <String, B03IdentityFixture>{};
    for (final fixture in identities) {
      if (fixture.displayName.trim().isEmpty ||
          (fixture.stableId != null && fixture.stableId!.trim().isEmpty)) {
        throw StateError('Identity ${fixture.id} is malformed.');
      }
      final stableId = fixture.stableId;
      if (stableId != null &&
          _normalize(stableId) == _normalize(fixture.displayName)) {
        throw StateError(
          'Identity ${fixture.id} derives ID from display text.',
        );
      }
      final requiresStableId =
          fixture.status == B03FixtureIdentityStatus.canonical ||
          fixture.status == B03FixtureIdentityStatus.approvedAlias;
      if (requiresStableId && stableId == null) {
        throw StateError('Resolved identity ${fixture.id} has no stable ID.');
      }
      if (!requiresStableId && stableId != null) {
        throw StateError('Unresolved identity ${fixture.id} has a stable ID.');
      }
      if (fixture.status == B03FixtureIdentityStatus.approvedAlias &&
          (fixture.alias == null || fixture.alias!.trim().isEmpty)) {
        throw StateError('Alias fixture ${fixture.id} has no alias text.');
      }
      if (fixture.source == B03FixtureSource.import &&
          (fixture.providerNamespace == null || fixture.externalId == null)) {
        throw StateError(
          'Imported identity ${fixture.id} lacks provider provenance.',
        );
      }
      if (stableId != null) {
        final previous = stableOwners[stableId];
        if (previous != null &&
            fixture.status != B03FixtureIdentityStatus.approvedAlias &&
            previous.status != B03FixtureIdentityStatus.approvedAlias) {
          throw StateError('Duplicate stable identity ID: $stableId.');
        }
        stableOwners[stableId] = fixture;
      }
    }
  }

  void _validateQuantities() {
    for (final fixture in quantities) {
      if (fixture.unit.trim().isEmpty || !fixture.value.isFinite) {
        throw StateError('Quantity ${fixture.id} is structurally malformed.');
      }
      final valueIsValid = fixture.value >= 0;
      if (fixture.caseKind == B03FixtureCaseKind.valid && !valueIsValid) {
        throw StateError('Valid quantity ${fixture.id} is negative.');
      }
      if (fixture.caseKind == B03FixtureCaseKind.invalid && valueIsValid) {
        throw StateError(
          'Invalid quantity ${fixture.id} lacks an invalid value.',
        );
      }
      if (fixture.caseKind == B03FixtureCaseKind.unknown &&
          fixture.availability != B03FixtureAvailability.unavailable) {
        throw StateError(
          'Unknown quantity ${fixture.id} is falsely available.',
        );
      }
    }
  }

  void _validateNutrients() {
    for (final fixture in nutrients) {
      if (fixture.nutrientKey.trim().isEmpty || fixture.basis.trim().isEmpty) {
        throw StateError('Nutrient ${fixture.id} is malformed.');
      }
      final bounds = [fixture.lower, fixture.point, fixture.upper];
      if (bounds.any((value) => value != null && !value.isFinite)) {
        throw StateError('Nutrient ${fixture.id} contains a non-finite value.');
      }
      if (fixture.status == B03FixtureNutrientStatus.knownZero &&
          (fixture.point != 0 || fixture.lower != 0 || fixture.upper != 0)) {
        throw StateError('Known-zero nutrient ${fixture.id} is not zero.');
      }
      if ({
            B03FixtureNutrientStatus.missing,
            B03FixtureNutrientStatus.notApplicable,
          }.contains(fixture.status) &&
          bounds.any((value) => value != null)) {
        throw StateError('Unknown nutrient ${fixture.id} has a numeric value.');
      }
      if (fixture.lower != null &&
          fixture.point != null &&
          fixture.upper != null &&
          (fixture.lower! < 0 ||
              fixture.lower! > fixture.point! ||
              fixture.point! > fixture.upper!)) {
        throw StateError('Nutrient ${fixture.id} has invalid bounds.');
      }
    }
  }

  void _validatePreparations() {
    for (final fixture in preparations) {
      if (fixture.sourceState.trim().isEmpty ||
          fixture.targetState.trim().isEmpty ||
          fixture.method.trim().isEmpty) {
        throw StateError('Preparation ${fixture.id} is malformed.');
      }
      if (fixture.availability == B03FixtureAvailability.exact &&
          (!fixture.reviewed || fixture.ruleVersion == null)) {
        throw StateError(
          'Exact preparation ${fixture.id} lacks review provenance.',
        );
      }
      if (fixture.availability == B03FixtureAvailability.unavailable &&
          fixture.ruleVersion != null) {
        throw StateError('Unavailable preparation ${fixture.id} has a rule.');
      }
    }
  }

  void _validateEstimates() {
    for (final fixture in estimates) {
      if (fixture.confidence.trim().isEmpty || fixture.status.trim().isEmpty) {
        throw StateError('Estimate ${fixture.id} is malformed.');
      }
      if (!fixture.hasBounds && fixture.status == 'verified') {
        throw StateError(
          'Point-only estimate ${fixture.id} is falsely verified.',
        );
      }
      if (fixture.storesImage || !fixture.correctionCreatesNewRecord) {
        throw StateError(
          'Estimate ${fixture.id} violates privacy/lineage rules.',
        );
      }
    }
  }

  void _validateConstraints() {
    for (final fixture in constraints) {
      final evidenceRequired = {
        B03ConstraintResult.confirmedConflict,
        B03ConstraintResult.possibleConflict,
        B03ConstraintResult.noKnownConflict,
      }.contains(fixture.expectedResult);
      if (evidenceRequired && fixture.evidenceRef == null) {
        throw StateError('Constraint ${fixture.id} lacks evidence.');
      }
      if (!fixture.compositionKnown &&
          fixture.expectedResult == B03ConstraintResult.noKnownConflict) {
        throw StateError(
          'Unknown composition ${fixture.id} claims no conflict.',
        );
      }
      if (fixture.userOverride &&
          fixture.expectedResult !=
              B03ConstraintResult.insufficientInformation) {
        throw StateError(
          'Constraint ${fixture.id} lets override change evidence.',
        );
      }
    }
  }

  void _validateLegacy() {
    for (final fixture in legacy) {
      if (fixture.entity.trim().isEmpty ||
          fixture.originalText.trim().isEmpty) {
        throw StateError('Legacy fixture ${fixture.id} is malformed.');
      }
      if (fixture.sourceVersion < 1 ||
          !fixture.copiedValuesRemainAuthoritative) {
        throw StateError('Legacy fixture ${fixture.id} loses legacy meaning.');
      }
      if (!fixture.canonicalMappingProven &&
          fixture.canonicalStableId != null) {
        throw StateError(
          'Unproven legacy fixture ${fixture.id} has an identity.',
        );
      }
    }
  }

  void _validateBackups() {
    for (final fixture in backups) {
      if (fixture.version < 1 ||
          !fixture.preservesUnknown ||
          !fixture.expectedZeroMutationOnFailure) {
        throw StateError('Backup fixture ${fixture.id} is unsafe.');
      }
      if (fixture.version >= 8 && fixture.expectedImport) {
        throw StateError('Future backup ${fixture.id} is accepted.');
      }
    }
  }
}

class B03FoodAuditRow {
  final String sourceId;
  final int rowIndex;
  final String displayName;
  final String normalizedName;
  final bool hasStableId;
  final bool hasPreparationMetadata;
  final bool hasAliasMetadata;
  final bool hasSourceRevision;

  const B03FoodAuditRow({
    required this.sourceId,
    required this.rowIndex,
    required this.displayName,
    required this.normalizedName,
    required this.hasStableId,
    required this.hasPreparationMetadata,
    required this.hasAliasMetadata,
    required this.hasSourceRevision,
  });
}

class B03FoodSourceAudit {
  final String sourceId;
  final String path;
  final int rowCount;
  final int uniqueNormalizedNameCount;
  final List<String> duplicateNormalizedNames;
  final List<String> overlapNormalizedNames;
  final int manifestGapCount;

  const B03FoodSourceAudit({
    required this.sourceId,
    required this.path,
    required this.rowCount,
    required this.uniqueNormalizedNameCount,
    required this.duplicateNormalizedNames,
    required this.overlapNormalizedNames,
    required this.manifestGapCount,
  });
}

/// Read-only audit of the current base catalogue and five regional packs.
class B03FoodManifestAudit {
  final int version;
  final bool manifestPresent;
  final int? manifestVersion;
  final List<B03FoodSourceAudit> sources;
  final List<B03FoodAuditRow> rows;
  final Map<String, List<String>> normalizedOverlaps;

  const B03FoodManifestAudit._({
    required this.version,
    required this.manifestPresent,
    required this.manifestVersion,
    required this.sources,
    required this.rows,
    required this.normalizedOverlaps,
  });

  factory B03FoodManifestAudit.fromSourceRows({
    required Map<String, List<Map<String, dynamic>>> sourceRows,
    required Map<String, String> sourcePaths,
    bool manifestPresent = false,
    int? manifestVersion,
  }) {
    final rows = <B03FoodAuditRow>[];
    final sortedSources = sourceRows.keys.toList()..sort();
    for (final sourceId in sortedSources) {
      final source = sourceRows[sourceId]!;
      for (var index = 0; index < source.length; index++) {
        final item = source[index];
        final rawName = item['name'];
        if (rawName is! String || rawName.trim().isEmpty) {
          throw FormatException('Food row $sourceId#$index has no name.');
        }
        final stableId = item['id'];
        final hasStableId = stableId is String && stableId.trim().isNotEmpty;
        rows.add(
          B03FoodAuditRow(
            sourceId: sourceId,
            rowIndex: index,
            displayName: rawName,
            normalizedName: _normalize(rawName),
            hasStableId: hasStableId,
            hasPreparationMetadata: _hasAnyKey(item, const [
              'preparation',
              'preparation_id',
              'state',
              'method',
              'variant_of',
            ]),
            hasAliasMetadata: item['aliases'] is List,
            hasSourceRevision: _hasAnyKey(item, const [
              'source_revision',
              'source_version',
              'sourceVersion',
            ]),
          ),
        );
      }
    }

    final namesToSources = <String, Set<String>>{};
    for (final row in rows) {
      namesToSources
          .putIfAbsent(row.normalizedName, () => <String>{})
          .add(row.sourceId);
    }
    final overlaps = <String, List<String>>{};
    for (final entry in namesToSources.entries) {
      if (entry.value.length > 1) {
        overlaps[entry.key] = entry.value.toList()..sort();
      }
    }

    final sources = <B03FoodSourceAudit>[];
    for (final sourceId in sortedSources) {
      final sourceRowsForId = rows
          .where((row) => row.sourceId == sourceId)
          .toList();
      final names = <String, int>{};
      for (final row in sourceRowsForId) {
        names[row.normalizedName] = (names[row.normalizedName] ?? 0) + 1;
      }
      final duplicateNames =
          names.entries
              .where((entry) => entry.value > 1)
              .map((entry) => entry.key)
              .toList()
            ..sort();
      final sourceOverlaps =
          overlaps.entries
              .where((entry) => entry.value.contains(sourceId))
              .map((entry) => entry.key)
              .toList()
            ..sort();
      sources.add(
        B03FoodSourceAudit(
          sourceId: sourceId,
          path: sourcePaths[sourceId] ?? sourceId,
          rowCount: sourceRowsForId.length,
          uniqueNormalizedNameCount: names.length,
          duplicateNormalizedNames: List.unmodifiable(duplicateNames),
          overlapNormalizedNames: List.unmodifiable(sourceOverlaps),
          manifestGapCount: sourceRowsForId
              .where((row) => !row.hasStableId)
              .length,
        ),
      );
    }

    return B03FoodManifestAudit._(
      version: kB03NutritionManifestAuditVersion,
      manifestPresent: manifestPresent,
      manifestVersion: manifestVersion,
      sources: List.unmodifiable(sources),
      rows: List.unmodifiable(rows),
      normalizedOverlaps: Map.unmodifiable(
        overlaps.map(
          (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
        ),
      ),
    );
  }

  static B03FoodManifestAudit loadFromAssetFilesSync({
    String basePath = 'assets/data/indian_foods.json',
    String regionalDirectory = 'assets/data/regional',
    String manifestPath = kB03NutritionManifestPath,
  }) {
    final sourceRows = <String, List<Map<String, dynamic>>>{};
    final sourcePaths = <String, String>{'base': basePath};
    sourceRows['base'] = _readRows(basePath);

    final regionalFiles =
        Directory(regionalDirectory)
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in regionalFiles) {
      final id =
          'regional/${file.uri.pathSegments.last.replaceFirst('.json', '')}';
      sourceRows[id] = _readRows(file.path);
      sourcePaths[id] = file.path;
    }

    var manifestPresent = false;
    int? manifestVersion;
    final manifestFile = File(manifestPath);
    if (manifestFile.existsSync()) {
      manifestPresent = true;
      final decoded = jsonDecode(manifestFile.readAsStringSync());
      if (decoded is! Map || decoded['version'] is! int) {
        throw const FormatException(
          'Nutrition identity manifest has no version.',
        );
      }
      manifestVersion = decoded['version'] as int;
    }

    final audit = B03FoodManifestAudit.fromSourceRows(
      sourceRows: sourceRows,
      sourcePaths: sourcePaths,
      manifestPresent: manifestPresent,
      manifestVersion: manifestVersion,
    );
    audit.validate();
    return audit;
  }

  int get totalRows => rows.length;

  int get mappedRows => rows.where((row) => row.hasStableId).length;

  int get unresolvedRows => rows.length - mappedRows;

  int get totalRegionalRows => sources
      .where((source) => source.sourceId != 'base')
      .fold<int>(0, (sum, source) => sum + source.rowCount);

  Set<String> get duplicateOrOverlappingNames => {
    for (final source in sources) ...source.duplicateNormalizedNames,
    ...normalizedOverlaps.keys,
  };

  void validate() {
    if (version != kB03NutritionManifestAuditVersion) {
      throw StateError('Unsupported B03 manifest audit version: $version.');
    }
    _validateUniqueIds('source', sources.map((source) => source.sourceId));
    final rowKeys = rows.map((row) => '${row.sourceId}#${row.rowIndex}');
    _validateUniqueIds('food audit row', rowKeys);
    if (sources.where((source) => source.sourceId == 'base').length != 1) {
      throw StateError(
        'B03 food audit must contain one base catalogue source.',
      );
    }
    for (final row in rows) {
      if (row.displayName.trim().isEmpty || row.normalizedName.trim().isEmpty) {
        throw StateError('B03 food audit contains an empty identity.');
      }
      if (row.rowIndex < 0) {
        throw StateError('B03 food audit contains a negative row index.');
      }
    }
    for (final source in sources) {
      if (source.duplicateNormalizedNames.isNotEmpty) {
        throw StateError(
          'Source ${source.sourceId} contains duplicate normalized identifiers: '
          '${source.duplicateNormalizedNames.join(', ')}',
        );
      }
    }
    if (mappedRows + unresolvedRows != totalRows) {
      throw StateError('B03 manifest coverage accounting is inconsistent.');
    }
    if (manifestPresent &&
        (manifestVersion == null ||
            manifestVersion != kB03NutritionManifestAuditVersion)) {
      throw StateError(
        'Unsupported or missing B03 manifest version: $manifestVersion.',
      );
    }
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# B03 Nutrition Fixture Matrix and Catalogue Audit')
      ..writeln()
      ..writeln('Generated from B03-01 read-only fixture/audit inputs.')
      ..writeln()
      ..writeln(
        '- Fixture contract version: `$kB03NutritionFixtureContractVersion`',
      )
      ..writeln('- Manifest audit version: `$version`')
      ..writeln('- Expected future manifest: `$kB03NutritionManifestPath`')
      ..writeln('- Manifest present during B03-01: `$manifestPresent`')
      ..writeln(
        '- Manifest version observed: `${manifestVersion ?? 'not present'}`',
      )
      ..writeln('- Total source rows: `$totalRows`')
      ..writeln('- Rows with stable manifest ID: `$mappedRows`')
      ..writeln('- Explicit unresolved/unmapped rows: `$unresolvedRows`')
      ..writeln()
      ..writeln('## Source coverage')
      ..writeln()
      ..writeln(
        '| Source | Rows | Unique normalized names | Manifest gaps | Overlaps |',
      )
      ..writeln('|---|---:|---:|---:|---:|');
    for (final source in sources) {
      buffer.writeln(
        '| `${source.sourceId}` | ${source.rowCount} | '
        '${source.uniqueNormalizedNameCount} | ${source.manifestGapCount} | '
        '${source.overlapNormalizedNames.length} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Normalized overlaps requiring explicit variant review')
      ..writeln()
      ..writeln('| Normalized name | Sources |')
      ..writeln('|---|---|');
    for (final entry in normalizedOverlaps.entries) {
      buffer.writeln('| `${entry.key}` | ${entry.value.join(', ')} |');
    }
    buffer
      ..writeln()
      ..writeln('## Unresolved coverage')
      ..writeln()
      ..writeln(
        'Every current row without a stable ID, preparation/variant metadata, '
        'approved alias, or source revision remains unresolved until the reviewed '
        'manifest task creates an explicit mapping. The runtime audit exposes each '
        'row as `source#rowIndex` plus original and normalized display text; no '
        'display name is promoted to identity here.',
      )
      ..writeln()
      ..writeln('## Contract traceability')
      ..writeln()
      ..writeln('| Reference | Cases | Downstream tasks |')
      ..writeln('|---|---|---|');
    for (final reference in b03ContractReferences) {
      buffer.writeln(
        '| `${reference.id}` | valid / invalid / unknown | '
        '${reference.downstreamTasks.join(', ')} |',
      );
    }
    return buffer.toString();
  }

  static List<Map<String, dynamic>> _readRows(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Food source asset not found at $path', path);
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! List) {
      throw FormatException('Food source asset must be a JSON list: $path');
    }
    final rows = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) {
        throw FormatException('Food source row is not an object: $path');
      }
      rows.add(Map<String, dynamic>.from(item));
    }
    return rows;
  }

  static bool _hasAnyKey(Map<String, dynamic> item, List<String> keys) =>
      keys.any(item.containsKey);
}

void _validateUniqueIds(String label, Iterable<String> ids) {
  final seen = <String>{};
  for (final id in ids) {
    if (id.trim().isEmpty || !seen.add(id)) {
      throw StateError('Duplicate or empty $label ID: $id');
    }
  }
}

String _normalize(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
