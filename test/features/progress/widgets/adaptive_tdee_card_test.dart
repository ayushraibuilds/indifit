import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/data/models/adaptive_tdee_models.dart';
import 'package:indifit/features/progress/widgets/adaptive_tdee_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createWidgetUnderTest({
    required AdaptiveTdeeEstimate estimate,
    required VoidCallback onAdjustTargets,
  }) {
    return MaterialApp(
      theme: ThemeData(
        extensions: const [B05SemanticColors.light],
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdaptiveTdeeCard(
            estimate: estimate,
            onAdjustTargets: onAdjustTargets,
          ),
        ),
      ),
    );
  }

  group('AdaptiveTdeeCard Widget Tests', () {
    testWidgets('renders metric, confidence pill, trend weight, and disclaimer', (tester) async {
      bool adjustTargetsCalled = false;

      final estimate = AdaptiveTdeeEstimate(
        currentTdeeKcal: 2485.4,
        baselineTdeeKcal: 2500.0,
        currentScaleWeightKg: 74.6,
        trendWeightKg: 74.2,
        confidence: AdaptiveTdeeConfidence.high,
        confidenceMessage: 'High confidence (18/21 food days, 15 weigh-ins).',
        loggedFoodDaysInWindow: 18,
        loggedWeightDaysInWindow: 15,
        totalObservedFoodDays: 30,
        policyVersion: 'adaptive_tdee_v1',
        history: const [],
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          estimate: estimate,
          onAdjustTargets: () => adjustTargetsCalled = true,
        ),
      );

      // Verify metric display
      expect(find.text('2485'), findsOneWidget);
      expect(find.text('kcal/day'), findsOneWidget);

      // Verify confidence pill
      expect(find.text('High Confidence'), findsOneWidget);
      expect(find.text('High confidence (18/21 food days, 15 weigh-ins).'), findsOneWidget);

      // Verify trend weight chip
      expect(find.text('Trend: 74.2 kg · Scale: 74.6 kg'), findsOneWidget);

      // Verify wellness disclaimer
      expect(
        find.text('Informational estimate for general wellness only. Adjust targets in the Coaching Hub.'),
        findsOneWidget,
      );

      // Verify action buttons
      expect(find.text('How it works'), findsOneWidget);
      expect(find.text('Adjust targets'), findsOneWidget);

      // Tap Adjust targets
      await tester.tap(find.text('Adjust targets'));
      await tester.pumpAndSettle();
      expect(adjustTargetsCalled, isTrue);
    });

    testWidgets('tapping "How it works" opens explanatory bottom sheet', (tester) async {
      final estimate = AdaptiveTdeeEstimate(
        currentTdeeKcal: 2200.0,
        baselineTdeeKcal: 2200.0,
        currentScaleWeightKg: null,
        trendWeightKg: null,
        confidence: AdaptiveTdeeConfidence.calibrating,
        confidenceMessage: 'Calibrating: log 4 more food days for moderate confidence.',
        loggedFoodDaysInWindow: 3,
        loggedWeightDaysInWindow: 2,
        totalObservedFoodDays: 3,
        policyVersion: 'adaptive_tdee_v1',
        history: const [],
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          estimate: estimate,
          onAdjustTargets: () {},
        ),
      );

      // Verify calibrating confidence pill
      expect(find.text('Calibrating'), findsOneWidget);

      // Tap How it works
      await tester.tap(find.text('How it works'));
      await tester.pumpAndSettle();

      // Bottom sheet contents
      expect(find.text('How Adaptive TDEE Works'), findsOneWidget);
      expect(find.textContaining('Expenditure = Calories In - (Delta Trend Weight * 7,700 kcal)'), findsOneWidget);
      expect(find.textContaining('Adherence-Neutral'), findsOneWidget);

      // Tap Got it to dismiss
      await tester.ensureVisible(find.text('Got it'));
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('How Adaptive TDEE Works'), findsNothing);
    });
  });
}
