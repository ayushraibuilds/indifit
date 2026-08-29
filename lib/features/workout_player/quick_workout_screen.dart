import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/b02_execution_draft_codec.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/services/workout_session_wake_lock_coordinator.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../exercise_picker/exercise_picker.dart';
import 'b02_strength_execution_controller.dart';
import 'workout_execution_route.dart';

/// The immutable input snapshot for a standalone B02 session. The draft owns
/// the live set state; this payload only records the exercise identities the
/// user chose for this Quick Workout.
String quickWorkoutSnapshotJson(String routineName) => jsonEncode({
  'version': 1,
  'routineName': routineName,
  'prescriptions': const <Map<String, dynamic>>[],
});

final quickWorkoutActiveDraftProvider =
    FutureProvider.autoDispose<WorkoutDraft?>((ref) async {
      return ref.watch(workoutRepositoryProvider).getActiveDraft();
    });

class QuickWorkoutScreen extends ConsumerStatefulWidget {
  const QuickWorkoutScreen({super.key});

  @override
  ConsumerState<QuickWorkoutScreen> createState() => _QuickWorkoutScreenState();
}

class _QuickWorkoutScreenState extends ConsumerState<QuickWorkoutScreen> {
  var _isStarting = false;
  var _isResolvingDraft = false;

  Future<void> _addExerciseAndStart() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final existing = await ref
          .read(workoutRepositoryProvider)
          .getActiveDraft();
      if (existing != null) {
        ref.invalidate(quickWorkoutActiveDraftProvider);
        return;
      }
      if (!mounted) return;
      final exercise = await showModalBottomSheet<Exercise>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const QuickExercisePicker(),
      );
      if (exercise?.stableId == null || !mounted) return;

      final adapter = ref.read(strengthExecutionCompatibilityAdapterProvider);
      final initial = await adapter.startUnscheduledDraft(
        routineName: 'Quick workout',
        executionSnapshotJson: quickWorkoutSnapshotJson('Quick workout'),
        snapshotId: const Uuid().v4(),
      );
      final withExercise = await adapter.addUnscheduledExercise(
        launch: initial,
        exerciseId: exercise!.stableId!,
        exerciseName: exercise.name,
      );
      final prepared = await adapter.prepareExecution(withExercise);
      if (!mounted) return;
      await context.push(
        '/b02-strength-player',
        extra: WorkoutExecutionRouteData.fromLaunch(
          withExercise.copyWith(state: prepared.state),
        ),
      );
      if (mounted) ref.invalidate(quickWorkoutActiveDraftProvider);
    } on B02StrengthExecutionException catch (error, stackTrace) {
      AppLogger.error(
        'Quick workout start was rejected',
        error,
        stackTrace,
        'QuickWorkout',
      );
      final active = await ref.read(workoutRepositoryProvider).getActiveDraft();
      if (!mounted) return;
      if (active != null) {
        ref.invalidate(quickWorkoutActiveDraftProvider);
      } else {
        _showGenericFailure();
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Quick workout could not start',
        error,
        stackTrace,
        'QuickWorkout',
      );
      if (!mounted) return;
      _showGenericFailure();
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _resumeDraft(WorkoutDraft draft) async {
    if (_isResolvingDraft) return;
    setState(() => _isResolvingDraft = true);
    try {
      final controller = ref.read(
        b02StrengthExecutionControllerProvider.notifier,
      );
      await controller.recover(draft.id);
      final recovered = ref.read(b02StrengthExecutionControllerProvider);
      if (!mounted ||
          recovered.status != B02StrengthExecutionStatus.ready ||
          recovered.launch == null) {
        throw StateError('The saved workout could not be recovered.');
      }
      await context.push(
        '/b02-strength-player',
        extra: WorkoutExecutionRouteData.fromLaunch(recovered.launch!),
      );
      if (mounted) ref.invalidate(quickWorkoutActiveDraftProvider);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Quick workout recovery failed',
        error,
        stackTrace,
        'QuickWorkout',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Saved workout unavailable. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolvingDraft = false);
    }
  }

  Future<void> _discardAndStart(WorkoutDraft draft) async {
    if (_isResolvingDraft || _isStarting) return;
    final hasLoggedSets = quickWorkoutDraftHasPerformedSets(draft);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard unfinished workout?'),
        content: Text(
          hasLoggedSets
              ? 'This will discard this unfinished workout and its logged sets. Completed workouts are not affected.'
              : 'This will discard this unfinished workout. Completed workouts are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep workout'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard and continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isResolvingDraft = true);
    try {
      await ref
          .read(strengthExecutionCompatibilityAdapterProvider)
          .discardDraft(draftId: draft.id, commandId: const Uuid().v4());
      final wakeLock = ref.read(workoutSessionWakeLockCoordinatorProvider);
      unawaited(
        wakeLock.clearActiveSession(b02WorkoutSessionWakeLockKey(draft.id)),
      );
      unawaited(
        wakeLock.clearActiveSession(
          legacyWorkoutSessionWakeLockKey(draft.scheduledOccurrenceId),
        ),
      );
      ref.invalidate(quickWorkoutActiveDraftProvider);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Quick workout discard failed',
        error,
        stackTrace,
        'QuickWorkout',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('The unfinished workout could not be discarded.'),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _isResolvingDraft = false);
    }
    if (mounted) await _addExerciseAndStart();
  }

  void _showGenericFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Quick workout could not start. Try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeDraft = ref.watch(quickWorkoutActiveDraftProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick workout'),
        actions: [
          B05IconAction(
            icon: Icons.close_rounded,
            label: 'Close quick workout',
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: activeDraft.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(B05Layout.space24),
            child: B05ActionButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(quickWorkoutActiveDraftProvider),
            ),
          ),
        ),
        data: (draft) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(B05Layout.space24),
            child: draft == null
                ? _QuickWorkoutStartSurface(
                    isStarting: _isStarting,
                    onStart: _addExerciseAndStart,
                  )
                : QuickWorkoutConflictSurface(
                    draft: draft,
                    isBusy: _isResolvingDraft || _isStarting,
                    onResume: () => _resumeDraft(draft),
                    onDiscard: () => _discardAndStart(draft),
                    onCancel: () => context.pop(),
                  ),
          ),
        ),
      ),
    );
  }
}

