import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../workout_player/widgets/manual_log_sheet.dart';

class TodayWorkoutCard extends ConsumerWidget {
  final String todayWorkoutName;
  final bool isRestDay;
  final int exerciseCount;
  final DateTime selectedDate;
  final VoidCallback onStartWorkout;
  final ValueChanged<WorkoutSession> onRepeatWorkout;
  final VoidCallback? onLogCompleted;

  const TodayWorkoutCard({
    super.key,
    required this.todayWorkoutName,
    required this.isRestDay,
    required this.exerciseCount,
    required this.selectedDate,
    required this.onStartWorkout,
    required this.onRepeatWorkout,
    this.onLogCompleted,
  });

  void _showManualLogSheet(BuildContext context) {
    showIndiFitBottomSheet(
      context: context,
      semanticLabel: 'Log completed workout',
      builder: (context) => ManualLogSheet(
        selectedDate: selectedDate,
        initialWorkoutName: isRestDay ? 'Extra Workout' : todayWorkoutName,
      ),
    ).then((saved) {
      if (saved == true && onLogCompleted != null) {
        onLogCompleted!();
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.b05Colors;
    return FutureBuilder<WorkoutSession?>(
      future: ref.read(workoutRepositoryProvider).getLastCompletedSession(),
      builder: (context, snapshot) {
        final lastSession = snapshot.data;
        return B05Surface(
          radius: B05SurfaceRadius.large,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isRestDay
                          ? colors.info.container
                          : colors.selected,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isRestDay
                          ? Icons.bedtime_rounded
                          : Icons.fitness_center_rounded,
                      color: isRestDay
                          ? colors.info.indicator
                          : colors.action,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TODAY\'S WORKOUT',
                          style: B05Typography.caption(context).copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          todayWorkoutName,
                          style: B05Typography.title(context).copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isRestDay
                              ? 'Time to recover and heal'
                              : '$exerciseCount Exercises scheduled',
                          style: B05Typography.caption(context).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (!isRestDay)
                    IconButton(
                      icon: Icon(
                        Icons.play_circle_fill_rounded,
                        color: colors.action,
                        size: 32,
                      ),
                      onPressed: onStartWorkout,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: colors.border),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _showManualLogSheet(context),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text(
                      'Log Completed Session',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.action,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (lastSession != null)
                    TextButton.icon(
                      onPressed: () => onRepeatWorkout(lastSession),
                      icon: const Icon(Icons.history_rounded, size: 14),
                      label: const Text(
                        'Repeat Last',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
