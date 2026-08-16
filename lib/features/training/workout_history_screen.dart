import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
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
        loading: () => Center(
          child: Semantics(
            label: 'Loading workout history',
            child: CircularProgressIndicator(),
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
                itemBuilder: (context, index) =>
                    _WorkoutHistoryRow(item: items[index]),
              ),
      ),
    );
  }
}

class _WorkoutHistoryRow extends StatelessWidget {
  const _WorkoutHistoryRow({required this.item});

  final B02ActivityHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final detail = _detailLabel(item);
    // Legacy rows keep a short provenance note; current rows need no label.
    final source = item.isLegacy ? 'Earlier workout' : null;
    final date = ConsumerDateLabel.dateTime(item.completedAt);
    return Semantics(
      label:
          '${item.name}, $date${source == null ? '' : ', $source'}, $detail.',
      child: B05Surface(
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
                    '$date · ${_activityLabel(item.activityType)}',
                    style: B05Typography.caption(context),
                  ),
                  const SizedBox(height: B05Layout.space4),
                  Text(detail, style: B05Typography.caption(context)),
                  if (source != null) ...[
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      source,
                      style: B05Typography.caption(
                        context,
                      ).copyWith(color: context.b05Colors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          : 'Cardio detail not available yet',
    B02ActivityType.yoga || B02ActivityType.mobility =>
      item.hasMobilityDetail
          ? 'Mobility detail'
          : 'Mobility detail not available yet',
    B02ActivityType.legacy => 'Details not available',
  };
}
