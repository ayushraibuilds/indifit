import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// Specification for deterministic bubble animation without frame randomness.
class HydrationBubbleSpec {
  const HydrationBubbleSpec({
    required this.relativeX,
    required this.radius,
    required this.phaseOffset,
    required this.speed,
  });

  final double relativeX;
  final double radius;
  final double phaseOffset;
  final double speed;
}

/// A fluid-fill wave progress indicator for hydration tracking (Stage 3).
///
/// Features:
/// - Continuous dual sinusoidal wave animation (foreground + background parallax)
/// - Smooth animated level rises on intake updates (easeOutCubic)
/// - Deterministic micro-bubbles (no random numbers, stable for testing/goldens)
/// - Dynamic semantic token coloring (info -> success upon goal completion)
/// - Lifecycle-aware ticker pausing on backgrounding
/// - Zero semantic duplication: wraps canvas in [ExcludeSemantics] so the
///   parent surface retains the single authoritative announcement.
class HydrationFluidFillIndicator extends StatefulWidget {
  const HydrationFluidFillIndicator({
    super.key,
    required this.progress,
    this.isGoalMet = false,
    this.height = 32.0,
    this.borderRadius = B05Radii.smallRadius,
    this.color,
    this.containerColor,
    this.successColor,
    this.successContainerColor,
    this.showPercentageBadge = false,
    this.repeatInTests = false,
  });

  /// The raw progress ratio (e.g. 0.6 for 60%, 1.2 for 120%).
  /// Visual fluid fill is clamped to [0.0, 1.0], while overflow (>1.0)
  /// activates the surplus celebration styling.
  final double progress;

  /// Whether the daily hydration goal has been met.
  final bool isGoalMet;

  /// Height of the reservoir bar in logical pixels.
  final double height;

  /// Border radius of the container.
  final BorderRadius borderRadius;

  /// Override color for water fluid (defaults to [B05SemanticColors.info.indicator]).
  final Color? color;

  /// Override container background color (defaults to [B05SemanticColors.info.container]).
  final Color? containerColor;

  /// Override color when goal is met (defaults to [B05SemanticColors.success.indicator]).
  final Color? successColor;

  /// Override container color when goal is met (defaults to [B05SemanticColors.success.container]).
  final Color? successContainerColor;

  /// Whether to render a compact percentage pill badge overlay.
  final bool showPercentageBadge;

  /// Whether to loop the wave continuously in Flutter test environments.
  /// Defaults to false so [WidgetTester.pumpAndSettle] can settle gracefully.
  final bool repeatInTests;

  @override
  State<HydrationFluidFillIndicator> createState() =>
      _HydrationFluidFillIndicatorState();
}

