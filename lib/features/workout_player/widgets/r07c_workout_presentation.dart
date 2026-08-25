import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/models/b02_execution_models.dart';

/// Presentation-only helpers for the R07C execution and review surfaces.
///
/// These functions deliberately format only values already present in the
/// B02 contracts. They never turn an unknown load into zero or imply a load
/// basis that the execution boundary did not provide.
String r07cFormatNumber(num value) {
  final doubleValue = value.toDouble();
  if (doubleValue == doubleValue.roundToDouble()) {
    return doubleValue.toStringAsFixed(0);
  }
  return doubleValue.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

String r07cFormatLoad(double? loadKg, B02LoadBasis? basis) {
  if (basis == B02LoadBasis.bodyweight) return 'Bodyweight';
  if (loadKg == null) return '';
  return '${r07cFormatNumber(loadKg)} kg';
}

String r07cFormatPerformedSet(B02PerformedSet set) {
  final load = r07cFormatLoad(set.actualLoadKg, set.actualLoadBasis);
  final reps = set.actualReps;
  final main = switch ((load.isEmpty, reps)) {
    (true, null) => 'Set not recorded',
    (true, final value) => '$value ${value == 1 ? 'rep' : 'reps'}',
    (false, null) => load,
    (false, final value) => '$load × $value',
  };
  return [
    'Set ${set.ordinal + 1}',
    if (set.role == B02SetRole.warmup) 'Warm-up',
    main,
    if (set.actualRpe != null) 'RPE ${set.actualRpe}',
  ].join(' · ');
}

String? r07cFormatTarget({
  required double? loadKg,
  required B02LoadBasis? loadBasis,
  required int? minReps,
  required int? maxReps,
  required int? rpe,
}) {
  final load = r07cFormatLoad(loadKg, loadBasis);
  final reps = _formatRepRange(minReps, maxReps);
  if (load.isEmpty && reps == null && rpe == null) return null;
  return [
    if (load.isNotEmpty) load,
    reps,
    if (rpe != null) 'RPE $rpe',
  ].join(' × ');
}

String? r07cFormatLastPerformance({
  required double? loadKg,
  required B02LoadBasis? loadBasis,
  required int? reps,
  required int? rpe,
}) {
  final load = r07cFormatLoad(loadKg, loadBasis);
  if (load.isEmpty && reps == null && rpe == null) return null;
  return [
    if (load.isNotEmpty) load,
    if (reps != null) '$reps ${reps == 1 ? 'rep' : 'reps'}',
    if (rpe != null) 'RPE $rpe',
  ].join(' × ');
}

/// Broad 1–20 suggestions are the fallback used when Quick Workout has no
/// meaningful prescription. They are not useful enough to occupy the target
/// hierarchy, so the UI hides them until stronger evidence exists.
bool r07cHasUsefulTarget({
  required double? loadKg,
  required B02LoadBasis? loadBasis,
  required int? minReps,
  required int? maxReps,
  required int? rpe,
}) {
  if (loadKg != null || loadBasis == B02LoadBasis.bodyweight || rpe != null) {
    return true;
  }
  if (minReps == null && maxReps == null) return false;
  return !(minReps == 1 && (maxReps == null || maxReps == 20));
}

String? r07cFormatWarmupProposal(B02WarmupSetProposal proposal) {
  final load = r07cFormatLoad(proposal.loadKg, proposal.loadBasis);
  final reps = '${proposal.reps} ${proposal.reps == 1 ? 'rep' : 'reps'}';
  if (load.isEmpty) return reps;
  return '$load × $reps';
}

class R07CPerformedSetList extends StatelessWidget {
  const R07CPerformedSetList({
    required this.sets,
    super.key,
    this.title,
    this.isBusy = false,
    this.onEdit,
    this.onDelete,
  });

  final List<B02PerformedSet> sets;
  final String? title;
  final bool isBusy;
  final ValueChanged<B02PerformedSet>? onEdit;
  final ValueChanged<B02PerformedSet>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) return const SizedBox.shrink();
    final colors = context.b05Colors;
    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: B05Typography.label(context)),
            const SizedBox(height: 6),
          ],
          for (final set in sets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Semantics(
                label: 'Logged set ${r07cFormatPerformedSet(set)}',
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: colors.success.foreground,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r07cFormatPerformedSet(set),
                        style: B05Typography.body(
                          context,
                        ).copyWith(color: colors.textPrimary),
                      ),
                    ),
                    if (onEdit != null || onDelete != null) ...[
                      B05IconAction(
                        icon: Icons.edit_outlined,
                        label: 'Edit set ${set.ordinal + 1}',
                        hint: 'Change the logged load, reps, or RPE',
                        onPressed: isBusy ? null : () => onEdit?.call(set),
                      ),
                      B05IconAction(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete set ${set.ordinal + 1}',
                        hint: 'Remove this logged set from the workout',
                        onPressed: isBusy ? null : () => onDelete?.call(set),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class R07CMetricTile extends StatelessWidget {
  const R07CMetricTile({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: B05Typography.title(context)),
          const SizedBox(height: 2),
          Text(label, style: B05Typography.caption(context)),
        ],
      ),
    );
  }
}

String? _formatRepRange(int? minReps, int? maxReps) {
  if (minReps == null && maxReps == null) return null;
  final min = minReps ?? maxReps!;
  final max = maxReps ?? min;
  return min == max ? '$min reps' : '$min–$max reps';
}
