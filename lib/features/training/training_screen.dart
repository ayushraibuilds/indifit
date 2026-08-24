import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/workout_draft_codec.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/services/indifit_haptics.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/program_lifecycle_repository.dart';
import '../../data/repositories/training_next_action_resolver.dart';
import '../../data/repositories/workout_repository.dart';
import '../calendar/occurrence_actions_sheet.dart';
import '../calendar/program_calendar_screen.dart';
import '../calendar/workout_contextual_launcher.dart';
import '../exercise_library/exercise_library_screen.dart';
import '../workout_player/b02_strength_execution_controller.dart';
import '../workout_player/b02_strength_player_screen.dart';
import '../workout_player/routine_display_screen.dart';
import '../workout_player/widgets/manual_log_sheet.dart';
import '../workout_player/workout_player_screen.dart';
import 'training_plan_lifecycle_controller.dart';
import 'training_workout_preview.dart';
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
    this.activeDraft,
    this.activeStrengthDraft,
    this.nextActionResolution,
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
  final WorkoutDraft? activeDraft;
  final WorkoutDraft? activeStrengthDraft;

  /// The same current/next projection consumed by Today. Training keeps the
  /// read model alongside its legacy fixture fields so older callers can
  /// continue constructing snapshots while production uses one authority.
  final TrainingNextActionResolution? nextActionResolution;

  bool get hasActiveDraft =>
      nextActionResolution?.hasActiveDraft ??
      (activeDraft != null || activeStrengthDraft != null);

  CalendarOccurrenceReadItem? get currentPlanContext =>
      nextActionResolution?.dominantScheduledOccurrence ??
      todayWorkout ??
      (upcoming.isEmpty ? null : upcoming.first);
}

