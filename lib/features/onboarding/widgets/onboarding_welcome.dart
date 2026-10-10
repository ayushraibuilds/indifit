import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/consumer_task_primitives.dart';

/// The first screen of a fresh setup (PREMIUM_REDESIGN_PLAN § 8.5): the
/// IndiFit mark assembles itself, then one line of value and "Get started".
///
/// The two strength bars slide in, the three leaves grow out of them, a
/// ring pulses once and a light sweep crosses the mark. Tapping anywhere
/// jumps to the end. Under Reduce Motion the final frame shows at once.
class OnboardingWelcome extends StatefulWidget {
  const OnboardingWelcome({required this.onStart, super.key});

  final VoidCallback onStart;

  static const Duration duration = Duration(milliseconds: 2600);

  @override
  State<OnboardingWelcome> createState() => _OnboardingWelcomeState();
}

class _OnboardingWelcomeState extends State<OnboardingWelcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: OnboardingWelcome.duration,
  );
  var _started = false;

  Animation<double> _interval(double begin, double end, [Curve? curve]) =>
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: curve ?? Curves.easeOutCubic),
      );

  late final _glow = _interval(0, 0.45);
  late final _bottomBar = _interval(0.04, 0.32);
  late final _topBar = _interval(0.12, 0.40);
  late final _centreLeaf = _interval(0.30, 0.58, Curves.easeOutBack);
  late final _leftLeaf = _interval(0.38, 0.70, Curves.easeOutBack);
  late final _rightLeaf = _interval(0.42, 0.74, Curves.easeOutBack);
  late final _pulse = _interval(0.62, 0.95, Curves.easeOut);
  late final _sheen = _interval(0.66, 0.94, Curves.easeInOut);
  late final _wordmark = _interval(0.55, 0.80);
  late final _tagline = _interval(0.63, 0.86);
  late final _action = _interval(0.72, 0.96);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (B05MotionPolicy.reduceMotion(context)) {
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

  void _finish() {
    if (_controller.isAnimating) _controller.value = 1;
  }

  Widget _rise(Animation<double> animation, Widget child) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) => Opacity(
      opacity: animation.value,
      alwaysIncludeSemantics: true,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - animation.value)),
        child: child,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final markSize = math.min(MediaQuery.sizeOf(context).width * 0.46, 184.0);
    return ConsumerTaskScaffold(
      key: const Key('onboarding_welcome'),
      scrollable: false,
      padding: EdgeInsets.zero,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: B05Layout.space24,
                  vertical: B05Layout.space24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      image: true,
                      label: 'IndiFit logo',
                      child: SizedBox.square(
                        dimension: markSize * 1.6,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) => CustomPaint(
                            key: const Key('onboarding_welcome_mark'),
                            painter: IndiFitMarkPainter(
                              palette: IndiFitMarkPalette.of(
                                dark: dark,
                                glow: colors.success.indicator,
                              ),
                              markFraction: 1 / 1.6,
                              glow: _glow.value,
                              bottomBar: _bottomBar.value,
                              topBar: _topBar.value,
                              centreLeaf: _centreLeaf.value,
                              leftLeaf: _leftLeaf.value,
                              rightLeaf: _rightLeaf.value,
                              pulse: _pulse.value,
                              sheen: _sheen.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _rise(
                      _wordmark,
                      Text(
                        'IndiFit',
                        textAlign: TextAlign.center,
                        style: B05Typography.pageTitle(context).copyWith(
                          fontSize: 40,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: B05Layout.space12),
                    _rise(
                      _tagline,
                      Text(
                        'Your Indian meals and workouts,\nin one place.',
                        textAlign: TextAlign.center,
                        style: B05Typography.body(
                          context,
                        ).copyWith(fontSize: 17, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      primaryAction: _rise(
        _action,
        B05ActionButton(
          key: const Key('onboarding_welcome_start'),
          label: 'Get started',
          onPressed: widget.onStart,
        ),
      ),
    );
  }
}

/// Colours for [IndiFitMarkPainter]. The dark set matches the app icon
/// (assets/branding/README.md); the light set is one step deeper so the
/// mark keeps its shape on the light page.
@immutable
class IndiFitMarkPalette {
  const IndiFitMarkPalette({
    required this.barTop,
    required this.barBottom,
    required this.leafTop,
    required this.leafBottom,
    required this.glow,
    required this.sheen,
  });

  factory IndiFitMarkPalette.of({required bool dark, required Color glow}) =>
      dark
      ? IndiFitMarkPalette(
          barTop: const Color(0xFF34D399),
          barBottom: const Color(0xFF10B981),
          leafTop: const Color(0xFF5EEAD4),
          leafBottom: const Color(0xFF2DD4BF),
          glow: glow,
          sheen: const Color(0xFFFFFFFF),
        )
      : IndiFitMarkPalette(
          barTop: const Color(0xFF10B981),
          barBottom: const Color(0xFF059669),
          leafTop: const Color(0xFF2DD4BF),
          leafBottom: const Color(0xFF0D9488),
          glow: glow,
          sheen: const Color(0xFFFFFFFF),
        );

  final Color barTop;
  final Color barBottom;
  final Color leafTop;
  final Color leafBottom;
  final Color glow;
  final Color sheen;

  @override
  bool operator ==(Object other) =>
      other is IndiFitMarkPalette &&
      other.barTop == barTop &&
      other.barBottom == barBottom &&
      other.leafTop == leafTop &&
      other.leafBottom == leafBottom &&
      other.glow == glow &&
      other.sheen == sheen;

  @override
  int get hashCode =>
      Object.hash(barTop, barBottom, leafTop, leafBottom, glow, sheen);
}

/// The IndiFit mark drawn as paths: two strength bars joined by a stem, and
/// three leaves rising out of them. Every part takes its own progress
/// (0 → 1) so the mark can assemble itself; all at 1 is the finished logo.
///
/// Geometry is in the app icon's 1024-unit space, traced from
/// `assets/branding/indifit_app_icon_master.png`.
class IndiFitMarkPainter extends CustomPainter {
  const IndiFitMarkPainter({
    required this.palette,
    this.markFraction = 1,
    this.glow = 1,
    this.bottomBar = 1,
    this.topBar = 1,
    this.centreLeaf = 1,
    this.leftLeaf = 1,
    this.rightLeaf = 1,
    this.pulse = 1,
    this.sheen = 1,
  });

  final IndiFitMarkPalette palette;

  /// The share of the canvas the mark fills; the rest holds the glow.
  final double markFraction;
  final double glow;
  final double bottomBar;
  final double topBar;
  final double centreLeaf;
  final double leftLeaf;
  final double rightLeaf;
  final double pulse;
  final double sheen;

  // The mark occupies x 237–787, y 218–775 of the icon.
  static const Rect _markBounds = Rect.fromLTRB(237, 218, 787, 775);
  static const Offset _leafBase = Offset(512, 775);

  static final Path _topBarPath = Path()
    ..moveTo(290, 218)
    ..lineTo(734, 218)
    ..lineTo(787, 300)
    ..lineTo(641, 300)
    ..lineTo(641, 425)
    ..lineTo(578, 480)
    ..lineTo(446, 480)
    ..lineTo(383, 425)
    ..lineTo(383, 300)
    ..lineTo(237, 300)
    ..close();

  static final Path _bottomBarPath = Path()
    ..moveTo(237, 688)
    ..lineTo(787, 688)
    ..lineTo(744, 773)
    ..lineTo(280, 773)
    ..close();

  static final Path _centreLeafPath = Path()
    ..moveTo(512, 322)
    ..cubicTo(478, 375, 462, 440, 466, 500)
    ..cubicTo(470, 580, 500, 640, 512, 705)
    ..cubicTo(524, 640, 554, 580, 558, 500)
    ..cubicTo(562, 440, 546, 375, 512, 322)
    ..close();

  // The dark gap around the centre leaf, wider at the tip as in the icon.
  static final Path _centreGapPath = Path()
    ..moveTo(512, 266)
    ..cubicTo(464, 330, 442, 418, 446, 500)
    ..cubicTo(450, 590, 506, 680, 512, 790)
    ..cubicTo(518, 680, 574, 590, 578, 500)
    ..cubicTo(582, 418, 560, 330, 512, 266)
    ..close();

  static final Path _leftLeafPath = Path()
    ..moveTo(383, 425)
    ..cubicTo(379, 480, 379, 530, 398, 578)
    ..cubicTo(424, 645, 492, 690, 507, 775)
    ..cubicTo(506, 610, 478, 505, 383, 425)
    ..close();

  static final Path _rightLeafPath = _leftLeafPath.transform(
    (Matrix4.identity()
          ..translateByDouble(1024, 0, 0, 1)
          ..scaleByDouble(-1, 1, 1, 1))
        .storage,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final markSide = size.shortestSide * markFraction;

    _paintGlow(canvas, centre, size.shortestSide / 2);
    _paintPulse(canvas, centre, markSide);

    final scale = markSide / _markBounds.longestSide;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(scale);
    canvas.translate(-_markBounds.center.dx, -_markBounds.center.dy);

    // One layer so the gaps can cut through the bars to the page, and the
    // sheen only lands on the mark.
    canvas.saveLayer(_markBounds.inflate(40), Paint());

    final barPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.barTop, palette.barBottom],
      ).createShader(_markBounds)
      ..strokeWidth = 18
      ..strokeJoin = StrokeJoin.round;

    _paintPart(canvas, bottomBar, Offset(-70 * (1 - bottomBar), 0), () {
      canvas.drawPath(_bottomBarPath, barPaint..style = PaintingStyle.fill);
      canvas.drawPath(_bottomBarPath, barPaint..style = PaintingStyle.stroke);
    });
    _paintPart(canvas, topBar, Offset(70 * (1 - topBar), 0), () {
      canvas.drawPath(_topBarPath, barPaint..style = PaintingStyle.fill);
      canvas.drawPath(_topBarPath, barPaint..style = PaintingStyle.stroke);
    });

    final leafPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.leafTop, palette.leafBottom, palette.barBottom],
        stops: const [0, 0.7, 1],
      ).createShader(const Rect.fromLTRB(237, 322, 787, 775));
    final gapPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeJoin = StrokeJoin.round;

    _paintLeaf(canvas, _leftLeafPath, leftLeaf, 0.42, leafPaint, gapPaint);
    _paintLeaf(canvas, _rightLeafPath, rightLeaf, -0.42, leafPaint, gapPaint);
    if (centreLeaf > 0) {
      canvas.save();
      _growFromBase(canvas, centreLeaf, 0);
      canvas.drawPath(_centreGapPath, Paint()..blendMode = BlendMode.clear);
      canvas.drawPath(
        _centreLeafPath,
        Paint()
          ..shader = leafPaint.shader
          ..color = Color.fromRGBO(0, 0, 0, centreLeaf.clamp(0, 1)),
      );
      canvas.restore();
    }

    _paintSheen(canvas);
    canvas.restore(); // layer
    canvas.restore();
  }

  void _paintPart(
    Canvas canvas,
    double progress,
    Offset offset,
    VoidCallback draw,
  ) {
    if (progress <= 0) return;
    canvas.saveLayer(
      _markBounds.inflate(80),
      Paint()..color = Color.fromRGBO(0, 0, 0, progress.clamp(0, 1)),
    );
    canvas.translate(offset.dx, offset.dy);
    draw();
    canvas.restore();
  }

  /// Leaves grow from the shared base; side leaves also unfold outwards
  /// from [foldAngle] (radians, folded onto the centre leaf) to upright.
  void _growFromBase(Canvas canvas, double progress, double foldAngle) {
    canvas.translate(_leafBase.dx, _leafBase.dy);
    canvas.rotate(foldAngle * (1 - progress));
    final grow = 0.25 + 0.75 * progress;
    canvas.scale(math.max(0.001, 0.6 + 0.4 * progress), grow);
    canvas.translate(-_leafBase.dx, -_leafBase.dy);
  }

  void _paintLeaf(
    Canvas canvas,
    Path path,
    double progress,
    double foldAngle,
    Paint fill,
    Paint gap,
  ) {
    if (progress <= 0) return;
    canvas.save();
    _growFromBase(canvas, progress, foldAngle);
    canvas.drawPath(path, gap);
    canvas.saveLayer(
      _markBounds.inflate(80),
      Paint()..color = Color.fromRGBO(0, 0, 0, progress.clamp(0, 1)),
    );
    canvas.drawPath(path, Paint()..shader = fill.shader);
    canvas.restore();
    canvas.restore();
  }

  void _paintGlow(Canvas canvas, Offset centre, double radius) {
    if (glow <= 0) return;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.glow.withValues(alpha: 0.30 * glow),
            palette.glow.withValues(alpha: 0.10 * glow),
            palette.glow.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
  }

  /// One ring that leaves the mark as the leaves land.
  void _paintPulse(Canvas canvas, Offset centre, double markSide) {
    if (pulse <= 0 || pulse >= 1) return;
    final radius = markSide * (0.55 + 0.35 * pulse);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 4 * (1 - pulse)
        ..color = palette.glow.withValues(alpha: 0.45 * (1 - pulse)),
    );
  }

  /// A soft diagonal band of light that crosses the mark once.
  void _paintSheen(Canvas canvas) {
    if (sheen <= 0 || sheen >= 1) return;
    final travel = _markBounds.width + _markBounds.height;
    final x = _markBounds.left - _markBounds.height + travel * sheen;
    canvas.drawRect(
      _markBounds.inflate(40),
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.sheen.withValues(alpha: 0),
            palette.sheen.withValues(alpha: 0.55),
            palette.sheen.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(x, _markBounds.top, 260, 260)),
    );
  }

  @override
  bool shouldRepaint(IndiFitMarkPainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.markFraction != markFraction ||
      oldDelegate.glow != glow ||
      oldDelegate.bottomBar != bottomBar ||
      oldDelegate.topBar != topBar ||
      oldDelegate.centreLeaf != centreLeaf ||
      oldDelegate.leftLeaf != leftLeaf ||
      oldDelegate.rightLeaf != rightLeaf ||
      oldDelegate.pulse != pulse ||
      oldDelegate.sheen != sheen;
}
