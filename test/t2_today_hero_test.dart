import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_presentation_types.dart';
import 'package:indifit/features/dashboard/widgets/today_helpers.dart';
import 'package:indifit/features/dashboard/widgets/today_nutrition_widgets.dart';

/// T2 (Today review 12 Oct, "Hero 2.0"): macro tiles, the 42 pt number,
/// ring depth, the coral overflow lap, tap-the-ring for targets and the
/// pink fat test. Gate: goldens for under, over, range, no target and an
/// empty day, dark and light.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final day = DateTime(2026, 10, 12);

  TodayNutritionMetricPresentation metric(
    String id,
    String label,
    double? point, {
    double? target,
    double? lower,
    double? upper,
    String unit = 'g',
  }) {
    String fmt(double v) => formatTodayMetric(v);
    final range = lower != null && upper != null;
    return TodayNutritionMetricPresentation(
      nutrientId: id,
      label: label,
      value: range ? '${fmt(lower)}–${fmt(upper)}' : fmt(point ?? 0),
      unit: unit,
      estimated: range,
      isAvailable: true,
      isRange: range,
      isIncomplete: false,
      pointValue: point,
      lowerValue: lower,
      upperValue: upper,
      targetValue: target,
    );
  }

  TodayNutritionPresentation hero({
    required TodayNutritionMetricPresentation calories,
    required List<double> macros,
    bool targets = true,
    bool empty = false,
  }) => TodayNutritionPresentation(
    state: TodayPresentationState.ready,
    headline: 'Nutrition today',
    detail: '',
    calories: calories,
    hasAcceptedCalorieTarget: targets,
    isNoConsumptionKnown: empty,
    macros: [
      metric('protein', 'Protein', macros[0], target: targets ? 112 : null),
      metric('carbohydrate', 'Carbs', macros[1], target: targets ? 365 : null),
      metric('fat', 'Fat', macros[2], target: targets ? 71 : null),
      metric('fibre', 'Fiber', macros[3]),
    ],
  );

  final states = <String, TodayNutritionPresentation>{
    'under': hero(
      calories: metric('energy', 'Calories', 1450, target: 2546, unit: 'kcal'),
      macros: [64, 182, 41, 18],
    ),
    'over': hero(
      calories: metric('energy', 'Calories', 2945, target: 2546, unit: 'kcal'),
      macros: [96, 410, 88, 22],
    ),
    'range': hero(
      calories: metric(
        'energy',
        'Calories',
        1350,
        lower: 1200,
        upper: 1500,
        target: 2546,
        unit: 'kcal',
      ),
      macros: [58, 170, 39, 14],
    ),
    'no_target': hero(
      calories: metric('energy', 'Calories', 650, unit: 'kcal'),
      macros: [40, 80, 20, 10],
      targets: false,
    ),
    'empty': hero(
      calories: metric('energy', 'Calories', 0, target: 2546, unit: 'kcal'),
      macros: [0, 0, 0, 0],
      empty: true,
    ),
  };

  Widget app(
    ThemeData theme,
    TodayNutritionPresentation presentation, {
    VoidCallback? onTargets,
    double textScale = 1,
  }) => ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(402, 520),
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Builder(
          builder: (context) => ColoredBox(
            color: context.b05Colors.page,
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: const Key('t2_hero'),
                  child: Padding(
                    // Room for the hero's shadow in the golden.
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TodayNutritionHero(
                      presentation: presentation,
                      onLogFood: () {},
                      onOpenFoodGuidance: null,
                      dateRelation: TodayDateRelation.today,
                      selectedDate: day,
                      onOpenTargetSetup: onTargets ?? () {},
                      onRetry: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    ThemeData theme,
    TodayNutritionPresentation presentation, {
    VoidCallback? onTargets,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(402, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(theme, presentation, onTargets: onTargets, textScale: textScale),
    );
    await tester.pumpAndSettle();
  }

  CalorieRingPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(find.byKey(const Key('today_calorie_ring')))
              .painter!
          as CalorieRingPainter;

  group('goldens', () {
    for (final entry in states.entries) {
      for (final (name, theme) in [
        ('dark', AppTheme.darkTheme),
        ('light', AppTheme.lightTheme),
      ]) {
        testWidgets('${entry.key}, $name', tags: const ['golden'], (
          tester,
        ) async {
          await pump(tester, theme, entry.value);
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('t2_hero')),
            matchesGoldenFile('goldens/t2_today_hero_${entry.key}_$name.png'),
          );
        });
      }
    }
  });

  testWidgets('number is 42 pt with tabular figures', (tester) async {
    await pump(tester, AppTheme.darkTheme, states['under']!);
    final number = tester.widget<Text>(find.text('1,450'));
    expect(number.style!.fontSize, 42);
    expect(
      number.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('over target: full green lap, coral second lap, red text only', (
    tester,
  ) async {
    await pump(tester, AppTheme.darkTheme, states['over']!);
    final ring = painter(tester);
    final colors = tester.element(find.byType(CalorieRing)).b05Colors;
    expect(ring.progressHigh, 1.0);
    expect(ring.color, colors.success.indicator);
    expect(ring.endColor, colors.protein.indicator);
    expect(ring.overflow, closeTo(2945 / 2546 - 1, 0.001));
    expect(ring.overflowColor, colors.overflow);
    expect(ring.overflowColor, isNot(colors.danger.indicator));
    final over = tester.widget<Text>(find.text('399 over'));
    expect(over.style!.color, colors.danger.indicator);
    // Carbs (410 / 365 g) is over too: coral, not red.
    final carbs =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(MacroTile).at(1),
                    matching: find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is RangeBarPainter,
                    ),
                  ),
                )
                .painter!
            as RangeBarPainter;
    expect(carbs.color, colors.overflow);
  });

  testWidgets('under target and ranges draw no overflow lap', (tester) async {
    await pump(tester, AppTheme.lightTheme, states['under']!);
    expect(painter(tester).overflow, 0);
    expect(painter(tester).dark, isFalse);
    await pump(tester, AppTheme.lightTheme, states['range']!);
    expect(painter(tester).overflow, 0);
    expect(find.text('1,200–1,500 kcal range'), findsOneWidget);
  });

  testWidgets('tapping the ring opens targets', (tester) async {
    var opened = 0;
    await pump(
      tester,
      AppTheme.darkTheme,
      states['under']!,
      onTargets: () => opened++,
    );
    await tester.tap(find.byKey(const Key('today_calorie_ring_tap')));
    expect(opened, 1);
    // The ring reads as a button with its calories as the label.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            (widget.properties.label ?? '').startsWith(
              'Calories 1,450 of 2,546 kilocalories',
            ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Targets'));
    expect(opened, 2);
  });

  testWidgets('three macro tiles and fibre as one quiet line', (tester) async {
    await pump(tester, AppTheme.darkTheme, states['under']!);
    expect(find.byType(MacroTile), findsNWidgets(3));
    expect(find.text('64 / 112 g'), findsOneWidget);
    expect(find.text('18 g · no target'), findsOneWidget);
    expect(find.text('Nutrition'), findsNothing);

    await pump(tester, AppTheme.darkTheme, states['no_target']!);
    // With no targets at all the note would only repeat the ring.
    expect(find.text('10 g'), findsOneWidget);
    expect(find.byType(MacroProgress), findsNothing);
  });

  testWidgets('tiles stack at large text without overflow', (tester) async {
    await pump(tester, AppTheme.darkTheme, states['over']!, textScale: 1.5);
    expect(tester.takeException(), isNull);
    final tiles = find.byType(MacroTile);
    expect(
      tester.getTopLeft(tiles.at(1)).dy,
      greaterThan(tester.getBottomLeft(tiles.at(0)).dy),
    );
  });

  test('fat is pink in both themes and stays apart from the overflow', () {
    expect(B05SemanticColors.dark.fat.indicator, const Color(0xFFF472B6));
    expect(B05SemanticColors.light.fat.indicator, const Color(0xFFDB2777));
    for (final colors in [B05SemanticColors.dark, B05SemanticColors.light]) {
      expect(colors.overflow, isNot(colors.fat.indicator));
      expect(colors.overflow, isNot(colors.danger.indicator));
    }
  });
}
