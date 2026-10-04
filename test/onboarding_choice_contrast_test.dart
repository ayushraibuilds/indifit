import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/features/onboarding/widgets/onboarding_step_widgets.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('P1 H8 onboarding choices meet contrast in $name', (
      tester,
    ) async {
      late OnboardingChoiceStyle unselected;
      late OnboardingChoiceStyle selected;
      late B05SemanticColors colors;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              colors = context.b05Colors;
              unselected = OnboardingChoiceStyle.of(context, false);
              selected = OnboardingChoiceStyle.of(context, true);
              return const SizedBox();
            },
          ),
        ),
      );

      // WCAG 1.4.11: a control's boundary and icons need 3:1.
      expect(
        _contrast(unselected.border.top.color, colors.page),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(unselected.border.top.color, unselected.fill),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(selected.border.top.color, colors.page),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(selected.icon, selected.iconBackground),
        greaterThanOrEqualTo(3),
      );
      expect(_contrast(selected.check, selected.fill), greaterThanOrEqualTo(3));
      // Selected and unselected fills must not look alike.
      expect(unselected.fill, isNot(selected.fill));
      expect(_contrast(colors.textPrimary, selected.fill), greaterThan(4.5));
    });
  }

  testWidgets('a selected sex option shows a checkmark, not only colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
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
              Expanded(
                child: OnboardingGenderOptionCard(
                  label: 'Female',
                  icon: Icons.female,
                  selected: true,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.male), findsOneWidget);
    expect(find.byIcon(Icons.female), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
