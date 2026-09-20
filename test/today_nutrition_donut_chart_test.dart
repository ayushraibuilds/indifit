import 'package:fl_chart/fl_chart.dart';
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

  testWidgets('CalorieRing renders PieChart when macros are provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: CalorieRing(
              calories: sampleCalories,
              hasTarget: true,
              incomplete: false,
              noConsumption: false,
              macros: sampleMacros,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('1450'), findsOneWidget);
    expect(find.text('of 2,000 kcal'), findsOneWidget);
    expect(find.text('550 left'), findsOneWidget);
  });

  testWidgets('CalorieRing falls back to CalorieRingPainter when macros are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: CalorieRing(
              calories: sampleCalories,
              hasTarget: true,
              incomplete: false,
              noConsumption: false,
              macros: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('1450'), findsOneWidget);
  });

  testWidgets('CalorieRingCard renders TodayNutritionHero with standard defaults', (
    tester,
  ) async {
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
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('1450'), findsOneWidget);
    expect(find.text('Nutrition'), findsOneWidget);
    expect(find.text('Log food'), findsOneWidget);
  });
}
