import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_adaptive_target_models.dart';
import 'package:indifit/data/models/b04_briefing_read_models.dart';
import 'package:indifit/data/models/b04_current_food_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/models/b04_recommendation_history_models.dart';
import 'package:indifit/data/models/b04_recommendation_models.dart';
import 'package:indifit/data/repositories/coaching_preference_repository.dart';
import 'package:indifit/data/repositories/nutrition_goal_repository.dart';
import 'package:indifit/features/coaching/b04_production_surface_controller.dart';
import 'package:indifit/features/coaching/b04_production_surface_widgets.dart';
import 'package:indifit/features/dashboard/b04_daily_briefing_controller.dart';
import 'package:indifit/features/nutrition/current_food_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() => db.close());

  test(
    'settings controller is default-off, preserves age uncertainty, and saves a version',
    () async {
      final goals = NutritionGoalRepository(database: db);
      final preferences = CoachingPreferenceRepository(
        database: db,
        nowUtc: () => DateTime.utc(2026, 8, 6, 10),
      );
      await goals.ensureCompatibilityImport(
        userId: 'user-a',
        legacyProfile: const NutritionGoalCommand(
          userId: 'user-a',
          goalType: NutritionGoalType.maintenance,
          calorieTargetKcal: 2000,
          proteinTargetG: 140,
          carbsTargetG: 220,
          fatTargetG: 60,
          effectiveFromLocalDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
        ),
      );
      final controller = B04GoalSettingsController(
        loadContext: () async => const B04ProductionUserContext(
          userId: 'user-a',
          localDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
        ),
        goals: goals,
        preferences: preferences,
        dates: _dates,
        nowUtc: () => DateTime.utc(2026, 8, 6, 10),
      );

      await controller.load();
      expect(controller.state.status, B04GoalSettingsStatus.ready);
      expect(
        controller.state.availability!.preferences.adaptiveCoachingEnabled,
        isFalse,
      );
      expect(
        controller.state.availability!.reasonCode,
        'coaching_consent_required',
      );

      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'age-withheld',
              userId: 'user-a',
              result: 'withheld_age',
              reasonCode: 'withheld_age',
              ageInputSource: 'withheld',
              evidenceTimestampUtc: DateTime.utc(2026, 8, 6, 9),
              evaluationUtc: DateTime.utc(2026, 8, 6, 9),
              evaluationLocalDate: '2026-08-06',
              timezoneId: 'Asia/Kolkata',
              policyVersion: kB04HoldPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
            ),
          );
      await controller.setAdaptiveConsent(CoachingConsentAction.enable);
      expect(controller.state.consentHistory, hasLength(1));
      expect(
        controller.state.availability!.preferences.adaptiveCoachingEnabled,
        isTrue,
      );
      expect(controller.state.availability!.reasonCode, 'withheld_age');
      expect(
        controller.state.consentHistory.single.consentPolicyVersion,
        kB04AdaptiveConsentPolicyVersion,
      );
      expect(
        controller.state.consentHistory.single.copyVersion,
        kB04AdaptiveConsentCopyVersion,
      );

      await controller.setAdaptiveConsent(CoachingConsentAction.disable);
      expect(
        controller.state.availability!.preferences.adaptiveCoachingEnabled,
        isFalse,
      );
      expect(controller.state.consentHistory, hasLength(2));

      await controller.setAdaptiveConsent(CoachingConsentAction.enable);
      await controller.setAdaptiveConsent(CoachingConsentAction.withdraw);
      expect(
        controller.state.availability!.preferences.adaptiveCoachingEnabled,
        isFalse,
      );
      expect(controller.state.consentHistory, hasLength(4));

      await controller.saveUserSetGoal(
        goalType: NutritionGoalType.loss,
        calorieTargetKcal: 400,
        proteinTargetG: 90,
        carbsTargetG: 40,
        fatTargetG: 20,
      );
      expect(controller.state.activeGoal!.source, NutritionGoalSource.userSet);
      expect(controller.state.activeGoal!.calorieTargetKcal, 400);
      expect(controller.state.goalHistory, hasLength(2));
      expect(
        b04ProductionStateCopy(controller.state.availability!.reasonCode),
        contains('unavailable'),
      );

      controller.dispose();
    },
  );

  test(
    'unknown age remains unavailable without punitive wording while user goals stay readable',
    () async {
      final goals = NutritionGoalRepository(database: db);
      final preferences = CoachingPreferenceRepository(
        database: db,
        nowUtc: () => DateTime.utc(2026, 8, 6, 10, 0, 1),
      );
      await goals.recordUserSetGoal(
        const NutritionGoalCommand(
          userId: 'user-a',
          goalType: NutritionGoalType.maintenance,
          calorieTargetKcal: 2100,
          proteinTargetG: 140,
          carbsTargetG: 220,
          fatTargetG: 70,
          effectiveFromLocalDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
        ),
      );
      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'age-unknown',
              userId: 'user-a',
              result: 'unknown_age',
              reasonCode: 'unknown_age',
              ageInputSource: 'unknown',
              evidenceTimestampUtc: DateTime.utc(2026, 8, 6, 9),
              evaluationUtc: DateTime.utc(2026, 8, 6, 9),
              evaluationLocalDate: '2026-08-06',
              timezoneId: 'Asia/Kolkata',
              policyVersion: kB04HoldPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
            ),
          );
      await preferences.recordConsent(
        CoachingConsentCommand(
          userId: 'user-a',
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: kB04AdaptiveConsentPolicyVersion,
          copyVersion: kB04AdaptiveConsentCopyVersion,
          timestampUtc: DateTime.utc(2026, 8, 6, 10),
          localDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
          actorSource: 'test',
        ),
      );
      final availability = await preferences.adaptiveAvailability(
        userId: 'user-a',
      );

      expect(availability.available, isFalse);
      expect(availability.reasonCode, 'unknown_age');
      expect(
        b04ProductionStateCopy('unknown_age'),
        allOf(contains('unavailable'), isNot(contains('punitive'))),
      );
      expect(
        (await goals.activeGoal(
          userId: 'user-a',
          localDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
        ))!.calorieTargetKcal,
        2100,
      );
    },
  );

  testWidgets('unavailable policy state exposes reason and compact semantics', (
    tester,
  ) async {
    const read = B04DailyBriefingReadModel(
      scope: B04RecommendationHistoryScope.daily,
      userId: 'user-a',
      startLocalDate: '2026-08-06',
      endLocalDate: '2026-08-06',
      timezoneId: 'Asia/Kolkata',
      status: B04BriefingReadStatus.unavailable,
      unavailableReasons: ['adaptive_policy_hold'],
      eligibilityState: null,
      consentState: null,
      policyState: B04RecommendationPolicyState.hold,
      missingEvidence: ['adaptive_policy_hold'],
      recommendations: [],
      lowRiskWarnings: [],
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: B04DailyBriefingContent(
              state: const B04DailyBriefingState(
                status: B04DailyBriefingControllerStatus.unavailable,
                briefing: read,
              ),
              onRetry: _noop,
              onAction: _ignoreAction,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('policy is on hold'), findsOneWidget);
    expect(find.text('Record override'), findsNothing);
    expect(tester.takeException(), isNull);
    final semantics = tester.ensureSemantics();
    try {
      expect(find.bySemanticsLabel(RegExp('Today’s coaching')), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'safety-sensitive current-food unavailable state cannot be bypassed',
    (tester) async {
      final guidance = B04CurrentFoodGuidance(
        status: B04CurrentFoodGuidanceStatus.unavailable,
        userId: 'user-a',
        localDate: '2026-08-06',
        timezoneId: 'Asia/Kolkata',
        evaluatedAtUtc: DateTime.utc(2026, 8, 6, 10),
        remainingTargets: B04RemainingTargetReadModel(
          userId: 'user-a',
          localDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
          goalVersionId: 'goal-v1',
          goalSource: 'user_set',
          goalEffectiveFromLocalDate: '2026-08-01',
          targets: const [],
        ),
        recommendationEvaluation: null,
        reasonCodes: const ['dietary_safety_evidence_missing'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: B04CurrentFoodContent(
              state: B04CurrentFoodState(
                status: B04CurrentFoodControllerStatus.unavailable,
                guidance: guidance,
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Safety-sensitive guidance is unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('safe'), findsNothing);
      expect(find.text('Override'), findsNothing);
    },
  );

  testWidgets(
    'available briefing renders canonical exact result and only model-approved target action',
    (tester) async {
      final recommendation = B04BriefingRecommendation(
        id: 'recommendation-1',
        action: 'nutrition_target',
        state: B04RecommendationState.confirm,
        priority: B04RecommendationPriority.nutrition,
        rationaleCode: 'canonical_target',
        confidence: B04RecommendationConfidence.high,
        completeness: B04RecommendationCompleteness.complete,
        explanation: 'A target proposal is available for your review.',
        alternatives: const [],
        missingEvidence: const [],
        uncertainty: const [],
        evidenceIds: const ['goal-v1', 'policy-v1'],
        goalVersionId: 'goal-v1',
        readinessSnapshotId: null,
        consentEventId: 'consent-1',
        eligibilityEvaluationId: 'eligibility-1',
        policyVersion: 'B04-D04-ENABLED-1',
        calculationVersion: 'calc-v1',
        ruleVersion: 'rule-v1',
        algorithmVersion: 'algorithm-v1',
        modelVersion: null,
        providerVersion: null,
        copyVersion: 'copy-v1',
        eligibilityState: B04RecommendationEligibilityState.eligible,
        consentState: B04RecommendationConsentState.enabled,
        canonicalResult: const B04BriefingNumericalResult(
          exactResultNumerator: '1750',
          exactResultDenominator: '1',
          normalizedMaintenanceKcal: 2000,
          proposedDeltaKcal: -100,
        ),
        targetAcceptanceState:
            B04BriefingTargetAcceptanceState.proposalAvailable,
        feedbackState: B04BriefingFeedbackState.untouched,
        feedback: const [],
        isVisible: true,
        engineRecommendation: _engineTargetRecommendation(),
        historicalRecommendation: null,
      );
      final read = B04BriefingReadModel(
        scope: B04RecommendationHistoryScope.daily,
        userId: 'user-a',
        startLocalDate: '2026-08-06',
        endLocalDate: '2026-08-06',
        timezoneId: 'Asia/Kolkata',
        status: B04BriefingReadStatus.available,
        unavailableReasons: const [],
        eligibilityState: B04RecommendationEligibilityState.eligible,
        consentState: B04RecommendationConsentState.enabled,
        policyState: B04RecommendationPolicyState.enabled,
        missingEvidence: const [],
        recommendations: [recommendation],
        lowRiskWarnings: const [],
      );
      final actions = <B04RecommendationFeedbackAction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: B04DailyBriefingContent(
              state: B04DailyBriefingState(
                status: B04DailyBriefingControllerStatus.ready,
                briefing: read,
              ),
              onRetry: _noop,
              onAction: (recommendation, action) async => actions.add(action),
            ),
          ),
        ),
      );
      expect(find.textContaining('Exact result: 1750/1'), findsOneWidget);
      expect(find.text('Eligibility: Eligible'), findsOneWidget);
      expect(find.text('Accept target'), findsOneWidget);
      await tester.tap(find.text('Accept target'));
      expect(actions, contains(B04RecommendationFeedbackAction.accept));
    },
  );
}

final _dates = LocalScheduleDateService();

B04Recommendation _engineTargetRecommendation() {
  final target = B04AdaptiveTargetResult(
    status: B04AdaptiveTargetStatus.available,
    reasonCode: 'proposal_available',
    policyVersion: kB04EnabledPolicyVersion,
    calculationVersion: 'calc-v1',
    algorithmVersion: 'algorithm-v1',
    direction: B04AdaptiveTargetDirection.decreaseCalories,
    adaptiveDeltaKcal: -100,
    currentTargetKcal: 1850,
    proposedTargetKcal: 1750,
    normalizedMaintenanceKcal: 2000,
    medianWeightGrams: null,
    slopeGramsPerDay: null,
    weeklyRatePercent: null,
    displayWeeklyRatePercent: '-0.50%',
    evidenceIds: const ['goal-v1', 'policy-v1'],
    proposal: const AdaptiveGoalProposal(
      id: 'proposal-1',
      userId: 'user-a',
      goalType: NutritionGoalType.loss,
      goalRate: 'loss:-0.50% body weight/week',
      calorieTargetKcal: 1750,
      proteinTargetG: 90,
      carbsTargetG: 40,
      fatTargetG: 20,
      policyVersion: kB04EnabledPolicyVersion,
      calculationVersion: 'calc-v1',
      algorithmVersion: 'algorithm-v1',
      effectiveFromLocalDate: '2026-08-06',
      timezoneId: 'Asia/Kolkata',
      evidenceFingerprint: 'proposal-evidence',
      exactResultNumerator: '1750',
      exactResultDenominator: '1',
      normalizedMaintenanceKcal: 2000,
    ),
    trainingOverlay: B04TrainingOverlayResult.unavailable,
  );
  return B04Recommendation(
    id: 'recommendation-1',
    action: B04RecommendationAction.nutritionTarget,
    state: B04RecommendationState.confirm,
    priority: B04RecommendationPriority.nutrition,
    rationaleCode: 'canonical_target',
    explanation: 'A target proposal is available for your review.',
    confidence: B04RecommendationConfidence.high,
    completeness: B04RecommendationCompleteness.complete,
    evidenceIds: const ['goal-v1', 'policy-v1'],
    eligibilityState: B04RecommendationEligibilityState.eligible,
    consentState: B04RecommendationConsentState.enabled,
    policyState: B04RecommendationPolicyState.enabled,
    policyVersion: kB04EnabledPolicyVersion,
    ruleVersion: 'rule-v1',
    algorithmVersion: 'algorithm-v1',
    copyVersion: 'copy-v1',
    targetAcceptanceState:
        B04RecommendationTargetAcceptanceState.proposalAvailable,
    canonicalAdaptiveTarget: target,
    canonicalTrainingRecommendation: null,
    safetyDisposition: null,
  );
}

void _noop() {}

Future<void> _ignoreAction(
  B04BriefingRecommendation recommendation,
  B04RecommendationFeedbackAction action,
) async {}
