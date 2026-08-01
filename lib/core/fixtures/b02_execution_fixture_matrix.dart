import 'exercise_identity_fixtures.dart';

/// Checked-in semantic examples for the B02 implementation tasks.
///
/// This is deliberately a fixture contract, not a production activity model.
/// It freezes the cases that later schema, codec, backup, volume and target
/// implementations must support without performing a migration, lookup, or
/// recommendation itself.
const int kB02FixtureContractVersion = 1;
const String kB02TargetRuleVersion = 'b02-target-v1';

enum B02FixtureActivityType {
  strength,
  running,
  cycling,
  walking,
  yoga,
  mobility,
  legacy,
}

enum B02FixtureActivitySource { manual, healthImport }

enum B02FixtureGroupType { superset, circuit, giantSet }

enum B02FixtureSetRole { warmup, working }

enum B02FixtureTechniqueTag { dropSet, restPause }

enum B02FixtureLoadBasis { external, bodyweight, machineStack }

enum B02FixtureMappingStatus { reviewed, unknown }

enum B02FixtureMuscleRole { primary, secondary, stabilizing }

enum B02FixtureIdentityStatus { resolved, unresolved, ambiguous }

enum B02FixtureTargetOutcome {
  prescriptionFallback,
  increaseOneIncrement,
  decreaseOneIncrement,
  keepComparableLoad,
  deloadReduction,
  noRecommendation,
}

enum B02FixtureConfidence { high, medium, low, insufficient }

enum B02FixtureBackupDisposition {
  restoreB01Only,
  restoreB02,
  rejectBeforeMutation,
}

enum B02FixtureBackupEntity {
  activitySession,
  exerciseGroup,
  exerciseGroupMember,
  strengthSetPrescription,
  cardioDetail,
  cardioInterval,
  mobilityDetail,
  performedExerciseGroup,
  performedExercise,
  targetRecommendation,
  performedSet,
  performedSetSegment,
  performedRestPeriod,
  muscle,
  exerciseMuscleMapping,
  workoutDraft,
  healthProvenance,
}

/// A legacy database or backup case that must stay readable without a B02
/// reclassification or fabricated rich execution row.
class B02LegacyCompatibilityFixture {
  final String id;
  final int sourceVersion;
  final bool isBackup;
  final bool hasLegacySession;
  final bool hasLegacySet;
  final bool hasV1Draft;
  final bool hasUnresolvedExercise;
  final bool hasHealthProvenance;

  const B02LegacyCompatibilityFixture({
    required this.id,
    required this.sourceVersion,
    required this.isBackup,
    required this.hasLegacySession,
    required this.hasLegacySet,
    required this.hasV1Draft,
    required this.hasUnresolvedExercise,
    required this.hasHealthProvenance,
  });
}

class B02ExerciseGroupMemberFixture {
  final String memberSlotId;
  final String expectedExerciseStableId;
  final String actualExerciseStableId;

  const B02ExerciseGroupMemberFixture({
    required this.memberSlotId,
    required this.expectedExerciseStableId,
    required this.actualExerciseStableId,
  });
}

/// The actual ID may repeat, while source member slots must remain distinct.
class B02ExerciseGroupFixture {
  final String id;
  final B02FixtureGroupType type;
  final int roundCount;
  final int? groupRestSeconds;
  final int? memberRestSeconds;
  final int resumeRoundIndex;
  final int resumeMemberIndex;
  final List<B02ExerciseGroupMemberFixture> members;

  const B02ExerciseGroupFixture({
    required this.id,
    required this.type,
    required this.roundCount,
    required this.groupRestSeconds,
    required this.memberRestSeconds,
    required this.resumeRoundIndex,
    required this.resumeMemberIndex,
    required this.members,
  });
}

class B02SetSegmentFixture {
  final int reps;
  final double externalLoadKg;
  final int restBeforeSeconds;

  const B02SetSegmentFixture({
    required this.reps,
    required this.externalLoadKg,
    this.restBeforeSeconds = 0,
  });
}

/// Composable technique facts. A normal set has no optional technique facts.
class B02TechniqueFixture {
  final String id;
  final B02FixtureSetRole role;
  final int performedReps;
  final Set<B02FixtureTechniqueTag> tags;
  final bool isAmrap;
  final bool reachedFailure;
  final int? eccentricSeconds;
  final int? bottomPauseSeconds;
  final int? concentricSeconds;
  final int? lockoutPauseSeconds;
  final String? pausedRepPosition;
  final int? pausedRepSeconds;
  final double? assistanceKg;
  final B02FixtureLoadBasis loadBasis;
  final List<B02SetSegmentFixture> segments;

  const B02TechniqueFixture({
    required this.id,
    required this.role,
    required this.performedReps,
    this.tags = const {},
    this.isAmrap = false,
    this.reachedFailure = false,
    this.eccentricSeconds,
    this.bottomPauseSeconds,
    this.concentricSeconds,
    this.lockoutPauseSeconds,
    this.pausedRepPosition,
    this.pausedRepSeconds,
    this.assistanceKg,
    required this.loadBasis,
    this.segments = const [],
  });
}

class B02ActivityFixture {
  final String id;
  final B02FixtureActivityType activityType;
  final B02FixtureActivitySource source;
  final int durationSeconds;
  final double? distanceKm;
  final double? paceSecondsPerKm;
  final String? provider;
  final String? externalId;
  final String? fingerprint;

  const B02ActivityFixture({
    required this.id,
    required this.activityType,
    required this.source,
    required this.durationSeconds,
    this.distanceKm,
    this.paceSecondsPerKm,
    this.provider,
    this.externalId,
    this.fingerprint,
  });
}

class B02EquipmentIncrementFixture {
  final String id;
  final B02FixtureLoadBasis loadBasis;
  final double? incrementKg;
  final bool isPerHand;
  final double? barWeightKg;

