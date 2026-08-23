import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import 'calendar_controller.dart';
import 'workout_contextual_launcher.dart';

/// Consumer label for an occurrence history event. Public for focused tests.
/// Splits both snake_case and camelCase event types into readable words.
String occurrenceEventLabel(String value) => value
    .replaceAll('_', ' ')
    .replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

/// Modal action sheet for calendar occurrences exposing B01 domain actions.
class OccurrenceActionsSheet extends ConsumerStatefulWidget {
  final CalendarOccurrenceReadItem occurrenceItem;
  final bool scheduleAdjustmentsOnly;

  const OccurrenceActionsSheet({
    super.key,
    required this.occurrenceItem,
    this.scheduleAdjustmentsOnly = false,
  });

  @override
  ConsumerState<OccurrenceActionsSheet> createState() =>
      _OccurrenceActionsSheetState();
}

class _OccurrenceActionsSheetState
    extends ConsumerState<OccurrenceActionsSheet> {
  bool _isLoading = false;

  Future<void> _startWorkout() async {
    final occurrence = widget.occurrenceItem.occurrence;
    final needsConfirmation =
        WorkoutContextualLauncher.requiresDateConfirmation(
          ref,
          widget.occurrenceItem,
        );
    if (needsConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start outside scheduled date?'),
          content: Text(
            'This workout is scheduled for ${ConsumerDateLabel.day(occurrence.effectiveLocalDate)}. Starting it will not move or skip any other workout.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start workout'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _isLoading = true);
    try {
      final target = await WorkoutContextualLauncher.prepare(
        ref: ref,
        item: widget.occurrenceItem,
        confirmedOutsideEffectiveDate: needsConfirmation,
      );

      if (mounted) {
        Navigator.pop(context);
        await WorkoutContextualLauncher.push(context, target);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ProductFailurePresentation.fromError(
                error,
                title: 'Workout could not be started',
                code: 'workout_unavailable',
              ).message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rescheduleOccurrence() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 180)),
    );

    if (picked == null || !mounted) return;

    final timezoneController = TextEditingController(
      text: widget.occurrenceItem.occurrence.effectiveTimezoneId,
    );
    final timezone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm reschedule'),
        content: TextField(
          controller: timezoneController,
          decoration: const InputDecoration(
            labelText: 'Time zone',
            helperText: 'Use the time zone where you will train.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, timezoneController.text.trim()),
            child: const Text('Reschedule'),
          ),
        ],
      ),
    );
    timezoneController.dispose();
    if (timezone == null || timezone.isEmpty || !mounted) return;

    final dates = ref.read(localScheduleDateServiceProvider);
    final newDateStr = dates.normalizeLocalDate(
      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
    );

    setState(() => _isLoading = true);
    try {
      final controller = ref.read(calendarControllerProvider.notifier);
      await controller.rescheduleOccurrence(
        widget.occurrenceItem.occurrence.id,
        newDateStr,
        confirmed: true,
        effectiveTimezoneId: timezone,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rescheduled to ${ConsumerDateLabel.day(newDateStr)}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ProductFailurePresentation.fromError(
                error,
                title: 'Workout could not be rescheduled',
                code: 'calendar_unavailable',
              ).message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSkipDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Skip workout'),
          content: const Text(
            'Would you like to make it up later, or skip it and continue your plan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'keepPending'),
              child: const Text('Make it up later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'skipAndAdvance'),
              child: const Text('Skip Workout'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (choice == null) return;

    final isBypass = choice == 'skipAndAdvance';

    setState(() => _isLoading = true);
    try {
      final controller = ref.read(calendarControllerProvider.notifier);
      await controller.skipOccurrence(
        widget.occurrenceItem.occurrence.id,
        disposition: isBypass
            ? SkipDisposition.advance
            : SkipDisposition.keepPending,
        reason: isBypass
            ? 'User chose skip and advance'
            : 'User chose keep pending',
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBypass
                  ? 'Workout skipped. Your plan will continue.'
                  : 'Workout kept on your plan for later.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ProductFailurePresentation.fromError(
                error,
                title: 'Workout could not be skipped',
                code: 'calendar_unavailable',
              ).message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelOccurrence() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel workout?'),
        content: const Text(
          'The workout remains in your calendar history and does not advance progression.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep workout'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel workout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final controller = ref.read(calendarControllerProvider.notifier);
      await controller.cancelOccurrence(
        widget.occurrenceItem.occurrence.id,
        reason: 'User cancelled via action sheet',
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Workout cancelled.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ProductFailurePresentation.fromError(
                error,
                title: 'Workout could not be cancelled',
                code: 'calendar_unavailable',
              ).message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showRepeatDialog() async {
    final purpose = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Repeat workout'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'makeUp'),
              child: const Text('Make up a missed workout'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'extra'),
              child: const Text('Add an extra workout'),
            ),
          ],
        );
      },
    );

    if (purpose == null) return;

    final dates = ref.read(localScheduleDateServiceProvider);
    final now = DateTime.now();
    final todayStr = dates.normalizeLocalDate(
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );

    setState(() => _isLoading = true);
    try {
      final controller = ref.read(calendarControllerProvider.notifier);
      await controller.repeatOccurrence(
        widget.occurrenceItem.occurrence.id,
        todayStr,
        purpose: purpose == 'makeUp'
            ? RepeatPurpose.makeUp
            : RepeatPurpose.extra,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created $purpose repeat workout.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Repeat could not be created. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreOccurrence() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(calendarControllerProvider.notifier)
          .restoreOccurrence(widget.occurrenceItem.occurrence.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout restored to the plan.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout could not be restored. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showHistory() async {
    final events = await ref
        .read(calendarRepositoryProvider)
        .getOccurrenceHistory(widget.occurrenceItem.occurrence.id);
    if (!mounted) return;
    await showIndiFitBottomSheet<void>(
      context: context,
      semanticLabel: 'Workout history',
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(B05Layout.space16),
        children: [
          Text('Session history', style: B05Typography.title(context)),
          const SizedBox(height: 8),
          if (events.isEmpty) const Text('No recorded events.'),
          ...events.map(
            (event) => ListTile(
              title: Text(_eventLabel(event.eventType)),
              subtitle: Text(
                '${_statusLabel(event.fromStatus)} → ${_statusLabel(event.toStatus)}\n${ConsumerDateLabel.dateTime(event.occurredAtUtc)}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final item = widget.occurrenceItem;
    final occ = item.occurrence;
    final isStartable = occ.status == 'planned' || occ.status == 'rescheduled';
    final isInProgress = occ.status == 'inProgress';
    final isTerminal = const {
      'completed',
      'partiallyCompleted',
      'skipped',
      'cancelled',
    }.contains(occ.status);
    final isRestorable = occ.status == 'skipped' || occ.status == 'cancelled';
    final scheduledDateLabel = ConsumerDateLabel.day(occ.originalLocalDate);
    final dateLabel = occ.originalLocalDate == occ.effectiveLocalDate
        ? 'Scheduled for $scheduledDateLabel'
        : 'Moved to ${ConsumerDateLabel.day(occ.effectiveLocalDate)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.template.name,
                  style: B05Typography.title(context),
                ),
              ),
              B05Surface(
                tone: B05SurfaceTone.selected,
                radius: B05SurfaceRadius.small,
                padding: const EdgeInsets.symmetric(
                  horizontal: B05Layout.space8,
                  vertical: B05Layout.space4,
                ),
                child: Text(
                  _statusLabel(occ.status),
                  style: B05Typography.caption(
                    context,
                  ).copyWith(color: colors.action, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            '$dateLabel${item.isOverdue ? ' • Overdue' : ''}',
            style: B05Typography.caption(context).copyWith(
              color: item.isOverdue
                  ? colors.warning.indicator
                  : colors.textSecondary,
              fontWeight: item.isOverdue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: B05Layout.space16),
          Text(
            '${item.block.name} • Week ${item.week.programWeekOrdinal + 1}${item.isDeload ? ' • Deload' : ''}',
            style: B05Typography.caption(context),
          ),
          const SizedBox(height: B05Layout.space8),
          if (item.prescriptions.isNotEmpty)
            Text(
              item.prescriptions
                  .map(
                    (prescription) =>
                        '${prescription.exerciseNameSnapshot} (${prescription.plannedSets} × ${prescription.repsRange})',
                  )
                  .join('\n'),
              style: B05Typography.caption(context),
            ),
          const SizedBox(height: B05Layout.space8),
          if (_isLoading)
            Center(
              child: Semantics(
                liveRegion: true,
                label: 'Updating workout',
                child: CircularProgressIndicator(color: colors.action),
              ),
            )
          else ...[
            if (!widget.scheduleAdjustmentsOnly &&
                (isStartable || isInProgress))
              ListTile(
                leading: Icon(Icons.play_arrow_rounded, color: colors.action),
                title: Text(isInProgress ? 'Resume Workout' : 'Start Workout'),
                onTap: _startWorkout,
              ),
            if (isStartable) ...[
              ListTile(
                leading: const Icon(Icons.edit_calendar_rounded),
                title: const Text('Reschedule'),
                onTap: _rescheduleOccurrence,
              ),
              ListTile(
                leading: const Icon(Icons.skip_next_rounded),
                title: const Text('Skip Workout'),
                onTap: _showSkipDialog,
              ),
              if (!widget.scheduleAdjustmentsOnly)
                ListTile(
                  leading: Icon(
                    Icons.cancel_outlined,
                    color: colors.danger.indicator,
                  ),
                  title: Text(
                    'Cancel Workout',
                    style: B05Typography.body(
                      context,
                    ).copyWith(color: colors.danger.indicator),
                  ),
                  onTap: _cancelOccurrence,
                ),
            ],
            if (isRestorable)
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Restore to Plan'),
                onTap: _restoreOccurrence,
              ),
            if (isTerminal)
              ListTile(
                leading: const Icon(Icons.repeat_rounded),
                title: const Text('Repeat Workout'),
                onTap: _showRepeatDialog,
              ),
            if (!widget.scheduleAdjustmentsOnly)
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('View History'),
                onTap: _showHistory,
              ),
          ],
        ],
      ),
    );
  }

  static String _eventLabel(String value) => occurrenceEventLabel(value);

  static String _statusLabel(String? value) {
    final key = value?.trim() ?? '';
    return switch (key) {
      'planned' => 'Planned',
      'rescheduled' => 'Rescheduled',
      'completed' => 'Completed',
      'partiallyCompleted' => 'Partially completed',
      'inProgress' => 'In progress',
      'skipped' => 'Skipped',
      'cancelled' => 'Cancelled',
      _ => key.isEmpty ? '—' : 'Status not available',
    };
  }
}
