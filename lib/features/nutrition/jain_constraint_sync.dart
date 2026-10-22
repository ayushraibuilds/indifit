import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/di/core_providers.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/presentation/diet_preference_presentation.dart';
import '../../data/repositories/nutrition_constraint_repository.dart';
import 'nutrition_providers.dart';

/// Choosing the Jain pattern turns on the Jain dietary need, so meal checks
/// warn about onion, garlic and animal products (UX-16).
///
/// It happens once: the user can turn the need off, and it is never turned
/// back on. Switching away from Jain leaves the need alone.
class JainConstraintSync {
  JainConstraintSync({
    required NutritionConstraintRepository repository,
    required Future<SharedPreferences> Function() preferences,
    String userId = kLocalNutritionUserScopeId,
  }) : _repository = repository,
       _preferences = preferences,
       _userId = userId;

  final NutritionConstraintRepository _repository;
  final Future<SharedPreferences> Function() _preferences;
  final String _userId;

  static bool isJain(String? dietPreference) =>
      DietPreferencePresentation.uiValueFor(dietPreference) == 'jain';

  /// Call after [dietPreference] is saved (onboarding, Settings), and at
  /// start for people who chose Jain before this existed.
  Future<void> applyFor(String? dietPreference) async {
    if (!isJain(dietPreference)) return;
    final prefs = await _preferences();
    if (prefs.getBool(AppPreferenceKeys.prefJainConstraintApplied) ?? false) {
      return;
    }
    final existing = await _repository.listAllConstraints(userId: _userId);
    // Any Jain need, on or off, is the user's own: leave it.
    final hasJain = existing.any(
      (constraint) =>
          constraint.type == NutritionConstraintType.religiousRestriction &&
          constraint.target.type == NutritionConstraintTargetType.foodFamily &&
          constraint.target.id == 'jain',
    );
    if (!hasJain) {
      await _repository.createUserConstraint(
        userId: _userId,
        type: NutritionConstraintType.religiousRestriction,
        target: NutritionConstraintTarget(
          type: NutritionConstraintTargetType.foodFamily,
          id: 'jain',
        ),
      );
    }
    await prefs.setBool(AppPreferenceKeys.prefJainConstraintApplied, true);
  }

  /// The one-time start-up pass for existing Jain users.
  Future<void> migrateExistingUser() async {
    final prefs = await _preferences();
    await applyFor(prefs.getString(AppPreferenceKeys.userDietPreference));
  }
}

final jainConstraintSyncProvider = Provider<JainConstraintSync>(
  (ref) => JainConstraintSync(
    repository: ref.watch(nutritionConstraintRepositoryProvider),
    preferences: () async =>
        sharedPreferencesOrNull(() => ref.read(sharedPreferencesProvider)) ??
        await SharedPreferences.getInstance(),
  ),
);
