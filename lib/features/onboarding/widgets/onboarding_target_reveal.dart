import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/presentation/consumer_number_label.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/theme/indifit_icons.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// Step 5's daily target, revealed (PREMIUM_REDESIGN_PLAN § 8.5): a short
/// "Building your targets" beat, then the calorie ring fills to the target
/// while the number counts up, and protein, carbs and fat appear under it.
///
/// With [animate] false, or under Reduce Motion, the final state shows on
/// the first frame. Screen readers always get the final values.
class OnboardingTargetReveal extends StatefulWidget {
  const OnboardingTargetReveal({
    required this.calories,
    required this.calorieRangeLabel,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.waterMl,
    required this.animate,
    super.key,
  });

  final int calories;
  final String calorieRangeLabel;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int waterMl;
  final bool animate;

  /// The "Building your targets" beat, then the ring fill.
  static const Duration buildingDuration = Duration(milliseconds: 1500);
  static const Duration fillDuration = Duration(milliseconds: 900);
  static const Duration totalDuration = Duration(milliseconds: 2400);

  @override
  State<OnboardingTargetReveal> createState() => _OnboardingTargetRevealState();
}

class _OnboardingTargetRevealState extends State<OnboardingTargetReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: OnboardingTargetReveal.totalDuration,
  );
  var _started = false;

  static final double _buildingEnd =
      OnboardingTargetReveal.buildingDuration.inMilliseconds /
      OnboardingTargetReveal.totalDuration.inMilliseconds;

  late final Animation<double> _fill = CurvedAnimation(
    parent: _controller,
    curve: Interval(_buildingEnd, 1, curve: B05MotionPolicy.standardCurve),
  );
  late final Animation<double> _macros = CurvedAnimation(
    parent: _controller,
    curve: Interval(0.8, 1, curve: B05MotionPolicy.standardCurve),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || B05MotionPolicy.reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _grams(double value) => '${ConsumerNumberLabel.rounded(value)} g';

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return B05Surface(
      key: const Key('onboarding_target_reveal'),
      tone: B05SurfaceTone.raised,
      child: Semantics(
        container: true,
        label:
            'Starting daily target: ${widget.calories} kilocalories, '
            '${widget.proteinG} grams protein, ${widget.carbsG} grams '
            'carbohydrates, ${widget.fatG} grams fat, ${widget.waterMl} '
            'milliliters water.',
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final building = _controller.value < _buildingEnd;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Starting daily target',
                    style: B05Typography.title(context),
                  ),
                  const SizedBox(height: B05Layout.space16),
                  Center(
                    child: SizedBox.square(
                      dimension: 168,
                      child: CustomPaint(
                        painter: OnboardingTargetRingPainter(
                          progress: _fill.value,
                          trackColor: colors.inset,
                          startColor: colors.success.indicator,
                          endColor: colors.macro(B05Macro.protein).indicator,
                        ),
                        // Large text scales down inside the ring instead of
                        // spilling out of it.
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: building
                                ? Column(
                                    key: const Key(
                                      'onboarding_target_building',
                                    ),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox.square(
                                        dimension: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: colors.action,
                                        ),
                                      ),
                                      const SizedBox(height: B05Layout.space8),
                                      Text(
                                        'Building your\ntargets',
                                        textAlign: TextAlign.center,
                                        style: B05Typography.caption(context),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        ConsumerNumberLabel.rounded(
                                          widget.calories * _fill.value,
                                        ),
                                        style: B05Typography.number(
                                          context,
                                          size: 34,
                                        ),
                                      ),
                                      Text(
                                        'kcal a day',
                                        style: B05Typography.caption(context),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: B05Layout.space8),
                  Text(
                    'Target zone: ${widget.calorieRangeLabel}',
                    textAlign: TextAlign.center,
                    style: B05Typography.caption(context),
                  ),
                  const SizedBox(height: B05Layout.space16),
                  Opacity(
                    opacity: _macros.value,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: B05Layout.space8,
                      runSpacing: B05Layout.space8,
                      children: [
                        _MacroChip(
                          label: 'Protein',
                          value: _grams(widget.proteinG),
                          icon: IndiFitIcons.protein,
                          role: colors.macro(B05Macro.protein),
                        ),
                        _MacroChip(
                          label: 'Carbs',
                          value: _grams(widget.carbsG),
                          icon: IndiFitIcons.carbs,
                          role: colors.macro(B05Macro.carbs),
                        ),
                        _MacroChip(
                          label: 'Fat',
                          value: _grams(widget.fatG),
                          icon: IndiFitIcons.fat,
                          role: colors.macro(B05Macro.fat),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: B05Layout.space12),
                  Text(
                    'Water: ${ConsumerNumberLabel.rounded(widget.waterMl.toDouble())} ml · '
                    'Saved when you finish; edit it later in Settings › Goal & targets.',
                    textAlign: TextAlign.center,
                    style: B05Typography.caption(context),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.role,
  });

  final String label;
  final String value;
  final IconData icon;
  final B05ColorRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: B05Layout.space12,
        vertical: B05Layout.space8,
      ),
      decoration: BoxDecoration(
        color: role.container,
        borderRadius: B05Radii.largeRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: role.indicator),
          const SizedBox(width: B05Layout.space8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: B05Typography.caption(context)),
              Text(
                value,
                style: B05Typography.number(
                  context,
                ).copyWith(color: role.foreground),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The target ring: a track and a gradient arc from the top, clockwise.
class OnboardingTargetRingPainter extends CustomPainter {
  const OnboardingTargetRingPainter({
    required this.progress,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
  });

  final double progress;
  final Color trackColor;
  final Color startColor;
  final Color endColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: [startColor, endColor, startColor],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(OnboardingTargetRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.startColor != startColor ||
      oldDelegate.endColor != endColor;
}
