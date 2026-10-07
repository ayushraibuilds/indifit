import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../progress/training_bests.dart';
import '../../progress/training_bests_providers.dart';

/// "New bests" on a saved workout: the top [visibleCount] in workout order,
/// then "and N more". Shows nothing while loading, on a failed read, or when
/// the workout set no bests.
class TrainingBestsSummaryBlock extends ConsumerWidget {
  const TrainingBestsSummaryBlock({
    super.key,
    required this.sessionId,
    this.visibleCount = 3,
  });

  final int sessionId;
  final int visibleCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bests =
        ref
            .watch(trainingBestsForSessionProvider(sessionId))
            .valueOrNull
            ?.bests ??
        const <TrainingBest>[];
    if (bests.isEmpty) return const SizedBox.shrink();
    final colors = context.b05Colors;
    final hidden = bests.length - visibleCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space16),
      child: B05Surface(
        key: const ValueKey('workout_summary_new_bests'),
        tone: B05SurfaceTone.inset,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: colors.success.indicator,
                  size: B05Layout.iconMedium,
                ),
                const SizedBox(width: B05Layout.space8),
                Expanded(
                  child: Text(
                    bests.length == 1 ? 'New best' : 'New bests',
                    style: B05Typography.title(context),
                  ),
                ),
              ],
            ),
            for (final best in bests.take(visibleCount)) ...[
              const SizedBox(height: B05Layout.space8),
              Semantics(
                label:
                    '${TrainingBestsCopy.semanticsLabel(best.kind)}, ${best.exerciseName}: ${TrainingBestsCopy.detail(best)}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        best.exerciseName,
                        style: B05Typography.label(context),
                      ),
                      Text(
                        TrainingBestsCopy.line(best),
                        style: B05Typography.body(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (hidden > 0) ...[
              const SizedBox(height: B05Layout.space8),
              Text('and $hidden more', style: B05Typography.caption(context)),
            ],
          ],
        ),
      ),
    );
  }
}
