import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/motion/indifit_motion.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

class _Counter extends StatefulWidget {
  const _Counter({required this.reduceMotion});

  final bool reduceMotion;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  double value = 100;

  @override
  Widget build(BuildContext context) => _app(
    reduceMotion: widget.reduceMotion,
    Column(
      children: [
        IndiFitCountUp(
          value: value,
          builder: (context, shown) => Text('kcal ${shown.round()}'),
        ),
        TextButton(
          onPressed: () => setState(() => value = 500),
          child: const Text('log'),
        ),
      ],
    ),
  );
}

void main() {
  group('IndiFitEnter', () {
    testWidgets('fades and rises in, then settles on the plain child', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const IndiFitEnter(child: Text('hello'))));
      final first = tester.widget<Opacity>(find.byType(Opacity));
      expect(first.opacity, lessThan(1));
      expect(find.bySemanticsLabel('hello'), findsOneWidget);

      final element = tester.element(find.text('hello'));
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      // The child keeps its element (and state) when the animation ends.
      expect(tester.element(find.text('hello')), same(element));
    });

    testWidgets('Reduce Motion shows the final state on frame one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          reduceMotion: true,
          const IndiFitEnter(
            delay: Duration(milliseconds: 80),
            child: Text('hello'),
          ),
        ),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      expect(tester.binding.transientCallbackCount, 0, reason: 'no ticker');
    });

    testWidgets('stagger delays the first six children only', (tester) async {
      final children = IndiFitMotion.stagger([
        for (var i = 0; i < 8; i++) Text('item $i'),
      ]);
      expect(children.take(6), everyElement(isA<IndiFitEnter>()));
      expect(children.skip(6), everyElement(isA<Text>()));
      expect(
        (children[5] as IndiFitEnter).delay,
        IndiFitMotion.staggerStep * 5,
      );

      await tester.pumpWidget(_app(Column(children: children)));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0, reason: 'no ticker');
    });
  });

  group('IndiFitCountUp', () {
    testWidgets('opens on the real value, then counts between updates', (
      tester,
    ) async {
      await tester.pumpWidget(const _Counter(reduceMotion: false));
      expect(find.text('kcal 100'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0, reason: 'no ticker');

      await tester.tap(find.text('log'));
      await tester.pump();
      await tester.pump(IndiFitMotion.countUpDuration ~/ 3);
      final mid = tester
          .widgetList<Text>(find.textContaining('kcal '))
          .single
          .data!;
      final shown = int.parse(mid.split(' ').last);
      expect(shown, greaterThan(100));
      expect(shown, lessThan(500));

      await tester.pumpAndSettle();
      expect(find.text('kcal 500'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0, reason: 'no ticker');
    });

    testWidgets('Reduce Motion jumps straight to the new value', (
      tester,
    ) async {
      await tester.pumpWidget(const _Counter(reduceMotion: true));
      await tester.tap(find.text('log'));
      // One frame, no in-between values (the button's ink ripple still runs).
      await tester.pump();
      expect(find.text('kcal 500'), findsOneWidget);
    });
  });

  group('IndiFitSuccessMorph', () {
    Widget morph({required bool success, bool reduceMotion = false}) => _app(
      reduceMotion: reduceMotion,
      IndiFitSuccessMorph(
        success: success,
        successChild: const Text('Added'),
        child: const Text('Add'),
      ),
    );

    testWidgets('cross-fades to the success content and back', (tester) async {
      await tester.pumpWidget(morph(success: false));
      expect(find.text('Add'), findsOneWidget);

      await tester.pumpWidget(morph(success: true));
      await tester.pump(IndiFitMotion.morphDuration ~/ 2);
      expect(find.text('Add'), findsOneWidget, reason: 'mid cross-fade');
      expect(find.text('Added'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Add'), findsNothing);
      expect(find.text('Added'), findsOneWidget);

      await tester.pumpWidget(morph(success: false));
      await tester.pumpAndSettle();
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Added'), findsNothing);
    });

    testWidgets('Reduce Motion swaps without a transition', (tester) async {
      await tester.pumpWidget(morph(success: false, reduceMotion: true));
      await tester.pumpWidget(morph(success: true, reduceMotion: true));
      await tester.pump();
      expect(find.text('Add'), findsNothing);
      expect(find.text('Added'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0, reason: 'no ticker');
    });
  });

  group('IndiFitPop', () {
    testWidgets('springs from 92 % to full size', (tester) async {
      await tester.pumpWidget(_app(const IndiFitPop(child: Text('best'))));
      final scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(IndiFitPop),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scale.scale.value, closeTo(0.92, 0.001));
      await tester.pumpAndSettle();
      expect(scale.scale.value, 1);
    });

    testWidgets('Reduce Motion renders at full size at once', (tester) async {
      await tester.pumpWidget(
        _app(reduceMotion: true, const IndiFitPop(child: Text('best'))),
      );
      final scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(IndiFitPop),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scale.scale.value, 1);
      expect(tester.binding.transientCallbackCount, 0, reason: 'no ticker');
    });
  });

  group('IndiFitSharedAxisSwitcher', () {
    Widget page(String id, {bool reverse = false, bool reduce = false}) => _app(
      reduceMotion: reduce,
      IndiFitSharedAxisSwitcher(
        reverse: reverse,
        child: Text(id, key: ValueKey(id)),
      ),
    );

    testWidgets('keeps both pages during the slide, then only the new one', (
      tester,
    ) async {
      await tester.pumpWidget(page('squat'));
      await tester.pumpWidget(page('bench'));
      await tester.pump(IndiFitMotion.sharedAxisDuration ~/ 2);
      expect(find.text('squat'), findsOneWidget);
      expect(find.text('bench'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('squat'), findsNothing);
      expect(find.text('bench'), findsOneWidget);
    });

    testWidgets('Reduce Motion switches pages at once', (tester) async {
      await tester.pumpWidget(page('squat', reduce: true));
      await tester.pumpWidget(page('bench', reduce: true));
      await tester.pump();
      expect(find.text('squat'), findsNothing);
      expect(find.text('bench'), findsOneWidget);
    });
  });

  test('the spring curve starts at 0 and ends exactly at 1', () {
    final curve = IndiFitMotion.springCurve(IndiFitMotion.popDuration);
    expect(curve.transform(0), 0);
    expect(curve.transform(1), 1);
    expect(curve.transform(0.5), greaterThan(0.5));
  });
}
