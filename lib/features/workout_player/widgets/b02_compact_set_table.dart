import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/theme/indifit_icons.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/responsive_form_primitives.dart';
import '../../../data/models/b02_execution_models.dart';
import '../../progress/training_bests.dart';
import 'b02_execution_semantics.dart';
import 'r07c_workout_presentation.dart';

/// The presentation contract for one compact execution row.
///
/// It contains only facts already held by the B02 slot or performed-set
/// models. It does not calculate targets, mutate drafts, or decide whether a
/// set is valid.
@immutable
class B02CompactSetRow {
  const B02CompactSetRow({
    required this.id,
    required this.displayNumber,
    required this.isLogged,
    required this.isExtra,
    required this.role,
    this.plannedLoadKg,
    this.plannedLoadBasis,
    this.plannedRepsMin,
    this.plannedRepsMax,
    this.plannedRpe,
    this.actualLoadKg,
    this.actualLoadBasis,
    this.actualReps,
    this.actualRpe,
    this.plannedTechnique,
    this.actualTechnique,
    this.performedSet,
    this.previousLabel,
  });

  factory B02CompactSetRow.fromLoggedSet({
    required B02PerformedSet set,
    required int displayNumber,
    required bool isExtra,
  }) {
    return B02CompactSetRow(
      id: set.id,
      displayNumber: displayNumber,
      isLogged: true,
      isExtra: isExtra,
      role: set.role,
      plannedLoadKg: set.targetLoadKg,
      plannedLoadBasis: set.targetLoadBasis,
      plannedRepsMin: set.targetRepsMin,
      plannedRepsMax: set.targetRepsMax,
      plannedRpe: set.targetRpe,
      actualLoadKg: set.actualLoadKg,
      actualLoadBasis: set.actualLoadBasis,
      actualReps: set.actualReps,
      actualRpe: set.actualRpe,
      actualTechnique: set.technique,
      performedSet: set,
    );
  }

  factory B02CompactSetRow.fromPlannedSlot({
    required B02StrengthExecutionSlot slot,
    required int displayNumber,
    required bool isExtra,
    int? prescriptionOrdinal,
  }) {
    return B02CompactSetRow(
      id: 'planned:${slot.id}:$displayNumber',
      displayNumber: displayNumber,
      isLogged: false,
      isExtra: isExtra,
      role: B02SetRole.working,
      plannedLoadKg: slot.targetLoadKg,
      plannedLoadBasis: slot.targetLoadBasis,
      plannedRepsMin: slot.targetRepsMin,
      plannedRepsMax: slot.targetRepsMax,
      plannedRpe: slot.targetRpe,
      plannedTechnique: slot.techniqueForSet(
        prescriptionOrdinal ?? displayNumber - 1,
      ),
    );
  }

  final String id;
  final int displayNumber;
  final bool isLogged;
  final bool isExtra;
  final B02SetRole role;
  final double? plannedLoadKg;
  final B02LoadBasis? plannedLoadBasis;
  final int? plannedRepsMin;
  final int? plannedRepsMax;
  final int? plannedRpe;
  final double? actualLoadKg;
  final B02LoadBasis? actualLoadBasis;
  final int? actualReps;
  final int? actualRpe;
  final B02TechniqueFields? plannedTechnique;
  final B02TechniqueFields? actualTechnique;
  final B02PerformedSet? performedSet;

  /// The same working set from the last comparable session ("60 kg × 8").
  final String? previousLabel;

  B02CompactSetRow withPrevious(String? label) => label == null
      ? this
      : B02CompactSetRow(
          id: id,
          displayNumber: displayNumber,
          isLogged: isLogged,
          isExtra: isExtra,
          role: role,
          plannedLoadKg: plannedLoadKg,
          plannedLoadBasis: plannedLoadBasis,
          plannedRepsMin: plannedRepsMin,
          plannedRepsMax: plannedRepsMax,
          plannedRpe: plannedRpe,
          actualLoadKg: actualLoadKg,
          actualLoadBasis: actualLoadBasis,
          actualReps: actualReps,
          actualRpe: actualRpe,
          plannedTechnique: plannedTechnique,
          actualTechnique: actualTechnique,
          performedSet: performedSet,
          previousLabel: label,
        );

  String? get plannedLabel => r07cFormatTarget(
    loadKg: plannedLoadKg,
    loadBasis: plannedLoadBasis,
    minReps: plannedRepsMin,
    maxReps: plannedRepsMax,
    rpe: plannedRpe,
  );

