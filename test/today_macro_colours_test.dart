import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/theme/indifit_icons.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/widgets/today_nutrition_widgets.dart';

TodayNutritionMetricPresentation _fat(double grams, {double target = 60}) =>
    TodayNutritionMetricPresentation(
      nutrientId: 'fat',
      label: 'Fat',
      value: grams.toStringAsFixed(0),
      unit: 'g',
      estimated: false,
      isAvailable: true,
      isRange: false,
      isIncomplete: false,
      pointValue: grams,
      lowerValue: null,
      upperValue: null,
      targetValue: target,
    );

Future<Color> _barColour(
  WidgetTester tester,
  TodayNutritionMetricPresentation metric,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: MacroRow(metric: metric)),
    ),
  );
  await tester.pumpAndSettle();
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(MacroProgress),
      matching: find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is RangeBarPainter,
      ),
    ),
  );
  return (paint.painter! as RangeBarPainter).color;
}

void main() {
  testWidgets('P1 H5 Fat is not red unless it is over target', (tester) async {
    final under = await _barColour(tester, _fat(30));
    final colors = tester.element(find.byType(MacroRow)).b05Colors;
    expect(under, isNot(colors.danger.indicator));
    expect(under, colors.fat.indicator);

    final over = await _barColour(tester, _fat(75));
    expect(over, colors.danger.indicator);
  });

  test('no macro uses the over-target red as its base colour', () {
    for (final colors in [B05SemanticColors.light, B05SemanticColors.dark]) {
      final roles = {
        for (final id in ['protein', 'carbohydrate', 'fat', 'fibre'])
          id: todayMacroColorRole(colors, id).indicator,
      };
      expect(roles.values, isNot(contains(colors.danger.indicator)));
      expect(roles.values.toSet(), hasLength(4), reason: 'each macro distinct');
      // Fat is orange, not hydration blue.
      expect(roles['fat'], isNot(colors.info.indicator));
    }
  });

  testWidgets('fat uses the half-filled drop, not the water drop', (
    tester,
  ) async {
    await _barColour(tester, _fat(30));
    final icon = tester.widget<IndiFitIcon>(
      find.descendant(
        of: find.byType(MacroRow),
        matching: find.byType(IndiFitIcon),
      ),
    );
    expect(icon.icon, IndiFitIcons.fat);
    expect(icon.icon, isNot(IndiFitIcons.hydration));
  });
}
