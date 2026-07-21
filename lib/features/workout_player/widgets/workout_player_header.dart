import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../data/database/app_database.dart';

class WorkoutPlayerHeader extends StatelessWidget {
  final String routineName;
  final int elapsedSeconds;
  final List<RoutineExercise> exercises;
  final int currentExerciseIndex;
  final ValueChanged<int> onExerciseSelected;

  const WorkoutPlayerHeader({
    super.key,
    required this.routineName,
    required this.elapsedSeconds,
    required this.exercises,
    required this.currentExerciseIndex,
    required this.onExerciseSelected,
  });

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routineName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Exercise ${currentExerciseIndex + 1} of ${exercises.length}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(elapsedSeconds),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(exercises.length, (idx) {
              final isSelected = idx == currentExerciseIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(
                    exercises[idx].exerciseName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.cardBackground,
                  onSelected: (_) => onExerciseSelected(idx),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
