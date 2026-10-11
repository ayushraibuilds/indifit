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

/// Today nutrition widgets (PV1-ENG-05B first pass).
///
/// Extracted verbatim from `today_daily_action_surface.dart`; unchanged.

/// The Today nutrition card. It remembers the last totals it showed, so when
/// a log lands it can say what was added ("+230 kcal · Poha", V3) while the
/// ring and numbers count up from the old values.
class TodayNutritionHero extends StatefulWidget {
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
  State<TodayNutritionHero> createState() => _TodayNutritionHeroState();
}

class _TodayNutritionHeroState extends State<TodayNutritionHero> {
  // The last ready totals, kept across loading states so a refresh after a
  // log still compares against what the user saw.
  DateTime? _seenDate;
  Set<String>? _seenIds;
  double? _seenKcal;

  String? _chipLabel;
  var _chipSerial = 0;

  @override
  void initState() {
    super.initState();
    _remember(widget);
  }

  @override
  void didUpdateWidget(covariant TodayNutritionHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    final chip = todayLoggedChipLabel(
      previousDate: _seenDate,
      previousIds: _seenIds,
      previousKcal: _seenKcal,
      date: widget.selectedDate,
      presentation: widget.presentation,
    );
    if (chip != null && !B05MotionPolicy.reduceMotion(context)) {
      _chipLabel = chip;
      _chipSerial++;
    }
    _remember(widget);
  }

  void _remember(TodayNutritionHero hero) {
    final presentation = hero.presentation;
    if (presentation.state == TodayPresentationState.loading ||
        presentation.state == TodayPresentationState.unavailable) {
      return;
    }
    _seenDate = hero.selectedDate;
    _seenIds = {for (final record in presentation.loggedRecords) record.$1};
    _seenKcal = presentation.calories?.pointValue;
  }

  @override
  Widget build(BuildContext context) {
    final label = _chipLabel;
    return _TodayNutritionHeroBody(
      presentation: widget.presentation,
      onLogFood: widget.onLogFood,
      onOpenFoodGuidance: widget.onOpenFoodGuidance,
      dateRelation: widget.dateRelation,
      selectedDate: widget.selectedDate,
      onOpenTargetSetup: widget.onOpenTargetSetup,
      onRetry: widget.onRetry,
      ringOverlay: label == null
          ? null
          : TodayLoggedChip(
              key: ValueKey<int>(_chipSerial),
              label: label,
              onDone: () {
                if (mounted) setState(() => _chipLabel = null);
              },
            ),
    );
  }
}

/// "+230 kcal · Poha" when the only change since [previousIds] is new records
/// on the same day and the calorie total went up; several new records read
/// "+640 kcal · 4 foods". Null otherwise (first view, another day, edits,
/// deletes, unknown totals), so the chip never claims more than it knows.
@visibleForTesting
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
  final what = added.length == 1
      ? added.single.$2.trim()
      : '${added.length} foods';
  final amount = '+${formatTodayMetric(delta)} kcal';
  return what.isEmpty ? amount : '$amount · $what';
}

/// Floats up above the ring once, holds, then fades and calls [onDone].
class TodayLoggedChip extends StatefulWidget {
  const TodayLoggedChip({required this.label, required this.onDone, super.key});

  static const Duration duration = Duration(milliseconds: 1800);

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

