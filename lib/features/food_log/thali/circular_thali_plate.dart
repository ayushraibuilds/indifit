import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/motion/indifit_motion.dart';
import '../../../core/nutrition_thali.dart';
import '../../../core/services/indifit_haptics.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/typed_quantities.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import 'steel_thali_art.dart';
import 'thali_plate_layout.dart';
import 'thali_quantity_label.dart';

/// A stream of plate tilt in radians, already smoothed and clamped.
typedef ThaliTiltSource = Stream<Offset> Function();

/// The steel thali: staples in the centre, katoris around them, the macro
/// split on the rim and a P / C / F legend underneath (concept A).
///
/// Each dish keeps its key, semantics label and 48 pt target. Motion: a new
/// dish drops in with a selection haptic, the others glide to their new
/// places, fill levels and the rim animate, and the plate leans with the
/// phone. All of it is still under Reduce Motion.
class CircularThaliPlate extends StatefulWidget {
  const CircularThaliPlate({
    super.key,
    required this.items,
    required this.previews,
    this.preview,
    this.selectedItemId,
    required this.onSelectItem,
    required this.onAddDish,
    required this.onViewAllDishes,
    this.tiltSource,
  });

  final List<NutritionThaliItem> items;
  final List<NutritionThaliItemPreview> previews;
  final NutritionThaliPreview? preview;
  final String? selectedItemId;
  final ValueChanged<String?> onSelectItem;
  final VoidCallback onAddDish;
  final VoidCallback onViewAllDishes;

  /// Defaults to the phone's accelerometer; tests pass their own or none.
  final ThaliTiltSource? tiltSource;

  /// The furthest the plate leans either way: 6°.
  static const double maxTilt = 6 * math.pi / 180;

  @override
  State<CircularThaliPlate> createState() => _CircularThaliPlateState();
}

class _CircularThaliPlateState extends State<CircularThaliPlate>
    with WidgetsBindingObserver {
  final _tilt = ValueNotifier<Offset>(Offset.zero);
  StreamSubscription<Offset>? _tiltSubscription;
  var _built = false;
  var _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTilt();
  }

  @override
  void didUpdateWidget(CircularThaliPlate oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = {for (final item in oldWidget.items) item.id};
    if (widget.items.any((item) => !before.contains(item.id))) {
      unawaited(IndiFitHaptics.selection());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncTilt();
  }

  /// Listen only while the plate is on screen, the app is in front and
  /// motion is allowed.
  void _syncTilt() {
    final route = ModalRoute.of(context);
    final wanted =
        _resumed &&
        (route?.isCurrent ?? true) &&
        !B05MotionPolicy.reduceMotion(context);
    if (wanted && _tiltSubscription == null) {
      final source = widget.tiltSource ?? thaliAccelerometerTilt;
      _tiltSubscription = source().listen(
        (value) => _tilt.value = value,
        // No sensor (simulator, tests): the plate simply stays level.
        onError: (Object _) => _stopTilt(),
        cancelOnError: true,
      );
    } else if (!wanted) {
      _stopTilt();
    }
  }

  void _stopTilt() {
    unawaited(_tiltSubscription?.cancel());
    _tiltSubscription = null;
    _tilt.value = Offset.zero;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_tiltSubscription?.cancel());
    _tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final animateEntry = _built;
    _built = true;
    // Its own layer: the tilt repaints at frame rate without touching the
    // rest of the screen.
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : width + _legendHeight;
          // When height is tight the legend gives way before the plate does.
          var showLegend = true;
          var diameter = math.min(
            math.min(width - 32, height - _legendHeight - 8),
            340.0,
          );
          if (diameter < 140) {
            showLegend = false;
            diameter = math.min(math.min(width - 32, height - 8), 340.0);
          }
          if (diameter < 140) return const SizedBox.shrink();

          final layout = ThaliPlateLayoutEngine.computeLayout(
            items: widget.items,
            previews: widget.previews,
            colors: colors,
            showAddSlot: true,
          );
          final grams = _macroGrams(widget.preview);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<Offset>(
                valueListenable: _tilt,
                builder: (context, tilt, child) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateX(-tilt.dy)
                    ..rotateY(tilt.dx),
                  child: child,
                ),
                child: SizedBox.square(
                  dimension: diameter,
                  child: _PlateBody(
                    diameter: diameter,
                    layout: layout,
                    preview: widget.preview,
                    split: grams.split,
                    tilt: _tilt,
                    selectedItemId: widget.selectedItemId,
                    animateEntry: animateEntry,
                    onSelectItem: widget.onSelectItem,
                    onAddDish: widget.onAddDish,
                    onViewAllDishes: widget.onViewAllDishes,
                  ),
                ),
              ),
              if (showLegend) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: _legendHeight,
                  child: grams.split.isEmpty
                      ? null
                      : _MacroLegend(
                          protein: grams.protein,
                          carbs: grams.carbs,
                          fat: grams.fat,
                        ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static const double _legendHeight = 24;
}

