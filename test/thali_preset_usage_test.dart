import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/features/food_log/thali/thali_nutrition_summary_bar.dart';
import 'package:indifit/features/food_log/thali/thali_preset_usage.dart';
import 'package:indifit/features/food_log/thali/thali_presets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ThaliPresetUsage> usage(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return ThaliPresetUsage(await SharedPreferences.getInstance());
  }

  test('no history has no usual preset', () async {
    expect((await usage({})).mostUsed(), isNull);
    expect(ThaliPresetUsage(null).mostUsed(), isNull);
  });

  test('the most-logged preset wins; ties go to the first listed', () async {
    final counts = await usage({
      ThaliPresetUsage.storageKey:
          '{"south_indian_meals": 2, "north_indian_classic": 2, '
          '"high_protein_veg": 1, "retired_preset": 9}',
    });
    // north_indian_classic is listed before south_indian_meals.
    expect(counts.mostUsed(), ThaliPresets.northIndianClassic);
  });

  test('recordLogged counts up and survives a reload', () async {
    final first = await usage({});
    await first.recordLogged('south_indian_meals');
    await first.recordLogged('south_indian_meals');
    final reloaded = ThaliPresetUsage(await SharedPreferences.getInstance());
    expect(reloaded.counts(), {'south_indian_meals': 2});
    expect(reloaded.mostUsed(), ThaliPresets.southIndianMeals);
  });

  test('unreadable stored counts are ignored, not fatal', () async {
    final broken = await usage({ThaliPresetUsage.storageKey: 'not json'});
    expect(broken.counts(), isEmpty);
    expect(broken.mostUsed(), isNull);
  });

  testWidgets('an empty plate reads 0 kcal, not "-- kcal"', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ThaliNutritionSummaryBar(
            preview: null,
            isLoading: false,
            hasItems: false,
            onLogThali: () {},
            onSaveTemplate: () {},
          ),
        ),
      ),
    );
    expect(find.text('0 kcal'), findsOneWidget);
    expect(find.text('-- kcal'), findsNothing);
    expect(find.text('--'), findsNothing);
  });
}
