import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/motion/indifit_motion.dart';
import 'package:indifit/core/services/indifit_haptics.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_presentation_types.dart';
import 'package:indifit/features/dashboard/widgets/hydration_fluid_fill.dart';
import 'package:indifit/features/dashboard/widgets/today_helpers.dart';
import 'package:indifit/features/dashboard/widgets/today_module_widgets.dart';
import 'package:indifit/features/dashboard/widgets/today_motion.dart';
import 'package:indifit/features/dashboard/widgets/today_nutrition_widgets.dart';

/// T3 (Today review 12 Oct, "Motion"): each moment plays once, in view.
/// Launch runs on loaded content; a log washes the meal row and puts the
/// chip where the eye is; over target flips at the crossing; a day change
/// slides; macro targets flash once a day; the water wave settles; Reduce
/// Motion shows values as they are.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final day = DateTime(2026, 10, 13);
  // One ThemeData: the getter builds a new one, which animates on re-pump.
  final theme = AppTheme.darkTheme;
  final haptics = <IndiFitHapticType>[];

  setUp(() {
    haptics.clear();
    IndiFitHaptics.debugHandler = haptics.add;
  });
  tearDown(() => IndiFitHaptics.debugHandler = null);

  TodayNutritionMetricPresentation metric(
    String id,
    String label,
    double point, {
    double? target,
    String unit = 'g',
  }) => TodayNutritionMetricPresentation(
    nutrientId: id,
    label: label,
    value: formatTodayMetric(point),
    unit: unit,
    estimated: false,
    isAvailable: true,
    isRange: false,
    isIncomplete: false,
    pointValue: point,
    lowerValue: null,
    upperValue: null,
    targetValue: target,
  );

  TodayMealPresentation meal(String type, String label, double? kcal) =>
      TodayMealPresentation(
        mealType: type,
        label: label,
        detail: kcal == null ? 'Nothing yet' : '1 item',
        calorieLabel: kcal == null ? '—' : '${formatTodayMetric(kcal)} kcal',
        kcal: kcal,
        logged: kcal != null,
        nutritionIncomplete: false,
        itemCount: kcal == null ? 0 : 1,
      );

  TodayNutritionPresentation nutrition({
    required double kcal,
    required List<(String, String)> records,
    double protein = 60,
    double? lunch,
  }) => TodayNutritionPresentation(
    state: TodayPresentationState.ready,
    headline: 'Nutrition today',
    detail: '',
    calories: metric('energy', 'Calories', kcal, target: 2546, unit: 'kcal'),
    hasAcceptedCalorieTarget: true,
    isNoConsumptionKnown: records.isEmpty,
    loggedRecords: records,
    macros: [
      metric('protein', 'Protein', protein, target: 112),
      metric('carbohydrate', 'Carbs', 200, target: 365),
      metric('fat', 'Fat', 40, target: 71),
    ],
    meals: [
      meal('breakfast', 'Breakfast', 1190),
      meal('lunch', 'Lunch', lunch),
    ],
  );

  const loading = TodayNutritionPresentation(
    state: TodayPresentationState.loading,
    headline: 'Nutrition today',
    detail: '',
  );

  final first = nutrition(kcal: 1190, records: const [('a', 'Dal')]);
  final logged = nutrition(
    kcal: 1420,
    records: const [('a', 'Dal'), ('b', 'Poha')],
    lunch: 230,
  );

  Future<void> pump(
    WidgetTester tester,
    TodayNutritionPresentation presentation, {
    DateTime? date,
    bool reduceMotion = false,
    double gap = 0,
    double topGap = 0,
  }) async {
    final ready = presentation.state != TodayPresentationState.loading;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(402, 874),
              disableAnimations: reduceMotion,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: TodayDayContent(
                  date: date ?? day,
                  ready: ready,
                  nutrition: presentation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: topGap),
                      TodayEnter(
                        key: const ValueKey('enter-hero'),
                        index: 0,
                        child: TodayNutritionHero(
                          presentation: presentation,
                          onLogFood: () {},
                          onOpenFoodGuidance: null,
                          dateRelation: TodayDateRelation.today,
                          selectedDate: date ?? day,
                          onOpenTargetSetup: () {},
                          onRetry: () {},
                        ),
                      ),
                      SizedBox(height: gap),
                      TodayEnter(
                        key: const ValueKey('enter-meals'),
                        index: 1,
                        child: TodayMealsModule(
                          meals: presentation.meals,
                          loading: !ready,
                          unavailable: false,
                          onLogMeal: (_) {},
                          onRetry: () {},
                          selectedDate: date ?? day,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double enterOpacity(WidgetTester tester, String key) => tester
      .widget<Opacity>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;

  Finder chipIn(Type type) => find.descendant(
    of: find.byType(type),
    matching: find.byType(TodayLoggedChip),
  );

  group('launch', () {
    testWidgets('the entrance waits for loaded content, then plays once', (
      tester,
    ) async {
      await pump(tester, loading);
      await tester.pump(const Duration(milliseconds: 16));
      // Placeholders show as they are.
      expect(enterOpacity(tester, 'enter-hero'), 1);

      await pump(tester, first);
      await tester.pump(const Duration(milliseconds: 16));
      expect(enterOpacity(tester, 'enter-hero'), lessThan(1));
      // The ring counts up from 0 and the bars wait their turn.
      expect(find.text('1,190'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('1,190'), findsOneWidget);
      expect(enterOpacity(tester, 'enter-hero'), 1);
      expect(haptics, isEmpty);

      // A refresh of the same day does not replay it.
      await pump(tester, first);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('1,190'), findsOneWidget);
    });

    testWidgets('Reduce Motion: no entrance, final values at once', (
      tester,
    ) async {
      await pump(tester, loading, reduceMotion: true);
      await pump(tester, first, reduceMotion: true);
      await tester.pump();
      expect(enterOpacity(tester, 'enter-hero'), 1);
      expect(find.text('1,190'), findsOneWidget);
    });
  });

  group('log from a meal row', () {
    testWidgets('the row washes, counts up and the chip rises from it', (
      tester,
    ) async {
      await pump(tester, first);
      await tester.pumpAndSettle();

      await pump(tester, logged);
      await tester.pump();
      expect(chipIn(TodayMealRowWash), findsOneWidget);
      expect(chipIn(TodayNutritionHero), findsNothing);
      expect(find.text('+230 kcal · Poha'), findsOneWidget);
      expect(haptics, [IndiFitHapticType.light]);
      // Mid count-up the row is between "—" and 230.
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('230 kcal'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('230 kcal'), findsOneWidget);
      expect(find.byType(TodayLoggedChip), findsNothing);
      expect(haptics, [IndiFitHapticType.light]);
    });

    testWidgets('row off screen: the chip plays at the ring', (tester) async {
      await pump(tester, first, gap: 1200);
      await tester.pumpAndSettle();
      await pump(tester, logged, gap: 1200);
      await tester.pump();
      expect(chipIn(TodayNutritionHero), findsOneWidget);
      expect(chipIn(TodayMealRowWash), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('neither on screen: no chip, still one haptic', (tester) async {
      await pump(tester, first, gap: 1200, topGap: 1200);
      await tester.pumpAndSettle();
      await pump(tester, logged, gap: 1200, topGap: 1200);
      await tester.pump();
      expect(find.byType(TodayLoggedChip), findsNothing);
      expect(haptics, [IndiFitHapticType.light]);
      await tester.pumpAndSettle();
    });

    testWidgets('waits while Today is hidden, then plays once shown', (
      tester,
    ) async {
      Future<void> app(TodayNutritionPresentation p, bool visible) =>
          tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: TickerMode(
                    enabled: visible,
                    child: SingleChildScrollView(
                      child: TodayDayContent(
                        date: day,
                        ready: true,
                        nutrition: p,
                        child: TodayMealsModule(
                          meals: p.meals,
                          loading: false,
                          unavailable: false,
                          onLogMeal: (_) {},
                          onRetry: () {},
                          selectedDate: day,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
      await app(first, true);
      await tester.pumpAndSettle();
      await app(logged, false);
      await tester.pump(const Duration(seconds: 3));
      expect(haptics, isEmpty);
      expect(find.byType(TodayLoggedChip), findsNothing);

      await app(logged, true);
      await tester.pump();
      await tester.pump();
      expect(haptics, [IndiFitHapticType.light]);
      expect(find.byType(TodayLoggedChip), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('Reduce Motion: no chip and no wash', (tester) async {
      await pump(tester, first, reduceMotion: true);
      await tester.pump();
      await pump(tester, logged, reduceMotion: true);
      await tester.pump();
      expect(find.byType(TodayLoggedChip), findsNothing);
      expect(find.text('230 kcal'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('going over', () {
    testWidgets('"N over" appears at the crossing, with one warning', (
      tester,
    ) async {
      await pump(tester, nutrition(kcal: 2400, records: const [('a', 'Dal')]));
      await tester.pumpAndSettle();
      await pump(
        tester,
        nutrition(
          kcal: 2700,
          records: const [('a', 'Dal'), ('b', 'Biryani')],
          lunch: 300,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // Still short of the target early in the sweep.
      expect(find.textContaining(' left'), findsOneWidget);
      expect(find.textContaining(' over'), findsNothing);
      final ring =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('today_calorie_ring')),
                  )
                  .painter!
              as CalorieRingPainter;
      expect(ring.overflow, 0);

      await tester.pumpAndSettle();
      expect(find.text('154 over'), findsOneWidget);
      expect(haptics, [IndiFitHapticType.warning]);
    });
  });

  group('macro targets', () {
    testWidgets('a target hit flashes once per macro per day', (tester) async {
      await pump(
        tester,
        nutrition(kcal: 1190, records: const [('a', 'Dal')], protein: 100),
      );
      await tester.pumpAndSettle();
      await pump(
        tester,
        nutrition(
          kcal: 1420,
          records: const [('a', 'Dal'), ('b', 'Paneer')],
          protein: 115,
          lunch: 230,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(haptics, [IndiFitHapticType.success]);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Another log the same day does not flash protein again.
      await pump(
        tester,
        nutrition(
          kcal: 1640,
          records: const [('a', 'Dal'), ('b', 'Paneer'), ('c', 'Egg')],
          protein: 121,
          lunch: 450,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(haptics, [IndiFitHapticType.success, IndiFitHapticType.light]);
      await tester.pumpAndSettle();
    });
  });

  group('changing day', () {
    testWidgets('slides, keeping the last day until the next one loads', (
      tester,
    ) async {
      await pump(tester, first);
      await tester.pumpAndSettle();
      final next = day.add(const Duration(days: -1));

      await pump(tester, loading, date: next);
      await tester.pump(const Duration(milliseconds: 50));
      // No placeholders: the last day stays.
      expect(find.text('1,190'), findsOneWidget);
      expect(find.byType(TodayModuleSkeleton), findsNothing);

      final yesterday = nutrition(kcal: 2000, records: const [('z', 'Thali')]);
      await pump(tester, yesterday, date: next);
      await tester.pump(const Duration(milliseconds: 100));
      // Both days are on screen mid-slide.
      expect(find.byType(SharedAxisTransition), findsNWidgets(2));
      // The new day shows its values as they are: no count-up, no chip.
      expect(find.text('2,000'), findsOneWidget);
      expect(find.byType(TodayLoggedChip), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('1,190'), findsNothing);
      expect(haptics, isEmpty);
    });
  });

  group('water', () {
    testWidgets('the wave settles 2 s after the last change and wakes', (
      tester,
    ) async {
      Future<void> fill(double progress, {bool met = false}) =>
          tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: HydrationFluidFillIndicator(
                  progress: progress,
                  isGoalMet: met,
                  repeatInTests: true,
                ),
              ),
            ),
          );
      await fill(.4);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(HydrationFluidFillIndicator.settleDuration);
      expect(tester.hasRunningAnimations, isFalse);

      await fill(1, met: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<HydrationWavePainter>()
          .single;
      expect(painter.ripple, greaterThan(0));
      await tester.pump(HydrationFluidFillIndicator.settleDuration);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  test('timings follow the review table', () {
    expect(TodayMotionTiming.ring, const Duration(milliseconds: 700));
    expect(TodayMotionTiming.bar, const Duration(milliseconds: 360));
    expect(TodayMotionTiming.barStep, const Duration(milliseconds: 60));
    expect(TodayMotionTiming.wash, const Duration(milliseconds: 950));
    expect(TodayLoggedChip.duration, const Duration(milliseconds: 1600));
    expect(IndiFitMotion.popDuration, const Duration(milliseconds: 220));
  });
}
