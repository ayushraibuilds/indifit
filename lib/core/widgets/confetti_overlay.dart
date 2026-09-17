import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lightweight, self-contained confetti animation overlay.
/// Drops colorful confetti particles across the child with zero external dependencies.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    required this.child,
    this.particleCount = 40,
    this.duration = const Duration(milliseconds: 2500),
  });

  final Widget child;
  final int particleCount;
  final Duration duration;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  static const List<Color> _colors = [
    Color(0xFFFF5252), // Red
    Color(0xFFFFD740), // Amber
    Color(0xFF69F0AE), // Mint
    Color(0xFF40C4FF), // Blue
    Color(0xFFE040FB), // Purple
    Color(0xFFFFAB40), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final random = math.Random();
    _particles = List.generate(widget.particleCount, (index) {
      return _ConfettiParticle(
        x: random.nextDouble(),
        speedY: 0.3 + random.nextDouble() * 0.7,
        swaySpeed: 2.0 + random.nextDouble() * 3.0,
        swayAmplitude: 15.0 + random.nextDouble() * 25.0,
        rotationSpeed: (random.nextDouble() - 0.5) * 8.0,
        size: 6.0 + random.nextDouble() * 6.0,
        color: _colors[index % _colors.length],
        delay: random.nextDouble() * 0.3,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (_controller.value == 0.0 || _controller.value == 1.0) {
                  return const SizedBox.shrink();
                }
                return CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _controller.value,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle({
    required this.x,
    required this.speedY,
    required this.swaySpeed,
    required this.swayAmplitude,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    required this.delay,
  });

  final double x;
  final double speedY;
  final double swaySpeed;
  final double swayAmplitude;
  final double rotationSpeed;
  final double size;
  final Color color;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (progress < p.delay) continue;
      final effectiveProgress = (progress - p.delay) / (1.0 - p.delay);
      final y = effectiveProgress * (size.height + 40) * p.speedY;
      if (y > size.height + 20) continue;

      final sway = math.sin(effectiveProgress * math.pi * p.swaySpeed) * p.swayAmplitude;
      final x = (p.x * size.width) + sway;

      final paint = Paint()
        ..color = p.color.withValues(alpha: (1.0 - effectiveProgress * 0.5).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(effectiveProgress * math.pi * p.rotationSpeed);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
