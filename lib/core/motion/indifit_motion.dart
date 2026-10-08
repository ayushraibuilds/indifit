import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../widgets/b05_accessibility_primitives.dart';

/// Shared motion presets (PREMIUM_REDESIGN_PLAN § 5).
///
/// Every preset reads [B05MotionPolicy.reduceMotion]; under Reduce Motion it
/// shows the final state on the first frame and starts no ticker. Delays are
/// part of the animation controller, never timers, so nothing is left
/// pending when a widget goes away.
abstract final class IndiFitMotion {
  static const Duration enterDuration = B05MotionPolicy.standardDuration;
  static const double enterOffset = 8;
  static const Duration staggerStep = Duration(milliseconds: 40);
  static const int staggerLimit = 6;
  static const Duration countUpDuration = B05MotionPolicy.completionDuration;
  static const Duration popDuration = Duration(milliseconds: 220);
  static const Duration morphDuration = Duration(milliseconds: 300);
  static const Duration sharedAxisDuration = Duration(milliseconds: 300);

  /// How long a success state (for example the Add → tick) stays visible.
  static const Duration successHold = Duration(milliseconds: 900);

  /// A quick spring with a little overshoot, for pops and the success tick.
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 28,
  );

  /// [spring] as a curve over [duration]; it always ends exactly at 1.
  static Curve springCurve(Duration duration) =>
      _SpringCurve(duration.inMicroseconds / Duration.microsecondsPerSecond);

  /// Wraps the first [staggerLimit] children in [IndiFitEnter], each
  /// [staggerStep] after the previous one. Later children appear at once.
  static List<Widget> stagger(List<Widget> children) => [
    for (var index = 0; index < children.length; index++)
      index < staggerLimit
          ? IndiFitEnter(delay: staggerStep * index, child: children[index])
          : children[index],
  ];
}

class _SpringCurve extends Curve {
  _SpringCurve(this.seconds)
    : _simulation = SpringSimulation(IndiFitMotion.spring, 0, 1, 0);

  final double seconds;
  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) => _simulation.x(t * seconds);
}

/// Fades in and rises [IndiFitMotion.enterOffset] on first build only.
class IndiFitEnter extends StatefulWidget {
  const IndiFitEnter({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.enabled = true,
  });

  final Widget child;
  final Duration delay;

  /// False shows [child] as is, for content that was already on screen.
  final bool enabled;

  @override
  State<IndiFitEnter> createState() => _IndiFitEnterState();
}

class _IndiFitEnterState extends State<IndiFitEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + IndiFitMotion.enterDuration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds / _controller.duration!.inMicroseconds,
      1,
      curve: B05MotionPolicy.standardCurve,
    ),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.enabled || B05MotionPolicy.reduceMotion(context)) {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      // The wrapper stays in the tree after the animation ends; swapping it
      // for the bare child would remount the subtree and reset its state.
      builder: (context, child) {
        final t = _progress.value;
        return Opacity(
          opacity: t,
          // Screen readers see the content from the first frame.
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, IndiFitMotion.enterOffset * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Shows [value] through [builder] and tweens from the previous value when it
/// changes. The first build shows the value as is, so a screen never counts
/// up from zero when it opens. Use tabular figures in the builder.
class IndiFitCountUp extends StatefulWidget {
  const IndiFitCountUp({required this.value, required this.builder, super.key});

  final double value;
  final Widget Function(BuildContext context, double value) builder;

  @override
  State<IndiFitCountUp> createState() => _IndiFitCountUpState();
}

class _IndiFitCountUpState extends State<IndiFitCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: IndiFitMotion.countUpDuration,
    value: 1,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: B05MotionPolicy.standardCurve,
  );
  late double _from = widget.value;
  late double _to = widget.value;

  double get _current => _from + (_to - _from) * _progress.value;

  @override
  void didUpdateWidget(IndiFitCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _to) return;
    if (B05MotionPolicy.reduceMotion(context)) {
      _from = _to = widget.value;
      _controller.value = 1;
      return;
    }
    _from = _current;
    _to = widget.value;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) =>
          widget.builder(context, _controller.isAnimating ? _current : _to),
    );
  }
}

/// Cross-fades [child] to [successChild] while [success] is true; the
/// success content springs in from 90 % scale. The caller owns the timing
/// (see [IndiFitMotion.successHold]) and fires the haptic after saving.
class IndiFitSuccessMorph extends StatelessWidget {
  const IndiFitSuccessMorph({
    required this.success,
    required this.child,
    required this.successChild,
    super.key,
  });

  final bool success;
  final Widget child;
  final Widget successChild;

  @override
  Widget build(BuildContext context) {
    final spring = IndiFitMotion.springCurve(IndiFitMotion.morphDuration);
    return AnimatedSwitcher(
      duration: B05MotionPolicy.transitionDuration(
        context,
        standard: IndiFitMotion.morphDuration,
      ),
      transitionBuilder: (child, animation) {
        final isSuccess = child.key == const ValueKey('indifit-success');
        return FadeTransition(
          opacity: animation,
          child: isSuccess
              ? ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.9,
                    end: 1,
                  ).animate(CurvedAnimation(parent: animation, curve: spring)),
                  child: child,
                )
              : child,
        );
      },
      child: success
          ? KeyedSubtree(
              key: const ValueKey('indifit-success'),
              child: successChild,
            )
          : KeyedSubtree(key: const ValueKey('indifit-idle'), child: child),
    );
  }
}

/// Scales [child] from 92 % to full size with [IndiFitMotion.spring] when
/// it first appears and whenever [trigger] changes.
class IndiFitPop extends StatefulWidget {
  const IndiFitPop({required this.child, super.key, this.trigger});

  final Widget child;
  final Object? trigger;

  @override
  State<IndiFitPop> createState() => _IndiFitPopState();
}

class _IndiFitPopState extends State<IndiFitPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: IndiFitMotion.popDuration,
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.92, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: IndiFitMotion.springCurve(IndiFitMotion.popDuration),
        ),
      );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(IndiFitPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _play();
  }

  void _play() {
    if (B05MotionPolicy.reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Slides between pages that share a horizontal axis, such as exercises in
/// the player. Give each page a distinct key; set [reverse] when moving back.
class IndiFitSharedAxisSwitcher extends StatelessWidget {
  const IndiFitSharedAxisSwitcher({
    required this.child,
    super.key,
    this.reverse = false,
  });

  final Widget child;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      reverse: reverse,
      duration: B05MotionPolicy.transitionDuration(
        context,
        standard: IndiFitMotion.sharedAxisDuration,
      ),
      layoutBuilder: (entries) =>
          Stack(alignment: Alignment.topCenter, children: entries),
      transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
        animation: primary,
        secondaryAnimation: secondary,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: Colors.transparent,
        child: child,
      ),
      child: child,
    );
  }
}
