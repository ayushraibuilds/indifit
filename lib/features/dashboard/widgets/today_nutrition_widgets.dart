import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/presentation/consumer_copy.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../today_consumer_presentation.dart';
import '../today_presentation_types.dart';
import '../today_surface_controller.dart';
import 'today_helpers.dart';
import 'today_module_widgets.dart';

/// Today nutrition widgets (PV1-ENG-05B first pass).
///
/// Extracted verbatim from `today_daily_action_surface.dart`; unchanged.

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
    if (!presentation.hasAcceptedCalorieTarget) {
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
        radius: B05SurfaceRadius.large,
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrition', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < B05Layout.compactBreakpoint ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.35;
                final ring = CalorieRing(
                  calories: presentation.calories,
                  hasTarget: presentation.hasAcceptedCalorieTarget,
                  incomplete: presentation.hasIncompleteNutrition,
                  noConsumption: presentation.isNoConsumptionKnown,
                  macros: presentation.macros,
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
            if (presentation.hasIncompleteNutrition) ...[
              const SizedBox(height: B05Layout.space12),
              NutritionNotice(
                icon: Icons.info_outline_rounded,
                label: ConsumerCopy.nutritionDetailsIncomplete,
                color: context.b05Colors.unavailable.indicator,
              ),
            ],
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
  const TodaySparseNutritionModule({super.key, 
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
  const TodayMealIdeasAction({super.key, 
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

class NutritionNotice extends StatelessWidget {
  const NutritionNotice({super.key, 
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Row(
      children: [
        Icon(icon, size: B05Layout.iconSmall, color: color),
        const SizedBox(width: B05Layout.space8),
        Expanded(child: Text(label, style: B05Typography.caption(context))),
      ],
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
    this.macros = const [],
  });

  final TodayNutritionMetricPresentation? calories;
  final bool hasTarget;
  final bool incomplete;
  final bool noConsumption;
  final List<TodayNutritionMetricPresentation> macros;

  Widget _buildDonutChart(BuildContext context, double diameter) {
    final colors = context.b05Colors;

    double proteinG = 0;
    double carbsG = 0;
    double fatG = 0;

    for (final m in macros) {
      final grams = m.pointValue ?? 0;
      if (m.nutrientId == 'protein') proteinG = grams > 0 ? grams : 0;
      if (m.nutrientId == 'carbohydrate') carbsG = grams > 0 ? grams : 0;
      if (m.nutrientId == 'fat') fatG = grams > 0 ? grams : 0;
    }

    final sections = <PieChartSectionData>[];
    if (proteinG > 0) {
      sections.add(
        PieChartSectionData(
          color: colors.success.indicator,
          value: proteinG,
          title: '',
          radius: 10,
          showTitle: false,
        ),
      );
    }
    if (carbsG > 0) {
      sections.add(
        PieChartSectionData(
          color: colors.warning.indicator,
          value: carbsG,
          title: '',
          radius: 10,
          showTitle: false,
        ),
      );
    }
    if (fatG > 0) {
      sections.add(
        PieChartSectionData(
          color: colors.danger.indicator,
          value: fatG,
          title: '',
          radius: 10,
          showTitle: false,
        ),
      );
    }
    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          color: colors.inset,
          value: 1,
          title: '',
          radius: 10,
          showTitle: false,
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: sections.length > 1 ? 2 : 0,
        centerSpaceRadius: (diameter / 2) - 10,
        startDegreeOffset: -90,
      ),
    );
  }

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
        : incomplete
        ? 'Some nutrition incomplete'
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
                  Positioned.fill(
                    child: macros.isNotEmpty
                        ? _buildDonutChart(context, diameter)
                        : CustomPaint(
                            painter: CalorieRingPainter(
                              progressLow: lowValue,
                              progressHigh: value,
                              color: color,
                              trackColor: colors.inset,
                              range: metric.isRange,
                            ),
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(inset),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          child: Text(
                            metric.value,
                            style: B05Typography.metric(
                              context,
                            ).copyWith(fontSize: 31, letterSpacing: -1),
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class CalorieRingPainter extends CustomPainter {
  const CalorieRingPainter({
    required this.progressLow,
    required this.progressHigh,
    required this.color,
    required this.trackColor,
    required this.range,
  });

  final double progressLow;
  final double progressHigh;
  final Color color;
  final Color trackColor;
  final bool range;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -1.5708, 6.28318, false, track);
    if (progressHigh <= 0) return;
    final base = Paint()
      ..color = range ? color.withValues(alpha: .48) : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (progressLow > 0) {
      canvas.drawArc(rect, -1.5708, 6.28318 * progressLow, false, base);
    }
    final remaining = progressHigh - progressLow;
    if (remaining > 0) {
      final high = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        -1.5708 + 6.28318 * progressLow,
        6.28318 * remaining,
        false,
        high,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CalorieRingPainter oldDelegate) =>
      oldDelegate.progressLow != progressLow ||
      oldDelegate.progressHigh != progressHigh ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.range != range;
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
    final role = switch (metric.nutrientId) {
      'protein' => context.b05Colors.success,
      'carbohydrate' => context.b05Colors.warning,
      'fat' => context.b05Colors.danger,
      'fibre' => context.b05Colors.info,
      _ => context.b05Colors.unavailable,
    };
    final icon = switch (metric.nutrientId) {
      'protein' => Icons.egg_alt_rounded,
      'carbohydrate' => Icons.grain_rounded,
      'fat' => Icons.opacity_rounded,
      'fibre' => Icons.eco_rounded,
      _ => Icons.circle_outlined,
    };
    final compact = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final label =
        '${metric.label}: ${metric.comparisonLabel}'
        '${metric.estimated ? ', estimated' : ''}'
        '${metric.isIncomplete ? ', incomplete' : ''}';
    final header = Row(
      children: [
        Icon(icon, size: B05Layout.iconSmall, color: role.indicator),
        const SizedBox(width: B05Layout.space4),
        Expanded(
          child: Text(metric.label, style: B05Typography.label(context)),
        ),
        if (!compact)
          Flexible(
            child: Text(
              metric.comparisonLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: B05Typography.caption(context).copyWith(
                color: metric.isOverTarget
                    ? context.b05Colors.danger.indicator
                    : context.b05Colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
              Text(
                metric.comparisonLabel,
                style: B05Typography.caption(context).copyWith(
                  color: metric.isOverTarget
                      ? context.b05Colors.danger.indicator
                      : context.b05Colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (metric.estimated && !metric.isIncomplete) ...[
              const SizedBox(height: B05Layout.space4),
              Text('Estimated', style: B05Typography.caption(context)),
            ],
            if (metric.hasTarget && metric.progress != null) ...[
              const SizedBox(height: B05Layout.space4),
              MacroProgress(metric: metric, color: role.indicator),
            ] else if (!metric.isAvailable) ...[
              const SizedBox(height: B05Layout.space4),
              Text('Not available', style: B05Typography.caption(context)),
            ],
          ],
        ),
      ),
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
              track: context.b05Colors.inset,
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

