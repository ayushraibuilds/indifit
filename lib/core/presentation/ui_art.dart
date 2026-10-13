/// UI art from Microsoft Fluent Emoji 3D (MIT; see assets/ui_icons/SOURCE.md).
/// 256 px PNGs, exact upstream bytes: sharp to about 85 pt, used at 24–28 pt.
abstract final class UiArt {
  static const String mealBreakfast = 'assets/ui_icons/meal_breakfast.png';
  static const String mealLunch = 'assets/ui_icons/meal_lunch.png';
  static const String mealDinner = 'assets/ui_icons/meal_dinner.png';
  static const String mealSnack = 'assets/ui_icons/meal_snack.png';
  static const String water = 'assets/ui_icons/water.png';

  static const List<String> all = [
    mealBreakfast,
    mealLunch,
    mealDinner,
    mealSnack,
    water,
  ];
}
