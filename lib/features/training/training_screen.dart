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
import '../../data/repositories/workout_repository.dart';
import '../calendar/program_calendar_screen.dart';
import '../calendar/workout_contextual_launcher.dart';
import '../exercise_library/exercise_library_screen.dart';
import '../travel/travel_mode_screen.dart';
import '../workout_player/b02_strength_execution_controller.dart';
import '../workout_player/b02_strength_player_screen.dart';
import '../workout_player/routine_display_screen.dart';
import '../workout_player/widgets/manual_log_sheet.dart';

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
    this.activeStrengthDraft,
  });

  final String localDate;
  final String timezoneId;
  final CalendarOccurrenceReadItem? todayWorkout;
  final List<CalendarOccurrenceReadItem> upcoming;
  final List<WorkoutSession> recentSessions;
  final String? activeProgramName;
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
      final calendarRepository = ref.watch(calendarReadRepositoryProvider);
      final invalidation = calendarRepository.watchInvalidation(
        startLocalDate: localDate,
        endLocalDate: endDate,
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
        startLocalDate: localDate,
        endLocalDate: endDate,
        timezoneId: timezoneId,
      );
      final sessions = await workoutRepository.getSessions();
      final activeDraft = await workoutRepository.getActiveDraft();
      final today = selectTrainingTodayWorkout(
        calendar.rangeOccurrences,
        localDate,
      );
      final upcoming = calendar.rangeOccurrences
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
        activeStrengthDraft:
            activeDraft?.activityType == 'strength' &&
                activeDraft?.executionStateJson != null &&
                activeDraft?.scheduledOccurrenceId == null
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
          onResumeDraft: data.activeStrengthDraft == null
              ? null
              : () => _resumeDraft(context, ref, data.activeStrengthDraft!),
          onOpenPlan: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoutineDisplayScreen()),
          ),
          onOpenCalendar: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProgramCalendarScreen()),
          ),
          onOpenExercises: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
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

class _TrainingLandingBody extends StatelessWidget {
  const _TrainingLandingBody({
    required this.data,
    required this.isLaunching,
    required this.onStartWorkout,
    required this.onStartTraining,
    required this.onResumeDraft,
    required this.onOpenPlan,
    required this.onOpenCalendar,
    required this.onOpenExercises,
    required this.onLogWorkout,
  });

  final TrainingLandingSnapshot data;
  final bool isLaunching;
  final ValueChanged<CalendarOccurrenceReadItem> onStartWorkout;
  final VoidCallback onStartTraining;
  final VoidCallback? onResumeDraft;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenExercises;
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
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: Text('Resume ${data.activeStrengthDraft!.routineName}'),
              subtitle: const Text(
                'Your exercises, sets, and active time are saved.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onResumeDraft,
            ),
          ),
          const SizedBox(height: B05Layout.space16),
        ],
        _SectionLabel(label: 'TODAY'),
        const SizedBox(height: B05Layout.space8),
        _TodayTrainingSurface(
          item: today,
          isLaunching: isLaunching,
          onStart: today == null || !canLaunchTrainingOccurrence(today)
              ? onStartTraining
              : onStartTraining,
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
                      data.activeProgramName ?? 'No training plan yet',
                      style: B05Typography.title(context),
                    ),
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      data.activeProgramName == null
                          ? 'Choose a plan or build one when you’re ready.'
                          : _planContextLabel(planContext),
                      style: B05Typography.body(context),
                    ),
                  ],
                ),
              ),
              B05IconAction(
                icon: Icons.chevron_right_rounded,
                label: 'View training plan',
                onPressed: onOpenPlan,
              ),
            ],
          ),
        ),
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
}

class _TodayTrainingSurface extends StatelessWidget {
  const _TodayTrainingSurface({
    required this.item,
    required this.isLaunching,
    required this.onStart,
    required this.onOpenPlan,
    required this.onLogWorkout,
  });

  final CalendarOccurrenceReadItem? item;
  final bool isLaunching;
  final VoidCallback? onStart;
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
              'Choose a workout or enjoy a recovery day.',
              style: B05Typography.body(context),
            ),
            const SizedBox(height: B05Layout.space12),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space12),
          if (isCompleted)
            Text(
              'Workout complete for today.',
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