class _HydrationFluidFillIndicatorState
    extends State<HydrationFluidFillIndicator>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _waveController;

  static const _bubbles = [
    HydrationBubbleSpec(relativeX: 0.18, radius: 1.8, phaseOffset: 0.10, speed: 1.0),
    HydrationBubbleSpec(relativeX: 0.42, radius: 1.5, phaseOffset: 0.55, speed: 1.25),
    HydrationBubbleSpec(relativeX: 0.68, radius: 2.1, phaseOffset: 0.35, speed: 0.90),
    HydrationBubbleSpec(relativeX: 0.86, radius: 1.4, phaseOffset: 0.80, speed: 1.15),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _startAnimationIfAllowed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      if (_waveController.isAnimating) {
        _waveController.stop();
      }
    } else if (state == AppLifecycleState.resumed) {
      _startAnimationIfAllowed();
    }
  }

  void _startAnimationIfAllowed() {
    if (!mounted) return;
    if (_waveController.isAnimating) return;
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest && !widget.repeatInTests) {
      _waveController.forward();
    } else {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant HydrationFluidFillIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress ||
        oldWidget.isGoalMet != widget.isGoalMet) {
      final isTest =
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (isTest && !widget.repeatInTests) {
        _waveController.forward(from: 0.0);
      } else {
        _startAnimationIfAllowed();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    final clampedLevel = widget.progress.clamp(0.0, 1.0);
    final isOverflow = widget.progress > 1.0;
    final percentInt = (widget.progress * 100).round();

    // Smooth 600ms easeOutCubic level tweening
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: clampedLevel),
      duration: B05MotionPolicy.transitionDuration(
        context,
        standard: const Duration(milliseconds: 600),
      ),
      curve: Curves.easeOutCubic,
      builder: (context, animatedLevel, _) {
        // Smooth 600ms color interpolation for goal transitions
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: widget.isGoalMet ? 1.0 : 0.0),
          duration: B05MotionPolicy.transitionDuration(
            context,
            standard: const Duration(milliseconds: 600),
          ),
          curve: Curves.easeOutCubic,
          builder: (context, colorT, _) {
            final activeIndicator = Color.lerp(
              widget.color ?? colors.info.indicator,
              widget.successColor ?? colors.success.indicator,
              colorT,
            )!;

            final activeContainer = Color.lerp(
              widget.containerColor ??
                  colors.info.container.withValues(alpha: 0.30),
              widget.successContainerColor ??
                  colors.success.container.withValues(alpha: 0.35),
              colorT,
            )!;

            final secondaryColor = activeIndicator.withValues(alpha: 0.40);
            final crestColor = Color.lerp(
              activeIndicator,
              Colors.white,
              0.45,
            )!.withValues(alpha: 0.65);

            return SizedBox(
              height: widget.height,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: HydrationWavePainter(
                                phase: _waveController.value,
                                level: animatedLevel,
                                waveColor: activeIndicator,
                                secondaryWaveColor: secondaryColor,
                                containerColor: activeContainer,
                                crestHighlightColor: crestColor,
                                borderRadius: widget.borderRadius,
                                isGoalMet: widget.isGoalMet,
                                isOverflow: isOverflow,
                                bubbles: _bubbles,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (widget.showPercentageBadge)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: B05Layout.space8,
                            vertical: B05Layout.space4 / 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.page.withValues(alpha: 0.70),
                            borderRadius: B05Radii.smallRadius,
                          ),
                          child: Text(
                            '$percentInt%',
                            style: B05Typography.caption(context).copyWith(
                              fontWeight: FontWeight.w700,
                              color: activeIndicator,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Custom painter for rendering dual sinusoidal hydration waves.
class HydrationWavePainter extends CustomPainter {
  const HydrationWavePainter({
    required this.phase,
    required this.level,
    required this.waveColor,
    required this.secondaryWaveColor,
    required this.containerColor,
    required this.crestHighlightColor,
    required this.borderRadius,
    required this.isGoalMet,
    required this.isOverflow,
    required this.bubbles,
  });

  final double phase;
  final double level;
  final Color waveColor;
  final Color secondaryWaveColor;
  final Color containerColor;
  final Color crestHighlightColor;
  final BorderRadius borderRadius;
  final bool isGoalMet;
  final bool isOverflow;
  final List<HydrationBubbleSpec> bubbles;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    canvas.save();
    canvas.clipRRect(rrect);

    // 1. Draw reservoir container background
    final bgPaint = Paint()
      ..color = containerColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, bgPaint);

    // 2. Draw fluid if level > 0
    final clampedLevel = level.clamp(0.0, 1.0);
    if (clampedLevel > 0.0) {
      final baseY = size.height * (1.0 - clampedLevel);

      // Dampen wave amplitude near 0% and 100% to prevent hard clipping
      final edgeDampening = math.sin(clampedLevel * math.pi);
      final maxAmplitude = math.min(size.height * 0.12, 4.0);
      final amplitude = maxAmplitude * edgeDampening;

      // --- Background Secondary Wave ---
      const f2 = 1.15;
      final phase2 = (phase * 0.75 + 0.25) * 2 * math.pi;
      final amp2 = amplitude * 0.65;

      final secondaryPath = Path();
      secondaryPath.moveTo(0, baseY + math.sin(phase2) * amp2);
      for (double x = 1.0; x <= size.width; x += 2.0) {
        final y = baseY +
            math.sin((x / size.width * 2 * math.pi * f2) + phase2) * amp2;
        secondaryPath.lineTo(x, y);
      }
      secondaryPath.lineTo(size.width, size.height);
      secondaryPath.lineTo(0, size.height);
      secondaryPath.close();

      final secondaryPaint = Paint()
        ..color = secondaryWaveColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(secondaryPath, secondaryPaint);

      // --- Deterministic Bubbles ---
      if (clampedLevel >= 0.12) {
        final bubblePaint = Paint()..style = PaintingStyle.fill;
        for (final bubble in bubbles) {
          final p = (phase * bubble.speed + bubble.phaseOffset) % 1.0;
          final bubbleY = (size.height - 2) -
              p * ((size.height - 2) - (baseY + 3));
          if (bubbleY >= baseY + 2) {
            final sway =
                math.sin((p * 2 * math.pi) + bubble.phaseOffset) * 3.0;
            final bubbleX = (size.width * bubble.relativeX + sway)
                .clamp(bubble.radius, size.width - bubble.radius);
            final alpha = (math.sin(p * math.pi) * 0.40).clamp(0.0, 1.0);
            bubblePaint.color = crestHighlightColor.withValues(alpha: alpha);
            canvas.drawCircle(
              Offset(bubbleX, bubbleY),
              bubble.radius,
              bubblePaint,
            );
          }
        }
      }

      // --- Foreground Primary Wave ---
      const f1 = 1.45;
      final phase1 = phase * 2 * math.pi;

      final primaryPath = Path();
      final crestPath = Path();

      final startY = baseY + math.sin(phase1) * amplitude;
      primaryPath.moveTo(0, startY);
      crestPath.moveTo(0, startY);

      for (double x = 1.0; x <= size.width; x += 2.0) {
        final y = baseY +
            math.sin((x / size.width * 2 * math.pi * f1) + phase1) * amplitude;
        primaryPath.lineTo(x, y);
        crestPath.lineTo(x, y);
      }
      primaryPath.lineTo(size.width, size.height);
      primaryPath.lineTo(0, size.height);
      primaryPath.close();

      final primaryPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            waveColor.withValues(alpha: 0.82),
            waveColor,
          ],
        ).createShader(
          Rect.fromLTWH(0, baseY, size.width, size.height - baseY),
        )
        ..style = PaintingStyle.fill;
      canvas.drawPath(primaryPath, primaryPaint);

      // --- Crest Luminous Highlight ---
      if (amplitude > 0.4) {
        final crestPaint = Paint()
          ..color = crestHighlightColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25;
        canvas.drawPath(crestPath, crestPaint);
      }
    }

    canvas.restore();

    // 3. Reservoir border & celebration glow
    if (isOverflow) {
      final glowPaint = Paint()
        ..color = waveColor.withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(rrect, glowPaint);
    } else {
      final borderPaint = Paint()
        ..color = waveColor.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HydrationWavePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.level != level ||
        oldDelegate.waveColor != waveColor ||
        oldDelegate.secondaryWaveColor != secondaryWaveColor ||
        oldDelegate.containerColor != containerColor ||
        oldDelegate.crestHighlightColor != crestHighlightColor ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isGoalMet != isGoalMet ||
        oldDelegate.isOverflow != isOverflow;
  }
}
