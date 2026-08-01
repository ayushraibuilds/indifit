import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b02_execution_draft_codec.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';
import 'package:indifit/data/services/b02_rest_recommendation_service.dart';
import 'package:indifit/data/services/b02_warmup_recommendation_service.dart';

void main() {
  final service = const WarmupRecommendationService();
  final rest = const RestRecommendationService();

  B02WarmupLoadCandidate candidate(
    double? load, {
    B02LoadBasis basis = B02LoadBasis.totalExternal,
    B02WarmupTargetSource source = B02WarmupTargetSource.prescription,
  }) {
    return B02WarmupLoadCandidate(
      loadKg: load,
      loadBasis: basis,
      source: source,
    );
  }

  B02ExecutionDraftState draft({
    B02WarmupRecommendation? warmupRecommendation,
    List<B02RestPeriod> restPeriods = const [],
  }) {
    return B02ExecutionDraftState(
      snapshotId: 'snapshot-1',
      snapshotVersion: 1,
      activityType: B02ActivityType.strength,
      routineName: 'B02',
      elapsedSeconds: 10,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
      warmupRecommendation: warmupRecommendation,
      restPeriods: restPeriods,
    );
  }

  B02RestPeriod openRest({
    String id = 'rest-1',
    int? recommendedSeconds = 90,
    int? selectedSeconds = 90,
  }) {
    return B02RestPeriod(
      id: id,
      performedSetId: 'set-1',
      scope: B02RestScope.exerciseSet,
      recommendedSeconds: recommendedSeconds,
      selectedSeconds: selectedSeconds,
      source: B02RestSource.automatic,
      startedAtUtc: DateTime.utc(2026, 8, 1, 10),
    );
  }

  group('B02-07 warm-up service', () {
    test('uses deterministic four-stage percentages and reps', () {
      final expected = <int, List<double>>{
        1: [50],
        2: [40, 70],
        3: [40, 60, 80],
        4: [30, 45, 60, 80],
      };
      for (final entry in expected.entries) {
        final result = service.recommend(
          B02WarmupRequest(
            requestedCount: entry.key,
            prescription: candidate(100),
            incrementInput: const B02EquipmentIncrementInput(
              effectiveItemIncrementKg: 2.5,
            ),
          ),
        );
        expect(result.availability, B02WarmupAvailability.available);
        expect(
          result.proposals.map((proposal) => proposal.percentageOfWorkingLoad),
          entry.value,
        );
        expect(
          result.proposals.map((proposal) => proposal.loadKg),
          entry.value,
        );
      }
    });

    test(
      'prefers explicit targets and preserves load basis without doubling',
      () {
        final result = service.recommend(
          B02WarmupRequest(
            userEditedTarget: candidate(
              50,
              basis: B02LoadBasis.perSide,
              source: B02WarmupTargetSource.userEditedDraft,
            ),
            targetRecommendation: candidate(80),
            prescription: candidate(100),
            requestedCount: 2,
            incrementInput: const B02EquipmentIncrementInput(
              effectiveItemIncrementKg: 2.5,
            ),
          ),
        );
        expect(result.selectedSource, B02WarmupTargetSource.userEditedDraft);
        expect(result.loadBasis, B02LoadBasis.perSide);
        expect(result.workingLoadKg, 50);
        expect(result.proposals.last.loadKg, 35);
      },
    );

    test(
      'uses profile fallback, marks missing increment, and keeps one decimal',
      () {
        final profileFallback = service.recommend(
          B02WarmupRequest(
            prescription: candidate(80),
            requestedCount: 3,
            incrementInput: const B02EquipmentIncrementInput(
              profileDefaultIncrementKg: 5,
            ),
          ),
        );
        expect(profileFallback.incrementKg, 5);
        expect(profileFallback.incrementUnavailable, isFalse);

        final unknown = service.recommend(
          B02WarmupRequest(prescription: candidate(80), requestedCount: 3),
        );
        expect(unknown.incrementKg, isNull);
        expect(unknown.incrementUnavailable, isTrue);
        expect(unknown.proposals.map((proposal) => proposal.loadKg), [
          32.0,
          48.0,
          64.0,
        ]);
      },
    );

    test(
      'handles bodyweight, very-light, malformed, and absent targets safely',
      () {
        final bodyweight = service.recommend(
          B02WarmupRequest(
            prescription: candidate(null, basis: B02LoadBasis.bodyweight),
          ),
        );
        expect(bodyweight.proposals.single.techniquePreparation, isTrue);
        expect(bodyweight.proposals.single.reps, inInclusiveRange(5, 10));
        expect(bodyweight.proposals.single.loadKg, isNull);

        final veryLight = service.recommend(
          B02WarmupRequest(
            prescription: candidate(1),
            incrementInput: const B02EquipmentIncrementInput(
              effectiveItemIncrementKg: 2.5,
            ),
          ),
        );
        expect(veryLight.proposals, isEmpty);
        expect(veryLight.reason, contains('already light'));

        final malformed = service.recommend(
          B02WarmupRequest(prescription: candidate(0)),
        );
        expect(malformed.availability, B02WarmupAvailability.unavailable);
        expect(malformed.proposals, isEmpty);

        final absent = service.recommend(const B02WarmupRequest());
        expect(absent.availability, B02WarmupAvailability.unavailable);
        expect(absent.reason, contains('No working target'));
      },
    );

    test(
      'explicit off suppresses the recommendation without inventing preference state',
      () {
        final off = service.recommend(
          B02WarmupRequest(
            preference: B02WarmupPreference.off,
            prescription: candidate(100),
          ),
        );
        expect(off.availability, B02WarmupAvailability.unavailable);
        expect(off.preference, B02WarmupPreference.off);
      },
    );

    test('draft codec round trips frozen warm-up evidence', () {
      final recommendation = service.recommend(
        B02WarmupRequest(
          preference: B02WarmupPreference.ask,
          requestedCount: 2,
          prescription: candidate(100),
          incrementInput: const B02EquipmentIncrementInput(
            effectiveItemIncrementKg: 2.5,
          ),
        ),
      );
      final state = draft(warmupRecommendation: recommendation);
      final restored = B02ExecutionDraftCodec.decode(
        B02ExecutionDraftCodec.encode(state),
      ).state!;
      expect(restored.warmupRecommendation!.toJson(), recommendation.toJson());
      expect(
        restored.warmupRecommendation!.preference,
        B02WarmupPreference.ask,
      );
    });
  });

  group('B02-07 rest service', () {
    test('applies the exact context precedence table', () {
      expect(
        rest
            .recommend(
              const B02RestSelectionRequest(
                scope: B02RestScope.exerciseSet,
                userSelectedSeconds: 70,
                prescribedSeconds: 80,
                exercisePreferenceSeconds: 100,
                templateDefaultRestSeconds: 120,
              ),
            )
            .selectedSeconds,
        70,
      );
      expect(
        rest
            .recommend(
              const B02RestSelectionRequest(
                scope: B02RestScope.exerciseSet,
                prescribedSeconds: 80,
                exercisePreferenceSeconds: 100,
                templateDefaultRestSeconds: 120,
              ),
            )
            .source,
        B02RestSource.prescription,
      );
      expect(
        rest
            .recommend(
              const B02RestSelectionRequest(
                scope: B02RestScope.groupRound,
                groupRestAfterRoundSeconds: 110,
                templateDefaultRestSeconds: 120,
              ),
            )
            .selectedSeconds,
        110,
      );
      expect(
        rest
            .recommend(
              const B02RestSelectionRequest(
                scope: B02RestScope.groupTransition,
              ),
            )
            .selectedSeconds,
        0,
      );
    });

    test(
      'applies bounded automatic RPE, failure, AMRAP, and fallback rules',
      () {
        expect(
          rest
              .recommend(
                const B02RestSelectionRequest(
                  scope: B02RestScope.exerciseSet,
                  rpe: 9,
                ),
              )
              .selectedSeconds,
          120,
        );
        expect(
          rest
              .recommend(
                const B02RestSelectionRequest(
                  scope: B02RestScope.exerciseSet,
                  rpe: 6,
                ),
              )
              .selectedSeconds,
          75,
        );
        expect(
          rest
              .recommend(
                const B02RestSelectionRequest(
                  scope: B02RestScope.exerciseSet,
                  effortMode: B02EffortMode.amrap,
                ),
              )
              .selectedSeconds,
          105,
        );
        expect(
          rest
              .recommend(
                const B02RestSelectionRequest(
                  scope: B02RestScope.exerciseSet,
                  endedAtFailure: true,
                ),
              )
              .explanation,
          contains('failure'),
        );
      },
    );

    test(
      'does not use a generic fallback for rest-pause and keeps overrides current-session only',
      () {
        final restPause = rest.recommend(
          const B02RestSelectionRequest(scope: B02RestScope.restPause),
        );
        expect(restPause.selectedSeconds, isNull);
        expect(restPause.source, B02RestSource.none);

        final override = rest.recommend(
          const B02RestSelectionRequest(
            scope: B02RestScope.exerciseSet,
            userSelectedSeconds: 301,
          ),
        );
        expect(override.selectedSeconds, 301);
        expect(override.source, B02RestSource.user);

        final overrideWinsOverMalformedFallback = rest.recommend(
          const B02RestSelectionRequest(
            scope: B02RestScope.exerciseSet,
            userSelectedSeconds: 135,
            prescribedSeconds: -1,
          ),
        );
        expect(overrideWinsOverMalformedFallback.selectedSeconds, 135);
        expect(overrideWinsOverMalformedFallback.source, B02RestSource.user);
      },
    );
  });

  group('B02-07 rest draft and persistence helpers', () {
    test(
      'rest draft survives selection, +30, finish, and wall-clock resume',
      () {
        const coordinator = B02RestDraftCoordinator();
        final initial = draft(restPeriods: [openRest()]);
        final selected = coordinator.select(initial, 'rest-1', 100);
        final extended = coordinator.extend(selected, 'rest-1');
        expect(
          B02RestTimerSnapshot(
            extended.restPeriods.single,
          ).remainingSeconds(DateTime.utc(2026, 8, 1, 10, 1)),
          70,
        );
        final finished = coordinator.finish(
          extended,
          'rest-1',
          endedAtUtc: DateTime.utc(2026, 8, 1, 10, 1, 45),
          endReason: B02RestEndReason.elapsed,
        );
        final period = finished.restPeriods.single;
        expect(period.selectedSeconds, 130);
        expect(period.actualSeconds, 105);
        expect(period.endReason, B02RestEndReason.elapsed);
        expect(
          B02RestTimerSnapshot(
            period,
          ).remainingSeconds(DateTime.utc(2026, 8, 1, 10, 1)),
          0,
        );

        final restored = B02ExecutionDraftCodec.decode(
          B02ExecutionDraftCodec.encode(finished),
        ).state!;
        expect(restored.restPeriods.single.actualSeconds, 105);
      },
    );

    test('rest persistence helper round trips typed fields', () {
      final period = B02RestPeriod(
        id: 'rest-2',
        performedExerciseGroupId: 'group-1',
        scope: B02RestScope.groupRound,
        recommendedSeconds: 90,
        selectedSeconds: 100,
        actualSeconds: 95,
        source: B02RestSource.user,
        startedAtUtc: DateTime.utc(2026, 8, 1, 10),
        endedAtUtc: DateTime.utc(2026, 8, 1, 10, 1, 35),
        endReason: B02RestEndReason.skipped,
      );
      final companion = B02RestPeriodPersistence.toCompanion(
        period,
        sessionId: 7,
      );
      final row = PerformedRestPeriod(
        id: companion.id.value,
        sessionId: companion.sessionId.value,
        performedSetId: companion.performedSetId.value,
        performedExerciseGroupId: companion.performedExerciseGroupId.value,
        scope: companion.scope.value,
        recommendedSeconds: companion.recommendedSeconds.value,
        selectedSeconds: companion.selectedSeconds.value,
        actualSeconds: companion.actualSeconds.value,
        source: companion.source.value,
        startedAtUtc: companion.startedAtUtc.value,
        endedAtUtc: companion.endedAtUtc.value,
        endReason: companion.endReason.value,
      );
      expect(B02RestPeriodPersistence.fromRow(row).toJson(), period.toJson());
    });
  });

  group('B02-07 execution preference repository', () {
    testWidgets('reads and explicitly persists warm-up/rest settings', (
      tester,
    ) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: const Value('exercise-1'),
              name: 'Bench',
              muscleGroups: 'Chest',
              equipment: 'barbell',
              difficulty: 'intermediate',
              formCues: '',
              commonMistakes: '',
            ),
          );
      final repository = ExercisePreferenceRepository(db);
      expect(
        await repository.getExecutionPreference(stableId: 'exercise-1'),
        isNull,
      );
      await repository.saveExecutionPreference(
        stableId: 'exercise-1',
        warmupPreference: B02WarmupPreference.ask,
        warmupSetCount: 4,
        customRestSeconds: 120,
      );
      final saved = await repository.getExecutionPreference(
        stableId: 'exercise-1',
      );
      expect(saved!.warmupPreference, B02WarmupPreference.ask);
      expect(saved.warmupSetCount, 4);
      expect(saved.customRestSeconds, 120);
    });
  });
}
