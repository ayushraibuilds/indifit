import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/utils/tdee_calculator.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';

import 'support/indifit_test_harness.dart';

/// UR-25: age, height and weight start empty, "Next step" asks for them,
/// and Skip goes on with the usual values, which the review names.
void main() {
  initializeIndiFitTestHarness();

  Future<void> pumpAbout(WidgetTester tester) async {
    setIndiFitTestPreferences({});
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final database = registerTestDatabaseScope().create();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tap(tester, 'Next step');
  }

  TextField field(WidgetTester tester, String label) => tester.widget(
    find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    ),
  );

  testWidgets('the fields start untouched, with placeholders and no tick', (
    tester,
  ) async {
    await pumpAbout(tester);
    for (final (label, hint) in [
      ('Age', '25'),
      ('Height', '170'),
      ('Current weight', '70'),
    ]) {
      expect(field(tester, label).controller!.text, '', reason: label);
      expect(field(tester, label).decoration!.hintText, hint, reason: label);
    }
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.text('Use 70 kg'), findsOneWidget);

    await tap(tester, 'Use 70 kg');
    expect(field(tester, 'Current weight').controller!.text, '70');
    expect(find.text('Use 70 kg'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('"Next step" asks to set them; Set them stays on the step', (
    tester,
  ) async {
    await pumpAbout(tester);
    await tap(tester, 'Male');
    await tap(tester, 'Next step');
    expect(find.text('Set your details?'), findsOneWidget);
    expect(find.textContaining('age, height, weight.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_about_set_details')));
    await tester.pumpAndSettle();
    expect(find.text('A bit about you'), findsOneWidget);
  });

  testWidgets('Skip goes on, and the review says what was not set', (
    tester,
  ) async {
    await pumpAbout(tester);
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Age',
      ),
      '31',
    );
    await tap(tester, 'Male');
    await tap(tester, 'Next step');
    expect(find.textContaining('height, weight.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_about_skip_defaults')));
    await tester.pumpAndSettle();
    expect(find.text('How do you move most days?'), findsOneWidget);

    await tap(tester, 'Moderately active');
    await tap(tester, 'Next step');
    await tap(tester, 'Vegetarian');
    await tap(tester, 'Review setup');
    expect(
      find.text(
        '31 years · Not set: using 170 cm · Not set: using 70 kg · '
        'Target Not set: using 70 kg',
      ),
      findsOneWidget,
    );
  });

  testWidgets('target weight starts untouched and follows the goal', (
    tester,
  ) async {
    await pumpAbout(tester);
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Current weight',
      ),
      '80',
    );
    await tap(tester, 'Male');
    await tap(tester, 'Next step');
    await tester.tap(find.byKey(const Key('onboarding_about_skip_defaults')));
    await tester.pumpAndSettle();
    await tap(tester, 'Moderately active');
    await tap(tester, 'Next step');
    await tap(tester, 'Vegetarian');
    await tap(tester, 'Review setup');
    // Maintain (the default goal) keeps the current weight.
    expect(
      find.textContaining('80 kg · Target Not set: using 80 kg'),
      findsOneWidget,
    );
  });

  test('a surplus goal centres the target zone on the target', () {
    final macros = TdeeCalculator.calculateMacros(
      tdee: 2500,
      goal: FitnessGoal.muscleGain,
      weightKg: 70,
    );
    expect(macros.calories, 2800);
    expect(macros.minCalories, 2650);
    expect(macros.maxCalories, 2950);
    expect(
      macros.calories - macros.minCalories,
      macros.maxCalories - macros.calories,
    );
  });
}

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