  /// [plannedLabel] shortened for the PLANNED cell ("60 kg × 8–10").
  String? get plannedCellLabel => r07cFormatTargetCompact(
    loadKg: plannedLoadKg,
    loadBasis: plannedLoadBasis,
    minReps: plannedRepsMin,
    maxReps: plannedRepsMax,
    rpe: plannedRpe,
  );

  String? get actualLabel {
    final load = r07cFormatLoad(actualLoadKg, actualLoadBasis);
    if (load.isEmpty && actualReps == null && actualRpe == null) return null;
    return [
      if (load.isNotEmpty && actualReps != null) '$load × $actualReps',
      if (load.isNotEmpty && actualReps == null) load,
      if (load.isEmpty && actualReps != null)
        '$actualReps ${actualReps == 1 ? 'rep' : 'reps'}',
      if (actualRpe != null) 'RPE $actualRpe',
    ].join(' · ');
  }

  String? get plannedDetailsLabel =>
      plannedTechnique == null ? null : b02TechniqueSummary(plannedTechnique!);

  String? get actualDetailsLabel =>
      actualTechnique == null ? null : b02TechniqueSummary(actualTechnique!);
}

/// A shared, compact set-entry surface for Planned and Quick execution.
///
/// The parent owns input controllers and all actions. This widget only lays
/// out the current entry row and the logged-set rows, preserving their stable
/// canonical IDs while the draft changes around them.
class B02CompactSetTable extends StatelessWidget {
  const B02CompactSetTable({
    required this.slot,
    required this.loggedSets,
    required this.isPlannedMode,
    required this.isBusy,
    required this.currentSet,
    required this.loadController,
    required this.repsController,
    required this.rpe,
    required this.isWarmup,
    required this.loadLabel,
    required this.onRpeChanged,
    required this.onWarmupChanged,
    required this.onEdit,
    required this.onDelete,
    required this.moreContent,
    super.key,
    this.onAddSet,
    this.showPendingEditor = true,
    this.onLoadChanged,
    this.onRepsChanged,
    this.onOpenPlateCalculator,
    this.onCompleteNext,
    this.targetSummary,
    this.previousSetLabels = const [],
    this.bestSetKinds = const {},
    this.bestLabel,
  });

  final B02StrengthExecutionSlot slot;
  final List<B02PerformedSet> loggedSets;
  final bool isPlannedMode;
  final bool isBusy;
  final int currentSet;
  final TextEditingController loadController;
  final TextEditingController repsController;
  final int? rpe;
  final bool isWarmup;
  final String loadLabel;
  final ValueChanged<int?> onRpeChanged;
  final ValueChanged<bool> onWarmupChanged;
  final ValueChanged<B02PerformedSet>? onEdit;
  final ValueChanged<B02PerformedSet>? onDelete;
  final Widget? moreContent;
  final VoidCallback? onAddSet;
  final bool showPendingEditor;
  final ValueChanged<String>? onLoadChanged;
  final ValueChanged<String>? onRepsChanged;
  final VoidCallback? onOpenPlateCalculator;

  /// Logs the next planned set with the values in the editor below, exactly
  /// as the primary "Log set" button does. Null hides the row checkmark.
  final VoidCallback? onCompleteNext;

  /// Last-time and suggested-target summary shown under the "Next set"
  /// label, so the suggestion sits beside the fields it fills.
  final Widget? targetSummary;

  /// Last session's working sets in order; set N today shows entry N - 1.
  final List<String> previousSetLabels;

  /// Logged sets that are factual new bests, by set ID.
  final Map<String, TrainingBestKind> bestSetKinds;

