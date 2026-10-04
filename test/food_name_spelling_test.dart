import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/services/food_name_spelling.dart';
import 'package:indifit/data/services/nutrition_food_search_ranking.dart';

void main() {
  test('variant spellings fold to the catalogue spelling', () {
    expect(foldFoodSpellings('aloo gobi sabzi'), 'aloo gobi sabji');
    expect(foldFoodSpellings('Subzi'), 'sabji');
    expect(foldFoodSpellings('mixed subjis'), 'mixed sabjis');
    expect(foldFoodSpellings('sabjee and sabzee'), 'sabji and sabji');
  });

  test('other words are left alone', () {
    expect(foldFoodSpellings('sabzimandi special'), 'sabzimandi special');
    expect(foldFoodSpellings('dal tadka'), 'dal tadka');
  });

  test('Food search also tries the catalogue spellings', () {
    expect(
      NutritionFoodSearchVocabulary.expand('lauki sabzi'),
      contains('lauki sabji'),
    );
    expect(
      NutritionFoodSearchVocabulary.expand('aloo gobi'),
      contains('aloo gobbi'),
    );
  });
}
