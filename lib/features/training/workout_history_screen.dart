import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_execution_compatibility_read_repository.dart';

final workoutHistoryItemsProvider =
    FutureProvider.autoDispose<List<B02ActivityHistoryItem>>((ref) {
      return B02ExecutionCompatibilityReadRepository(
        ref.watch(databaseProvider),
      ).readHistory(limit: 100);
    });

/// Shared workout-history destination for Progress and Training.
///
/// The screen reads the canonical B02 compatibility contract directly so a
/// Progress-only list cannot drift from the history shown by the rest of the
/// training experience. Legacy rows remain explicitly labelled.
class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryItemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Workout history')),
      body: history.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(B05Layout.space20),
          child: ConsumerStatusRow(
            label: 'Loading workout history',
            loading: true,
          ),
        ),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(B05Layout.space20),
            child: ProductFailureCard(
              failure: ProductFailurePresentation.fromCode(
                'progress_unavailable',
                title: 'Couldn’t load workout history',
              ),
              onRetry: () => ref.invalidate(workoutHistoryItemsProvider),
            ),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(B05Layout.space24),
                  child: Text('Complete a workout to start building history.'),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(B05Layout.space20),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: B05Layout.space8),
                itemBuilder: (context, index) => _WorkoutHistoryRow(
                  item: items[index],
                  onOpen: items[index].isCanonical
                      ? () => context.push(
                          items[index].activityType == B02ActivityType.strength
                              ? '/workout-history/${items[index].sessionId}'
                              : '/activity-history/${items[index].sessionId}',
                        )
                      : null,
                ),
              ),
      ),
    );
  }
}

class _WorkoutHistoryRow extends StatelessWidget {
  const _WorkoutHistoryRow({required this.item, this.onOpen});

  final B02ActivityHistoryItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final detail = _detailLabel(item);
    final source = _historyContextLabel(item);
    final status = item.isPartial ? 'Partially completed' : 'Completed';
    final date = ConsumerDateLabel.dateTime(item.completedAt);
    final row = B05Surface(
      tone: B05SurfaceTone.interactive,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fitness_center_rounded, color: context.b05Colors.action),
          const SizedBox(width: B05Layout.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: B05Typography.label(context)),
                const SizedBox(height: B05Layout.space4),
                Text(
                  '$date · ${_activityLabel(item.activityType)} · $source',
                  style: B05Typography.caption(context),
                ),
                const SizedBox(height: B05Layout.space4),
                Text(
                  '${_formatDuration(item.durationSeconds)} · $detail · $status',
                  style: B05Typography.caption(context),
                ),
              ],
            ),
          ),
          if (onOpen != null) ...[
            const SizedBox(width: B05Layout.space8),
            Icon(Icons.chevron_right_rounded, color: context.b05Colors.action),
          ],
        ],
      ),
    );
    return Semantics(
      button: onOpen != null,
      label: '${item.name}, $date, $source, $detail, $status.',
      child: onOpen == null
          ? row
          : InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(16),
              child: row,
            ),
    );
  }
}

String _historyContextLabel(B02ActivityHistoryItem item) {
  if (item.isLegacy) return 'Earlier workout';
  if (item.scheduledOccurrenceId != null) return 'Planned workout';
  if (item.activityType == B02ActivityType.strength) {
    // The canonical session schema does not distinguish Quick from manual
    // historical strength input. Keep that difference truthful instead of
    // guessing from a display name.
    return 'Independent workout';
  }
  return 'Logged activity';
}

String _activityLabel(B02ActivityType type) => switch (type) {
  B02ActivityType.strength => 'Strength',
  B02ActivityType.running => 'Running',
  B02ActivityType.cycling => 'Cycling',
  B02ActivityType.walking => 'Walking',
  B02ActivityType.yoga => 'Yoga',
  B02ActivityType.mobility => 'Mobility',
  B02ActivityType.legacy => 'Workout',
};

String _detailLabel(B02ActivityHistoryItem item) {
  if (item.isLegacy) {
    return item.legacySetCount > 0
        ? '${item.legacySetCount} recorded sets'
        : 'Details not available';
  }
  return switch (item.activityType) {
    B02ActivityType.strength =>
      '${item.performedExerciseCount} exercises · ${item.performedGroupCount} groups',
    B02ActivityType.running ||
    B02ActivityType.cycling ||
    B02ActivityType.walking =>
      item.hasCardioDetail
          ? '${item.cardioIntervalCount} intervals'
          : 'Cardio details are unavailable',
    B02ActivityType.yoga || B02ActivityType.mobility =>
      item.hasMobilityDetail
          ? 'Mobility detail'
          : 'Mobility details are unavailable',
    B02ActivityType.legacy => 'Details not available',
  };
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  if (remainder == 0) return '$minutes min';
  return '$minutes min ${remainder}s';
}
