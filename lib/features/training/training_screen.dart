import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/program_lifecycle_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../calendar/program_calendar_screen.dart';
import '../calendar/workout_contextual_launcher.dart';
import '../exercise_library/exercise_library_screen.dart';
import '../travel/travel_mode_screen.dart';
import '../workout_player/b02_strength_execution_controller.dart';
import '../workout_player/b02_strength_player_screen.dart';
import '../workout_player/routine_display_screen.dart';
import '../workout_player/widgets/manual_log_sheet.dart';
import 'training_plan_lifecycle_controller.dart';
import 'workout_history_screen.dart';

/// Read-only, presentation-ready data for the Training landing page.
///
/// Calendar and workout history remain owned by their existing repositories;
/// this model only gives the consumer landing page one coherent read boundary.
class TrainingLandingSnapshot {
  const TrainingLandingSnapshot({
    required this.localDate,
    required this.timezoneId,
    required this.todayWorkout,
    required this.upcoming,
    required this.recentSessions,
    required this.activeProgramName,
    this.currentWeekStartLocalDate,
    this.currentWeekOccurrences = const [],
    this.lastEndedProgramName,
    this.lastEndedOutcome,
    this.activeStrengthDraft,
  });

  final String localDate;
  final String timezoneId;
  final CalendarOccurrenceReadItem? todayWorkout;
  final List<CalendarOccurrenceReadItem> upcoming;
  final List<WorkoutSession> recentSessions;
  final String? activeProgramName;
  final String? currentWeekStartLocalDate;
  final List<CalendarOccurrenceReadItem> currentWeekOccurrences;
  final String? lastEndedProgramName;
  final String? lastEndedOutcome;
  final WorkoutDraft? activeStrengthDraft;

  CalendarOccurrenceReadItem? get currentPlanContext =>
      todayWorkout ?? (upcoming.isEmpty ? null : upcoming.first);
}

/// The landing can only launch an occurrence that remains actionable in B01.
/// Completed and retired occurrences stay readable elsewhere, never startable.
bool canLaunchTrainingOccurrence(CalendarOccurrenceReadItem item) {
  final status = item.occurrence.status;
  return status == 'planned' ||
      status == 'rescheduled' ||
      status == 'inProgress';
}

/// Picks the single Today card without hiding an in-progress workout behind a
/// completed or later planned occurrence on the same local date.
CalendarOccurrenceReadItem? selectTrainingTodayWorkout(
  Iterable<CalendarOccurrenceReadItem> occurrences,
  String localDate,
) {
  CalendarOccurrenceReadItem? selected;
  for (final item in occurrences) {
    final status = item.occurrence.status;
    if (item.occurrence.effectiveLocalDate != localDate ||
        status == 'cancelled' ||
        status == 'skipped') {
      continue;
    }
    if (selected == null ||
        _todayWorkoutPriority(item) > _todayWorkoutPriority(selected)) {
      selected = item;
    }
  }
  return selected;
}

int _todayWorkoutPriority(CalendarOccurrenceReadItem item) =>
    switch (item.occurrence.status) {
      'inProgress' => 3,
      'planned' || 'rescheduled' => 2,
      'completed' || 'partiallyCompleted' => 1,
      _ => 0,
    };

