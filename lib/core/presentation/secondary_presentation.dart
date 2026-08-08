import '../nutrition_constraints.dart';
import '../nutrition_household_measures.dart';

/// Consumer-facing choices used by the settings and preference surfaces.
///
/// The domain keeps stable IDs and taxonomy values; widgets receive these
/// small view models instead of formatting domain objects themselves.
class DietaryChoicePresentation {
  final String id;
  final String label;
  final NutritionConstraintTargetType targetType;
  final String? description;

  const DietaryChoicePresentation({
    required this.id,
    required this.label,
    required this.targetType,
    this.description,
  });
}

abstract final class DietaryChoicesPresentation {
  static const common = <DietaryChoicePresentation>[
    DietaryChoicePresentation(
      id: 'peanut',
      label: 'Peanuts',
      targetType: NutritionConstraintTargetType.allergen,
    ),
    DietaryChoicePresentation(
      id: 'milk',
      label: 'Milk',
      targetType: NutritionConstraintTargetType.allergen,
    ),
    DietaryChoicePresentation(
      id: 'egg',
      label: 'Egg',
      targetType: NutritionConstraintTargetType.allergen,
    ),
    DietaryChoicePresentation(
      id: 'gluten',
      label: 'Gluten',
      targetType: NutritionConstraintTargetType.allergen,
    ),
    DietaryChoicePresentation(
      id: 'shellfish',
      label: 'Shellfish',
      targetType: NutritionConstraintTargetType.allergen,
    ),
    DietaryChoicePresentation(
      id: 'tree_nut',
      label: 'Tree nuts',
      targetType: NutritionConstraintTargetType.allergen,
    ),
    DietaryChoicePresentation(
      id: 'soy',
      label: 'Soy',
      targetType: NutritionConstraintTargetType.allergen,
    ),
    DietaryChoicePresentation(
      id: 'sesame',
      label: 'Sesame',
      targetType: NutritionConstraintTargetType.allergen,
    ),
    DietaryChoicePresentation(
      id: 'fish',
      label: 'Fish',
      targetType: NutritionConstraintTargetType.animalProduct,
    ),
    DietaryChoicePresentation(
      id: 'meat',
      label: 'Meat',
      targetType: NutritionConstraintTargetType.animalProduct,
    ),
    DietaryChoicePresentation(
      id: 'pork',
      label: 'Pork',
      targetType: NutritionConstraintTargetType.animalProduct,
    ),
    DietaryChoicePresentation(
      id: 'lactose',
      label: 'Lactose',
      targetType: NutritionConstraintTargetType.ingredient,
    ),
    DietaryChoicePresentation(
      id: 'onion',
      label: 'Onion',
      targetType: NutritionConstraintTargetType.ingredient,
    ),
    DietaryChoicePresentation(
      id: 'garlic',
      label: 'Garlic',
      targetType: NutritionConstraintTargetType.ingredient,
    ),
    DietaryChoicePresentation(
      id: 'alcohol',
      label: 'Alcohol',
      targetType: NutritionConstraintTargetType.additive,
    ),
  ];

  static DietaryChoicePresentation? find(String id) {
    final key = id.trim().toLowerCase().replaceAll('-', '_');
    for (final choice in common) {
      if (choice.id == key) return choice;
    }
    return null;
  }

  static List<DietaryChoicePresentation> search(String query) {
    final key = query.trim().toLowerCase();
    if (key.isEmpty) return common;
    return common
        .where((choice) => choice.label.toLowerCase().contains(key))
        .toList(growable: false);
  }
}

class NutritionConstraintPresentation {
  final String title;
  final String detail;
  final String handling;
  final String? note;
  final bool crossContact;
  final bool active;

  const NutritionConstraintPresentation({
    required this.title,
    required this.detail,
    required this.handling,
    required this.note,
    required this.crossContact,
    required this.active,
  });

