import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/widgets/today_nutrition_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleCalories = TodayNutritionMetricPresentation(
    nutrientId: 'energy',
    label: 'Calories',
    value: '1450',
    unit: 'kcal',
    estimated: false,
    isAvailable: true,
    isRange: false,
    isIncomplete: false,
    pointValue: 1450,
    lowerValue: null,
    upperValue: null,
    targetValue: 2000,
  );

  const sampleMacros = [
    TodayNutritionMetricPresentation(
      nutrientId: 'protein',
      label: 'Protein',
      value: '120',
      unit: 'g',
      estimated: false,
      isAvailable: true,
      isRange: false,
      isIncomplete: false,
      pointValue: 120,
      lowerValue: null,
      upperValue: null,
      targetValue: 150,
    ),
    TodayNutritionMetricPresentation(
      nutrientId: 'carbohydrate',
      label: 'Carbs',
      value: '150',
      unit: 'g',
      estimated: false,
      isAvailable: true,
      isRange: false,
      isIncomplete: false,
      pointValue: 150,
      lowerValue: null,
      upperValue: null,
      targetValue: 200,
    ),
    TodayNutritionMetricPresentation(
      nutrientId: 'fat',
      label: 'Fat',
      value: '45',
      unit: 'g',
      estimated: false,
      isAvailable: true,
      isRange: false,
      isIncomplete: false,
      pointValue: 45,
      lowerValue: null,
      upperValue: null,
      targetValue: 60,
    ),
  ];

  CalorieRingPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(find.byKey(const Key('today_calorie_ring')))
              .painter!
          as CalorieRingPainter;

  testWidgets('the ring shows calories eaten against the target (UX-03)', (
    tester,
  ) async {
    const eaten = TodayNutritionMetricPresentation(
      nutrientId: 'energy',
      label: 'Calories',
      value: '810',
      unit: 'kcal',
      estimated: false,
      isAvailable: true,
      isRange: false,
      isIncomplete: false,
      pointValue: 810,
      lowerValue: null,
      upperValue: null,
      targetValue: 2038,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: CalorieRing(
              calories: eaten,
              hasTarget: true,
              incomplete: false,
              noConsumption: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A macro pie drew a full circle here; the day is 40 % eaten.
    expect(painter(tester).progressHigh, closeTo(0.397, 0.001));
    expect(find.text('810'), findsOneWidget);
    expect(find.text('of 2,038 kcal'), findsOneWidget);
    expect(find.text('1,228 left'), findsOneWidget);
  });

  testWidgets('the ring turns red only above the target', (tester) async {
    Future<Color> ringColor(double eaten) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: CalorieRing(
                calories: TodayNutritionMetricPresentation(
                  nutrientId: 'energy',
                  label: 'Calories',
                  value: '${eaten.round()}',
                  unit: 'kcal',
                  estimated: false,
                  isAvailable: true,
                  isRange: false,
                  isIncomplete: false,
                  pointValue: eaten,
                  lowerValue: null,
                  upperValue: null,
                  targetValue: 2000,
                ),
                hasTarget: true,
                incomplete: false,
                noConsumption: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return painter(tester).color;
    }

    final under = await ringColor(1450);
    final over = await ringColor(2300);
    expect(under, isNot(over));
    expect(painter(tester).progressHigh, 1.0);
  });

  testWidgets('a partial macro shows its value and an info icon, not '
      '"(partial)"', (tester) async {
    const partial = TodayNutritionMetricPresentation(
      nutrientId: 'protein',
      label: 'Protein',
      value: '45',
      unit: 'g',
      estimated: false,
      isAvailable: true,
      isRange: false,
      isIncomplete: true,
      pointValue: 45,
      lowerValue: null,
      upperValue: null,
      targetValue: 150,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: MacroRow(metric: partial)),
      ),
    );
    expect(find.text('45 / 150 g'), findsOneWidget);
    expect(find.textContaining('(partial)'), findsNothing);
    expect(find.byKey(const ValueKey('macro_partial_protein')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('incomplete')), findsOneWidget);
  });

  testWidgets(
    'CalorieRingCard renders TodayNutritionHero with standard defaults',
    (tester) async {
      const presentation = TodayNutritionPresentation(
        state: TodayPresentationState.ready,
        headline: 'Nutrition',
        detail: 'Daily totals',
        calories: sampleCalories,
        macros: sampleMacros,
        hasAcceptedCalorieTarget: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CalorieRingCard(
                presentation: presentation,
                onLogFood: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TodayNutritionHero), findsOneWidget);
      expect(find.byKey(const Key('today_calorie_ring')), findsOneWidget);
      expect(find.text('1450'), findsOneWidget);
      expect(find.text('Nutrition'), findsOneWidget);
      expect(find.text('Log food'), findsOneWidget);
    },
  );
}