({double protein, double carbs, double fat, ThaliMacroSplit split}) _macroGrams(
  NutritionThaliPreview? preview,
) {
  final facts = preview?.aggregate.facts;
  final protein = facts?['protein']?.point?.value.asDouble ?? 0.0;
  final carbs = facts?['carbohydrate']?.point?.value.asDouble ?? 0.0;
  final fat = facts?['fat']?.point?.value.asDouble ?? 0.0;
  return (
    protein: protein,
    carbs: carbs,
    fat: fat,
    split: ThaliMacroSplit.fromGrams(protein: protein, carbs: carbs, fat: fat),
  );
}

/// Tilt from gravity: a low-passed lean relative to how the phone was held
/// when the plate opened, clamped to [CircularThaliPlate.maxTilt]. Gravity
/// gives an absolute angle, so the plate never drifts the way integrated
/// gyroscope rates would.
Stream<Offset> thaliAccelerometerTilt() {
  // Phones only. Widget tests have no sensor plugin, and the plugin reports
  // that through the global error handler rather than the stream.
  if (!(Platform.isIOS || Platform.isAndroid) ||
      Platform.environment.containsKey('FLUTTER_TEST')) {
    return const Stream.empty();
  }
  Offset? baseline;
  var smoothed = Offset.zero;
  const max = CircularThaliPlate.maxTilt;
  return accelerometerEventStream(
    samplingPeriod: SensorInterval.uiInterval,
  ).map((event) {
    double angle(double g) => math.asin((g / 9.81).clamp(-1.0, 1.0));
    final raw = Offset(angle(event.x), angle(event.y));
    baseline ??= raw;
    final lean = raw - baseline!;
    smoothed = Offset.lerp(smoothed, lean, 0.15)!;
    return Offset(
      (smoothed.dx * 0.5).clamp(-max, max),
      (-smoothed.dy * 0.5).clamp(-max, max),
    );
  });
}

/// How full a katori looks: one katori, serving or piece fills it, and
/// grams or millilitres count against a 150 ml katori. Clamped to
/// 0.35–1.0 so a small portion still reads as food.
double thaliKatoriFill(Quantity quantity) {
  final amount = quantity.amount.asDouble;
  final level = switch (quantity.unit) {
    QuantityUnit.householdReference ||
    QuantityUnit.serving ||
    QuantityUnit.piece => amount,
    QuantityUnit.gram || QuantityUnit.millilitre => amount / 150,
    QuantityUnit.kilogram || QuantityUnit.litre => amount * 1000 / 150,
    QuantityUnit.milligram => amount / 150000,
    QuantityUnit.unknown || QuantityUnit.legacy => 1.0,
  };
  return level.clamp(0.35, 1.0);
}

class _PlateBody extends StatelessWidget {
  const _PlateBody({
    required this.diameter,
    required this.layout,
    required this.preview,
    required this.split,
    required this.tilt,
    required this.selectedItemId,
    required this.animateEntry,
    required this.onSelectItem,
    required this.onAddDish,
    required this.onViewAllDishes,
  });

  final double diameter;
  final ({
    List<ThaliItemSlot> centerStaples,
    List<ThaliPlateSlot> perimeterSlots,
  })
  layout;
  final NutritionThaliPreview? preview;
  final ThaliMacroSplit split;
  final ValueNotifier<Offset> tilt;
  final String? selectedItemId;
  final bool animateEntry;
  final ValueChanged<String?> onSelectItem;
  final VoidCallback onAddDish;
  final VoidCallback onViewAllDishes;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final tones = SteelTones.of(context);
    final katori = (diameter * 0.25).clamp(48.0, 76.0);
    final orbit = diameter * 0.32;
    final centre = diameter * 0.36;
    final glide = B05MotionPolicy.transitionDuration(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: Semantics(
              label: preview?.isPartial == true
                  ? 'Thali macro distribution ring with partial nutrition estimate'
                  : 'Thali macro distribution ring',
              child: TweenAnimationBuilder<ThaliMacroSplit>(
                tween: _SplitTween(end: split),
                duration: B05MotionPolicy.transitionDuration(
                  context,
                  standard: B05MotionPolicy.completionDuration,
                ),
                curve: B05MotionPolicy.standardCurve,
                builder: (context, value, _) => CustomPaint(
                  painter: SteelPlatePainter(
                    tones: tones,
                    colors: colors,
                    split: value,
                    partial: preview?.isPartial ?? false,
                    tilt: tilt,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: (diameter - centre) / 2,
          top: (diameter - centre) / 2,
          width: centre,
          height: centre,
          child: _CentreStaples(
            staples: layout.centerStaples,
            tones: tones,
            selectedItemId: selectedItemId,
            onSelectItem: onSelectItem,
          ),
        ),
        for (final slot in layout.perimeterSlots)
          AnimatedPositioned(
            key: ValueKey(_slotKey(slot)),
            duration: glide,
            curve: B05MotionPolicy.standardCurve,
            left: diameter / 2 + orbit * math.cos(slot.angle) - katori / 2,
            top: diameter / 2 + orbit * math.sin(slot.angle) - katori / 2,
            width: katori,
            height: katori,
            child: _DropIn(
              enabled: animateEntry && slot is ThaliItemSlot,
              child: _PerimeterSlot(
                slot: slot,
                tones: tones,
                size: katori,
                selectedItemId: selectedItemId,
                onSelectItem: onSelectItem,
                onAddDish: onAddDish,
                onViewAllDishes: onViewAllDishes,
              ),
            ),
          ),
      ],
    );
  }

  static String _slotKey(ThaliPlateSlot slot) => switch (slot) {
    ThaliItemSlot(:final item) => 'katori:${item.id}',
    ThaliAddSlot() => 'katori:add',
    ThaliOverflowSlot() => 'katori:overflow',
  };
}

class _SplitTween extends Tween<ThaliMacroSplit> {
  _SplitTween({required ThaliMacroSplit end}) : super(end: end);

