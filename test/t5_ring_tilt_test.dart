import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/motion/device_tilt.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/widgets/today_nutrition_widgets.dart';

/// T5 (Today review 12 Oct): the calorie ring's gloss line and glow follow
/// the phone's tilt, up to ±3°. Off under Reduce Motion, off screen and in
/// tests (no sensor).
void main() {
  final metric = TodayNutritionMetricPresentation(
    nutrientId: 'energy',
    label: 'Calories',
    value: '1450',
    unit: 'kcal',
    estimated: false,
    isAvailable: true,
    isRange: false,
    isIncomplete: false,
    pointValue: 1450,
    lowerValue: null,
    upperValue: null,
    targetValue: 2546,
  );

  // One ThemeData for every pump: a new instance would start MaterialApp's
  // theme animation on each re-pump.
  final theme = AppTheme.darkTheme;

  Widget ring({
    Stream<Offset> Function()? tiltSource,
    bool reduceMotion = false,
    Widget Function(Widget child)? wrap,
  }) {
    final child = Scaffold(
      body: Center(
        child: CalorieRing(
          calories: metric,
          hasTarget: true,
          incomplete: false,
          noConsumption: false,
          tiltSource: tiltSource,
        ),
      ),
    );
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(theme: theme, home: wrap?.call(child) ?? child),
    );
  }

  CalorieRingPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(find.byKey(const Key('today_calorie_ring')))
              .painter!
          as CalorieRingPainter;

  testWidgets('the light follows the phone, at most 3 degrees', (tester) async {
    final tilt = StreamController<Offset>();
    // close() on a never-listened controller waits for a listener; don't.
    addTearDown(() => unawaited(tilt.close()));
    await tester.pumpWidget(ring(tiltSource: () => tilt.stream));
    await tester.pumpAndSettle();
    expect(tilt.hasListener, isTrue);
    expect(CalorieRing.maxTilt, closeTo(0.0524, 0.0001));
    expect(painter(tester).tilt!.value, Offset.zero);

    tilt.add(const Offset(0.03, -0.02));
    await tester.pump();
    expect(painter(tester).tilt!.value, const Offset(0.03, -0.02));
  });

  testWidgets('Reduce Motion never listens to the sensor', (tester) async {
    final tilt = StreamController<Offset>();
    addTearDown(() => unawaited(tilt.close()));
    await tester.pumpWidget(
      ring(tiltSource: () => tilt.stream, reduceMotion: true),
    );
    await tester.pumpAndSettle();
    expect(tilt.hasListener, isFalse);
    expect(painter(tester).tilt!.value, Offset.zero);
  });

  testWidgets('a hidden tab does not listen to the sensor', (tester) async {
    final tilt = StreamController<Offset>();
    addTearDown(() => unawaited(tilt.close()));
    await tester.pumpWidget(
      ring(
        tiltSource: () => tilt.stream,
        wrap: (child) => TickerMode(enabled: false, child: child),
      ),
    );
    expect(tilt.hasListener, isFalse);
  });

  testWidgets('the sensor stops when the ring goes away', (tester) async {
    final tilt = StreamController<Offset>();
    addTearDown(() => unawaited(tilt.close()));
    await tester.pumpWidget(ring(tiltSource: () => tilt.stream));
    await tester.pumpAndSettle();
    expect(tilt.hasListener, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tilt.hasListener, isFalse);
  });

  testWidgets('tests and desktop have no sensor: the ring stays level', (
    tester,
  ) async {
    await tester.pumpWidget(ring());
    await tester.pumpAndSettle();
    expect(painter(tester).tilt!.value, Offset.zero);
    expect(await deviceTiltStream(maxRadians: 1).isEmpty, isTrue);
  });

  test('painter repaints on tilt only, and the shift is a few pixels', () {
    expect(CalorieRingPainter.glossShift, lessThanOrEqualTo(3));
    expect(CalorieRingPainter.glowShift, lessThanOrEqualTo(4));
    final tilt = ValueNotifier(Offset.zero);
    addTearDown(tilt.dispose);
    CalorieRingPainter make(ValueNotifier<Offset>? t) => CalorieRingPainter(
      progressLow: .5,
      progressHigh: .5,
      color: Colors.green,
      trackColor: Colors.grey,
      range: false,
      tilt: t,
    );
    expect(make(tilt).shouldRepaint(make(tilt)), isFalse);
    expect(make(tilt).shouldRepaint(make(null)), isTrue);
  });
}
