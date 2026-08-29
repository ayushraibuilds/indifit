import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/presentation/consumer_copy.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/consumer_task_primitives.dart';

void main() {
  test('shared actions use consistent consumer copy', () {
    expect(ConsumerCopy.logFoodAction, 'Log food');
    expect(ConsumerCopy.quickWorkoutAction, 'Quick workout');
    expect(ConsumerCopy.customizeTodayAction, 'Customize today');
    expect(
      ConsumerCopy.nutritionDetailsIncomplete,
      'Some nutrition details are incomplete',
    );
    expect(ConsumerCopy.earlierEntry, 'Earlier entry');
    expect(ConsumerCopy.historyAction('workout'), 'View workout history');
    expect(ConsumerCopy.historyAction('strength'), 'View strength history');
    expect(ConsumerCopy.logToMeal('LUNCH'), 'Log to lunch');
    expect(
      ConsumerCopy.updateFoodInMeal('BREAKFAST'),
      'Update food in breakfast',
    );
    expect(
      ConsumerCopy.addFoodsToMeal(count: 1, meal: 'DINNER'),
      'Add 1 food to dinner',
    );
    expect(
      ConsumerCopy.addFoodsToMeal(count: 2, meal: 'DINNER'),
      'Add 2 foods to dinner',
    );
  });

  testWidgets(
    'shared status pattern keeps loading concise and retry conditional',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: ConsumerStatusRow(
              label: 'Loading workout history',
              loading: true,
            ),
          ),
        ),
      );

      expect(find.text('Loading workout history'), findsOneWidget);
      expect(find.byTooltip('Retry'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ConsumerStatusRow(
              label: 'Workout history unavailable',
              detail: 'Try again to load your history.',
              error: true,
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Workout history unavailable'), findsOneWidget);
      expect(find.byTooltip('Retry'), findsOneWidget);
    },
  );
}