final trainingLandingSnapshotProvider =
    FutureProvider.autoDispose<TrainingLandingSnapshot>((ref) async {
      ref.watch(civilDateRevisionProvider);
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
          .watchTrainingInvalidation()
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(draftSubscription.cancel);
      final calendar = await calendarRepository.readSnapshot(
        startLocalDate: weekStart,
        endLocalDate: snapshotEnd,
        timezoneId: timezoneId,
      );
      final sessions = await workoutRepository.getSessions();
      final activeDraft = await workoutRepository.getActiveDraft();
      final resolution = resolveTrainingNextAction(
        snapshot: calendar,
        localDate: localDate,
        activeDraft: activeDraft,
      );
      final resumableDraft = resolution.activeDraft;
      final activeOccurrences = calendar.activeProgramVersionId == null
          ? const <CalendarOccurrenceReadItem>[]
          : calendar.rangeOccurrences
                .where(
                  (item) =>
                      item.occurrence.programVersionId ==
                      calendar.activeProgramVersionId,
                )
                .toList(growable: false);
      final today =
          resolution.currentOccurrence ??
          resolution.todayOccurrence ??
          resolution.overdueOccurrence ??
          resolution.todayCompletedOccurrence;
      final upcoming = resolution.upcomingOccurrences
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
        activeDraft: activeDraft,
        activeStrengthDraft: resumableDraft,
        nextActionResolution: resolution,
      );
    });

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  var _isLaunching = false;
  var _isOpeningPreview = false;
  var _isEndingPlan = false;

  static WorkoutDraft? _resumableDraftFor(TrainingLandingSnapshot data) {
    final resolution = data.nextActionResolution;
    if (resolution != null) return resolution.activeDraft;
    final draft = data.activeStrengthDraft;
    if (draft != null) return draft;
    final fallback = data.activeDraft;
    return fallback != null && isTrainingResumableDraft(fallback)
        ? fallback
        : null;
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
      if (isFinish) {
        unawaited(IndiFitHaptics.confirmation());
      } else {
        unawaited(IndiFitHaptics.warning());
      }
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
      if (draft.executionStateJson == null) {
        final repo = ref.read(workoutRepositoryProvider);
        final loggedCompanions = WorkoutDraftCodec.decodeLoggedSets(
          draft.loggedSetsJson,
        );
        final scheduledLaunch = draft.scheduledOccurrenceId == null
            ? null
            : await ref
                  .read(workoutExecutionCompatibilityAdapterProvider)
                  .resumeScheduledDraft(draft);
        final exercises =
            scheduledLaunch?.exercises ??
            await repo.getExercisesForRoutineName(draft.routineName);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkoutPlayerScreen(
              routineName: draft.routineName,
              exercises: exercises,
              initialExerciseIndex: draft.currentExerciseIndex,
              initialSetIndex: draft.currentSetIndex,
              initialElapsedSeconds: draft.elapsedSeconds,
              initialLoggedSets: loggedCompanions,
              scheduledOccurrenceId: scheduledLaunch?.occurrenceId,
              executionSnapshotJson: scheduledLaunch?.executionSnapshotJson,
              personalExerciseContextByName:
                  scheduledLaunch?.personalExerciseContextByName ?? const {},
            ),
          ),
        );
        if (context.mounted) ref.invalidate(trainingLandingSnapshotProvider);
        return;
      }
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
    } catch (error) {
      if (context.mounted) {
        final message = ProductFailurePresentation.fromError(
          error,
          title: 'Saved workout unavailable',
          code: 'workout_recovery_needed',
        ).message;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
    if (_isLaunching || !isActionableTrainingOccurrence(item)) return;
    final snapshotState = ref.read(trainingLandingSnapshotProvider);
    if (!snapshotState.hasValue ||
        snapshotState
                .requireValue
                .nextActionResolution
                ?.activeDraftReadAvailable ==
            false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Workout state unavailable. Try again before starting another workout.',
          ),
        ),
      );
      return;
    }
    final snapshotData = snapshotState.requireValue;
    final hasActiveDraft = snapshotData.hasActiveDraft;
    final resumableDraft = _resumableDraftFor(snapshotData);
    final currentOccurrenceId =
        snapshotData.nextActionResolution?.currentOccurrence?.occurrence.id;
    if (hasActiveDraft) {
      if (resumableDraft != null &&
          resumableDraft.scheduledOccurrenceId == item.occurrence.id &&
          (item.occurrence.status == 'inProgress' ||
              currentOccurrenceId == item.occurrence.id)) {
        await _resumeDraft(context, ref, resumableDraft);
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Finish or discard your active workout before starting another.',
            ),
          ),
        );
        return;
      }
    }
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
    } catch (error) {
      if (!context.mounted) return;
      final message = ProductFailurePresentation.fromError(
        error,
        title: 'Workout unavailable',
      ).message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  Future<void> _openWorkoutPreview(
    BuildContext context,
    WidgetRef ref,
    CalendarOccurrenceReadItem item,
  ) async {
    if (_isLaunching || _isOpeningPreview) return;
    if (!isActionableTrainingOccurrence(item) ||
        item.occurrence.status == 'inProgress') {
      return;
    }
    setState(() => _isOpeningPreview = true);
    try {
      final snapshotJson = await ref
          .read(calendarRepositoryProvider)
          .readWorkoutPreviewSnapshot(item.occurrence.id);
      final preview = TrainingWorkoutPreviewData.fromOccurrence(
        item,
        snapshotJson: snapshotJson,
      );
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrainingWorkoutPreviewScreen(
            preview: preview,
            onStartWorkout: () => _startWorkout(context, ref, item),
            onOpenScheduleActions: () =>
                _showOccurrenceActions(context, ref, item),
          ),
        ),
      );
      if (context.mounted) ref.invalidate(trainingLandingSnapshotProvider);
    } catch (error) {
      if (!context.mounted) return;
      final message = ProductFailurePresentation.fromError(
        error,
        title: 'Workout preview unavailable',
        code: 'workout_unavailable',
      ).message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isOpeningPreview = false);
    }
  }

  Future<void> _showOccurrenceActions(
    BuildContext context,
    WidgetRef ref,
    CalendarOccurrenceReadItem item,
  ) async {
    await showIndiFitBottomSheet<void>(
      context: context,
      semanticLabel: 'Workout actions',
      builder: (_) => OccurrenceActionsSheet(
        occurrenceItem: item,
        scheduleAdjustmentsOnly: true,
      ),
    );
    if (context.mounted) ref.invalidate(trainingLandingSnapshotProvider);
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
        !snapshot.isLoading &&
        snapshot.valueOrNull?.activeProgramName?.trim().isNotEmpty == true;
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
        skipLoadingOnRefresh: false,
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
        data: (data) => _DominantTrainingLandingBody(
          data: data,
          isLaunching: _isLaunching || _isOpeningPreview,
          onStartWorkout: (item) => _openWorkoutPreview(context, ref, item),
          onStartQuickWorkout: () => context.push('/quick-workout'),
          onResumeDraft: _resumableDraftFor(data) == null
              ? null
              : () => _resumeDraft(context, ref, _resumableDraftFor(data)!),
          onOpenPlan: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoutineDisplayScreen()),
          ),
          onOpenBuilder: () => context.push('/program-author'),
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
          onRetry: () => ref.invalidate(trainingLandingSnapshotProvider),
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
  return ProductFailurePresentation.fromError(error).message;
}