  @override
  void initState() {
    super.initState();
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
    this.ringOverlay,
  });

  final TodayNutritionPresentation presentation;
  final VoidCallback onLogFood;
  final VoidCallback? onOpenFoodGuidance;
  final TodayDateRelation dateRelation;
  final DateTime selectedDate;
  final VoidCallback onOpenTargetSetup;
  final VoidCallback onRetry;
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
    return Semantics(
      container: true,
      label: 'Nutrition. ${presentation.headline}',
      child: B05Surface(
        tone: B05SurfaceTone.raised,
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Nutrition', style: B05Typography.title(context)),
                ),
                if (presentation.hasIncompleteNutrition)
                  const NutritionIncompleteInfo(),
              ],
            ),
            const SizedBox(height: B05Layout.space12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < B05Layout.compactBreakpoint ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.35;
                final calorieRing = CalorieRing(
                  calories: presentation.calories,
                  hasTarget: presentation.hasAcceptedCalorieTarget,
                  incomplete: presentation.hasIncompleteNutrition,
                  noConsumption: presentation.isNoConsumptionKnown,
                );
                final overlay = ringOverlay;
                // One structure with or without the chip, so the ring keeps
                // its count-up state when the chip comes and goes.
                final ring = Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    calorieRing,
                    // Above the arc's start, a little wider than the ring;
                    // long names ellipsize.
                    Positioned(
                      top: -B05Layout.space20,
                      left: -B05Layout.space32,
                      right: -B05Layout.space32,
                      child: Center(child: overlay ?? const SizedBox.shrink()),
                    ),
                  ],
                );
                final macros = MacroComparison(metrics: presentation.macros);
                return compact
                    ? Column(
                        children: [
                          ring,
                          const SizedBox(height: B05Layout.space16),
                          macros,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ring,
                          const SizedBox(width: B05Layout.space20),
                          Expanded(child: macros),
                        ],
                      );
              },
            ),
            const SizedBox(height: B05Layout.space16),
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
                B05ActionButton(
                  label: 'View targets',
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
                  label: 'Set a target',
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

/// Keeps "some details are missing" one tap away instead of a standing
/// line on the card; most Indian foods don't list every nutrient.
class NutritionIncompleteInfo extends StatelessWidget {
  const NutritionIncompleteInfo({super.key});

  static const explanation =
      'Some foods you logged don’t list every nutrient. Totals include '
      'what is known; missing values are left out, not counted as zero.';

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: ConsumerCopy.nutritionDetailsIncomplete,
    icon: Icon(
      Icons.info_outline_rounded,
      color: context.b05Colors.unavailable.indicator,
    ),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ConsumerCopy.nutritionDetailsIncomplete),
        content: const Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
}

