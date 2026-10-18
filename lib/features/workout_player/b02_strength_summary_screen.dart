import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/core_providers.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/indifit_haptics.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/progress_statistics_repository.dart';
import 'b02_strength_execution_controller.dart';
import 'widgets/b02_summary_widgets.dart';
import 'workout_execution_context.dart';

export 'widgets/b02_summary_widgets.dart';

/// Final review for B02 strength execution. Full and partial completion are
/// explicit actions; a failed finalization keeps the linked draft visible.
class B02StrengthSummaryScreen extends ConsumerStatefulWidget {
  final B02StrengthExecutionLaunch launch;
  final WorkoutExecutionContext? executionContext;

  const B02StrengthSummaryScreen({
    super.key,
    required this.launch,
    this.executionContext,
  });

  @override
  ConsumerState<B02StrengthSummaryScreen> createState() =>
      _B02StrengthSummaryScreenState();
}

class _B02StrengthSummaryScreenState
    extends ConsumerState<B02StrengthSummaryScreen> {
  late final String _completionCommandId;
  var _isFinalizing = false;
  var _hasCelebratedMilestones = false;

  /// Badges this workout unlocked. They wait in a row on the summary rather
  /// than opening over it, so the hero number is seen first.
  List<Achievement> _unlocks = const [];
  B02StrengthExecutionLaunch? _completionLaunch;
  CompletionKind? _pendingCompletionKind;
  String? _pendingCompletionReason;

  @override
  void initState() {
    super.initState();
    _completionCommandId = const Uuid().v4();
  }

  @override
  Widget build(BuildContext context) {
    final provider = b02StrengthExecutionScreenControllerProvider(
      widget.launch,
    );
    final ui = ref.watch(provider);
    final current = ui.launch ?? widget.launch;
    final execution =
        (widget.executionContext ?? WorkoutExecutionContext.fromLaunch(current))
            .rebind(current);
    final completed =
        ui.status == B02StrengthExecutionStatus.ready && ui.launch == null;
    if (completed) {
      if (!_hasCelebratedMilestones) {
        _hasCelebratedMilestones = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadUnlocks();
        });
      }
      final completionLaunch = _completionLaunch ?? widget.launch;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Workout saved'),
          actions: [
            IconButton(
              key: const Key('workout_share_appbar_button'),
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share workout recap',
              onPressed: () => showWorkoutShareSheet(
                context,
                WorkoutCompletionRecap.fromLaunch(
                  completionLaunch,
                ).withBests(savedSessionBests(ref, ui.completedSessionId)),
              ),
            ),
          ],
        ),
        body: B02WorkoutCompletionSuccess(
          launch: completionLaunch,
          sessionId: ui.completedSessionId,
          completionKind: ui.completedCompletionKind ?? CompletionKind.full,
          onDone: () => goToTrainingTab(context),
          allowCelebration: true,
          unlocks: _unlocks,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review workout')),
      body: B02SummaryBody(
        launch: current,
        executionContext: execution,
        ui: ui,
        onRetry: ui.launch == null || _pendingCompletionKind == null
            ? null
            : () {
                final kind = b02HasIncompleteExercises(current.state)
                    ? CompletionKind.partial
                    : _pendingCompletionKind!;
                unawaited(
                  _complete(
                    context,
                    provider,
                    kind,
                    reason: _pendingCompletionReason,
                  ),
                );
              },
        onFull: ui.isBusy || _isFinalizing
            ? null
            : () => _handleFullCompletion(context, provider, current),
        onPartial: ui.isBusy || _isFinalizing
            ? null
            : () => _complete(context, provider, CompletionKind.partial),
        onDiscard: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Discard workout?'),
              content: const Text(
                'This will discard this unfinished workout session and return to dashboard.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Keep'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          if (confirmed == true && mounted) {
            await ref.read(provider.notifier).discard();
            if (!context.mounted) return;
            goToTrainingTab(context);
          }
        },
        onBack: () => context.pop(),
      ),
    );
  }

  Future<void> _handleFullCompletion(
    BuildContext context,
    dynamic provider,
    B02StrengthExecutionLaunch launch,
  ) {
    // The review only offers Complete when nothing is missing; this guard
    // keeps a stale tap from saving an incomplete workout as full.
    return _complete(
      context,
      provider,
      b02HasIncompleteExercises(launch.state)
          ? CompletionKind.partial
          : CompletionKind.full,
    );
  }

  Future<void> _complete(
    BuildContext context,
    dynamic provider,
    CompletionKind kind, {
    String? reason,
  }) async {
    if (_isFinalizing) return;
    setState(() {
      _isFinalizing = true;
      _pendingCompletionKind = kind;
      _pendingCompletionReason = reason?.isEmpty == true ? null : reason;
    });
    final controller = ref.read(provider.notifier);
    try {
      await controller.pauseElapsed();
      if (!mounted) return;
      _completionLaunch = ref.read(provider).launch ?? widget.launch;
      final finalized = await controller.finalize(
        commandId: _completionCommandId,
        completionKind: kind,
        reason: _pendingCompletionReason,
      );
      if (finalized && mounted) {
        unawaited(IndiFitHaptics.confirmation());
      }
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  Future<void> _loadUnlocks() async {
    if (!mounted) return;
    try {
      final statsRepo = ref.read(progressStatisticsRepositoryProvider);
      SharedPreferences? prefs = sharedPreferencesOrNull(
        () => ref.read(sharedPreferencesProvider),
      );
      prefs ??= await SharedPreferences.getInstance();
      final uncelebrated =
          await AchievementService.getUncelebratedWorkoutUnlocks(
            statsRepository: statsRepo,
            prefs: prefs,
          );
      if (uncelebrated.isEmpty || !mounted) return;

      // Marked once they are on the summary: the row is how they are
      // announced, so the next workout does not announce them again.
      await AchievementService.markCelebrated(
        prefs,
        uncelebrated.map((a) => a.id),
      );
      if (mounted) setState(() => _unlocks = uncelebrated);
    } catch (e) {
      // Non-blocking: failures in achievement presentation never break recap.
      AppLogger.warning(
        'Failed to evaluate milestone unlocks: $e',
        'B02StrengthSummaryScreen',
      );
    }
  }
}

/// Consumer-facing evidence shown only after canonical B02 finalization
/// succeeds. When [sessionId] is present, all post-completion facts come from
/// the immutable saved session. The launch fallback exists for compatibility
/// callers/tests that render this presentation without a database handoff.
