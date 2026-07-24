import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
    return FutureBuilder<WorkoutSession?>(
      future: ref.read(workoutRepositoryProvider).getLastCompletedSession(),
      builder: (context, snapshot) {
        final lastSession = snapshot.data;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isRestDay ? Colors.blue.withValues(alpha: 0.1) : AppColors.primaryGlow,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRestDay ? Icons.spa_rounded : Icons.fitness_center_rounded,
                        color: isRestDay ? Colors.blue : AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TODAY\'S WORKOUT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(todayWorkoutName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            isRestDay ? 'Time to recover and heal' : '$exerciseCount Exercises scheduled',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (!isRestDay)
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 32),
                        onPressed: onStartWorkout,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.border),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showManualLogSheet(context),
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('Log Completed Session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    if (lastSession != null)
                      TextButton.icon(
                        onPressed: () => onRepeatWorkout(lastSession),
                        icon: const Icon(Icons.history_rounded, size: 14),
                        label: const Text('Repeat Last', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
