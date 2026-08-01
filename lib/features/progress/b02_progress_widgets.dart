import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/b02_execution_models.dart';
import '../../data/models/b02_muscle_volume_models.dart';
import '../../data/models/b02_progress_read_models.dart';
import 'b02_progress_controller.dart';

/// B02 progress read models rendered on the existing Progress surface. The
/// widget only formats values and chooses explicit empty/unknown states; it
/// does not query Drift or calculate volume, coverage, or recommendations.
class B02ProgressOverview extends ConsumerWidget {
  const B02ProgressOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(b02ProgressControllerProvider);
    final data = state.data;
    if (state.status == B02ProgressStatus.failure && data == null) {
      return _B02ProgressFailureCard(
        message: state.issues.isEmpty
            ? 'Progress data is unavailable.'
            : state.issues.first,
        onRetry: () => ref.read(b02ProgressControllerProvider.notifier).retry(),
      );
    }
    if (data == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.status == B02ProgressStatus.loading)
          const LinearProgressIndicator(minHeight: 2),
        if (state.status == B02ProgressStatus.partial ||
            state.status == B02ProgressStatus.recovery)
          _B02ProgressIssueBanner(
            status: state.status,
            issues: state.issues,
            onRetry: () =>
                ref.read(b02ProgressControllerProvider.notifier).retry(),
          ),
        Text(
          'Read range: ${data.query.startLocalDate} – ${data.query.endLocalDate} · ${data.query.timezoneId}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        B02ProgressActivityHistoryCard(records: data.activityHistory),
        const SizedBox(height: 12),
        B02ProgressGroupHistoryCard(records: data.groupHistory),
        const SizedBox(height: 12),
        B02ProgressTargetEvidenceCard(records: data.targetEvidence),
        const SizedBox(height: 12),
        B02ProgressMuscleHeatMapCard(readModel: data.muscleVolume),
      ],
    );
  }
}

class B02ProgressActivityHistoryCard extends StatelessWidget {
  final List<B02ProgressActivityRecord>? records;

