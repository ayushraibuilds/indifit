import 'package:flutter/material.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../core/utils/weekly_training_goal_calculator.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';

/// The Training "This week" goal line: a small ring, "2 of 3", and the run
/// of weeks that met their goal (hidden at zero).
class TrainingWeekGoalSummary extends StatelessWidget {
  const TrainingWeekGoalSummary({
    super.key,
    required this.status,
    this.onEditGoal,
  });

  final WeeklyTrainingGoalStatus status;

  /// Opens the goal sheet. Null when the goal comes from the active plan.
  final VoidCallback? onEditGoal;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final run = WeeklyTrainingGoalCopy.weeksInARow(status);
    final ringColor = status.isMet ? colors.success.foreground : colors.action;
    return B05Surface(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space12,
        B05Layout.space12,
        B05Layout.space4,
        B05Layout.space12,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: SizedBox.square(
              dimension: 44,
              child: CircularProgressIndicator(
                key: const ValueKey('training_week_goal_ring'),
                value: (status.completed / status.goal).clamp(0, 1).toDouble(),
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                color: ringColor,
                backgroundColor: colors.surfaceSubtle,
              ),
            ),
          ),
          const SizedBox(width: B05Layout.space12),
          Expanded(
            child: Semantics(
              container: true,
              label: [WeeklyTrainingGoalCopy.thisWeek(status), ?run].join('. '),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      WeeklyTrainingGoalCopy.progress(status),
                      style: B05Typography.title(context),
                    ),
                    Text(
                      'workouts this week',
                      style: B05Typography.caption(context),
                    ),
                    if (run != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        run,
                        style: B05Typography.caption(context).copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (onEditGoal != null)
            B05IconAction(
              icon: Icons.edit_outlined,
              label: 'Change weekly goal',
              onPressed: onEditGoal,
            ),
        ],
      ),
    );
  }
}

/// One sheet to pick 1–7 workouts a week. Pops the chosen goal, or null.
class TrainingWeekGoalSheet extends StatefulWidget {
  const TrainingWeekGoalSheet({super.key, required this.initialGoal});

  final int initialGoal;

  @override
  State<TrainingWeekGoalSheet> createState() => _TrainingWeekGoalSheetState();
}

class _TrainingWeekGoalSheetState extends State<TrainingWeekGoalSheet> {
  late int _goal = WeeklyTrainingGoalCalculator.clampUserGoal(
    widget.initialGoal,
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space16,
        B05Layout.space8,
        B05Layout.space16,
        B05Layout.space16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly goal', style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Workouts per week. Changing it never changes past weeks.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space16),
          Wrap(
            spacing: B05Layout.space8,
            runSpacing: B05Layout.space8,
            children: [
              for (
                var goal = WeeklyTrainingGoalCalculator.minGoal;
                goal <= WeeklyTrainingGoalCalculator.maxGoal;
                goal++
              )
                ChoiceChip(
                  key: ValueKey('training_week_goal_option_$goal'),
                  label: Text('$goal'),
                  selected: goal == _goal,
                  onSelected: (_) => setState(() => _goal = goal),
                ),
            ],
          ),
          const SizedBox(height: B05Layout.space16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _goal),
              child: const Text('Save goal'),
            ),
          ),
        ],
      ),
    ),
  );
}