  const B02EquipmentIncrementFixture({
    required this.id,
    required this.loadBasis,
    required this.incrementKg,
    this.isPerHand = false,
    this.barWeightKg,
  });
}

class B02MuscleContributionFixture {
  final String muscleId;
  final B02FixtureMuscleRole role;
  final int contributionBasisPoints;

  const B02MuscleContributionFixture({
    required this.muscleId,
    required this.role,
    required this.contributionBasisPoints,
  });
}

class B02MuscleMappingFixture {
  final String id;
  final String exerciseStableId;
  final B02FixtureMappingStatus status;
  final int mappingVersion;
  final String? reviewedSource;
  final List<B02MuscleContributionFixture> contributions;

  const B02MuscleMappingFixture({
    required this.id,
    required this.exerciseStableId,
    required this.status,
    required this.mappingVersion,
    required this.reviewedSource,
    required this.contributions,
  });
}

/// A fully specified truth-table row for the future pure target rule.
class B02TargetComparatorFixture {
  final String id;
  final String exerciseStableId;
  final B02FixtureIdentityStatus identityStatus;
  final double? prescriptionLoadKg;
  final double? comparableLoadKg;
  final int? comparableReps;
  final int? comparableRpe;
  final bool priorFailed;
  final bool hasRecentComparableHistory;
  final bool isDeloadWeek;
  final bool recoveryIsKnown;
  final double? incrementKg;
  final B02FixtureTargetOutcome expectedOutcome;
  final double? expectedLoadKg;
  final B02FixtureConfidence expectedConfidence;
  final String requiredRationaleCode;
  final double? userOverrideKg;

  const B02TargetComparatorFixture({
    required this.id,
    required this.exerciseStableId,
    required this.identityStatus,
    required this.prescriptionLoadKg,
    required this.comparableLoadKg,
    required this.comparableReps,
    required this.comparableRpe,
    required this.priorFailed,
    required this.hasRecentComparableHistory,
    required this.isDeloadWeek,
    required this.recoveryIsKnown,
    required this.incrementKg,
    required this.expectedOutcome,
    required this.expectedLoadKg,
    required this.expectedConfidence,
    required this.requiredRationaleCode,
    this.userOverrideKg,
  });
}

class B02ProviderTypeFixture {
  final String id;
  final String provider;
  final String providerType;
  final B02FixtureActivityType activityType;

  const B02ProviderTypeFixture({
    required this.id,
    required this.provider,
    required this.providerType,
    required this.activityType,
  });
}

class B02HealthImportFixture {
  final String id;
  final B02FixtureActivitySource source;
  final String? provider;
  final String? externalId;
  final String? fingerprint;
  final bool expectedDuplicateSuppression;

  const B02HealthImportFixture({
    required this.id,
    required this.source,
    required this.provider,
    required this.externalId,
    required this.fingerprint,
    required this.expectedDuplicateSuppression,
  });
}

class B02BackupRelationshipFixture {
  final B02FixtureBackupEntity child;
  final B02FixtureBackupEntity parent;
  final bool parentExists;

  const B02BackupRelationshipFixture({
    required this.child,
    required this.parent,
    required this.parentExists,
  });
}

class B02BackupFixture {
  final String id;
  final int version;
  final B02FixtureBackupDisposition expectedDisposition;
  final Set<B02FixtureBackupEntity> ownedEntities;
  final List<B02BackupRelationshipFixture> relationships;

  const B02BackupFixture({
    required this.id,
    required this.version,
    required this.expectedDisposition,
    required this.ownedEntities,
    required this.relationships,
  });
}

/// Immutable, versioned fixture matrix for B02-01 and its dependants.
class B02ExecutionFixtureMatrix {
  final int version;
  final List<B02LegacyCompatibilityFixture> legacyCases;
  final List<B02ExerciseGroupFixture> groups;
  final List<B02TechniqueFixture> techniques;
  final List<B02ActivityFixture> activities;
  final List<B02EquipmentIncrementFixture> equipmentIncrements;
  final List<B02MuscleMappingFixture> muscleMappings;
  final List<B02TargetComparatorFixture> targetComparators;
  final List<B02ProviderTypeFixture> providerTypes;
  final Set<String> unsupportedProviderTypes;
  final List<B02HealthImportFixture> healthImports;
  final List<B02BackupFixture> backups;

  const B02ExecutionFixtureMatrix({
    required this.version,
    required this.legacyCases,
    required this.groups,
    required this.techniques,
    required this.activities,
    required this.equipmentIncrements,
    required this.muscleMappings,
    required this.targetComparators,
    required this.providerTypes,
    required this.unsupportedProviderTypes,
    required this.healthImports,
    required this.backups,
  });

