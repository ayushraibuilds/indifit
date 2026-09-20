import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createApp() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(
        home: OnboardingScreen(),
      ),
    );
  }

  group('Onboarding Step Counter & Unit Suffix Tests (Item 16)', () {
    testWidgets('Unit suffixes (years, cm, kg) remain visible alongside checkmark when valid', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('1 of 5'), findsOneWidget);

      // Verify suffixes are initially visible
      expect(find.text('years'), findsOneWidget);
      expect(find.text('cm'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);

      // Enter valid age
      final ageField = find.byType(TextField).at(0);
      await tester.enterText(ageField, '25');
      await tester.pump();

      // 'years' must STILL be visible along with checkmark
      expect(find.text('years'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsAtLeastNWidgets(1));
    });

    testWidgets('Step counter accurately displays 1 of 5 through 5 of 5 across all steps', (tester) async {
      await tester.pumpWidget(createApp());
      await tester.pump(const Duration(milliseconds: 200));

      Future<void> tapVisible(String text) async {
        final finder = find.text(text);
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      // Step 1 of 5: About you
      expect(find.text('1 of 5'), findsOneWidget);

      // Select sex (age/height/weight already have defaults)
      await tapVisible('Male');
      await tapVisible('Next Step');

      // Step 2 of 5: Goal
      expect(find.text('2 of 5'), findsOneWidget);
      await tapVisible('Maintain');
      await tapVisible('Next Step');

      // Step 3 of 5: Activity
      expect(find.text('3 of 5'), findsOneWidget);
      await tapVisible('Moderately Active');
      await tapVisible('Next Step');

      // Step 4 of 5: Diet
      expect(find.text('4 of 5'), findsOneWidget);
      expect(find.text('Review setup'), findsOneWidget);

      // Tap Review setup -> Step 5 of 5 (Payoff)
      await tapVisible('Review setup');
      expect(find.text('5 of 5'), findsOneWidget);
      expect(find.text('Finish setup'), findsOneWidget);

      // Tap Back -> returns to 4 of 5
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('4 of 5'), findsOneWidget);
      expect(find.text('Review setup'), findsOneWidget);
    });
  });
}
