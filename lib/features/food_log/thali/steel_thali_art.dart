import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import 'thali_plate_layout.dart';

/// Painted art for the steel thali (PREMIUM_REDESIGN_PLAN § 6, concept A).
///
/// Everything here is drawn with gradients and strokes: no images, no
/// shader. The plate's lathe marks are concentric, as on a real turned steel
/// thali. Food colour comes only from the dish's existing
/// [ThaliDishCategory]; nothing is inferred beyond that.

/// Steel tones. Darker in dark mode so the plate doesn't glare.
@immutable
class SteelTones {
  const SteelTones({
    required this.highlight,
    required this.mid,
    required this.shade,
    required this.deep,
    required this.shadow,
  });

  final Color highlight;
  final Color mid;
  final Color shade;
  final Color deep;
  final Color shadow;

  static const dark = SteelTones(
    highlight: Color(0xFFD5DBE1),
    mid: Color(0xFF9AA3AC),
    shade: Color(0xFF6B747D),
    deep: Color(0xFF474F57),
    shadow: Color(0x99000000),
  );

  static const light = SteelTones(
    highlight: Color(0xFFF4F6F8),
    mid: Color(0xFFC3CAD1),
    shade: Color(0xFF959EA7),
    deep: Color(0xFF6E7781),
    shadow: Color(0x400F172A),
  );

