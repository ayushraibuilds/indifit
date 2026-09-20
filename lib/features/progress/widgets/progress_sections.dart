import 'package:flutter/material.dart';

import '../../../core/presentation/consumer_copy.dart';
import '../../../core/services/local_schedule_date_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/models/b02_muscle_volume_models.dart';
import '../progress_dashboard_models.dart';
import '../r08f4_training_volume_presentation.dart';
import 'progress_formatters.dart';
import 'progress_view_models.dart';

/// Progress section widgets (PV1-ENG-05A first pass).
///
/// Extracted verbatim from `progress_screen.dart`; behavior unchanged.

class ProgressHighlights extends StatelessWidget {
  const ProgressHighlights({super.key, 
    required this.snapshot,
    required this.onViewTrainingHistory,
    required this.onViewStrengthHistory,
    required this.units,
  });

  final ProgressDashboardSnapshot snapshot;
  final VoidCallback onViewTrainingHistory;
  final void Function(String name, String stableExerciseId)
  onViewStrengthHistory;
  final String units;

  @override
  Widget build(BuildContext context) {
    final highlights = <ProgressHighlight>[];
    final thisWeek = workoutsThisWeek(snapshot);
    if (thisWeek.isNotEmpty) {
      final summary = R08F4TrainingVolumePresentation.summarizeConsistency(
        thisWeek,
      );
      final sessionCount = summary.sessionCount;
      final daysCount = snapshot.weeklyTrainedDates.isNotEmpty
          ? snapshot.weeklyTrainedDates.length
          : summary.trainingDayCount;
      final dayLabel = daysCount == 1 ? 'training day' : 'training days';
      final sessionLabel = sessionCount == 1 ? 'workout' : 'workouts';
      highlights.add(
        ProgressHighlight(
          label: 'Training',
          value: '$daysCount $dayLabel',
          detail: '$sessionCount $sessionLabel this week',
          icon: Icons.fitness_center_rounded,
          onPressed: onViewTrainingHistory,
          actionLabel: 'View workout history',
          semanticDetail:
              '$sessionCount $sessionLabel completed across $daysCount $dayLabel this week.',
        ),
      );
    }

    final strength = selectStrengthHighlight(
      snapshot.strengthSets ?? const [],
    );
    if (strength != null) {
      highlights.add(
        ProgressHighlight(
          label: 'Strength',
          value:
              '${distinctStrengthSessionCount(strength.records)} ${distinctStrengthSessionCount(strength.records) == 1 ? 'session' : 'sessions'}',
          detail: strength.comparisonText == null
              ? '${strength.exerciseName} · latest ${formatSet(strength.heaviest)}'
              : '${strength.exerciseName} · ${strength.comparisonText}',
          icon: Icons.show_chart_rounded,
          onPressed: () =>
              onViewStrengthHistory(strength.exerciseName, strength.exerciseId),
          actionLabel: 'View strength history',
          semanticDetail:
              '${strength.exerciseName}; latest recorded set ${formatSet(strength.heaviest)}.',
        ),
      );
    }

    final allWeights = snapshot.weightMeasurements.toList(growable: true)
      ..sort(compareMeasurementsChronologically);
    final dailyWeights = dailyWeightObservations(allWeights);
    if (dailyWeights.length >= 3) {
      final first = dailyWeights.first;
      final latest = dailyWeights.last;
      final difference = latest.weightKg! - first.weightKg!;
      final days = civilDayDifference(
        measurementDate(first),
        measurementDate(latest),
      );
      final period = days > 0
          ? 'since ${shortCivilDate(measurementDate(first))}'
          : 'across recorded measurements';
      final value = difference == 0
          ? '${dailyWeights.length} measurements'
          : '${formatWeight(difference.abs(), units)} ${difference < 0 ? 'lower' : 'higher'}';
      final detail = difference == 0 ? 'No change $period' : period;
      final semanticChange = difference == 0
          ? 'No change $period'
          : '${formatWeight(difference.abs(), units)} ${difference < 0 ? 'lower' : 'higher'} $period';
      highlights.add(
        ProgressHighlight(
          label: 'Weight',
          value: value,
          detail: detail,
          icon: weightDirectionIcon(allWeights),
          semanticDetail:
              'Weight: $semanticChange; the detailed Weight section shows the latest observation and history.',
        ),
      );
    }

    if (highlights.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: 'Progress highlights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProgressSectionHeading(title: 'Highlights'),
          const SizedBox(height: B05Layout.space8),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final twoColumns = constraints.maxWidth >= 330 && textScale < 1.5;
              final width = twoColumns
                  ? (constraints.maxWidth - B05Layout.space12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: B05Layout.space12,
                runSpacing: B05Layout.space12,
                children: [
                  for (final highlight in highlights)
                    SizedBox(
                      width: width,
                      child: ProgressHighlightTile(highlight: highlight),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProgressHighlightTile extends StatelessWidget {
  const ProgressHighlightTile({super.key, required this.highlight});

  final ProgressHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final accent = colors.action;
    final semanticLabel =
        '${highlight.label}: ${highlight.value}. '
        '${highlight.semanticDetail ?? highlight.detail}';
    final surface = B05Surface(
      tone: highlight.onPressed == null
          ? B05SurfaceTone.inset
          : B05SurfaceTone.interactive,
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  highlight.icon,
                  size: B05Layout.iconMedium,
                  color: accent,
                ),
              ),
              const SizedBox(width: B05Layout.space8),
              Expanded(
                child: Text(
                  highlight.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: B05Typography.caption(context).copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (highlight.onPressed != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: B05Layout.iconSmall,
                  color: colors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: B05Layout.space8),
          Text(
            highlight.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: B05Typography.title(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            highlight.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: B05Typography.caption(context),
          ),
        ],
      ),
    );
    final interactiveSurface = highlight.onPressed == null
        ? surface
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: b05Radius(B05SurfaceRadius.medium),
              onTap: highlight.onPressed,
              child: surface,
            ),
          );
    return Semantics(
      container: true,
      label: semanticLabel,
      button: highlight.onPressed != null,
      enabled: highlight.onPressed != null,
      onTap: highlight.onPressed,
      hint: highlight.actionLabel,
      child: KeyedSubtree(
        key: ValueKey('progress_highlight_${highlight.label.toLowerCase()}'),
        child: ExcludeSemantics(child: interactiveSurface),
      ),
    );
  }
}

class TrainingConsistencySection extends StatelessWidget {
  const TrainingConsistencySection({super.key, 
    required this.snapshot,
    required this.onViewHistory,
  });

  final ProgressDashboardSnapshot snapshot;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final thisWeek = workoutsThisWeek(snapshot);
    final lastFourWeeks = workoutsInRecentFourWeeks(snapshot);
    final totalWorkingSets = (snapshot.workouts ?? const []).fold<int>(
      0,
      (sum, w) => sum + w.workingSetsCount,
    );

    final thisWeekSummary =
        R08F4TrainingVolumePresentation.summarizeConsistency(thisWeek);
    final thisWeekSessionCount = thisWeekSummary.sessionCount;
    final thisWeekDaysCount = snapshot.weeklyTrainedDates.isNotEmpty
        ? snapshot.weeklyTrainedDates.length
        : thisWeekSummary.trainingDayCount;

    final lastFourWeeksSummary =
        R08F4TrainingVolumePresentation.summarizeConsistency(lastFourWeeks);
    final recentSessionCount = lastFourWeeksSummary.sessionCount;
    final recentDaysCount = lastFourWeeksSummary.trainingDayCount;

    final headingText = R08F4TrainingVolumePresentation.formatThisWeekHeading(
      thisWeekSessionCount,
    );
    final subtitleText = R08F4TrainingVolumePresentation.formatThisWeekSubtitle(
      sessionCount: thisWeekSessionCount,
      dayCount: thisWeekDaysCount,
    );
    final semanticsLabel =
        R08F4TrainingVolumePresentation.formatThisWeekSemantics(
          sessionCount: thisWeekSessionCount,
          dayCount: thisWeekDaysCount,
        );
    final fourWeeksSummaryText =
        R08F4TrainingVolumePresentation.formatRecentHistorySummary(
          sessionCount: recentSessionCount,
          dayCount: recentDaysCount,
          workingSetsCount: totalWorkingSets,
          weeks: 4,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProgressSectionHeading(title: 'Training consistency'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: semanticsLabel,
                child: ExcludeSemantics(
                  child: Text(
                    headingText,
                    style: B05Typography.metric(context),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitleText, style: B05Typography.body(context)),
              const SizedBox(height: B05Layout.space16),
              WeekCalendarStrip(
                todayLocalDate: snapshot.todayLocalDate,
                timezoneId: snapshot.timezoneId,
                trainedDates: snapshot.weeklyTrainedDates,
                workouts: thisWeek,
              ),
              if (fourWeeksSummaryText.isNotEmpty) ...[
                const SizedBox(height: B05Layout.space16),
                Text(
                  fourWeeksSummaryText,
                  style: B05Typography.caption(context),
                ),
              ],
              const SizedBox(height: B05Layout.space16),
              B05ActionButton(
                label: 'View workout history',
                icon: Icons.history_rounded,
                emphasis: B05ActionEmphasis.tertiary,
                onPressed: onViewHistory,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WeekCalendarStrip extends StatelessWidget {
  const WeekCalendarStrip({super.key, 
    required this.todayLocalDate,
    required this.timezoneId,
    required this.trainedDates,
    this.workouts = const [],
  });

  final String todayLocalDate;
  final String timezoneId;
  final Set<String> trainedDates;
  final List<ProgressWorkoutRecord> workouts;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final dates = LocalScheduleDateService();
    final currentWeekday = dates.weekday(todayLocalDate, timezoneId);
    final monday = dates.addCalendarDays(
      todayLocalDate,
      timezoneId,
      DateTime.monday - currentWeekday,
    );

    return Semantics(
      container: true,
      label: 'This week training activity calendar',
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            Expanded(
              child: Builder(
                builder: (context) {
                  final dateStr = dates.addCalendarDays(monday, timezoneId, i);
                  final sessionsOnDate = workouts
                      .where((w) => w.localDate == dateStr)
                      .length;
                  final isTrained = trainedDates.contains(dateStr);
                  final isToday = dateStr == todayLocalDate;
                  final dayLabel = days[i];

                  final semanticText =
                      R08F4TrainingVolumePresentation.formatDaySemanticLabel(
                        dayLabel: dayLabel,
                        sessionCount: sessionsOnDate > 0
                            ? sessionsOnDate
                            : (isTrained ? 1 : 0),
                        isToday: isToday,
                      );

                  return Semantics(
                    label: semanticText,
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: B05Typography.caption(context).copyWith(
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isToday
                                  ? colors.action
                                  : colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isTrained
                                  ? colors.action
                                  : colors.surfaceSubtle,
                              border: Border.all(
                                color: isToday ? colors.action : colors.border,
                                width: isToday ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              isTrained
                                  ? Icons.fitness_center_rounded
                                  : Icons.horizontal_rule_rounded,
                              size: isTrained ? 14 : 12,
                              color: isTrained
                                  ? colors.onAction
                                  : colors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StrengthSection extends StatelessWidget {
  const StrengthSection({super.key, required this.snapshot, required this.onViewHistory});

  final ProgressDashboardSnapshot snapshot;
  final void Function(String name, String stableExerciseId) onViewHistory;

  @override
  Widget build(BuildContext context) {
    final highlights = selectStrengthHighlights(
      snapshot.strengthSets ?? const [],
    );
    if (highlights.isEmpty) return const SizedBox.shrink();

    if (highlights.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProgressSectionHeading(title: 'Strength'),
          const SizedBox(height: B05Layout.space8),
          B05Surface(
            padding: const EdgeInsets.all(B05Layout.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved actual sets from strength sessions.',
                  style: B05Typography.body(context),
                ),
                const SizedBox(height: B05Layout.space8),
                for (final highlight in highlights)
                  Semantics(
                    button: true,
                    label:
                        'View actual performance history for ${highlight.exerciseName}',
                    hint: 'Open this exercise’s recorded sets over time',
                    onTap: () => onViewHistory(
                      highlight.exerciseName,
                      highlight.exerciseId,
                    ),
                    child: ExcludeSemantics(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        minVerticalPadding: B05Layout.space8,
                        title: Text(
                          highlight.exerciseName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: B05Typography.title(context),
                        ),
                        subtitle: Text(
                          '${formatSet(highlight.heaviest)} · ${distinctStrengthSessionCount(highlight.records)} ${distinctStrengthSessionCount(highlight.records) == 1 ? 'session' : 'sessions'}',
                          style: B05Typography.caption(context),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: context.b05Colors.textSecondary,
                        ),
                        onTap: () => onViewHistory(
                          highlight.exerciseName,
                          highlight.exerciseId,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    final highlight = highlights.first;

    final setFormatted = formatSet(highlight.heaviest);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProgressSectionHeading(title: 'Strength'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label:
                    '${highlight.exerciseName}, $setFormatted performed.'
                    '${highlight.comparisonText != null ? ' ${highlight.comparisonText}.' : ''}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: B05Layout.space8,
                        runSpacing: B05Layout.space4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            setFormatted,
                            style: B05Typography.metric(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        highlight.exerciseName,
                        style: B05Typography.body(context),
                      ),
                      if (highlight.comparisonText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          highlight.comparisonText!,
                          style: B05Typography.caption(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: B05Layout.space16),
              B05ActionButton(
                label: ConsumerCopy.historyAction('strength'),
                icon: Icons.history_rounded,
                emphasis: B05ActionEmphasis.tertiary,
                onPressed: () =>
                    onViewHistory(highlight.exerciseName, highlight.exerciseId),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StrengthEmptySection extends StatelessWidget {
  const StrengthEmptySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProgressSectionHeading(title: 'Strength'),
        const SizedBox(height: B05Layout.space8),
        Semantics(
          container: true,
          label: 'Your logged working sets will appear here after you train.',
          child: B05Surface(
            tone: B05SurfaceTone.inset,
            padding: const EdgeInsets.all(B05Layout.space16),
            child: Text(
              'Your logged working sets will appear here after you train.',
              style: B05Typography.body(context),
            ),
          ),
        ),
      ],
    );
  }
}

class NutritionAdherenceSection extends StatelessWidget {
  const NutritionAdherenceSection({super.key, 
    required this.summary,
    required this.fitnessGoalLabel,
    required this.onViewTargets,
  });

  final ProgressNutritionSummary summary;
  final String? fitnessGoalLabel;
  final VoidCallback onViewTargets;

  @override
  Widget build(BuildContext context) {
    final completeDays = completeNutritionDays(summary);
    final hasRichHistory = completeDays.length >= 2;
    final headlineSemantics = nutritionHeadlineSemantics(
      summary: summary,
      completeDays: completeDays,
      hasRichHistory: hasRichHistory,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProgressSectionHeading(title: 'Nutrition adherence'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: EdgeInsets.all(
            hasRichHistory ? B05Layout.space20 : B05Layout.space16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: headlineSemantics,
                child: ExcludeSemantics(
                  child: NutritionHeadline(
                    summary: summary,
                    completeDays: completeDays,
                    hasRichHistory: hasRichHistory,
                  ),
                ),
              ),
              SizedBox(
                height: hasRichHistory ? B05Layout.space16 : B05Layout.space12,
              ),
              NutritionTargetContext(
                summary: summary,
                fitnessGoalLabel: fitnessGoalLabel,
                onViewTargets: onViewTargets,
              ),
              if (hasRichHistory) ...[
                const SizedBox(height: B05Layout.space16),
                NutritionWeekStrip(days: summary.days),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class NutritionHeadline extends StatelessWidget {
  const NutritionHeadline({super.key, 
    required this.summary,
    required this.completeDays,
    required this.hasRichHistory,
  });

  final ProgressNutritionSummary summary;
  final List<ProgressNutritionDaySummary> completeDays;
  final bool hasRichHistory;

  @override
  Widget build(BuildContext context) {
    if (!hasRichHistory) {
      final day = completeDays.isEmpty ? null : completeDays.last;
      final factLine = nutritionCompactFactLine(day);
      final status = completeDays.length == 1
          ? '1 complete logged day'
          : '${summary.loggedDaysCount} ${summary.loggedDaysCount == 1 ? 'logged day' : 'logged days'} · Some nutrition details are incomplete';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            factLine ?? status,
            style: factLine == null
                ? B05Typography.title(context)
                : B05Typography.title(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800),
          ),
          if (factLine != null) ...[
            const SizedBox(height: 4),
            Text(status, style: B05Typography.caption(context)),
          ],
        ],
      );
    }

    final hasCalorieAverage =
        summary.averageCaloriesKcal != null &&
        summary.calorieEvidenceDaysCount >= 2;
    final hasProteinAverage =
        summary.averageProteinG != null &&
        summary.proteinEvidenceDaysCount >= 2;
    final titleText = nutritionAdherenceLabel(summary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasCalorieAverage
              ? '${formatVolume(summary.averageCaloriesKcal!)} kcal'
              : hasProteinAverage
              ? '${formatNumber(summary.averageProteinG!)} g protein'
              : '${completeDays.length} complete logged days',
          style: B05Typography.metric(context),
        ),
        if (hasCalorieAverage) ...[
          const SizedBox(height: 2),
          Text(
            'Average across ${summary.calorieEvidenceDaysCount} complete ${summary.calorieEvidenceDaysCount == 1 ? 'day' : 'days'}',
            style: B05Typography.caption(context),
          ),
        ],
        const SizedBox(height: 2),
        Text(titleText, style: B05Typography.body(context)),
        if (hasProteinAverage && summary.averageProteinG != null) ...[
          const SizedBox(height: 4),
          Text(
            summary.targetProteinG != null
                ? 'Avg protein: ${formatNumber(summary.averageProteinG!)} / ${formatNumber(summary.targetProteinG!)} g across ${summary.proteinEvidenceDaysCount} complete ${summary.proteinEvidenceDaysCount == 1 ? 'day' : 'days'}'
                : 'Avg protein: ${formatNumber(summary.averageProteinG!)} g across ${summary.proteinEvidenceDaysCount} complete ${summary.proteinEvidenceDaysCount == 1 ? 'day' : 'days'}',
            style: B05Typography.caption(context),
          ),
        ],
      ],
    );
  }
}

class NutritionTargetContext extends StatelessWidget {
  const NutritionTargetContext({super.key, 
    required this.summary,
    required this.fitnessGoalLabel,
    required this.onViewTargets,
  });

  final ProgressNutritionSummary summary;
  final String? fitnessGoalLabel;
  final VoidCallback onViewTargets;

  @override
  Widget build(BuildContext context) {
    final hasTargetValues =
        summary.targetCaloriesKcal != null || summary.targetProteinG != null;
    final hasTargetContext = hasTargetValues || summary.targetGoalType != null;
    final values = <String>[
      if (summary.targetCaloriesKcal != null)
        '${formatVolume(summary.targetCaloriesKcal!)} kcal',
      if (summary.targetProteinG != null)
        '${formatNumber(summary.targetProteinG!)} g protein',
    ];

    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.all(B05Layout.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: [
              if (hasTargetContext) 'Today’s nutrition target.',
              if (values.isNotEmpty) '${values.join(' · ')}.',
              if (hasTargetContext && fitnessGoalLabel != null)
                'Fitness goal: $fitnessGoalLabel.',
              if (summary.targetGoalType != null)
                'Nutrition strategy: ${progressNutritionStrategyLabel(summary.targetGoalType!)}.',
              if (!hasTargetContext) 'No nutrition target saved for today.',
              if (hasTargetContext && !hasTargetValues)
                'No calorie or macro target values are saved for today.',
            ].join(' '),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today’s nutrition target',
                    style: B05Typography.label(context),
                  ),
                  const SizedBox(height: B05Layout.space4),
                  if (values.isNotEmpty)
                    Text(
                      values.join(' · '),
                      style: B05Typography.title(context),
                    ),
                  if (hasTargetContext && fitnessGoalLabel != null) ...[
                    if (values.isNotEmpty)
                      const SizedBox(height: B05Layout.space4),
                    Text(
                      'Fitness goal: $fitnessGoalLabel',
                      style: B05Typography.body(context),
                    ),
                  ],
                  if (summary.targetGoalType != null) ...[
                    if (values.isNotEmpty || fitnessGoalLabel != null)
                      const SizedBox(height: B05Layout.space4),
                    Text(
                      'Nutrition strategy: ${progressNutritionStrategyLabel(summary.targetGoalType!)}',
                      style: B05Typography.body(context),
                    ),
                  ],
                  if (!hasTargetContext)
                    Text(
                      'No nutrition target saved for today.',
                      style: B05Typography.body(context),
                    ),
                  if (hasTargetContext && !hasTargetValues)
                    Text(
                      'No calorie or macro target values are saved for today.',
                      style: B05Typography.body(context),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: B05Layout.space8),
          B05ActionButton(
            label: hasTargetContext
                ? 'View nutrition targets'
                : 'Set nutrition target',
            hint: hasTargetContext
                ? 'Open the saved nutrition target for today.'
                : 'Open Goal & targets to set today’s values.',
            icon: Icons.open_in_new_rounded,
            emphasis: B05ActionEmphasis.tertiary,
            onPressed: onViewTargets,
          ),
        ],
      ),
    );
  }
}

class NutritionWeekStrip extends StatelessWidget {
  const NutritionWeekStrip({super.key, required this.days});

  final List<ProgressNutritionDaySummary> days;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return Semantics(
      container: true,
      label: 'Weekly nutrition adherence day by day',
      child: Row(
        children: [
          for (final day in days) ...[
            Expanded(
              child: Builder(
                builder: (context) {
                  final hasLog = day.hasFoodLog;
                  final metProtein = day.isProteinTargetMet;
                  final incomplete = day.isNutrientIncomplete;

                  final semanticLabel = !hasLog
                      ? '${day.dayLabel}, no meals logged.'
                      : '${day.dayLabel}, logged.'
                            '${day.caloriesKcal != null ? ' ${day.caloriesKcal!.round()} kcal.' : ''}'
                            '${metProtein ? ' Protein target met.' : ''}'
                            '${incomplete ? ' Nutrition data is incomplete.' : ''}';

                  return Semantics(
                    label: semanticLabel,
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            day.dayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: B05Typography.caption(context).copyWith(
                              fontWeight: day.isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: day.isToday
                                  ? colors.action
                                  : colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: metProtein
                                  ? colors.success.indicator
                                  : incomplete
                                  ? colors.warning.container
                                  : hasLog
                                  ? colors.surfaceSubtle
                                  : colors.surfaceSubtle,
                              border: Border.all(
                                color: day.isToday
                                    ? colors.action
                                    : metProtein
                                    ? colors.success.indicator
                                    : incomplete
                                    ? colors.warning.indicator
                                    : colors.border,
                                width: day.isToday ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              metProtein
                                  ? Icons.check_rounded
                                  : incomplete
                                  ? Icons.help_outline_rounded
                                  : hasLog
                                  ? Icons.restaurant_rounded
                                  : Icons.horizontal_rule_rounded,
                              size: 14,
                              color: metProtein
                                  ? Colors.white
                                  : hasLog
                                  ? colors.textPrimary
                                  : colors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TrainingVolumeSection extends StatelessWidget {
  const TrainingVolumeSection({super.key, required this.snapshot, this.units = 'kg'});

  final ProgressDashboardSnapshot snapshot;
  final String units;

  @override
  Widget build(BuildContext context) {
    final summary = R08F4TrainingVolumePresentation.summarizeVolume(
      allWorkouts: snapshot.workouts ?? const <ProgressWorkoutRecord>[],
      todayLocalDate: snapshot.todayLocalDate,
      timezoneId: snapshot.timezoneId,
      units: units,
    );

    final semanticLabel = R08F4TrainingVolumePresentation.formatVolumeSemantics(
      displayVolume: summary.displayVolume,
      units: units,
      useRecent: summary.useRecent,
    );
    final subtitle = R08F4TrainingVolumePresentation.formatVolumeSubtitle(
      units: units,
      useRecent: summary.useRecent,
    );
    final comparison = R08F4TrainingVolumePresentation.formatVolumeComparison(
      summary,
    );
    final semanticComparison = comparison == null ? '' : ' $comparison.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProgressSectionHeading(title: 'Loaded volume'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Semantics(
            label: '$semanticLabel$semanticComparison',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  R08F4TrainingVolumePresentation.formatVolume(
                    summary.displayVolume,
                  ),
                  style: B05Typography.metric(context),
                ),
                Text(subtitle, style: B05Typography.body(context)),
                if (comparison != null) ...[
                  const SizedBox(height: 4),
                  Text(comparison, style: B05Typography.caption(context)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MuscleBalanceSection extends StatelessWidget {
  const MuscleBalanceSection({super.key, required this.readModel});

  final B02MuscleVolumeReadModel readModel;

  @override
  Widget build(BuildContext context) {
    final muscles =
        readModel.muscles
            .where((muscle) => muscle.workingSetUnits > 0)
            .toList(growable: false)
          ..sort(
            (first, second) =>
                second.workingSetUnits.compareTo(first.workingSetUnits),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProgressSectionHeading(title: 'Recent training emphasis'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            children: [
              for (final muscle in muscles.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: B05Layout.space12),
                  child: Semantics(
                    label:
                        '${muscle.displayName}, ${formatNumber(muscle.workingSetUnits)} working set units.',
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: B05Layout.space8,
                          runSpacing: B05Layout.space4,
                          children: [
                            Text(
                              muscle.displayName,
                              style: B05Typography.label(context),
                            ),
                            Text(
                              '${formatNumber(muscle.workingSetUnits)} working sets',
                              style: B05Typography.caption(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class MeasurementsSection extends StatelessWidget {
  const MeasurementsSection({super.key, 
    required this.measurements,
    required this.onLogMeasurement,
    required this.onViewHistory,
  });

  final List<ProgressMeasurementRecord> measurements;
  final VoidCallback onLogMeasurement;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final ordered = measurements.toList(growable: true)
      ..sort(compareMeasurementsNewestFirst);
    final values = bodyMeasurementValues(ordered);
    final latestEntry = ordered.first;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compactActions = textScale >= 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProgressSectionHeading(title: 'Measurements'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final value in values)
                Padding(
                  padding: const EdgeInsets.only(bottom: B05Layout.space8),
                  child: Semantics(
                    label:
                        '${value.label}, ${formatNumber(value.value)} centimetres${value.changeText == null ? '.' : '. ${value.changeText}.'}',
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value.label,
                            style: B05Typography.label(context),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatNumber(value.value)} cm',
                            style: B05Typography.body(context),
                          ),
                          if (value.changeText != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              value.changeText!,
                              style: B05Typography.caption(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              Text(
                'Latest entry · ${shortCivilDate(measurementDate(latestEntry))}',
                style: B05Typography.caption(context),
              ),
              const SizedBox(height: B05Layout.space12),
              B05ActionButton(
                label: ConsumerCopy.historyAction('measurement'),
                icon: Icons.history_rounded,
                emphasis: B05ActionEmphasis.tertiary,
                onPressed: onViewHistory,
              ),
              B05ActionButton(
                label: compactActions ? 'Log' : 'Log measurement',
                hint: compactActions ? 'Log measurement' : null,
                icon: Icons.add_rounded,
                emphasis: B05ActionEmphasis.tertiary,
                onPressed: onLogMeasurement,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProgressSectionHeading extends StatelessWidget {
  const ProgressSectionHeading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: B05Typography.caption(
        context,
      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: .5),
    );
  }
}

