import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../media/b05_playlist_launcher.dart';
import 'calendar_controller.dart';
import 'workout_contextual_action_controller.dart';
import 'workout_contextual_launcher.dart';

/// Contextual actions for one B01 calendar occurrence. The row never removes
/// itself or invents a status; B01 mutation results are reconciled through the
/// calendar read controller.
class WorkoutContextualActions extends ConsumerStatefulWidget {
  const WorkoutContextualActions({
    required this.item,
    required this.onOpenDetails,
    super.key,
  });

  final CalendarOccurrenceReadItem item;
  final VoidCallback onOpenDetails;

  @override
  ConsumerState<WorkoutContextualActions> createState() =>
      _WorkoutContextualActionsState();
}

class _WorkoutContextualActionsState
    extends ConsumerState<WorkoutContextualActions> {
  var _isLaunching = false;
  String? _launchError;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _undoFeedback;

  CalendarOccurrenceReadItem get _item => widget.item;

  bool get _isStartable =>
      _item.occurrence.status == OccurrenceStatus.planned.dbValue ||
      _item.occurrence.status == OccurrenceStatus.rescheduled.dbValue;

  bool get _isInProgress =>
      _item.occurrence.status == OccurrenceStatus.inProgress.dbValue;

  bool get _canLaunch => _isStartable || _isInProgress;

  Future<void> _startOrResume() async {
    if (_isLaunching) return;
    final needsConfirmation =
        WorkoutContextualLauncher.requiresDateConfirmation(ref, _item);
    if (needsConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start outside scheduled date?'),
          content: Text(
            'This workout is scheduled for ${ConsumerDateLabel.day(_item.occurrence.effectiveLocalDate)}. Starting it will not move or skip any other workout.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_isInProgress ? 'Resume workout' : 'Start workout'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isLaunching = true;
      _launchError = null;
    });
    try {
      final target = await WorkoutContextualLauncher.prepare(
        ref: ref,
        item: _item,
        confirmedOutsideEffectiveDate: needsConfirmation,
      );
      if (!mounted) return;
      dismissIndiFitFeedback(context);
      await WorkoutContextualLauncher.push(context, target);
      if (mounted) await _reconcile();
    } catch (error) {
      if (mounted) {
        setState(
          () => _launchError = ProductFailurePresentation.fromError(
            error,
            title: 'Workout unavailable',
            code: 'workout_unavailable',
          ).message,
        );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  Future<void> _confirmSkip() async {
    if (!_isStartable) return;
    final disposition = await showDialog<SkipDisposition>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip workout?'),
        content: const Text(
          'Choose how this skipped workout affects your existing progression plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, SkipDisposition.keepPending),
            child: const Text('Keep pending'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, SkipDisposition.advance),
            child: const Text('Skip and advance'),
          ),
        ],
      ),
    );
    if (disposition == null || !mounted) return;
    await _skip(disposition);
  }

  Future<void> _skip(SkipDisposition disposition) async {
    final controller = ref.read(
      workoutOccurrenceActionControllerProvider(_item.occurrence.id).notifier,
    );
    await controller.skip(disposition);
    if (!mounted) return;
    await _reconcile();
    final state = ref.read(
      workoutOccurrenceActionControllerProvider(_item.occurrence.id),
    );
    final offer = state.undoOffer;
    if (state.status == WorkoutOccurrenceActionStatus.success &&
        offer != null) {
      _showUndo(offer);
    }
  }

  void _showUndo(WorkoutOccurrenceUndoOffer offer) {
    final messenger = ScaffoldMessenger.of(context);
    final duration = offer.expiresAtUtc.difference(DateTime.now().toUtc());
    messenger.clearSnackBars();
    final snackBar = messenger.showSnackBar(
      indiFitUndoSnackBar(
        context,
        message: 'Workout skipped.',
        duration: duration.isNegative ? const Duration(seconds: 1) : duration,
        onUndo: () => unawaited(_undo()),
      ),
    );
    _undoFeedback = snackBar;
    unawaited(
      snackBar.closed.then((_) {
        if (mounted) {
          ref
              .read(
                workoutOccurrenceActionControllerProvider(
                  _item.occurrence.id,
                ).notifier,
              )
              .expireUndo();
        }
      }),
    );
  }

  Future<void> _undo() async {
    final controller = ref.read(
      workoutOccurrenceActionControllerProvider(_item.occurrence.id).notifier,
    );
    await controller.undo();
    if (!mounted) return;
    await _reconcile();
  }

  Future<void> _reconcile() =>
      ref.read(calendarControllerProvider.notifier).refresh();

  @override
  void dispose() {
    _undoFeedback?.close();
    super.dispose();
  }

  Future<bool> _onSwipe(DismissDirection direction) async {
    if (_isLaunching || !_canLaunch) return false;
    if (direction == DismissDirection.startToEnd) {
      await _startOrResume();
    } else if (direction == DismissDirection.endToStart) {
      await _confirmSkip();
    }
    // A B01 read-model stream owns removal/status changes. Dismissible never
    // creates a widget-local disappearance.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final occurrence = item.occurrence;
    final actionState = ref.watch(
      workoutOccurrenceActionControllerProvider(occurrence.id),
    );
    final dates = ref.watch(localScheduleDateServiceProvider);
    final today = dates.todayIn(occurrence.effectiveTimezoneId);
    final isToday = occurrence.effectiveLocalDate == today;
    final isFuture = dates.compare(occurrence.effectiveLocalDate, today) > 0;
    final busy = _isLaunching || actionState.isPending;
    final colors = context.b05Colors;
    final status = _statusFor(
      colors,
      occurrence.status,
      item.isDeload,
      item.isOverdue,
    );
    final spokenStatus = _spokenStatus(
      occurrence.status,
      isOverdue: item.isOverdue,
      isToday: isToday,
      isFuture: isFuture,
    );

    return Semantics(
      container: true,
      label: '${item.template.name} workout',
      value: 'Status $spokenStatus',
      hint: _canLaunch && isToday
          ? 'Swipe right to open the workout player or left to skip. Buttons provide the same actions.'
          : occurrence.status == OccurrenceStatus.completed.dbValue
          ? 'Open the completed workout to review its details.'
          : occurrence.status == OccurrenceStatus.partiallyCompleted.dbValue
          ? 'Open the partially completed workout to review its details.'
          : occurrence.status == OccurrenceStatus.skipped.dbValue
          ? 'This workout was skipped.'
          : 'Open details for this workout.',
      child: Dismissible(
        key: ValueKey('workout-contextual-${occurrence.id}'),
        direction: (_canLaunch && isToday)
            ? DismissDirection.horizontal
            : DismissDirection.none,
        movementDuration: B05MotionPolicy.transitionDuration(context),
        confirmDismiss: _onSwipe,
        background: _SwipeBackground(
          alignment: Alignment.centerLeft,
          icon: _isInProgress ? Icons.play_arrow_rounded : Icons.check_rounded,
          label: _isInProgress ? 'Resume workout' : 'Start workout',
          role: colors.info,
        ),
        secondaryBackground: _SwipeBackground(
          alignment: Alignment.centerRight,
          icon: Icons.skip_next_rounded,
          label: 'Skip workout',
          role: colors.warning,
        ),
        child: B05Surface(
          padding: const EdgeInsets.all(B05Layout.space12),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: status.container,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(B05Layout.space8),
                        child: Icon(
                          _statusIcon(occurrence.status, isOverdue: item.isOverdue),
                          color: status.indicator,
                        ),
                      ),
                    ),
                    const SizedBox(width: B05Layout.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.template.name,
                            style: B05Typography.title(context),
                          ),
                          const SizedBox(height: B05Layout.space4),
                          Text(
                            _detailsLabel(item),
                            style: B05Typography.body(context),
                          ),
                        ],
                      ),
                    ),
                    B05IconAction(
                      icon: Icons.more_horiz_rounded,
                      label: 'More actions for ${item.template.name}',
                      hint:
                          'Opens workout details and other supported actions.',
                      onPressed: busy ? null : widget.onOpenDetails,
                      focusOrder: 4,
                    ),
                  ],
                ),
                const SizedBox(height: B05Layout.space12),
                Semantics(
                  label: 'Workout status',
                  value: spokenStatus,
                  child: Text(
                    spokenStatus,
                    style: B05Typography.label(
                      context,
                    ).copyWith(color: status.foreground),
                  ),
                ),
                const SizedBox(height: B05Layout.space12),
                if (_canLaunch)
                  B05ActionGroup(
                    children: [
                      B05ActionButton(
                        label: _isInProgress
                            ? 'Resume workout'
                            : 'Start workout',
                        hint: _isInProgress
                            ? 'Resumes this existing workout draft.'
                            : isFuture
                            ? 'Starts this scheduled future workout in the player.'
                            : 'Starts this scheduled workout in the player.',
                        icon: _isInProgress
                            ? Icons.play_arrow_rounded
                            : Icons.check_circle_outline_rounded,
                        onPressed: busy ? null : _startOrResume,
                        focusOrder: 1,
                      ),
                      if (_isStartable)
                        B05ActionButton(
                          label: 'Skip workout',
                          hint:
                              'Choose whether to keep this workout pending or advance progression.',
                          icon: Icons.skip_next_rounded,
                          emphasis: B05ActionEmphasis.secondary,
                          onPressed: busy ? null : _confirmSkip,
                          focusOrder: 2,
                        ),
                      const WorkoutPlaylistLauncherSlot(),
                    ],
                  )
                else if (occurrence.status ==
                        OccurrenceStatus.completed.dbValue ||
                    occurrence.status ==
                        OccurrenceStatus.partiallyCompleted.dbValue)
                  B05ActionGroup(
                    children: [
                      B05ActionButton(
                        label: 'View workout',
                        hint: 'Review this workout.',
                        icon: Icons.open_in_new_rounded,
                        onPressed: busy
                            ? null
                            : () {
                                dismissIndiFitFeedback(context);
                                widget.onOpenDetails();
                              },
                      ),
                    ],
                  )
                else if (occurrence.status == OccurrenceStatus.skipped.dbValue ||
                    occurrence.status == OccurrenceStatus.cancelled.dbValue)
                  B05ActionGroup(
                    children: [
                      B05ActionButton(
                        label: 'Restore to plan',
                        hint: 'Restores this workout to your plan.',
                        icon: Icons.undo_rounded,
                        emphasis: B05ActionEmphasis.secondary,
                        onPressed: busy
                            ? null
                            : () async {
                                dismissIndiFitFeedback(context);
                                await ref
                                    .read(calendarControllerProvider.notifier)
                                    .restoreOccurrence(occurrence.id);
                              },
                      ),
                    ],
                  )
                else
                  const B05StatusMessage(
                    status: B05SemanticStatus.unavailable,
                    label: 'Workout actions unavailable',
                    value:
                        'Open details to review history and supported actions.',
                  ),
                if (busy) ...[
                  const SizedBox(height: B05Layout.space8),
                  const B05StatusMessage(
                    status: B05SemanticStatus.info,
                    label: 'Updating workout',
                    value: 'Please wait before trying another action.',
                  ),
                ],
                if (_launchError != null) ...[
                  const SizedBox(height: B05Layout.space8),
                  B05StatusMessage(
                    status: B05SemanticStatus.danger,
                    label: 'Workout unavailable',
                    value: _launchError,
                  ),
                  const SizedBox(height: B05Layout.space8),
                  B05ActionButton(
                    label: 'Retry workout',
                    emphasis: B05ActionEmphasis.secondary,
                    onPressed: _startOrResume,
                  ),
                ],
                if (actionState.status ==
                        WorkoutOccurrenceActionStatus.failure ||
                    actionState.status ==
                        WorkoutOccurrenceActionStatus.unavailable) ...[
                  const SizedBox(height: B05Layout.space8),
                  B05StatusMessage(
                    status:
                        actionState.status ==
                            WorkoutOccurrenceActionStatus.failure
                        ? B05SemanticStatus.danger
                        : B05SemanticStatus.unavailable,
                    label:
                        actionState.status ==
                            WorkoutOccurrenceActionStatus.failure
                        ? 'Could not update workout'
                        : 'Workout action unavailable',
                    value: actionState.message,
                  ),
                  if (actionState.canRetry) ...[
                    const SizedBox(height: B05Layout.space8),
                    B05ActionButton(
                      label: 'Retry workout action',
                      emphasis: B05ActionEmphasis.secondary,
                      onPressed: () async {
                        await ref
                            .read(
                              workoutOccurrenceActionControllerProvider(
                                occurrence.id,
                              ).notifier,
                            )
                            .retry();
                        if (mounted) await _reconcile();
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _detailsLabel(
    CalendarOccurrenceReadItem item,
  ) {
    final occurrence = item.occurrence;
    return '${ConsumerDateLabel.day(occurrence.effectiveLocalDate)} • ${item.block.name} • Week ${item.week.programWeekOrdinal + 1}'
        '${item.isDeload ? ' • Deload' : ''}'
        '${item.isOverdue ? ' • Overdue' : ''}';
  }

  static B05ColorRole _statusFor(
    B05SemanticColors colors,
    String status,
    bool isDeload,
    bool isOverdue,
  ) {
    if (isOverdue) return colors.warning;
    if (isDeload) return colors.info;
    return switch (status) {
      'completed' => colors.success,
      'partiallyCompleted' => colors.info,
      'inProgress' => colors.info,
      'rescheduled' => colors.warning,
      'skipped' => colors.unavailable,
      'cancelled' => colors.danger,
      _ => colors.info,
    };
  }

  static IconData _statusIcon(String status, {required bool isOverdue}) {
    if (isOverdue) return Icons.warning_amber_rounded;
    return switch (status) {
      'completed' => Icons.check_circle_rounded,
      'partiallyCompleted' => Icons.pie_chart_outline_rounded,
      'inProgress' => Icons.play_circle_fill_rounded,
      'skipped' => Icons.skip_next_rounded,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.fitness_center_rounded,
    };
  }

  static String _spokenStatus(
    String status, {
    required bool isOverdue,
    required bool isToday,
    required bool isFuture,
  }) {
    if (isOverdue) return 'Overdue';
    return switch (status) {
      'planned' => isToday
          ? 'Planned for today'
          : isFuture
          ? 'Scheduled'
          : 'Planned',
      'rescheduled' => isToday
          ? 'Rescheduled for today'
          : isFuture
          ? 'Rescheduled'
          : 'Rescheduled',
      'completed' => 'Completed',
      'partiallyCompleted' => 'Partially completed',
      'inProgress' => 'In progress',
      'skipped' => 'Skipped',
      'cancelled' => 'Cancelled',
      _ => 'Status not available',
    };
  }
}

/// B05-08 owns the playlist behavior; this retained slot keeps the launcher
/// in the contextual workout action group without changing B01 occurrence
/// semantics.
class WorkoutPlaylistLauncherSlot extends StatelessWidget {
  const WorkoutPlaylistLauncherSlot({super.key});

  @override
  Widget build(BuildContext context) => const B05PlaylistLauncherButton();
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.role,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final B05ColorRole role;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: role.container,
      borderRadius: B05Radii.mediumRadius,
    ),
    child: Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space20),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: alignment == Alignment.centerLeft
                ? [
                    Icon(icon, color: role.indicator),
                    const SizedBox(width: B05Layout.space8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: role.foreground),
                      ),
                    ),
                  ]
                : [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(color: role.foreground),
                      ),
                    ),
                    const SizedBox(width: B05Layout.space8),
                    Icon(icon, color: role.indicator),
                  ],
          ),
        ),
      ),
    ),
  );
}
