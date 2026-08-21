import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/services/indifit_haptics.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/legacy_program_compatibility_adapter.dart';
import '../../data/repositories/program_lifecycle_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../training/training_plan_lifecycle_controller.dart';
import 'widgets/manual_log_sheet.dart';

class RoutineDisplayScreen extends ConsumerStatefulWidget {
  const RoutineDisplayScreen({super.key});

  @override
  ConsumerState<RoutineDisplayScreen> createState() =>
      _RoutineDisplayScreenState();
}

class _RoutineDisplayScreenState extends ConsumerState<RoutineDisplayScreen> {
  WorkoutRoutine? _activeRoutine;
  List<Map<String, dynamic>> _routineDays = [];
  int _selectedDayOfWeek = DateTime.now().weekday; // 1 = Mon, 7 = Sun
  bool _loading = false;
  Set<int> _completedDayOfWeeks = {};
  String? _activeProgramVersionId;
  String? _activeProgramName;

  @override
  void initState() {
    super.initState();
    _loadActiveRoutine();
  }

  Future<void> _loadActiveRoutine() async {
    setState(() => _loading = true);

    try {
      final repo = ref.read(workoutRepositoryProvider);
      final selection = await ref
          .read(legacyProgramCompatibilityAdapterProvider)
          .resolveActivePlanSelection();
      final sessions = await repo.watchSessions().first;

      final now = DateTime.now();
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(
        const Duration(days: 6, hours: 23, minutes: 59),
      );
      final completed = sessions
          .where(
            (s) =>
                s.completedAt.isAfter(
                  monday.subtract(const Duration(seconds: 1)),
                ) &&
                s.completedAt.isBefore(sunday),
          )
          .map((s) => s.completedAt.weekday)
          .toSet();

      if (selection.type == ActivePlanType.legacyRoutine) {
        final active = await repo.getSavedRoutines().then(
          (routines) => routines.singleWhere(
            (routine) => routine.id == selection.legacyRoutineId,
          ),
        );
        final details = await repo.getRoutineDetails(active.id);

        setState(() {
          _activeRoutine = active;
          _activeProgramVersionId = null;
          _activeProgramName = null;
          _routineDays = details;
          _completedDayOfWeeks = completed;
          _loading = false;
        });
      } else if (selection.type == ActivePlanType.b01Program) {
        final detail = await ref
            .read(programRepositoryProvider)
            .getProgramVersionDetail(selection.programVersionId!);
        setState(() {
          _activeRoutine = null;
          _activeProgramVersionId = selection.programVersionId;
          _activeProgramName = detail?.program.name;
          _routineDays = [];
          _completedDayOfWeeks = completed;
          _loading = false;
        });
      } else {
        setState(() {
          _activeRoutine = null;
          _activeProgramVersionId = null;
          _activeProgramName = null;
          _routineDays = [];
          _completedDayOfWeeks = completed;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _endActivePlan(PlanEndOutcome outcome) async {
    if (_loading) return;
    final planName = _activeProgramName ?? 'this plan';
    final isFinish = outcome == PlanEndOutcome.finished;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isFinish ? 'Finish plan?' : 'Leave plan?'),
        content: Text(
          isFinish
              ? 'Future workouts in $planName will stop. Completed and partially completed workouts stay in your history.'
              : 'Future workouts in $planName will stop. Your completed workout history stays saved.',
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
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final controller = ref.read(trainingPlanLifecycleControllerProvider);
      final result = isFinish
          ? await controller.finishPlan()
          : await controller.leavePlan();
      if (!mounted) return;
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
      await _loadActiveRoutine();
    } on ProgramLifecycleException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_routinePlanLifecycleMessage(error))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan action unavailable. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _activeProgramVersionId == null ? 'Training Split' : 'Training plan',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_run_rounded),
            tooltip: 'Log typed activity',
            onPressed: () => context.push('/activity-create'),
          ),
          if (_activeRoutine != null) ...[
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Log Past Workout',
              onPressed: () {
                showIndiFitBottomSheet(
                  context: context,
                  semanticLabel: 'Log completed workout',
                  builder: (context) =>
                      ManualLogSheet(selectedDate: DateTime.now()),
                ).then((_) => _loadActiveRoutine());
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: 'Edit Split',
              onPressed: () async {
                final success = await context.push<bool>('/routine-editor');
                if (success == true) {
                  await _loadActiveRoutine();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.psychology_rounded),
              tooltip: 'Re-generate Split with AI',
              onPressed: () async {
                final success = await context.push<bool>('/routine-wizard');
                if (success == true) {
                  await _loadActiveRoutine();
                }
              },
            ),
          ],
        ],
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(20.0),
              child: SkeletonList(count: 4),
            )
          : _activeRoutine == null
          ? _activeProgramVersionId == null
                ? _buildEmptyState()
                : _buildActiveProgramState()
          : _buildRoutineLayout(),
    );
  }

  Widget _buildActiveProgramState() {
    return ActiveProgramManagementSurface(
      planName: _activeProgramName,
      onOpenCalendar: () => context.push('/calendar'),
      onChangePlan: () => context.push('/program-author'),
      onFinishPlan: () => _endActivePlan(PlanEndOutcome.finished),
      onLeavePlan: () => _endActivePlan(PlanEndOutcome.left),
    );
  }

  Widget _buildEmptyState() {
    final colors = context.b05Colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: colors.selected,
                borderRadius: BorderRadius.circular(40),
              ),
              padding: const EdgeInsets.all(20),
              child: Icon(
                Icons.psychology_rounded,
                size: 56,
                color: colors.action,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Workout Split Generated',
              style: B05Typography.title(context),
            ),
            const SizedBox(height: 12),
            Text(
              'Our AI Fitness Coach can design a custom training split matching your equipment, experience, and schedules.',
              textAlign: TextAlign.center,
              style: B05Typography.body(context),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final success = await context.push<bool>('/routine-wizard');
                  if (success == true) {
                    await _loadActiveRoutine();
                  }
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text(
                  'Generate Split with AI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final success = await context.push<bool>(
                        '/routine-editor',
                      );
                      if (success == true) {
                        await _loadActiveRoutine();
                      }
                    },
                    icon: const Icon(
                      Icons.dashboard_customize_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      'Templates',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final success = await context.push<bool>(
                        '/routine-editor',
                      );
                      if (success == true) {
                        await _loadActiveRoutine();
                      }
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text(
                      'Manual Build',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineLayout() {
    final colors = context.b05Colors;
    // Locate details for selected day
    final dayData = _routineDays.firstWhere(
      (d) => (d['day'] as RoutineDay).dayOfWeek == _selectedDayOfWeek,
      orElse: () => {
        'day': RoutineDay(
          id: 0,
          routineId: 0,
          dayOfWeek: _selectedDayOfWeek,
          name: 'Rest Day',
          isRestDay: true,
        ),
        'exercises': <RoutineExercise>[],
      },
    );

    final RoutineDay day = dayData['day'];
    final List<RoutineExercise> exercises =
        dayData['exercises'] as List<RoutineExercise>;

    return Column(
      children: [
        // 1. Horizontal Weekday Selector Card
        _buildWeeklyCalendarHeader(),
        const SizedBox(height: 24),

        // 2. Day Schedule Detail Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      day.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (day.isRestDay)
                      Text(
                        '🧘 REST',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      )
                    else
                      Text(
                        '${exercises.length} Exercises',
                        style: TextStyle(
                          color: colors.action,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: day.isRestDay
                      ? _buildRestDayState()
                      : _buildExercisesList(exercises),
                ),

                // 3. Start Workout Trigger CTA
                if (!day.isRestDay && exercises.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: FilledButton.icon(
                      onPressed: () {
                        context.push(
                          '/workout-player',
                          extra: {
                            'routineName': day.name,
                            'exercises': exercises,
                          },
                        );
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text(
                        'Start Workout',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyCalendarHeader() {
    final colors = context.b05Colors;
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    return Container(
      color: colors.section,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(7, (index) {
            final dayNum = index + 1;
            final isSelected = _selectedDayOfWeek == dayNum;
            final date = monday.add(Duration(days: index));

            // Check if this day is a rest day
            final daySplit = _routineDays.firstWhere(
              (d) => (d['day'] as RoutineDay).dayOfWeek == dayNum,
              orElse: () => {'day': null},
            );
            final RoutineDay? rDay = daySplit['day'];
            final isRest = rDay?.isRestDay ?? true;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Semantics(
                button: true,
                selected: isSelected,
                label: '${weekdays[index]} ${date.day}',
                child: InkWell(
                  onTap: () => setState(() => _selectedDayOfWeek = dayNum),
                  borderRadius: B05Radii.largeRadius,
                  child: AnimatedContainer(
                    duration: B05MotionPolicy.transitionDuration(context),
                    width: 58,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isSelected ? colors.action : colors.inset,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : colors.border,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekdays[index],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? colors.onAction
                                : colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? colors.onAction
                                : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          _completedDayOfWeeks.contains(dayNum)
                              ? Icons.check_circle_rounded
                              : (isRest
                                    ? Icons.spa_rounded
                                    : Icons.fitness_center_rounded),
                          size: 14,
                          color: isSelected
                              ? colors.onAction
                              : (_completedDayOfWeeks.contains(dayNum)
                                    ? colors.success.indicator
                                    : (isRest
                                          ? colors.info.indicator
                                          : colors.action)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRestDayState() {
    final colors = context.b05Colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.info.container,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.spa_rounded,
              size: 48,
              color: colors.info.foreground,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Time to Recover',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Your muscles grow during rest periods. Hydrate and eat well!',
            textAlign: TextAlign.center,
            style: B05Typography.caption(context),
          ),
        ],
      ),
    );
  }

  Widget _buildExercisesList(List<RoutineExercise> list) {
    final colors = context.b05Colors;
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final ex = list[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colors.selected,
              foregroundColor: colors.action,
              child: Text('${index + 1}'),
            ),
            title: Text(
              ex.exerciseName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'Target: ${ex.sets} Sets of ${ex.repsRange} Reps',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }
}

class ActiveProgramManagementSurface extends StatelessWidget {
  const ActiveProgramManagementSurface({
    required this.planName,
    required this.onOpenCalendar,
    required this.onChangePlan,
    this.onFinishPlan,
    this.onLeavePlan,
    super.key,
  });

  final String? planName;
  final VoidCallback onOpenCalendar;
  final VoidCallback onChangePlan;
  final VoidCallback? onFinishPlan;
  final VoidCallback? onLeavePlan;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_rounded, size: 56, color: colors.action),
            const SizedBox(height: 20),
            Text(
              planName ?? 'Current training plan',
              textAlign: TextAlign.center,
              style: B05Typography.title(context),
            ),
            const SizedBox(height: 10),
            Text(
              'Your workouts are scheduled and ready. Open the calendar to train, or choose a different plan when you are ready for a change.',
              textAlign: TextAlign.center,
              style: B05Typography.body(context),
            ),
            const SizedBox(height: 20),
            B05ActionGroup(
              children: [
                B05ActionButton(
                  label: 'Open calendar',
                  icon: Icons.calendar_today_rounded,
                  onPressed: onOpenCalendar,
                ),
                B05ActionButton(
                  label: 'Change plan',
                  icon: Icons.swap_horiz_rounded,
                  emphasis: B05ActionEmphasis.secondary,
                  onPressed: onChangePlan,
                ),
                if (onFinishPlan != null || onLeavePlan != null)
                  PopupMenuButton<String>(
                    tooltip: 'Plan actions',
                    onSelected: (value) {
                      if (value == 'finish') onFinishPlan?.call();
                      if (value == 'leave') onLeavePlan?.call();
                    },
                    itemBuilder: (context) => [
                      if (onFinishPlan != null)
                        const PopupMenuItem(
                          value: 'finish',
                          child: Text('Finish plan'),
                        ),
                      if (onLeavePlan != null)
                        const PopupMenuItem(
                          value: 'leave',
                          child: Text('Leave plan'),
                        ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.more_horiz_rounded),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _routinePlanLifecycleMessage(ProgramLifecycleException error) {
  return ProductFailurePresentation.fromError(error).message;
}