enum _TrainingActionKind {
  unavailable,
  resume,
  blocked,
  start,
  completed,
  partial,
  openDay,
  noPlan,
}

class _TrainingActionModel {
  const _TrainingActionModel({
    required this.kind,
    required this.title,
    required this.detail,
    this.occurrence,
    this.draft,
    this.primaryLabel,
    this.primaryIcon,
  });

  final _TrainingActionKind kind;
  final String title;
  final String detail;
  final CalendarOccurrenceReadItem? occurrence;
  final WorkoutDraft? draft;
  final String? primaryLabel;
  final IconData? primaryIcon;

  bool get showsQuickWorkout => switch (kind) {
    _TrainingActionKind.start ||
    _TrainingActionKind.completed ||
    _TrainingActionKind.partial ||
    _TrainingActionKind.openDay ||
    _TrainingActionKind.noPlan => true,
    _ => false,
  };
}

/// Presentation-only mapping of the shared current/next read. It contains no
/// scheduling queries or priority rules; those remain in the shared resolver.
_TrainingActionModel _trainingActionFor(TrainingLandingSnapshot data) {
  final resolution = data.nextActionResolution;
  if (resolution != null && !resolution.activeDraftReadAvailable) {
    return const _TrainingActionModel(
      kind: _TrainingActionKind.unavailable,
      title: 'Workout state unavailable',
      detail: 'Try again to check your active workout before starting another.',
      primaryLabel: 'Try again',
      primaryIcon: Icons.refresh_rounded,
    );
  }

  final rawDraft = data.activeDraft ?? data.activeStrengthDraft;
  final resumableDraft = resolution != null
      ? resolution.activeDraft
      : data.activeStrengthDraft ??
            (rawDraft != null && isTrainingResumableDraft(rawDraft)
                ? rawDraft
                : null);
  final hasActiveDraft = resolution?.hasActiveDraft ?? rawDraft != null;
  final currentOccurrence =
      resolution?.currentOccurrence ??
      (data.todayWorkout?.occurrence.status == 'inProgress'
          ? data.todayWorkout
          : null);
  final activePlan = resolution != null
      ? resolution.activeProgramVersionId != null
      : data.activeProgramName?.trim().isNotEmpty == true;
  final planned = activePlan
      ? resolution?.overdueOccurrence ??
            resolution?.todayOccurrence ??
            (data.todayWorkout != null &&
                    isActionableTrainingOccurrence(data.todayWorkout!)
                ? data.todayWorkout
                : null)
      : null;
  final matchingDraft =
      resumableDraft != null &&
      resumableDraft.scheduledOccurrenceId != null &&
      (resumableDraft.scheduledOccurrenceId ==
              currentOccurrence?.occurrence.id ||
          resumableDraft.scheduledOccurrenceId == planned?.occurrence.id ||
          (data.todayWorkout?.occurrence.status == 'inProgress' &&
              resumableDraft.scheduledOccurrenceId ==
                  data.todayWorkout?.occurrence.id));

  if (hasActiveDraft) {
    if (resumableDraft != null) {
      final detail = matchingDraft || planned == null
          ? 'Your saved workout is ready to continue.'
          : 'Finish this workout before starting another.';
      return _TrainingActionModel(
        kind: _TrainingActionKind.resume,
        title: resumableDraft.routineName,
        detail: detail,
        occurrence: currentOccurrence,
        draft: resumableDraft,
        primaryLabel: 'Resume workout',
        primaryIcon: Icons.play_arrow_rounded,
      );
    }
    return const _TrainingActionModel(
      kind: _TrainingActionKind.blocked,
      title: 'Workout in progress',
      detail: 'Finish or reopen your active workout before starting another.',
    );
  }

  // An in-progress occurrence without a readable matching draft is a
  // recovery state. It must never be downgraded to a Start button.
  if (currentOccurrence != null) {
    return const _TrainingActionModel(
      kind: _TrainingActionKind.blocked,
      title: 'Workout in progress',
      detail: 'This workout needs attention before you can start another.',
    );
  }

  if (planned != null) {
    final isOverdue =
        planned.isOverdue ||
        planned.occurrence.effectiveLocalDate.compareTo(data.localDate) < 0;
    final count = planned.prescriptions.length;
    final countLabel = '$count ${count == 1 ? 'exercise' : 'exercises'}';
    return _TrainingActionModel(
      kind: _TrainingActionKind.start,
      title: planned.template.name,
      detail:
          '${isOverdue ? 'Still pending' : 'Today'} · $countLabel · ${_trainingPlanContextLabel(planned)}',
      occurrence: planned,
      primaryLabel: 'Start workout',
      primaryIcon: Icons.play_arrow_rounded,
    );
  }

  final terminal =
      resolution?.todayCompletedOccurrence ??
      (data.todayWorkout?.occurrence.status == 'completed' ||
              data.todayWorkout?.occurrence.status == 'partiallyCompleted'
          ? data.todayWorkout
          : null);
  if (activePlan && terminal != null) {
    final isPartial = terminal.occurrence.status == 'partiallyCompleted';
    return _TrainingActionModel(
      kind: isPartial
          ? _TrainingActionKind.partial
          : _TrainingActionKind.completed,
      title: isPartial
          ? 'Workout partially completed'
          : 'Workout complete today',
      detail: isPartial
          ? 'Your progress is saved. No new workout starts from this state.'
          : 'Your workout is saved. Nothing else starts from this state.',
      occurrence: terminal,
    );
  }

  if (!activePlan) {
    final previous = data.lastEndedProgramName;
    return _TrainingActionModel(
      kind: _TrainingActionKind.noPlan,
      title: 'Set up your training plan',
      detail: previous == null
          ? 'Choose a plan or build one when you’re ready.'
          : '$previous is saved in history. Choose what you want to do next.',
      primaryLabel: 'Choose a plan',
      primaryIcon: Icons.route_outlined,
    );
  }

  return const _TrainingActionModel(
    kind: _TrainingActionKind.openDay,
    title: 'No workout planned today',
    detail:
        'Nothing needs your attention today. Use Quick Workout if you want to move.',
  );
}

