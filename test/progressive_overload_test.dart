import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b02_execution_fixture_matrix.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_target_recommendation_repository.dart';
import 'package:indifit/data/services/b02_load_target_recommendation_service.dart';
import 'package:indifit/data/services/b02_warmup_recommendation_service.dart';

double calculate1RM(double weight, int reps) {
  if (reps <= 0 || weight <= 0) return 0.0;
  return weight * (1 + reps / 30.0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = LoadTargetRecommendationService();
  final now = DateTime.utc(2026, 8, 1, 10);

  group('Progressive Overload 1RM regression', () {
    test('calculates 1RM accurately using the Epley formula', () {
      expect(calculate1RM(100, 10), closeTo(133.33, 0.01));
    });

    test('preserves PR comparison behavior', () {
      expect(calculate1RM(102.5, 8) > calculate1RM(100, 8), isTrue);
      expect(calculate1RM(95, 10) > calculate1RM(100, 10), isFalse);
    });
  });

  B02LoadTargetRecommendationResult recommend({
    required String id,
    required String stableId,
    bool resolved = true,
    double? prescriptionLoad = 100,
    List<B02TargetComparator> comparators = const [],
    bool isDeload = false,
    bool recoveryKnown = true,
    double? increment = 2.5,
    int? minReps = 8,
    int? maxReps = 12,
  }) {
    return service.recommend(
      B02LoadTargetRecommendationRequest(
        recommendationId: 'recommendation-$id',
        performedExerciseId: 'performed-$id',
        prescription: B02LoadTargetPrescription(
          stableExerciseId: stableId,
          identityResolved: resolved,
          loadBasis: B02LoadBasis.totalExternal,
          prescribedLoadKg: prescriptionLoad,
          targetRepsMin: minReps,
          targetRepsMax: maxReps,
          isDeloadWeek: isDeload,
        ),
        evidence: B02LoadTargetEvidence(
          cutoffUtc: now.subtract(B02LoadTargetRuleV1.comparatorWindow),
          comparators: comparators,
          recentWorkingSetCount: 4,
          recoveryKnown: recoveryKnown,
        ),
        incrementInput: B02EquipmentIncrementInput(
          effectiveItemIncrementKg: increment,
        ),
      ),
    );
  }

  B02TargetComparator comparator({
    String id = 'set-1',
    String stableId = '089ec703-a25e-5b12-a39a-78b17ee33742',
    B02LoadBasis basis = B02LoadBasis.totalExternal,
    double load = 100,
    int reps = 10,
    int? rpe = 8,
    bool failed = false,
    DateTime? completedAtUtc,
  }) => B02TargetComparator(
    performedSetId: id,
    stableExerciseId: stableId,
    loadBasis: basis,
    actualLoadKg: load,
    actualReps: reps,
    actualRpe: rpe,
    endedAtFailure: failed,
    completedAtUtc: completedAtUtc ?? now.subtract(const Duration(days: 1)),
  );

  group('B02-D11 target recommendation rule', () {
    test('matches every accepted target fixture outcome and explanation', () {
      for (final fixture
          in B02ExecutionFixtureMatrix.current.targetComparators) {
        final result = recommend(
          id: fixture.id,
          stableId: fixture.exerciseStableId,
          resolved: fixture.identityStatus == B02FixtureIdentityStatus.resolved,
          prescriptionLoad: fixture.prescriptionLoadKg,
          comparators: fixture.hasRecentComparableHistory
              ? [
                  comparator(
                    id: '${fixture.id}-set',
                    stableId: fixture.exerciseStableId,
                    load: fixture.comparableLoadKg!,
                    reps: fixture.comparableReps!,
                    rpe: fixture.comparableRpe,
                    failed: fixture.priorFailed,
                  ),
                ]
              : const [],
          isDeload: fixture.isDeloadWeek,
          recoveryKnown: fixture.recoveryIsKnown,
          increment: fixture.incrementKg,
        );
        expect(
          result.recommendation.recommendedLoadKg,
          fixture.expectedLoadKg,
          reason: fixture.id,
        );
        expect(
          result.recommendation.confidence.dbValue,
          fixture.expectedConfidence.name,
          reason: fixture.id,
        );
        expect(
          result.recommendation.rationaleCodes,
          contains(fixture.requiredRationaleCode),
          reason: fixture.id,
        );
      }
    });

    test(
      'selects the most recent in-range exact comparator, never a fuzzy row',
      () {
        final result = recommend(
          id: 'exact',
          stableId: 'exercise-a',
          comparators: [
            comparator(
              id: 'older-in-range',
              stableId: 'exercise-a',
              reps: 12,
              completedAtUtc: now.subtract(const Duration(days: 4)),
            ),
            comparator(
              id: 'newer-out-of-range',
              stableId: 'exercise-a',
              reps: 5,
              failed: true,
              completedAtUtc: now.subtract(const Duration(days: 1)),
            ),
            comparator(
              id: 'wrong-stable-id',
              stableId: 'exercise-b',
              reps: 12,
              completedAtUtc: now.subtract(const Duration(hours: 1)),
            ),
            comparator(
              id: 'wrong-load-basis',
              stableId: 'exercise-a',
              basis: B02LoadBasis.perSide,
              reps: 12,
              completedAtUtc: now.subtract(const Duration(hours: 2)),
            ),
          ],
        );

        expect(result.selectedComparator!.performedSetId, 'older-in-range');
        expect(result.recommendation.recommendedLoadKg, 102.5);
        expect(result.recommendation.comparatorCount, 2);
      },
    );

    test(
      'does not guess a load when an adjustment or deload lacks an increment',
      () {
        final increase = recommend(
          id: 'no-increment',
          stableId: 'exercise-a',
          increment: null,
          comparators: [comparator(stableId: 'exercise-a', reps: 12)],
        );
        final deload = recommend(
          id: 'deload-no-increment',
          stableId: 'exercise-a',
          increment: null,
          isDeload: true,
          comparators: [comparator(stableId: 'exercise-a')],
        );

        expect(increase.recommendation.recommendedLoadKg, isNull);
        expect(increase.recommendation.confidence, B02Confidence.insufficient);
        expect(
          increase.recommendation.rationaleCodes,
          contains('increment-unavailable'),
        );
        expect(deload.recommendation.recommendedLoadKg, isNull);
        expect(
          deload.recommendation.rationaleCodes,
          contains('deload-load-unavailable'),
        );
      },
    );

    test(
      'keeps recovery unknown as evidence only and preserves prior reps without a range',
      () {
        final result = recommend(
          id: 'unknown-recovery',
          stableId: 'exercise-a',
          recoveryKnown: false,
          minReps: null,
          maxReps: null,
          comparators: [comparator(stableId: 'exercise-a', reps: 9)],
        );

        expect(result.recommendation.recommendedLoadKg, 100);
        expect(result.recommendation.confidence, B02Confidence.low);
        expect(result.recommendation.targetRepsMin, isNull);
        expect(result.recommendation.targetRepsMax, isNull);
        expect(result.recommendation.completeness['previousAchievedReps'], 9);
        expect(
          result.recommendation.rationaleCodes,
          contains('recovery-unknown'),
        );
      },
    );
  });

  group('B02 target evidence and persistence', () {
    late AppDatabase db;
    late B02TargetEvidenceRepository evidence;
    late B02TargetRecommendationPersistenceRepository persistence;

    setUp(() {
      db = AppDatabase.memory();
      evidence = B02TargetEvidenceRepository(db);
      persistence = B02TargetRecommendationPersistenceRepository(db);
    });

    tearDown(() => db.close());

    Future<(int, String)> insertCanonicalHistory({
      required String stableId,
      required String performedExerciseId,
      required String performedSetId,
      required B02SetRole role,
      required B02LoadBasis basis,
      required DateTime completedAtUtc,
      int reps = 10,
    }) async {
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: Value(stableId),
              name: stableId,
              muscleGroups: 'ignored-by-target-rule',
              equipment: 'barbell',
              difficulty: 'intermediate',
              formCues: '',
              commonMistakes: '',
              isCustom: const Value(true),
            ),
          );
      final sessionId = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: 'Strength',
              totalVolume: 0,
              durationSeconds: 600,
              estimatedCalories: 0,
              completedAt: Value(completedAtUtc),
              activityType: const Value('strength'),
              activitySchemaVersion: const Value(1),
            ),
          );
      await db
          .into(db.performedExercises)
          .insert(
            PerformedExercisesCompanion.insert(
              id: performedExerciseId,
              sessionId: sessionId,
              ordinal: 0,
              actualExerciseId: stableId,
              actualExerciseNameSnapshot: stableId,
            ),
          );
      await db
          .into(db.performedSets)
          .insert(
            PerformedSetsCompanion.insert(
              id: performedSetId,
              performedExerciseId: performedExerciseId,
              ordinal: 0,
              role: role.dbValue,
              actualLoadKg: const Value(100),
              actualLoadBasis: Value(basis.dbValue),
              actualReps: Value(reps),
            ),
          );
      return (sessionId, performedExerciseId);
    }

    test(
      'queries only canonical, exact-ID working history and preserves timezone unknown',
      () async {
        const stableId = 'stable-exercise';
        await insertCanonicalHistory(
          stableId: stableId,
          performedExerciseId: 'valid-exercise',
          performedSetId: 'valid-working',
          role: B02SetRole.working,
          basis: B02LoadBasis.totalExternal,
          completedAtUtc: now.subtract(const Duration(days: 1)),
        );
        await insertCanonicalHistory(
          stableId: 'other-exercise',
          performedExerciseId: 'other-exercise-row',
          performedSetId: 'wrong-id',
          role: B02SetRole.working,
          basis: B02LoadBasis.totalExternal,
          completedAtUtc: now.subtract(const Duration(days: 1)),
        );
        await insertCanonicalHistory(
          stableId: 'warmup-exercise',
          performedExerciseId: 'warmup-exercise-row',
          performedSetId: 'warmup',
          role: B02SetRole.warmup,
          basis: B02LoadBasis.totalExternal,
          completedAtUtc: now.subtract(const Duration(days: 1)),
        );

        final gathered = await evidence.gather(
          B02TargetEvidenceQuery(
            stableExerciseId: stableId,
            identityResolved: true,
            loadBasis: B02LoadBasis.totalExternal,
            nowUtc: now,
            executionTimezoneId: null,
            recoveryKnown: false,
          ),
        );
        expect(gathered.comparators.map((row) => row.performedSetId), [
          'valid-working',
        ]);
        expect(gathered.recentWorkingSetCount, isNull);
        expect(gathered.recoveryKnown, isFalse);
      },
    );

    test(
      'draft override and completed evidence preserve offered and actual values separately',
      () async {
        const stableId = 'persistent-exercise';
        final record = await insertCanonicalHistory(
          stableId: stableId,
          performedExerciseId: 'completed-exercise',
          performedSetId: 'completed-set',
          role: B02SetRole.working,
          basis: B02LoadBasis.totalExternal,
          completedAtUtc: now.subtract(const Duration(days: 1)),
        );
        final offer = recommend(
          id: 'persistent',
          stableId: stableId,
          comparators: [comparator(stableId: stableId, reps: 12)],
        ).recommendation;
        final draft = B02ExecutionDraftState(
          snapshotId: 'snapshot-target',
          snapshotVersion: 1,
          activityType: B02ActivityType.strength,
          routineName: 'Strength',
          elapsedSeconds: 0,
          currentExerciseOrdinal: 0,
          currentSetOrdinal: 0,
          performedExercises: [
            B02PerformedExerciseDraft(
              id: offer.performedExerciseId,
              ordinal: 0,
              actualExerciseId: stableId,
              actualExerciseNameSnapshot: 'Exercise',
              status: 'inProgress',
              sets: [
                B02PerformedSet(
                  id: 'draft-set',
                  performedExerciseId: offer.performedExerciseId,
                  ordinal: 0,
                  role: B02SetRole.working,
                  actualLoadKg: 101,
                  actualLoadBasis: B02LoadBasis.totalExternal,
                  actualReps: 10,
                ),
              ],
            ),
          ],
        );
        const coordinator = B02TargetDraftCoordinator();
        final overridden = coordinator.recordOverride(
          coordinator.freezeRecommendation(draft, offer),
          offer.performedExerciseId,
        );
        expect(
          overridden
              .performedExercises
              .single
              .targetRecommendation!
              .recommendedLoadKg,
          102.5,
        );
        expect(
          overridden
              .performedExercises
              .single
              .targetRecommendation!
              .wasOverridden,
          isTrue,
        );
        expect(
          overridden.performedExercises.single.sets.single.actualLoadKg,
          101,
        );

        final completedOffer = offer.copyWith(wasOverridden: true);
        final frozen = B02TargetRecommendation(
          id: completedOffer.id,
          performedExerciseId: record.$2,
          ruleVersion: completedOffer.ruleVersion,
          confidence: completedOffer.confidence,
          completeness: completedOffer.completeness,
          recommendedLoadKg: completedOffer.recommendedLoadKg,
          loadBasis: completedOffer.loadBasis,
          targetRepsMin: completedOffer.targetRepsMin,
          targetRepsMax: completedOffer.targetRepsMax,
          targetRpe: completedOffer.targetRpe,
          incrementKg: completedOffer.incrementKg,
          evidenceCutoffUtc: completedOffer.evidenceCutoffUtc,
          comparatorCount: completedOffer.comparatorCount,
          rationaleCodes: completedOffer.rationaleCodes,
          wasOverridden: completedOffer.wasOverridden,
        );
        await persistence.persistCompleted(frozen);
        final restored = await persistence.readCompleted(record.$2);
        final actual = await (db.select(
          db.performedSets,
        )..where((table) => table.id.equals('completed-set'))).getSingle();
        expect(restored!.recommendedLoadKg, 102.5);
        expect(restored.wasOverridden, isTrue);
        expect(actual.actualLoadKg, 100);
        await expectLater(
          persistence.persistCompleted(frozen),
          throwsA(isA<B02ValidationException>()),
        );
      },
    );
  });
}
