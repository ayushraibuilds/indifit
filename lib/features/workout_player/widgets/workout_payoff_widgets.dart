import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/services/indifit_haptics.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/weekly_training_goal_calculator.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/confetti_overlay.dart';
import '../../progress/training_bests_providers.dart';
import '../../progress/training_vs_last_time.dart';
import '../workout_celebration_store.dart';
import 'r07c_workout_presentation.dart';
import 'training_bests_summary.dart';

/// The workout summary as the payoff (training plan § 6, TP-6) and its
/// motion (§ 7, TP-7). Every animation takes its duration from
/// [B05MotionPolicy], so reduce motion shows final values on the first frame.

/// "1,440 kg": whole kilograms grouped by thousands, decimals kept.
String formatKgLifted(double kg) {
  final parts = r07cFormatNumber(kg).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return parts.length == 1 ? '$whole kg' : '$whole.${parts[1]} kg';
}

/// A number that counts up once from 0 to [value] over
/// [B05MotionPolicy.completionDuration]. With reduce motion the final value
/// shows immediately. Screen readers always get the final value.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.textAlign,
  });

  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final finalText = format(value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: B05MotionPolicy.transitionDuration(
        context,
        standard: B05MotionPolicy.completionDuration,
      ),
      curve: B05MotionPolicy.standardCurve,
      builder: (context, shown, _) => Text(
        shown == value ? finalText : format(shown.roundToDouble()),
        semanticsLabel: finalText,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

/// "Workout complete", the routine name, and one line of numbers:
/// "1,440 kg lifted · 3 sets · 2 min 48 sec". The brand-colour check
/// scales in once.
class WorkoutSummaryHeadline extends StatelessWidget {
  const WorkoutSummaryHeadline({
    super.key,
    required this.isPartial,
    required this.routineName,
    required this.savedLine,
    required this.totalLiftedKg,
    required this.setCount,
    required this.durationLabel,
  });

  final bool isPartial;
  final String routineName;
  final String savedLine;
  final double totalLiftedKg;
  final int setCount;

  /// Null when the duration is unknown.
  final String? durationLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.b05Colors;
    String stats(double kg) => [
      if (totalLiftedKg > 0) '${formatKgLifted(kg)} lifted',
      if (setCount > 0) '$setCount ${setCount == 1 ? 'set' : 'sets'}',
      ?durationLabel,
    ].join(' · ');
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: B05MotionPolicy.transitionDuration(
            context,
            standard: B05MotionPolicy.completionDuration,
          ),
          curve: B05MotionPolicy.standardCurve,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Icon(
            isPartial
                ? Icons.check_circle_outline_rounded
                : Icons.check_circle_rounded,
            key: const ValueKey('workout_summary_check'),
            color: colors.action,
            size: 56,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isPartial ? 'Workout partially completed' : 'Workout complete',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          routineName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (stats(totalLiftedKg).isNotEmpty) ...[
          const SizedBox(height: 8),
          CountUpText(
            key: const ValueKey('workout_summary_headline_stats'),
            value: totalLiftedKg,
            format: stats,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
        ],
        const SizedBox(height: 8),
        Text(savedLine, textAlign: TextAlign.center),
      ],
    );
  }
}

/// True when this workout is the one that met the week goal, matching the
/// "Week goal done" summary copy.
bool weekGoalJustMet(WeeklyTrainingGoalStatus? goal) =>
    goal != null && goal.completed == goal.goal;

/// The one moment of the summary: the new bests, or the week goal when this
/// workout met it and set no bests.
///
/// When [celebrate] is true the moment is celebrated once per saved
/// workout: a confetti burst (none with reduce motion) and
/// [IndiFitHaptics.success]. The session is marked in
/// [WorkoutCelebrationStore] first, so reopening the summary never repeats
/// it. When [achievementSheetWillOpen] is true the sheet is the burst and
/// this block stays still.
class WorkoutPayoffMoment extends ConsumerStatefulWidget {
  const WorkoutPayoffMoment({
    super.key,
    required this.sessionId,
    required this.bestsSessionId,
    required this.weeklyGoal,
    this.celebrate = false,
    this.achievementSheetWillOpen = false,
  });

  /// The saved session the celebration flag is kept for.
  final int? sessionId;

  /// The session whose bests are read. Null when its saved detail could not
  /// be read, so only the week goal can be the moment.
  final int? bestsSessionId;

  final WeeklyTrainingGoalStatus? weeklyGoal;
  final bool celebrate;
  final bool achievementSheetWillOpen;

  @override
  ConsumerState<WorkoutPayoffMoment> createState() =>
      _WorkoutPayoffMomentState();
}

class _WorkoutPayoffMomentState extends ConsumerState<WorkoutPayoffMoment> {
  var _decisionStarted = false;
  var _burst = false;

  @override
  Widget build(BuildContext context) {
    final bestsSessionId = widget.bestsSessionId;
    final bestsRead = bestsSessionId == null
        ? null
        : ref.watch(trainingBestsForSessionProvider(bestsSessionId));
    final bestsResolved = bestsRead == null || !bestsRead.isLoading;
    final hasBests = bestsRead?.valueOrNull?.bests.isNotEmpty ?? false;
    final goal = widget.weeklyGoal;
    final goalMoment = !hasBests && bestsResolved && weekGoalJustMet(goal);

    if (widget.celebrate && bestsResolved && !_decisionStarted) {
      _decisionStarted = true;
      final hasMoment = hasBests || goalMoment;
      if (hasMoment && widget.sessionId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_celebrateOnce(widget.sessionId!));
        });
      }
    }

    final Widget content;
    if (hasBests) {
      content = TrainingBestsSummaryBlock(sessionId: bestsSessionId!);
    } else if (goalMoment) {
      content = _WeekGoalMomentCard(goal: goal!);
    } else {
      return const SizedBox.shrink();
    }
    if (!_burst || B05MotionPolicy.reduceMotion(context)) return content;
    return ConfettiOverlay(
      key: const ValueKey('workout_summary_celebration'),
      particleCount: 30,
      child: content,
    );
  }

  Future<void> _celebrateOnce(int sessionId) async {
    try {
      var prefs = sharedPreferencesOrNull(
        () => ref.read(sharedPreferencesProvider),
      );
      prefs ??= await SharedPreferences.getInstance();
      if (WorkoutCelebrationStore.hasCelebrated(prefs, sessionId)) return;
      // Marked before it shows: a crash in between loses the moment rather
      // than repeating it.
      await WorkoutCelebrationStore.markCelebrated(prefs, sessionId);
      if (!mounted) return;
      if (!widget.achievementSheetWillOpen) setState(() => _burst = true);
      unawaited(IndiFitHaptics.success());
    } catch (error) {
      // Presentation only: the summary stays correct without the moment.
      AppLogger.warning(
        'Workout celebration skipped: $error',
        'WorkoutPayoffMoment',
      );
    }
  }
}

