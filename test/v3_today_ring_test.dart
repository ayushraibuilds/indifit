import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_presentation_types.dart';
import 'package:indifit/features/dashboard/widgets/today_nutrition_widgets.dart';

/// V3 (PREMIUM_REDESIGN_PLAN § 8.2): the Today ring's gradient and glow, and
/// the "+230 kcal · Poha" chip after a log.
void main() {
  final day = DateTime(2026, 10, 9);

  TodayNutritionMetricPresentation kcal(double value, {double target = 2546}) =>
      TodayNutritionMetricPresentation(
        nutrientId: 'energy',
        label: 'Calories',
        value: '${value.round()}',
        unit: 'kcal',
        estimated: false,
        isAvailable: true,
        isRange: false,
        isIncomplete: false,
        pointValue: value,
        lowerValue: null,
        upperValue: null,
        targetValue: target,
      );

  TodayNutritionPresentation nutrition(
    double calories,
    List<(String, String)> records, {
    double target = 2546,
  }) => TodayNutritionPresentation(
    state: TodayPresentationState.ready,
    headline: 'Nutrition today',
    detail: 'Your day at a glance.',
    calories: kcal(calories, target: target),
    hasAcceptedCalorieTarget: true,
    isNoConsumptionKnown: records.isEmpty,
    loggedRecords: records,
  );

  group('todayLoggedChipLabel', () {
    String? label(
      TodayNutritionPresentation next, {
      Set<String>? ids = const {'a'},
      double? kcal = 1190,
      DateTime? seenOn,
      DateTime? date,
    }) => todayLoggedChipLabel(
      previousDate: seenOn ?? day,
      previousIds: ids,
      previousKcal: kcal,
      date: date ?? day,
      presentation: next,
    );

    test('one new record names the food', () {
      expect(
        label(nutrition(1420, [('a', 'Dal'), ('b', 'Poha')])),
        '+230 kcal · Poha',
      );
    });

    test('several new records count the foods', () {
      expect(
        label(nutrition(1830, [('a', 'Dal'), ('b', 'Rice'), ('c', 'Roti')])),
        '+640 kcal · 2 foods',
      );
    });

    test('no chip on first view, another day, deletes or a lower total', () {
      final next = nutrition(1420, [('a', 'Dal'), ('b', 'Poha')]);
      expect(label(next, ids: null, kcal: null), isNull);
      expect(
        label(next, seenOn: day.subtract(const Duration(days: 1))),
        isNull,
      );
      // "a" was deleted and "b" added: not a pure log, so no claim.
      expect(label(nutrition(1420, [('b', 'Poha')])), isNull);
      // An edit that lowered the total.
      expect(label(nutrition(900, [('a', 'Dal'), ('b', 'Poha')])), isNull);
      // Nothing new.
      expect(label(nutrition(1190, [('a', 'Dal')])), isNull);
    });

    test('unknown totals make no claim', () {
      final incomplete = TodayNutritionPresentation(
        state: TodayPresentationState.ready,
        headline: 'Nutrition details incomplete',
        detail: '',
        calories: const TodayNutritionMetricPresentation(
          nutrientId: 'energy',
          label: 'Calories',
          value: '—',
          unit: 'kcal',
          estimated: false,
          isAvailable: false,
          isRange: false,
          isIncomplete: true,
          pointValue: null,
          lowerValue: null,
          upperValue: null,
          targetValue: 2546,
        ),
        loggedRecords: const [('a', 'Dal'), ('b', 'Poha')],
      );
      expect(label(incomplete), isNull);
    });
  });

  group('ring painter', () {
    CalorieRingPainter painter(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('today_calorie_ring')),
                )
                .painter!
            as CalorieRingPainter;

    Future<void> pumpRing(WidgetTester tester, double eaten) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: CalorieRing(
                calories: kcal(eaten, target: 2000),
                hasTarget: true,
                incomplete: false,
                noConsumption: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('under target: green to teal with a glow, 14 pt stroke', (
      tester,
    ) async {
      await pumpRing(tester, 1450);
      final ring = painter(tester);
      final colors = tester.element(find.byType(CalorieRing)).b05Colors;
      expect(ring.color, colors.success.indicator);
      expect(ring.endColor, colors.protein.indicator);
      expect(ring.glow, isTrue);
      expect(CalorieRingPainter.stroke, 14);
    });

    testWidgets('over target: solid red, no glow', (tester) async {
      await pumpRing(tester, 2300);
      final ring = painter(tester);
      final colors = tester.element(find.byType(CalorieRing)).b05Colors;
      expect(ring.color, colors.danger.indicator);
      expect(ring.endColor, isNull);
      expect(ring.glow, isFalse);
    });
  });

  group('log chip on Today', () {
    Future<void> pumpHero(
      WidgetTester tester,
      TodayNutritionPresentation presentation, {
      bool reduceMotion = false,
      DateTime? date,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(
              body: SingleChildScrollView(
                child: TodayNutritionHero(
                  presentation: presentation,
                  onLogFood: () {},
                  onOpenFoodGuidance: null,
                  dateRelation: TodayDateRelation.past,
                  selectedDate: date ?? day,
                  onOpenTargetSetup: () {},
                  onRetry: () {},
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a log shows the chip once, then it goes', (tester) async {
      await pumpHero(tester, nutrition(1190, [('a', 'Dal')]));
      await tester.pumpAndSettle();
      expect(find.byType(TodayLoggedChip), findsNothing);

      await pumpHero(tester, nutrition(1420, [('a', 'Dal'), ('b', 'Poha')]));
      await tester.pump();
      expect(find.text('+230 kcal · Poha'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(TodayLoggedChip.duration);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
      expect(find.byType(TodayLoggedChip), findsNothing);
    });

    testWidgets('the chip survives a loading state between the two reads', (
      tester,
    ) async {
      await pumpHero(tester, nutrition(1190, [('a', 'Dal')]));
      await tester.pumpAndSettle();
      await pumpHero(
        tester,
        const TodayNutritionPresentation(
          state: TodayPresentationState.loading,
          headline: 'Nutrition today',
          detail: 'Preparing your daily totals.',
        ),
      );
      await tester.pump();
      await pumpHero(tester, nutrition(1420, [('a', 'Dal'), ('b', 'Poha')]));
      await tester.pump();
      expect(find.text('+230 kcal · Poha'), findsOneWidget);
      await tester.pump(TodayLoggedChip.duration + const Duration(seconds: 1));
    });

    testWidgets('Reduce Motion: no chip', (tester) async {
      await pumpHero(
        tester,
        nutrition(1190, [('a', 'Dal')]),
        reduceMotion: true,
      );
      await tester.pump();
      await pumpHero(
        tester,
        nutrition(1420, [('a', 'Dal'), ('b', 'Poha')]),
        reduceMotion: true,
      );
      await tester.pump();
      expect(find.byType(TodayLoggedChip), findsNothing);
    });

    testWidgets('changing the day shows no chip', (tester) async {
      await pumpHero(tester, nutrition(1190, [('a', 'Dal')]));
      await tester.pumpAndSettle();
      await pumpHero(
        tester,
        nutrition(1420, [('a', 'Dal'), ('b', 'Poha')]),
        date: day.add(const Duration(days: 1)),
      );
      await tester.pump();
      expect(find.byType(TodayLoggedChip), findsNothing);
      await tester.pumpAndSettle();
    });
  });
}
