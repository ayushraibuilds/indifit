import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_activity_session_repository.dart';
import 'b02_activity_controller.dart';

final b02ActivityHistoryDetailProvider = FutureProvider.autoDispose
    .family<B02TypedActivityHistoryRecord?, int>(
      (ref, sessionId) => ref
          .watch(b02ActivitySessionRepositoryProvider)
          .readTypedActivity(sessionId),
    );

/// Consumer-readable detail for a saved Other Activity record. It reads the
/// typed activity authority directly and does not expose storage names,
/// calories, or unsupported training metrics.
class B02ActivityHistoryDetailScreen extends ConsumerWidget {
  final int sessionId;

  const B02ActivityHistoryDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(b02ActivityHistoryDetailProvider(sessionId));
    return Scaffold(
      appBar: AppBar(title: const Text('Activity details')),
      body: record.when(
        loading: () => Center(
          child: Semantics(
            label: 'Loading activity details',
            child: CircularProgressIndicator(),
          ),
        ),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(B05Layout.space20),
            child: ProductFailureCard(
              failure: ProductFailurePresentation.fromCode(
                'history_unavailable',
                title: 'Activity details unavailable',
              ),
              onRetry: () =>
                  ref.invalidate(b02ActivityHistoryDetailProvider(sessionId)),
            ),
          ),
        ),
        data: (value) => value == null
            ? const Center(child: Text('Activity details unavailable.'))
            : _ActivityDetail(record: value),
      ),
    );
  }
}

class _ActivityDetail extends StatelessWidget {
  final B02TypedActivityHistoryRecord record;

  const _ActivityDetail({required this.record});

  @override
  Widget build(BuildContext context) {
    final detail = record.cardioDetail ?? record.mobilityDetail;
    final fields = <Widget>[
      _Fact(label: 'Activity', value: _activityLabel(record.activityType)),
      _Fact(
        label: 'Date',
        value: ConsumerDateLabel.dateTime(record.completedAtUtc.toLocal()),
      ),
      _Fact(label: 'Duration', value: _formatDuration(record.durationSeconds)),
    ];
    if (detail is B02CardioSessionDetail) {
      if (detail.distanceMetres != null) {
        fields.add(
          _Fact(label: 'Distance', value: '${detail.distanceMetres} m'),
        );
      }
      if (detail.intervals.isNotEmpty) {
        fields.add(
          _Fact(
            label: 'Intervals',
            value: '${detail.intervals.length} recorded',
          ),
        );
      }
    } else if (detail is B02MobilitySessionDetail) {
      if (detail.style != null) {
        fields.add(_Fact(label: 'Style', value: detail.style!));
      }
      if (detail.intensity != null) {
        fields.add(_Fact(label: 'Intensity', value: detail.intensity!));
      }
      if (detail.focusNote != null) {
        fields.add(_Fact(label: 'Focus', value: detail.focusNote!));
      }
    }
    return ListView(
      padding: const EdgeInsets.all(B05Layout.space20),
      children: [
        B05Surface(
          tone: B05SurfaceTone.selected,
          child: Semantics(
            container: true,
            label: '${record.name}, ${_activityLabel(record.activityType)}',
            child: Text(record.name, style: B05Typography.pageTitle(context)),
          ),
        ),
        const SizedBox(height: B05Layout.space12),
        B05Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                fields[index],
                if (index != fields.length - 1)
                  const Divider(height: B05Layout.space20),
              ],
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space16),
        Text(
          'This activity was logged manually. It is not a scheduled workout.',
          style: B05Typography.caption(
            context,
          ).copyWith(color: context.b05Colors.textSecondary),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;

  const _Fact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: B05Layout.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(label, style: B05Typography.caption(context)),
            ),
            Expanded(child: Text(value, style: B05Typography.label(context))),
          ],
        ),
      ),
    );
  }
}

String _activityLabel(B02ActivityType type) => switch (type) {
  B02ActivityType.running => 'Running',
  B02ActivityType.cycling => 'Cycling',
  B02ActivityType.walking => 'Walking',
  B02ActivityType.yoga => 'Yoga',
  B02ActivityType.mobility => 'Mobility',
  B02ActivityType.strength => 'Strength',
  B02ActivityType.legacy => 'Activity',
};

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  if (remainder == 0) return '$minutes min';
  return '$minutes min ${remainder}s';
}
