import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/models/b02_execution_models.dart';
import 'r07c_workout_presentation.dart';

/// Short moments in the player (PREMIUM_REDESIGN_PLAN § 7): one pulse when a
/// rest runs out, and a one-second "exercise done" card between exercises.
///
/// Each beat runs on its own animation controller and calls [onDone] when it
/// ends, so nothing is left pending when the player goes away. Tapping a beat
/// ends it early. The player does not show beats under Reduce Motion.
abstract final class B02PlayerBeats {
  static const Duration restDone = Duration(milliseconds: 1400);
  static const Duration exerciseDone = Duration(milliseconds: 1000);
}

/// Shown in place of the rest timer for a moment after the countdown reaches
/// zero: the ring pulses once, then the beat fades. The rest-end haptic is
/// fired by RestPresenceService when the end is saved, not here.
class RestDoneBeat extends StatefulWidget {
  final String? upNextTitle;
  final VoidCallback onDone;

  const RestDoneBeat({super.key, required this.onDone, this.upNextTitle});

  @override
  State<RestDoneBeat> createState() => _RestDoneBeatState();
}

class _RestDoneBeatState extends State<RestDoneBeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: B02PlayerBeats.restDone,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.9,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 18,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.08,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 17,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
  ]).animate(_controller);
  late final Animation<double> _opacity = CurvedAnimation(
    parent: ReverseAnimation(_controller),
    curve: const Interval(0, 0.2),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(_finish);
  }

  var _finished = false;

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.b05Colors;
    final next = widget.upNextTitle;
    return Semantics(
      container: true,
      liveRegion: true,
      label: next == null ? 'Rest done' : 'Rest done. Up next, $next',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _finish,
          child: FadeTransition(
            opacity: _opacity,
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    ScaleTransition(
                      scale: _scale,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.action, width: 4),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 22,
                          color: colors.action,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rest done',
                            style: B05Typography.label(context),
                          ),
                          if (next != null)
                            Text(
                              next,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: B05Typography.caption(context),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Leg Press done · 3 × 8 · 60 kg", shown for a second after the last
/// planned set of an exercise is saved, before the next exercise slides in.
class ExerciseDoneBeat extends StatefulWidget {
  final String exerciseName;
  final String? summary;
  final bool newBest;
  final VoidCallback onDone;

  const ExerciseDoneBeat({
    super.key,
    required this.exerciseName,
    required this.onDone,
    this.summary,
    this.newBest = false,
  });

  @override
  State<ExerciseDoneBeat> createState() => _ExerciseDoneBeatState();
}

class _ExerciseDoneBeatState extends State<ExerciseDoneBeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: B02PlayerBeats.exerciseDone,
  );
  late final Animation<double> _scale = Tween(begin: 0.92, end: 1.0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.3, curve: Curves.easeOutBack),
    ),
  );

  var _finished = false;

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(_finish);
    // The set list is usually scrolled down to "Log set"; bring the beat,
    // which takes the set table's place, into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: B05MotionPolicy.transitionDuration(context),
        curve: B05MotionPolicy.standardCurve,
      );
    });
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final title = '${widget.exerciseName} done';
    return Semantics(
      container: true,
      liveRegion: true,
      button: true,
      onTapHint: 'Go to the next exercise',
      label: [
        title,
        ?widget.summary,
        if (widget.newBest) 'New best',
      ].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _finish,
          child: B05Surface(
            tone: B05SurfaceTone.raised,
            padding: const EdgeInsets.symmetric(
              horizontal: B05Layout.space16,
              vertical: B05Layout.space24,
            ),
            child: Column(
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: colors.action,
                  ),
                ),
                const SizedBox(height: B05Layout.space8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: B05Typography.title(context),
                ),
                if (widget.summary != null) ...[
                  const SizedBox(height: B05Layout.space4),
                  Text(
                    widget.summary!,
                    textAlign: TextAlign.center,
                    style: B05Typography.number(context),
                  ),
                ],
                if (widget.newBest) ...[
                  const SizedBox(height: B05Layout.space8),
                  Chip(
                    avatar: Icon(
                      Icons.emoji_events_rounded,
                      size: 18,
                      color: colors.action,
                    ),
                    label: const Text('New best'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "3 × 8 · 60 kg" from the working sets just logged. Mixed reps read
/// "3 sets · 24 reps"; mixed loads read "up to 62.5 kg". Unknown values are
/// left out rather than shown as zero.
String? b02ExerciseDoneSummary(List<B02PerformedSet> sets) {
  final working = sets
      .where((set) => set.role == B02SetRole.working)
      .toList(growable: false);
  if (working.isEmpty) return null;
  final reps = [
    for (final set in working)
      if (set.actualReps != null) set.actualReps!,
  ];
  final repsPart = reps.length != working.length
      ? '${working.length} ${working.length == 1 ? 'set' : 'sets'}'
      : reps.toSet().length == 1
      ? '${working.length} × ${reps.first}'
      : '${working.length} sets · ${reps.fold<int>(0, (a, b) => a + b)} reps';
  final loads = [
    for (final set in working)
      if (set.actualLoadKg != null) set.actualLoadKg!,
  ];
  final basis = working.first.actualLoadBasis;
  final sameBasis = working.every((set) => set.actualLoadBasis == basis);
  String? loadPart;
  if (sameBasis && basis == B02LoadBasis.bodyweight && loads.isEmpty) {
    loadPart = r07cFormatLoad(null, basis);
  } else if (sameBasis && loads.length == working.length) {
    final top = loads.reduce((a, b) => a > b ? a : b);
    final label = r07cFormatLoad(top, basis);
    loadPart = loads.toSet().length == 1 ? label : 'up to $label';
  }
  return [repsPart, ?loadPart].join(' · ');
}
