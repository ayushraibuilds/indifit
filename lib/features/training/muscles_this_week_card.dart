import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fixtures/exercise_display_muscles.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../media/indifit_muscle_map.dart';
import 'muscles_this_week.dart';

/// "Muscles this week" on Training (TF-4, free): a front/back map shaded by
/// working sets, the rule as its legend, and the counts as a list so the
/// shading is never the only signal. Tapping a muscle shows its count and
/// the exercises that hit it.
class MusclesThisWeekCard extends ConsumerStatefulWidget {
  const MusclesThisWeekCard({super.key});

  @override
  ConsumerState<MusclesThisWeekCard> createState() =>
      _MusclesThisWeekCardState();
}

class _MusclesThisWeekCardState extends ConsumerState<MusclesThisWeekCard> {
  String? _selected;

  void _select(String muscle) =>
      setState(() => _selected = _selected == muscle ? null : muscle);

  @override
  Widget build(BuildContext context) {
    // Hidden while loading or unreadable; the rest of the week still shows.
    final counts = ref.watch(musclesThisWeekProvider).valueOrNull;
    if (counts == null) return const SizedBox.shrink();
    final colors = context.b05Colors;
    final selected = counts.sets.containsKey(_selected) ? _selected : null;
    return B05Surface(
      key: const ValueKey('muscles_this_week'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Muscles this week', style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space12),
          IndiFitMuscleMap.sets(
            setCounts: counts.sets,
            onMuscleTap: counts.isEmpty ? null : _select,
          ),
          const SizedBox(height: B05Layout.space12),
          if (counts.isEmpty)
            Text(
              'Train this week to fill your muscle-group map',
              textAlign: TextAlign.center,
              style: B05Typography.body(context),
            )
          else ...[
            Text(MuscleSetRule.legend, style: B05Typography.caption(context)),
            const SizedBox(height: B05Layout.space8),
            const IndiFitMuscleMapLegend(),
            if (selected != null) ...[
              const SizedBox(height: B05Layout.space12),
              _MuscleDetail(
                muscle: selected,
                sets: counts.sets[selected]!,
                exercises: counts.exercises[selected] ?? const [],
              ),
            ],
            const SizedBox(height: B05Layout.space12),
            for (final entry in counts.ranked)
              MergeSemantics(
                child: InkWell(
                  key: ValueKey('muscle_count_${entry.key}'),
                  borderRadius: B05Radii.rowRadius,
                  onTap: () => _select(entry.key),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: B05Layout.minTouchTarget,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ExerciseDisplayMuscles.formatMuscle(entry.key),
                            style: B05Typography.body(context).copyWith(
                              fontWeight: entry.key == selected
                                  ? FontWeight.w700
                                  : null,
                            ),
                          ),
                        ),
                        Text(
                          '${IndiFitMuscleMap.formatSets(entry.value)} '
                          '${entry.value == 1 ? 'set' : 'sets'}',
                          style: B05Typography.body(
                            context,
                          ).copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MuscleDetail extends StatelessWidget {
  const _MuscleDetail({
    required this.muscle,
    required this.sets,
    required this.exercises,
  });

  final String muscle;
  final double sets;
  final List<String> exercises;

  @override
  Widget build(BuildContext context) {
    return B05Surface(
      key: const ValueKey('muscle_detail'),
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.all(B05Layout.space12),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ExerciseDisplayMuscles.formatMuscle(muscle)} group · '
              '${IndiFitMuscleMap.formatSets(sets)} working '
              '${sets == 1 ? 'set' : 'sets'}',
              style: B05Typography.label(context),
            ),
            if (exercises.isNotEmpty) ...[
              const SizedBox(height: B05Layout.space4),
              Text(exercises.join(', '), style: B05Typography.body(context)),
            ],
          ],
        ),
      ),
    );
  }
}