  static const current = B02ExecutionFixtureMatrix(
    version: kB02FixtureContractVersion,
    legacyCases: [
      B02LegacyCompatibilityFixture(
        id: 'backup-v05-legacy-history',
        sourceVersion: 5,
        isBackup: true,
        hasLegacySession: true,
        hasLegacySet: true,
        hasV1Draft: false,
        hasUnresolvedExercise: false,
        hasHealthProvenance: false,
      ),
      B02LegacyCompatibilityFixture(
        id: 'backup-v06-scheduled-draft',
        sourceVersion: 6,
        isBackup: true,
        hasLegacySession: true,
        hasLegacySet: true,
        hasV1Draft: true,
        hasUnresolvedExercise: false,
        hasHealthProvenance: true,
      ),
      B02LegacyCompatibilityFixture(
        id: 'database-v15-unresolved-custom',
        sourceVersion: 15,
        isBackup: false,
        hasLegacySession: true,
        hasLegacySet: true,
        hasV1Draft: false,
        hasUnresolvedExercise: true,
        hasHealthProvenance: true,
      ),
    ],
    groups: [
      B02ExerciseGroupFixture(
        id: 'circuit-three-members',
        type: B02FixtureGroupType.circuit,
        roundCount: 3,
        groupRestSeconds: 90,
        memberRestSeconds: 0,
        resumeRoundIndex: 1,
        resumeMemberIndex: 2,
        members: [
          B02ExerciseGroupMemberFixture(
            memberSlotId: 'circuit-slot-01',
            expectedExerciseStableId: 'd3b5ab04-74f6-5155-9621-50238644eeda',
            actualExerciseStableId: 'd3b5ab04-74f6-5155-9621-50238644eeda',
          ),
          B02ExerciseGroupMemberFixture(
            memberSlotId: 'circuit-slot-02',
            expectedExerciseStableId: '426ff89a-6639-51d1-a6c1-33184586bbed',
            actualExerciseStableId: '426ff89a-6639-51d1-a6c1-33184586bbed',
          ),
          B02ExerciseGroupMemberFixture(
            memberSlotId: 'circuit-slot-03',
            expectedExerciseStableId: '3525a526-c7a6-5d33-9758-4428da2760b6',
            actualExerciseStableId: '3525a526-c7a6-5d33-9758-4428da2760b6',
          ),
        ],
      ),
      B02ExerciseGroupFixture(
        id: 'giant-set-repeated-actual-exercise',
        type: B02FixtureGroupType.giantSet,
        roundCount: 2,
        groupRestSeconds: 120,
        memberRestSeconds: 0,
        resumeRoundIndex: 0,
        resumeMemberIndex: 1,
        members: [
          B02ExerciseGroupMemberFixture(
            memberSlotId: 'giant-slot-01',
            expectedExerciseStableId: '37088aa5-6989-5241-8ad9-23f1687a9435',
            actualExerciseStableId: '37088aa5-6989-5241-8ad9-23f1687a9435',
          ),
          B02ExerciseGroupMemberFixture(
            memberSlotId: 'giant-slot-02',
            expectedExerciseStableId: 'c6422f26-c3ca-5a2b-9796-e4a3c17d1563',
            actualExerciseStableId: 'c6422f26-c3ca-5a2b-9796-e4a3c17d1563',
          ),
          B02ExerciseGroupMemberFixture(
            memberSlotId: 'giant-slot-03',
            expectedExerciseStableId: '7acd7ccb-01ec-5c3a-80c8-7797efcd3302',
            actualExerciseStableId: 'c6422f26-c3ca-5a2b-9796-e4a3c17d1563',
          ),
        ],
      ),
      B02ExerciseGroupFixture(
        id: 'superset-substitution',
        type: B02FixtureGroupType.superset,
        roundCount: 3,
        groupRestSeconds: 75,
        memberRestSeconds: 0,
        resumeRoundIndex: 2,
        resumeMemberIndex: 0,
        members: [
          B02ExerciseGroupMemberFixture(
            memberSlotId: 'superset-slot-01',
            expectedExerciseStableId: '089ec703-a25e-5b12-a39a-78b17ee33742',
            actualExerciseStableId: '089ec703-a25e-5b12-a39a-78b17ee33742',
          ),
          B02ExerciseGroupMemberFixture(
            memberSlotId: 'superset-slot-02',
            expectedExerciseStableId: '30dcad52-0a4d-55a4-a33b-e8923f85a51a',
            actualExerciseStableId: '9fae7317-b8a5-5f5c-ba93-9d1611fb21dc',
          ),
        ],
      ),
    ],
    techniques: [
      B02TechniqueFixture(
        id: 'warmup-standard',
        role: B02FixtureSetRole.warmup,
        performedReps: 5,
        loadBasis: B02FixtureLoadBasis.external,
      ),
      B02TechniqueFixture(
        id: 'working-amrap-failure',
        role: B02FixtureSetRole.working,
        performedReps: 12,
        isAmrap: true,
        reachedFailure: true,
        loadBasis: B02FixtureLoadBasis.external,
      ),
      B02TechniqueFixture(
        id: 'working-drop-rest-pause',
        role: B02FixtureSetRole.working,
        performedReps: 15,
        tags: {
          B02FixtureTechniqueTag.dropSet,
          B02FixtureTechniqueTag.restPause,
        },
        loadBasis: B02FixtureLoadBasis.machineStack,
        segments: [
          B02SetSegmentFixture(reps: 8, externalLoadKg: 50),
          B02SetSegmentFixture(
            reps: 4,
            externalLoadKg: 40,
            restBeforeSeconds: 20,
          ),
          B02SetSegmentFixture(
            reps: 3,
            externalLoadKg: 32.5,
            restBeforeSeconds: 20,
          ),
        ],
      ),
      B02TechniqueFixture(
        id: 'working-tempo-pause-assisted',
        role: B02FixtureSetRole.working,
        performedReps: 8,
        eccentricSeconds: 3,
        bottomPauseSeconds: 1,
        concentricSeconds: 1,
        lockoutPauseSeconds: 0,
        pausedRepPosition: 'bottom',
        pausedRepSeconds: 1,
        assistanceKg: 15,
        loadBasis: B02FixtureLoadBasis.external,
      ),
    ],
    activities: [
      B02ActivityFixture(
        id: 'manual-mobility-no-distance',
        activityType: B02FixtureActivityType.mobility,
        source: B02FixtureActivitySource.manual,
        durationSeconds: 900,
      ),
      B02ActivityFixture(
        id: 'manual-yoga-no-distance',
        activityType: B02FixtureActivityType.yoga,
        source: B02FixtureActivitySource.manual,
        durationSeconds: 1800,
      ),
      B02ActivityFixture(
        id: 'provider-running-distance-known',
        activityType: B02FixtureActivityType.running,
        source: B02FixtureActivitySource.healthImport,
        durationSeconds: 1500,
        distanceKm: 5,
        paceSecondsPerKm: 300,
        provider: 'health_connect',
        externalId: 'hc-run-1001',
        fingerprint: 'hc-fp-run-1001',
      ),
      B02ActivityFixture(
        id: 'provider-walking-distance-unknown',
        activityType: B02FixtureActivityType.walking,
        source: B02FixtureActivitySource.healthImport,
        durationSeconds: 1200,
        provider: 'health_kit',
        externalId: null,
        fingerprint: 'hk-fp-walk-1001',
      ),
    ],
    equipmentIncrements: [
      B02EquipmentIncrementFixture(
        id: 'barbell-standard',
        loadBasis: B02FixtureLoadBasis.external,
        incrementKg: 2.5,
        barWeightKg: 20,
      ),
      B02EquipmentIncrementFixture(
        id: 'bodyweight-no-external-increment',
        loadBasis: B02FixtureLoadBasis.bodyweight,
        incrementKg: null,
      ),
      B02EquipmentIncrementFixture(
        id: 'dumbbell-per-hand',
        loadBasis: B02FixtureLoadBasis.external,
        incrementKg: 2,
        isPerHand: true,
      ),
      B02EquipmentIncrementFixture(
        id: 'machine-stack',
        loadBasis: B02FixtureLoadBasis.machineStack,
        incrementKg: 5,
      ),
    ],
    muscleMappings: [
      B02MuscleMappingFixture(
        id: 'barbell-squat-reviewed-v1',
        exerciseStableId: 'd3b5ab04-74f6-5155-9621-50238644eeda',
        status: B02FixtureMappingStatus.reviewed,
        mappingVersion: 1,
        reviewedSource: 'reviewed-b02-v1',
        contributions: [
          B02MuscleContributionFixture(
            muscleId: 'glute-maximus',
            role: B02FixtureMuscleRole.secondary,
            contributionBasisPoints: 3000,
          ),
          B02MuscleContributionFixture(
            muscleId: 'quadriceps',
            role: B02FixtureMuscleRole.primary,
            contributionBasisPoints: 7000,
          ),
        ],
      ),
      B02MuscleMappingFixture(
        id: 'bench-press-reviewed-v1',
        exerciseStableId: '089ec703-a25e-5b12-a39a-78b17ee33742',
        status: B02FixtureMappingStatus.reviewed,
        mappingVersion: 1,
        reviewedSource: 'reviewed-b02-v1',
        contributions: [
          B02MuscleContributionFixture(
            muscleId: 'chest',
            role: B02FixtureMuscleRole.primary,
            contributionBasisPoints: 7000,
          ),
          B02MuscleContributionFixture(
            muscleId: 'triceps',
            role: B02FixtureMuscleRole.secondary,
            contributionBasisPoints: 3000,
          ),
        ],
      ),
      B02MuscleMappingFixture(
        id: 'custom-exercise-unknown',
        exerciseStableId: 'legacy-custom-unresolved-001',
        status: B02FixtureMappingStatus.unknown,
        mappingVersion: 1,
        reviewedSource: null,
        contributions: [],
      ),
    ],
    targetComparators: [
      B02TargetComparatorFixture(
        id: 'deload-rounds-resolved-load',
        exerciseStableId: '089ec703-a25e-5b12-a39a-78b17ee33742',
        identityStatus: B02FixtureIdentityStatus.resolved,
        prescriptionLoadKg: 100,
        comparableLoadKg: 100,
        comparableReps: 10,
        comparableRpe: 8,
        priorFailed: false,
        hasRecentComparableHistory: true,
        isDeloadWeek: true,
        recoveryIsKnown: true,
        incrementKg: 2.5,
        expectedOutcome: B02FixtureTargetOutcome.deloadReduction,
        expectedLoadKg: 90,
        expectedConfidence: B02FixtureConfidence.medium,
        requiredRationaleCode: 'deload-v1',
      ),
      B02TargetComparatorFixture(
        id: 'failed-before-minimum-decreases',
        exerciseStableId: '089ec703-a25e-5b12-a39a-78b17ee33742',
        identityStatus: B02FixtureIdentityStatus.resolved,
        prescriptionLoadKg: 100,
        comparableLoadKg: 100,
        comparableReps: 5,
        comparableRpe: 10,
        priorFailed: true,
        hasRecentComparableHistory: true,
        isDeloadWeek: false,
        recoveryIsKnown: true,
        incrementKg: 2.5,
        expectedOutcome: B02FixtureTargetOutcome.decreaseOneIncrement,
        expectedLoadKg: 97.5,
        expectedConfidence: B02FixtureConfidence.high,
        requiredRationaleCode: 'below-rep-minimum',
      ),
      B02TargetComparatorFixture(
        id: 'max-reps-low-rpe-increases-one-increment',
        exerciseStableId: '089ec703-a25e-5b12-a39a-78b17ee33742',
        identityStatus: B02FixtureIdentityStatus.resolved,
        prescriptionLoadKg: 100,
        comparableLoadKg: 100,
        comparableReps: 12,
        comparableRpe: 8,
        priorFailed: false,
        hasRecentComparableHistory: true,
        isDeloadWeek: false,
        recoveryIsKnown: true,
        incrementKg: 2.5,
        expectedOutcome: B02FixtureTargetOutcome.increaseOneIncrement,
        expectedLoadKg: 102.5,
        expectedConfidence: B02FixtureConfidence.high,
        requiredRationaleCode: 'max-reps-rpe-at-most-8',
        userOverrideKg: 101,
      ),
      B02TargetComparatorFixture(
        id: 'missing-recovery-keeps-comparator',
        exerciseStableId: '089ec703-a25e-5b12-a39a-78b17ee33742',
        identityStatus: B02FixtureIdentityStatus.resolved,
        prescriptionLoadKg: 100,
        comparableLoadKg: 100,
        comparableReps: 9,
        comparableRpe: 9,
        priorFailed: false,
        hasRecentComparableHistory: true,
        isDeloadWeek: false,
        recoveryIsKnown: false,
        incrementKg: 2.5,
        expectedOutcome: B02FixtureTargetOutcome.keepComparableLoad,
        expectedLoadKg: 100,
        expectedConfidence: B02FixtureConfidence.medium,
        requiredRationaleCode: 'recovery-unknown',
      ),
      B02TargetComparatorFixture(
        id: 'new-exercise-uses-explicit-prescription',
        exerciseStableId: '30dcad52-0a4d-55a4-a33b-e8923f85a51a',
        identityStatus: B02FixtureIdentityStatus.resolved,
        prescriptionLoadKg: 55,
        comparableLoadKg: null,
        comparableReps: null,
        comparableRpe: null,
        priorFailed: false,
        hasRecentComparableHistory: false,
        isDeloadWeek: false,
        recoveryIsKnown: false,
        incrementKg: 2.5,
        expectedOutcome: B02FixtureTargetOutcome.prescriptionFallback,
        expectedLoadKg: 55,
        expectedConfidence: B02FixtureConfidence.low,
        requiredRationaleCode: 'no-comparable-history',
      ),
      B02TargetComparatorFixture(
        id: 'unresolved-identity-has-no-target',
        exerciseStableId: 'legacy-custom-unresolved-001',
        identityStatus: B02FixtureIdentityStatus.unresolved,
        prescriptionLoadKg: 55,
        comparableLoadKg: 55,
        comparableReps: 12,
        comparableRpe: 8,
        priorFailed: false,
        hasRecentComparableHistory: true,
        isDeloadWeek: false,
        recoveryIsKnown: true,
        incrementKg: 2.5,
        expectedOutcome: B02FixtureTargetOutcome.noRecommendation,
        expectedLoadKg: null,
        expectedConfidence: B02FixtureConfidence.insufficient,
        requiredRationaleCode: 'identity-unresolved',
      ),
    ],
    providerTypes: [
      B02ProviderTypeFixture(
        id: 'health-connect-cycling',
        provider: 'health_connect',
        providerType: 'EXERCISE_SESSION_TYPE_BIKING',
        activityType: B02FixtureActivityType.cycling,
      ),
      B02ProviderTypeFixture(
        id: 'health-connect-running',
        provider: 'health_connect',
        providerType: 'EXERCISE_SESSION_TYPE_RUNNING',
        activityType: B02FixtureActivityType.running,
      ),
      B02ProviderTypeFixture(
        id: 'health-connect-walking',
        provider: 'health_connect',
        providerType: 'EXERCISE_SESSION_TYPE_WALKING',
        activityType: B02FixtureActivityType.walking,
      ),
      B02ProviderTypeFixture(
        id: 'health-kit-cycling',
        provider: 'health_kit',
        providerType: 'HKWorkoutActivityTypeCycling',
        activityType: B02FixtureActivityType.cycling,
      ),
      B02ProviderTypeFixture(
        id: 'health-kit-running',
        provider: 'health_kit',
        providerType: 'HKWorkoutActivityTypeRunning',
        activityType: B02FixtureActivityType.running,
      ),
      B02ProviderTypeFixture(
        id: 'health-kit-walking',
        provider: 'health_kit',
        providerType: 'HKWorkoutActivityTypeWalking',
        activityType: B02FixtureActivityType.walking,
      ),
    ],
    unsupportedProviderTypes: {
      'health_connect|EXERCISE_SESSION_TYPE_OTHER_WORKOUT',
      'health_kit|HKWorkoutActivityTypeOther',
    },
    healthImports: [
      B02HealthImportFixture(
        id: 'manual-session-is-not-import-deduplicated',
        source: B02FixtureActivitySource.manual,
        provider: null,
        externalId: null,
        fingerprint: null,
        expectedDuplicateSuppression: false,
      ),
      B02HealthImportFixture(
        id: 'provider-external-id-reimport-suppressed',
        source: B02FixtureActivitySource.healthImport,
        provider: 'health_connect',
        externalId: 'hc-run-1001',
        fingerprint: 'hc-fp-run-1001',
        expectedDuplicateSuppression: true,
      ),
      B02HealthImportFixture(
        id: 'provider-fingerprint-reimport-suppressed',
        source: B02FixtureActivitySource.healthImport,
        provider: 'health_kit',
        externalId: null,
        fingerprint: 'hk-fp-walk-1001',
        expectedDuplicateSuppression: true,
      ),
    ],
    backups: [
      B02BackupFixture(
        id: 'backup-v05-restores-b01-only',
        version: 5,
        expectedDisposition: B02FixtureBackupDisposition.restoreB01Only,
        ownedEntities: {},
        relationships: [],
      ),
      B02BackupFixture(
        id: 'backup-v06-restores-b01-only',
        version: 6,
        expectedDisposition: B02FixtureBackupDisposition.restoreB01Only,
        ownedEntities: {},
        relationships: [],
      ),
      B02BackupFixture(
        id: 'backup-v07-complete-b02-graph',
        version: 7,
        expectedDisposition: B02FixtureBackupDisposition.restoreB02,
        ownedEntities: {
          B02FixtureBackupEntity.activitySession,
          B02FixtureBackupEntity.exerciseGroup,
          B02FixtureBackupEntity.exerciseGroupMember,
          B02FixtureBackupEntity.strengthSetPrescription,
          B02FixtureBackupEntity.cardioDetail,
          B02FixtureBackupEntity.cardioInterval,
          B02FixtureBackupEntity.mobilityDetail,
          B02FixtureBackupEntity.performedExerciseGroup,
          B02FixtureBackupEntity.performedExercise,
          B02FixtureBackupEntity.targetRecommendation,
          B02FixtureBackupEntity.performedSet,
          B02FixtureBackupEntity.performedSetSegment,
          B02FixtureBackupEntity.performedRestPeriod,
          B02FixtureBackupEntity.muscle,
          B02FixtureBackupEntity.exerciseMuscleMapping,
          B02FixtureBackupEntity.workoutDraft,
          B02FixtureBackupEntity.healthProvenance,
        },
        relationships: [
          B02BackupRelationshipFixture(
            child: B02FixtureBackupEntity.cardioDetail,
            parent: B02FixtureBackupEntity.activitySession,
            parentExists: true,
          ),
          B02BackupRelationshipFixture(
            child: B02FixtureBackupEntity.cardioInterval,
            parent: B02FixtureBackupEntity.cardioDetail,
            parentExists: true,
          ),
          B02BackupRelationshipFixture(
            child: B02FixtureBackupEntity.performedExercise,
            parent: B02FixtureBackupEntity.activitySession,
            parentExists: true,
          ),
          B02BackupRelationshipFixture(
            child: B02FixtureBackupEntity.performedSet,
            parent: B02FixtureBackupEntity.performedExercise,
            parentExists: true,
          ),
          B02BackupRelationshipFixture(
            child: B02FixtureBackupEntity.performedSetSegment,
            parent: B02FixtureBackupEntity.performedSet,
            parentExists: true,
          ),
          B02BackupRelationshipFixture(
            child: B02FixtureBackupEntity.healthProvenance,
            parent: B02FixtureBackupEntity.activitySession,
            parentExists: true,
          ),
        ],
      ),
      B02BackupFixture(
        id: 'backup-v07-orphan-rejected-before-mutation',
        version: 7,
        expectedDisposition: B02FixtureBackupDisposition.rejectBeforeMutation,
        ownedEntities: {B02FixtureBackupEntity.performedSet},
        relationships: [
          B02BackupRelationshipFixture(
            child: B02FixtureBackupEntity.performedSet,
            parent: B02FixtureBackupEntity.performedExercise,
            parentExists: false,
          ),
        ],
      ),
      B02BackupFixture(
        id: 'backup-v08-future-version-rejected-before-mutation',
        version: 8,
        expectedDisposition: B02FixtureBackupDisposition.rejectBeforeMutation,
        ownedEntities: {},
        relationships: [],
      ),
    ],
  );

