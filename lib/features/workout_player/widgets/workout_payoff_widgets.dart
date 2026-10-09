import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/motion/indifit_motion.dart';
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

/// The summary hero (V6, PREMIUM_REDESIGN_PLAN § 8.3): the tick pops in,
/// then the status and routine name, one hero number that counts up
/// ("1,440 kg" total lifted, or the reps for a bodyweight workout) and one
/// row of three stats. Each fact is shown once.
class WorkoutSummaryHero extends StatelessWidget {
  const WorkoutSummaryHero({
    super.key,
    required this.isPartial,
    required this.routineName,
    required this.savedLine,
    required this.totalLiftedKg,
    required this.setCount,
    required this.repCount,
    required this.durationLabel,
  });

  final bool isPartial;
  final String routineName;
  final String savedLine;

  /// 0 when nothing with an external load was logged.
  final double totalLiftedKg;
  final int setCount;

  /// 0 when no reps are known.
  final int repCount;

  /// Null when the duration is unknown.
  final String? durationLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.b05Colors;
    final hero = workoutSummaryHeroNumber(
      totalLiftedKg: totalLiftedKg,
      repCount: repCount,
    );
    final stats = workoutSummaryStats(
      setCount: setCount,
      repCount: hero?.isReps == true ? 0 : repCount,
      durationLabel: durationLabel,
    );
    return Column(
      children: [
        IndiFitPop(
          child: Icon(
            isPartial
                ? Icons.check_circle_outline_rounded
                : Icons.check_circle_rounded,
            key: const ValueKey('workout_summary_check'),
            color: colors.action,
            size: 56,
          ),
        ),
        const SizedBox(height: B05Layout.space12),
        Text(
          isPartial ? 'Workout partially completed' : 'Workout complete',
          textAlign: TextAlign.center,
          style: B05Typography.sectionLabel(context),
        ),
        const SizedBox(height: B05Layout.space4),
        Text(
          routineName,
          textAlign: TextAlign.center,
          style: B05Typography.pageTitle(context),
        ),
        if (hero != null) ...[
          const SizedBox(height: B05Layout.space20),
          CountUpText(
            key: const ValueKey('workout_summary_hero_number'),
            value: hero.value,
            format: hero.format,
            textAlign: TextAlign.center,
            style: B05Typography.metric(
              context,
            ).copyWith(color: colors.action, fontSize: 44, height: 1.1),
          ),
          Text(
            hero.label,
            textAlign: TextAlign.center,
            style: B05Typography.body(context),
          ),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: B05Layout.space20),
          WorkoutSummaryStatsRow(stats: stats),
        ],
        const SizedBox(height: B05Layout.space12),
        Text(
          savedLine,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// The hero number: kilograms lifted when any external load was logged,
/// otherwise the reps. Null when neither is known.
({double value, String Function(double) format, String label, bool isReps})?
workoutSummaryHeroNumber({
  required double totalLiftedKg,
  required int repCount,
}) {
  if (totalLiftedKg > 0) {
    return (
      value: totalLiftedKg,
      format: formatKgLifted,
      label: 'Total lifted',
      isReps: false,
    );
  }
  if (repCount > 0) {
    return (
      value: repCount.toDouble(),
      format: (value) => '${value.round()}',
      label: repCount == 1 ? 'Rep' : 'Reps',
      isReps: true,
    );
  }
  return null;
}

/// Sets, reps and duration, leaving out what is unknown.
List<({String value, String label})> workoutSummaryStats({
  required int setCount,
  required int repCount,
  required String? durationLabel,
}) => [
  if (setCount > 0) (value: '$setCount', label: setCount == 1 ? 'Set' : 'Sets'),
  if (repCount > 0) (value: '$repCount', label: repCount == 1 ? 'Rep' : 'Reps'),
  if (durationLabel != null) (value: durationLabel, label: 'Duration'),
];

/// One row of up to three stats with tabular figures. Stacks at large text
/// sizes so nothing truncates.
class WorkoutSummaryStatsRow extends StatelessWidget {
  const WorkoutSummaryStatsRow({super.key, required this.stats});

  final List<({String value, String label})> stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    Widget stat(({String value, String label}) stat) => Semantics(
      container: true,
      label: '${stat.value} ${stat.label.toLowerCase()}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stat.value,
              textAlign: TextAlign.center,
              style: B05Typography.number(context, size: 20),
            ),
            const SizedBox(height: 2),
            Text(
              stat.label,
              textAlign: TextAlign.center,
              style: B05Typography.caption(context),
            ),
          ],
        ),
      ),
    );
    return B05Surface(
      key: const ValueKey('workout_summary_stats_row'),
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.symmetric(
        horizontal: B05Layout.space8,
        vertical: B05Layout.space12,
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(height: B05Layout.space12),
                  stat(stats[i]),
                ],
              ],
            )
          : IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: colors.borderSubtle,
                      ),
                    Expanded(child: stat(stats[i])),
                  ],
                ],
              ),
            ),
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
      child: WorkoutWeekGoalPill(goal: goal),
    );
  }
}

/// "2 of 3 workouts this week" as a pill; "Week goal done · …" gets the
/// success colour and a tick.
class WorkoutWeekGoalPill extends StatelessWidget {
  const WorkoutWeekGoalPill({super.key, required this.goal});

  final WeeklyTrainingGoalStatus goal;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final met = goal.isMet;
    final tone = met ? colors.success : null;
    return Center(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: tone?.container ?? colors.surfaceSubtle,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: B05Layout.space12,
            vertical: B05Layout.space8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                met ? Icons.check_rounded : Icons.calendar_today_rounded,
                size: 16,
                color: tone?.indicator ?? colors.textSecondary,
              ),
              const SizedBox(width: B05Layout.space8),
              Flexible(
                child: Text(
                  WeeklyTrainingGoalCopy.summary(goal),
                  key: const Key('workout_summary_week_goal'),
                  textAlign: TextAlign.center,
                  style: B05Typography.label(
                    context,
                  ).copyWith(color: tone?.foreground ?? colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
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