  static SteelTones of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// The food colour for a katori, top-left to bottom-right; null for a dish
/// shown as plain steel.
({Color top, Color bottom})? thaliFoodFill(ThaliDishCategory category) {
  return switch (category) {
    ThaliDishCategory.dal => (
      top: const Color(0xFFF2C14E),
      bottom: const Color(0xFFC98E1B),
    ),
    ThaliDishCategory.sabzi => (
      top: const Color(0xFF8DB04A),
      bottom: const Color(0xFF4E7A23),
    ),
    ThaliDishCategory.curry => (
      top: const Color(0xFFE07A3A),
      bottom: const Color(0xFFA8461A),
    ),
    ThaliDishCategory.curd => (
      top: const Color(0xFFFBF8F1),
      bottom: const Color(0xFFE4DCCB),
    ),
    ThaliDishCategory.sweet => (
      top: const Color(0xFFF6B26B),
      bottom: const Color(0xFFD9822B),
    ),
    ThaliDishCategory.side ||
    ThaliDishCategory.stapleBread ||
    ThaliDishCategory.stapleRice => null,
  };
}

/// Macro energy split for the rim, as fractions of macro kcal.
@immutable
class ThaliMacroSplit {
  const ThaliMacroSplit({
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  static const none = ThaliMacroSplit(protein: 0, carbs: 0, fat: 0);

  final double protein;
  final double carbs;
  final double fat;

  bool get isEmpty => protein + carbs + fat <= 0;

  static ThaliMacroSplit fromGrams({
    required double protein,
    required double carbs,
    required double fat,
  }) {
    final p = protein * 4, c = carbs * 4, f = fat * 9;
    final total = p + c + f;
    if (total <= 0) return none;
    return ThaliMacroSplit(
      protein: p / total,
      carbs: c / total,
      fat: f / total,
    );
  }

  static ThaliMacroSplit lerp(ThaliMacroSplit a, ThaliMacroSplit b, double t) {
    return ThaliMacroSplit(
      protein: a.protein + (b.protein - a.protein) * t,
      carbs: a.carbs + (b.carbs - a.carbs) * t,
      fat: a.fat + (b.fat - a.fat) * t,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThaliMacroSplit &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat;

  @override
  int get hashCode => Object.hash(protein, carbs, fat);
}

/// The plate: drop shadow, raised lip with the macro ring, lathe-turned
/// well and a soft specular sweep.
class SteelPlatePainter extends CustomPainter {
  SteelPlatePainter({
    required this.tones,
    required this.colors,
    required this.split,
    this.partial = false,
    this.tilt,
  }) : super(repaint: tilt);

  final SteelTones tones;
  final B05SemanticColors colors;
  final ThaliMacroSplit split;
  final bool partial;

  /// The plate's tilt in radians (x: left/right, y: towards/away). The
  /// specular sweep slides the other way so the steel catches the light.
  final ValueListenable<Offset>? tilt;

  /// Inner edge of the lip as a fraction of the radius.
  static const double wellFraction = 0.88;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    final plate = Rect.fromCircle(center: c, radius: r);

    // Shadow under the plate.
    canvas.drawCircle(
      c.translate(0, r * 0.03),
      r,
      Paint()
        ..color = tones.shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
    );

    // Lip: lit from the top left, falling off to the bottom right.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tones.highlight, tones.mid, tones.shade],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(plate),
    );

    // Well.
    final wellR = r * wellFraction;
    final well = Rect.fromCircle(center: c, radius: wellR);
    canvas.drawCircle(
      c,
      wellR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.3),
          radius: 1.05,
          colors: [tones.highlight, tones.mid, tones.shade],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(well),
    );

    // Lathe marks: faint concentric rings with a fixed pseudo-random rhythm.
    final random = math.Random(7);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (var rr = wellR * 0.06; rr < wellR - 1; rr += 1.6) {
      final light = random.nextBool();
      ring.color = (light ? Colors.white : Colors.black).withValues(
        alpha: 0.015 + random.nextDouble() * 0.035,
      );
      canvas.drawCircle(c, rr, ring);
    }

    // The step down from lip to well: a dark line with a highlight inside.
    canvas.drawCircle(
      c,
      wellR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = tones.deep.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      c,
      wellR - 1.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // Specular sweep across the upper left of the well.
    final lean = tilt?.value ?? Offset.zero;
    final sweep = Rect.fromCenter(
      center: c.translate(
        -wellR * (0.35 + lean.dx * 4),
        -wellR * (0.45 + lean.dy * 4),
      ),
      width: wellR * 1.3,
      height: wellR * 0.7,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(well));
    canvas.drawOval(
      sweep,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(sweep),
    );
    canvas.restore();

    // Outer edge of the lip.
    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = tones.deep.withValues(alpha: 0.6),
    );

    _paintMacroRing(canvas, c, (r + wellR) / 2, r - wellR);
  }

  void _paintMacroRing(Canvas canvas, Offset c, double radius, double lip) {
    final width = math.max(3.0, lip * 0.32);
    final rect = Rect.fromCircle(center: c, radius: radius);
    if (split.isEmpty) {
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = tones.deep.withValues(alpha: 0.25),
      );
      return;
    }
    var angle = -math.pi / 2;
    const gap = 0.05;
    for (final (fraction, color) in [
      (split.protein, colors.protein.indicator),
      (split.carbs, colors.carbs.indicator),
      (split.fat, colors.fat.indicator),
    ]) {
      final sweep = fraction * 2 * math.pi;
      if (sweep > gap * 2) {
        canvas.drawArc(
          rect,
          angle + gap / 2,
          sweep - gap,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
      }
      angle += sweep;
    }
    if (partial) {
      canvas.drawCircle(
        c,
        radius - width,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors.warning.indicator,
      );
    }
  }

  @override
  bool shouldRepaint(SteelPlatePainter old) =>
      old.tones != tones ||
      old.colors != colors ||
      old.split != split ||
      old.partial != partial ||
      old.tilt != tilt;
}

/// A steel katori seen from above, filled to [fill] (0.35–1.0) with the
/// category's food colour. [fill] 0 draws an empty bowl.
class SteelKatoriPainter extends CustomPainter {
  const SteelKatoriPainter({
    required this.tones,
    required this.category,
    required this.fill,
    this.selectedColor,
  });

  final SteelTones tones;
  final ThaliDishCategory? category;
  final double fill;
  final Color? selectedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1;

    // Shadow cast on the plate.
    canvas.drawCircle(
      c.translate(r * 0.06, r * 0.1),
      r * 0.98,
      Paint()
        ..color = tones.shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );

    // Rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tones.highlight, tones.mid, tones.deep],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Inside wall: the far (top) side is in shadow, the near side lit.
    final inner = r * 0.86;
    final innerRect = Rect.fromCircle(center: c, radius: inner);
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tones.deep, tones.shade, tones.highlight],
        ).createShader(innerRect),
    );
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.45),
    );

    final food = category == null ? null : thaliFoodFill(category!);
    if (fill > 0) {
      // A fuller bowl shows a wider food surface (the bowl tapers).
      final level = fill.clamp(0.35, 1.0);
      final foodR = inner * (0.5 + 0.42 * level);
      final foodCentre = c.translate(0, inner * 0.06 * (1 - level));
      final foodRect = Rect.fromCircle(center: foodCentre, radius: foodR);
      if (food == null) {
        // Plain steel: an inner floor, no food colour.
        canvas.drawCircle(
          foodCentre,
          foodR,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [tones.mid, tones.shade],
            ).createShader(foodRect),
        );
      } else {
        // A flat surface: mostly the top colour, darkening only at the
        // far edge where the bowl wall shades it.
        canvas.drawCircle(
          foodCentre,
          foodR,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0, 0.25),
              radius: 1.05,
              colors: [food.top, food.top, food.bottom],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(foodRect),
        );
        _paintTexture(canvas, foodCentre, foodR);
        // Meniscus where the food meets the bowl wall.
        canvas.drawCircle(
          foodCentre,
          foodR - 0.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = food.bottom.withValues(alpha: 0.9),
        );
        // Wet sheen.
        canvas.drawOval(
          Rect.fromCenter(
            center: foodCentre.translate(-foodR * 0.3, -foodR * 0.35),
            width: foodR * 0.9,
            height: foodR * 0.45,
          ),
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0),
                  ],
                ).createShader(
                  Rect.fromCenter(
                    center: foodCentre.translate(-foodR * 0.3, -foodR * 0.35),
                    width: foodR * 0.9,
                    height: foodR * 0.45,
                  ),
                ),
        );
      }
    }

    if (selectedColor != null) {
      canvas.drawCircle(
        c,
        r + 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = selectedColor!,
      );
    }
  }

  void _paintTexture(Canvas canvas, Offset c, double r) {
    final random = math.Random(category!.index * 31 + 3);
    switch (category!) {
      case ThaliDishCategory.sabzi:
        // Light and dark flecks of vegetable.
        for (var i = 0; i < 9; i++) {
          final a = random.nextDouble() * math.pi * 2;
          final d = random.nextDouble() * r * 0.75;
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * d,
            r * (0.07 + random.nextDouble() * 0.06),
            Paint()
              ..color = i < 3
                  ? const Color(0xFFC9DE8A)
                  : const Color(0xFF3E6419).withValues(alpha: 0.7),
          );
        }
      case ThaliDishCategory.dal:
        // Tadka: a few darker specks.
        for (var i = 0; i < 6; i++) {
          final a = random.nextDouble() * math.pi * 2;
          final d = random.nextDouble() * r * 0.7;
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * d,
            r * 0.045,
            Paint()..color = const Color(0xFF8A4B10).withValues(alpha: 0.75),
          );
        }
      case ThaliDishCategory.curry:
        // Oil pooling at the edge.
        canvas.drawCircle(
          c,
          r * 0.92,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.1
            ..color = const Color(0xFFF2A65A).withValues(alpha: 0.35),
        );
      case ThaliDishCategory.curd:
        // A soft swirl.
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.5),
          -0.4,
          math.pi * 1.2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.06
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFD9CFBA).withValues(alpha: 0.8),
        );
      case ThaliDishCategory.sweet:
        // Saffron strands.
        for (var i = 0; i < 5; i++) {
          final a = random.nextDouble() * math.pi * 2;
          final d = random.nextDouble() * r * 0.6;
          final p = c + Offset(math.cos(a), math.sin(a)) * d;
          canvas.drawLine(
            p,
            p + Offset(r * 0.14, r * 0.05),
            Paint()
              ..strokeWidth = 1.2
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFFB8420F),
          );
        }
      case ThaliDishCategory.side ||
          ThaliDishCategory.stapleBread ||
          ThaliDishCategory.stapleRice:
        break;
    }
  }

  @override
  bool shouldRepaint(SteelKatoriPainter old) =>
      old.tones != tones ||
      old.category != category ||
      old.fill != fill ||
      old.selectedColor != selectedColor;
}

