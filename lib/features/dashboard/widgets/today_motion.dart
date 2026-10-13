import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/motion/indifit_motion.dart';
import '../../../core/services/indifit_haptics.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../today_consumer_presentation.dart';
import 'today_nutrition_widgets.dart';

/// Today motion (T3, Today review "Motion"): one moment at a time, where the
/// eye is.
///
/// [TodayDayContent] holds everything below the week strip. It
/// - runs the entrance once, on the first loaded content (never on the
///   loading placeholders, never again on another day);
/// - slides between days, keeping the last day on screen until the next one
///   has loaded;
/// - turns a change in the day's food into one [TodayLogMoment]: the meal row
///   that changed, the "+kcal" chip (at that row when it is on screen, else at
///   the ring when that is, else nowhere), the macros that reached their
///   target and whether calories went over. Haptics fire once per moment,
///   when Today is on screen.
///
/// Widgets below read it through [TodayMotion.maybeOf]; without one (a hero
/// on its own) they show their values as is.
abstract final class TodayMotionTiming {
  static const Duration ring = Duration(milliseconds: 700);
  static const Duration bar = Duration(milliseconds: 360);
  static const Duration barsStart = Duration(milliseconds: 240);
  static const Duration barStep = Duration(milliseconds: 60);
  static const Duration flameDelay = ring;
  static const Duration wash = Duration(milliseconds: 950);
  static const Duration macroHit = Duration(milliseconds: 900);

  /// The part of [macroHit] in which the bar end flashes.
  static const double macroFlashShare = 400 / 900;
}

/// Where the "+kcal" chip plays.
enum TodayChipPlace { ring, row }

@immutable
class TodayLogMoment {
  const TodayLogMoment({
    required this.serial,
    this.chipLabel,
    this.mealType,
    this.macros = const {},
    this.wentOver = false,
  });

  final int serial;

  /// "+230 kcal · Poha"; null when nothing was added (an edit, say).
  final String? chipLabel;

  /// The one meal row whose food changed, if exactly one did.
  final String? mealType;

  /// Nutrient ids that reached their target with this change, each at most
  /// once per day.
  final Set<String> macros;

  /// Calories crossed the target with this change.
  final bool wentOver;
}

class TodayMotion extends InheritedWidget {
  const TodayMotion({
    required this.entrance,
    required this.ringKey,
    required this.rowKey,
    required this.onChipDone,
    required super.child,
    super.key,
    this.moment,
    this.chipPlace,
    this.placeholderLayer = false,
  });

  /// True while the first loaded content mounts. Read it once, when a
  /// widget first builds; it is false for anything that mounts later.
  final bool entrance;

  /// Set once Today is on screen; until then nothing plays.
  final TodayLogMoment? moment;
  final TodayChipPlace? chipPlace;
  final GlobalKey ringKey;
  final GlobalKey Function(String mealType) rowKey;
  final VoidCallback onChipDone;

  /// The fading copy of the loading layout: only placeholders show in it.
  final bool placeholderLayer;

  static TodayMotion? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TodayMotion>();

  @override
  bool updateShouldNotify(TodayMotion oldWidget) =>
      moment != oldWidget.moment || chipPlace != oldWidget.chipPlace;
}

/// Wraps a Today module in the entrance stagger; it plays only on the first
/// loaded content. Mark modules that show a loading [placeholder]: only
/// they fade out over that content, so real cards never ghost.
class TodayEnter extends StatelessWidget {
  const TodayEnter({
    required this.index,
    required this.child,
    super.key,
    this.placeholder = false,
  });

  final int index;
  final Widget child;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final motion = TodayMotion.maybeOf(context);
    if (motion?.placeholderLayer ?? false) {
      // Same size as in the loading layout, so the placeholders fade out
      // exactly where they were.
      return Visibility(
        visible: placeholder,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: child,
      );
    }
    return IndiFitEnter(
      enabled:
          (motion?.entrance ?? false) && index < IndiFitMotion.staggerLimit,
      delay: IndiFitMotion.staggerStep * index,
      child: child,
    );
  }
}

class TodayDayContent extends StatefulWidget {
  const TodayDayContent({
    required this.date,
    required this.ready,
    required this.nutrition,
    required this.child,
    super.key,
  });

  final DateTime date;

  /// False while the day's first read is loading.
  final bool ready;
  final TodayNutritionPresentation nutrition;
  final Widget child;

  @override
  State<TodayDayContent> createState() => TodayDayContentState();
}

