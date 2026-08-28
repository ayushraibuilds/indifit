import '../../core/fixtures/exercise_family_metadata.dart';
import '../../data/database/app_database.dart';

class ExerciseFamilyPresentationItem {
  const ExerciseFamilyPresentationItem.independent(this.primaryExercise)
    : family = null,
      visibleVariants = const [];

  const ExerciseFamilyPresentationItem.family({
    required this.primaryExercise,
    required this.family,
    required this.visibleVariants,
  });

  final Exercise primaryExercise;
  final ExerciseFamilyMetadata? family;
  final List<Exercise> visibleVariants;

  bool get isFamily => family != null;
  int get variantCount => family == null ? 0 : family!.members.length - 1;
}

/// Collapses only exact, reviewed family UUIDs that are present together in
/// the current result set. A lone variant remains independent, which keeps an
/// exact variant search useful and makes incomplete data fail open.
List<ExerciseFamilyPresentationItem> buildExerciseFamilyPresentation(
  List<Exercise> exercises, {
  ExerciseFamilyRegistry? registry,
}) {
  final familyRegistry = registry ?? reviewedExerciseFamilyRegistry;
  final byId = <String, Exercise>{
    for (final exercise in exercises)
      if (exercise.stableId?.trim().isNotEmpty == true)
        exercise.stableId!.trim(): exercise,
  };
  final output = <ExerciseFamilyPresentationItem>[];

  for (final exercise in exercises) {
    final exerciseId = exercise.stableId?.trim();
    final family = familyRegistry.familyForExerciseId(exerciseId);
    if (family == null || exerciseId == null) {
      output.add(ExerciseFamilyPresentationItem.independent(exercise));
      continue;
    }

    final base = byId[family.baseExerciseId];
    if (base == null) {
      output.add(ExerciseFamilyPresentationItem.independent(exercise));
      continue;
    }
    if (exerciseId != family.baseExerciseId) continue;

    final variants = <Exercise>[];
    for (final member in family.members) {
      if (member.role != ExerciseFamilyMemberRole.variant) continue;
      final variant = byId[member.exerciseId];
      if (variant != null) variants.add(variant);
    }
    if (variants.isEmpty) {
      output.add(ExerciseFamilyPresentationItem.independent(exercise));
      continue;
    }
    output.add(
      ExerciseFamilyPresentationItem.family(
        primaryExercise: base,
        family: family,
        visibleVariants: List.unmodifiable(variants),
      ),
    );
  }
  return List.unmodifiable(output);
}

List<Exercise> exercisesForFamily(
  ExerciseFamilyMetadata family,
  Iterable<Exercise> catalogue,
) {
  final byId = <String, Exercise>{
    for (final exercise in catalogue)
      if (exercise.stableId?.trim().isNotEmpty == true)
        exercise.stableId!.trim(): exercise,
  };
  final result = <Exercise>[];
  for (final member in family.members) {
    final exercise = byId[member.exerciseId];
    if (exercise != null) result.add(exercise);
  }
  return List.unmodifiable(result);
}
