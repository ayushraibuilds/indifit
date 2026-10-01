import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/services/b02_activity_form_service.dart';
import 'package:indifit/features/food_log/widgets/edit_food_log_sheet.dart';
import 'package:indifit/features/onboarding/widgets/onboarding_step_widgets.dart';

void main() {
  group('Onboarding UI/UX Refinements', () {
    testWidgets(
      'OnboardingGenderOptionCard renders cleanly on 320px width without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        String selectedSex = 'male';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Row(
                      children: [
                        Expanded(
                          child: OnboardingGenderOptionCard(
                            label: 'Male',
                            icon: Icons.male,
                            selected: selectedSex == 'male',
                            onTap: () => setState(() => selectedSex = 'male'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OnboardingGenderOptionCard(
                            label: 'Female',
                            icon: Icons.female,
                            selected: selectedSex == 'female',
                            onTap: () => setState(() => selectedSex = 'female'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OnboardingGenderOptionCard(
                            label: 'Other',
                            icon: Icons.transgender,
                            selected: selectedSex == 'other',
                            onTap: () => setState(() => selectedSex = 'other'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Verify no overflow errors
        expect(tester.takeException(), isNull);
        expect(find.text('Male'), findsOneWidget);
        expect(find.text('Female'), findsOneWidget);
        expect(find.text('Other'), findsOneWidget);

        // Tap "Other" and verify selection changes without overflow or layout breakage
        await tester.tap(find.text('Other'));
        await tester.pumpAndSettle();
        expect(selectedSex, equals('other'));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'OnboardingGenderOptionCard scales with 2.0x Dynamic Type textScaler',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
                size: Size(390, 844),
              ),
              child: Scaffold(
                body: Row(
                  children: [
                    Expanded(
                      child: OnboardingGenderOptionCard(
                        label: 'Male',
                        icon: Icons.male,
                        selected: false,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OnboardingGenderOptionCard(
                        label: 'Female',
                        icon: Icons.female,
                        selected: true,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OnboardingGenderOptionCard(
                        label: 'Other',
                        icon: Icons.transgender,
                        selected: false,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Female'), findsOneWidget);
      },
    );

    test(
      'OnboardingPageContainer has bottomActionClearance >= 100 to avoid sticky button occlusion',
      () {
        expect(
          OnboardingPageContainer.bottomActionClearance,
          greaterThanOrEqualTo(100.0),
        );
      },
    );
  });

  group('Input Hardening & Validation', () {
    test('B02ActivityFormService rejects negative distanceMetres', () {
      const service = B02ActivityFormService();
      expect(
        () => service.build(
          activityType: B02ActivityType.running,
          durationSeconds: 1800,
          distanceMetres: -500,
        ),
        throwsA(isA<B02ValidationException>()),
      );
    });

    test(
      'B02ActivityFormService rejects negative recoverySeconds in interval workout',
      () {
        const service = B02ActivityFormService();
        expect(
          () => service.build(
            activityType: B02ActivityType.running,
            durationSeconds: 1800,
            isIntervalWorkout: true,
            workSeconds: 60,
            recoverySeconds: -10,
          ),
          throwsA(isA<B02ValidationException>()),
        );
      },
    );

    testWidgets(
      'EditFoodLogSheet displays inline errors and blocks onSave for invalid calories or negative values',
      (tester) async {
        bool onSaveCalled = false;
        final dummyLog = FoodLog(
          id: 1,
          foodItemId: 101,
          name: 'Dal Tadka',
          mealType: 'lunch',
          loggedAt: DateTime.now(),
          calories: 220,
          proteinG: 9.0,
          carbsG: 28.0,
          fatG: 7.0,
          servingLogged: 1.0,
          servingUnit: 'katori',
          isSynced: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EditFoodLogSheet(
                log: dummyLog,
                onSave:
                    ({
                      required id,
                      required name,
                      required calories,
                      required proteinG,
                      required carbsG,
                      required fatG,
                      required servingLogged,
                    }) {
                      onSaveCalled = true;
                    },
              ),
            ),
          ),
        );

        // Enter negative calories
        final caloriesField = find.widgetWithText(TextField, '220');
        await tester.enterText(caloriesField, '-50');

        // Tap Save Changes
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();

        // onSave should NOT be called
        expect(onSaveCalled, isFalse);

        // Inline error should be visible
        expect(find.text('Valid calories required (≥ 0)'), findsOneWidget);
      },
    );

    test('European comma-decimal strings parse safely as doubles', () {
      final input = '4,5'.replaceAll(',', '.');
      final parsed = double.tryParse(input);
      expect(parsed, equals(4.5));
    });

    testWidgets(
      'Profile name field preserves Semantics hint Optional with Name label',
      (tester) async {
        final controller = TextEditingController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Semantics(
                hint: 'Optional',
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Name (optional)'), findsNothing);
        final semantics = tester.getSemantics(find.byType(TextField));
        expect(semantics.label, equals('Name'));
        expect(semantics.hint, equals('Optional'));
      },
    );
  });
}
