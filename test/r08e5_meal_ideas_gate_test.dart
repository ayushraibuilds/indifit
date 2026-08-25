import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/models/b04_current_food_models.dart';
import 'package:indifit/data/models/b04_recommendation_context_models.dart';
import 'package:indifit/data/models/b04_recommendation_models.dart';
import 'package:indifit/data/services/b04_current_food_guidance_service.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_daily_action_surface.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/nutrition/current_food_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loading and failure states fail closed', () {
    for (final status in [
      B04CurrentFoodControllerStatus.loading,
      B04CurrentFoodControllerStatus.failure,
    ]) {
      expect(
        todayMealIdeasAreAvailable(
          dateRelation: TodayDateRelation.today,
          state: B04CurrentFoodState(status: status),
        ),
        isFalse,
      );
    }
  });

  test('unavailable, ineligible, and insufficient guidance stay hidden', () {
    for (final reason in [
      'guidance_unavailable',
      'eligibility_unavailable',
      'insufficient_nutrition_evidence',
    ]) {
      expect(
        todayMealIdeasAreAvailable(
          dateRelation: TodayDateRelation.today,
          state: _state(
            controllerStatus: B04CurrentFoodControllerStatus.unavailable,
            guidanceStatus: B04CurrentFoodGuidanceStatus.unavailable,
            reason: reason,
          ),
        ),
        isFalse,
      );
    }
  });

  test('empty and no-recommendation results never expose the action', () {
    expect(
      todayMealIdeasAreAvailable(
        dateRelation: TodayDateRelation.today,
        state: _state(
          controllerStatus: B04CurrentFoodControllerStatus.noCandidate,
          guidanceStatus: B04CurrentFoodGuidanceStatus.noCandidate,
          reason: 'no_candidate',
        ),
      ),
      isFalse,
    );
    expect(
      todayMealIdeasAreAvailable(
        dateRelation: TodayDateRelation.today,
        state: _state(
          controllerStatus: B04CurrentFoodControllerStatus.ready,
          guidanceStatus: B04CurrentFoodGuidanceStatus.available,
          cards: const [],
          reason: 'no_candidate_after_filter',
        ),
      ),
      isFalse,
    );
  });

  test('only a current-day usable B04 card enables Meal Ideas', () {
    final state = _state(
      controllerStatus: B04CurrentFoodControllerStatus.ready,
      guidanceStatus: B04CurrentFoodGuidanceStatus.available,
      reason: 'candidate_guidance_available',
    );

    expect(
      todayMealIdeasAreAvailable(
        dateRelation: TodayDateRelation.today,
        state: state,
        expectedLocalDate: '2026-08-07',
      ),
      isTrue,
    );
    expect(
      todayMealIdeasAreAvailable(
        dateRelation: TodayDateRelation.today,
        state: state,
        expectedLocalDate: '2026-08-08',
      ),
      isFalse,
    );
  });

  test('historical and future dates stay hidden even with usable guidance', () {
    final state = _state(
      controllerStatus: B04CurrentFoodControllerStatus.ready,
      guidanceStatus: B04CurrentFoodGuidanceStatus.available,
      reason: 'candidate_guidance_available',
    );
    for (final relation in [TodayDateRelation.past, TodayDateRelation.future]) {
      expect(
        todayMealIdeasAreAvailable(dateRelation: relation, state: state),
        isFalse,
      );
    }
  });

  testWidgets('Log food remains available while Meal Ideas is gated', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 8, 7);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TodayNutritionHero(
          presentation: TodayNutritionPresentation.from(
            _emptySnapshot(selectedDate).nutrition,
            loading: false,
          ),
          onLogFood: () {},
          onOpenFoodGuidance: null,
          dateRelation: TodayDateRelation.today,
          selectedDate: selectedDate,
          onOpenTargetSetup: () {},
          onRetry: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Log food'), findsOneWidget);
    expect(find.text('What can I eat?'), findsNothing);
  });

  testWidgets('first production load rebuilds when guidance becomes ready', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 8, 7);
    var guidanceOpened = false;
    final controller = _ReadyCurrentFoodController(
      _state(
        controllerStatus: B04CurrentFoodControllerStatus.ready,
        guidanceStatus: B04CurrentFoodGuidanceStatus.available,
        reason: 'candidate_guidance_available',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          b04ProductionRecommendationContextProvider.overrideWith(
            (ref) async => _recommendationContext(),
          ),
          b04CurrentFoodControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: TodayNutritionHero(
            presentation: TodayNutritionPresentation.from(
              _emptySnapshot(selectedDate).nutrition,
              loading: false,
            ),
            onLogFood: () {},
            onOpenFoodGuidance: () => guidanceOpened = true,
            dateRelation: TodayDateRelation.today,
            selectedDate: selectedDate,
            onOpenTargetSetup: () {},
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.loadCount, 1);
    expect(find.text('What can I eat?'), findsOneWidget);
    await tester.tap(find.text('What can I eat?'));
    expect(guidanceOpened, isTrue);
  });
}

class _ReadyCurrentFoodController extends B04CurrentFoodController {
  _ReadyCurrentFoodController(this.readyState)
    : super(service: const B04CurrentFoodGuidanceService());