final trainingLandingSnapshotProvider =
    FutureProvider.autoDispose<TrainingLandingSnapshot>((ref) async {
      final dates = ref.watch(localScheduleDateServiceProvider);
      final timezoneId = await ref
          .watch(localTimezoneServiceProvider)
          .currentTimezoneId();
      final localDate = dates.todayIn(timezoneId);
      final endDate = dates.addCalendarDays(localDate, timezoneId, 14);
      final weekStart = dates.addCalendarDays(
        localDate,
        timezoneId,
        -(dates.weekday(localDate, timezoneId) - 1),
      );
      final weekEnd = dates.addCalendarDays(weekStart, timezoneId, 6);
      final snapshotEnd = dates.compare(endDate, weekEnd) >= 0
          ? endDate
          : weekEnd;
      final calendarRepository = ref.watch(calendarReadRepositoryProvider);
      final invalidation = calendarRepository.watchInvalidation(
        startLocalDate: weekStart,
        endLocalDate: snapshotEnd,
        timezoneId: timezoneId,
      );
      final invalidationSubscription = invalidation.listen(
        (_) => ref.invalidateSelf(),
      );
      ref.onDispose(invalidationSubscription.cancel);
      final workoutRepository = ref.watch(workoutRepositoryProvider);
      final draftSubscription = workoutRepository
          .watchActiveDraftInvalidation()
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(draftSubscription.cancel);
      final calendar = await calendarRepository.readSnapshot(
        startLocalDate: weekStart,
        endLocalDate: snapshotEnd,
        timezoneId: timezoneId,
      );
      final sessions = await workoutRepository.getSessions();
      final activeDraft = await workoutRepository.getActiveDraft();
      final today = selectTrainingTodayWorkout(
        calendar.rangeOccurrences,
        localDate,
      );
      final activeOccurrences = calendar.activeProgramVersionId == null
          ? const <CalendarOccurrenceReadItem>[]
          : calendar.rangeOccurrences
                .where(
                  (item) =>
                      item.occurrence.programVersionId ==
                      calendar.activeProgramVersionId,
                )
                .toList(growable: false);
      final upcoming = activeOccurrences
          .where(
            (item) =>
                item.occurrence.effectiveLocalDate.compareTo(localDate) > 0 &&
                canLaunchTrainingOccurrence(item),
          )
          .take(3)
          .toList(growable: false);
      return TrainingLandingSnapshot(
        localDate: localDate,
        timezoneId: timezoneId,
        todayWorkout: today,
        upcoming: upcoming,
        recentSessions: sessions.take(3).toList(growable: false),
        activeProgramName: calendar.activeProgramName,
        currentWeekStartLocalDate: weekStart,
        currentWeekOccurrences: activeOccurrences
            .where(
              (item) =>
                  dates.compare(
                        item.occurrence.effectiveLocalDate,
                        weekStart,
                      ) >=
                      0 &&
                  dates.compare(item.occurrence.effectiveLocalDate, weekEnd) <=
                      0,
            )
            .toList(growable: false),
        lastEndedProgramName: calendar.lastEndedProgramName,
        lastEndedOutcome: calendar.lastEndedOutcome,
        activeStrengthDraft:
            activeDraft?.activityType == 'strength' &&
                activeDraft?.executionStateJson != null
            ? activeDraft
            : null,
      );
    });

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  var _isLaunching = false;
  var _isEndingPlan = false;

  Future<void> _openStartWorkout(
    BuildContext context,
    WidgetRef ref,
    TrainingLandingSnapshot data,
  ) async {
    final today = data.todayWorkout;
    final activeDraft = data.activeStrengthDraft;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            B05Layout.space8,
            B05Layout.space8,
            B05Layout.space8,
            B05Layout.space16,
          ),
          children: [
            const ListTile(
              title: Text('Start workout'),
              subtitle: Text('Train right now or follow today’s plan.'),
            ),
            if (activeDraft != null)
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: Text('Resume ${activeDraft.routineName}'),
                subtitle: const Text('Continue your saved workout first.'),
                onTap: () => Navigator.pop(sheetContext, 'resume'),
              ),
            if (today != null && canLaunchTrainingOccurrence(today))
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text('Today’s workout · ${today.template.name}'),
                subtitle: const Text('Use the scheduled workout and targets.'),
                onTap: () => Navigator.pop(sheetContext, 'today'),
              ),
            if (activeDraft == null)
              ListTile(
                leading: const Icon(Icons.bolt_rounded),
                title: const Text('Quick workout'),
                subtitle: const Text(
                  'Start immediately and choose exercises as you go.',
                ),
                onTap: () => Navigator.pop(sheetContext, 'quick'),
              ),
            ListTile(
              leading: const Icon(Icons.route_outlined),
              title: const Text('Choose a plan'),
              subtitle: const Text(
                'Review or build a training plan for later.',
              ),
              onTap: () => Navigator.pop(sheetContext, 'plan'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'resume':
        if (activeDraft != null) {
          await _resumeDraft(context, ref, activeDraft);
        }
      case 'quick':
        await context.push('/quick-workout');
      case 'today':
        if (today != null) await _startWorkout(context, ref, today);
      case 'plan':
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RoutineDisplayScreen()));
    }
    if (context.mounted) ref.invalidate(trainingLandingSnapshotProvider);
  }

  Future<void> _showPlanActions(
    BuildContext context,
    WidgetRef ref,
    TrainingLandingSnapshot data,
  ) async {
    if (_isEndingPlan || data.activeProgramName == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            B05Layout.space8,
            B05Layout.space8,
            B05Layout.space8,
            B05Layout.space16,
          ),
          children: [
            ListTile(
              title: Text(data.activeProgramName!),
              subtitle: const Text('Manage your current training plan.'),
            ),
            ListTile(
              leading: const Icon(Icons.route_outlined),
              title: const Text('View plan'),
              onTap: () => Navigator.pop(sheetContext, 'plan'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('View calendar'),
              onTap: () => Navigator.pop(sheetContext, 'calendar'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Finish plan'),
              subtitle: const Text(
                'Stop future workouts and keep your history.',
              ),
              onTap: () => Navigator.pop(sheetContext, 'finish'),
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app_rounded),
              title: const Text('Leave plan'),
              subtitle: const Text('Stop using this plan for now.'),
              onTap: () => Navigator.pop(sheetContext, 'leave'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'plan':
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RoutineDisplayScreen()));
      case 'calendar':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProgramCalendarScreen()),
        );
      case 'finish':
        await _confirmEndPlan(context, ref, data, PlanEndOutcome.finished);
      case 'leave':
        await _confirmEndPlan(context, ref, data, PlanEndOutcome.left);
    }
    if (context.mounted) ref.invalidate(trainingLandingSnapshotProvider);
  }

  Future<void> _confirmEndPlan(
    BuildContext context,
    WidgetRef ref,
    TrainingLandingSnapshot data,
    PlanEndOutcome outcome,
  ) async {
    final isFinish = outcome == PlanEndOutcome.finished;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isFinish ? 'Finish plan?' : 'Leave plan?'),
        content: Text(
          isFinish
              ? 'Future workouts in ${data.activeProgramName} will stop. Completed and partially completed workouts stay in your history.'
              : 'Future workouts in ${data.activeProgramName} will stop. Your completed workout history stays saved, and you can choose another plan later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isFinish ? 'Finish plan' : 'Leave plan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted || _isEndingPlan) return;
    setState(() => _isEndingPlan = true);
    try {
      final controller = ref.read(trainingPlanLifecycleControllerProvider);
      final result = isFinish
          ? await controller.finishPlan()
          : await controller.leavePlan();
      if (!context.mounted) return;
      final count = result.cancelledOccurrenceIds.length;
      final stoppedLabel = count == 0
          ? 'Future workouts are no longer scheduled.'
          : '$count future ${count == 1 ? 'workout' : 'workouts'} stopped.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFinish
                ? 'Plan finished. $stoppedLabel'
                : 'Plan left. Your workout history is still here.',
          ),
        ),
      );
      ref.invalidate(trainingLandingSnapshotProvider);
    } on ProgramLifecycleException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_planLifecycleFailureMessage(error))),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan action unavailable. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _isEndingPlan = false);
    }
  }

  Future<void> _resumeDraft(
    BuildContext context,
    WidgetRef ref,
    WorkoutDraft draft,
  ) async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);
    try {
      final controller = ref.read(
        b02StrengthExecutionControllerProvider.notifier,
      );
      await controller.recover(draft.id);
      final recovered = ref.read(b02StrengthExecutionControllerProvider);
      if (!context.mounted) return;
      if (recovered.launch == null ||
          recovered.status == B02StrengthExecutionStatus.recovery ||
          recovered.status == B02StrengthExecutionStatus.failure) {
        throw StateError('The saved workout could not be recovered.');
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => B02StrengthPlayerScreen(launch: recovered.launch!),
        ),
      );
      if (context.mounted) ref.invalidate(trainingLandingSnapshotProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved workout unavailable. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  Future<void> _startWorkout(
    BuildContext context,
    WidgetRef ref,
    CalendarOccurrenceReadItem item,
  ) async {
    if (_isLaunching || !canLaunchTrainingOccurrence(item)) return;
    setState(() => _isLaunching = true);
    try {
      final needsConfirmation =
          WorkoutContextualLauncher.requiresDateConfirmation(ref, item);
      if (needsConfirmation) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Start outside scheduled date?'),
            content: Text(
              'This workout is scheduled for ${ConsumerDateLabel.day(item.occurrence.effectiveLocalDate)}. Starting it will not change your plan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  item.occurrence.status == 'inProgress'
                      ? 'Resume workout'
                      : 'Start workout',
                ),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
      }
      final target = await WorkoutContextualLauncher.prepare(
        ref: ref,
        item: item,
        confirmedOutsideEffectiveDate: needsConfirmation,
      );
      if (!context.mounted) return;
      await WorkoutContextualLauncher.push(context, target);
      if (context.mounted) ref.invalidate(trainingLandingSnapshotProvider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout unavailable. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  Future<void> _logWorkout(
    BuildContext context,
    TrainingLandingSnapshot data,
  ) async {
    final logged = await showIndiFitBottomSheet<bool>(
      context: context,
      semanticLabel: 'Log completed workout',
      builder: (_) => ManualLogSheet(
        selectedDate: DateTime.parse('${data.localDate}T12:00:00'),
      ),
    );
    if (logged == true && mounted) {
      ref.invalidate(trainingLandingSnapshotProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(trainingLandingSnapshotProvider);
    final hasActiveProgram =
        snapshot.asData?.value.activeProgramName?.trim().isNotEmpty == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training'),
        actions: [
          B05IconAction(
            icon: Icons.more_horiz_rounded,
            label: 'More training options',
            hint: 'Open advanced training tools.',
            onPressed: () =>
                _showMore(context, ref, hasActiveProgram: hasActiveProgram),
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(B05Layout.space16),
          child: ConsumerStatusRow(
            label: 'Loading training',
            detail: 'Finding today’s workout and your plan.',
            loading: true,
          ),
        ),
        error: (_, stackTrace) => Padding(
          padding: const EdgeInsets.all(B05Layout.space16),
          child: ProductEmptyState(
            icon: Icons.fitness_center_outlined,
            title: 'Training is unavailable',
            message: 'Try again to load your plan and workouts.',
            action: () => ref.invalidate(trainingLandingSnapshotProvider),
            actionLabel: 'Try again',
            actionIcon: Icons.refresh_rounded,
          ),
        ),
        data: (data) => _TrainingLandingBody(
          data: data,
          isLaunching: _isLaunching,
          onStartWorkout: (item) => _startWorkout(context, ref, item),
          onStartTraining: () => _openStartWorkout(context, ref, data),
          onStartQuickWorkout: () => context.push('/quick-workout'),
          onResumeDraft: data.activeStrengthDraft == null
              ? null
              : () => _resumeDraft(context, ref, data.activeStrengthDraft!),
          onOpenPlan: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoutineDisplayScreen()),
          ),
          onOpenPlanActions: () => _showPlanActions(context, ref, data),
          onOpenCalendar: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProgramCalendarScreen()),
          ),
          onOpenExercises: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
          ),
          onOpenHistory: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WorkoutHistoryScreen()),
          ),
          onLogWorkout: () => _logWorkout(context, data),
        ),
      ),
    );
  }

  void _showMore(
    BuildContext context,
    WidgetRef ref, {
    required bool hasActiveProgram,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: B05Surface(
          radius: B05SurfaceRadius.large,
          padding: const EdgeInsets.fromLTRB(
            B05Layout.space16,
            B05Layout.space12,
            B05Layout.space16,
            B05Layout.space16,
          ),
          child: Wrap(
            runSpacing: B05Layout.space4,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: const Text('Manage plan'),
                subtitle: const Text('Create or edit your training plan.'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RoutineDisplayScreen(),
                    ),
                  );
                },
              ),
              if (hasActiveProgram)
                ListTile(
                  leading: const Icon(Icons.flight_outlined),
                  title: const Text('Travel mode'),
                  subtitle: const Text('Adjust training for a trip.'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TravelModeScreen(),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Equipment and preferences'),
                subtitle: const Text('Fine-tune advanced training options.'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/equipment-profiles');
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('Log completed workout'),
                subtitle: const Text('Add a workout you already finished.'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final data = ref
                      .read(trainingLandingSnapshotProvider)
                      .asData
                      ?.value;
                  if (data != null) _logWorkout(context, data);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _planLifecycleFailureMessage(ProgramLifecycleException error) {
  if (error.code == 'blocked') return error.message;
  if (error.code == 'no_active_plan') {
    return 'This plan is no longer active. Refresh Training to see the next step.';
  }
  return 'Plan action unavailable. Try again.';
}

class _TrainingLandingBody extends StatelessWidget {
  const _TrainingLandingBody({
    required this.data,
    required this.isLaunching,
    required this.onStartWorkout,
    required this.onStartTraining,
    required this.onStartQuickWorkout,
    required this.onResumeDraft,
    required this.onOpenPlan,
    required this.onOpenPlanActions,
    required this.onOpenCalendar,
    required this.onOpenExercises,
    required this.onOpenHistory,
    required this.onLogWorkout,
  });

  final TrainingLandingSnapshot data;
  final bool isLaunching;
  final ValueChanged<CalendarOccurrenceReadItem> onStartWorkout;
  final VoidCallback onStartTraining;
  final VoidCallback onStartQuickWorkout;
  final VoidCallback? onResumeDraft;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenPlanActions;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenExercises;
  final VoidCallback onOpenHistory;
  final VoidCallback onLogWorkout;

  @override
  Widget build(BuildContext context) {
    final today = data.todayWorkout;
    final planContext = data.currentPlanContext;
    final isEmpty =
        today == null &&
        data.upcoming.isEmpty &&
        data.recentSessions.isEmpty &&
        data.activeProgramName?.trim().isNotEmpty != true &&
        data.lastEndedOutcome == null &&
        data.activeStrengthDraft == null;
    if (isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          B05Layout.space16,
          B05Layout.space16,
          B05Layout.space32,
        ),
        children: [
          _SectionLabel(label: 'START TRAINING'),
          const SizedBox(height: B05Layout.space8),
          _TrainingEmptySurface(
            onStart: onStartTraining,
            onChoosePlan: onOpenPlan,
            onLogWorkout: onLogWorkout,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space16,
        B05Layout.space8,
        B05Layout.space16,
        B05Layout.space32,
      ),
      children: [
        if (data.activeStrengthDraft != null) ...[
          B05Surface(
            tone: B05SurfaceTone.selected,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      color: context.b05Colors.action,
                    ),
                    const SizedBox(width: B05Layout.space8),
                    Expanded(
                      child: Text(
                        'WORKOUT IN PROGRESS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: B05Typography.label(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: B05Layout.space8),
                Text(
                  data.activeStrengthDraft!.routineName,
                  style: B05Typography.title(context),
                ),
                const SizedBox(height: B05Layout.space4),
                Text(
                  'Your exercises, sets, and active time are saved.',
                  style: B05Typography.body(context),
                ),
                const SizedBox(height: B05Layout.space12),
                SizedBox(
                  width: double.infinity,
                  child: B05ActionButton(
                    label: 'Resume ${data.activeStrengthDraft!.routineName}',
                    onPressed: onResumeDraft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: B05Layout.space16),
        ],
        _SectionLabel(label: 'TODAY'),
        const SizedBox(height: B05Layout.space8),
        _TodayTrainingSurface(
          item: today,
          isLaunching: isLaunching,
          hasActiveDraft: data.activeStrengthDraft != null,
          onStart: today == null || !canLaunchTrainingOccurrence(today)
              ? onStartTraining
              : onStartTraining,
          onStartQuickWorkout: onStartQuickWorkout,
          onOpenPlan: onOpenPlan,
          onLogWorkout: onLogWorkout,
        ),
        const SizedBox(height: B05Layout.space20),
        _SectionLabel(label: 'CURRENT PLAN'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          tone: B05SurfaceTone.section,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.route_outlined, color: context.b05Colors.action),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.activeProgramName ??
                          _endedPlanTitle(data.lastEndedOutcome),
                      style: B05Typography.title(context),
                    ),
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      data.activeProgramName == null
                          ? data.lastEndedOutcome == null
                                ? 'Choose a plan or build one when you’re ready.'
                                : '${data.lastEndedProgramName ?? 'Your previous plan'} is saved in history. Choose another plan whenever you are ready.'
                          : _planContextLabel(planContext),
                      style: B05Typography.body(context),
                    ),
                  ],
                ),
              ),
              if (data.activeProgramName != null)
                B05IconAction(
                  icon: Icons.more_horiz_rounded,
                  label: 'Plan actions',
                  hint: 'View, switch, finish, or leave this plan.',
                  onPressed: onOpenPlanActions,
                )
              else
                B05IconAction(
                  icon: Icons.chevron_right_rounded,
                  label: 'Choose a training plan',
                  onPressed: onOpenPlan,
                ),
            ],
          ),
        ),
        if (data.activeProgramName != null) ...[
          const SizedBox(height: B05Layout.space20),
          _SectionLabel(label: 'THIS WEEK'),
          const SizedBox(height: B05Layout.space8),
          _TrainingWeekStrip(
            weekStartLocalDate:
                data.currentWeekStartLocalDate ??
                _mondayForLocalDate(data.localDate),
            occurrences: data.currentWeekOccurrences,
            localDate: data.localDate,
          ),
        ],
        const SizedBox(height: B05Layout.space20),
        _SectionLabel(label: 'UPCOMING'),
        const SizedBox(height: B05Layout.space8),
        if (data.upcoming.isEmpty)
          B05Surface(
            tone: B05SurfaceTone.inset,
            child: Text(
              'Nothing else is scheduled yet.',
              style: B05Typography.body(context),
            ),
          )
        else
          B05Surface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < data.upcoming.length; index++) ...[
                  _UpcomingTrainingRow(
                    item: data.upcoming[index],
                    onTap: isLaunching
                        ? null
                        : () => onStartWorkout(data.upcoming[index]),
                  ),
                  if (index < data.upcoming.length - 1)
                    Divider(height: 1, color: context.b05Colors.border),
                ],
              ],
            ),
          ),
        if (data.recentSessions.isNotEmpty) ...[
          const SizedBox(height: B05Layout.space8),
          Align(
            alignment: Alignment.centerLeft,
            child: B05ActionButton(
              label: 'View all history',
              icon: Icons.history_rounded,
              emphasis: B05ActionEmphasis.tertiary,
              onPressed: onOpenHistory,
            ),
          ),
        ],
        const SizedBox(height: B05Layout.space20),
        _SectionLabel(label: 'RECENT'),
        const SizedBox(height: B05Layout.space8),
        if (data.recentSessions.isEmpty)
          ProductEmptyState(
            icon: Icons.history_rounded,
            title: 'No exercise history yet',
            message: 'Complete a workout to start building history.',
          )
        else
          B05Surface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < data.recentSessions.length; index++)
                  _RecentTrainingRow(
                    session: data.recentSessions[index],
                    showDivider: index < data.recentSessions.length - 1,
                  ),
              ],
            ),
          ),
        const SizedBox(height: B05Layout.space20),
        _SectionLabel(label: 'EXPLORE'),
        const SizedBox(height: B05Layout.space8),
        Row(
          children: [
            Expanded(
              child: B05ActionButton(
                label: 'Exercises',
                icon: Icons.search_rounded,
                onPressed: onOpenExercises,
                emphasis: B05ActionEmphasis.secondary,
              ),
            ),
            const SizedBox(width: B05Layout.space8),
            Expanded(
              child: B05ActionButton(
                label: 'Calendar',
                icon: Icons.calendar_month_outlined,
                onPressed: onOpenCalendar,
                emphasis: B05ActionEmphasis.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _planContextLabel(CalendarOccurrenceReadItem? item) {
    if (item == null) return 'Your next workout will appear here.';
    final week = item.week.programWeekOrdinal + 1;
    final deload = item.isDeload ? ' · Deload week' : '';
    return 'Week $week$deload · ${item.template.name}';
  }

  static String _endedPlanTitle(String? outcome) => switch (outcome) {
    'finished' => 'Plan finished',
    'left' => 'Plan left',
    _ => 'No training plan yet',
  };

  static String _mondayForLocalDate(String localDate) {
    final date = DateTime.parse('${localDate}T12:00:00Z');
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }
}

class _TrainingWeekStrip extends StatelessWidget {
  const _TrainingWeekStrip({
    required this.weekStartLocalDate,
    required this.occurrences,
    required this.localDate,
  });

  final String weekStartLocalDate;
  final List<CalendarOccurrenceReadItem> occurrences;
  final String localDate;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse('${weekStartLocalDate}T12:00:00Z');
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.symmetric(
        horizontal: B05Layout.space8,
        vertical: B05Layout.space12,
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: _TrainingWeekDay(
                label: labels[index],
                date: start.add(Duration(days: index)),
                isToday:
                    _formatDate(start.add(Duration(days: index))) == localDate,
                occurrences: occurrences
                    .where(
                      (item) =>
                          item.occurrence.effectiveLocalDate ==
                          _formatDate(start.add(Duration(days: index))),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// Neutral label for a week-strip day with no occurrence. B01 records no
/// explicit rest evidence, so absence must not infer recovery intent.
const String trainingWeekEmptyDayLabel = 'no workout scheduled';

/// Semantic label for one week-strip day. Public for focused tests.
String trainingWeekDaySemanticLabel(
  String weekdayName,
  int day,
  String statusLabel,
  String? workoutName,
) =>
    '$weekdayName, $day: $statusLabel'
    '${workoutName == null ? '' : ', $workoutName'}';

class _TrainingWeekDay extends StatelessWidget {
  const _TrainingWeekDay({
    required this.label,
    required this.date,
    required this.isToday,
    required this.occurrences,
  });

  final String label;
  final DateTime date;
  final bool isToday;
  final List<CalendarOccurrenceReadItem> occurrences;

  @override
  Widget build(BuildContext context) {
    final status = _TrainingWeekStatus.from(occurrences);
    final colors = context.b05Colors;
    final workoutName = occurrences.isEmpty
        ? null
        : occurrences.first.template.name;
    return Semantics(
      label: trainingWeekDaySemanticLabel(
        _weekdayName(date.weekday),
        date.day,
        status.accessibleLabel,
        workoutName,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        decoration: BoxDecoration(
          color: isToday ? colors.selected : Colors.transparent,
          borderRadius: B05Radii.smallRadius,
          border: Border.all(
            color: isToday ? colors.action : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: B05Layout.space4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: B05Typography.caption(context).copyWith(
                color: isToday ? colors.action : colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: B05Layout.space4),
            Icon(status.icon, size: 18, color: status.color(context)),
            const SizedBox(height: B05Layout.space4),
            Text(
              '${date.day}',
              style: B05Typography.caption(context).copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekdayName(int weekday) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][weekday - 1];
}

enum _TrainingWeekStatus {
  rest,
  scheduled,
  inProgress,
  complete,
  partial,
  skipped,
  cancelled;

  IconData get icon => switch (this) {
    rest => Icons.circle_outlined,
    scheduled => Icons.event_outlined,
    inProgress => Icons.play_circle_outline_rounded,
    complete => Icons.check_circle_outline_rounded,
    partial => Icons.timelapse_rounded,
    skipped => Icons.skip_next_rounded,
    cancelled => Icons.remove_circle_outline_rounded,
  };

  String get accessibleLabel => switch (this) {
    // An empty day has no occurrence row: B01 does not record explicit
    // rest evidence, so the label stays neutral instead of inferring rest.
    rest => 'no workout scheduled',
    scheduled => 'scheduled',
    inProgress => 'in progress',
    complete => 'completed',
    partial => 'partially completed',
    skipped => 'skipped',
    cancelled => 'cancelled',
  };

  Color color(BuildContext context) => switch (this) {
    rest => context.b05Colors.textSecondary,
    scheduled => context.b05Colors.action,
    inProgress => context.b05Colors.action,
    complete => context.b05Colors.success.foreground,
    partial => context.b05Colors.warning.foreground,
    skipped => context.b05Colors.textSecondary,
    cancelled => context.b05Colors.textSecondary,
  };

  static _TrainingWeekStatus from(List<CalendarOccurrenceReadItem> items) {
    if (items.isEmpty) return rest;
    final statuses = items.map((item) => item.occurrence.status).toSet();
    if (statuses.contains('inProgress')) return inProgress;
    if (statuses.contains('planned') || statuses.contains('rescheduled')) {
      return scheduled;
    }
    if (statuses.contains('partiallyCompleted')) return partial;
    if (statuses.contains('completed')) return complete;
    if (statuses.contains('skipped')) return skipped;
    return cancelled;
  }
}

class _TodayTrainingSurface extends StatelessWidget {
  const _TodayTrainingSurface({
    required this.item,
    required this.isLaunching,
    required this.hasActiveDraft,
    required this.onStart,
    required this.onStartQuickWorkout,
    required this.onOpenPlan,
    required this.onLogWorkout,
  });

  final CalendarOccurrenceReadItem? item;
  final bool isLaunching;
  final bool hasActiveDraft;
  final VoidCallback? onStart;
  final VoidCallback onStartQuickWorkout;
  final VoidCallback onOpenPlan;
  final VoidCallback onLogWorkout;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return B05Surface(
        tone: B05SurfaceTone.inset,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.self_improvement_outlined,
              color: context.b05Colors.info.foreground,
            ),
            const SizedBox(height: B05Layout.space8),
            Text('Nothing planned today', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space4),
            Text(
              hasActiveDraft
                  ? 'Resume your saved workout before starting another.'
                  : 'Choose a workout or enjoy a recovery day.',
              style: B05Typography.body(context),
            ),
            if (!hasActiveDraft) ...[
              const SizedBox(height: B05Layout.space12),
              SizedBox(
                width: double.infinity,
                child: B05ActionButton(
                  label: 'Quick Workout',
                  icon: Icons.bolt_rounded,
                  onPressed: isLaunching ? null : onStartQuickWorkout,
                ),
              ),
            ],
            const SizedBox(height: B05Layout.space8),
            Wrap(
              spacing: B05Layout.space8,
              runSpacing: B05Layout.space8,
              children: [
                B05ActionButton(
                  label: 'View plan',
                  icon: Icons.route_outlined,
                  onPressed: onOpenPlan,
                  emphasis: B05ActionEmphasis.secondary,
                ),
                B05ActionButton(
                  label: 'Log workout',
                  icon: Icons.edit_note_rounded,
                  onPressed: onLogWorkout,
                  emphasis: B05ActionEmphasis.tertiary,
                ),
              ],
            ),
          ],
        ),
      );
    }
    final occurrence = item!.occurrence;
    final status = _statusLabel(occurrence.status);
    final isCompleted =
        occurrence.status == 'completed' ||
        occurrence.status == 'partiallyCompleted';
    final actionLabel = occurrence.status == 'inProgress'
        ? 'Resume workout'
        : 'Start workout';
    final prescriptionPreview = item!.prescriptions
        .take(2)
        .map(
          (prescription) =>
              '${prescription.exerciseNameSnapshot} · ${prescription.plannedSets} × ${prescription.repsRange}',
        )
        .join('  ·  ');
    return B05Surface(
      tone: B05SurfaceTone.selected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCompleted ? Icons.check_circle_outline : Icons.fitness_center,
                color: isCompleted
                    ? context.b05Colors.success.foreground
                    : context.b05Colors.action,
              ),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item!.template.name,
                      style: B05Typography.title(context),
                    ),
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      '${item!.prescriptions.length} ${item!.prescriptions.length == 1 ? 'exercise' : 'exercises'} · $status',
                      style: B05Typography.body(context),
                    ),
                    if (!isCompleted && prescriptionPreview.isNotEmpty) ...[
                      const SizedBox(height: B05Layout.space4),
                      Text(
                        prescriptionPreview,
                        style: B05Typography.caption(context),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space12),
          if (isCompleted) ...[
            Text(
              'Workout complete for today.',
              style: B05Typography.body(context),
            ),
            const SizedBox(height: B05Layout.space12),
            if (hasActiveDraft)
              Text(
                'Resume your saved workout before starting another.',
                style: B05Typography.body(context),
              )
            else
              B05ActionButton(
                label: 'Quick Workout',
                icon: Icons.bolt_rounded,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: isLaunching ? null : onStartQuickWorkout,
              ),
          ] else if (hasActiveDraft)
            Text(
              'Resume your saved workout before starting today’s plan.',
              style: B05Typography.body(context),
            )
          else
            B05ActionButton(
              label: isLaunching ? 'Opening workout…' : actionLabel,
              icon: Icons.play_arrow_rounded,
              onPressed: isLaunching ? null : onStart,
            ),
        ],
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'inProgress' => 'in progress',
    'completed' => 'completed',
    'partiallyCompleted' => 'partially complete',
    'rescheduled' => 'rescheduled',
    _ => 'scheduled',
  };
}

class _TrainingEmptySurface extends StatelessWidget {
  const _TrainingEmptySurface({
    required this.onStart,
    required this.onChoosePlan,
    required this.onLogWorkout,
  });

  final VoidCallback onStart;
  final VoidCallback onChoosePlan;
  final VoidCallback onLogWorkout;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.fitness_center_outlined, color: context.b05Colors.action),
        const SizedBox(height: B05Layout.space8),
        Text('Nothing planned today', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space4),
        Text('No training plan yet', style: B05Typography.body(context)),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Start with one meaningful action.',
          style: B05Typography.body(context),
        ),
        const SizedBox(height: B05Layout.space16),
        SizedBox(
          width: double.infinity,
          child: B05ActionButton(
            label: 'Start quick workout',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ),
        const SizedBox(height: B05Layout.space8),
        Wrap(
          spacing: B05Layout.space8,
          runSpacing: B05Layout.space8,
          children: [
            B05ActionButton(
              label: 'View plan',
              icon: Icons.route_outlined,
              emphasis: B05ActionEmphasis.secondary,
              onPressed: onChoosePlan,
            ),
            B05ActionButton(
              label: 'Log workout',
              icon: Icons.edit_note_rounded,
              emphasis: B05ActionEmphasis.tertiary,
              onPressed: onLogWorkout,
            ),
          ],
        ),
      ],
    ),
  );
}

class _UpcomingTrainingRow extends StatelessWidget {
  const _UpcomingTrainingRow({required this.item, required this.onTap});

  final CalendarOccurrenceReadItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label:
        '${item.template.name}, ${ConsumerDateLabel.day(item.occurrence.effectiveLocalDate)}',
    onTap: onTap,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(B05Layout.space12),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: Text(
                ConsumerDateLabel.day(item.occurrence.effectiveLocalDate),
                style: B05Typography.caption(context),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.template.name, style: B05Typography.label(context)),
                  Text(
                    '${item.prescriptions.length} ${item.prescriptions.length == 1 ? 'exercise' : 'exercises'}',
                    style: B05Typography.caption(context),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _RecentTrainingRow extends StatelessWidget {
  const _RecentTrainingRow({required this.session, required this.showDivider});

  final WorkoutSession session;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        leading: Icon(Icons.history_rounded, color: context.b05Colors.action),
        title: Text(session.name, style: B05Typography.label(context)),
        subtitle: Text(
          '${ConsumerDateLabel.dateTime(session.completedAt)}${session.durationSeconds > 0 ? ' · ${session.durationSeconds ~/ 60} min' : ''}',
          style: B05Typography.caption(context),
        ),
      ),
      if (showDivider) Divider(height: 1, color: context.b05Colors.border),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: B05Typography.caption(context).copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: .8,
      color: context.b05Colors.textSecondary,
    ),
  );
}