  @override
  ThaliMacroSplit lerp(double t) =>
      ThaliMacroSplit.lerp(begin ?? end!, end!, t);
}

/// A new dish falls into place from 24 pt above with a little bounce.
class _DropIn extends StatefulWidget {
  const _DropIn({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  static const duration = Duration(milliseconds: 420);

  @override
  State<_DropIn> createState() => _DropInState();
}

class _DropInState extends State<_DropIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _DropIn.duration,
  );
  late final Animation<double> _fall = CurvedAnimation(
    parent: _controller,
    curve: IndiFitMotion.springCurve(_DropIn.duration),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.enabled && !B05MotionPolicy.reduceMotion(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fall,
      child: widget.child,
      builder: (context, child) => Opacity(
        // Fades in over the first third while it falls.
        opacity: math.min(1.0, _controller.value / 0.3),
        alwaysIncludeSemantics: true,
        child: Transform.translate(
          offset: Offset(0, -24 * (1 - _fall.value)),
          child: child,
        ),
      ),
    );
  }
}

class _CentreStaples extends StatelessWidget {
  const _CentreStaples({
    required this.staples,
    required this.tones,
    required this.selectedItemId,
    required this.onSelectItem,
  });

  final List<ThaliItemSlot> staples;
  final SteelTones tones;
  final String? selectedItemId;
  final ValueChanged<String?> onSelectItem;