  /// Fails before a future consumer can use an ambiguous fixture contract.
  void validate() {
    if (version != kB02FixtureContractVersion) {
      throw StateError('Unsupported B02 fixture contract version: $version');
    }
    _validateSortedUnique('legacy case', legacyCases.map((item) => item.id));
    _validateSortedUnique('group', groups.map((item) => item.id));
    _validateSortedUnique('technique', techniques.map((item) => item.id));
    _validateSortedUnique('activity', activities.map((item) => item.id));
    _validateSortedUnique(
      'equipment increment',
      equipmentIncrements.map((item) => item.id),
    );
    _validateSortedUnique(
      'muscle mapping',
      muscleMappings.map((item) => item.id),
    );
    _validateSortedUnique(
      'target comparator',
      targetComparators.map((item) => item.id),
    );
    _validateSortedUnique(
      'provider type',
      providerTypes.map((item) => item.id),
    );
    _validateSortedUnique(
      'health import',
      healthImports.map((item) => item.id),
    );
    _validateSortedUnique('backup', backups.map((item) => item.id));

    for (final fixture in legacyCases) {
      final expectedVersion = fixture.isBackup ? {5, 6} : {15};
      if (!expectedVersion.contains(fixture.sourceVersion)) {
        throw StateError(
          'Legacy fixture ${fixture.id} has an invalid version.',
        );
      }
      if (!fixture.hasLegacySession && !fixture.hasV1Draft) {
        throw StateError(
          'Legacy fixture ${fixture.id} has no retained B01 fact.',
        );
      }
    }
    for (final fixture in groups) {
      _validateGroup(fixture);
    }
    for (final fixture in techniques) {
      _validateTechnique(fixture);
    }
    for (final fixture in activities) {
      _validateActivity(fixture);
    }
    for (final fixture in equipmentIncrements) {
      _validateEquipment(fixture);
    }
    for (final fixture in muscleMappings) {
      _validateMapping(fixture);
    }
    for (final fixture in targetComparators) {
      _validateTarget(fixture);
    }
    _validateProviderTypes();
    _validateHealthImports();
    for (final fixture in backups) {
      _validateBackup(fixture);
    }
  }

