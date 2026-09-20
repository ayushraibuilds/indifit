import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/presentation/diet_preference_presentation.dart';

void main() {
  group('DietPreferencePresentation Unit Tests', () {
    test('1. Options expose valid shortLabel and rich label', () {
      for (final option in DietPreferencePresentation.options) {
        expect(option.shortLabel, isNotEmpty);
        expect(option.label, contains(option.shortLabel));
        expect(option.uiValue, isNotEmpty);
        expect(option.preferredPersistedValue, isNotEmpty);
      }

      final veg = DietPreferencePresentation.optionForUiValue('veg');
      expect(veg?.shortLabel, 'Vegetarian');

      final nonVeg = DietPreferencePresentation.optionForUiValue('non_veg');
      expect(nonVeg?.shortLabel, 'Non-Vegetarian');

      final vegan = DietPreferencePresentation.optionForUiValue('vegan');
      expect(vegan?.shortLabel, 'Vegan');
    });

    testWidgets('2. DietPreferenceDropdown renders shortLabel in collapsed view', (tester) async {
      String? selectedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                child: DietPreferenceDropdown(
                  persistedValue: 'non-veg',
                  onChanged: (val) => selectedValue = val,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Collapsed field displays the shortLabel without truncating
      expect(find.text('Non-Vegetarian'), findsOneWidget);
      expect(find.text('Non-Vegetarian (Chicken, Eggs, Fish)'), findsNothing);

      // Tap dropdown to open menu
      await tester.tap(find.text('Non-Vegetarian'));
      await tester.pumpAndSettle();

      // In popup menu, full labels are displayed
      expect(find.text('Vegetarian (Paneer, Curd, Dals)'), findsOneWidget);
      expect(find.text('Non-Vegetarian (Chicken, Eggs, Fish)'), findsWidgets);
      expect(find.text('Vegan (Plant-based, Tofu, Soya)'), findsOneWidget);

      // Select Vegan
      await tester.tap(find.text('Vegan (Plant-based, Tofu, Soya)').last);
      await tester.pumpAndSettle();

      expect(selectedValue, 'vegan');
    });
  });
}