String _trainingPlanContextLabel(CalendarOccurrenceReadItem? item) {
  if (item == null) return 'Your next workout will appear here.';
  final week = item.week.programWeekOrdinal + 1;
  final deload = item.isDeload ? ' · Deload week' : '';
  return 'Week $week$deload · ${item.template.name}';
}

String _trainingMondayForLocalDate(String localDate) {
  final date = DateTime.parse('${localDate}T12:00:00Z');
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return '${monday.year.toString().padLeft(4, '0')}-'
      '${monday.month.toString().padLeft(2, '0')}-'
      '${monday.day.toString().padLeft(2, '0')}';
}

class _DominantTrainingLandingBody extends StatelessWidget {
  const _DominantTrainingLandingBody({
    required this.data,
    required this.isLaunching,
    required this.onStartWorkout,
    required this.onStartQuickWorkout,
    required this.onResumeDraft,
    required this.onOpenPlan,
    required this.onOpenBuilder,
    required this.onOpenPlanActions,
    required this.onOpenCalendar,
    required this.onOpenExercises,
    required this.onOpenHistory,
    required this.onRetry,
  });

  final TrainingLandingSnapshot data;
  final bool isLaunching;
  final ValueChanged<CalendarOccurrenceReadItem> onStartWorkout;
  final VoidCallback onStartQuickWorkout;
  final VoidCallback? onResumeDraft;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenBuilder;
  final VoidCallback onOpenPlanActions;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenExercises;
  final VoidCallback onOpenHistory;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final action = _trainingActionFor(data);
    final activePlan =
        data.activeProgramName?.trim().isNotEmpty == true &&
        (data.nextActionResolution == null ||
            data.nextActionResolution!.activeProgramVersionId != null);
    final nextWorkout = data.upcoming.isEmpty ? null : data.upcoming.first;
    final planContext =
        data.nextActionResolution?.dominantScheduledOccurrence ??
        data.currentPlanContext;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space16,
        B05Layout.space12,
        B05Layout.space16,
        B05Layout.space32,
      ),
      children: [
        _DominantTrainingAction(
          action: action,
          isLaunching: isLaunching,
          onStart: action.occurrence == null
              ? null
              : () => onStartWorkout(action.occurrence!),
          onResume: action.draft == null ? null : onResumeDraft,
          onChoosePlan: onOpenPlan,
          onRetry: onRetry,
          onQuickWorkout: onStartQuickWorkout,
        ),
        if (activePlan) ...[
          const SizedBox(height: B05Layout.space12),
          _TrainingPlanContext(
            planName: data.activeProgramName!,
            item: planContext,
            onOpenActions: onOpenPlanActions,
          ),
          if (data.currentWeekOccurrences.isNotEmpty) ...[
            const SizedBox(height: B05Layout.space16),
            const _SectionLabel(label: 'THIS WEEK'),
            const SizedBox(height: B05Layout.space8),
            _TrainingWeekStrip(
              weekStartLocalDate:
                  data.currentWeekStartLocalDate ??
                  _trainingMondayForLocalDate(data.localDate),
              occurrences: data.currentWeekOccurrences,
              localDate: data.localDate,
            ),
          ],
        ],
        if (nextWorkout != null) ...[
          const SizedBox(height: B05Layout.space16),
          const _SectionLabel(label: 'NEXT WORKOUT'),
          const SizedBox(height: B05Layout.space8),
          _NextTrainingContext(item: nextWorkout, onTap: onOpenCalendar),
        ],
        if (data.recentSessions.isNotEmpty) ...[
          const SizedBox(height: B05Layout.space16),
          const _SectionLabel(label: 'RECENT'),
          const SizedBox(height: B05Layout.space8),
          B05Surface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < data.recentSessions.length && index < 2;
                  index++
                )
                  _RecentTrainingRow(
                    session: data.recentSessions[index],
                    showDivider:
                        index < data.recentSessions.length - 1 && index < 1,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    B05Layout.space12,
                    B05Layout.space4,
                    B05Layout.space12,
                    B05Layout.space8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: B05ActionButton(
                      label: 'View history',
                      icon: Icons.history_rounded,
                      emphasis: B05ActionEmphasis.tertiary,
                      onPressed: onOpenHistory,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: B05Layout.space16),
        const _SectionLabel(label: 'MORE TRAINING'),
        const SizedBox(height: B05Layout.space8),
        _TrainingSecondaryNavigation(
          onOpenExercises: onOpenExercises,
          onOpenHistory: onOpenHistory,
          onOpenCalendar: onOpenCalendar,
          onOpenPlan: onOpenPlan,
          onOpenBuilder: onOpenBuilder,
        ),
      ],
    );
  }
}

