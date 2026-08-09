import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/database/app_database.dart';
import '../education/b05_education_content.dart';
import '../media/b05_muscle_diagram.dart';
import '../workout_player/widgets/plate_calculator_sheet.dart';
import 'exercise_history_screen.dart';

class ExerciseDetailsSheet extends ConsumerWidget {
  final Exercise exercise;

  const ExerciseDetailsSheet({super.key, required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              for (var index = 0; index < muscles.length; index++)
                Chip(
                  avatar: Icon(
                    index == 0
                        ? Icons.star_outline_rounded
                        : Icons.circle_outlined,
                    size: 16,
                  ),
                  label: Text(
                    '${muscles[index]} · ${index == 0 ? 'Primary' : 'Secondary'}',
                  ),
                ),
              if (exercise.equipment.trim().isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.fitness_center_outlined, size: 16),
                  label: Text(exercise.equipment),
                ),
            ],
          ),
          const SizedBox(height: B05Layout.space16),
          Wrap(
            spacing: B05Layout.space8,
            runSpacing: B05Layout.space8,
            children: [
              B05ActionButton(
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
                icon: Icons.history_rounded,
                label: 'History',
                emphasis: B05ActionEmphasis.secondary,
              ),
              B05ActionButton(
                onPressed: () => showIndiFitBottomSheet<void>(
                  context: context,
                  semanticLabel: 'Plate calculator',
                  builder: (_) => const PlateCalculatorSheet(targetWeight: 80),
                ),
                icon: Icons.calculate_outlined,
                label: 'Plate calculator',
                emphasis: B05ActionEmphasis.secondary,
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space20),

          Text(
            'FORM',
            style: B05Typography.caption(
              context,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: .6),
          ),
          const SizedBox(height: B05Layout.space8),
          if (cues.isEmpty)
            Text(
              'Quick form cues are not available yet.',
              style: B05Typography.body(context),
            )
          else
            ...cues
                .take(3)
                .toList()
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: B05Layout.space8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: B05Layout.iconSmall,
                          color: colors.action,
                        ),
                        const SizedBox(width: B05Layout.space8),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: B05Typography.body(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: B05Layout.space4),
          B05ActionButton(
            onPressed: () => showIndiFitBottomSheet<void>(
              context: context,
              semanticLabel: 'Exercise guide',
              builder: (_) => _ExerciseGuideContent(
                exercise: exercise,
                cues: cues,
                mistakes: mistakes,
              ),
            ),
            icon: Icons.menu_book_outlined,
            label: 'View full guide',
            emphasis: B05ActionEmphasis.tertiary,
          ),
          const SizedBox(height: B05Layout.space20),
          _ExerciseEducationPreview(
            exerciseName: exercise.name,
            stableExerciseId: exercise.stableId,
            cues: cues,
            mistakes: mistakes,
          ),
          const SizedBox(height: B05Layout.space20),
        ],
      ),
    );
  }
}

/// Keeps the existing B05 education authority reachable from the compact
/// exercise surface without making the full catalogue feel like the primary
/// detail view. The complete checklist, cues and personal guidance remain in
/// the guide sheet opened above.
class _ExerciseEducationPreview extends ConsumerWidget {
  const _ExerciseEducationPreview({
    required this.exerciseName,
    required this.stableExerciseId,
    required this.cues,
    required this.mistakes,
  });

  final String exerciseName;
  final String? stableExerciseId;
  final List<String> cues;
  final List<String> mistakes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = B05ExerciseEducationQuery(
      exerciseName: exerciseName,
      stableExerciseId: stableExerciseId,
      catalogueCues: cues,
      catalogueMistakes: mistakes,
    );
    final visualRegistry = ref.watch(b05MuscleVisualRegistryProvider);
    final state = ref.watch(b05ExerciseEducationProvider(query));
    return Semantics(
      container: true,
      label: 'Exercise education',
      child: B05Surface(
        radius: B05SurfaceRadius.medium,
        child: state.when(
          loading: () => const B05StatusMessage(
            status: B05SemanticStatus.info,
            label: 'Loading exercise education',
          ),
          error: (_, _) => const B05StatusMessage(
            status: B05SemanticStatus.unavailable,
            label: 'Exercise education is unavailable',
            value: 'Open the guide to review the available cues.',
          ),
          data: (model) {
            final checklist = model.checklist.take(2).toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exercise education', style: B05Typography.title(context)),
                const SizedBox(height: B05Layout.space12),
                Text('Form checklist', style: B05Typography.label(context)),
                const SizedBox(height: B05Layout.space4),
                for (final item in checklist)
                  Padding(
                    padding: const EdgeInsets.only(bottom: B05Layout.space4),
                    child: Semantics(
                      container: true,
                      label: item.label,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: B05Layout.iconSmall,
                            color: context.b05Colors.action,
                          ),
                          const SizedBox(width: B05Layout.space8),
                          Expanded(
                            child: Text(
                              item.label,
                              style: B05Typography.body(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (visualRegistry != null &&
                    visualRegistry.regions.isNotEmpty) ...[
                  const SizedBox(height: B05Layout.space8),
                  B05InteractiveMuscleDiagram(
                    muscles: model.muscles,
                    visualRegistry: visualRegistry,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExerciseGuideContent extends StatelessWidget {
  const _ExerciseGuideContent({
    required this.exercise,
    required this.cues,
    required this.mistakes,
  });

  final Exercise exercise;
  final List<String> cues;
  final List<String> mistakes;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space20,
        B05Layout.space8,
        B05Layout.space20,
        B05Layout.space24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exercise guide', style: B05Typography.pageTitle(context)),
          const SizedBox(height: B05Layout.space4),
          Text(exercise.name, style: B05Typography.body(context)),
          const SizedBox(height: B05Layout.space20),
          Text('Form cues', style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space8),
          if (cues.isEmpty)
            Text(
              'Form cues are not available yet.',
              style: B05Typography.body(context),
            )
          else
            for (final cue in cues)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.check_rounded,
                  color: context.b05Colors.action,
                ),
                title: Text(cue),
              ),
          const SizedBox(height: B05Layout.space12),
          Text('Common mistakes', style: B05Typography.title(context)),
          const SizedBox(height: B05Layout.space8),
          if (mistakes.isEmpty)
            Text(
              'Common mistakes are not available yet.',
              style: B05Typography.body(context),
            )
          else
            for (final mistake in mistakes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.close_rounded,
                  color: context.b05Colors.danger.foreground,
                ),
                title: Text(mistake),
              ),
          const SizedBox(height: B05Layout.space16),
          B05ExerciseEducationPanel(
            exerciseName: exercise.name,
            stableExerciseId: exercise.stableId,
            catalogueCues: cues,
            catalogueMistakes: mistakes,
          ),
        ],
      ),
    );
  }
}