  @override
  Widget build(BuildContext context) {
    if (staples.isEmpty) {
      return Semantics(
        label: 'Center platter, empty',
        child: const SizedBox.expand(),
      );
    }
    if (staples.length == 1) {
      return _Staple(
        slot: staples.single,
        tones: tones,
        selected: selectedItemId == staples.single.item.id,
        onSelectItem: onSelectItem,
      );
    }
    return Row(
      children: [
        for (final slot in staples.take(2))
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _Staple(
                  slot: slot,
                  tones: tones,
                  selected: selectedItemId == slot.item.id,
                  onSelectItem: onSelectItem,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Staple extends StatelessWidget {
  const _Staple({
    required this.slot,
    required this.tones,
    required this.selected,
    required this.onSelectItem,
  });

  final ThaliItemSlot slot;
  final SteelTones tones;
  final bool selected;
  final ValueChanged<String?> onSelectItem;

  @override
  Widget build(BuildContext context) {
    final item = slot.item;
    final energy = _energy(slot.preview);
    final energyStr = energy != null ? '${energy.round()} kcal' : null;
    final quantityStr = thaliQuantityLabel(item.quantity);
    final pieces = item.quantity.unit == QuantityUnit.piece
        ? item.quantity.amount.asDouble.ceil()
        : 1;
    final painter = slot.placement.category == ThaliDishCategory.stapleRice
        ? RiceMoundPainter(tones: tones)
        : RotiStackPainter(tones: tones, pieces: pieces);
    return B05TouchTarget(
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '${item.displayLabel ?? slot.placement.categoryLabel}, ${slot.placement.categoryLabel}, $quantityStr${energyStr != null ? ", $energyStr" : ""}',
        child: GestureDetector(
          key: Key('thali_plate_staple_${item.id}'),
          onTap: () => onSelectItem(selected ? null : item.id),
          behavior: HitTestBehavior.opaque,
          child: ExcludeSemantics(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: CustomPaint(painter: painter)),
                if (selected) const Positioned.fill(child: _SelectedRing()),
                if (energy != null)
                  Positioned(bottom: 2, child: _KcalChip(kcal: energy)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PerimeterSlot extends StatelessWidget {
  const _PerimeterSlot({
    required this.slot,
    required this.tones,
    required this.size,
    required this.selectedItemId,
    required this.onSelectItem,
    required this.onAddDish,
    required this.onViewAllDishes,
  });

  final ThaliPlateSlot slot;
  final SteelTones tones;
  final double size;
  final String? selectedItemId;
  final ValueChanged<String?> onSelectItem;
  final VoidCallback onAddDish;
  final VoidCallback onViewAllDishes;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    switch (slot) {
      case ThaliItemSlot(:final item, :final preview, :final placement):
        final selected = selectedItemId == item.id;
        final energy = _energy(preview);
        final energyStr = energy != null ? '${energy.round()}' : null;
        return B05TouchTarget(
          child: Semantics(
            button: true,
            selected: selected,
            label:
                '${item.displayLabel ?? placement.categoryLabel}, ${placement.categoryLabel}${energyStr != null ? ", $energyStr calories" : ""}',
            child: GestureDetector(
              key: Key('thali_plate_katori_${item.id}'),
              onTap: () => onSelectItem(selected ? null : item.id),
              behavior: HitTestBehavior.opaque,
              child: ExcludeSemantics(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: thaliKatoriFill(item.quantity)),
                        duration: B05MotionPolicy.transitionDuration(context),
                        curve: B05MotionPolicy.standardCurve,
                        builder: (context, fill, _) => CustomPaint(
                          painter: SteelKatoriPainter(
                            tones: tones,
                            category: placement.category,
                            fill: fill,
                            selectedColor: selected ? colors.action : null,
                          ),
                        ),
                      ),
                    ),
                    if (energy != null)
                      Positioned(
                        bottom: size * 0.06,
                        child: _KcalChip(kcal: energy),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

      case ThaliAddSlot():
        return B05TouchTarget(
          child: Semantics(
            button: true,
            label: 'Add dish to platter',
            child: GestureDetector(
              key: const Key('thali_plate_add_slot'),
              onTap: onAddDish,
              behavior: HitTestBehavior.opaque,
              child: ExcludeSemantics(
                child: _EmptyBowl(
                  tones: tones,
                  child: Icon(Icons.add_rounded, color: colors.action),
                ),
              ),
            ),
          ),
        );

      case ThaliOverflowSlot(:final overflowCount):
        return B05TouchTarget(
          child: Semantics(
            button: true,
            label: 'View all $overflowCount more dishes in list',
            child: GestureDetector(
              key: const Key('thali_plate_overflow_slot'),
              onTap: onViewAllDishes,
              behavior: HitTestBehavior.opaque,
              child: ExcludeSemantics(
                child: _EmptyBowl(
                  tones: tones,
                  child: Text(
                    '+$overflowCount',
                    style: B05Typography.label(context).copyWith(
                      color: Colors.white,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }
}

class _EmptyBowl extends StatelessWidget {
  const _EmptyBowl({required this.tones, required this.child});

  final SteelTones tones;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: SteelKatoriPainter(tones: tones, category: null, fill: 0),
          ),
        ),
        child,
      ],
    );
  }
}

class _SelectedRing extends StatelessWidget {
  const _SelectedRing();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: context.b05Colors.action, width: 2.5),
    ),
  );
}

/// The kcal number on a dish: white on a dark pill so it reads over any
/// food colour in both themes.
class _KcalChip extends StatelessWidget {
  const _KcalChip({required this.kcal});

  final double kcal;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          '${kcal.round()}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Names each rim colour with its grams, so colour is never the only cue.
class _MacroLegend extends StatelessWidget {
  const _MacroLegend({
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, grams, role) in [
            ('Protein', protein, colors.protein),
            ('Carbs', carbs, colors.carbs),
            ('Fat', fat, colors.fat),
          ]) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: role.indicator,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$label ${grams.round()} g',
              style: B05Typography.caption(
                context,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            if (label != 'Fat') const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }
}

double? _energy(NutritionThaliItemPreview? preview) =>
    preview?.calculation.facts['energy']?.point?.value.asDouble;

/// The name shown for a dish in short form: the first of several names and
/// without a parenthetical ("Toor Dal / Yellow Dal Tadka" → "Toor Dal"). The
/// full name stays in the semantics label and the dish list.
String thaliPlateShortName(String name) {
  var short = name.split(' / ').first;
  final paren = short.indexOf(' (');
  if (paren > 0) short = short.substring(0, paren);
  return short.trim().isEmpty ? name : short.trim();
}
