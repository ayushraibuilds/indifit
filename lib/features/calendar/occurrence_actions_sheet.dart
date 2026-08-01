import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/providers.dart';
import '../../core/theme/colors.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../workout_player/b02_strength_execution_controller.dart';
import 'calendar_controller.dart';

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
    final dates = ref.read(localScheduleDateServiceProvider);
    final startsOutsideEffectiveDate =
        dates.todayIn(occurrence.effectiveTimezoneId) !=
        occurrence.effectiveLocalDate;
    if (startsOutsideEffectiveDate) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start outside scheduled date?'),
          content: Text(
            'This workout is scheduled for ${occurrence.effectiveLocalDate} in ${occurrence.effectiveTimezoneId}. Starting it will not move or skip any other workout.',
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
      final activityType = B02ActivityType.parse(
        widget.occurrenceItem.template.activityType,
      );
      final isStrength = activityType == B02ActivityType.strength;
      if (isStrength) {
        final coverage = await ref
            .read(strengthExecutionCompatibilityAdapterProvider)
            .checkScheduledCoverage(occurrence.id);
        if (coverage.supported) {
          final b02 = ref.read(b02StrengthExecutionControllerProvider.notifier);
          if (occurrence.status == 'inProgress') {
            await b02.resumeScheduled(occurrence.id);
          } else {
            await b02.startScheduled(
              occurrenceId: occurrence.id,
              commandId: 'b02-start-${DateTime.now().millisecondsSinceEpoch}',
              confirmedOutsideEffectiveDate: startsOutsideEffectiveDate,
            );
          }
          final b02State = ref.read(b02StrengthExecutionControllerProvider);
          if (b02State.status == B02StrengthExecutionStatus.ready &&
              b02State.launch != null &&
              mounted) {
            Navigator.pop(context);
            await context.push(
              '/b02-strength-player',
              extra: {'launch': b02State.launch},
            );
            return;
          }
          // In-progress v1 drafts intentionally remain on the retained B01
          // route; the successor reports this as recovery rather than guessing.
          if (b02State.status != B02StrengthExecutionStatus.recovery) {
            throw StateError(
              b02State.errorMessage ??
                  'B02 strength draft could not be started.',
            );
          }
        }
      } else if (activityType != B02ActivityType.legacy) {
        throw StateError(
          'Scheduled ${activityType.dbValue} activity uses the typed activity flow; it must not open the legacy strength player.',
        );
      }
      final adapter = ref.read(workoutExecutionCompatibilityAdapterProvider);
      final launchData = occurrence.status == 'inProgress'
          ? await adapter.resumeScheduledOccurrence(occurrence.id)
          : await adapter.startScheduledOccurrence(
              occurrenceId: occurrence.id,
              commandId: 'cmd-start-${DateTime.now().millisecondsSinceEpoch}',
              confirmedOutsideEffectiveDate: startsOutsideEffectiveDate,
            );

      if (mounted) {
        Navigator.pop(context); // Close sheet
        await context.push(
          '/workout-player',
          extra: {'scheduledLaunch': launchData},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start workout: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rescheduled to $newDateStr.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Reschedule failed: $e')));
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Skip failed: $e')));
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Repeat failed: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $error')));
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
                title: Text(event.eventType),
                subtitle: Text(
                  '${event.fromStatus ?? '—'} → ${event.toStatus ?? '—'}\n${event.occurredAtUtc.toLocal()}',
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
                    occ.status.toUpperCase(),
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
              'Scheduled: ${occ.originalLocalDate} • ${occ.originalTimezoneId}\nEffective: ${occ.effectiveLocalDate} • ${occ.effectiveTimezoneId}${item.isOverdue ? " • OVERDUE" : ""}',
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
}