  /// The best to beat ("Best 62.5 kg × 8") or the first-time baseline note.
  final String? bestLabel;

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    final nextRow = rows.where((row) => !row.isLogged).firstOrNull;
    return B05Surface(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('Sets', style: B05Typography.title(context)),
              ),
              if (loggedSets.isNotEmpty)
                Text(
                  '${loggedSets.length} logged',
                  style: B05Typography.caption(context),
                ),
            ],
          ),
          if (bestLabel case final label?) ...[
            const SizedBox(height: 2),
            Text(
              label,
              key: const ValueKey('compact-set-best-label'),
              style: B05Typography.caption(context),
            ),
          ],
          const SizedBox(height: 10),
          if (rows.isNotEmpty) ...[
            for (final row in rows) ...[
              _SetRow(
                row: row,
                isBusy: isBusy,
                onEdit: onEdit,
                onDelete: onDelete,
                onComplete: identical(row, nextRow) ? onCompleteNext : null,
                bestKind: row.isLogged ? bestSetKinds[row.id] : null,
              ),
              if (row != rows.last) const Divider(height: 1),
            ],
            const SizedBox(height: 10),
          ],
          if (showPendingEditor)
            _PendingSetEditor(
              slot: slot,
              currentSet: currentSet,
              loadController: loadController,
              repsController: repsController,
              rpe: rpe,
              isWarmup: isWarmup,
              loadLabel: loadLabel,
              isBusy: isBusy,
              onRpeChanged: onRpeChanged,
              onWarmupChanged: onWarmupChanged,
              onLoadChanged: onLoadChanged,
              onRepsChanged: onRepsChanged,
              moreContent: moreContent,
              onOpenPlateCalculator: onOpenPlateCalculator,
              targetSummary: targetSummary,
              previousLabel: nextRow != null || isWarmup
                  ? null
                  : _previousFor(currentSet - 1),
            ),
          if (onAddSet != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: B05ActionButton(
                label: 'Add set',
                hint: 'Prepare another set for this exercise',
                icon: Icons.add_rounded,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: isBusy ? null : onAddSet,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<B02CompactSetRow> _rows() {
    final ordered = [...loggedSets]
      ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
    final rows = <B02CompactSetRow>[];
    var workingLogged = 0;
    for (final set in ordered) {
      final isExtra =
          isPlannedMode &&
          set.role == B02SetRole.working &&
          workingLogged >= slot.plannedSets;
      final row = B02CompactSetRow.fromLoggedSet(
        set: set,
        displayNumber: rows.length + 1,
        isExtra: isExtra,
      );
      rows.add(
        set.role == B02SetRole.working
            ? row.withPrevious(_previousFor(workingLogged))
            : row,
      );
      if (set.role == B02SetRole.working) workingLogged++;
    }
    final hasPlannedContext =
        rows.any((row) => row.plannedLabel != null) ||
        r07cHasUsefulTarget(
          loadKg: slot.targetLoadKg,
          loadBasis: slot.targetLoadBasis,
          minReps: slot.targetRepsMin,
          maxReps: slot.targetRepsMax,
          rpe: slot.targetRpe,
        );
    final showPlannedRows = isPlannedMode || hasPlannedContext;
    if (showPlannedRows) {
      while (workingLogged < slot.plannedSets) {
        rows.add(
          B02CompactSetRow.fromPlannedSlot(
            slot: slot,
            displayNumber: rows.length + 1,
            isExtra: false,
            prescriptionOrdinal: slot.setPrescriptionOrdinal ?? workingLogged,
          ).withPrevious(_previousFor(workingLogged)),
        );
        workingLogged++;
      }
    }
    return rows;
  }

  String? _previousFor(int workingIndex) =>
      workingIndex >= 0 && workingIndex < previousSetLabels.length
      ? previousSetLabels[workingIndex]
      : null;
}

/// One set as a plain row (TP-8): "Set 2 · 8–12 reps", a faint "Last 60 kg ×
/// 8" under it while it's to come, and "✓ 60 kg × 8" once logged. No column
/// headers: each row says what it is.
class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.row,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
    this.onComplete,
    this.bestKind,
  });

  final B02CompactSetRow row;
  final bool isBusy;
  final ValueChanged<B02PerformedSet>? onEdit;
  final ValueChanged<B02PerformedSet>? onDelete;

  /// Set only on the next planned row: tapping its checkmark logs it.
  final VoidCallback? onComplete;

  /// Non-null when this logged set beat every earlier comparable set.
  final TrainingBestKind? bestKind;

  @override
  Widget build(BuildContext context) {
    final previous = row.previousLabel;
    return Semantics(
      container: true,
      label: _semanticLabel(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title(), style: B05Typography.label(context)),
                  if (!row.isLogged && row.plannedDetailsLabel != null)
                    Text(
                      'Details: ${row.plannedDetailsLabel}',
                      style: B05Typography.caption(context),
                    ),
                  if (row.isLogged) ...[
                    const SizedBox(height: 2),
                    _withBest(
                      _logged(
                        context,
                        _valueWithDetails(
                          context,
                          row.actualLabel ?? 'No actual value',
                          row.actualDetailsLabel,
                        ),
                      ),
                    ),
                  ] else if (previous != null)
                    Text(
                      'Last $previous',
                      style: B05Typography.caption(context),
                    ),
                ],
              ),
            ),
            if (row.isLogged) _actions(context) else _pendingStatus(context),
          ],
        ),
      ),
    );
  }

  /// "Set 2 · 8–12 reps", "Set 1 · Warm-up", "Set 5 · Extra".
  String _title() {
    final parts = <String>[
      'Set ${row.displayNumber}',
      if (row.role == B02SetRole.warmup) 'Warm-up',
      if (row.isExtra) 'Extra',
      ?row.plannedCellLabel,
    ];
    return parts.join(' · ');
  }

  Widget _actions(BuildContext context) {
    final set = row.performedSet;
    if (set == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        B05IconAction(
          icon: Icons.edit_outlined,
          label: 'Edit set ${row.displayNumber}',
          hint: 'Change the logged values or set details',
          onPressed: isBusy || onEdit == null ? null : () => onEdit!(set),
        ),
        B05IconAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete set ${row.displayNumber}',
          hint: 'Remove this logged set from the workout',
          onPressed: isBusy || onDelete == null ? null : () => onDelete!(set),
        ),
      ],
    );
  }

  /// One status for an unlogged row: a checkmark that logs it (next row
  /// only) or an empty circle for sets still to come.
  Widget _pendingStatus(BuildContext context) {
    final complete = onComplete;
    if (complete != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: B05IconAction(
          icon: Icons.check_circle_outline_rounded,
          label: 'Log set ${row.displayNumber}',
          hint: 'Log this set with the weight and reps below',
          onPressed: isBusy ? null : complete,
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ExcludeSemantics(
          child: Icon(
            Icons.radio_button_unchecked_rounded,
            size: 22,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }

  /// A logged value gets a tick, and fills in once when the set is saved:
  /// scale 0.9 to 1 with a fade over [B05MotionPolicy.fastDuration], instant
  /// with reduce motion. Unlogged rows are returned unchanged.
  Widget _logged(BuildContext context, Widget value) {
    if (!row.isLogged) return value;
    return B02LoggedSetTick(
      key: ValueKey('compact-set-logged-${row.id}'),
      child: value,
    );
  }

  Widget _withBest(Widget value) {
    final kind = bestKind;
    if (kind == null) return value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        value,
        const SizedBox(height: 2),
        B02NewBestChip(kind: kind),
      ],
    );
  }

  Widget _valueWithDetails(
    BuildContext context,
    String value,
    String? details, {
    TextStyle? style,
  }) {
    if (details == null) return Text(value, style: style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: style),
        Text('Details: $details', style: B05Typography.caption(context)),
      ],
    );
  }

  String _statusLabel() {
    if (!row.isLogged) return 'Not logged yet';
    if (row.role == B02SetRole.warmup) return 'Warm-up';
    return row.isExtra ? 'Extra' : 'Logged';
  }

  String _semanticLabel() {
    final parts = <String>[
      'Set ${row.displayNumber}',
      _statusLabel(),
      if (row.plannedLabel != null) 'planned ${row.plannedLabel}',
      if (row.actualLabel != null) 'actual ${row.actualLabel}',
      if (row.previousLabel != null) 'last time ${row.previousLabel}',
      if (row.plannedDetailsLabel != null)
        'planned details ${row.plannedDetailsLabel}',
      if (row.actualDetailsLabel != null)
        'actual details ${row.actualDetailsLabel}',
    ];
    return parts.join(', ');
  }
}