  static void _validateSortedUnique(String label, Iterable<String> ids) {
    String? previous;
    for (final id in ids) {
      if (id.trim().isEmpty) {
        throw StateError('$label fixture has an empty ID.');
      }
      if (previous != null && previous.compareTo(id) >= 0) {
        throw StateError('$label fixture IDs must be unique and sorted: $id');
      }
      previous = id;
    }
  }

  static void _validateGroup(B02ExerciseGroupFixture fixture) {
    final requiredMemberCount = switch (fixture.type) {
      B02FixtureGroupType.superset => 2,
      B02FixtureGroupType.circuit => 2,
      B02FixtureGroupType.giantSet => 3,
    };
    if (fixture.members.length < requiredMemberCount ||
        (fixture.type == B02FixtureGroupType.superset &&
            fixture.members.length != 2)) {
      throw StateError(
        'Invalid ${fixture.type.name} member count in ${fixture.id}.',
      );
    }
    if (fixture.roundCount < 1 ||
        fixture.resumeRoundIndex < 0 ||
        fixture.resumeRoundIndex >= fixture.roundCount ||
        fixture.resumeMemberIndex < 0 ||
        fixture.resumeMemberIndex >= fixture.members.length ||
        (fixture.groupRestSeconds != null && fixture.groupRestSeconds! < 0) ||
        (fixture.memberRestSeconds != null && fixture.memberRestSeconds! < 0)) {
      throw StateError('Invalid group progress or rest in ${fixture.id}.');
    }
    final slots = <String>{};
    for (final member in fixture.members) {
      if (!slots.add(member.memberSlotId) ||
          !_isCanonicalId(member.expectedExerciseStableId) ||
          !_isCanonicalId(member.actualExerciseStableId)) {
        throw StateError('Invalid group member identity in ${fixture.id}.');
      }
    }
  }