class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.calories,
    required this.hasTarget,
    required this.incomplete,
    required this.noConsumption,
  });

  final TodayNutritionMetricPresentation? calories;
  final bool hasTarget;
  final bool incomplete;
  final bool noConsumption;

  @override
  Widget build(BuildContext context) {
    final metric = calories;
    if (metric == null) {
      return Semantics(
        label: 'Calories are unavailable.',
        child: const SizedBox(width: 152, height: 152),
      );
    }
    final colors = context.b05Colors;
    final isOver = metric.isOverTarget;
    final color = isOver ? colors.danger.indicator : colors.success.indicator;
    final high = hasTarget
        ? metric.upperProgress ?? metric.progress ?? 0.0
        : 0.0;
    final low = hasTarget ? metric.lowerProgress ?? high : 0;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final diameter = largeText ? 176.0 : 152.0;
    final inset = largeText ? B05Layout.space16 : B05Layout.space20;
    final targetText = metric.hasTarget
        ? 'of ${formatTodayMetric(metric.targetValue!)} kcal'
        : metric.isAvailable
        ? 'kcal logged'
        : 'Nutrition incomplete';
    final status = !metric.isAvailable
        ? '—'
        : metric.isRange
        ? '${metric.value} kcal range'
        : metric.hasTarget
        ? isOver
              ? '${formatTodayMetric(metric.pointValue! - metric.targetValue!)} over'
              : '${formatTodayMetric(metric.targetValue! - (metric.pointValue ?? 0))} left'
        : noConsumption
        ? 'No meals yet'
        : 'Calories logged';
    final statusColor = isOver
        ? colors.danger.indicator
        : incomplete && !metric.isAvailable
        ? colors.unavailable.indicator
        : colors.textSecondary;
    final semantics = metric.isAvailable
        ? metric.hasTarget
              ? 'Calories ${metric.value} of ${formatTodayMetric(metric.targetValue!)} kilocalories. $status.'
              : 'Calories ${metric.value} kilocalories logged. No target set.'
        : 'Calories are incomplete. No total is shown.';

    return Semantics(
      label: semantics,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: high),
          duration: B05MotionPolicy.transitionDuration(
            context,
            standard: B05MotionPolicy.standardDuration,
          ),
          curve: B05MotionPolicy.standardCurve,
          builder: (context, value, _) {
            final lowValue = high == 0 ? 0.0 : low * (value / high);
            return SizedBox(
              width: diameter,
              height: diameter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Calories eaten against the target, never a macro pie: a
                  // full circle of macro shares read as "done" at 40 % of
                  // the day's calories (audit UX-03). Macros are the bars.
                  Positioned.fill(
                    child: CustomPaint(
                      key: const Key('today_calorie_ring'),
                      painter: CalorieRingPainter(
                        progressLow: lowValue,
                        progressHigh: value,
                        color: color,
                        // Green into teal; over the target stays solid red.
                        endColor: isOver ? null : colors.protein.indicator,
                        glow: !isOver,
                        trackColor: colors.borderSubtle,
                        range: metric.isRange,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(inset),
                    // Bound the center column to the ring's inner width so the
                    // FittedBox labels below can scale down instead of
                    // overflowing the donut on narrow text (e.g. long status).
                    child: SizedBox(
                      width: diameter - inset * 2 - 16,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            child: IndiFitCountUp(
                              value: metric.pointValue ?? 0,
                              builder: (context, kcal) => Text(
                                metric.valueAt(kcal),
                                style: B05Typography.metric(
                                  context,
                                ).copyWith(fontSize: 31, letterSpacing: -1),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              targetText,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: B05Typography.caption(context),
                            ),
                          ),
                          const SizedBox(height: B05Layout.space4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              status,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: B05Typography.caption(context).copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The calorie arc (V3, concept E): a gradient from [color] to [endColor]
/// with a soft glow under it. Over the target it is a solid [color] (red)
/// with no glow, as before.
class CalorieRingPainter extends CustomPainter {
  const CalorieRingPainter({
    required this.progressLow,
    required this.progressHigh,
    required this.color,
    required this.trackColor,
    required this.range,
    this.endColor,
    this.glow = false,
  });

  static const double stroke = 14;
  static const double glowSigma = 6;
  static const double glowAlpha = 0.3;

  final double progressLow;
  final double progressHigh;
  final Color color;
  final Color? endColor;
  final Color trackColor;
  final bool range;
  final bool glow;

  static const double _start = -math.pi / 2;
  static const double _full = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Leave room for the glow so it is not clipped at the edge.
    final inset = stroke / 2 + (glow ? glowSigma / 2 : 0);
    final radius = size.shortestSide / 2 - inset;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _full, false, track);
    if (progressHigh <= 0) return;

    final sweep = _full * progressHigh.clamp(0.0, 1.0);
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

    if (glow) {
      canvas.drawArc(
        rect,
        _start,
        sweep,
        false,
        arcPaint(alpha: glowAlpha, blurred: true),
      );
    }
    final low = progressLow.clamp(0.0, progressHigh);
    if (low > 0) {
      canvas.drawArc(
        rect,
        _start,
        _full * low,
        false,
        arcPaint(alpha: range ? .48 : 1),
      );
    }
    final remaining = progressHigh - low;
    if (remaining > 0) {
      canvas.drawArc(
        rect,
        _start + _full * low,
        _full * remaining,
        false,
        arcPaint(),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CalorieRingPainter oldDelegate) =>
      oldDelegate.progressLow != progressLow ||
      oldDelegate.progressHigh != progressHigh ||
      oldDelegate.color != color ||
      oldDelegate.endColor != endColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.range != range ||
      oldDelegate.glow != glow;
}

class MacroComparison extends StatelessWidget {
  const MacroComparison({super.key, required this.metrics});

  final List<TodayNutritionMetricPresentation> metrics;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < metrics.length; index++) ...[
        MacroRow(metric: metrics[index]),
        if (index < metrics.length - 1)
          const SizedBox(height: B05Layout.space12),
      ],
    ],
  );
}

class MacroRow extends StatelessWidget {
  const MacroRow({super.key, required this.metric});

  final TodayNutritionMetricPresentation metric;

  @override
  Widget build(BuildContext context) {
    final role = todayMacroColorRole(context.b05Colors, metric.nutrientId);
    final icon = switch (_todayMacro(metric.nutrientId)) {
      B05Macro.protein => IndiFitIcons.protein,
      B05Macro.carbs => IndiFitIcons.carbs,
      B05Macro.fat => IndiFitIcons.fat,
      B05Macro.fibre => IndiFitIcons.fibre,
      null => Icons.circle_outlined,
    };
    final compact = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final label =
        '${metric.label}: ${metric.comparisonLabel}'
        '${metric.estimated ? ', estimated' : ''}'
        '${metric.isIncomplete ? ', incomplete' : ''}';
    final header = Row(
      children: [
        IndiFitIcon(icon, size: B05Layout.iconSmall, color: role.indicator),
        const SizedBox(width: B05Layout.space4),
        Expanded(
          child: Text(metric.label, style: B05Typography.label(context)),
        ),
        if (!compact) Flexible(child: _value(context, TextAlign.end)),
      ],
    );
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            if (compact) ...[
              const SizedBox(height: B05Layout.space4),
              _value(context, TextAlign.start),
            ],
            if (metric.estimated && !metric.isIncomplete) ...[
              const SizedBox(height: B05Layout.space4),
              Text('Estimated', style: B05Typography.caption(context)),
            ],
            if (metric.hasTarget && metric.progress != null) ...[
              const SizedBox(height: B05Layout.space4),
              MacroProgress(metric: metric, color: role.indicator),
            ],
          ],
        ),
      ),
    );
  }
}

extension on MacroRow {
  /// Unknown values read as a quiet "—" with the reason a tap away; the
  /// row's semantics label still says "Not available".
  Widget _value(BuildContext context, TextAlign align) {
    if (!metric.isAvailable) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: align == TextAlign.end
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Text('—', style: B05Typography.caption(context)),
          const SizedBox(width: B05Layout.space4),
          Tooltip(
            message:
                '${metric.label} isn’t listed for the foods you logged, so '
                'no total is shown.',
            triggerMode: TooltipTriggerMode.tap,
            child: Icon(
              Icons.info_outline_rounded,
              size: B05Layout.iconSmall,
              color: context.b05Colors.unavailable.indicator,
            ),
          ),
        ],
      );
    }
    final value = IndiFitCountUp(
      value: metric.pointValue ?? 0,
      builder: (context, point) => Text(
        metric.valueLabelAt(point),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: B05Typography.caption(context).copyWith(
          color: metric.isOverTarget
              ? context.b05Colors.danger.indicator
              : context.b05Colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    if (!metric.isIncomplete) return value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: align == TextAlign.end
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(child: value),
        const SizedBox(width: B05Layout.space4),
        Tooltip(
          key: ValueKey('macro_partial_${metric.nutrientId}'),
          message:
              'Partial: some foods you logged don’t list '
              '${metric.label.toLowerCase()}, so this total is lower than '
              'what you ate.',
          triggerMode: TooltipTriggerMode.tap,
          child: Icon(
            Icons.info_outline_rounded,
            size: B05Layout.iconSmall,
            color: context.b05Colors.unavailable.indicator,
          ),
        ),
      ],
    );
  }
}

