import 'package:flutter/material.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';
import '../education/b05_education_content.dart';
import 'exercise_history_screen.dart';

class ExerciseDetailsSheet extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailsSheet({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final muscles = exercise.muscleGroups
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final cues = exercise.formCues
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final mistakes = exercise.commonMistakes
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return Material(
      color: colors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Exercise Name & Difficulty
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.action.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.action.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    exercise.difficulty,
                    style: TextStyle(
                      color: colors.action,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Muscle Groups & Equipment Badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...muscles.map(
                  (m) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      m,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    '🔧 ${exercise.equipment}',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
            Divider(color: colors.border, height: 32),

            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close sheet first
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ExerciseHistoryScreen(exerciseName: exercise.name),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_rounded),
              label: const Text('View 1RM Trend & Plate Calc'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.action,
                foregroundColor: colors.onAction,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Form Cues List
            Text(
              'FORM CUES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            if (cues.isEmpty)
              Text(
                'Form cues are not available for this exercise yet.',
                style: B05Typography.body(context),
              )
            else
              ...cues.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key + 1}. ',
                        style: TextStyle(
                          color: colors.action,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: B05Typography.body(
                            context,
                          ).copyWith(height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Common Mistakes List
            Text(
              'COMMON MISTAKES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colors.danger.foreground,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            if (mistakes.isEmpty)
              Text(
                'Common mistakes are not available for this exercise yet.',
                style: B05Typography.body(context),
              )
            else
              ...mistakes.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: colors.danger.foreground,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m,
                          style: B05Typography.body(
                            context,
                          ).copyWith(height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            B05ExerciseEducationPanel(
              exerciseName: exercise.name,
              stableExerciseId: exercise.stableId,
              catalogueCues: cues,
              catalogueMistakes: mistakes,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
