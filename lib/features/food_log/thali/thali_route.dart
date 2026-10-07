/// The thali builder's location for a meal and day.
///
/// The food screen opens the thali for the meal and date it is logging.
/// It used to push a bare `/food/thali`, so a dinner logged for yesterday
/// landed in today's Lunch (audit C-02).
String thaliRouteLocation({String? mealType, DateTime? date}) {
  final meal = mealType?.trim();
  final query = {
    if (meal != null && meal.isNotEmpty) 'meal': meal,
    if (date != null) 'date': _localDate(date),
  };
  return Uri(
    path: '/food/thali',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

String _localDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
