import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/indifit_haptics.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// A horizontal ruler for height and weight (PREMIUM_REDESIGN_PLAN § 8.5).
///
/// The ruler slides under a fixed centre needle: dragging left raises the
/// value. Each step it crosses writes the new value to [controller], calls
/// [onChanged] and fires one [IndiFitHaptics.selection]. The text field above
/// it stays the accessible way to type a value; the ruler follows whatever
/// the field holds. Screen readers get a slider (swipe up/down to adjust)
/// and keyboards the arrow keys.
class OnboardingRulerPicker extends StatefulWidget {
  const OnboardingRulerPicker({
    required this.controller,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    required this.majorEvery,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final double min;
  final double max;
  final double step;

  /// Every [majorEvery] steps the tick is taller and carries a number.
  final int majorEvery;
  final ValueChanged<String> onChanged;

  /// Distance between two ticks.
  static const double tickSpacing = 10;
  static const double height = 64;

  @override
  State<OnboardingRulerPicker> createState() => _OnboardingRulerPickerState();
}

class _OnboardingRulerPickerState extends State<OnboardingRulerPicker> {
  final _focusNode = FocusNode(debugLabel: 'onboarding-ruler');

  /// The unsnapped value while a drag is under way.
  double? _dragValue;

  double get _value {
    final parsed = double.tryParse(widget.controller.text.trim());
    return _snap(parsed ?? (widget.min + widget.max) / 2);
  }

  double _snap(double value) {
    final steps = ((value - widget.min) / widget.step).round();
    return (widget.min + steps * widget.step).clamp(widget.min, widget.max);
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  void _commit(double value) {
    final snapped = _snap(value);
    if (snapped == _value &&
        widget.controller.text.trim() == _format(snapped)) {
      return;
    }
    final text = _format(snapped);
    widget.controller.text = text;
    widget.onChanged(text);
    unawaited(IndiFitHaptics.selection());
  }

  void _nudge(int steps) => _commit(_value + steps * widget.step);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, _, _) {
        final value = _value;
        final shown = _dragValue ?? value;
        final canDecrease = value > widget.min;
        final canIncrease = value < widget.max;
        return Semantics(
          key: Key('onboarding_ruler_${widget.label}'),
          container: true,
          slider: true,
          label: '${widget.label} ruler',
          value: '${_format(value)} ${widget.unit}',
          increasedValue: canIncrease
              ? '${_format(_snap(value + widget.step))} ${widget.unit}'
              : null,
          decreasedValue: canDecrease
              ? '${_format(_snap(value - widget.step))} ${widget.unit}'
              : null,
          onIncrease: canIncrease ? () => _nudge(1) : null,
          onDecrease: canDecrease ? () => _nudge(-1) : null,
          child: ExcludeSemantics(
            child: Focus(
              focusNode: _focusNode,
              // Not a stop for Next / Tab between the number fields; the
              // field above is the keyboard path, and arrow keys work once
              // the ruler has been touched.
              skipTraversal: true,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _nudge(1);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _nudge(-1);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  _focusNode.requestFocus();
                  setState(() => _dragValue = value);
                },
                onHorizontalDragUpdate: (details) {
                  final next =
                      (_dragValue ?? value) -
                      details.delta.dx /
                          OnboardingRulerPicker.tickSpacing *
                          widget.step;
                  setState(
                    () => _dragValue = next.clamp(widget.min, widget.max),
                  );
                  _commit(_dragValue!);
                },
                onHorizontalDragEnd: (_) => setState(() => _dragValue = null),
                onHorizontalDragCancel: () => setState(() => _dragValue = null),
                child: Container(
                  height: OnboardingRulerPicker.height,
                  decoration: BoxDecoration(
                    color: colors.inset,
                    borderRadius: B05Radii.largeRadius,
                  ),
                  child: ClipRRect(
                    borderRadius: B05Radii.largeRadius,
                    child: CustomPaint(
                      size: const Size.fromHeight(OnboardingRulerPicker.height),
                      painter: OnboardingRulerPainter(
                        value: shown,
                        min: widget.min,
                        max: widget.max,
                        step: widget.step,
                        majorEvery: widget.majorEvery,
                        tickColor: colors.textSecondary,
                        labelStyle: B05Typography.caption(context).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        needleColor: colors.action,
                        textScaler: MediaQuery.textScalerOf(
                          context,
                        ).clamp(maxScaleFactor: 1.3),
                        format: _format,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingRulerPainter extends CustomPainter {
  const OnboardingRulerPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.majorEvery,
    required this.tickColor,
    required this.labelStyle,
    required this.needleColor,
    required this.textScaler,
    required this.format,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final int majorEvery;
  final Color tickColor;
  final TextStyle labelStyle;
  final Color needleColor;
  final TextScaler textScaler;
  final String Function(double) format;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = OnboardingRulerPicker.tickSpacing;
    final centre = size.width / 2;
    final visible = (centre / spacing).ceil() + 1;
    final valueSteps = (value - min) / step;
    final first = math.max(0, (valueSteps - visible).floor());
    final last = math.min(
      ((max - min) / step).round(),
      (valueSteps + visible).ceil(),
    );

    for (var i = first; i <= last; i++) {
      final x = centre + (i - valueSteps) * spacing;
      final major = i % majorEvery == 0;
      final half = !major && majorEvery.isEven && i % (majorEvery ~/ 2) == 0;
      // Ticks fade towards the edges so the needle reads as the focus.
      final fade = (1 - ((x - centre).abs() / centre)).clamp(0.15, 1.0);
      final paint = Paint()
        ..color = tickColor.withValues(alpha: fade)
        ..strokeWidth = major ? 2 : 1
        ..strokeCap = StrokeCap.round;
      final length = major ? 22.0 : (half ? 15.0 : 10.0);
      canvas.drawLine(Offset(x, 8), Offset(x, 8 + length), paint);
      if (major) {
        final painter = TextPainter(
          text: TextSpan(
            text: format(min + i * step),
            style: labelStyle.copyWith(
              color: labelStyle.color?.withValues(alpha: fade),
            ),
          ),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();
        painter.paint(
          canvas,
          Offset(x - painter.width / 2, size.height - painter.height - 6),
        );
      }
    }

    final needle = Paint()
      ..color = needleColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(centre, 4), Offset(centre, 36), needle);
  }

  @override
  bool shouldRepaint(OnboardingRulerPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.tickColor != tickColor ||
      oldDelegate.needleColor != needleColor ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.textScaler != textScaler;
}
