import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/catalog/food_catalog_models.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/typed_quantities.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// The household vessel a portion is measured in.
enum PortionVessel {
  smallKatori,
  katori,
  mediumKatori,
  bowl,
  glass,
  spoon,
  plate,
  piece,
}

/// What the portion sheet draws: [count] of [vessel], with an optional
/// metric equivalent ("≈ 225 g").
class PortionVisualSpec {
  final PortionVessel vessel;
  final double count;

  /// The measure's name for the caption, e.g. "katori" or "glass".
  final String unitLabel;

  /// Grams or millilitres the portion comes to, when known.
  final String? metricLabel;

  const PortionVisualSpec({
    required this.vessel,
    required this.count,
    required this.unitLabel,
    this.metricLabel,
  });

  /// "1½ katori", "2 glasses".
  String get caption {
    final amount = formatPortionCount(count);
    final unit = count > 1 ? _plural(unitLabel) : unitLabel;
    return '$amount $unit';
  }

  /// "1.5 katori, about 225 grams".
  String get semanticsLabel {
    final amount = count == count.roundToDouble()
        ? count.toStringAsFixed(0)
        : count.toString();
    final unit = count > 1 ? _plural(unitLabel) : unitLabel;
    final metric = metricLabel
        ?.replaceFirst('≈ ', 'about ')
        .replaceFirst(RegExp(r' g$'), ' grams')
        .replaceFirst(RegExp(r' ml$'), ' millilitres');
    return metric == null ? '$amount $unit' : '$amount $unit, $metric';
  }

  static String _plural(String unit) => switch (unit) {
    'katori' || 'tbsp' || 'tsp' => unit,
    'glass' => 'glasses',
    _ when unit.endsWith('s') => unit,
    _ => '${unit}s',
  };
}

/// "1", "1½", "2¼", "1.3".
String formatPortionCount(double count) {
  final whole = count.floor();
  final fraction = count - whole;
  String? glyph;
  if ((fraction - 0.25).abs() < 0.01) glyph = '¼';
  if ((fraction - 0.5).abs() < 0.01) glyph = '½';
  if ((fraction - 0.75).abs() < 0.01) glyph = '¾';
  if (fraction.abs() < 0.01) return '$whole';
  if (glyph != null) return whole == 0 ? glyph : '$whole$glyph';
  return count.toStringAsFixed(1);
}

/// Which vessel and how many the portion sheet's selection amounts to, or
/// null when it is a plain metric amount with no household measure.
///
/// - A household quantity names its measure ("katori").
/// - A serving whose label is a household measure ("1 katori", "glass").
/// - Grams or millilitres that equal one of the sheet's household chips.
PortionVisualSpec? portionVisualSpecFor({
  required Quantity quantity,
  String? servingUnitLabel,
  List<ServingOption> servingOptions = const [],
}) {
  final amount = quantity.amount.asDouble;
  if (!amount.isFinite || amount <= 0) return null;

  if (quantity.unit == QuantityUnit.householdReference) {
    final measure = quantity.context.householdMeasure?.measureType;
    final vessel = measure == null ? null : _vesselForName(measure);
    if (vessel == null) return null;
    return PortionVisualSpec(
      vessel: vessel,
      count: amount,
      unitLabel: _unitLabelFor(measure!),
    );
  }

  if (quantity.unit == QuantityUnit.serving && servingUnitLabel != null) {
    final match = RegExp(
      r'^\s*([\d.]+)?\s*(.+?)\s*$',
    ).firstMatch(servingUnitLabel.toLowerCase());
    final perServing = double.tryParse(match?.group(1) ?? '') ?? 1;
    final name = match?.group(2) ?? '';
    final vessel = _vesselForName(name);
    if (vessel == null || vessel == PortionVessel.piece) return null;
    return PortionVisualSpec(
      vessel: vessel,
      count: amount * perServing,
      unitLabel: _unitLabelFor(name),
    );
  }

  final isMass = quantity.unit == QuantityUnit.gram;
  final isVolume = quantity.unit == QuantityUnit.millilitre;
  if (!isMass && !isVolume) return null;
  for (final option in servingOptions) {
    final vessel = _vesselForName(option.unitName);
    if (vessel == null) continue;
    // The sheet sets millilitres as grams / 1.03, rounded.
    final optionAmount = isMass
        ? option.gramWeight
        : (option.gramWeight / 1.03).roundToDouble();
    if ((optionAmount - amount).abs() > 0.5) continue;
    final metric = isMass ? '≈ ${amount.round()} g' : '≈ ${amount.round()} ml';
    return PortionVisualSpec(
      vessel: vessel,
      count: 1,
      unitLabel: _unitLabelFor(option.unitName),
      metricLabel: metric,
    );
  }
  return null;
}

PortionVessel? _vesselForName(String raw) {
  final name = raw.toLowerCase().replaceAll('_', ' ').trim();
  if (name.contains('small') && name.contains('katori')) {
    return PortionVessel.smallKatori;
  }
  if ((name.contains('medium') || name.contains('med')) &&
      name.contains('katori')) {
    return PortionVessel.mediumKatori;
  }
  if (name.contains('katori')) return PortionVessel.katori;
  if (name.contains('bowl')) return PortionVessel.bowl;
  if (name.contains('glass') || name.contains('cup')) {
    return PortionVessel.glass;
  }
  if (name.contains('spoon') || name == 'tbsp' || name == 'tsp') {
    return PortionVessel.spoon;
  }
  if (name.contains('plate') || name.contains('thali')) {
    return PortionVessel.plate;
  }
  if (const {
    'piece',
    'roti',
    'chapati',
    'paratha',
    'idli',
    'dosa',
  }.any(name.contains)) {
    return PortionVessel.piece;
  }
  return null;
}

