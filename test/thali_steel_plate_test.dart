import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/services/indifit_haptics.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/features/food_log/thali/circular_thali_plate.dart';

NutritionThaliItem _item(
  String id,
  String label, {
  double amount = 150,
  QuantityUnit unit = QuantityUnit.gram,
}) => NutritionThaliItem(
  id: id,
  position: 0,
  source: NutritionThaliItemSource.food,
  foodId: 'food_$id',
  recipeVersionId: null,
  displayLabel: label,
  quantity: Quantity.fromNum(amount: amount, unit: unit),
);

// One ThemeData for every pump: a new instance would start MaterialApp's
// theme animation on each re-pump.
final _theme = AppTheme.darkTheme;

Widget _plate(
  List<NutritionThaliItem> items, {
  double size = 360,
  bool reduceMotion = false,
  ThaliTiltSource? tiltSource,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: MaterialApp(
    theme: _theme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: size,
          height: size + 40,
          child: CircularThaliPlate(
            items: items,
            previews: const [],
            onSelectItem: (_) {},
            onAddDish: () {},
            onViewAllDishes: () {},
            tiltSource: tiltSource ?? () => const Stream.empty(),
          ),
        ),
      ),
    ),
  ),
);

double _fallOffset(WidgetTester tester, String id) {
  final transform = tester.widget<Transform>(
    find
        .ancestor(
          of: find.byKey(Key('thali_plate_katori_$id')),
          matching: find.byType(Transform),
        )
        .first,
  );
  return transform.transform.getTranslation().y;
}

void main() {
  late List<IndiFitHapticType> haptics;

  setUp(() {
    haptics = [];
    IndiFitHaptics.debugHandler = haptics.add;
  });
  tearDown(() => IndiFitHaptics.debugHandler = null);

  group('katori fill', () {
    Quantity q(double amount, QuantityUnit unit) =>
        Quantity.fromNum(amount: amount, unit: unit);

    test('one piece fills the bowl', () {
      expect(thaliKatoriFill(q(1, QuantityUnit.piece)), 1);
      expect(thaliKatoriFill(q(0.5, QuantityUnit.piece)), 0.5);
      expect(thaliKatoriFill(q(2, QuantityUnit.piece)), 1);
    });

    test('grams and millilitres count against a 150 ml katori', () {
      expect(thaliKatoriFill(q(75, QuantityUnit.gram)), 0.5);
      expect(thaliKatoriFill(q(150, QuantityUnit.millilitre)), 1);
      expect(thaliKatoriFill(q(0.075, QuantityUnit.litre)), closeTo(0.5, 1e-9));
    });

    test('a small portion still reads as food', () {
      expect(thaliKatoriFill(q(10, QuantityUnit.gram)), 0.35);
      expect(thaliKatoriFill(q(0.1, QuantityUnit.piece)), 0.35);
    });
  });

  testWidgets('an added dish drops in with one selection haptic', (
    tester,
  ) async {
    await tester.pumpWidget(_plate([_item('dal', 'Dal Tadka')]));
    await tester.pumpAndSettle();
    expect(haptics, isEmpty, reason: 'opening the plate is not an add');

    await tester.pumpWidget(
      _plate([_item('dal', 'Dal Tadka'), _item('sabzi', 'Aloo Gobi')]),
    );
    expect(haptics, [IndiFitHapticType.selection]);
    await tester.pump(const Duration(milliseconds: 40));
    expect(_fallOffset(tester, 'sabzi'), lessThan(0), reason: 'falling');
    expect(_fallOffset(tester, 'dal'), 0, reason: 'already on the plate');

    await tester.pumpAndSettle();
    expect(_fallOffset(tester, 'sabzi'), 0);
    expect(haptics, hasLength(1));
  });

  testWidgets('Reduce Motion places a new dish at once', (tester) async {
    await tester.pumpWidget(
      _plate([_item('dal', 'Dal Tadka')], reduceMotion: true),
    );
    await tester.pumpWidget(
      _plate([
        _item('dal', 'Dal Tadka'),
        _item('sabzi', 'Aloo Gobi'),
      ], reduceMotion: true),
    );
    await tester.pump();
    expect(_fallOffset(tester, 'sabzi'), 0);
    expect(tester.binding.transientCallbackCount, 0);
    expect(haptics, [IndiFitHapticType.selection]);
  });

  testWidgets('the plate leans with the phone, at most 6 degrees', (
    tester,
  ) async {
    final tilt = StreamController<Offset>();
    // close() on a never-listened controller waits for a listener; don't.
    addTearDown(() => unawaited(tilt.close()));
    await tester.pumpWidget(
      _plate([_item('dal', 'Dal Tadka')], tiltSource: () => tilt.stream),
    );
    expect(tilt.hasListener, isTrue);

    Matrix4 plateTransform() => tester
        .widget<Transform>(
          find
              .ancestor(
                of: find.byKey(const Key('thali_plate_katori_dal')),
                matching: find.byType(Transform),
              )
              .last,
        )
        .transform;
    final level = Matrix4.identity()..setEntry(3, 2, 0.0012);
    expect(plateTransform(), level);

    tilt.add(const Offset(0.05, 0));
    await tester.pump();
    expect(plateTransform(), isNot(level));
    expect(CircularThaliPlate.maxTilt, closeTo(0.1047, 0.0001));
  });

  testWidgets('Reduce Motion never listens to the sensor', (tester) async {
    final tilt = StreamController<Offset>();
    // close() on a never-listened controller waits for a listener; don't.
    addTearDown(() => unawaited(tilt.close()));
    await tester.pumpWidget(
      _plate(
        [_item('dal', 'Dal Tadka')],
        reduceMotion: true,
        tiltSource: () => tilt.stream,
      ),
    );
    expect(tilt.hasListener, isFalse);
  });

  testWidgets('the sensor stops when the plate goes away', (tester) async {
    final tilt = StreamController<Offset>();
    // close() on a never-listened controller waits for a listener; don't.
    addTearDown(() => unawaited(tilt.close()));
    await tester.pumpWidget(
      _plate([_item('dal', 'Dal Tadka')], tiltSource: () => tilt.stream),
    );
    expect(tilt.hasListener, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tilt.hasListener, isFalse);
  });

  testWidgets('every dish and the add slot keep a 48 pt target at 320 pt', (
    tester,
  ) async {
    await tester.pumpWidget(
      _plate([
        _item('roti', 'Roti', unit: QuantityUnit.piece, amount: 2),
        _item('dal', 'Dal Tadka'),
        _item('sabzi', 'Aloo Gobi'),
        _item('curd', 'Curd'),
      ], size: 288),
    );
    await tester.pumpAndSettle();
    for (final key in [
      'thali_plate_staple_roti',
      'thali_plate_katori_dal',
      'thali_plate_katori_sabzi',
      'thali_plate_katori_curd',
      'thali_plate_add_slot',
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
  });
}
