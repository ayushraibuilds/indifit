import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_adaptive_target_models.dart';
import 'package:indifit/data/models/b04_briefing_read_models.dart';
import 'package:indifit/data/models/b04_current_food_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/models/b04_nutrition_safety_models.dart';
import 'package:indifit/data/models/b04_recommendation_context_models.dart';
import 'package:indifit/data/models/b04_recommendation_history_models.dart';
import 'package:indifit/data/models/b04_recommendation_models.dart';
import 'package:indifit/data/repositories/b04_briefing_read_repositories.dart';
import 'package:indifit/data/repositories/b04_recommendation_history_repository.dart';
import 'package:indifit/data/repositories/coaching_preference_repository.dart';
import 'package:indifit/data/repositories/nutrition_goal_repository.dart';
import 'package:indifit/features/coaching/b04_production_surface_controller.dart';
import 'package:indifit/features/coaching/b04_production_surface_widgets.dart';
import 'package:indifit/features/dashboard/b04_daily_briefing_controller.dart';
import 'package:indifit/features/nutrition/current_food_controller.dart';
import 'package:indifit/features/progress/b04_weekly_review_controller.dart';

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

      await preferences.recordConsent(
        CoachingConsentCommand(
          userId: 'user-a',
          category: CoachingConsentCategory.optionalAi,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: kB04AdaptiveConsentPolicyVersion,
          copyVersion: kB04AdaptiveConsentCopyVersion,
          timestampUtc: DateTime.utc(2026, 8, 6, 9, 30),
          localDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
          actorSource: 'test',
        ),
      );

      await controller.load();
      expect(controller.state.status, B04GoalSettingsStatus.ready);
      expect(controller.state.consentHistory, isEmpty);
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
      final goalBeforeNoOp = controller.state.activeGoal;
      await controller.setAdaptiveConsent(CoachingConsentAction.enable);
      expect(controller.state.consentHistory, hasLength(1));
      expect(controller.state.activeGoal, same(goalBeforeNoOp));

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
      expect(controller.state.activeGoal!.calorieTargetKcal, 2000);
      expect(controller.state.goalHistory, hasLength(1));

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
        startsWith('Add your date of birth'),
      );

      controller.dispose();
    },
  );

  test(
    'unknown age remains unknown while user goals stay readable',
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
        allOf(
          startsWith('Add your date of birth'),
          isNot(contains('unavailable for this age')),
          isNot(contains('ineligible')),
        ),
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

  test(
    'settings controller appends invalid and corrected age evidence through production state',
    () async {
      final preferences = CoachingPreferenceRepository(
        database: db,
        dates: _dates,
        nowUtc: () => DateTime.utc(2026, 8, 6, 10),
      );
      final controller = B04GoalSettingsController(
        loadContext: () async => const B04ProductionUserContext(
          userId: 'user-a',
          localDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
        ),
        goals: NutritionGoalRepository(database: db, dates: _dates),
        preferences: preferences,
        dates: _dates,
        nowUtc: () => DateTime.utc(2026, 8, 6, 10),
      );

      await controller.load();
      await controller.recordEligibility(dateOfBirthLocalDate: '2000-02-30');
      expect(
        controller.state.availability!.eligibility!.result,
        CoachingEligibilityResult.invalidEvidence,
      );

      await controller.recordEligibility(dateOfBirthLocalDate: '2000-02-29');
      expect(
        controller.state.availability!.eligibility!.result,
        CoachingEligibilityResult.eligible,
      );
      expect(
        await db.select(db.coachingEligibilityEvaluations).get(),
        hasLength(2),
      );
      controller.dispose();
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
    expect(
      find.textContaining('Coaching suggestions are unavailable'),
      findsOneWidget,
    );
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
        find.textContaining('I need more dietary information'),
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
      expect(
        find.textContaining('Suggested change: -100 kcal/day'),
        findsOneWidget,
      );
      expect(find.textContaining('Daily estimate: 2000 kcal'), findsOneWidget);
      expect(find.text('Accept target'), findsOneWidget);
      expect(find.byType(B05ActionButton), findsNWidgets(4));
      expect(
        tester.getSize(find.byType(B05TouchTarget).first).height,
        greaterThanOrEqualTo(B05Layout.minTouchTarget),
      );
      await tester.tap(find.text('Accept target'));
      expect(actions, contains(B04RecommendationFeedbackAction.accept));
    },
  );

  testWidgets('dismissed briefing projections are not rendered', (
    tester,
  ) async {
    final dismissed = B04BriefingRecommendation(
      id: 'dismissed-recommendation',
      action: 'education',
      state: B04RecommendationState.dismissed,
      priority: B04RecommendationPriority.education,
      rationaleCode: 'dismissed',
      confidence: B04RecommendationConfidence.high,
      completeness: B04RecommendationCompleteness.complete,
      explanation: 'This explanation must not be shown after dismissal.',
      alternatives: const [],
      missingEvidence: const [],
      uncertainty: const [],
      evidenceIds: const ['evidence-1'],
      goalVersionId: null,
      readinessSnapshotId: null,
      consentEventId: null,
      eligibilityEvaluationId: null,
      policyVersion: null,
      calculationVersion: null,
      ruleVersion: null,
      algorithmVersion: null,
      modelVersion: null,
      providerVersion: null,
      copyVersion: null,
      eligibilityState: null,
      consentState: null,
      canonicalResult: null,
      targetAcceptanceState: B04BriefingTargetAcceptanceState.notApplicable,
      feedbackState: B04BriefingFeedbackState.dismissed,
      feedback: const [],
      isVisible: false,
      engineRecommendation: null,
      historicalRecommendation: null,
    );
    final read = B04DailyBriefingReadModel(
      scope: B04RecommendationHistoryScope.daily,
      userId: 'user-a',
      startLocalDate: '2026-08-06',
      endLocalDate: '2026-08-06',
      timezoneId: 'Asia/Kolkata',
      status: B04BriefingReadStatus.available,
      unavailableReasons: const [],
      eligibilityState: null,
      consentState: null,
      policyState: null,
      missingEvidence: const [],
      recommendations: [dismissed],
      lowRiskWarnings: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: B04DailyBriefingContent(
            state: B04DailyBriefingState(
              status: B04DailyBriefingControllerStatus.ready,
              briefing: read,
            ),
            onRetry: _noop,
            onAction: _ignoreAction,
          ),
        ),
      ),
    );

    expect(find.text('Nothing to recommend yet.'), findsOneWidget);
    expect(
      find.text('This explanation must not be shown after dismissal.'),
      findsNothing,
    );
  });

  testWidgets('current-food surface exposes ranges and candidate evidence', (
    tester,
  ) async {
    final remaining = B04RemainingTargetReadModel(
      userId: 'user-a',
      localDate: '2026-08-06',
      timezoneId: 'Asia/Kolkata',
      goalVersionId: 'goal-v1',
      goalSource: 'user_set',
      goalEffectiveFromLocalDate: '2026-08-01',
      targets: [
        B04CurrentFoodNutrientValue(
          nutrientId: 'energy',
          unit: NutrientUnit.kilocalorie,
          state: B04CurrentFoodValueState.known,
          point: '1200',
          sourceType: 'b03_daily_totals',
          sourceIds: const ['totals-v1'],
        ),
        B04CurrentFoodNutrientValue(
          nutrientId: 'protein',
          unit: NutrientUnit.gram,
          state: B04CurrentFoodValueState.range,
          lower: '40',
          upper: '60',
          sourceType: 'b03_daily_totals',
          sourceIds: const ['totals-v1'],
        ),
      ],
    );
    final card = B04CurrentFoodCandidateCard(
      selectionId: 'food-1',
      subjectId: 'food-1',
      source: B04MealCandidateSource.canonicalFood,
      displayLabel: 'Local bowl',
      recommendation: _mealRecommendation(),
      targetFit: B04CurrentFoodTargetFit(
        state: B04CurrentFoodTargetFitState.fits,
        rank: 0,
        reasonCode: 'target_fit',
        nutrientId: 'energy',
        evidenceIds: const ['totals-v1', 'candidate-v1'],
      ),
      nutrientFacts: [
        B04CurrentFoodNutrientValue(
          nutrientId: 'energy',
          unit: NutrientUnit.kilocalorie,
          state: B04CurrentFoodValueState.known,
          point: '450',
          sourceType: 'b03_candidate_facts',
          sourceIds: const ['candidate-v1'],
        ),
      ],
    );
    final guidance = B04CurrentFoodGuidance(
      status: B04CurrentFoodGuidanceStatus.available,
      userId: 'user-a',
      localDate: '2026-08-06',
      timezoneId: 'Asia/Kolkata',
      evaluatedAtUtc: DateTime.utc(2026, 8, 6, 10),
      remainingTargets: remaining,
      cards: [card],
      recommendationEvaluation: null,
      reasonCodes: const ['candidate_guidance_available'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: B04CurrentFoodContent(
            state: B04CurrentFoodState(
              status: B04CurrentFoodControllerStatus.ready,
              guidance: guidance,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Calories: 1200 kcal'), findsOneWidget);
    expect(find.textContaining('Protein: 40–60 g'), findsOneWidget);
    expect(find.textContaining('candidate-v1'), findsNothing);
    expect(find.textContaining('daily_totals_missing'), findsNothing);
    expect(
      find.textContaining(
        'This guidance is based on the information you have logged.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('current-food failures expose retry', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: B04CurrentFoodContent(
            state: const B04CurrentFoodState(
              status: B04CurrentFoodControllerStatus.failure,
              errorMessage: 'History is unavailable offline.',
            ),
            onRetry: () => retryCount++,
          ),
        ),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retryCount, 1);
  });

  testWidgets('production context failures expose provider retries', (
    tester,
  ) async {
    var dailyAttempts = 0;

    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('daily-context-error'),
        overrides: [
          databaseProvider.overrideWithValue(db),
          b04ProductionUserContextProvider.overrideWith((ref) async {
            dailyAttempts++;
            throw StateError('offline');
          }),
        ],
        child: const MaterialApp(home: B04DailyBriefingCard()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(dailyAttempts, 2);

    var weeklyAttempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('weekly-context-error'),
        overrides: [
          databaseProvider.overrideWithValue(db),
          b04ProductionUserContextProvider.overrideWith((ref) async {
            weeklyAttempts++;
            throw StateError('offline');
          }),
        ],
        child: const MaterialApp(home: B04WeeklyReviewCard()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(weeklyAttempts, 2);

    var foodContextAttempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('current-food-context-error'),
        overrides: [
          databaseProvider.overrideWithValue(db),
          b04ProductionRecommendationContextProvider.overrideWith((ref) async {
            foodContextAttempts++;
            throw StateError('offline');
          }),
        ],
        child: const MaterialApp(home: B04CurrentFoodCard()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(foodContextAttempts, 2);
  });

  test('production copy identifies boundary and rapid-change holds', () {
    expect(
      b04ProductionStateCopy('policy_boundary_reached'),
      contains('supported range'),
    );
    expect(
      b04ProductionStateCopy('rapid_change_review'),
      contains('Recent changes need'),
    );
    expect(
      b04ProductionStateCopy('readiness_incomplete_or_unavailable'),
      contains('need a little more activity information'),
    );
    expect(
      b04ProductionStateCopy('candidate_evidence_unavailable'),
      contains('need more dietary information'),
    );
    expect(
      b04ProductionStateCopy('no_candidate_after_filter'),
      contains('Nothing to recommend yet'),
    );
  });

  test(
    'weekly feedback uses the action local date, not the displayed period',
    () async {
      final history = B04RecommendationHistoryRepository(database: db);
      final actionDate = _dates.localDateFor(
        DateTime.now().toUtc(),
        'Asia/Kolkata',
      );
      final periodEnd = _dates.addCalendarDays(actionDate, 'Asia/Kolkata', -1);
      final periodStart = _dates.addCalendarDays(periodEnd, 'Asia/Kolkata', -6);
      await db
          .into(db.recommendations)
          .insert(
            RecommendationsCompanion.insert(
              id: 'weekly-feedback-recommendation',
              userId: 'user-a',
              scope: 'weekly',
              localPeriodStart: periodStart,
              localPeriodEnd: periodEnd,
              timezoneId: 'Asia/Kolkata',
              status: 'available',
              priority: 5,
              action: 'education',
              explanation: 'A historical weekly explanation.',
              ruleVersion: kB04RecommendationRuleVersion,
              contextFingerprint: 'context-weekly-feedback',
              replayHash: const Value('replay-weekly-feedback'),
              createdAtUtc: Value(DateTime.now().toUtc()),
              effectiveAtUtc: Value(DateTime.now().toUtc()),
            ),
          );
      final controller = B04WeeklyReviewController(
        repository: B04WeeklyReviewReadRepository(history: history),
        history: history,
        dates: _dates,
      );

      await controller.load(
        userId: 'user-a',
        startLocalDate: periodStart,
        endLocalDate: periodEnd,
        timezoneId: 'Asia/Kolkata',
      );
      expect(controller.state.status, B04WeeklyReviewControllerStatus.ready);

      await controller.recordFeedback(
        recommendationId: 'weekly-feedback-recommendation',
        action: B04RecommendationFeedbackAction.dismiss,
      );

      expect(controller.state.status, B04WeeklyReviewControllerStatus.ready);
      final feedback = await db.select(db.recommendationFeedback).getSingle();
      expect(feedback.localDate, actionDate);
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

B04Recommendation _mealRecommendation() => B04Recommendation(
  id: 'meal-recommendation-1',
  action: B04RecommendationAction.nutritionMeal,
  state: B04RecommendationState.available,
  priority: B04RecommendationPriority.nutrition,
  rationaleCode: 'meal_opportunity_target_fit',
  explanation: 'reason_code=daily_totals_missing evidence_id=candidate-v1',
  confidence: B04RecommendationConfidence.high,
  completeness: B04RecommendationCompleteness.complete,
  evidenceIds: const ['candidate-v1'],
  eligibilityState: B04RecommendationEligibilityState.missing,
  consentState: B04RecommendationConsentState.disabled,
  policyState: B04RecommendationPolicyState.missing,
  policyVersion: kB04HoldPolicyVersion,
  ruleVersion: kB04RecommendationRuleVersion,
  algorithmVersion: kB04RecommendationAlgorithmVersion,
  copyVersion: kB04RecommendationCopyVersion,
  targetAcceptanceState: B04RecommendationTargetAcceptanceState.notApplicable,
  canonicalAdaptiveTarget: null,
  canonicalTrainingRecommendation: null,
  safetyDisposition: B04NutritionSafetyDisposition.noKnownConflict,
);

Future<void> _ignoreAction(
  B04BriefingRecommendation recommendation,
  B04RecommendationFeedbackAction action,
) async {}