class _DominantTrainingAction extends StatelessWidget {
  const _DominantTrainingAction({
    required this.action,
    required this.isLaunching,
    required this.onStart,
    required this.onResume,
    required this.onChoosePlan,
    required this.onRetry,
    required this.onQuickWorkout,
  });

  final _TrainingActionModel action;
  final bool isLaunching;
  final VoidCallback? onStart;
  final VoidCallback? onResume;
  final VoidCallback onChoosePlan;
  final VoidCallback onRetry;
  final VoidCallback onQuickWorkout;

  @override
  Widget build(BuildContext context) {
    final icon = switch (action.kind) {
      _TrainingActionKind.resume => Icons.play_circle_outline_rounded,
      _TrainingActionKind.start => Icons.fitness_center_rounded,
      _TrainingActionKind.completed => Icons.check_circle_outline_rounded,
      _TrainingActionKind.partial => Icons.timelapse_rounded,
      _TrainingActionKind.openDay => Icons.self_improvement_outlined,
      _TrainingActionKind.noPlan => Icons.route_outlined,
      _TrainingActionKind.blocked => Icons.pause_circle_outline_rounded,
      _TrainingActionKind.unavailable => Icons.error_outline_rounded,
    };
    final iconColor = switch (action.kind) {
      _TrainingActionKind.completed => context.b05Colors.success.indicator,
      _TrainingActionKind.partial ||
      _TrainingActionKind.blocked => context.b05Colors.warning.indicator,
      _TrainingActionKind.unavailable =>
        context.b05Colors.unavailable.indicator,
      _ => context.b05Colors.action,
    };
    final primary = switch (action.kind) {
      _TrainingActionKind.resume => onResume,
      _TrainingActionKind.start => onStart,
      _TrainingActionKind.noPlan => onChoosePlan,
      _TrainingActionKind.unavailable => onRetry,
      _ => null,
    };
    final primaryLabel = action.kind == _TrainingActionKind.start && isLaunching
        ? 'Opening workout…'
        : action.primaryLabel;
    final primaryButton = primaryLabel == null
        ? null
        : B05ActionButton(
            label: primaryLabel,
            icon: action.primaryIcon,
            onPressed: isLaunching ? null : primary,
          );
    final quickButton = action.showsQuickWorkout
        ? B05ActionButton(
            label: 'Quick Workout',
            icon: Icons.bolt_rounded,
            emphasis: B05ActionEmphasis.secondary,
            onPressed: isLaunching ? null : onQuickWorkout,
          )
        : null;

    return Semantics(
      container: true,
      label: 'What to do now. ${action.title}. ${action.detail}',
      child: B05Surface(
        tone: B05SurfaceTone.selected,
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(B05Layout.space8),
                    child: Icon(icon, color: iconColor),
                  ),
                ),
                const SizedBox(width: B05Layout.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WHAT TO DO NOW', style: _trainingEyebrow(context)),
                      const SizedBox(height: B05Layout.space4),
                      Text(action.title, style: B05Typography.title(context)),
                      const SizedBox(height: B05Layout.space4),
                      Text(action.detail, style: B05Typography.body(context)),
                    ],
                  ),
                ),
              ],
            ),
            if (primaryButton != null || quickButton != null) ...[
              const SizedBox(height: B05Layout.space12),
              B05ActionGroup(children: [?primaryButton, ?quickButton]),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrainingPlanContext extends StatelessWidget {
  const _TrainingPlanContext({
    required this.planName,
    required this.item,
    required this.onOpenActions,
  });

  final String planName;
  final CalendarOccurrenceReadItem? item;
  final VoidCallback onOpenActions;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    padding: const EdgeInsets.symmetric(
      horizontal: B05Layout.space12,
      vertical: B05Layout.space8,
    ),
    child: Row(
      children: [
        Icon(
          Icons.route_outlined,
          size: B05Layout.iconMedium,
          color: context.b05Colors.action,
        ),
        const SizedBox(width: B05Layout.space8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plan', style: _trainingEyebrow(context)),
              Text(planName, style: B05Typography.label(context)),
              if (item != null)
                Text(
                  _trainingPlanContextLabel(item),
                  style: B05Typography.caption(context),
                ),
            ],
          ),
        ),
        B05IconAction(
          icon: Icons.more_horiz_rounded,
          label: 'Plan actions',
          hint: 'View, switch, finish, or leave this plan.',
          onPressed: onOpenActions,
        ),
      ],
    ),
  );
}

