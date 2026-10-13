import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/motion/indifit_motion.dart';
import '../../../core/presentation/consumer_copy.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/theme/indifit_icons.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../today_consumer_presentation.dart';
import '../today_presentation_types.dart';
import '../today_surface_controller.dart';
import 'today_helpers.dart';
import 'today_module_widgets.dart';
import 'today_motion.dart';

/// Today nutrition widgets (PV1-ENG-05B first pass).
///
/// Extracted verbatim from `today_daily_action_surface.dart`; unchanged.

/// The Today nutrition card. A log that lands while it is on screen shows
/// what was added ("+230 kcal · Poha", V3) above the ring, while the ring and
/// numbers count up from the old values; [TodayDayContent] decides whether
/// the chip plays here, at the meal row, or not at all (T3).
class TodayNutritionHero extends StatelessWidget {
  const TodayNutritionHero({
    required this.presentation,
    required this.onLogFood,
    required this.onOpenFoodGuidance,
    required this.dateRelation,
    required this.selectedDate,
    required this.onOpenTargetSetup,
    required this.onRetry,
    super.key,
  });

  final TodayNutritionPresentation presentation;
  final VoidCallback onLogFood;
  final VoidCallback? onOpenFoodGuidance;
  final TodayDateRelation dateRelation;
  final DateTime selectedDate;
  final VoidCallback onOpenTargetSetup;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final motion = TodayMotion.maybeOf(context);
    final moment = motion?.moment;
    final label = moment?.chipLabel;
    return _TodayNutritionHeroBody(
      presentation: presentation,
      onLogFood: onLogFood,
      onOpenFoodGuidance: onOpenFoodGuidance,
      dateRelation: dateRelation,
      selectedDate: selectedDate,
      onOpenTargetSetup: onOpenTargetSetup,
      onRetry: onRetry,
      ringKey: motion?.ringKey,
      ringOverlay: label == null || motion?.chipPlace != TodayChipPlace.ring
          ? null
          : TodayLoggedChip(
              key: ValueKey<int>(moment!.serial),
              label: label,
              onDone: motion!.onChipDone,
            ),
    );
  }
}

/// "+230 kcal · Poha" when the only change since [previousIds] is new records
/// on the same day and the calorie total went up; several new records read
/// "+640 kcal · 4 foods". Null otherwise (first view, another day, edits,
/// deletes, unknown totals), so the chip never claims more than it knows.
String? todayLoggedChipLabel({
  required DateTime? previousDate,
  required Set<String>? previousIds,
  required double? previousKcal,
  required DateTime date,
  required TodayNutritionPresentation presentation,
}) {
  if (previousDate == null ||
      previousIds == null ||
      previousKcal == null ||
      !DateUtils.isSameDay(previousDate, date)) {
    return null;
  }
  if (presentation.state == TodayPresentationState.loading ||
      presentation.state == TodayPresentationState.unavailable) {
    return null;
  }
  final kcal = presentation.calories?.pointValue;
  if (kcal == null || presentation.calories?.isAvailable != true) return null;
  final ids = {for (final record in presentation.loggedRecords) record.$1};
  if (!ids.containsAll(previousIds)) return null;
  final added = [
    for (final record in presentation.loggedRecords)
      if (!previousIds.contains(record.$1)) record,
  ];
  final delta = kcal - previousKcal;
  if (added.isEmpty || delta.round() <= 0) return null;
  // Older quick adds were named "Quick Add (260 kcal)", which repeats the
  // amount already in the chip.
  final what = added.length == 1
      ? added.single.$2
            .replaceFirst(RegExp(r'\s*\(\s*[\d,.]+\s*kcal\s*\)\s*$'), '')
            .replaceFirst(RegExp('^Quick Add\$'), 'Quick add')
            .trim()
      : '${added.length} foods';
  final amount = '+${formatTodayMetric(delta)} kcal';
  return what.isEmpty ? amount : '$amount · $what';
}

/// Floats up above the ring once, holds, then fades and calls [onDone].
class TodayLoggedChip extends StatefulWidget {
  const TodayLoggedChip({required this.label, required this.onDone, super.key});

  static const Duration duration = Duration(milliseconds: 1600);

  final String label;
  final VoidCallback onDone;

  @override
  State<TodayLoggedChip> createState() => _TodayLoggedChipState();
}

