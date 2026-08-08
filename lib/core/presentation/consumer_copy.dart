/// Small, reviewed mappings from domain vocabulary to consumer language.
/// Unknown values intentionally collapse to a useful phrase rather than
/// leaking a new enum or reason-code string into the product.
abstract final class ConsumerCopy {
  static String state(String? value) {
    final key = _key(value);
    return switch (key) {
      'available' || 'ready' || 'known' || 'fits' => 'Available',
      'cautious' || 'uncertain' || 'range' => 'Use with care',
      'confirm' || 'proposal_available' => 'Ready to review',
      'accepted' => 'Accepted',
      'unchanged' => 'No change suggested',
      'unavailable' || 'missing' || 'invalid' || 'unknown' => 'Unavailable',
      'exceeds' => 'Above today’s target',
      'no_candidate' ||
      'no_candidate_after_filter' => 'Nothing to recommend yet',
      'dismissed' => 'Dismissed',
      _ => 'More information needed',
    };
  }

  static String action(String? value) {
    final key = _key(value);
    return switch (key) {
      'training' => 'Plan a workout',
      'nutrition_target' => 'Tune your daily target',
      'nutrition_meal' => 'Choose a meal',
      'education' => 'Learn something new',
      'reduce_calories' || 'reduce_energy' => 'Adjust your daily target',
      'increase_calories' || 'increase_energy' => 'Increase your daily target',
      'maintain_calories' || 'maintain_energy' => 'Keep your daily target',
      'log_meal' || 'log_food' => 'Log a meal',
      'rest' => 'Take a recovery day',
      _ => 'Your next step',
    };
  }

  static String nutrient(String? value) {
    final key = _key(value);
    return switch (key) {
      'energy' || 'calories' || 'kcal' => 'Calories',
      'protein' => 'Protein',
      'carbohydrate' || 'carbohydrates' || 'carbs' => 'Carbohydrates',
      'fat' => 'Fat',
      'fiber' || 'fibre' => 'Fibre',
      _ => 'Nutrition',
    };
  }

  static String targetType(String? value) {
    final key = _key(value);
    return switch (key) {
      'food' => 'Food',
      'food_family' => 'Food group',
      'ingredient' => 'Ingredient',
      'allergen' => 'Allergen',
      'animal_product' => 'Animal product',
      'preparation' => 'Preparation',
      'additive' => 'Additive',
      'region' => 'Region',
      'nutrient' => 'Nutrient',
      _ => 'Food or ingredient',
    };
  }

  static String strictness(String? value) {
    return switch (_key(value)) {
      'avoid' => 'Avoid',
      'warn' => 'Warn me',
      'informational' => 'For information',
      _ => 'Preference',
    };
  }

  static String target(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Food or ingredient';
    if (RegExp(
      r'^(?:[0-9a-f]{8}-[0-9a-f-]{27,}|[0-9a-f]{24,})$',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return 'Selected item';
    }
    if (_containsImplementationTerm(trimmed)) return 'Selected item';
    if (RegExp(r'[/:]|\d{4,}').hasMatch(trimmed)) return 'Selected item';
    final key = _key(trimmed);
    const labels = <String, String>{
      'vegan': 'Vegan',
      'vegetarian': 'Vegetarian',
      'eggetarian': 'Eggetarian',
      'jain': 'Jain',
      'halal': 'Halal',
      'milk': 'Milk',
      'egg': 'Egg',
      'peanut': 'Peanuts',
      'tree_nut': 'Tree nuts',
      'soy': 'Soy',
      'wheat': 'Wheat',
      'gluten': 'Gluten',
      'sesame': 'Sesame',
      'fish': 'Fish',
      'shellfish': 'Shellfish',
      'meat': 'Meat',
      'poultry': 'Poultry',
      'pork': 'Pork',
      'beef': 'Beef',
      'lactose': 'Lactose',
      'onion': 'Onion',
      'garlic': 'Garlic',
      'salt': 'Salt',
      'alcohol': 'Alcohol',
      'india': 'India',
      'bengali': 'Bengali',
      'gujarati': 'Gujarati',
      'maharashtrian': 'Maharashtrian',
      'punjabi': 'Punjabi',
      'south_indian': 'South Indian',
    };
    // Unknown target values are portable identities, not reviewed consumer
    // copy. Showing one can disclose an internal key, so collapse it instead
    // of attempting to turn it into a label.
    return labels[key] ?? 'Selected item';
  }

  /// Keeps an already consumer-facing display label intact while guarding
  /// against accidental engine metadata in a read model.
  static String label(String? value, {String fallback = 'Selected item'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || _containsImplementationTerm(trimmed)) {
      return fallback;
    }
    return trimmed;
  }

  static String explanation(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || _containsImplementationTerm(text)) {
      return 'I need a little more information before I can show this safely.';
    }
    return text;
  }

  static String missingInformation({String subject = 'this'}) =>
      'I don’t have enough information about $subject yet.';

  static String _key(String? value) => (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');

  static bool _containsImplementationTerm(String value) {
    final lower = value.toLowerCase();
    return lower.contains('uuid') ||
        lower.contains('source_id') ||
        lower.contains('evidence_id') ||
        lower.contains('evidence') ||
        lower.contains('goal_version') ||
        lower.contains('policy') ||
        lower.contains('version') ||
        lower.contains('daily_totals_missing') ||
        lower.contains('canonical') ||
        lower.contains('persisted') ||
        lower.contains('unresolved') ||
        lower.contains('reason_code') ||
        lower.contains('utc') ||
        lower.contains('candidate') ||
        lower.contains('inferred') ||
        lower.contains('inference') ||
        lower.contains('local meal opportunity') ||
        lower.contains('recorded') ||
        lower.contains('frozen') ||
        RegExp(
          r'\b[0-9a-f]{8}-[0-9a-f-]{27,}\b',
          caseSensitive: false,
        ).hasMatch(lower) ||
        RegExp(r'\b[0-9a-f]{24,}\b', caseSensitive: false).hasMatch(lower);
  }
}