  static void _validateTechnique(B02TechniqueFixture fixture) {
    if (fixture.performedReps < 1) {
      throw StateError('Technique ${fixture.id} has no performed repetitions.');
    }
    final tempo = [
      fixture.eccentricSeconds,
      fixture.bottomPauseSeconds,
      fixture.concentricSeconds,
      fixture.lockoutPauseSeconds,
    ];
    final hasTempo = tempo.any((component) => component != null);
    if (hasTempo &&
        (tempo.any((component) => component == null) ||
            tempo.any((component) => component! < 0 || component > 20) ||
            tempo.every((component) => component == 0))) {
      throw StateError('Technique ${fixture.id} has invalid tempo components.');
    }
    if ((fixture.pausedRepPosition == null) !=
            (fixture.pausedRepSeconds == null) ||
        (fixture.pausedRepSeconds != null && fixture.pausedRepSeconds! < 1)) {
      throw StateError(
        'Technique ${fixture.id} has an invalid paused repetition.',
      );
    }
    if (fixture.assistanceKg != null && fixture.assistanceKg! <= 0) {
      throw StateError('Technique ${fixture.id} has invalid assistance.');
    }
    if (fixture.role == B02FixtureSetRole.warmup &&
        (fixture.tags.isNotEmpty ||
            fixture.isAmrap ||
            fixture.reachedFailure ||
            fixture.assistanceKg != null ||
            hasTempo)) {
      throw StateError(
        'Warm-up ${fixture.id} cannot carry working techniques.',
      );
    }
    final segmentReps = fixture.segments.fold<int>(
      0,
      (total, segment) => total + segment.reps,
    );
    if (fixture.tags.isEmpty && fixture.segments.isNotEmpty ||
        fixture.tags.isNotEmpty && fixture.segments.length < 2 ||
        fixture.segments.any(
          (segment) =>
              segment.reps < 1 ||
              segment.externalLoadKg < 0 ||
              segment.restBeforeSeconds < 0,
        ) ||
        fixture.segments.isNotEmpty && segmentReps != fixture.performedReps) {
      throw StateError('Technique ${fixture.id} has invalid segments.');
    }
    if (fixture.tags.contains(B02FixtureTechniqueTag.dropSet) &&
        !fixture.segments
            .skip(1)
            .toList()
            .asMap()
            .entries
            .any(
              (entry) =>
                  entry.value.externalLoadKg <
                  fixture.segments[entry.key].externalLoadKg,
            )) {
      throw StateError('Drop set ${fixture.id} never drops load.');
    }
    if (fixture.tags.contains(B02FixtureTechniqueTag.restPause) &&
        fixture.segments
            .skip(1)
            .any((segment) => segment.restBeforeSeconds < 1)) {
      throw StateError('Rest-pause ${fixture.id} lacks cluster rest.');
    }
  }