class _PendingSetEditor extends StatelessWidget {
  const _PendingSetEditor({
    required this.slot,
    required this.currentSet,
    required this.loadController,
    required this.repsController,
    required this.rpe,
    required this.isWarmup,
    required this.loadLabel,
    required this.isBusy,
    required this.onRpeChanged,
    required this.onWarmupChanged,
    required this.onLoadChanged,
    required this.onRepsChanged,
    required this.moreContent,
    this.onOpenPlateCalculator,
    this.targetSummary,
    this.previousLabel,
  });

  final B02StrengthExecutionSlot slot;
  final int currentSet;
  final TextEditingController loadController;
  final TextEditingController repsController;
  final int? rpe;
  final bool isWarmup;
  final String loadLabel;
  final bool isBusy;
  final ValueChanged<int?> onRpeChanged;
  final ValueChanged<bool> onWarmupChanged;
  final ValueChanged<String>? onLoadChanged;
  final ValueChanged<String>? onRepsChanged;
  final Widget? moreContent;
  final VoidCallback? onOpenPlateCalculator;
  final Widget? targetSummary;
  final String? previousLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Next set input',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Next set · $currentSet',
                  style: B05Typography.label(context),
                ),
              ),
              if (_hasUsefulTarget)
                Flexible(
                  child: Text(
                    'Enter actuals',
                    textAlign: TextAlign.end,
                    style: B05Typography.caption(context),
                  ),
                ),
            ],
          ),
          if (previousLabel != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                Text('Last time', style: B05Typography.caption(context)),
                Text(previousLabel!),
              ],
            ),
          ],
          if (targetSummary != null) ...[
            const SizedBox(height: 6),
            targetSummary!,
          ],
          const SizedBox(height: 8),
          IndiFitResponsiveFieldGroup(
            spacing: 10,
            breakpoint: 350,
            children: [
              TextFormField(
                key: ValueKey('compact-load-${slot.id}'),
                controller: loadController,
                enabled: !isBusy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: loadLabel,
                  suffixIcon: onOpenPlateCalculator == null
                      ? null
                      : IconButton(
                          tooltip: 'Plate calculator',
                          icon: const Icon(IndiFitIcons.plateCalculator),
                          onPressed: isBusy ? null : onOpenPlateCalculator,
                        ),
                ),
                onChanged: onLoadChanged,
              ),
              TextFormField(
                key: ValueKey('compact-reps-${slot.id}'),
                controller: repsController,
                enabled: !isBusy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Reps'),
                onChanged: onRepsChanged,
                onEditingComplete: () =>
                    FocusManager.instance.primaryFocus?.unfocus(),
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('More for this set'),
            subtitle: Text(
              isWarmup ? 'Warm-up set · Optional details' : 'Optional details',
            ),
            children: [
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: rpe,
                decoration: const InputDecoration(labelText: 'RPE'),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Not set'),
                  ),
                  for (var effort = 1; effort <= 10; effort++)
                    DropdownMenuItem(value: effort, child: Text('$effort')),
                ],
                onChanged: isBusy ? null : onRpeChanged,
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('RPE is optional. RPE 8 ≈ about 2 good reps left.'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: isWarmup ? 'warmup' : 'working',
                decoration: const InputDecoration(labelText: 'Set role'),
                items: const [
                  DropdownMenuItem(
                    value: 'working',
                    child: Text('Working set'),
                  ),
                  DropdownMenuItem(value: 'warmup', child: Text('Warm-up set')),
                ],
                onChanged: isBusy
                    ? null
                    : (value) => onWarmupChanged(value == 'warmup'),
              ),
              if (moreContent != null) ...[
                const SizedBox(height: 8),
                IgnorePointer(ignoring: isBusy, child: moreContent!),
              ],
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasUsefulTarget => r07cHasUsefulTarget(
    loadKg: slot.targetLoadKg,
    loadBasis: slot.targetLoadBasis,
    minReps: slot.targetRepsMin,
    maxReps: slot.targetRepsMax,
    rpe: slot.targetRpe,
  );
}

