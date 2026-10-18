import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/offline_starter_plan_catalog.dart';
import '../../data/repositories/plan_library_read_repository.dart';
import 'weekly_training_goal_providers.dart';

/// What "Recommended for you" ranks on (UR-45). Any field may be unknown.
class PlanRecommendationInputs {
  const PlanRecommendationInputs({
    this.goal,
    this.equipmentAccess,
    this.trainingDaysPerWeek,
  });

  /// Onboarding goal: 'lose', 'maintain' or 'gain'.
  final String? goal;

  /// Profile equipment: 'full_gym', 'dumbbells' or 'bodyweight'.
  final String? equipmentAccess;

  /// The days the user trains: their current plan's chosen days, else
  /// their weekly goal.
  final int? trainingDaysPerWeek;
}

/// The training days the recommendation uses: the active plan's chosen
/// days (step 9), else the user's weekly goal.
final planRecommendationTrainingDaysProvider = FutureProvider.autoDispose
    .family<int?, String?>((ref, activeProgramVersionId) async {
      if (activeProgramVersionId != null) {
        final shape = await ref
            .watch(planScheduleReaderProvider)
            .read(activeProgramVersionId);
        if (shape != null) return shape.sessionsPerWeek;
      }
      return ref.watch(weeklyTrainingGoalRepositoryProvider).userGoal();
    });

/// Ranks starter plans for "Recommended for you". Equipment the user lacks
/// rules a plan out; then the plan's purpose against the goal, its days
/// against the user's training days and the profile's exact equipment
/// match add up. Ties keep catalogue order. Never the active plan.
List<PlanLibraryEntry> rankRecommendedPlans(
  Iterable<PlanLibraryEntry> entries,
  PlanRecommendationInputs inputs,
) {
  final equipment = inputs.equipmentAccess?.trim().toLowerCase();
  final scored = <(PlanLibraryEntry, int, int)>[];
  var order = 0;
  for (final entry in entries) {
    final starter = entry.starterPlan;
    if (entry.isActive || starter == null) continue;
    if (!_fitsEquipment(starter, equipment)) continue;
    scored.add((entry, _score(starter, inputs, equipment), order++));
  }
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    return byScore == 0 ? a.$3.compareTo(b.$3) : byScore;
  });
  return [for (final item in scored) item.$1];
}

bool _fitsEquipment(OfflineStarterPlan plan, String? equipment) {
  return switch (equipment) {
    'bodyweight' =>
      plan.environment == StarterPlanEnvironment.home &&
          plan.equipment.toLowerCase().contains('no equipment'),
    'dumbbells' => plan.environment != StarterPlanEnvironment.gym,
    _ => true,
  };
}

int _score(
  OfflineStarterPlan plan,
  PlanRecommendationInputs inputs,
  String? equipment,
) {
  var score = 0;
  final purpose = plan.purpose.toLowerCase();
  switch (inputs.goal) {
    case 'gain':
      if (purpose.contains('muscle')) score += 2;
    case 'lose' || 'maintain':
      if (purpose.contains('general fitness')) score += 2;
  }
  final days = inputs.trainingDaysPerWeek;
  if (days != null) {
    final difference = (plan.daysPerWeek - days).abs();
    if (difference == 0) {
      score += 2;
    } else if (difference == 1) {
      score += 1;
    }
  }
  final exactEquipment = switch (equipment) {
    'full_gym' || 'gym' => plan.environment == StarterPlanEnvironment.gym,
    'dumbbells' => plan.equipment.toLowerCase().startsWith('dumbbells'),
    'bodyweight' => true,
    _ => false,
  };
  if (exactEquipment) score += 1;
  return score;
}
