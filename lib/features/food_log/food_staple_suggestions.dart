/// Starter chips on an empty food search, keyed on meal × diet (UR-31).
///
/// Breakfast and snacks have their own staples; lunch and dinner keep the
/// everyday plate. Eggs and chicken only appear for diets that eat them.
/// On a marked vrat day (UF-9) every meal gets vrat foods, each one in the
/// catalogue.
List<String> foodStapleSuggestions({
  String? mealType,
  String? diet,
  bool vratDay = false,
}) {
  final normalizedDiet = (diet ?? 'veg').toLowerCase();
  final eatsMeat = const {
    'non-veg',
    'non_veg',
    'non-vegetarian',
  }.contains(normalizedDiet);
  final eatsEggs = eatsMeat || normalizedDiet == 'eggetarian';
  final vegan = normalizedDiet == 'vegan';
  if (vratDay) {
    return ['Sabudana', 'Makhana', 'Fruit', if (!vegan) 'Curd', 'Peanuts'];
  }
  switch (mealType) {
    case 'breakfast':
      return [
        'Poha',
        'Idli',
        'Paratha',
        'Upma',
        if (!vegan) 'Chai',
        if (eatsEggs) 'Eggs',
      ];
    case 'snack':
    case 'snacks':
    case 'evening_snack':
    case 'morning_snack':
      return [if (!vegan) 'Chai', 'Biscuit', 'Fruit', 'Namkeen', 'Chana'];
  }
  if (eatsMeat) {
    return const ['Roti', 'Dal', 'Rice', 'Chicken', 'Eggs', 'Paneer', 'Whey'];
  }
  if (vegan) {
    return const [
      'Roti',
      'Dal',
      'Rice',
      'Tofu',
      'Soya',
      'Chana',
      'Peanut Butter',
    ];
  }
  if (normalizedDiet == 'eggetarian') {
    return const ['Roti', 'Dal', 'Rice', 'Eggs', 'Paneer', 'Chai', 'Whey'];
  }
  return const ['Roti', 'Dal', 'Rice', 'Paneer', 'Curd', 'Chai', 'Whey'];
}
