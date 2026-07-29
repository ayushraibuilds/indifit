import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/providers.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/theme/app_colors.dart';
import 'calendar_controller.dart';
import 'calendar_read_model.dart';

/// Modal action sheet for calendar occurrences exposing B01 domain actions.
class OccurrenceActionsSheet extends ConsumerStatefulWidget {
  final CalendarOccurrenceItem occurrenceItem;

  const OccurrenceActionsSheet({super.key, required this.occurrenceItem});

  @override
  ConsumerState<OccurrenceActionsSheet> createState() =>
      _OccurrenceActionsSheetState();
}

class _OccurrenceActionsSheetState
    extends ConsumerState<OccurrenceActionsSheet> {
  final LocalScheduleDateService _dates = LocalScheduleDateService();
  bool _isLoading = false;

  Future<void> _startWorkout() async {
    setState(() => _isLoading = true);
    try {
      final adapter = ref.read(workoutExecutionCompatibilityAdapterProvider);
      final commandId = 'cmd-start-${DateTime.now().millisecondsSinceEpoch}';

      final launchData = await adapter.startScheduledOccurrence(
        occurrenceId: widget.occurrenceItem.occurrence.id,
        commandId: commandId,
      );

      if (mounted) {
        Navigator.pop(context); // Close sheet
        context.push('/workout-player', extra: {'scheduledLaunch': launchData});
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

    if (picked == null) return;

    final newDateStr = _dates.formatLocalDate(picked);
    final commandId = 'cmd-resched-${DateTime.now().millisecondsSinceEpoch}';

    setState(() => _isLoading = true);
    try {
      final controller = ref.read(calendarControllerProvider.notifier);
      await controller.reschedule(
        occurrenceId: widget.occurrenceItem.occurrence.id,
        commandId: commandId,
        newEffectiveLocalDate: newDateStr,
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
    // B01-PD01: Explicit User Choice Required. No option selected by default.
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

    final commandId = 'cmd-skip-${DateTime.now().millisecondsSinceEpoch}';
    final isBypass = choice == 'skipAndAdvance';

    setState(() => _isLoading = true);
    try {
      final controller = ref.read(calendarControllerProvider.notifier);
      await controller.skip(
        occurrenceId: widget.occurrenceItem.occurrence.id,
        commandId: commandId,
        advanceProgression: isBypass,
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
    final commandId = 'cmd-cancel-${DateTime.now().millisecondsSinceEpoch}';
    setState(() => _isLoading = true);
    try {
      final controller = ref.read(calendarControllerProvider.notifier);
      await controller.cancel(
        occurrenceId: widget.occurrenceItem.occurrence.id,
        commandId: commandId,
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

    final commandId = 'cmd-repeat-${DateTime.now().millisecondsSinceEpoch}';
    setState(() => _isLoading = true);
    try {
      final controller = ref.read(calendarControllerProvider.notifier);
      await controller.repeat(
        occurrenceId: widget.occurrenceItem.occurrence.id,
        commandId: commandId,
        repeatPurpose: purpose,
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

  @override
  Widget build(BuildContext context) {
    final item = widget.occurrenceItem;
    final occ = item.occurrence;

    return Padding(
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
                  item.templateName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: GoogleFonts.outfit().fontFamily,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            'Date: ${occ.effectiveLocalDate} • Timezone: ${occ.effectiveTimezoneId}${item.isOverdue ? " • OVERDUE" : ""}',
            style: TextStyle(
              color: item.isOverdue ? Colors.orange : Colors.grey,
              fontWeight: item.isOverdue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            ListTile(
              leading: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Start Workout'),
              onTap: _startWorkout,
            ),
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
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('Repeat Workout'),
              onTap: _showRepeatDialog,
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
        ],
      ),
    );
  }
}
