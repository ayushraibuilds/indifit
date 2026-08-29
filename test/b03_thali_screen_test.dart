import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/repositories/nutrition_thali_repository.dart';
import 'package:indifit/features/food_log/nutrition_thali_controller.dart';
import 'package:indifit/features/food_log/thali_builder_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'empty builder exposes search/add affordance at compact and large text',
    (tester) async {
      NutritionThaliController makeController() {
        final controller = NutritionThaliController(
          repository: Completer<NutritionThaliRepository>().future,
          userId: 'ui-user',
          mealCategory: 'lunch',
        );
        controller.state = NutritionThaliState(
          status: NutritionThaliStatus.ready,
          draft: NutritionThaliDraft(
            id: 'thali-ui',
            userId: 'ui-user',
            name: 'Lunch thali',
            description: null,
            lifecycle: 'active',
            currentVersion: 1,
            createdAtUtc: DateTime.utc(2026, 8, 4),
            updatedAtUtc: DateTime.utc(2026, 8, 4),
            items: const [],
          ),
        );
        return controller;
      }

      Widget app(double scale, NutritionThaliController controller) =>
          ProviderScope(
            overrides: [
              nutritionThaliControllerProvider(
                'lunch',
              ).overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 568),
                  textScaler: TextScaler.linear(scale),
                ),
                child: const ThaliBuilderScreen(mealType: 'lunch'),
              ),
            ),
          );

      await tester.pumpWidget(app(1, makeController()));
      expect(find.text('Build meal · Lunch'), findsOneWidget);
      expect(find.text('Your meal is empty'), findsOneWidget);
      expect(find.text('Add food or saved recipe'), findsOneWidget);
      expect(find.text('Meal name'), findsOneWidget);
      expect(find.text('Save meal'), findsOneWidget);
      expect(find.text('Draft name'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(app(2, makeController()));
      expect(find.text('Your meal is empty'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('items expose semantic quantity and remove labels', (
    tester,
  ) async {
    final controller = NutritionThaliController(
      repository: Completer<NutritionThaliRepository>().future,
      userId: 'ui-user',
      mealCategory: 'dinner',
    );
    controller.state = NutritionThaliState(
      status: NutritionThaliStatus.ready,
      standardMeasures: NutritionStandardHouseholdMeasures.definitions,
      draft: NutritionThaliDraft(
        id: 'thali-ui-items',
        userId: 'ui-user',
        name: 'Dinner thali',
        description: null,
        lifecycle: 'active',
        currentVersion: 1,
        createdAtUtc: DateTime.utc(2026, 8, 4),
        updatedAtUtc: DateTime.utc(2026, 8, 4),
        items: [
          NutritionThaliItem(
            id: 'item-ui',
            position: 0,
            source: NutritionThaliItemSource.food,
            foodId: 'food-ui',
            recipeVersionId: null,
            quantity: Quantity.fromNum(amount: 100, unit: QuantityUnit.gram),
            displayLabel: 'Dal',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionThaliControllerProvider(
            'dinner',
          ).overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: ThaliBuilderScreen(mealType: 'dinner')),
      ),
    );
    expect(find.text('Dal'), findsOneWidget);
    expect(find.textContaining('100 g'), findsOneWidget);
    expect(find.byTooltip('Remove Dal'), findsOneWidget);
    expect(find.byTooltip('Reorder Dal'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit quantity for Dal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<QuantityUnit>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('household measures').last);
    await tester.pumpAndSettle();
    expect(find.text('Measure or vessel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