bool quickWorkoutDraftHasPerformedSets(WorkoutDraft draft) {
  final raw = draft.executionStateJson;
  if (raw == null) return false;
  try {
    final decoded = B02ExecutionDraftCodec.decode(raw);
    return decoded.isCanonical &&
        decoded.state!.performedExercises.any(
          (exercise) => exercise.sets.isNotEmpty,
        );
  } on FormatException {
    return false;
  } on B02UnsupportedDraftVersionException {
    return false;
  }
}

class QuickWorkoutConflictSurface extends StatelessWidget {
  const QuickWorkoutConflictSurface({
    required this.draft,
    required this.isBusy,
    required this.onResume,
    required this.onDiscard,
    required this.onCancel,
    super.key,
  });

  final WorkoutDraft draft;
  final bool isBusy;
  final VoidCallback onResume;
  final VoidCallback onDiscard;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final planned = draft.scheduledOccurrenceId != null;
    return B05Surface(
      tone: B05SurfaceTone.selected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            size: 40,
            color: context.b05Colors.action,
          ),
          const SizedBox(height: B05Layout.space12),
          Text(
            planned ? 'You have a workout in progress' : 'Workout in progress',
            style: B05Typography.pageTitle(context),
          ),
          const SizedBox(height: B05Layout.space8),
          Text(
            planned
                ? '${draft.routineName} is saved. Resume it, or discard only this unfinished workout before starting a quick workout.'
                : 'Your saved ${ConsumerCopy.quickWorkoutAction} is ready to continue.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space20),
          B05ActionGroup(
            children: [
              B05ActionButton(
                label: planned ? 'Resume planned workout' : 'Resume workout',
                icon: Icons.play_arrow_rounded,
                onPressed: isBusy ? null : onResume,
              ),
              B05ActionButton(
                label: planned
                    ? 'Discard draft and start a quick workout'
                    : 'Discard and start new',
                icon: Icons.delete_outline_rounded,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: isBusy ? null : onDiscard,
              ),
              B05ActionButton(
                label: 'Cancel',
                emphasis: B05ActionEmphasis.tertiary,
                onPressed: isBusy ? null : onCancel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickWorkoutStartSurface extends StatelessWidget {
  const _QuickWorkoutStartSurface({
    required this.isStarting,
    required this.onStart,
  });

  final bool isStarting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => B05Surface(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.bolt_rounded, size: 40, color: context.b05Colors.action),
        const SizedBox(height: B05Layout.space12),
        Text('Start anywhere', style: B05Typography.pageTitle(context)),
        const SizedBox(height: B05Layout.space8),
        Text(
          'Choose exercises as you go. No plan or schedule is required.',
          style: B05Typography.body(context),
        ),
        const SizedBox(height: B05Layout.space20),
        SizedBox(
          width: double.infinity,
          child: B05ActionButton(
            label: isStarting ? 'Opening picker…' : 'Add exercise',
            icon: Icons.add_rounded,
            onPressed: isStarting ? null : onStart,
          ),
        ),
        const SizedBox(height: B05Layout.space8),
        Text(
          'You can add exercises and extra sets throughout the session.',
          style: B05Typography.caption(context),
        ),
      ],
    ),
  );
}

/// Compatibility wrapper for the existing Quick Workout callers. The picker
/// surface and search authority now live in [ExercisePicker], while this
/// symbol keeps the pre-B.4 `Exercise` return shape for callers that have not
/// yet moved to the typed selection result.
class QuickExercisePicker extends StatelessWidget {
  const QuickExercisePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ExercisePicker(
      selectionContext: const QuickExercisePickerContext(),
      onExerciseSelected: (exercise, _) {
        Navigator.of(context).pop(exercise);
      },
    );
  }
}