class _TodayLoggedChipState extends State<TodayLoggedChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TodayLoggedChip.duration,
  );
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: B05MotionPolicy.standardCurve)),
      weight: 15,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
  ]).animate(_controller);
  late final Animation<Offset> _rise =
      Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.25, curve: Curves.easeOutCubic),
        ),
      );

  var _started = false;

  // Starts only once Today is on screen: a log made from the Food tab or a
  // pushed route plays when the person comes back, not while they are away.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !TickerMode.valuesOf(context).enabled) return;
    _started = true;
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Semantics(
      liveRegion: true,
      label: 'Added ${widget.label.replaceFirst('+', '')}',
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: SlideTransition(
            position: _rise,
            child: FadeTransition(
              opacity: _opacity,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.success.container,
                  shape: const StadiumBorder(),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: B05Layout.space12,
                    vertical: B05Layout.space4,
                  ),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: B05Typography.label(context).copyWith(
                      color: colors.success.foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayNutritionHeroBody extends StatelessWidget {
  const _TodayNutritionHeroBody({
    required this.presentation,
    required this.onLogFood,
    required this.onOpenFoodGuidance,
    required this.dateRelation,
    required this.selectedDate,
    required this.onOpenTargetSetup,
    required this.onRetry,
    this.ringKey,
    this.ringOverlay,
  });

  final TodayNutritionPresentation presentation;
  final VoidCallback onLogFood;
  final VoidCallback? onOpenFoodGuidance;
  final TodayDateRelation dateRelation;
  final DateTime selectedDate;
  final VoidCallback onOpenTargetSetup;
  final VoidCallback onRetry;
  final GlobalKey? ringKey;
  final Widget? ringOverlay;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const TodayModuleSkeleton(label: 'Preparing nutrition');
    }
    if (presentation.state == TodayPresentationState.unavailable) {
      return TodayUnavailableModule(
        title: 'Nutrition unavailable',
        detail: 'Try again to load your meals and nutrition.',
        onRetry: onRetry,
      );
    }
    if (!presentation.hasAcceptedCalorieTarget &&
        presentation.isNoConsumptionKnown) {
      return TodaySparseNutritionModule(
        presentation: presentation,
        onLogFood: onLogFood,
        onOpenTargetSetup: onOpenTargetSetup,
        dateRelation: dateRelation,
        selectedDate: selectedDate,
        onOpenFoodGuidance: onOpenFoodGuidance,
      );
    }
    final calorieRing = CalorieRing(
      calories: presentation.calories,
      hasTarget: presentation.hasAcceptedCalorieTarget,
      incomplete: presentation.hasIncompleteNutrition,
      noConsumption: presentation.isNoConsumptionKnown,
      onTap: onOpenTargetSetup,
    );
    final overlay = ringOverlay;
    // One structure with or without the chip, so the ring keeps its
    // count-up state when the chip comes and goes.
    final ring = Stack(
      key: ringKey,
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        calorieRing,
        // Above the arc's start, a little wider than the ring; long names
        // ellipsize.
        Positioned(
          top: -B05Layout.space20,
          left: -B05Layout.space32,
          right: -B05Layout.space32,
          child: Center(child: overlay ?? const SizedBox.shrink()),
        ),
      ],
    );
    // T2: the ring leads, centred, with the macro tiles under it. No title:
    // the ring and tiles say what the card is, and the hero drops from
    // 448 to about 330 pt on a 6.1" phone.
    return Semantics(
      container: true,
      label: 'Nutrition. ${presentation.headline}',
      child: B05Surface(
        tone: B05SurfaceTone.raised,
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          B05Layout.space16,
          B05Layout.space16,
          B05Layout.space12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: ring),
            const SizedBox(height: B05Layout.space12),
            MacroComparison(
              metrics: presentation.macros,
              showPartialNote: presentation.hasIncompleteNutrition,
            ),
            const SizedBox(height: B05Layout.space12),
            Wrap(
              spacing: B05Layout.space8,
              runSpacing: B05Layout.space8,
              children: [
                B05ActionButton(
                  label: ConsumerCopy.logFoodAction,
                  icon: Icons.add_rounded,
                  hint: 'Search foods and log them for this day.',
                  onPressed: onLogFood,
                ),
                TodayMealIdeasAction(
                  dateRelation: dateRelation,
                  selectedDate: selectedDate,
                  onOpenFoodGuidance: onOpenFoodGuidance,
                ),
                // The ring opens targets too, so this is a short link.
                B05ActionButton(
                  label: 'Targets',
                  emphasis: B05ActionEmphasis.tertiary,
                  hint: 'Opens Goal & targets for this date.',
                  onPressed: onOpenTargetSetup,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TodaySparseNutritionModule extends StatelessWidget {
  const TodaySparseNutritionModule({
    super.key,
    required this.presentation,
    required this.onLogFood,
    required this.onOpenTargetSetup,
    required this.dateRelation,
    required this.selectedDate,
    required this.onOpenFoodGuidance,
  });

  final TodayNutritionPresentation presentation;
  final VoidCallback onLogFood;
  final VoidCallback onOpenTargetSetup;
  final TodayDateRelation dateRelation;
  final DateTime selectedDate;
  final VoidCallback? onOpenFoodGuidance;

  @override
  Widget build(BuildContext context) {
    final noFood = presentation.isNoConsumptionKnown;
    final calories = presentation.calories;
    final loggedCalories = calories?.isAvailable == true
        ? '${calories!.value} ${calories.unit} logged'
        : 'Food logged';
    final loggedMacros = presentation.macros
        .where((metric) => metric.isAvailable)
        .map((metric) => '${metric.label} ${metric.value} ${metric.unit}')
        .toList(growable: false);
    final targetContext = presentation.targetUnavailable
        ? 'Target unavailable for this date'
        : 'No daily target for this date';
    final detail = noFood ? 'Nothing logged for this day' : loggedCalories;

    return Semantics(
      container: true,
      label: noFood
          ? 'Nutrition. Nothing logged for this day.'
          : 'Nutrition. $loggedCalories. $targetContext.',
      child: B05Surface(
        key: const ValueKey('today-sparse-nutrition'),
        padding: const EdgeInsets.all(B05Layout.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrition', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space4),
            Text(detail, style: B05Typography.body(context)),
            if (!noFood && loggedMacros.isNotEmpty) ...[
              const SizedBox(height: B05Layout.space8),
              Text(
                loggedMacros.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: B05Typography.caption(context),
              ),
            ],
            if (!noFood && presentation.hasIncompleteNutrition) ...[
              const SizedBox(height: B05Layout.space8),
              Text(
                ConsumerCopy.nutritionDetailsIncomplete,
                style: B05Typography.caption(context),
              ),
            ],
            if (!noFood || presentation.targetUnavailable) ...[
              const SizedBox(height: B05Layout.space8),
              Text(targetContext, style: B05Typography.caption(context)),
            ],
            const SizedBox(height: B05Layout.space12),
            B05ActionGroup(
              children: [
                B05ActionButton(
                  label: 'Log food',
                  icon: Icons.add_rounded,
                  hint: 'Search foods and log them for this day.',
                  onPressed: onLogFood,
                ),
                TodayMealIdeasAction(
                  dateRelation: dateRelation,
                  selectedDate: selectedDate,
                  onOpenFoodGuidance: onOpenFoodGuidance,
                ),
                B05ActionButton(
                  label: 'View targets',
                  emphasis: B05ActionEmphasis.tertiary,
                  hint: 'Open Goal & targets for this date.',
                  onPressed: onOpenTargetSetup,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TodayMealIdeasAction extends ConsumerStatefulWidget {
  const TodayMealIdeasAction({
    super.key,
    required this.dateRelation,
    required this.selectedDate,
    required this.onOpenFoodGuidance,
  });

  final TodayDateRelation dateRelation;
  final DateTime selectedDate;
  final VoidCallback? onOpenFoodGuidance;

  @override
  ConsumerState<TodayMealIdeasAction> createState() =>
      TodayMealIdeasActionState();
}

class TodayMealIdeasActionState extends ConsumerState<TodayMealIdeasAction> {
  Object? _loadedContext;

  @override
  Widget build(BuildContext context) {
    if (widget.dateRelation != TodayDateRelation.today ||
        widget.onOpenFoodGuidance == null) {
      return const SizedBox.shrink();
    }

    final contextAsync = ref.watch(b04ProductionRecommendationContextProvider);
    final currentFoodContext = contextAsync.isLoading || contextAsync.hasError
        ? null
        : contextAsync.valueOrNull;
    // Subscribe before scheduling the first load. Otherwise the short-circuit
    // below can skip the watch while [needsLoad] is true, leaving this action
    // unaware when the controller transitions from loading to ready.
    final currentFoodState = ref.watch(b04CurrentFoodControllerProvider);
    final expectedLocalDate = todaySurfaceDateKey(widget.selectedDate);
    final contextMatchesDate =
        currentFoodContext != null &&
        currentFoodContext.window.startLocalDate == expectedLocalDate;
    final needsLoad =
        contextMatchesDate && !identical(_loadedContext, currentFoodContext);
    if (needsLoad) {
      _loadedContext = currentFoodContext;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(b04CurrentFoodControllerProvider.notifier)
              .loadProduction(context: currentFoodContext),
        );
      });
    }

    final available =
        contextMatchesDate &&
        !needsLoad &&
        todayMealIdeasAreAvailable(
          dateRelation: widget.dateRelation,
          state: currentFoodState,
          expectedLocalDate: expectedLocalDate,
        );
    if (!available) return const SizedBox.shrink();

    return B05ActionButton(
      label: 'What can I eat?',
      icon: Icons.lightbulb_outline_rounded,
      hint: 'Shows a concise meal suggestion when one is ready.',
      emphasis: B05ActionEmphasis.secondary,
      onPressed: widget.onOpenFoodGuidance!,
    );
  }
}

B05Macro? _todayMacro(String nutrientId) => switch (nutrientId) {
  'protein' => B05Macro.protein,
  'carbohydrate' => B05Macro.carbs,
  'fat' => B05Macro.fat,
  'fibre' => B05Macro.fibre,
  _ => null,
};

/// Macro hues from the shared map. Red is reserved for "over target", so no
/// macro uses it as its base colour.
B05ColorRole todayMacroColorRole(B05SemanticColors colors, String nutrientId) {
  final macro = _todayMacro(nutrientId);
  return macro == null ? colors.unavailable : colors.macro(macro);
}

/// The calorie ring (T2): eaten against the target in a recessed well, with
/// the number at 42 pt. Over the target the green lap stays full and the
/// extra draws as a coral second lap; only the "N over" text is red.
/// Tapping it opens Goal & targets when [onTap] is set.
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.calories,
    required this.hasTarget,
    required this.incomplete,
    required this.noConsumption,
    this.onTap,
  });

  final TodayNutritionMetricPresentation? calories;
  final bool hasTarget;
  final bool incomplete;
  final bool noConsumption;
  final VoidCallback? onTap;

  static const double diameter = 176;
  static const double largeTextDiameter = 196;

  @override
  Widget build(BuildContext context) {
    final metric = calories;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final diameter = largeText
        ? CalorieRing.largeTextDiameter
        : CalorieRing.diameter;
    if (metric == null) {
      return Semantics(
        label: 'Calories are unavailable.',
        child: SizedBox(width: diameter, height: diameter),
      );
    }
    final colors = context.b05Colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final high = hasTarget
        ? metric.upperProgress ?? metric.progress ?? 0.0
        : 0.0;
    final low = hasTarget ? metric.lowerProgress ?? high : 0.0;
    final target = metric.targetValue;
    final point = metric.pointValue;
    // One clock for the arc, the number and the status (T3): the sweep runs
    // to 100 % in green, past 12 o'clock into the coral lap, and "N over"
    // fades in as it crosses the top, not on the first frame.
    final pointTarget = hasTarget && !metric.isRange && point != null;
    (double, double, double) arcAt(double kcal) {
      if (!hasTarget) return (0, 0, 0);
      if (pointTarget) {
        final ratio = kcal / target!;
        final green = ratio.clamp(0.0, 1.0);
        return (green, green, (ratio - 1).clamp(0.0, 1.0));
      }
      final share = point == null || point <= 0
          ? 1.0
          : (kcal / point).clamp(0.0, 1.0);
      return (low * share, high * share, 0);
    }

    // Track plus the gap to the number; the label column stays inside it.
    final inset = CalorieRingPainter.stroke + B05Layout.space12;
    final targetText = metric.hasTarget
        ? 'of ${formatTodayMetric(metric.targetValue!)} kcal'
        : metric.isAvailable
        ? 'kcal logged'
        : 'Nutrition incomplete';
    String statusAt(double kcal) => !metric.isAvailable
        ? '—'
        : metric.isRange
        ? '${metric.value} kcal range'
        : metric.hasTarget
        ? kcal > metric.targetValue!
              ? '${formatTodayMetric(kcal - metric.targetValue!)} over'
              : '${formatTodayMetric(metric.targetValue! - kcal)} left'
        : noConsumption
        ? 'No meals yet'
        : 'No target set';
    final status = statusAt(point ?? 0);
    final semantics = metric.isAvailable
        ? metric.hasTarget
              ? 'Calories ${metric.value} of ${formatTodayMetric(metric.targetValue!)} kilocalories. $status.'
              : 'Calories ${metric.value} kilocalories logged. No target set.'
        : 'Calories are incomplete. No total is shown.';
    final tabular = const [FontFeature.tabularFigures()];
    // Launch: the ring sweeps from 0 with the count-up, once.
    final entrance = TodayMotion.maybeOf(context)?.entrance ?? false;

    final ring = IndiFitCountUp(
      value: point ?? 0,
      begin: entrance ? 0 : null,
      duration: TodayMotionTiming.ring,
      builder: (context, kcal) {
        final (lowValue, green, overflow) = arcAt(kcal);
        final over = pointTarget && kcal > target!;
        final statusColor = over
            ? colors.danger.indicator
            : incomplete && !metric.isAvailable
            ? colors.unavailable.indicator
            : colors.textSecondary;
        return SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Calories eaten against the target, never a macro pie: a
              // full circle of macro shares read as "done" at 40 % of the
              // day's calories (audit UX-03). Macros are the tiles.
              Positioned.fill(
                child: CustomPaint(
                  key: const Key('today_calorie_ring'),
                  painter: CalorieRingPainter(
                    progressLow: lowValue,
                    progressHigh: green,
                    overflow: overflow,
                    color: colors.success.indicator,
                    endColor: colors.protein.indicator,
                    overflowColor: colors.overflow,
                    trackColor: colors.borderSubtle,
                    range: metric.isRange,
                    dark: dark,
                  ),
                ),
              ),
              SizedBox(
                width: diameter - inset * 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        metric.valueAt(kcal),
                        maxLines: 1,
                        style: B05Typography.metric(context).copyWith(
                          fontSize: 42,
                          height: 1,
                          letterSpacing: -1.5,
                          fontFeatures: tabular,
                        ),
                      ),
                    ),
                    const SizedBox(height: B05Layout.space4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        targetText,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: B05Typography.caption(
                          context,
                        ).copyWith(fontFeatures: tabular),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: B05MotionPolicy.transitionDuration(
                        context,
                        standard: B05MotionPolicy.fastDuration,
                      ),
                      child: FittedBox(
                        key: ValueKey<bool>(over),
                        fit: BoxFit.scaleDown,
                        child: Text(
                          statusAt(kcal),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: B05Typography.caption(context).copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontFeatures: tabular,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    final tap = onTap;
    return Semantics(
      label: semantics,
      button: tap != null,
      hint: tap == null ? null : 'Opens Goal & targets for this date.',
      onTap: tap,
      child: ExcludeSemantics(
        child: tap == null
            ? ring
            // No clip on the Material: it would cut the arc's glow. The
            // splash keeps to the circle through customBorder.
            : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: const Key('today_calorie_ring_tap'),
                  customBorder: const CircleBorder(),
                  onTap: tap,
                  child: ring,
                ),
              ),
      ),
    );
  }
}

/// The calorie ring (T2 depth on the V3 arc): a recessed well, a soft track
/// edge, a green-to-teal arc with a glow and a gloss line, and a shadow under
/// the arc tip. [overflow] (0–1) is the coral second lap past the target; it
/// starts at 12 o'clock and casts its shadow onto the full green lap.
class CalorieRingPainter extends CustomPainter {
  const CalorieRingPainter({
    required this.progressLow,
    required this.progressHigh,
    required this.color,
    required this.trackColor,
    required this.range,
    this.endColor,
    this.overflow = 0,
    this.overflowColor = const Color(0xFFFF8A65),
    this.dark = true,
  });

  static const double stroke = 14;
  static const double glowSigma = 6;
  static const double glowAlpha = 0.3;

  final double progressLow;
  final double progressHigh;
  final double overflow;
  final Color color;
  final Color? endColor;
  final Color overflowColor;
  final Color trackColor;
  final bool range;
  final bool dark;

  static const double _start = -math.pi / 2;
  static const double _full = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Leave room for the glow so it is not clipped at the edge.
    final radius = size.shortestSide / 2 - stroke / 2 - glowSigma / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // The well: lit a little above centre, darker towards the track.
    final wellRadius = radius - stroke / 2 - 1;
    canvas.drawCircle(
      center,
      wellRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.16),
          radius: 0.58,
          colors: dark
              ? const [Color(0x09FFFFFF), Color(0x47000000)]
              : const [Color(0x000F172A), Color(0x0D0F172A)],
        ).createShader(Rect.fromCircle(center: center, radius: wellRadius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    // A soft edge on the outside of the track.
    canvas.drawCircle(
      center,
      radius + stroke / 2 - .5,
      Paint()
        ..color = dark ? const Color(0x0FFFFFFF) : const Color(0x140F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final high = progressHigh.clamp(0.0, 1.0);
    if (high <= 0) return;
    final sweep = _full * high;
    Paint arcPaint({double alpha = 1, bool blurred = false}) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      final end = endColor;
      if (end == null) {
        paint.color = color.withValues(alpha: color.a * alpha);
      } else {
        // The gradient spans the drawn arc, so a short arc still shows both
        // colours. Alphas are baked in so the glow and range parts fade.
        paint.shader = SweepGradient(
          startAngle: 0,
          endAngle: sweep,
          colors: [
            color.withValues(alpha: color.a * alpha),
            end.withValues(alpha: end.a * alpha),
          ],
          transform: const GradientRotation(_start),
        ).createShader(rect);
      }
      if (blurred) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, glowSigma);
      }
      return paint;
    }

    final shadow = dark ? const Color(0x8C000000) : const Color(0x400F172A);
    canvas.drawArc(
      rect,
      _start,
      sweep,
      false,
      arcPaint(alpha: glowAlpha, blurred: true),
    );
    if (overflow <= 0) _tipShadow(canvas, center, radius, high, shadow);
    final low = progressLow.clamp(0.0, high);
    if (low > 0) {
      canvas.drawArc(
        rect,
        _start,
        _full * low,
        false,
        arcPaint(alpha: range ? .48 : 1),
      );
    }
    final remaining = high - low;
    if (remaining > 0) {
      canvas.drawArc(
        rect,
        _start + _full * low,
        _full * remaining,
        false,
        arcPaint(),
      );
    }
    // Gloss: a thin light line along the outer part of the arc.
    final glossSweep = sweep - _full * .01;
    if (glossSweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + stroke / 2 - 3),
        _start,
        glossSweep,
        false,
        Paint()
          ..color = const Color(0x61FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
    }

    final extra = overflow.clamp(0.0, 1.0);
    if (extra <= 0) return;
    // The coral lap sits on top of the green one: its shadow falls on the
    // green, and the tip shadow shows where it ends.
    canvas.save();
    canvas.translate(0, 1.5);
    canvas.drawArc(
      rect,
      _start,
      _full * extra,
      false,
      Paint()
        ..color = shadow
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    canvas.restore();
    canvas.drawArc(
      rect,
      _start,
      _full * extra,
      false,
      Paint()
        ..color = overflowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  /// A soft shadow under the round end of the arc, so the tip reads as
  /// lying on the track rather than printed on it.
  void _tipShadow(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
    Color shadow,
  ) {
    final angle = _start + _full * progress;
    final tip = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(
      tip + const Offset(0, 1.5),
      stroke / 2,
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
  }

  @override
  bool shouldRepaint(covariant CalorieRingPainter oldDelegate) =>
      oldDelegate.progressLow != progressLow ||
      oldDelegate.progressHigh != progressHigh ||
      oldDelegate.overflow != overflow ||
      oldDelegate.color != color ||
      oldDelegate.endColor != endColor ||
      oldDelegate.overflowColor != overflowColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.range != range ||
      oldDelegate.dark != dark;
}

/// Macro tiles as in the onboarding reveal (T2), one per macro with a
/// target or a logged value. Fibre has no target authority, so it is one
/// quiet line under the tiles instead of a tile with no bar.
class MacroComparison extends StatelessWidget {
  const MacroComparison({
    super.key,
    required this.metrics,
    this.showPartialNote = false,
  });

  final List<TodayNutritionMetricPresentation> metrics;

  /// Some logged food lists no macros (a quick add, say).
  final bool showPartialNote;

  static bool _quiet(TodayNutritionMetricPresentation metric) =>
      metric.nutrientId == 'fibre' && !metric.hasTarget;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final metric in metrics)
        if (!_quiet(metric)) metric,
    ];
    final quiet = metrics.where(_quiet).toList(growable: false);
    // At large text three tiles can't hold "120 / 150 g", so they stack.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final anyTarget = metrics.any((metric) => metric.hasTarget);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tiles.isNotEmpty)
          stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < tiles.length; index++) ...[
                      if (index > 0) const SizedBox(height: B05Layout.space8),
                      MacroTile(metric: tiles[index], order: index),
                    ],
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < tiles.length; index++) ...[
                        if (index > 0) const SizedBox(width: B05Layout.space8),
                        Expanded(
                          child: MacroTile(
                            metric: tiles[index],
                            fill: true,
                            order: index,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        for (final metric in quiet)
          _QuietMacroLine(metric: metric, noTargetNote: anyTarget),
        // One line instead of an "i" on the header and every tile.
        if (showPartialNote ||
            metrics.any((metric) => metric.isIncomplete)) ...[
          const SizedBox(height: B05Layout.space8),
          Text(
            key: const ValueKey('macros_partial_note'),
            'Partial: some foods list no macros',
            style: B05Typography.caption(context),
          ),
        ],
      ],
    );
  }
}

/// "Fiber · 21 g · no target" as one caption line.
class _QuietMacroLine extends StatelessWidget {
  const _QuietMacroLine({required this.metric, required this.noTargetNote});

  final TodayNutritionMetricPresentation metric;

  /// Only when other macros have targets; with no targets at all it would
  /// repeat on every line what the ring already says.
  final bool noTargetNote;

  @override
  Widget build(BuildContext context) {
    final style = B05Typography.caption(
      context,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final suffix = noTargetNote ? ' · no target' : '';
    return Semantics(
      label:
          '${metric.label}: ${metric.comparisonLabel}'
          '${metric.estimated ? ', estimated' : ''}'
          '${noTargetNote ? ', no target' : ''}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, B05Layout.space8, 2, 0),
          child: Row(
            children: [
              Text(metric.label, style: style),
              const SizedBox(width: B05Layout.space8),
              Expanded(
                child: metric.isAvailable
                    ? IndiFitCountUp(
                        value: metric.pointValue ?? 0,
                        builder: (context, point) => Text(
                          '${metric.valueLabelAt(point)}$suffix',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: style,
                        ),
                      )
                    : Text('—', textAlign: TextAlign.end, style: style),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One macro: icon and name, "120 / 150 g" with the target small, and a
/// 4 pt bar. Tinted with the macro's own hue; over its target the value
/// and bar turn coral, as the calorie overflow lap does. Red stays on the
/// ring's "N over" text. On launch the bars fill one after another; when a
/// log brings the macro to its target the bar end flashes and a check pops,
/// once per macro per day (T3).
class MacroTile extends StatelessWidget {
  const MacroTile({
    super.key,
    required this.metric,
    this.fill = false,
    this.order = 0,
  });

  final TodayNutritionMetricPresentation metric;

  /// In a row of tiles of equal height: push the bar to the bottom.
  final bool fill;

  /// Position among the tiles, for the launch fill.
  final int order;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final role = todayMacroColorRole(colors, metric.nutrientId);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final motion = TodayMotion.maybeOf(context);
    final entrance = motion?.entrance ?? false;
    final moment = motion?.moment;
    final hitSerial =
        moment != null && moment.macros.contains(metric.nutrientId)
        ? moment.serial
        : null;
    final icon = switch (_todayMacro(metric.nutrientId)) {
      B05Macro.protein => IndiFitIcons.protein,
      B05Macro.carbs => IndiFitIcons.carbs,
      B05Macro.fat => IndiFitIcons.fat,
      B05Macro.fibre => IndiFitIcons.fibre,
      null => Icons.circle_outlined,
    };
    final label =
        '${metric.label}: ${metric.comparisonLabel}'
        '${metric.estimated ? ', estimated' : ''}'
        '${metric.isIncomplete ? ', incomplete' : ''}';
    final delay =
        TodayMotionTiming.barsStart + TodayMotionTiming.barStep * order;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: _MacroHit(
          serial: hitSerial,
          builder: (context, hit) => DecoratedBox(
            decoration: ShapeDecoration(
              color: role.indicator.withValues(alpha: dark ? .10 : .08),
              shape: B05Radii.shape(B05Radii.rowRadius),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IndiFitIcon(icon, size: 14, color: role.indicator),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              metric.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: B05Typography.caption(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: B05Layout.space4),
                      _value(context, entrance: entrance, delay: delay),
                      if (metric.estimated && !metric.isIncomplete)
                        Text(
                          'Estimated',
                          style: B05Typography.caption(context),
                        ),
                      if (metric.hasTarget && metric.progress != null) ...[
                        if (fill) const Spacer(),
                        const SizedBox(height: 6),
                        MacroProgress(
                          metric: metric,
                          color: role.indicator,
                          entranceDelay: entrance ? delay : null,
                          flash: hit,
                        ),
                      ],
                    ],
                  ),
                ),
                if (hit != null)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: _MacroHitCheck(progress: hit, color: role.indicator),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Unknown values read as a quiet "—"; the hero's single partial note
  /// gives the reason, and the tile's semantics label says "Not available".
  Widget _value(
    BuildContext context, {
    required bool entrance,
    required Duration delay,
  }) {
    final colors = context.b05Colors;
    final big = B05Typography.number(context, size: 17).copyWith(
      height: 1.2,
      letterSpacing: -0.2,
      color: metric.isOverTarget ? colors.overflowText : colors.textPrimary,
    );
    if (!metric.isAvailable) {
      return Text('—', style: big.copyWith(color: colors.textSecondary));
    }
    final small = B05Typography.caption(context).copyWith(
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return IndiFitCountUp(
      value: metric.pointValue ?? 0,
      begin: entrance ? 0 : null,
      delay: delay,
      duration: TodayMotionTiming.bar,
      builder: (context, point) {
        // "120 / 150 g" → "120" large, " / 150 g" small.
        final text = metric.valueLabelAt(point);
        final split = text.indexOf(' ');
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: split < 0 ? text : text.substring(0, split),
                  style: big,
                ),
                if (split >= 0)
                  TextSpan(text: text.substring(split), style: small),
              ],
            ),
            maxLines: 1,
          ),
        );
      },
    );
  }
}

/// Plays [TodayMotionTiming.macroHit] once for each new [serial] while it
/// is on screen; [builder] gets its progress (0–1), or null when idle.
class _MacroHit extends StatefulWidget {
  const _MacroHit({required this.serial, required this.builder});

  final int? serial;
  final Widget Function(BuildContext context, double? progress) builder;

  @override
  State<_MacroHit> createState() => _MacroHitState();
}

class _MacroHitState extends State<_MacroHit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TodayMotionTiming.macroHit,
  );
  int? _played;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePlay();
  }

  @override
  void didUpdateWidget(covariant _MacroHit oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePlay();
  }

  void _maybePlay() {
    final serial = widget.serial;
    if (serial == null || serial == _played) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    _played = serial;
    if (B05MotionPolicy.reduceMotion(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(
      context,
      _controller.isAnimating ? _controller.value : null,
    ),
  );
}

/// The small check that pops in at the tile corner and fades out.
class _MacroHitCheck extends StatelessWidget {
  const _MacroHitCheck({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pop = IndiFitMotion.springCurve(
      IndiFitMotion.popDuration,
    ).transform((progress * 900 / 220).clamp(0.0, 1.0));
    final fade = 1 - ((progress - .75) / .25).clamp(0.0, 1.0);
    return Opacity(
      opacity: fade,
      child: Transform.scale(
        scale: pop,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.check_rounded,
              size: 12,
              color: context.b05Colors.page,
            ),
          ),
        ),
      ),
    );
  }
}

class MacroProgress extends StatelessWidget {
  const MacroProgress({
    super.key,
    required this.metric,
    required this.color,
    this.entranceDelay,
    this.flash,
  });

  final TodayNutritionMetricPresentation metric;
  final Color color;

  /// Fills from empty after this delay (launch); null shows the bar as is.
  final Duration? entranceDelay;

  /// Progress of a target-hit flash at the bar end (0–1), or null.
  final double? flash;

  @override
  Widget build(BuildContext context) {
    if (!metric.isAvailable) {
      return Text('Not available', style: B05Typography.caption(context));
    }
    if (!metric.hasTarget || metric.progress == null) {
      return const SizedBox.shrink();
    }
    final end = metric.upperProgress ?? metric.progress!;
    final flashShare = TodayMotionTiming.macroFlashShare;
    final f = flash;
    final glow = f == null || f >= flashShare
        ? 0.0
        : math.sin(f / flashShare * math.pi);
    return IndiFitCountUp(
      value: end,
      begin: entranceDelay == null ? null : 0,
      delay: entranceDelay ?? Duration.zero,
      duration: TodayMotionTiming.bar,
      builder: (context, value) {
        final low = metric.lowerProgress ?? end;
        final displayedLow = end == 0 ? 0.0 : low * (value / end);
        return SizedBox(
          height: 4,
          width: double.infinity,
          child: CustomPaint(
            painter: RangeBarPainter(
              low: displayedLow.clamp(0.0, value),
              high: value,
              color: metric.isOverTarget ? context.b05Colors.overflow : color,
              track: context.b05Colors.borderSubtle,
              isRange: metric.isRange,
              glow: glow,
            ),
          ),
        );
      },
    );
  }
}

class RangeBarPainter extends CustomPainter {
  const RangeBarPainter({
    required this.low,
    required this.high,
    required this.color,
    required this.track,
    required this.isRange,
    this.glow = 0,
  });

  final double low;
  final double high;
  final Color color;
  final Color track;
  final bool isRange;

  /// 0–1: a soft flash at the bar end when the target is reached.
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = track,
    );
    if (low > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * low, size.height),
          radius,
        ),
        Paint()..color = isRange ? color.withValues(alpha: .45) : color,
      );
    }
    if (high > low) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * low,
            0,
            size.width * (high - low),
            size.height,
          ),
          radius,
        ),
        Paint()..color = color,
      );
    }
    if (glow > 0 && high > 0) {
      final tip = Offset(size.width * high - size.height / 2, size.height / 2);
      canvas.drawCircle(
        tip,
        size.height * (1 + 1.5 * glow),
        Paint()
          ..color = color.withValues(alpha: .55 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        tip,
        size.height * .75,
        Paint()..color = Color.lerp(color, const Color(0xFFFFFFFF), .6 * glow)!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RangeBarPainter oldDelegate) =>
      oldDelegate.glow != glow ||
      oldDelegate.low != low ||
      oldDelegate.high != high ||
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.isRange != isRange;
}

/// Composite card wrapping TodayNutritionHero with standard defaults.
class CalorieRingCard extends StatelessWidget {
  const CalorieRingCard({
    super.key,
    required this.presentation,
    required this.onLogFood,
    this.onOpenFoodGuidance,
    this.dateRelation = TodayDateRelation.today,
    this.selectedDate,
    this.onOpenTargetSetup,
    this.onRetry,
    this.onScanBarcode,
    this.onAiNutrition,
    this.onViewDiary,
  });

  final TodayNutritionPresentation presentation;
  final VoidCallback onLogFood;
  final VoidCallback? onOpenFoodGuidance;
  final TodayDateRelation dateRelation;
  final DateTime? selectedDate;
  final VoidCallback? onOpenTargetSetup;
  final VoidCallback? onRetry;
  final VoidCallback? onScanBarcode;
  final VoidCallback? onAiNutrition;
  final VoidCallback? onViewDiary;

  @override
  Widget build(BuildContext context) {
    return TodayNutritionHero(
      presentation: presentation,
      onLogFood: onLogFood,
      onOpenFoodGuidance: onOpenFoodGuidance,
      dateRelation: dateRelation,
      selectedDate: selectedDate ?? DateTime.now(),
      onOpenTargetSetup: onOpenTargetSetup ?? () {},
      onRetry: onRetry ?? () {},
    );
  }
}
