import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/features/food_log/food_diary_screen.dart';
import 'package:indifit/features/food_log/thali/thali_quantity_label.dart';
import 'package:indifit/features/food_log/widgets/food_diary_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// UR-10 / UR-50: one unit-label path, and no internal ids on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuantityFormatter labels every unit in plain words', () {
    String format(String amount, QuantityUnit unit, {String? measure}) =>
        QuantityFormatter.format(
          Quantity(
            amount: QuantityAmount.fromString(amount),
            unit: unit,
            context: QuantityContext(
              householdMeasure: measure == null
                  ? null
                  : HouseholdMeasureReference(measureType: measure),
            ),
          ),
        );

    test('metric units use symbols', () {
      expect(format('150', QuantityUnit.gram), '150 g');
      expect(format('1', QuantityUnit.gram), '1 g');
      expect(format('5', QuantityUnit.milligram), '5 mg');
      expect(format('2', QuantityUnit.kilogram), '2 kg');
      expect(format('200', QuantityUnit.millilitre), '200 ml');
      expect(format('1.5', QuantityUnit.litre), '1.5 L');
    });

    test('counts are singular for one and plural otherwise', () {
      expect(format('1', QuantityUnit.piece), '1 piece');
      expect(format('2', QuantityUnit.piece), '2 pieces');
      expect(format('0.5', QuantityUnit.piece), '0.5 pieces');
      String label(QuantityUnit unit, String amount) =>
          QuantityFormatter.unitLabel(
            unit,
            amount: QuantityAmount.fromString(amount),
          );
      expect(label(QuantityUnit.serving, '1'), 'serving');
      expect(label(QuantityUnit.serving, '3'), 'servings');
      expect(label(QuantityUnit.unknown, '1'), 'serving');
      expect(label(QuantityUnit.legacy, '2'), 'servings');
    });

    test('household measures name the vessel, never the id', () {
      const katori = 'household_measure_katori_v1';
      expect(
        format('1', QuantityUnit.householdReference, measure: katori),
        '1 katori',
      );
      expect(
        format('2', QuantityUnit.householdReference, measure: katori),
        '2 katori',
      );
      expect(
        format(
          '1',
          QuantityUnit.householdReference,
          measure: 'household_measure_glass_v2',
        ),
        '1 glass',
      );
      expect(
        format(
          '2',
          QuantityUnit.householdReference,
          measure: 'household_measure_glass_v1',
        ),
        '2 glass',
      );
      expect(
        format(
          '3',
          QuantityUnit.householdReference,
          measure: 'household_measure_roti_v1',
        ),
        '3 pieces',
      );
      expect(
        QuantityFormatter.unitLabel(QuantityUnit.householdReference),
        'measure',
      );
    });

    test('every unit has a label', () {
      for (final unit in QuantityUnit.values) {
        final label = QuantityFormatter.unitLabel(unit);
        expect(label, isNotEmpty, reason: '$unit');
        expect(label, isNot(contains('_')), reason: '$unit');
      }
    });

    test('stored units from older records read the same way', () {
      expect(QuantityFormatter.formatStored('150', 'mass_gram'), '150 g');
      expect(QuantityFormatter.formatStored('2', 'pieces'), '2 pieces');
      expect(
        QuantityFormatter.formatStored('1', 'household_measure_katori_v1'),
        '1 katori',
      );
      expect(QuantityFormatter.formatStored('1.0', 'grams'), '1 g');
    });

    test('the thali labels come from the same place', () {
      expect(thaliQuantityLabel(katori(1)), '1 katori');
      expect(
        thaliQuantityLabel(
          Quantity.fromNum(amount: 2, unit: QuantityUnit.piece),
        ),
        '2 pieces',
      );
      expect(
        thaliQuantityLabel(
          Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
        ),
        '150 g',
      );
    });
  });

  group('no internal id reaches the screen', () {
    late RealCatalogue catalogue;

    setUp(() => SharedPreferences.setMockInitialValues({}));

    final internal = RegExp(r'household_measure|_v\d\b|::|food-seed-');

    void expectNoInternalText(WidgetTester tester) {
      final leaks = [
        for (final widget in tester.widgetList<Text>(find.byType(Text)))
          if (internal.hasMatch(
            widget.data ?? widget.textSpan?.toPlainText() ?? '',
          ))
            widget.data ?? widget.textSpan!.toPlainText(),
        for (final widget in tester.widgetList<RichText>(find.byType(RichText)))
          if (internal.hasMatch(widget.text.toPlainText()))
            widget.text.toPlainText(),
      ];
      expect(leaks, isEmpty);
    }

    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(402, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      catalogue = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, catalogue.db));
      await tester.runAsync(() => LoggedRecords.log(catalogue));
      await tester.pumpWidget(
        ProviderScope(
          overrides: loggedRecordsOverrides(catalogue),
          child: MaterialApp(theme: AppTheme.lightTheme, home: home),
        ),
      );
      await settleLoggedRecords(tester);
    }

    testWidgets('the meal page', (tester) async {
      await pump(
        tester,
        FoodMealDetailScreen(
          mealType: 'lunch',
          selectedDate: DateTime(2026, 10, 8),
        ),
      );
      expect(find.textContaining('1 katori'), findsWidgets);
      // Thali and recipe rows show their items when expanded (UR-40).
      for (final toggle
          in find.byIcon(Icons.expand_more_rounded).evaluate().toList()) {
        await tester.tap(find.byWidget(toggle.widget));
      }
      await tester.pump();
      expect(find.textContaining('2 pieces'), findsWidgets);
      expect(find.text('Home dal'), findsOneWidget);
      expectNoInternalText(tester);
    });

    testWidgets('the diary', (tester) async {
      await pump(
        tester,
        FoodDiaryScreen(
          selectedDate: DateTime(2026, 10, 8),
          today: DateTime(2026, 10, 8),
        ),
      );
      expect(find.textContaining('Lunch'), findsWidgets);
      expectNoInternalText(tester);
    });
  });
}
