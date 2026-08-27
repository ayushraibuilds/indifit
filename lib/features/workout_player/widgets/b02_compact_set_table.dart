import 'package:flutter/material.dart';

import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/responsive_form_primitives.dart';
import '../../../data/models/b02_execution_models.dart';
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

  String? get plannedLabel => r07cFormatTarget(
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
      if (load.isNotEmpty) load,
      if (actualReps != null) '$actualReps ${actualReps == 1 ? 'rep' : 'reps'}',
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

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    final showTarget = rows.any((row) => row.plannedLabel != null);
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
          const SizedBox(height: 10),
          if (rows.isNotEmpty) ...[
            _TableHeader(showTarget: showTarget),
            const SizedBox(height: 4),
            for (final row in rows) ...[
              _SetRow(
                row: row,
                showTarget: showTarget,
                isBusy: isBusy,
                onEdit: onEdit,
                onDelete: onDelete,
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
      rows.add(
        B02CompactSetRow.fromLoggedSet(
          set: set,
          displayNumber: rows.length + 1,
          isExtra: isExtra,
        ),
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
          ),
        );
        workingLogged++;
      }
    }
    return rows;
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.showTarget});

  final bool showTarget;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compact = MediaQuery.sizeOf(context).width < 380 || textScale >= 1.3;
    return Semantics(
      header: true,
      child: compact ? _buildCompact(context) : _buildWide(context),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('SET / DETAILS')),
        const Text('STATUS'),
      ],
    );
  }

  Widget _buildWide(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 42, child: Text('SET')),
        if (showTarget) const Expanded(flex: 2, child: Text('PLANNED')),
        const Expanded(flex: 3, child: Text('ACTUAL')),
        SizedBox(
          width: B05Layout.minTouchTarget * 2,
          child: const Text('STATUS'),
        ),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.row,
    required this.showTarget,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
  });

  final B02CompactSetRow row;
  final bool showTarget;
  final bool isBusy;
  final ValueChanged<B02PerformedSet>? onEdit;
  final ValueChanged<B02PerformedSet>? onDelete;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompact(context);
    return Semantics(
      container: true,
      label: _semanticLabel(),
      child: compact ? _buildCompact(context) : _buildWide(context),
    );
  }

  Widget _buildWide(BuildContext context) {
    final actual = row.isLogged
        ? row.actualLabel ?? 'No actual value'
        : 'Not logged';
    final status = _statusLabel();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '${row.displayNumber}',
              style: B05Typography.label(context),
            ),
          ),
          if (showTarget)
            Expanded(
              flex: 2,
              child: _valueWithDetails(
                context,
                row.plannedLabel ?? 'No target',
                row.plannedDetailsLabel,
              ),
            ),
          Expanded(
            flex: 3,
            child: _valueWithDetails(context, actual, row.actualDetailsLabel),
          ),
          SizedBox(
            width: B05Layout.minTouchTarget * 2,
            child: row.isLogged
                ? _actions(context)
                : Text(status, style: B05Typography.caption(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final actual = row.isLogged
        ? row.actualLabel ?? 'No actual value'
        : 'Not logged';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Set ${row.displayNumber}${row.isExtra ? ' · Extra' : ''}',
                  style: B05Typography.label(context),
                ),
              ),
              Text(_statusLabel(), style: B05Typography.caption(context)),
            ],
          ),
          if (showTarget) ...[
            const SizedBox(height: 2),
            _valueWithDetails(
              context,
              'Planned: ${row.plannedLabel ?? 'No target'}',
              row.plannedDetailsLabel,
              style: B05Typography.caption(context),
            ),
          ],
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _valueWithDetails(
                  context,
                  'Actual: $actual',
                  row.actualDetailsLabel,
                ),
              ),
              if (row.isLogged) _actions(context),
            ],
          ),
        ],
      ),
    );
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
    if (!row.isLogged) return 'Ready';
    if (row.role == B02SetRole.warmup) return 'Warm-up';
    return row.isExtra ? 'Extra' : 'Logged';
  }

  String _semanticLabel() {
    final parts = <String>[
      'Set ${row.displayNumber}',
      _statusLabel(),
      if (row.plannedLabel != null) 'planned ${row.plannedLabel}',
      if (row.actualLabel != null) 'actual ${row.actualLabel}',
      if (row.plannedDetailsLabel != null)
        'planned details ${row.plannedDetailsLabel}',
      if (row.actualDetailsLabel != null)
        'actual details ${row.actualDetailsLabel}',
    ];
    return parts.join(', ');
  }

  bool _isCompact(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return MediaQuery.sizeOf(context).width < 380 || textScale >= 1.3;
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
              if (slot.targetRepsMin != null || slot.targetLoadKg != null)
                Flexible(
                  child: Text(
                    'Enter actuals',
                    textAlign: TextAlign.end,
                    style: B05Typography.caption(context),
                  ),
                ),
            ],
          ),
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
                decoration: InputDecoration(labelText: loadLabel),
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
            title: Row(
              children: [
                const Expanded(child: Text('More for this set')),
                Flexible(
                  child: Text(
                    'RPE',
                    style: Theme.of(context).textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              rpe == null
                  ? (isWarmup ? 'Warm-up set' : 'RPE and set role')
                  : 'RPE $rpe${isWarmup ? ' · Warm-up' : ''}',
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
}