  const B02ProgressActivityHistoryCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    return _B02ReadCard(
      title: 'Activity history',
      subtitle:
          'Date range and modality are taken from persisted activity rows.',
      child: records == null
          ? const _B02Unavailable(label: 'Activity history')
          : records!.isEmpty
          ? const _B02Empty(label: 'No activity in this date range.')
          : Column(
              children: [
                for (final record in records!.take(8))
                  _ActivityRow(record: record),
              ],
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final B02ProgressActivityRecord record;

  const _ActivityRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = record.isLegacy
        ? 'Legacy B01 projection · ${record.legacySetCount} sets'
        : switch (record.activityType) {
            B02ActivityType.strength =>
              '${record.performedExerciseCount} exercises · ${record.performedGroupCount} groups',
            B02ActivityType.running ||
            B02ActivityType.cycling ||
            B02ActivityType.walking =>
              record.hasCardioDetail
                  ? '${record.cardioIntervalCount} intervals · cardio detail'
                  : 'Cardio detail unavailable',
            B02ActivityType.yoga || B02ActivityType.mobility =>
              record.hasMobilityDetail
                  ? 'Mobility detail'
                  : 'Mobility detail unavailable',
            B02ActivityType.legacy => 'Legacy B01 projection',
          };
    final source = record.isLegacy
        ? 'Legacy'
        : switch (record.source) {
            B02ActivitySource.manual => 'Manual',
            B02ActivitySource.healthImport => 'Health import',
            null => 'Source unknown',
          };
    return Semantics(
      label:
          '${record.name}, ${_activityLabel(record.activityType)}, $source, $detail',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(record.name),
        subtitle: Text(
          '${_activityLabel(record.activityType)} · ${_dateLabel(record.completedAtUtc)}\n$detail',
        ),
        trailing: Chip(
          label: Text(source),
          visualDensity: VisualDensity.compact,
          labelStyle: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}

class B02ProgressGroupHistoryCard extends StatelessWidget {
  final List<B02ProgressGroupHistory>? records;

  const B02ProgressGroupHistoryCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    return _B02ReadCard(
      title: 'Group history',
      subtitle: 'Supersets, circuits, and giant sets retain member status.',
      child: records == null
          ? const _B02Unavailable(label: 'Group history')
          : records!.isEmpty
          ? const _B02Empty(
              label: 'No grouped strength activity in this range.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in records!.take(8)) _GroupRow(group: group),
              ],
            ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final B02ProgressGroupHistory group;

  const _GroupRow({required this.group});

  @override
  Widget build(BuildContext context) {
    final members = group.members.isEmpty
        ? 'Members unavailable'
        : group.members
              .map(
                (member) => member.wasSubstituted
                    ? '${member.actualExerciseName} (substituted)'
                    : member.actualExerciseName,
              )
              .join(' · ');
    final rounds = '${group.completedRounds}/${group.plannedRounds} rounds';
    return Semantics(
      label:
          '${group.label ?? _groupLabel(group.groupType)}, $rounds, $members',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(group.label ?? _groupLabel(group.groupType)),
        subtitle: Text(
          '${_groupLabel(group.groupType)} · ${_dateLabel(group.completedAtUtc)}\n$members',
        ),
        trailing: Text(rounds),
      ),
    );
  }
}

class B02ProgressTargetEvidenceCard extends StatelessWidget {
  final List<B02ProgressTargetEvidence>? records;

  const B02ProgressTargetEvidenceCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    return _B02ReadCard(
      title: 'Target evidence',
      subtitle:
          'Frozen rule version, confidence, and explanation are shown as recorded.',
      child: records == null
          ? const _B02Unavailable(label: 'Target evidence')
          : records!.isEmpty
          ? const _B02Empty(
              label: 'No canonical strength target evidence in this range.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final record in records!.take(8))
                  _TargetRow(record: record),
              ],
            ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  final B02ProgressTargetEvidence record;

  const _TargetRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final recommendation = record.recommendation;
    final explanation = recommendation == null
        ? 'No target evidence recorded'
        : '${recommendation.confidence.dbValue} confidence · ${recommendation.ruleVersion} · ${recommendation.comparatorCount} comparators';
    final rationale = recommendation?.rationaleCodes.join(', ');
    final target = recommendation == null
        ? 'Target unavailable'
        : _targetLabel(recommendation);
    return Semantics(
      label: '${record.actualExerciseName}, $target, $explanation',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(record.actualExerciseName),
        subtitle: Text(
          '${_dateLabel(record.completedAtUtc)} · $explanation'
          '${rationale == null ? '' : '\nWhy: $rationale'}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(target),
            if (record.wasOverridden)
              const Text('User override', style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class B02ProgressMuscleHeatMapCard extends StatelessWidget {
  final B02MuscleVolumeReadModel? readModel;

  const B02ProgressMuscleHeatMapCard({super.key, required this.readModel});

  @override
  Widget build(BuildContext context) {
    final model = readModel;
    return _B02ReadCard(
      title: 'Weekly muscle sets',
      subtitle: model == null
          ? 'Metric: working-set units; effective evidence unavailable.'
          : 'Metric: working-set units; effective evidence when target-backed · '
                '${model.startLocalDate} – ${model.endLocalDate} · ${model.timezoneId}',
      child: model == null
          ? const _B02Unavailable(label: 'Muscle volume')
          : model.isEmpty
          ? const _B02Empty(
              label: 'No canonical working sets in this date range.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CoverageSummary(model: model),
                const SizedBox(height: 12),
                if (model.muscles.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cell in model.muscles) _MuscleCell(cell: cell),
                    ],
                  ),
                if (model.unknown.hasUnknownCoverage) ...[
                  const SizedBox(height: 12),
                  _UnknownSummary(unknown: model.unknown),
                ],
                if (model.hasLegacyCoverage) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Legacy history: ${model.legacySetCount} sets are count-only and excluded from mapped muscle allocation.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
    );
  }
}

class _CoverageSummary extends StatelessWidget {
  final B02MuscleVolumeReadModel model;

  const _CoverageSummary({required this.model});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Working sets: ${model.totalWorkingSetCount} · mapped: ${model.mappedWorkingSetCount} '
      '(${_coverageLabel(model.mappingCoverage)}) · effective evidence: ${_coverageLabel(model.effectiveEvidenceCoverage)}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _MuscleCell extends StatelessWidget {
  final B02MuscleVolumeCell cell;

  const _MuscleCell({required this.cell});

  @override
  Widget build(BuildContext context) {
    final effective = cell.effectiveSetUnits == null
        ? 'Unknown'
        : _number(cell.effectiveSetUnits!);
    return Semantics(
      label:
          '${cell.displayName}: ${_number(cell.workingSetUnits)} working set units; effective evidence $effective',
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cell.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text('${_number(cell.workingSetUnits)} working'),
            Text('$effective effective'),
          ],
        ),
      ),
    );
  }
}

class _UnknownSummary extends StatelessWidget {
  final B02MuscleVolumeUnknown unknown;

  const _UnknownSummary({required this.unknown});

  @override
  Widget build(BuildContext context) {
    final effective = unknown.effectiveSetUnits == null
        ? 'Unknown'
        : _number(unknown.effectiveSetUnits!);
    return Semantics(
      label:
          'Unknown muscle mapping: ${_number(unknown.workingSetUnits)} working set units; effective evidence $effective',
      child: Text(
        'Unknown mapping: ${unknown.workingSetCount} working sets · ${_number(unknown.workingSetUnits)} working units · effective $effective',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _B02ReadCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _B02ReadCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _B02Empty extends StatelessWidget {
  final String label;

  const _B02Empty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _B02Unavailable extends StatelessWidget {
  final String label;

  const _B02Unavailable({required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label unavailable',
      child: Text(
        '$label unavailable · retry to load this metric.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _B02ProgressFailureCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _B02ProgressFailureCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Progress data could not be loaded.'),
            const SizedBox(height: 6),
            Text(message),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onRetry, child: const Text('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _B02ProgressIssueBanner extends StatelessWidget {
  final B02ProgressStatus status;
  final List<String> issues;
  final VoidCallback onRetry;

  const _B02ProgressIssueBanner({
    required this.status,
    required this.issues,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final title = status == B02ProgressStatus.recovery
        ? 'Showing the last known progress while recovery is attempted.'
        : 'Some progress metrics are incomplete.';
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$title ${issues.join(' ')}',
                semanticsLabel: '$title ${issues.join(' ')}',
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
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
  B02ActivityType.legacy => 'Legacy workout',
};

String _groupLabel(B02GroupType type) => switch (type) {
  B02GroupType.superset => 'Superset',
  B02GroupType.circuit => 'Circuit',
  B02GroupType.giantSet => 'Giant set',
};

String _dateLabel(DateTime value) {
  final utc = value.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')}';
}

String _number(double value) => value.toStringAsFixed(1);

String _coverageLabel(double? coverage) =>
    coverage == null ? 'Unknown' : '${(coverage * 100).round()}%';

String _targetLabel(B02TargetRecommendation recommendation) {
  final load = recommendation.recommendedLoadKg == null
      ? 'load unknown'
      : '${_number(recommendation.recommendedLoadKg!)} kg';
  final reps = recommendation.targetRepsMin == null
      ? 'reps unknown'
      : recommendation.targetRepsMax == null
      ? '${recommendation.targetRepsMin} reps'
      : '${recommendation.targetRepsMin}–${recommendation.targetRepsMax} reps';
  return '$load · $reps';
}