String _unitLabelFor(String raw) {
  final name = raw.toLowerCase().replaceAll('_', ' ').trim();
  if (name.contains('katori')) {
    if (name.contains('small')) return 'small katori';
    if (name.contains('med')) return 'medium katori';
    return 'katori';
  }
  if (name.contains('bowl')) return 'bowl';
  if (name.contains('glass')) return 'glass';
  if (name.contains('cup')) return 'cup';
  if (name.contains('tablespoon') || name == 'tbsp') return 'tbsp';
  if (name.contains('teaspoon') || name == 'tsp') return 'tsp';
  if (name.contains('plate')) return 'plate';
  if (name.contains('thali')) return 'thali';
  if (name.contains('roti')) return 'roti';
  if (name.contains('paratha')) return 'paratha';
  if (name.contains('idli')) return 'idli';
  if (name.contains('dosa')) return 'dosa';
  return 'piece';
}

/// Draws the portion as vessels: one per whole unit and a part-filled one
/// for a fraction, up to [maxDrawn]; more than that shows one vessel "×N".
class HouseholdPortionVisual extends StatelessWidget {
  final PortionVisualSpec spec;
  static const int maxDrawn = 4;

  const HouseholdPortionVisual({super.key, required this.spec});

  /// The fill of each drawn vessel, 0–1.
  @visibleForTesting
  static List<double> fills(double count) {
    if (count > maxDrawn) return const [1];
    final whole = count.floor();
    final fraction = count - whole;
    return [for (var i = 0; i < whole; i++) 1.0, if (fraction > 0.01) fraction];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final drawn = fills(spec.count);
    final overflow = spec.count > maxDrawn;
    return Semantics(
      label: 'Portion: ${spec.semanticsLabel}',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('household_portion_visual'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Flexible(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  for (final fill in drawn)
                    PortionVesselIcon(
                      vessel: spec.vessel,
                      fill: fill,
                      size: 40,
                    ),
                  if (overflow)
                    Text(
                      '×${formatPortionCount(spec.count)}',
                      style: B05Typography.label(
                        context,
                      ).copyWith(color: colors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spec.caption,
                  style: B05Typography.label(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                if (spec.metricLabel != null)
                  Text(
                    spec.metricLabel!,
                    style: B05Typography.caption(
                      context,
                    ).copyWith(color: colors.textSecondary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One vessel drawing; also used as the household chips' icon.
class PortionVesselIcon extends StatelessWidget {
  final PortionVessel vessel;
  final double fill;
  final double size;

  const PortionVesselIcon({
    super.key,
    required this.vessel,
    this.fill = 1,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return SizedBox(
      width: size,
      height: size * 0.8,
      child: CustomPaint(
        painter: _VesselPainter(
          vessel: vessel,
          fill: fill.clamp(0, 1).toDouble(),
          outline: colors.textSecondary,
          food: colors.action,
        ),
      ),
    );
  }
}

class _VesselPainter extends CustomPainter {
  final PortionVessel vessel;
  final double fill;
  final Color outline;
  final Color food;

  _VesselPainter({
    required this.vessel,
    required this.fill,
    required this.outline,
    required this.food,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.width / 22)
      ..strokeJoin = StrokeJoin.round;
    final foodPaint = Paint()..color = food.withValues(alpha: 0.55);

    final shape = _shape(size);
    if (fill > 0) {
      final bounds = shape.getBounds();
      final top = bounds.bottom - bounds.height * fill;
      canvas.save();
      canvas.clipPath(shape);
      canvas.drawRect(
        Rect.fromLTRB(bounds.left, top, bounds.right, bounds.bottom),
        foodPaint,
      );
      canvas.restore();
    }
    canvas.drawPath(shape, stroke);
    if (vessel == PortionVessel.spoon) {
      final y = size.height * 0.45;
      canvas.drawLine(
        Offset(size.width * 0.55, y),
        Offset(size.width * 0.98, y - size.height * 0.15),
        stroke,
      );
    }
  }

  /// The vessel's outline; the fill is clipped to it.
  Path _shape(Size size) {
    final w = size.width;
    final h = size.height;
    // Katoris and bowls are open bowls of different widths and depths.
    Path bowl(double widthFactor, double depthFactor) {
      final bw = w * widthFactor;
      final left = (w - bw) / 2;
      final rimY = h * (1 - depthFactor) * 0.9;
      return Path()
        ..moveTo(left, rimY)
        ..lineTo(left + bw, rimY)
        ..arcToPoint(
          Offset(left, rimY),
          radius: Radius.elliptical(bw / 2, h - rimY),
        )
        ..close();
    }

    return switch (vessel) {
      PortionVessel.smallKatori => bowl(0.62, 0.5),
      PortionVessel.katori => bowl(0.8, 0.6),
      PortionVessel.mediumKatori => bowl(0.9, 0.68),
      PortionVessel.bowl => bowl(1.0, 0.85),
      PortionVessel.glass =>
        Path()
          ..moveTo(w * 0.28, 0)
          ..lineTo(w * 0.72, 0)
          ..lineTo(w * 0.66, h)
          ..lineTo(w * 0.34, h)
          ..close(),
      PortionVessel.spoon =>
        Path()..addOval(Rect.fromLTWH(w * 0.05, h * 0.25, w * 0.5, h * 0.42)),
      PortionVessel.plate =>
        Path()..addOval(Rect.fromLTWH(0, h * 0.45, w, h * 0.4)),
      PortionVessel.piece =>
        Path()..addOval(Rect.fromLTWH(w * 0.12, h * 0.05, w * 0.76, h * 0.9)),
    };
  }

  @override
  bool shouldRepaint(_VesselPainter old) =>
      old.vessel != vessel ||
      old.fill != fill ||
      old.outline != outline ||
      old.food != food;
}
