import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double rotation;
  double vr;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.vr,
  });
}

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool isPlaying;

  const ConfettiOverlay({
    super.key,
    required this.child,
    this.isPlaying = false,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();

  final List<Color> _colors = const [
    Color(0xFFFF5252),
    Color(0xFFFF4081),
    Color(0xFFE040FB),
    Color(0xFF7C4DFF),
    Color(0xFF536DFE),
    Color(0xFF448AFF),
    Color(0xFF1DE9B6),
    Color(0xFF64DD17),
    Color(0xFFFFD600),
    Color(0xFFFF6D00),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        _updateParticles();
        setState(() {});
      });

    if (widget.isPlaying) {
      _triggerBurst();
    }
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _triggerBurst();
    }
  }

  void _triggerBurst() {
    _particles.clear();
    for (int i = 0; i < 60; i++) {
      _particles.add(
        ConfettiParticle(
          x: 0.5,
          y: 0.3,
          vx: (_random.nextDouble() - 0.5) * 1.2,
          vy: -_random.nextDouble() * 1.5 - 0.5,
          size: _random.nextDouble() * 8 + 6,
          color: _colors[_random.nextInt(_colors.length)],
          rotation: _random.nextDouble() * 2 * pi,
          vr: (_random.nextDouble() - 0.5) * 0.2,
        ),
      );
    }
    _controller.forward(from: 0.0);
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.x += p.vx * 0.02;
      p.y += p.vy * 0.02;
      p.vy += 0.03; // gravity
      p.rotation += p.vr;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_controller.isAnimating)
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(_particles),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()..color = p.color;
      final px = p.x * size.width;
      final py = p.y * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
