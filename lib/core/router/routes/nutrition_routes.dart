part of '../app_router.dart';

final nutritionRoutes = <RouteBase>[
  GoRoute(
    path: '/food',
    builder: (context, state) => foodRouteDestination(
      mealType: state.uri.queryParameters['mealType'],
      date: state.uri.queryParameters['date'],
    ),
  ),
  // Former AI meal logging route fails safely into Food diary without
  // mounting unavailable surfaces.
  GoRoute(
    path: '/food/ai',
    redirect: (context, state) =>
        compatibilityRouteRedirect(state.matchedLocation),
  ),
  GoRoute(
    path: '/food/estimate-review',
    builder: (context, state) {
      final estimateId = state.uri.queryParameters['estimateId'];
      if (estimateId == null || estimateId.trim().isEmpty) {
        return const Scaffold(
          body: Center(child: Text('No estimate selected.')),
        );
      }
      return NutritionEstimateReviewScreen(estimateId: estimateId);
    },
  ),
  GoRoute(
    path: '/food/label-ocr',
    builder: (context, state) => NutritionLabelOcrScreen(
      mealType: state.uri.queryParameters['mealType'],
      date: state.uri.queryParameters['date'],
    ),
  ),
  GoRoute(
    path: '/food/describe',
    builder: (context, state) => NaturalLanguageMealScreen(
      mealType: state.uri.queryParameters['mealType'],
      date: state.uri.queryParameters['date'],
    ),
  ),
  GoRoute(
    path: '/food/recipes/edit',
    builder: (context, state) => NutritionRecipeEditorScreen(
      recipeId: state.uri.queryParameters['recipeId'],
      draftVersionId: state.uri.queryParameters['draftVersionId'],
    ),
  ),
  GoRoute(
    path: '/food/thali',
    builder: (context, state) {
      final extraMap = state.extra is Map ? state.extra as Map : const {};
      final extraDate = extraMap['selectedDate'] is DateTime
          ? extraMap['selectedDate'] as DateTime
          : null;
      final queryDate = parseFoodRouteDate(state.uri.queryParameters['date']);
      return ThaliBuilderScreen(
        mealCategory: state.uri.queryParameters['meal'] ?? 'lunch',
        initialThaliId: state.uri.queryParameters['thaliId'],
        selectedDate: extraDate ?? queryDate,
      );
    },
  ),
  GoRoute(
    path: '/settings/household-measures',
    builder: (context, state) => const HouseholdMeasuresScreen(),
  ),
  GoRoute(
    path: '/settings/dietary-constraints',
    builder: (context, state) => const NutritionConstraintsScreen(),
  ),
  GoRoute(
    path: '/settings/dietary-constraints/review',
    builder: (context, state) => NutritionConstraintEvaluationReviewScreen(
      foodId: state.uri.queryParameters['foodId'],
      recipeVersionId: state.uri.queryParameters['recipeVersionId'],
    ),
  ),
  // Former AI meal planner route fails safely into Food diary.
  GoRoute(
    path: '/meal-planner',
    redirect: (context, state) =>
        compatibilityRouteRedirect(state.matchedLocation),
  ),
];