class MacroProgress extends StatelessWidget {
  const MacroProgress({super.key, required this.metric, required this.color});

  final TodayNutritionMetricPresentation metric;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!metric.isAvailable) {
      return Text('Not available', style: B05Typography.caption(context));
    }
    if (!metric.hasTarget || metric.progress == null) {
      return const SizedBox.shrink();
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: metric.upperProgress ?? metric.progress!),
      duration: B05MotionPolicy.transitionDuration(
        context,
        standard: B05MotionPolicy.standardDuration,
      ),
      curve: B05MotionPolicy.standardCurve,
      builder: (context, value, _) {
        final high = metric.upperProgress ?? value;
        final low = metric.lowerProgress ?? high;
        final displayedLow = high == 0 ? 0.0 : low * (value / high);
        return SizedBox(
          height: 7,
          width: double.infinity,
          child: CustomPaint(
            painter: RangeBarPainter(
              low: displayedLow,
              high: value,
              color: metric.isOverTarget
                  ? context.b05Colors.danger.indicator
                  : color,
              track: context.b05Colors.borderSubtle,
              isRange: metric.isRange,
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
  });

  final double low;
  final double high;
  final Color color;
  final Color track;
  final bool isRange;

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
  }

  @override
  bool shouldRepaint(covariant RangeBarPainter oldDelegate) =>
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
