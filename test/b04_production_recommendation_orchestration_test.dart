import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_briefing_read_models.dart';
import 'package:indifit/data/models/b04_current_food_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/models/b04_recommendation_history_models.dart';
import 'package:indifit/data/models/b04_recommendation_models.dart';
import 'package:indifit/data/repositories/b04_recommendation_history_repository.dart';
import 'package:indifit/data/repositories/coaching_preference_repository.dart';
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_goal_repository.dart';
import 'package:indifit/features/coaching/b04_production_surface_controller.dart';
import 'package:indifit/features/dashboard/b04_daily_briefing_controller.dart';
import 'package:indifit/features/nutrition/current_food_controller.dart';
import 'package:indifit/features/progress/b04_weekly_review_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutrientRegistry registry;
  ProviderContainer? container;

  setUp(() {
    db = AppDatabase.memory();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
  });

  tearDown(() async {
    container?.dispose();
    await db.close();
  });

  test(
    'production provider connects local candidates to current, daily, and weekly surfaces',
    () async {
      final scenario = await _seedScenario(db: db, registry: registry);
      container = _container(db: db, registry: registry);

      final orchestrator = await container!.read(
        b04ProductionRecommendationOrchestratorProvider.future,
      );
      final current = await orchestrator.loadCurrentFood(
        userId: scenario.userId,
        localDate: scenario.localDate,
        timezoneId: scenario.timezoneId,
      );

      expect(current.candidates, hasLength(1));
      expect(current.candidates.single.selection.subjectId, 'food-1');
      expect(current.guidance.status, B04CurrentFoodGuidanceStatus.available);
      expect(current.guidance.cards, hasLength(1));
      expect(current.guidance.cards.single.subjectId, 'food-1');
      expect(
        current.guidance.cards.single.recommendation.evidenceIds,
        isNotEmpty,
      );

      final currentController = container!.read(
        b04CurrentFoodControllerProvider.notifier,
      );
      await currentController.loadProduction(context: current.context);
      expect(
        currentController.state.status,
        B04CurrentFoodControllerStatus.ready,
      );
      expect(currentController.state.guidance!.cards, hasLength(1));

      final dailyController = container!.read(
        b04DailyBriefingControllerProvider.notifier,
      );
      await dailyController.load(
        userId: scenario.userId,
        localDate: scenario.localDate,
        timezoneId: scenario.timezoneId,
      );
      expect(
        dailyController.state.status,
        B04DailyBriefingControllerStatus.unavailable,
      );
      expect(dailyController.state.briefing!.recommendations, isNotEmpty);
      expect(
        dailyController.state.briefing!.policyState,
        B04RecommendationPolicyState.hold,
      );

      final weeklyController = container!.read(
        b04WeeklyReviewControllerProvider.notifier,
      );
      await weeklyController.load(
        userId: scenario.userId,
        startLocalDate: scenario.weekStart,
        endLocalDate: scenario.localDate,
        timezoneId: scenario.timezoneId,
      );
      expect(
        weeklyController.state.status,
        B04WeeklyReviewControllerStatus.unavailable,
      );
      expect(weeklyController.state.review!.recommendations, isNotEmpty);
      expect(
        weeklyController.state.review!.policyState,
        B04RecommendationPolicyState.hold,
      );

      final history = B04RecommendationHistoryRepository(database: db);
      final dailyRows = await history.listHistory(
        userId: scenario.userId,
        scope: B04RecommendationHistoryScope.daily,
      );
      final weeklyRows = await history.listHistory(
        userId: scenario.userId,
        scope: B04RecommendationHistoryScope.weekly,
      );
      expect(dailyRows, hasLength(1));
      expect(weeklyRows, hasLength(1));
      expect(dailyRows.single.consentEventId, isNotNull);
      expect(dailyRows.single.eligibilityEvaluationId, isNotNull);
      expect(weeklyRows.single.consentEventId, isNotNull);
      expect(weeklyRows.single.eligibilityEvaluationId, isNotNull);

      await dailyController.load(
        userId: scenario.userId,
        localDate: scenario.localDate,
        timezoneId: scenario.timezoneId,
      );
      await weeklyController.load(
        userId: scenario.userId,
        startLocalDate: scenario.weekStart,
        endLocalDate: scenario.localDate,
        timezoneId: scenario.timezoneId,
      );
      expect(
        await history.listHistory(
          userId: scenario.userId,
          scope: B04RecommendationHistoryScope.daily,
        ),
        hasLength(1),
      );
      expect(
        await history.listHistory(
          userId: scenario.userId,
          scope: B04RecommendationHistoryScope.weekly,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'production candidate safety remains unavailable when B03 evidence is insufficient',
    () async {
      final scenario = await _seedScenario(
        db: db,
        registry: registry,
        addAllergyWithoutFoodEvidence: true,
      );
      container = _container(db: db, registry: registry);

      final orchestrator = await container!.read(
        b04ProductionRecommendationOrchestratorProvider.future,
      );
      final current = await orchestrator.loadCurrentFood(
        userId: scenario.userId,
        localDate: scenario.localDate,
        timezoneId: scenario.timezoneId,
      );

      expect(current.candidates, hasLength(1));
      expect(current.candidates.single.safety!.isUnavailable, isTrue);
      expect(current.guidance.status, B04CurrentFoodGuidanceStatus.unavailable);
      expect(current.guidance.cards, isEmpty);
      expect(current.guidance.excludedCandidates, hasLength(1));
      expect(
        current.guidance.excludedCandidates.single.reasonCodes,
        contains('dietary_unavailable'),
      );
    },
  );

  test(
    'production context provider and current-food controller use the live provider path',
    () async {
      final scenario = await _seedScenario(
        db: db,
        registry: registry,
        userId: '1',
      );
      await db.into(db.userProfiles).insert(UserProfilesCompanion.insert());
      container = _container(db: db, registry: registry);

      final context = await container!.read(
        b04ProductionRecommendationContextProvider.future,
      );
      expect(context.userId, scenario.userId);

      final controller = container!.read(
        b04CurrentFoodControllerProvider.notifier,
      );
      await controller.loadProduction(context: context);

      expect(controller.state.status, B04CurrentFoodControllerStatus.ready);
      expect(controller.state.guidance!.cards, hasLength(1));
      expect(controller.state.guidance!.cards.single.subjectId, 'food-1');
    },
  );

  test(
    'production history deduplication survives orchestrator recreation',
    () async {
      final scenario = await _seedScenario(db: db, registry: registry);
      container = _container(db: db, registry: registry);

      final first = await container!.read(
        b04ProductionRecommendationOrchestratorProvider.future,
      );
      await first.loadDaily(
        userId: scenario.userId,
        localDate: scenario.localDate,
        timezoneId: scenario.timezoneId,
      );

      container!.invalidate(b04ProductionRecommendationOrchestratorProvider);
      final second = await container!.read(
        b04ProductionRecommendationOrchestratorProvider.future,
      );
      await second.loadDaily(
        userId: scenario.userId,
        localDate: scenario.localDate,
        timezoneId: scenario.timezoneId,
      );

      final history = B04RecommendationHistoryRepository(database: db);
      expect(
        await history.listHistory(
          userId: scenario.userId,
          scope: B04RecommendationHistoryScope.daily,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'production eat-now with no candidates does not issue a target recommendation',
    () async {
      final scenario = await _seedScenario(
        db: db,
        registry: registry,
        includeConsumption: false,
      );
      container = _container(db: db, registry: registry);

      final orchestrator = await container!.read(
        b04ProductionRecommendationOrchestratorProvider.future,
      );
      final current = await orchestrator.loadCurrentFood(
        userId: scenario.userId,
        localDate: scenario.localDate,
        timezoneId: scenario.timezoneId,
      );

      expect(current.guidance.status, B04CurrentFoodGuidanceStatus.noCandidate);
      expect(current.guidance.recommendationEvaluation, isNull);
      expect(
        await B04RecommendationHistoryRepository(database: db).listHistory(
          userId: scenario.userId,
          scope: B04RecommendationHistoryScope.mealOpportunity,
        ),
        isEmpty,
      );
    },
  );

  test(
    'current-food issuance is independent of adaptive consent and deduplicates history',
    () async {
      final scenario = await _seedScenario(
        db: db,
        registry: registry,
        includeAdaptiveLineage: false,
      );
      container = _container(db: db, registry: registry);

      final orchestrator = await container!.read(
        b04ProductionRecommendationOrchestratorProvider.future,
      );
      final first = await orchestrator.loadCurrentFood(
        userId: scenario.userId,
        localDate: scenario.localDate,
        timezoneId: scenario.timezoneId,
      );
      expect(first.guidance.status, B04CurrentFoodGuidanceStatus.available);

      final history = B04RecommendationHistoryRepository(database: db);
      final issued = await history.listHistory(
        userId: scenario.userId,
        scope: B04RecommendationHistoryScope.mealOpportunity,
      );
      expect(issued, hasLength(1));
      expect(issued.single.consentEventId, isNull);
      expect(issued.single.eligibilityEvaluationId, isNull);

      final second = await orchestrator.reloadCurrentFood(
        userId: scenario.userId,
        localDate: scenario.localDate,
        timezoneId: scenario.timezoneId,
      );
      expect(second.guidance.status, B04CurrentFoodGuidanceStatus.available);
      expect(
        await history.listHistory(
          userId: scenario.userId,
          scope: B04RecommendationHistoryScope.mealOpportunity,
        ),
        hasLength(1),
      );

      await history.recordFeedback(
        B04RecommendationFeedbackCommand(
          userId: scenario.userId,
          recommendationId: issued.single.id,
          action: B04RecommendationFeedbackAction.acknowledge,
          source: 'test',
          localDate: scenario.localDate,
          timezoneId: scenario.timezoneId,
          createdAtUtc: DateTime.now().toUtc(),
        ),
      );
      final withFeedback = await history.listHistory(
        userId: scenario.userId,
        scope: B04RecommendationHistoryScope.mealOpportunity,
      );
      expect(withFeedback.single.feedback, hasLength(1));
    },
  );

  test(
    'production missing consent, eligibility, and nutrition evidence stays typed and offline',
    () async {
      final nowUtc = DateTime.now().toUtc();
      final dates = LocalScheduleDateService();
      final timezoneId = 'Asia/Kolkata';
      final localDate = dates.localDateFor(nowUtc, timezoneId);
      container = _container(db: db, registry: registry);

      final orchestrator = await container!.read(
        b04ProductionRecommendationOrchestratorProvider.future,
      );
      final current = await orchestrator.loadCurrentFood(
        userId: 'missing-user',
        localDate: localDate,
        timezoneId: timezoneId,
      );
      expect(current.candidates, isEmpty);
      expect(current.guidance.status, B04CurrentFoodGuidanceStatus.noCandidate);

      final daily = await orchestrator.loadDaily(
        userId: 'missing-user',
        localDate: localDate,
        timezoneId: timezoneId,
      );
      expect(daily.status, B04BriefingReadStatus.unavailable);
      expect(daily.recommendations, isNotEmpty);
      expect(daily.missingEvidence, isNotEmpty);
      expect(daily.consentState, B04RecommendationConsentState.disabled);
      expect(daily.eligibilityState, B04RecommendationEligibilityState.missing);
    },
  );
}

ProviderContainer _container({
  required AppDatabase db,
  required NutrientRegistry registry,
}) => ProviderContainer(
  overrides: [
    databaseProvider.overrideWithValue(db),
    nutritionRegistryProvider.overrideWith((ref) async => registry),
    localTimezoneServiceProvider.overrideWithValue(
      LocalTimezoneService(read: () async => 'Asia/Kolkata'),
    ),
  ],
);

Future<_Scenario> _seedScenario({
  required AppDatabase db,
  required NutrientRegistry registry,
  String userId = 'user-1',
  bool includeConsumption = true,
  bool addAllergyWithoutFoodEvidence = false,
  bool includeAdaptiveLineage = true,
}) async {
  const timezoneId = 'Asia/Kolkata';
  final dates = LocalScheduleDateService();
  final nowUtc = DateTime.now().toUtc();
  final localDate = dates.localDateFor(nowUtc, timezoneId);
  final weekStart = dates.addCalendarDays(localDate, timezoneId, -6);
  final goals = NutritionGoalRepository(database: db, dates: dates);
  await goals.recordUserSetGoal(
    NutritionGoalCommand(
      userId: userId,
      goalType: NutritionGoalType.maintenance,
      calorieTargetKcal: 2000,
      proteinTargetG: 140,
      carbsTargetG: 220,
      fatTargetG: 70,
      effectiveFromLocalDate: weekStart,
      timezoneId: timezoneId,
    ),
  );

  final eligibilityAt = nowUtc.subtract(const Duration(hours: 1));
  if (includeAdaptiveLineage) {
    await db
        .into(db.coachingEligibilityEvaluations)
        .insert(
          CoachingEligibilityEvaluationsCompanion.insert(
            id: 'eligibility-1',
            userId: userId,
            result: 'eligible',
            reasonCode: 'eligible',
            ageInputSource: 'verified_dob',
            evidenceTimestampUtc: eligibilityAt,
            evaluationUtc: eligibilityAt,
            evaluationLocalDate: dates.localDateFor(eligibilityAt, timezoneId),
            timezoneId: timezoneId,
            policyVersion: kB04EnabledPolicyVersion,
            minimumAgeRuleVersion: 'minimum-age-v1',
          ),
        );

    final preferences = CoachingPreferenceRepository(
      database: db,
      dates: dates,
      nowUtc: () => nowUtc,
    );
    await preferences.recordConsent(
      CoachingConsentCommand(
        userId: userId,
        category: CoachingConsentCategory.adaptiveCoaching,
        action: CoachingConsentAction.enable,
        consentPolicyVersion: kB04AdaptiveConsentPolicyVersion,
        copyVersion: kB04AdaptiveConsentCopyVersion,
        timestampUtc: eligibilityAt,
        localDate: dates.localDateFor(eligibilityAt, timezoneId),
        timezoneId: timezoneId,
        actorSource: 'test',
        eventId: 'consent-1',
      ),
    );
  }

  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: 'food-1',
          kind: 'userCreated',
          displayName: 'Local food',
          locale: 'en-IN',
          sourceType: 'user',
          lifecycle: 'active',
        ),
      );
  if (includeConsumption) {
    final consumption = NutritionConsumptionRepository(
      db: db,
      registry: registry,
      nowUtc: () => nowUtc,
    );
    for (var index = 0; index < 7; index++) {
      final date = dates.addCalendarDays(weekStart, timezoneId, index);
      await consumption.finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: userId,
          consumptionId: 'consumption-$index',
          commandId: 'command-$index',
          loggedAtUtc: nowUtc.subtract(Duration(days: 6 - index)),
          mealCategory: 'lunch',
          sourceType: 'direct_food',
          localDate: date,
          timezoneId: timezoneId,
          calculatorVersion: 'test-snapshot-v1',
          items: [
            NutritionConsumptionItemInput(
              id: 'item-$index',
              position: 0,
              sourceType: 'direct_food',
              foodId: 'food-1',
              displayLabel: 'Local food',
              quantity: Quantity.fromDecimal(
                amount: '100',
                unit: QuantityUnit.gram,
              ),
              calculation: _completeCalculation(registry),
            ),
          ],
        ),
      );
    }
  }

  if (addAllergyWithoutFoodEvidence) {
    await NutritionConstraintRepository(
      database: db,
      nowUtc: () => nowUtc,
    ).createUserConstraint(
      userId: userId,
      type: NutritionConstraintType.allergy,
      target: NutritionConstraintTarget(
        type: NutritionConstraintTargetType.allergen,
        id: 'peanut',
      ),
      strictness: NutritionConstraintStrictness.avoid,
      effectiveFrom: eligibilityAt,
      id: 'allergy-1',
    );
  }

  return _Scenario(
    userId: userId,
    localDate: localDate,
    weekStart: weekStart,
    timezoneId: timezoneId,
  );
}

NutritionConsumptionCalculationSnapshot _completeCalculation(
  NutrientRegistry registry,
) {
  final facts = <String, NutrientFact>{
    for (final definition in registry.definitions)
      definition.id: NutrientFact.known(
        nutrientId: definition.id,
        point: NutrientAmount(
          value: QuantityAmount.fromString(
            definition.id == 'energy' ? '100' : '1',
          ),
          unit: definition.unit,
        ),
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: NutrientSourceType.reviewedCatalogue,
        sourceReference: 'catalogue:food-1:${definition.id}',
        factVersion: 'food-v1',
      ),
  };
  return NutritionConsumptionCalculationSnapshot.fromFacts(
    facts: facts,
    registry: registry,
    requestedNutrientIds: registry.definitions.map((item) => item.id),
    calculatorVersion: 'test-snapshot-v1',
    calculationFingerprint: 'complete-food-v1',
  );
}

class _Scenario {
  final String userId;
  final String localDate;
  final String weekStart;
  final String timezoneId;

  const _Scenario({
    required this.userId,
    required this.localDate,
    required this.weekStart,
    required this.timezoneId,
  });
}