  static void _validateActivity(B02ActivityFixture fixture) {
    if (fixture.durationSeconds < 1 ||
        (fixture.distanceKm != null && fixture.distanceKm! <= 0) ||
        (fixture.paceSecondsPerKm != null && fixture.paceSecondsPerKm! <= 0)) {
      throw StateError('Activity ${fixture.id} has invalid measured values.');
    }
    final forbidsDistance = {
      B02FixtureActivityType.strength,
      B02FixtureActivityType.yoga,
      B02FixtureActivityType.mobility,
      B02FixtureActivityType.legacy,
    }.contains(fixture.activityType);
    if (forbidsDistance &&
        (fixture.distanceKm != null || fixture.paceSecondsPerKm != null)) {
      throw StateError(
        'Activity ${fixture.id} has inappropriate distance data.',
      );
    }
    final imported = fixture.source == B02FixtureActivitySource.healthImport;
    if (imported &&
        (fixture.provider == null ||
            (fixture.externalId == null && fixture.fingerprint == null))) {
      throw StateError('Imported activity ${fixture.id} lacks provenance.');
    }
    if (!imported &&
        (fixture.provider != null ||
            fixture.externalId != null ||
            fixture.fingerprint != null)) {
      throw StateError('Manual activity ${fixture.id} has import provenance.');
    }
  }

  static void _validateEquipment(B02EquipmentIncrementFixture fixture) {
    if (fixture.loadBasis == B02FixtureLoadBasis.bodyweight) {
      if (fixture.incrementKg != null || fixture.barWeightKg != null) {
        throw StateError(
          'Bodyweight fixture ${fixture.id} has an external load.',
        );
      }
      return;
    }
    if (fixture.incrementKg == null ||
        fixture.incrementKg! <= 0 ||
        (fixture.barWeightKg != null && fixture.barWeightKg! <= 0)) {
      throw StateError(
        'Equipment fixture ${fixture.id} has invalid increments.',
      );
    }
  }

