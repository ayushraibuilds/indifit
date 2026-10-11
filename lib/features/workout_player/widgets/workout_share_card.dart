import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../models/workout_completion_recap.dart';
import 'workout_payoff_widgets.dart';

/// The workout recap as a 1080 × 1920 story image (V6, PREMIUM_REDESIGN_PLAN
/// § 8.3), with a preview, a weights switch and a plain-text fallback.
///
/// Invariant: the image holds the workout only — no name, photo or other
/// personal data (decision 9) — and never an unbacked score.
class WorkoutShareCard extends StatefulWidget {
  final WorkoutCompletionRecap recap;

  const WorkoutShareCard({super.key, required this.recap});

  @override
  State<WorkoutShareCard> createState() => _WorkoutShareCardState();
}

class _WorkoutShareCardState extends State<WorkoutShareCard> {
  final _imageKey = GlobalKey();
  bool _includeWeights = true;
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final theme = Theme.of(context);
    final recap = widget.recap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Semantics(
              image: true,
              label:
                  'Share image preview. '
                  '${recap.generateShareText(includeWeights: _includeWeights)}',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: b05Radius(B05SurfaceRadius.large),
                  child: AspectRatio(
                    aspectRatio: WorkoutStoryCard.size.aspectRatio,
                    child: FittedBox(
                      child: RepaintBoundary(
                        key: _imageKey,
                        child: WorkoutStoryCard(
                          recap: recap,
                          includeWeights: _includeWeights,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: B05Layout.space12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Include weights in share',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: _includeWeights,
              onChanged: (val) => setState(() => _includeWeights = val),
            ),
          ],
        ),
        const SizedBox(height: B05Layout.space8),
        FilledButton.icon(
          key: const Key('workout_share_button'),
          onPressed: _sharing ? null : _shareImage,
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('Share image'),
        ),
        TextButton(
          key: const Key('workout_share_text_button'),
          onPressed: _shareText,
          child: const Text('Share as text'),
        ),
      ],
    );
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  void _shareText() {
    unawaited(
      Share.share(
        widget.recap.generateShareText(includeWeights: _includeWeights),
        sharePositionOrigin: _shareOrigin(),
      ),
    );
  }

  Future<void> _shareImage() async {
    setState(() => _sharing = true);
    try {
      final bytes = await renderWorkoutStoryPng(_imageKey);
      if (bytes == null) {
        _shareText();
        return;
      }
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: const ['indifit-workout.png'],
        sharePositionOrigin: _shareOrigin(),
      );
    } catch (error) {
      // The text recap carries the same facts.
      AppLogger.warning('Share image failed: $error', 'WorkoutShareCard');
      _shareText();
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

/// Renders the [RepaintBoundary] under [key] as a 1080 × 1920 PNG. Null when
/// it is not on screen.
Future<Uint8List?> renderWorkoutStoryPng(GlobalKey key) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(
    pixelRatio: WorkoutStoryCard.pixelSize.width / WorkoutStoryCard.size.width,
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// The story image itself, laid out at 360 × 640 and rendered at 3×. It
/// always uses the dark brand palette and ignores the app's text size, since
/// it is a picture, not UI.
class WorkoutStoryCard extends StatelessWidget {
  const WorkoutStoryCard({
    super.key,
    required this.recap,
    required this.includeWeights,
  });

  static const size = Size(360, 640);
  static const pixelSize = Size(1080, 1920);

  static const _ink = Color(0xFFF1F5F9);
  static const _muted = Color(0xFF94A3B8);
  static const _emerald = Color(0xFF34D399);
  static const _teal = Color(0xFF5EEAD4);

  final WorkoutCompletionRecap recap;
  final bool includeWeights;

  @override
  Widget build(BuildContext context) {
    final hero = workoutSummaryHeroNumber(
      totalLiftedKg: includeWeights ? recap.totalVolumeKg : 0,
      repCount: recap.totalRepsCount,
    );
    final stats = workoutSummaryStats(
      setCount: recap.completedSetsCount,
      repCount: hero?.isReps == true ? 0 : recap.totalRepsCount,
      durationLabel: recap.durationSeconds > 0
          ? formatStoryDuration(recap.durationSeconds)
          : null,
    );
    final bests = recap.bestsLine(includeWeights: includeWeights);
    final date = DateFormat('EEE d MMM').format(recap.completedAt.toLocal());
    const font = 'Outfit';

    return MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF060A12), Color(0xFF0A2620), Color(0xFF0D3B35)],
              stops: [0, 0.6, 1],
            ),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.1),
                radius: 0.8,
                colors: [Color(0x3334D399), Color(0x0034D399)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: font,
                  color: _ink,
                  fontFeatures: [ui.FontFeature.tabularFigures()],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/branding/indifit_mark.png',
                          width: 28,
                          height: 28,
                          errorBuilder: (_, _, _) =>
                              const SizedBox(width: 28, height: 28),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'IndiFit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(flex: 3),
                    Icon(
                      recap.isPartial
                          ? Icons.check_circle_outline_rounded
                          : Icons.check_circle_rounded,
                      color: _emerald,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${recap.isPartial ? 'Workout partially completed' : 'Workout complete'} · $date',
                      style: const TextStyle(fontSize: 13, color: _muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recap.workoutTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (hero != null) ...[
                      const SizedBox(height: 28),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [_emerald, _teal],
                          ).createShader(bounds),
                          child: Text(
                            hero.format(hero.value),
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        hero.label.toLowerCase(),
                        style: const TextStyle(fontSize: 16, color: _muted),
                      ),
                    ],
                    if (stats.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          for (final stat in stats)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stat.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    stat.label.toLowerCase(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (bests != null) ...[
                      const SizedBox(height: 24),
                      Row(
                        key: const Key('workout_share_bests_line'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            size: 18,
                            color: _emerald,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bests,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(flex: 4),
                    const Text(
                      'Tracked with IndiFit',
                      style: TextStyle(fontSize: 13, color: _muted),
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

/// "1:22" or "1:05:09": the stopwatch form fits one third of the story row.
String formatStoryDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest'
      : '$minutes:$rest';
}
