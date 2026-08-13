import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
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
    final colors = context.b05Colors;
    final routineDetail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          routineName,
          style: B05Typography.pageTitle(
            context,
          ).copyWith(fontSize: 24, letterSpacing: -0.5),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Exercise ${currentExerciseIndex + 1} of ${exercises.length}',
          style: B05Typography.caption(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    final timer = B05Surface(
      tone: B05SurfaceTone.selected,
      radius: B05SurfaceRadius.medium,
      padding: const EdgeInsets.symmetric(
        horizontal: B05Layout.space12,
        vertical: B05Layout.space8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            color: colors.action,
            size: B05Layout.iconMedium,
          ),
          const SizedBox(width: B05Layout.space4),
          Text(
            _formatDuration(elapsedSeconds),
            style: B05Typography.title(
              context,
            ).copyWith(color: colors.action, letterSpacing: 0.5),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, _) {
            final compact =
                MediaQuery.sizeOf(context).width <
                    B05Layout.compactBreakpoint ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  routineDetail,
                  const SizedBox(height: B05Layout.space8),
                  Align(alignment: Alignment.centerRight, child: timer),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: routineDetail),
                const SizedBox(width: B05Layout.space12),
                timer,
              ],
            );
          },
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
                      fontSize: Theme.of(context).textTheme.bodySmall!.fontSize,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? colors.action : colors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: colors.selected,
                  backgroundColor: colors.inset,
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
