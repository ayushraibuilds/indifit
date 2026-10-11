import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion/device_tilt.dart';
import '../../../core/services/achievement_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// Badge art (Fluent Emoji 3D, MIT; see assets/badges/SOURCE.md) for each
/// achievement id. Ids without art fall back to the achievement's icon.
const Set<String> kBadgeArtIds = {
  'first_workout',
  'streak_7',
  'streak_30',
  'volume_1000',
  'volume_5000',
  'volume_10000',
  'meals_10',
  'meals_50',
  'first_thali',
};

String? badgeArtAsset(String achievementId) =>
    kBadgeArtIds.contains(achievementId)
    ? 'assets/badges/$achievementId.png'
    : null;

/// A source of device lean in radians; tests pass their own.
typedef BadgeTiltSource = Stream<Offset> Function();

Stream<Offset> _defaultTilt() =>
    deviceTiltStream(maxRadians: BadgeMedal.maxTilt);

/// Saturation 0 with the luminance kept: the matte silhouette of a locked
/// badge.
const ColorFilter _lockedFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// One achievement's medal (PREMIUM_REDESIGN_PLAN § 8.4).
///
/// Unlocked badges show the full-colour art. Locked badges show the same art
/// desaturated and dimmed. With [tilt], an unlocked badge leans up to ±10°
/// with the phone while its route is current. With [sheen], a light band
/// sweeps across an unlocked badge once when it first appears. Under Reduce
/// Motion there is no tilt and no sheen, and the badge is final on frame one.
///
/// The art is decorative: callers provide the semantics label.
class BadgeMedal extends StatefulWidget {
  const BadgeMedal({
    required this.achievement,
    super.key,
    this.size = 48,
    this.tilt = false,
    this.sheen = false,
    this.tiltSource,
  }) : assert(size <= maxSize, 'Fluent 3D art is 256 px: sharp to 85 pt.');

  final Achievement achievement;
  final double size;
  final bool tilt;
  final bool sheen;
  final BadgeTiltSource? tiltSource;

  /// 256 px art stays sharp up to about 85 pt at @3x.
  static const double maxSize = 85;

  /// The furthest a badge leans either way: 10°.
  static const double maxTilt = 10 * math.pi / 180;

  /// How long the unlock sheen takes to cross the badge.
  static const Duration sheenDuration = Duration(milliseconds: 900);

  @override
  State<BadgeMedal> createState() => _BadgeMedalState();
}

class _BadgeMedalState extends State<BadgeMedal>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _tilt = ValueNotifier<Offset>(Offset.zero);
  StreamSubscription<Offset>? _tiltSubscription;
  AnimationController? _sheen;
  var _resumed = true;
  var _sheenStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTilt();
    _startSheenOnce();
  }

  @override
  void didUpdateWidget(BadgeMedal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTilt();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncTilt();
  }

  bool get _unlocked => widget.achievement.isUnlocked;

  void _syncTilt() {
    final route = ModalRoute.of(context);
    final wanted =
        widget.tilt &&
        _unlocked &&
        _resumed &&
        (route?.isCurrent ?? true) &&
        !B05MotionPolicy.reduceMotion(context);
    if (wanted && _tiltSubscription == null) {
      _tiltSubscription = (widget.tiltSource ?? _defaultTilt)().listen(
        (value) => _tilt.value = value,
        // No sensor: the badge simply stays level.
        onError: (Object _) => _stopTilt(),
        cancelOnError: true,
      );
    } else if (!wanted) {
      _stopTilt();
    }
  }

  void _stopTilt() {
    unawaited(_tiltSubscription?.cancel());
    _tiltSubscription = null;
    _tilt.value = Offset.zero;
  }

  void _startSheenOnce() {
    if (_sheenStarted) return;
    _sheenStarted = true;
    if (!widget.sheen || !_unlocked || B05MotionPolicy.reduceMotion(context)) {
      return;
    }
    _sheen =
        AnimationController(vsync: this, duration: BadgeMedal.sheenDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) setState(() {});
          })
          ..forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_tiltSubscription?.cancel());
    _tilt.dispose();
    _sheen?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget art = _art(context);

    if (!_unlocked) {
      art = Opacity(
        opacity: 0.45,
        child: ColorFiltered(colorFilter: _lockedFilter, child: art),
      );
    }

    final sheen = _sheen;
    if (sheen != null && !sheen.isCompleted) {
      art = AnimatedBuilder(
        animation: sheen,
        child: art,
        builder: (context, child) => ShaderMask(
          key: const Key('badge_medal_sheen'),
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // A soft white band from the top-left corner to the bottom-right.
            final t = -1 + sheen.value * 3;
            return LinearGradient(
              begin: Alignment(t - 1, t - 1),
              end: Alignment(t + 1, t + 1),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x8CFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        ),
      );
    }

    if (widget.tilt) {
      art = ValueListenableBuilder<Offset>(
        valueListenable: _tilt,
        child: art,
        builder: (context, lean, child) => Transform(
          key: const Key('badge_medal_tilt'),
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateX(lean.dy)
            ..rotateY(lean.dx),
          child: child,
        ),
      );
    }

    return ExcludeSemantics(
      child: SizedBox.square(dimension: widget.size, child: art),
    );
  }

  Widget _art(BuildContext context) {
    final path = badgeArtAsset(widget.achievement.id);
    if (path == null) return _fallback(context);
    return Image.asset(
      path,
      key: Key('badge_medal_art_${widget.achievement.id}'),
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, _, _) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    final achievement = widget.achievement;
    return Icon(
      achievement.icon,
      size: widget.size * 0.7,
      color: _unlocked ? achievement.color : context.b05Colors.textDisabled,
    );
  }
}
