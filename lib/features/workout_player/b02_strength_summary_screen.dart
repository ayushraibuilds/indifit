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
import 'widgets/achievement_celebration_sheet.dart';
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
          _checkAndShowAchievements();
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
                WorkoutCompletionRecap.fromLaunch(completionLaunch),
              ),
            ),
          ],
        ),
        body: B02WorkoutCompletionSuccess(
          launch: completionLaunch,
          sessionId: ui.completedSessionId,
          completionKind: ui.completedCompletionKind ?? CompletionKind.full,
          onDone: () => goToTrainingTab(context),
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
            : () => _complete(
                context,
                provider,
                _pendingCompletionKind!,
                reason: _pendingCompletionReason,
              ),
        onFull: ui.isBusy || _isFinalizing
            ? null
            : () => _complete(context, provider, CompletionKind.full),
        onPartial: ui.isBusy || _isFinalizing
            ? null
            : () => _confirmPartial(context, provider),
        onBack: () => context.pop(),
      ),
    );
  }

  Future<void> _confirmPartial(BuildContext context, dynamic provider) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Finish partially?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'For example: time or equipment limit',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Keep training'),
            ),
            FilledButton(
              onPressed: () => context.pop(controller.text.trim()),
              child: const Text('Confirm partial finish'),
            ),
          ],
        );
      },
    );
    if (reason == null || !context.mounted) return;
    await _complete(context, provider, CompletionKind.partial, reason: reason);
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

  Future<void> _checkAndShowAchievements() async {
    if (!mounted) return;
    try {
      final statsRepo = ref.read(progressStatisticsRepositoryProvider);
      SharedPreferences? prefs;
      try {
        prefs = ref.read(sharedPreferencesProvider);
      } catch (_) {}
      prefs ??= await SharedPreferences.getInstance();
      final uncelebrated =
          await AchievementService.getUncelebratedWorkoutUnlocks(
        statsRepository: statsRepo,
        prefs: prefs,
      );
      if (uncelebrated.isEmpty || !mounted) return;

      // Mark celebrated right before presentation: fails closed toward silence
      // (a process kill between mark and sheet mount swallows the celebration,
      // preventing annoying duplicate fanfare), while kills before this point
      // leave the unlock pending celebration.
      await AchievementService.markCelebrated(
        prefs,
        uncelebrated.map((a) => a.id),
      );

      if (!mounted) return;
      await showAchievementCelebrationSheet(
        context,
        achievements: uncelebrated,
      );
    } catch (e) {
      // Non-blocking: failures in achievement presentation never break recap.
      AppLogger.warning(
        'Failed to evaluate or present milestone celebration: $e',
        'B02StrengthSummaryScreen',
      );
    }
  }
}

/// Consumer-facing evidence shown only after canonical B02 finalization
/// succeeds. When [sessionId] is present, all post-completion facts come from
/// the immutable saved session. The launch fallback exists for compatibility
/// callers/tests that render this presentation without a database handoff.
