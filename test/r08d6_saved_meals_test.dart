import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/repositories/nutrition_thali_repository.dart';
import 'package:indifit/features/food_log/saved_meal_detail_screen.dart';
import 'package:indifit/features/food_log/saved_meal_editor_screen.dart';
import 'package:indifit/features/food_log/saved_meal_presentation.dart';
import 'package:indifit/features/food_log/saved_meals_controller.dart';
import 'package:indifit/features/food_log/saved_meals_screen.dart';

void main() {
  test(
    'saved meal presentation keeps canonical units and household identity',
    () {
      final household = NutritionThaliItem(
        id: 'household-item',
        position: 0,
        source: NutritionThaliItemSource.food,
        foodId: 'food::rice',
        recipeVersionId: null,
        quantity: Quantity.householdReference(
          count: '1.5',
          reference: const HouseholdMeasureReference(measureType: 'katori'),
        ),
        measureId: 'katori',
        displayLabel: 'Cooked rice',
      );

      expect(savedMealQuantityLabel(household), '1.5 katori');
    },
  );

  testWidgets('Saved Meals opens a composition-first detail route', (
    tester,
  ) async {
    final controller = _StaticSavedMealsController(
      SavedMealsState(status: SavedMealsStatus.ready, meals: [_displayMeal()]),
    );

    await tester.pumpWidget(
      _providerApp(controller, const SavedMealsScreen(mealType: 'lunch')),
    );
    await tester.pump();

    await tester.tap(find.text('Dinner plate'));
    await tester.pumpAndSettle();

    expect(find.text('Saved meal'), findsOneWidget);
    expect(find.text('Composition'), findsOneWidget);
    expect(find.text('Cooked rice'), findsOneWidget);
    expect(find.text('150 g'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Food Cooked rice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saved Meals exposes a recoverable failure state', (
    tester,
  ) async {
    final controller = _StaticSavedMealsController(
      const SavedMealsState(
        status: SavedMealsStatus.failure,
        errorMessage: 'Saved meals could not be loaded.',
      ),
    );

    await tester.pumpWidget(
      _providerApp(controller, const SavedMealsScreen(mealType: 'lunch')),
    );
    await tester.pump();

    expect(find.text('Saved meals could not be loaded.'), findsOneWidget);
    expect(find.text('Saved meals could not be loaded'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('No saved meals yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Saved Meal detail remains readable at narrow width and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: MaterialApp(
            home: SavedMealDetailScreen(
              meal: _displayMeal(),
              mealType: 'lunch',
              onQuickLog: () async => false,
              onReviewPortions: () async => false,
              onEdit: () async => false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Composition'), findsOneWidget);
      expect(find.text('Log to lunch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Saved Meal detail uses explicit danger styling for delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SavedMealDetailScreen(
          meal: _displayMeal(),
          mealType: 'lunch',
          onQuickLog: () async => false,
          onReviewPortions: () async => false,
          onEdit: () async => false,
          onDelete: () async => true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Saved meal actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final delete = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    expect(delete.style?.backgroundColor?.resolve({}), isNotNull);
    expect(delete.style?.foregroundColor?.resolve({}), isNotNull);
  });

  testWidgets('Saved Meal editor uses title-case save action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SavedMealEditorScreen()),
    );
    await tester.pump();

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('SAVE'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _providerApp(SavedMealsController controller, Widget home) {
  return MaterialApp(
    home: _SavedMealsProviderHost(controller: controller, child: home),
  );
}

class _SavedMealsProviderHost extends StatelessWidget {
  final SavedMealsController controller;
  final Widget child;

  const _SavedMealsProviderHost({
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        savedMealsControllerProvider.overrideWith((ref) => controller),
      ],
      child: child,
    );
  }
}

class _StaticSavedMealsController extends SavedMealsController {
  _StaticSavedMealsController(SavedMealsState seed)
    : super(
        thaliRepoFuture: Completer<NutritionThaliRepository>().future,
        userId: kLocalNutritionUserScopeId,
      ) {
    state = seed;
  }
}

SavedMealDisplayItem _displayMeal() {
  final draft = NutritionThaliDraft(
    id: 'thali::detail-meal',
    userId: kLocalNutritionUserScopeId,
    name: 'Dinner plate',
    description: 'A repeatable dinner composition',
    lifecycle: 'active',
    currentVersion: 1,
    createdAtUtc: DateTime.utc(2026, 8, 24),
    updatedAtUtc: DateTime.utc(2026, 8, 24),
    items: [
      NutritionThaliItem(
        id: 'detail-item-rice',
        position: 0,
        source: NutritionThaliItemSource.food,
        foodId: 'food::rice',
        recipeVersionId: null,
        quantity: Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
        displayLabel: 'Cooked rice',
      ),
    ],
  );
  return SavedMealDisplayItem(
    draft: draft,
    itemCount: 1,
    estimatedCalories: 240,
    estimatedProteinG: 5,
    summary: 'Cooked rice',
  );
}