/// "New best" on a saved set row. It scales in once when the row first shows
/// it (instantly with reduce motion) and is never shown before the save.
class B02NewBestChip extends StatelessWidget {
  const B02NewBestChip({super.key, required this.kind});

  final TrainingBestKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    // Its own node, read right after the row: "New best, heaviest".
    return Semantics(
      container: true,
      label: TrainingBestsCopy.semanticsLabel(kind),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: B05MotionPolicy.transitionDuration(
          context,
          standard: B05MotionPolicy.completionDuration,
        ),
        curve: B05MotionPolicy.standardCurve,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: child,
        ),
        child: Container(
          key: const ValueKey('compact-set-new-best'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colors.success.container,
            borderRadius: b05Radius(B05SurfaceRadius.small),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                size: 14,
                color: colors.success.foreground,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  TrainingBestsCopy.newBest,
                  style: B05Typography.caption(context).copyWith(
                    color: colors.success.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tick on a saved set row (TP-7). The row's own semantics already say
/// the set is logged, so the icon is decorative.
class B02LoggedSetTick extends StatelessWidget {
  const B02LoggedSetTick({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: B05MotionPolicy.transitionDuration(
        context,
        standard: B05MotionPolicy.fastDuration,
      ),
      curve: B05MotionPolicy.standardCurve,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: 0.9 + 0.1 * progress,
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 1, right: 4),
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: context.b05Colors.action,
              ),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}