/// A mound of rice: off-white with a grain texture.
class RiceMoundPainter extends CustomPainter {
  const RiceMoundPainter({required this.tones});

  final SteelTones tones;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.9;
    canvas.drawCircle(
      c.translate(r * 0.05, r * 0.08),
      r,
      Paint()
        ..color = tones.shadow.withValues(alpha: tones.shadow.a * 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.1),
    );
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          colors: [Color(0xFFFFFFFF), Color(0xFFF1EDE3), Color(0xFFD8D1C0)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(rect),
    );
    final random = math.Random(11);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.2, r * 0.045);
    for (var i = 0; i < 70; i++) {
      final a = random.nextDouble() * math.pi * 2;
      final d = math.sqrt(random.nextDouble()) * r * 0.9;
      final p = c + Offset(math.cos(a), math.sin(a)) * d;
      final t = random.nextDouble() * math.pi;
      final len = r * 0.09;
      grain.color = (random.nextBool() ? Colors.white : const Color(0xFFC9C1AE))
          .withValues(alpha: 0.9);
      canvas.drawLine(
        p - Offset(math.cos(t), math.sin(t)) * len / 2,
        p + Offset(math.cos(t), math.sin(t)) * len / 2,
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(RiceMoundPainter old) => old.tones != tones;
}

/// A short stack of rotis, one disc per piece up to three.
class RotiStackPainter extends CustomPainter {
  const RotiStackPainter({required this.tones, required this.pieces});

  final SteelTones tones;
  final int pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final count = pieces.clamp(1, 3);
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * (count == 1 ? 0.86 : 0.74);
    final step = r * 0.22;
    for (var i = count - 1; i >= 0; i--) {
      final dc = c.translate(step * (i - (count - 1) / 2), step * i * 0.45);
      canvas.drawCircle(
        dc.translate(r * 0.04, r * 0.07),
        r,
        Paint()
          ..color = tones.shadow.withValues(alpha: tones.shadow.a * 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
      );
      final rect = Rect.fromCircle(center: dc, radius: r);
      // Flat bread: an even tone with a slightly darker, crisper edge.
      canvas.drawCircle(
        dc,
        r,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFE6BD83), Color(0xFFDDB077), Color(0xFFB98447)],
            stops: [0.0, 0.8, 1.0],
          ).createShader(rect),
      );
      canvas.drawCircle(
        dc,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF8A5A2B).withValues(alpha: 0.6),
      );
    }
    // Char spots on the top roti.
    final random = math.Random(5);
    final top = c.translate(-step * (count - 1) / 2, 0);
    final topR = r;
    for (var i = 0; i < 14; i++) {
      final a = random.nextDouble() * math.pi * 2;
      final d = math.sqrt(random.nextDouble()) * topR * 0.8;
      canvas.drawOval(
        Rect.fromCenter(
          center: top + Offset(math.cos(a), math.sin(a)) * d,
          width: topR * (0.08 + random.nextDouble() * 0.12),
          height: topR * (0.05 + random.nextDouble() * 0.08),
        ),
        Paint()
          ..color = const Color(
            0xFF5A3313,
          ).withValues(alpha: 0.35 + random.nextDouble() * 0.4),
      );
    }
  }

  @override
  bool shouldRepaint(RotiStackPainter old) =>
      old.tones != tones || old.pieces != pieces;
}
