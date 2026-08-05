import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/data/models/b02_progress_read_models.dart';
import 'package:indifit/data/models/b04_adaptive_target_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/models/b04_recommendation_context_models.dart';
import 'package:indifit/data/models/b04_recovery_models.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/services/b04_meal_opportunity_service.dart';
import 'package:indifit/data/services/b04_recommendation_context_assembler.dart';

const userId = 'user-a';
const timezoneId = 'America/New_York';

void main() {
  const timezoneId = 'America/New_York';
  const userId = 'user-a';
  final evaluatedAt = DateTime.utc(2026, 3, 8, 12);
  final assembler = B04RecommendationContextAssembler();
  final opportunities = B04MealOpportunityService();

  test('daily context freezes target, lineage, local date, and N8 absence', () {
    final selected = opportunities.create(
      currentInstantUtc: evaluatedAt,
      timezoneId: timezoneId,
      kind: B04MealOpportunityKind.now,
      candidates: const [
        B04MealCandidate(
          selectionId: 'selection-1',
          source: B04MealCandidateSource.canonicalFood,
          subjectId: 'food-1',
        ),
      ],
    );
    final context = assembler.assemble(
      _input(
        period: B04RecommendationPeriod.daily,
        startLocalDate: '2026-03-08',
        endLocalDate: '2026-03-08',
        nutritionDays: [_daily('2026-03-08')],
        mealOpportunity: selected,
      ),
    );

    expect(context.window.startLocalDate, '2026-03-08');
    expect(context.window.timezoneId, timezoneId);
    expect(context.window.targetEvaluationWindowDays, 21);
    expect(context.window.aggregateWindowDays, 42);
    expect(context.activeGoal!.id, 'goal-v7');
    expect(
      context.targetResult!.policyVersion,
      B04AdaptiveTargetPolicy.current.policyVersion,
    );
    expect(context.nutrition.days.single.recordIds, ['snapshot-1']);
    expect(context.mealOpportunity!.hasSelection, isTrue);
    expect(context.n8.state, 'absent');
    expect(context.missingEvidence, isEmpty);
    expect(context.availability, B04ContextAvailability.available);
  });

  test('weekly context uses seven civil dates across DST', () {
    final context = assembler.assemble(
      _input(
        period: B04RecommendationPeriod.weekly,
        startLocalDate: '2026-03-08',
        endLocalDate: '2026-03-14',
        nutritionDays: [
          for (var day = 8; day <= 14; day++)
            _daily('2026-03-${day.toString().padLeft(2, '0')}'),
        ],
      ),
    );

    expect(context.window.period, B04RecommendationPeriod.weekly);
    expect(context.nutrition.expectedLocalDates, [
      '2026-03-08',
      '2026-03-09',
      '2026-03-10',
      '2026-03-11',
      '2026-03-12',
      '2026-03-13',
      '2026-03-14',
    ]);
    expect(context.nutrition.missingLocalDates, isEmpty);
  });

  test('weekly context rejects a non-seven-day civil range', () {
    expect(
      () => assembler.assemble(
        _input(
          period: B04RecommendationPeriod.weekly,
          startLocalDate: '2026-03-08',
          endLocalDate: '2026-03-15',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('unknown nutrition totals remain unknown and evidence-limited', () {
    final context = assembler.assemble(
      _input(
        nutritionDays: [
          _daily('2026-03-08', state: NutrientCompletenessState.unknown),
        ],
      ),
    );

    expect(context.availability, B04ContextAvailability.evidenceLimited);
    expect(context.nutrition.days.single.totals.facts, isEmpty);
    expect(
      context.missingEvidence.map((item) => item.reasonCode),
      contains('daily_totals_unknown'),
    );
    expect(context.toRedactedMap()['nutrition'], isNot(contains('0')));
  });

  test('no candidate is explicit unavailable state, never inferred', () {
    final opportunity = opportunities.create(
      currentInstantUtc: evaluatedAt,
      timezoneId: timezoneId,
      kind: B04MealOpportunityKind.now,
      candidates: const [],
    );
    final context = assembler.assemble(_input(mealOpportunity: opportunity));

    expect(opportunity.status, B04MealOpportunityStatus.noCandidate);
    expect(opportunity.reasonCode, 'no_explicit_candidate');
    expect(context.mealOpportunity!.candidates, isEmpty);
    expect(
      context.missingEvidence.any(
        (item) => item.kind == B04MissingEvidenceKind.mealOpportunity,
      ),
      isTrue,
    );
  });

  test(
    'explicit opportunity preserves local date across a cross-midnight boundary',
    () {
      final opportunity = opportunities.create(
        currentInstantUtc: DateTime.utc(2026, 1, 1, 23, 30),
        timezoneId: 'Asia/Kolkata',
        kind: B04MealOpportunityKind.plannedMeal,
        explicitMealCategory: 'dinner',
        candidates: const [
          B04MealCandidate(
            selectionId: 'recipe-selection',
            source: B04MealCandidateSource.publishedRecipeVersion,
            subjectId: 'recipe-v4',
          ),
        ],
      );

      expect(opportunity.status, B04MealOpportunityStatus.available);
      expect(opportunity.localDate, '2026-01-02');
      expect(opportunity.timezoneId, 'Asia/Kolkata');
      expect(opportunity.candidates.single.subjectId, 'recipe-v4');
    },
  );

  test(
    'absence of opportunity, legacy source, and non-UTC input fail safely',
    () {
      final absent = opportunities.create(
        currentInstantUtc: evaluatedAt,
        timezoneId: timezoneId,
        kind: null,
        candidates: const [],
      );
      expect(absent.status, B04MealOpportunityStatus.unavailable);
      expect(absent.reasonCode, 'explicit_opportunity_required');

      expect(
        () => B04MealCandidate.fromSourceId(
          selectionId: 'legacy',
          sourceId: 'legacy_food_log',
          subjectId: 'food-log-1',
        ),
        throwsArgumentError,
      );
      expect(
        () => opportunities.create(
          currentInstantUtc: DateTime(2026, 3, 8, 12),
          timezoneId: timezoneId,
          kind: B04MealOpportunityKind.now,
          candidates: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => opportunities.create(
          currentInstantUtc: evaluatedAt,
          timezoneId: timezoneId,
          kind: B04MealOpportunityKind.now,
          candidates: const [
            B04MealCandidate(
              selectionId: '',
              source: B04MealCandidateSource.canonicalFood,
              subjectId: 'food-1',
            ),
          ],
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'redacted context excludes identity and raw/provider-style payloads',
    () {
      final context = assembler.assemble(
        _input(
          mealOpportunity: opportunities.create(
            currentInstantUtc: evaluatedAt,
            timezoneId: timezoneId,
            kind: B04MealOpportunityKind.now,
            candidates: const [
              B04MealCandidate(
                selectionId: 'selection-1',
                source: B04MealCandidateSource.canonicalFood,
                subjectId: 'food-1',
              ),
            ],
          ),
        ),
      );
      final redacted = context.toRedactedMap();
      final encoded = jsonEncode(redacted);

      expect(redacted.containsKey('user_id'), isFalse);
      expect(encoded, isNot(contains(userId)));
      expect(encoded, isNot(contains('displayLabel')));
      expect(encoded, isNot(contains('prompt')));
      expect(encoded, isNot(contains('image')));
      expect(encoded, isNot(contains('health_payload')));
      expect(encoded, isNot(contains('holiday')));
      expect(encoded, isNot(contains('restaurant')));
      expect(encoded, isNot(contains('food_history')));
      expect(redacted['n8'], {'state': 'absent'});
    },
  );

  test(
    'replaying the same frozen inputs produces the same redacted context',
    () {
      final input = _input(
        mealOpportunity: opportunities.create(
          currentInstantUtc: evaluatedAt,
          timezoneId: timezoneId,
          kind: B04MealOpportunityKind.now,
          candidates: const [
            B04MealCandidate(
              selectionId: 'selection-1',
              source: B04MealCandidateSource.canonicalFood,
              subjectId: 'food-1',
            ),
          ],
        ),
      );

      expect(
        assembler.assemble(input).toRedactedMap(),
        assembler.assemble(input).toRedactedMap(),
      );
    },
  );
}

B04RecommendationContextInput _input({
  B04RecommendationPeriod period = B04RecommendationPeriod.daily,
  String startLocalDate = '2026-03-08',
  String endLocalDate = '2026-03-08',
  List<NutritionDailyReadModel>? nutritionDays,
  B04MealOpportunity? mealOpportunity,
}) {
  return B04RecommendationContextInput(
    contextId: 'context-1',
    userId: userId,
    period: period,
    startLocalDate: startLocalDate,
    endLocalDate: endLocalDate,
    timezoneId: timezoneId,
    evaluatedAtUtc: DateTime.utc(2026, 3, 8, 12),
    activeGoal: NutritionGoalVersionReadModel(
      id: 'goal-v7',
      userId: userId,
      versionNumber: 7,
      goalType: NutritionGoalType.maintenance,
      source: NutritionGoalSource.userSet,
      calorieTargetKcal: 2000,
      proteinTargetG: 120,
      carbsTargetG: 240,
      fatTargetG: 70,
      policyVersion: B04AdaptiveTargetPolicy.current.policyVersion,
      calculationVersion: B04AdaptiveTargetPolicy.current.calculationVersion,
      algorithmVersion: B04AdaptiveTargetPolicy.current.algorithmVersion,
      effectiveFromLocalDate: '2026-03-01',
      effectiveToLocalDate: null,
      timezoneId: timezoneId,
      supersedesGoalVersionId: null,
      evidenceFingerprint: 'goal-fingerprint',
      exactResultNumerator: null,
      exactResultDenominator: null,
      normalizedMaintenanceKcal: 2000,
      createdAtUtc: DateTime.utc(2026, 3, 1, 12),
    ),
    preferences: const CoachingPreferencesReadModel(
      userId: userId,
      adaptiveCoachingEnabled: true,
      optionalAiEnabled: false,
      adaptiveCoachingEvent: null,
      optionalAiEvent: null,
    ),
    eligibility: CoachingEligibilityReadModel(
      userId: userId,
      result: CoachingEligibilityResult.eligible,
      reasonCode: 'eligible',
      policyVersion: 'B04-05-ELIGIBILITY-V1',
      evaluationLocalDate: '2026-03-08',
      timezoneId: timezoneId,
      evaluationUtc: DateTime.utc(2026, 3, 8, 12),
    ),
    readinessSnapshot: ReadinessSnapshotReadModel(
      id: 'readiness-1',
      userId: userId,
      localDate: startLocalDate,
      timezoneId: timezoneId,
      completeness: ReadinessCompleteness.complete,
      status: ReadinessStatus.available,
      band: ReadinessBand.ready,
      confidence: 0.9,
      calculationVersion: 'B04-06-READINESS-V1',
      policyVersion: 'READINESS-HOLD-1',
      unavailableReason: null,
      evidenceFingerprint: 'readiness-fingerprint',
      createdAtUtc: DateTime.utc(2026, 3, 8, 12),
      supersededAtUtc: null,
      supersedesSnapshotId: null,
    ),
    progress: B02ProgressReadModel(
      query: B02ProgressQuery(
        startLocalDate: startLocalDate,
        endLocalDate: endLocalDate,
        timezoneId: timezoneId,
      ),
      activityHistory: const [],
      groupHistory: const [],
      targetEvidence: const [],
      muscleVolume: null,
    ),
    schedule: const CalendarReadSnapshot(
      rangeOccurrences: [],
      overdueOccurrences: [],
      activeProgramVersionId: 'program-v1',
      activeProgramName: 'Hidden from context',
    ),
    nutritionDays: nutritionDays ?? [_daily(startLocalDate)],
    constraintEvaluations: const [],
    targetResult: B04AdaptiveTargetResult(
      status: B04AdaptiveTargetStatus.onTrack,
      reasonCode: 'target_on_track',
      policyVersion: B04AdaptiveTargetPolicy.current.policyVersion,
      calculationVersion: B04AdaptiveTargetPolicy.current.calculationVersion,
      algorithmVersion: B04AdaptiveTargetPolicy.current.algorithmVersion,
      direction: B04AdaptiveTargetDirection.onTrack,
      adaptiveDeltaKcal: 0,
      currentTargetKcal: 2000,
      proposedTargetKcal: null,
      normalizedMaintenanceKcal: 2000,
      medianWeightGrams: null,
      slopeGramsPerDay: null,
      weeklyRatePercent: null,
      displayWeeklyRatePercent: null,
      evidenceIds: const ['weight-1', 'nutrition-1'],
      proposal: null,
      trainingOverlay: B04TrainingOverlayResult.unavailable,
    ),
    mealOpportunity: mealOpportunity,
  );
}

NutritionDailyReadModel _daily(
  String localDate, {
  NutrientCompletenessState state = NutrientCompletenessState.complete,
}) => NutritionDailyReadModel(
  userId: userId,
  localDate: localDate,
  records: const [],
  recordIds: const ['snapshot-1'],
  totals: NutrientAggregationResult(
    facts: const {},
    completeness: NutrientCompleteness(
      state: state,
      requestedNutrientIds: const ['energy'],
      availableNutrientIds: const [],
      missingNutrientIds: const ['energy'],
      estimatedNutrientIds: const [],
      notApplicableNutrientIds: const [],
      partiallyKnownNutrientIds: const [],
    ),
    sourceLineage: const {},
    factVersionLineage: const {},
  ),
  sourceCounts: const {'canonical_snapshot': 1},
  issues: const [],
);
