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
    final List<String> muscles = exercise.muscleGroups.split(',');
    final List<String> cues = exercise.formCues.split('\n');
    final List<String> mistakes = exercise.commonMistakes.split('\n');

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space20,
        B05Layout.space8,
        B05Layout.space20,
        B05Layout.space24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise.name,
                  style: B05Typography.pageTitle(context),
                ),
              ),
              B05IconAction(
                icon: Icons.close_rounded,
                label: 'Close exercise details',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space8),
          B05Surface(
            tone: B05SurfaceTone.selected,
            radius: B05SurfaceRadius.small,
            padding: const EdgeInsets.symmetric(
              horizontal: B05Layout.space8,
              vertical: B05Layout.space4,
            ),
            child: Text(
              exercise.difficulty,
              style: B05Typography.caption(
                context,
              ).copyWith(color: colors.action, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: B05Layout.space12),

          Wrap(
            spacing: B05Layout.space8,
            runSpacing: B05Layout.space8,
            children: [
              ...muscles.map((m) => Chip(label: Text(m.trim()))),
              Chip(
                avatar: const Icon(Icons.fitness_center_outlined, size: 16),
                label: Text(exercise.equipment),
              ),
            ],
          ),
          Divider(color: colors.border, height: B05Layout.space32),

          SizedBox(
            width: double.infinity,
            child: B05ActionButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ExerciseHistoryScreen(exerciseName: exercise.name),
                  ),
                );
              },
              icon: Icons.analytics_rounded,
              label: 'View history and plate calculator',
            ),
          ),
          const SizedBox(height: B05Layout.space20),

          Text(
            'Form cues',
            style: B05Typography.caption(
              context,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: .6),
          ),
          const SizedBox(height: B05Layout.space8),
          ...cues.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: B05Layout.space8),
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
                      style: B05Typography.body(context).copyWith(height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: B05Layout.space16),

          Text(
            'Common mistakes',
            style: B05Typography.caption(context).copyWith(
              color: colors.danger.foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: B05Layout.space8),
          ...mistakes.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: B05Layout.space8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    color: colors.danger.foreground,
                    size: B05Layout.iconSmall,
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: Text(
                      m,
                      style: B05Typography.body(context).copyWith(height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: B05Layout.space12),
          B05ExerciseEducationPanel(
            exerciseName: exercise.name,
            stableExerciseId: exercise.stableId,
            catalogueCues: cues,
            catalogueMistakes: mistakes,
          ),
          const SizedBox(height: B05Layout.space20),
        ],
      ),
    );
  }
}