  factory NutritionConstraintPresentation.fromDomain(
    NutritionUserConstraint constraint,
  ) {
    final choice = DietaryChoicesPresentation.find(constraint.target.id);
    final targetLabel = choice?.label ?? _safeLabel(constraint.target.id);
    final contextLabel = switch (constraint.type) {
      NutritionConstraintType.allergy => 'Allergy',
      NutritionConstraintType.intolerance => 'Intolerance',
      NutritionConstraintType.religiousRestriction => 'Religious or cultural',
      NutritionConstraintType.ethicalPreference => 'Lifestyle preference',
      NutritionConstraintType.dietaryPattern => 'Dietary pattern',
      NutritionConstraintType.tasteDislike => 'Taste preference',
      NutritionConstraintType.temporaryAvoidance => 'Temporary choice',
      NutritionConstraintType.regionalPreference => 'Regional preference',
    };
    return NutritionConstraintPresentation(
      title: targetLabel,
      detail: contextLabel,
      handling: switch (constraint.strictness) {
        NutritionConstraintStrictness.avoid => 'Avoid',
        NutritionConstraintStrictness.warn => 'Warn me',
        NutritionConstraintStrictness.informational => 'For information',
      },
      note: constraint.notes,
      crossContact: constraint.crossContact,
      active: constraint.isActive,
    );
  }

  static String _safeLabel(String value) {
    final raw = value.trim();
    final lower = raw.toLowerCase();
    final looksLikeInternalValue =
        raw.isEmpty ||
        raw.contains(':') ||
        RegExp(r'\d{4,}').hasMatch(raw) ||
        RegExp(
          r'^(?:[0-9a-f]{8}-[0-9a-f-]{27,}|[0-9a-f]{24,})$',
          caseSensitive: false,
        ).hasMatch(raw) ||
        lower.contains('source_id') ||
        lower.contains('evidence_id') ||
        lower.contains('goal_version') ||
        lower.contains('daily_totals_');
    if (looksLikeInternalValue) {
      return 'Selected food or ingredient';
    }
    final cleaned = raw.replaceAll(RegExp(r'[_-]+'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class HouseholdMeasurePresentation {
  final String label;
  final String status;
  final String? volume;
  final bool calibrated;

  const HouseholdMeasurePresentation({
    required this.label,
    required this.status,
    required this.volume,
    required this.calibrated,
  });

  factory HouseholdMeasurePresentation.fromDefinition(
    NutritionHouseholdMeasureDefinition definition,
  ) {
    final volume = definition.volume?.normalizedToMillilitres().point;
    final hasVolume = definition.hasReviewedVolume && volume != null;
    return HouseholdMeasurePresentation(
      label: definition.displayName,
      status: hasVolume ? 'Ready to use' : 'Not calibrated',
      volume: hasVolume ? '$volume mL' : null,
      calibrated: hasVolume,
    );
  }

  factory HouseholdMeasurePresentation.fromCalibration({
    required String label,
    required NutritionVesselCalibration? calibration,
  }) {
    final volume = calibration?.volume.normalizedToMillilitres().point;
    return HouseholdMeasurePresentation(
      label: label,
      status: volume == null ? 'Not calibrated' : 'Ready to use',
      volume: volume == null ? null : '$volume mL',
      calibrated: volume != null,
    );
  }
}

abstract final class SecondaryConsumerCopy {
  static String profileSex(String value) =>
      switch (value.trim().toLowerCase()) {
        'female' => 'Female',
        'male' => 'Male',
        _ => 'Prefer not to say',
      };

  static String goal(String value) => switch (value.trim().toLowerCase()) {
    'lose' => 'Lose weight',
    'gain' => 'Build muscle',
    _ => 'Maintain and feel strong',
  };

  static String activity(String value) => switch (value.trim().toLowerCase()) {
    'sedentary' => 'Mostly seated',
    'light' => 'Lightly active',
    'active' => 'Very active',
    _ => 'Moderately active',
  };

  static String equipment(String value) => switch (value.trim().toLowerCase()) {
    'dumbbells' => 'Dumbbells',
    'bodyweight' => 'Bodyweight',
    _ => 'Full gym',
  };

  static String playlistUnavailable() =>
      'Workout music is not available on this device yet.';
}