  final B04CurrentFoodState readyState;
  var loadCount = 0;

  @override
  Future<void> loadProduction({
    required B04RecommendationContext context,
    bool refresh = false,
  }) async {
    loadCount += 1;
    state = const B04CurrentFoodState(
      status: B04CurrentFoodControllerStatus.loading,
    );
    await Future<void>.delayed(Duration.zero);
    state = readyState;
  }
}

B04RecommendationContext _recommendationContext() => B04RecommendationContext(
  contextId: 'today-meal-ideas-context',
  userId: 'user-1',
  window: const B04RecommendationWindow(
    period: B04RecommendationPeriod.daily,
    startLocalDate: '2026-08-07',
    endLocalDate: '2026-08-07',
    timezoneId: 'UTC',
    targetEvaluationWindowDays: 1,
    aggregateWindowDays: 1,
  ),
  evaluatedAtUtc: DateTime.utc(2026, 8, 7, 12),
  availability: B04ContextAvailability.available,
  activeGoal: null,
  preferences: null,
  eligibility: null,
  readiness: null,
  workload: null,
  schedule: null,
  nutrition: const B04NutritionContext(
    days: [],
    expectedLocalDates: ['2026-08-07'],
    missingLocalDates: [],
  ),
  constraints: const [],
  targetResult: null,
  mealOpportunity: null,
  missingEvidence: const [],
  n8: B04N8Context.absent,
);

B04CurrentFoodState _state({
  required B04CurrentFoodControllerStatus controllerStatus,
  required B04CurrentFoodGuidanceStatus guidanceStatus,
  required String reason,
  List<B04CurrentFoodCandidateCard>? cards,
}) => B04CurrentFoodState(
  status: controllerStatus,
  guidance: B04CurrentFoodGuidance(
    status: guidanceStatus,
    userId: 'user-1',
    localDate: '2026-08-07',
    timezoneId: 'UTC',
    evaluatedAtUtc: DateTime.utc(2026, 8, 7, 12),
    remainingTargets: B04RemainingTargetReadModel(
      userId: 'user-1',
      localDate: '2026-08-07',
      timezoneId: 'UTC',
      goalVersionId: null,
      goalSource: null,
      goalEffectiveFromLocalDate: null,
      targets: const [],
    ),
    cards:
        cards ??
        (guidanceStatus == B04CurrentFoodGuidanceStatus.available
            ? [_card()]
            : const []),
    recommendationEvaluation: null,
    reasonCodes: [reason],
  ),
);

B04CurrentFoodCandidateCard _card() => B04CurrentFoodCandidateCard(
  selectionId: 'selection-1',
  subjectId: 'food-1',
  source: B04MealCandidateSource.canonicalFood,
  displayLabel: 'Canonical food',
  recommendation: B04Recommendation(
    id: 'recommendation-1',
    action: B04RecommendationAction.nutritionMeal,
    state: B04RecommendationState.available,
    priority: B04RecommendationPriority.userSelected,
    rationaleCode: 'meal_opportunity_target_fit',
    explanation: 'A tested recommendation.',
    confidence: B04RecommendationConfidence.high,
    completeness: B04RecommendationCompleteness.complete,
    evidenceIds: const ['evidence-1'],
    eligibilityState: B04RecommendationEligibilityState.eligible,
    consentState: B04RecommendationConsentState.enabled,
    policyState: B04RecommendationPolicyState.enabled,
    policyVersion: 'test-policy',
    ruleVersion: 'test-rule',
    algorithmVersion: 'test-algorithm',
    copyVersion: 'test-copy',
    targetAcceptanceState: B04RecommendationTargetAcceptanceState.notApplicable,
    canonicalAdaptiveTarget: null,
    canonicalTrainingRecommendation: null,
    safetyDisposition: null,
  ),
  targetFit: B04CurrentFoodTargetFit(
    state: B04CurrentFoodTargetFitState.fits,
    rank: 0,
    reasonCode: 'within_remaining_target',
    nutrientId: 'energy',
    evidenceIds: const ['evidence-1'],
  ),
);

TodaySurfaceSnapshot _emptySnapshot(DateTime selectedDate) =>
    TodaySurfaceSnapshot(
      selectedDate: selectedDate,
      localDate: todaySurfaceDateKey(selectedDate),
      timezoneId: 'UTC',
      calendar: const TodayDomainRead.unavailable('offline'),
      progress: const TodayDomainRead.unavailable('offline'),
      nutrition: TodayDomainRead.available(
        NutritionDailyReadModel(
          userId: 'local-nutrition-user',
          localDate: todaySurfaceDateKey(selectedDate),
          records: const [],
          recordIds: const [],
          totals: NutrientAggregationResult(
            facts: const {},
            completeness: NutrientCompleteness(
              state: NutrientCompletenessState.unknown,
              requestedNutrientIds: const [],
              availableNutrientIds: const [],
              missingNutrientIds: const [],
              estimatedNutrientIds: const [],
              notApplicableNutrientIds: const [],
              partiallyKnownNutrientIds: const [],
            ),
            sourceLineage: const {},
            factVersionLineage: const {},
          ),
          sourceCounts: const {},
          issues: const [],
        ),
      ),
      targets: const TodayDomainRead.available(null),
    );