class TodayDayContentState extends State<TodayDayContent>
    with SingleTickerProviderStateMixin {
  // The placeholders fade out over the first loaded content, so launch never
  // shows an empty page between the two.
  late final AnimationController _fade;
  Widget? _fadingOut;
  late final _TodayDayKeys _fadeKeys = _TodayDayKeys(widget.date);

  // Entrance.
  var _entrancePending = true;
  var _generation = 0;

  // Day changes.
  Widget? _held;
  var _reverse = false;
  late _TodayDayKeys _keys = _TodayDayKeys(widget.date);

  // What the person last saw for the day.
  _TodaySeen? _seen;
  var _serial = 0;
  TodayLogMoment? _pending;
  TodayLogMoment? _moment;
  TodayChipPlace? _chipPlace;
  var _placing = false;
  final Set<String> _macrosHit = {};

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: B05MotionPolicy.standardDuration,
    )..addStatusListener(_fadeStatus);
    _remember();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePlacement();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _fadeStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _fadingOut = null);
    }
  }

  @override
  void didUpdateWidget(covariant TodayDayContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.ready &&
        widget.ready &&
        _held == null &&
        !B05MotionPolicy.reduceMotion(context) &&
        TickerMode.valuesOf(context).enabled) {
      _fadingOut = oldWidget.child;
      _fade.forward(from: 0);
    }
    if (!DateUtils.isSameDay(oldWidget.date, widget.date)) {
      _reverse = widget.date.isBefore(oldWidget.date);
      _keys = _TodayDayKeys(widget.date);
      _pending = null;
      _moment = null;
      _chipPlace = null;
    }
    final moment = _detect();
    if (moment != null) {
      _pending = moment;
      _schedulePlacement();
    }
    _remember();
  }

  TodayLogMoment? _detect() {
    final seen = _seen;
    final presentation = widget.nutrition;
    if (seen == null ||
        !widget.ready ||
        !DateUtils.isSameDay(seen.date, widget.date) ||
        !_TodaySeen.readable(presentation)) {
      return null;
    }
    final chip = todayLoggedChipLabel(
      previousDate: seen.date,
      previousIds: seen.ids,
      previousKcal: seen.kcal,
      date: widget.date,
      presentation: presentation,
    );
    String? mealType;
    if (chip != null) {
      final changed = [
        for (final meal in presentation.meals)
          if (seen.meals[meal.mealType] != (meal.itemCount, meal.kcal))
            meal.mealType,
      ];
      if (changed.length == 1) mealType = changed.single;
    }
    final dayKey = DateUtils.dateOnly(widget.date).toIso8601String();
    final macros = <String>{
      for (final metric in presentation.macros)
        if (metric.hasTarget &&
            metric.pointValue != null &&
            metric.pointValue! >= metric.targetValue! &&
            (seen.macros[metric.nutrientId] ?? 0) < metric.targetValue! &&
            !_macrosHit.contains('$dayKey:${metric.nutrientId}'))
          metric.nutrientId,
    };
    final calories = presentation.calories;
    final wentOver =
        calories != null &&
        calories.hasTarget &&
        !calories.isRange &&
        calories.pointValue != null &&
        seen.kcal != null &&
        seen.kcal! <= calories.targetValue! &&
        calories.pointValue! > calories.targetValue!;
    if (chip == null && macros.isEmpty && !wentOver) return null;
    _macrosHit.addAll({for (final id in macros) '$dayKey:$id'});
    return TodayLogMoment(
      serial: ++_serial,
      chipLabel: chip,
      mealType: mealType,
      macros: macros,
      wentOver: wentOver,
    );
  }

  void _remember() {
    if (!widget.ready || !_TodaySeen.readable(widget.nutrition)) return;
    _seen = _TodaySeen.of(widget.date, widget.nutrition);
  }

  // A moment starts only with Today on screen: a log made from the Food tab
  // or a pushed route plays when the person comes back.
  void _schedulePlacement() {
    if (_pending == null || _placing) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    _placing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _placing = false;
      if (!mounted) return;
      final moment = _pending;
      if (moment == null) return;
      if (!TickerMode.valuesOf(context).enabled) return;
      _pending = null;
      _place(moment);
    });
  }

  void _place(TodayLogMoment moment) {
    final reduceMotion = B05MotionPolicy.reduceMotion(context);
    TodayChipPlace? place;
    if (!reduceMotion && moment.chipLabel != null) {
      final row = moment.mealType;
      if (row != null && todayIsOnScreen(_keys.row(row).currentContext)) {
        place = TodayChipPlace.row;
      } else if (todayIsOnScreen(_keys.ring.currentContext)) {
        place = TodayChipPlace.ring;
      }
    }
    // One haptic per moment, the strongest that applies.
    if (moment.wentOver) {
      unawaited(IndiFitHaptics.warning());
    } else if (moment.macros.isNotEmpty) {
      unawaited(IndiFitHaptics.success());
    } else if (moment.chipLabel != null) {
      unawaited(IndiFitHaptics.light());
    }
    setState(() {
      _moment = moment;
      _chipPlace = place;
    });
  }

  void _chipDone() {
    if (mounted && _chipPlace != null) setState(() => _chipPlace = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ready) {
      // The last day stays until the next one has loaded, so a day change
      // slides between two loaded days instead of through placeholders.
      final held = _held;
      if (held != null) return _loaded(held);
      return TodayMotion(
        entrance: false,
        ringKey: _keys.ring,
        rowKey: _keys.row,
        onChipDone: _chipDone,
        child: widget.child,
      );
    }
    if (_held == null) _generation++;
    final entrance = _entrancePending;
    if (entrance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _entrancePending = false;
      });
    }
    final child = KeyedSubtree(
      // One key per visit, so going back to a day mid-slide never repeats one.
      key: ObjectKey(_keys),
      child: TodayMotion(
        entrance: entrance,
        ringKey: _keys.ring,
        rowKey: _keys.row,
        moment: _moment,
        chipPlace: _chipPlace,
        onChipDone: _chipDone,
        child: widget.child,
      ),
    );
    _held = child;
    return _loaded(child);
  }

  // One structure from the first loaded build on, with or without the
  // fading placeholders, so the day content never remounts.
  Widget _loaded(Widget child) {
    final fadingOut = _fadingOut;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _switcher(child),
        if (fadingOut != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: FadeTransition(
                  opacity: ReverseAnimation(
                    CurvedAnimation(
                      parent: _fade,
                      curve: B05MotionPolicy.standardCurve,
                    ),
                  ),
                  child: TodayMotion(
                    entrance: false,
                    // Its own keys: the loaded day owns the real ones.
                    ringKey: _fadeKeys.ring,
                    rowKey: _fadeKeys.row,
                    onChipDone: () {},
                    placeholderLayer: true,
                    child: fadingOut,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // A new generation (after placeholders) shows its first day without a
  // slide; the switcher animates only from one loaded day to another.
  Widget _switcher(Widget child) => KeyedSubtree(
    key: ValueKey<int>(_generation),
    child: IndiFitSharedAxisSwitcher(reverse: _reverse, child: child),
  );
}

class _TodayDayKeys {
  _TodayDayKeys(this.date);

  final DateTime date;
  final GlobalKey ring = GlobalKey(debugLabel: 'today-ring');
  final Map<String, GlobalKey> _rows = {};

  GlobalKey row(String mealType) => _rows.putIfAbsent(
    mealType,
    () => GlobalKey(debugLabel: 'today-meal-$mealType'),
  );
}

class _TodaySeen {
  _TodaySeen({
    required this.date,
    required this.ids,
    required this.kcal,
    required this.meals,
    required this.macros,
  });

  factory _TodaySeen.of(
    DateTime date,
    TodayNutritionPresentation p,
  ) => _TodaySeen(
    date: date,
    ids: {for (final record in p.loggedRecords) record.$1},
    kcal: p.calories?.pointValue,
    meals: {
      for (final meal in p.meals) meal.mealType: (meal.itemCount, meal.kcal),
    },
    macros: {
      for (final metric in p.macros)
        if (metric.pointValue != null) metric.nutrientId: metric.pointValue!,
    },
  );

  static bool readable(TodayNutritionPresentation p) =>
      p.state != TodayPresentationState.loading &&
      p.state != TodayPresentationState.unavailable;

  final DateTime date;
  final Set<String> ids;
  final double? kcal;
  final Map<String, (int, double?)> meals;
  final Map<String, double> macros;
}

/// Whether at least half of [context]'s box is inside its scroll view (and
/// below the status bar).
bool todayIsOnScreen(BuildContext? context) {
  if (context == null || !context.mounted) return false;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return false;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  final media = MediaQuery.maybeOf(context);
  var viewport = Offset.zero & (media?.size ?? rect.size);
  final scrollable = Scrollable.maybeOf(context);
  final scrollBox = scrollable?.context.findRenderObject();
  if (scrollBox is RenderBox && scrollBox.hasSize) {
    viewport = scrollBox.localToGlobal(Offset.zero) & scrollBox.size;
  }
  final top = media?.padding.top ?? 0;
  if (viewport.top < top) {
    viewport = Rect.fromLTRB(
      viewport.left,
      top,
      viewport.right,
      viewport.bottom,
    );
  }
  final visible = rect.intersect(viewport);
  if (visible.isEmpty || visible.height <= 0) return false;
  return visible.height >= rect.height / 2;
}
