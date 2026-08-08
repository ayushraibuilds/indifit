import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/colors.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import 'calendar_controller.dart';
import 'workout_contextual_launcher.dart';

/// Modal action sheet for calendar occurrences exposing B01 domain actions.
class OccurrenceActionsSheet extends ConsumerStatefulWidget {
  final CalendarOccurrenceReadItem occurrenceItem;

  const OccurrenceActionsSheet({super.key, required this.occurrenceItem});

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
            labelText: 'IANA timezone',
            helperText: 'For example: Asia/Kolkata or Europe/London',
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
          title: Text(
            'Skip Workout',
            style: TextStyle(fontFamily: GoogleFonts.outfit().fontFamily),
          ),
          content: const Text(
            'How would you like to handle progression for this skipped workout?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'keepPending'),
              child: const Text('1. Keep Pending (Make up later)'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'skipAndAdvance'),
              child: const Text('2. Skip & Advance Progression'),
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
                  ? 'Skipped and advanced progression.'
                  : 'Skipped (Kept pending for make-up).',
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
        ).showSnackBar(const SnackBar(content: Text('Occurrence cancelled.')));
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
          title: const Text('Repeat Workout Purpose'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'makeUp'),
              child: const Text('Make-up Repeat (Fulfills pending ordinal)'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'extra'),
              child: const Text('Extra Repeat (Additional volume)'),
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
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Occurrence history',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.outfit().fontFamily,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(occ.status),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Scheduled: ${ConsumerDateLabel.day(occ.originalLocalDate)}\nEffective: ${ConsumerDateLabel.day(occ.effectiveLocalDate)}${item.isOverdue ? ' • Overdue' : ''}',
              style: TextStyle(
                color: item.isOverdue ? Colors.orange : Colors.grey,
                fontWeight: item.isOverdue
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${item.block.name} • Week ${item.week.programWeekOrdinal + 1}${item.isDeload ? ' • Deload' : ''}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (item.prescriptions.isNotEmpty)
              Text(
                item.prescriptions
                    .map(
                      (prescription) =>
                          '${prescription.exerciseNameSnapshot} (${prescription.plannedSets} × ${prescription.repsRange})',
                    )
                    .join('\n'),
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (isStartable || isInProgress)
                ListTile(
                  leading: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    isInProgress ? 'Resume Workout' : 'Start Workout',
                  ),
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
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                  title: const Text(
                    'Cancel Workout',
                    style: TextStyle(color: Colors.red),
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
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('View History'),
                onTap: _showHistory,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _eventLabel(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

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