  static void _validateMapping(B02MuscleMappingFixture fixture) {
    if (fixture.mappingVersion < 1) {
      throw StateError('Mapping ${fixture.id} has no mapping version.');
    }
    final muscles = <String>{};
    final total = fixture.contributions.fold<int>(
      0,
      (sum, item) => sum + item.contributionBasisPoints,
    );
    for (final contribution in fixture.contributions) {
      if (contribution.muscleId.trim().isEmpty ||
          !muscles.add(contribution.muscleId) ||
          contribution.contributionBasisPoints < 1) {
        throw StateError('Mapping ${fixture.id} has invalid contributions.');
      }
    }
    if (fixture.status == B02FixtureMappingStatus.reviewed &&
        (!_isCanonicalId(fixture.exerciseStableId) ||
            fixture.reviewedSource == null ||
            fixture.reviewedSource!.trim().isEmpty ||
            total != 10000)) {
      throw StateError('Reviewed mapping ${fixture.id} is incomplete.');
    }
    if (fixture.status == B02FixtureMappingStatus.unknown &&
        (fixture.reviewedSource != null || fixture.contributions.isNotEmpty)) {
      throw StateError(
        'Unknown mapping ${fixture.id} invents allocation data.',
      );
    }
  }

  static void _validateTarget(B02TargetComparatorFixture fixture) {
    if (fixture.requiredRationaleCode.trim().isEmpty) {
      throw StateError('Target ${fixture.id} has no explanation.');
    }
    final resolved =
        fixture.identityStatus == B02FixtureIdentityStatus.resolved;
    if (resolved != _isCanonicalId(fixture.exerciseStableId)) {
      throw StateError('Target ${fixture.id} has invalid exercise identity.');
    }
    if (fixture.incrementKg != null && fixture.incrementKg! <= 0) {
      throw StateError('Target ${fixture.id} has invalid increment.');
    }
    final shouldHaveNoRecommendation =
        !resolved ||
        (!fixture.hasRecentComparableHistory &&
            fixture.prescriptionLoadKg == null);
    if (shouldHaveNoRecommendation &&
        fixture.expectedOutcome != B02FixtureTargetOutcome.noRecommendation) {
      throw StateError(
        'Target ${fixture.id} recommends from insufficient evidence.',
      );
    }
    if (fixture.expectedOutcome == B02FixtureTargetOutcome.noRecommendation &&
        (fixture.expectedLoadKg != null ||
            fixture.expectedConfidence != B02FixtureConfidence.insufficient)) {
      throw StateError(
        'Target ${fixture.id} has an unsafe empty recommendation.',
      );
    }
    if (fixture.expectedOutcome != B02FixtureTargetOutcome.noRecommendation &&
        (fixture.expectedLoadKg == null || fixture.expectedLoadKg! < 0)) {
      throw StateError('Target ${fixture.id} has no expected load.');
    }
    if (!fixture.recoveryIsKnown &&
        fixture.requiredRationaleCode != 'recovery-unknown' &&
        fixture.expectedOutcome !=
            B02FixtureTargetOutcome.prescriptionFallback) {
      throw StateError(
        'Target ${fixture.id} fails to disclose unknown recovery.',
      );
    }
    if (fixture.userOverrideKg != null && fixture.userOverrideKg! < 0) {
      throw StateError('Target ${fixture.id} has an invalid user override.');
    }
  }

  void _validateProviderTypes() {
    final keys = <String>{};
    for (final fixture in providerTypes) {
      final key = '${fixture.provider}|${fixture.providerType}';
      if (fixture.provider.trim().isEmpty ||
          fixture.providerType.trim().isEmpty ||
          !keys.add(key) ||
          fixture.activityType == B02FixtureActivityType.legacy ||
          unsupportedProviderTypes.contains(key)) {
        throw StateError('Provider fixture ${fixture.id} is ambiguous.');
      }
    }
  }

  void _validateHealthImports() {
    final externalKeys = <String>{};
    final fingerprints = <String>{};
    for (final fixture in healthImports) {
      final imported = fixture.source == B02FixtureActivitySource.healthImport;
      if (!imported) {
        if (fixture.provider != null ||
            fixture.externalId != null ||
            fixture.fingerprint != null ||
            fixture.expectedDuplicateSuppression) {
          throw StateError(
            'Manual fixture ${fixture.id} has import deduplication.',
          );
        }
        continue;
      }
      if (fixture.provider == null ||
          (fixture.externalId == null && fixture.fingerprint == null) ||
          !fixture.expectedDuplicateSuppression) {
        throw StateError(
          'Import fixture ${fixture.id} lacks deterministic dedupe.',
        );
      }
      if (fixture.externalId != null &&
          !externalKeys.add('${fixture.provider}|${fixture.externalId}')) {
        throw StateError('Duplicate provider external ID in ${fixture.id}.');
      }
      if (fixture.fingerprint != null &&
          !fingerprints.add(fixture.fingerprint!)) {
        throw StateError('Duplicate fallback fingerprint in ${fixture.id}.');
      }
    }
  }

  static void _validateBackup(B02BackupFixture fixture) {
    if (fixture.version > 7 &&
        fixture.expectedDisposition !=
            B02FixtureBackupDisposition.rejectBeforeMutation) {
      throw StateError('Future backup ${fixture.id} does not fail closed.');
    }
    if ({5, 6}.contains(fixture.version) &&
        fixture.expectedDisposition !=
            B02FixtureBackupDisposition.restoreB01Only) {
      throw StateError(
        'Legacy backup ${fixture.id} does not preserve B01 mode.',
      );
    }
    if (fixture.expectedDisposition == B02FixtureBackupDisposition.restoreB02 &&
        (!fixture.ownedEntities.containsAll(B02FixtureBackupEntity.values) ||
            fixture.relationships.any((relation) => !relation.parentExists))) {
      throw StateError('B02 backup ${fixture.id} has an incomplete graph.');
    }
    if (fixture.expectedDisposition ==
            B02FixtureBackupDisposition.rejectBeforeMutation &&
        fixture.version == 7 &&
        fixture.relationships.every((relation) => relation.parentExists)) {
      throw StateError(
        'Rejected backup ${fixture.id} has no invalid relationship.',
      );
    }
  }

  static bool _isCanonicalId(String stableId) =>
      ExerciseCatalogManifest.goldenCatalogUuids.values.contains(stableId);
}
