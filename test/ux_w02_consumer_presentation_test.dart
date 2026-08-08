import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/presentation/consumer_copy.dart';
import 'package:indifit/core/presentation/consumer_date_label.dart';
import 'package:indifit/core/presentation/product_failure_presentation.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/models/b02_progress_read_models.dart';
import 'package:indifit/data/models/b04_current_food_models.dart';
import 'package:indifit/features/coaching/b04_consumer_presentation.dart';
import 'package:indifit/features/progress/b02_progress_presentation.dart';

void main() {
  const forbidden = <String>[
    'uuid',
    'source_id',
    'evidence_id',
    'reason_code',
    'daily_totals_missing',
    'goal_version',
    'canonical',
    'persisted',
    'unresolved',
    'utc',
  ];

  test('consumer date labels use civil, human-readable dates', () {
    expect(
      ConsumerDateLabel.day('2026-08-08', today: DateTime(2026, 8, 8)),
      'Today',
    );
    expect(
      ConsumerDateLabel.range('2026-08-01', '2026-08-08'),
      'Aug 1 – Aug 8, 2026',
    );
    expect(
      ConsumerDateLabel.day('2026-08-08', today: DateTime(2026, 8, 9)),
      'Yesterday',
    );
    expect(ConsumerDateLabel.day('2026-08-08'), isNot(contains('UTC')));
  });

  test('unknown failures never expose exception details', () {
    final failure = ProductFailurePresentation.fromError(
      StateError('uuid=secret reason_code=daily_totals_missing'),
    );
    expect(failure.message, 'We couldn’t load this right now. Try again.');
    expect(failure.message, isNot(contains('secret')));
    expect(failure.supportReference, isNull);
  });

  test('consumer mappings hide implementation vocabulary', () {
    final values = <String>[
      ConsumerCopy.state('daily_totals_missing'),
      ConsumerCopy.targetType('food_family'),
      ConsumerCopy.target('tree_nut'),
      ConsumerCopy.strictness('avoid'),
      ConsumerCopy.explanation('daily_totals_missing / UUID / reason_code'),
      B02ProgressPresentation.targetEmpty(),
      B02ProgressPresentation.range(const _Query('2026-08-01', '2026-08-08')),
      B03NutritionPresentation.value(_nutritionValue()),
    ];
    for (final value in values) {
      final lower = value.toLowerCase();
      for (final term in forbidden) {
        expect(
          lower,
          isNot(contains(term)),
          reason: '$term leaked in "$value"',
        );
      }
    }
  });

  test('recommendation presentation collapses raw engine explanations', () {
    final explanation = ConsumerCopy.explanation(
      'daily_totals_missing · goal_version: 7b7d1a5a-9e4c-4dd6-8f2b-123456789abc',
    );
    expect(
      explanation,
      'I need a little more information before I can show this safely.',
    );
    expect(explanation.toLowerCase(), isNot(contains('uuid')));
    expect(explanation.toLowerCase(), isNot(contains('goal_version')));
  });

  testWidgets('production failure component renders safe copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductFailureCard(
            failure: ProductFailurePresentation.fromCode('timeout'),
            onRetry: () {},
          ),
        ),
      ),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(
      find.text('This is taking longer than expected. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}

class _Query extends B02ProgressQuery {
  const _Query(String start, String end)
    : super(
        startLocalDate: start,
        endLocalDate: end,
        timezoneId: 'Asia/Kolkata',
      );
}

B04CurrentFoodNutrientValue _nutritionValue() => B04CurrentFoodNutrientValue(
  nutrientId: 'energy',
  unit: NutrientUnit.kilocalorie,
  state: B04CurrentFoodValueState.known,
  point: '400',
  sourceType: 'meal_log',
  sourceIds: const ['source-1'],
);