class _NextTrainingContext extends StatelessWidget {
  const _NextTrainingContext({required this.item, required this.onTap});

  final CalendarOccurrenceReadItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label:
        'Next workout. ${item.template.name}, ${ConsumerDateLabel.day(item.occurrence.effectiveLocalDate)}',
    hint: 'Open the training calendar.',
    onTap: onTap,
    child: B05Surface(
      tone: B05SurfaceTone.inset,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: B05Radii.mediumRadius,
        child: Padding(
          padding: const EdgeInsets.all(B05Layout.space12),
          child: Row(
            children: [
              Icon(Icons.event_outlined, color: context.b05Colors.action),
              const SizedBox(width: B05Layout.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.template.name,
                      style: B05Typography.label(context),
                    ),
                    Text(
                      '${ConsumerDateLabel.day(item.occurrence.effectiveLocalDate)} · ${item.prescriptions.length} ${item.prescriptions.length == 1 ? 'exercise' : 'exercises'}',
                      style: B05Typography.caption(context),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.b05Colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TrainingSecondaryNavigation extends StatelessWidget {
  const _TrainingSecondaryNavigation({
    required this.onOpenExercises,
    required this.onOpenHistory,
    required this.onOpenCalendar,
    required this.onOpenPlan,
    required this.onOpenBuilder,
  });

  final VoidCallback onOpenExercises;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenBuilder;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    padding: const EdgeInsets.symmetric(
      horizontal: B05Layout.space8,
      vertical: B05Layout.space4,
    ),
    child: B05ActionGroup(
      children: [
        B05ActionButton(
          label: 'Exercise Library',
          icon: Icons.search_rounded,
          emphasis: B05ActionEmphasis.tertiary,
          onPressed: onOpenExercises,
        ),
        B05ActionButton(
          label: 'History',
          icon: Icons.history_rounded,
          emphasis: B05ActionEmphasis.tertiary,
          onPressed: onOpenHistory,
        ),
        B05ActionButton(
          label: 'Calendar',
          icon: Icons.calendar_month_outlined,
          emphasis: B05ActionEmphasis.tertiary,
          onPressed: onOpenCalendar,
        ),
        B05ActionButton(
          label: 'Plan Library',
          icon: Icons.collections_bookmark_outlined,
          emphasis: B05ActionEmphasis.tertiary,
          onPressed: onOpenPlan,
        ),
        B05ActionButton(
          label: 'Builder',
          icon: Icons.edit_note_rounded,
          emphasis: B05ActionEmphasis.tertiary,
          onPressed: onOpenBuilder,
        ),
      ],
    ),
  );
}

TextStyle _trainingEyebrow(BuildContext context) => B05Typography.caption(
  context,
).copyWith(fontWeight: FontWeight.w700, letterSpacing: .8);

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
