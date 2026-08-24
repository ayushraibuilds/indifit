import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/fixtures/exercise_display_muscles.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/database/app_database.dart';
import '../education/b05_education_content.dart';
import '../media/b05_exercise_visual_registry.dart';
import '../workout_player/widgets/plate_calculator_sheet.dart';
import 'exercise_history_screen.dart';

class ExerciseDetailsSheet extends ConsumerWidget {
  final Exercise exercise;

  const ExerciseDetailsSheet({super.key, required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.b05Colors;
    final registry = ref.watch(b05ExerciseVisualRegistryProvider).valueOrNull ??
        const B05ExerciseVisualRegistry.empty();
    final displayMuscles = ExerciseDisplayMuscles.fromMuscleGroups(
      exercise.muscleGroups,
    );
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
          if (exercise.difficulty.trim().isNotEmpty) ...[
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
            const SizedBox(height: B05Layout.space8),
          ],
          // Approved visual / MuscleMap fallback
          B05Surface(
            tone: B05SurfaceTone.inset,
            padding: const EdgeInsets.all(B05Layout.space8),
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: Center(
                child: ExerciseVisual(
                  canonicalExerciseUuid: exercise.stableId ?? '',
                  registry: registry,
                  displayMuscles: ExerciseVisualMuscleFacts(
                    primaryMuscle: displayMuscles.primary,
                    secondaryMuscles: displayMuscles.secondary,
                  ),
                  equipment: exercise.equipment.trim().isNotEmpty
                      ? exercise.equipment
                      : null,
                  semanticsContext: '${exercise.name} exercise visual',
                ),
              ),
            ),
          ),
          const SizedBox(height: B05Layout.space8),
          Wrap(
            spacing: B05Layout.space8,
            runSpacing: B05Layout.space8,
            children: [
              if (displayMuscles.hasPrimary)
                Chip(
                  avatar: const Icon(Icons.star_rounded, size: 16),
                  label: Text('${displayMuscles.primary} · Primary'),
                ),
              for (final secondary in displayMuscles.secondary)
                Chip(
                  avatar: const Icon(Icons.circle_outlined, size: 14),
                  label: Text('$secondary · Secondary'),
                ),
              if (exercise.equipment.trim().isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.fitness_center_outlined, size: 16),
                  label: Text(exercise.equipment),
                ),
            ],
          ),
          const SizedBox(height: B05Layout.space12),
          Text(
            'PERFORMANCE',
            style: B05Typography.caption(
              context,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: .6),
          ),
          const SizedBox(height: B05Layout.space8),
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
                      builder: (context) => ExerciseHistoryScreen(
                        exerciseName: exercise.name,
                        stableExerciseId: exercise.stableId,
                      ),
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
          const SizedBox(height: B05Layout.space12),

          Text(
            'GUIDE',
            style: B05Typography.caption(
              context,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: .6),
          ),
          const SizedBox(height: B05Layout.space8),
          if (cues.isNotEmpty)
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
        ],
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