class _WeekGoalMomentCard extends StatelessWidget {
  const _WeekGoalMomentCard({required this.goal});

  final WeeklyTrainingGoalStatus goal;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final run = WeeklyTrainingGoalCopy.weeksInARow(goal);
    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space16),
      child: B05Surface(
        key: const ValueKey('workout_summary_week_goal_moment'),
        tone: B05SurfaceTone.inset,
        child: Semantics(
          container: true,
          label: [WeeklyTrainingGoalCopy.summary(goal), ?run].join('. '),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  color: colors.success.indicator,
                  size: B05Layout.iconMedium,
                ),
                const SizedBox(width: B05Layout.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        WeeklyTrainingGoalCopy.summary(goal),
                        key: const Key('workout_summary_week_goal'),
                        style: B05Typography.title(context),
                      ),
                      if (run != null)
                        Text(run, style: B05Typography.caption(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "2 of 3 workouts this week" (or "Week goal done · …"). Hidden when the
/// week goal is already the summary's moment.
class WorkoutWeekGoalLine extends ConsumerWidget {
  const WorkoutWeekGoalLine({
    super.key,
    required this.goal,
    required this.bestsSessionId,
  });

  final WeeklyTrainingGoalStatus goal;
  final int? bestsSessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionId = bestsSessionId;
    final bestsRead = sessionId == null
        ? null
        : ref.watch(trainingBestsForSessionProvider(sessionId));
    final bestsResolved = bestsRead == null || !bestsRead.isLoading;
    final hasBests = bestsRead?.valueOrNull?.bests.isNotEmpty ?? false;
    if (weekGoalJustMet(goal) && bestsResolved && !hasBests) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space16),
      child: Text(
        WeeklyTrainingGoalCopy.summary(goal),
        key: const Key('workout_summary_week_goal'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

/// "Vs last time": one line per exercise, in workout order. Hidden while
/// loading, on a failed read, or when there is nothing to compare.
class WorkoutVsLastTimeBlock extends ConsumerWidget {
  const WorkoutVsLastTimeBlock({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines =
        ref
            .watch(trainingVsLastTimeForSessionProvider(sessionId))
            .valueOrNull ??
        const <ExerciseVsLastTime>[];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space16),
      child: B05Surface(
        key: const ValueKey('workout_summary_vs_last_time'),
        tone: B05SurfaceTone.inset,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              TrainingVsLastTimeCopy.title,
              style: B05Typography.title(context),
            ),
            for (final line in lines) ...[
              const SizedBox(height: B05Layout.space8),
              Text(
                TrainingVsLastTimeCopy.line(line),
                semanticsLabel: [
                  TrainingVsLastTimeCopy.line(line),
                  ?TrainingVsLastTimeCopy.detail(line),
                ].join(', '),
                style: B05Typography.body(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
