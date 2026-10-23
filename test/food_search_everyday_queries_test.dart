import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/services/food_query_amount.dart';
import 'package:indifit/data/services/food_search_pipeline.dart';
import 'package:indifit/data/services/nutrition_food_search_ranking.dart';

import 'support/indifit_test_harness.dart';
import 'support/real_catalogue.dart';

/// Everyday searches against the shipped catalogue, through the same
/// pipeline the food screen uses (§ 3.5 of the 17 Oct user-readiness
/// review). Each query names text its first result must contain. Every pack
/// or ranking change shows its effect here.
///
/// Dishes the catalogue doesn't have (ragi mudde, lime pickle, protein bar)
/// are left out: there is no right first result to pin until a pack adds
/// them. Pack 5 added the rest of § 3.4.
const Map<String, String> everydayFirstResult = {
  // Breakfast
  'aloo paratha': 'Aloo Paratha',
  'paneer paratha': 'Paneer Paratha',
  'gobi paratha': 'Gobi Paratha',
  'methi thepla': 'Thepla',
  'moong dal chilla': 'Moong Dal Chilka',
  'bread omelette': 'Bread Omelette',
  '2 boiled eggs': 'Boiled Eggs',
  'masala oats': 'Masala Oats',
  'cornflakes': 'Cornflakes',
  'muesli': 'Muesli',
  'idli sambar': 'Idli with Sambar',
  'rava upma': 'Upma',
  'sprouts salad': 'Sprouted',
  'chai with sugar': 'Masala Chai',
  // "chai" is an alias of Tea with Milk and Sugar; Masala Chai follows.
  '1 cup chai': 'Tea with Milk and Sugar',
  'black coffee': 'Black Coffee',
  'bournvita milk': 'Malted Milk',
  '1 glass milk': 'Milk',
  '200 ml milk': 'Milk',
  // Lunch and dinner
  'rajma chawal': 'Rajma Chawal',
  'dal chawal': 'Dal Chawal',
  'veg pulao': 'Vegetable Pulao',
  'jeera aloo': 'Jeera Aloo',
  'aloo matar': 'Mattar',
  'lauki sabzi': 'Lauki Ki Sabji',
  'tinda': 'Tinda',
  'karela': 'Karela',
  'palak dal': 'Palak',
  'dal fry': 'Dal Fry',
  'dal makhni': 'Dal Makhani',
  'aloo ki sabji': 'Aloo',
  'bhindi fry': 'Bhindi',
  'kadai paneer': 'Kadai Paneer',
  'malai kofta': 'Malai Kofta',
  'dum aloo': 'Dum Aloo',
  'paneer tikka': 'Paneer Tikka',
  'paneer bhurji': 'Paneer Bhurji',
  'egg bhurji': 'Egg Bhurji',
  'anda curry': 'Egg Curry',
  'grilled chicken': 'Chicken Breast',
  'fish fry': 'Fish Fry',
  'mutton biryani': 'Mutton Biryani',
  'half plate biryani': 'Biryani',
  'veg hakka noodles': 'Veg Hakka Noodles',
  'rumali roti': 'Rumali Roti',
  'missi roti': 'Missi Roti',
  'bajra roti': 'Bajra Roti',
  'jowar bhakri': 'Jowar Roti',
  'ragi mudde': 'Ragi',
  'lemon rice': 'Lemon Rice',
  'bisi bele bath': 'Bisi Bele Bath',
  'avial': 'Avial',
  'cabbage thoran': 'Cabbage Thoran',
  'moong dal khichdi': 'Khichdi',
  'cucumber raita': 'Raita',
  'green salad': 'Kachumber',
  // Amounts typed with the food (UR-01)
  '2 roti': 'Roti',
  '3 roti': 'Roti',
  '4 eggs': 'Egg',
  '2 idli': 'Idli',
  '1 katori dal': 'Dal',
  'dal 2 katori': 'Dal',
  'chawal 1 plate': 'Rice',
  '100g paneer': 'Paneer',
  // Typos and Hinglish
  'chapatti': 'Roti',
  'parantha': 'Paratha',
  'panner': 'Paneer',
  'biriyani': 'Biryani',
  'sabji': 'Sabji',
  'chiken curry': 'Chicken Curry',
  'idly': 'Idli',
  'dosai': 'Dosa',
  'samber': 'Sambar',
  // Snacks and drinks
  'roasted chana': 'Roasted Chana',
  'peanuts': 'Peanuts',
  'banana chips': 'Banana Chips',
  'namkeen': 'Namkeen',
  'marie biscuit': 'Marie',
  'rusk': 'Rusk',
  'cold coffee': 'Cold Coffee',
  'sugarcane juice': 'Sugarcane Juice',
  'orange juice': 'Orange Juice',
  'guava': 'Guava',
  'chikoo': 'Chikoo',
  'anar': 'Pomegranate',
  'grapes': 'Grapes',
  // Sweets
  'rasmalai': 'Rasmalai',
  'kaju katli': 'Kaju Katli',
  'gajar halwa': 'Gajar Halwa',
  'ice cream': 'Ice Cream',
  'dark chocolate': 'Dark Chocolate',
  'shrikhand': 'Shrikhand',
  'mysore pak': 'Mysore Pak',
  'peda': 'Peda',
  // Eating out
  'pizza': 'Pizza',
  'burger': 'Burger',
  'veg sandwich': 'Veg Sandwich',
  'french fries': 'French Fries',
  'chicken shawarma': 'Shawarma',
  'kathi roll': 'Frankie',
  'masala maggi': 'Masala Noodles',
  // One word dropped when the whole search matches nothing (UR-03)
  'fried momos': 'Momos',
  'cheese dosa': 'Dosa',
  'prawn curry': 'Prawns',
  // Pack 5: the § 3.4 gap dishes, as people type them
  'besan chilla': 'Besan Chilla',
  'chilla': 'Chilla',
  'puri bhaji': 'Puri Bhaji',
  'poori bhaji': 'Puri Bhaji',
  'chole bhature': 'Chole Bhature',
  'sabudana vada': 'Sabudana Vada',
  'banana shake': 'Banana Shake',
  'mango shake': 'Mango Shake',
  'kadhi chawal': 'Kadhi Chawal',
  'egg fried rice': 'Egg Fried Rice',
  'chilli paneer': 'Chilli Paneer',
  'chili paneer': 'Chilli Paneer',
  'veg manchurian': 'Veg Manchurian',
  'manchurian': 'Manchurian',
  'chicken manchurian': 'Chicken Manchurian',
  'chilli chicken': 'Chilli Chicken',
  'schezwan fried rice': 'Schezwan Fried Rice',
  'szechuan rice': 'Schezwan Fried Rice',
  'puliyogare': 'Puliyogare',
  'tamarind rice': 'Puliyogare',
  'dalia': 'Dalia',
  'tomato soup': 'Tomato Soup',
  'sweet corn soup': 'Sweet Corn Soup',
  'papad': 'Papad',
  'achar': 'Pickle',
  'mango pickle': 'Mango Pickle',
  'khakhra': 'Khakhra',
  'chakli': 'Chakli',
  'murukku': 'Chakli',
  'mathri': 'Mathri',
  'dahi bhalla': 'Dahi Bhalla',
  'dahi vada': 'Dahi Bhalla',
  'coconut chutney': 'Coconut Chutney',
  'green chutney': 'Green Chutney',
  'onion salad': 'Onion Salad',
  'modak': 'Modak',
  'soan papdi': 'Soan Papdi',
  'puran poli': 'Puran Poli',
};

void main() {
  initializeIndiFitTestHarness();

  late RealCatalogue catalogue;
  late FoodSearchPipeline pipeline;

  setUpAll(() async {
    catalogue = await RealCatalogue.open();
    pipeline = FoodSearchPipeline(
      FoodRepository(catalogue.db),
      optionFor: catalogue.catalog.getOption,
    );
  });

  tearDownAll(() => catalogue.close());

  Future<List<String>> names(String query) async {
    final (_, ranked) = await pipeline.search(query);
    return [for (final result in ranked) result.candidate.displayName];
  }

  group('first result', () {
    for (final MapEntry(key: query, value: expected)
        in everydayFirstResult.entries) {
      test('"$query" leads with $expected', () async {
        final results = await names(query);
        expect(results, isNotEmpty);
        expect(results.first, contains(expected));
      });
    }
  });

  group('milk is a milk (UR-04)', () {
    for (final query in ['milk', '1 glass milk', '200 ml milk']) {
      test('"$query"', () async {
        final first = (await names(query)).first;
        expect(first, contains('Milk'));
        expect(
          NutritionFoodSearchVocabulary.isDessert(displayName: first),
          isFalse,
          reason: first,
        );
      });
    }

    test('a sweet search still finds the sweet', () async {
      expect((await names('milk barfi')).first, 'Milk Barfi');
    });
  });

  group('amounts typed with the food (UR-01, UR-02)', () {
    test('a bare number before a food is an amount', () async {
      final resolved = await pipeline.resolve('3 roti');
      expect(resolved.query, 'roti');
      expect(resolved.amount?.amount, 3);
      expect(resolved.amount?.unit, isNull);
    });

    test('a number that is part of a name stays', () async {
      for (final query in ['7 up', '5 star']) {
        final resolved = await pipeline.resolve(query);
        expect(resolved.query, query);
        expect(resolved.amount, isNull);
      }
    });

    test('units before and after the food, and grams and millilitres', () {
      ParsedFoodQuery parse(String query) => FoodQueryParser.parse(query);
      expect(parse('chawal 1 plate').food, 'chawal');
      expect(parse('chawal 1 plate').amount?.unit, 'plate');
      expect(parse('dal 2 katori').amount?.amount, 2);
      expect(parse('100g paneer').food, 'paneer');
      expect(parse('100g paneer').amount?.unit, 'g');
      expect(parse('200 ml milk').amount?.unit, 'ml');
      expect(parse('1 glass milk').amount?.unit, 'glass');
      expect(parse('half plate biryani').amount?.amount, 0.5);
      expect(parse('1/2 katori curd').amount?.amount, 0.5);
      expect(parse('2 cups').food, '2 cups');
      expect(parse('1 lassi').food, 'lassi');
      expect(parse('1 lassi').bareNumber, isTrue);
      expect(parse('chicken 65').amount, isNull);
    });

    test('the amount becomes a quantity of the food', () async {
      Future<String?> amountFor(String typed, String food) async {
        final option = (await catalogue.catalog.getOption(
          await catalogue.foodId(food),
        ))!;
        final quantity = (await pipeline.resolve(
          typed,
        )).amount?.quantityFor(option);
        return quantity == null
            ? null
            : option.measure?.pickedAmountLabel(quantity);
      }

      expect(
        await amountFor('3 roti', 'Whole Wheat Roti / Chapati'),
        '3 pieces',
      );
      expect(await amountFor('4 eggs', 'Boiled Eggs (2 pieces)'), '4 pieces');
      expect(
        await amountFor('1 katori dal', 'Toor Dal / Yellow Dal Tadka'),
        '1 katori (150 g)',
      );
      expect(
        await amountFor('300g dal', 'Toor Dal / Yellow Dal Tadka'),
        '2 katori (300 g)',
      );
      // A plate of something counted in pieces doesn't fit: no pre-fill.
      expect(
        await amountFor('roti 1 plate', 'Whole Wheat Roti / Chapati'),
        isNull,
      );
    });

    test('the "+" button names the typed amount', () {
      expect(const FoodQueryAmount(3).label(servingUnit: 'piece'), '3 pieces');
      expect(const FoodQueryAmount(1, 'plate').label(), '1 plate');
      expect(const FoodQueryAmount(200, 'ml').label(), '200 ml');
      expect(const FoodQueryAmount(2).label(servingUnit: 'g'), '2 servings');
    });
  });

  group('one word dropped when nothing matches (UR-03)', () {
    test('says it relaxed the search', () async {
      final resolved = await pipeline.resolve('cheese dosa');
      expect(resolved.relaxed, isTrue);
      expect(resolved.query, 'dosa');
    });

    test('a search that matches as typed is left alone', () async {
      final resolved = await pipeline.resolve('dal fry');
      expect(resolved.relaxed, isFalse);
      expect(resolved.query, 'dal fry');
    });
  });

  group('the dish word is kept when a word is dropped (R-9)', () {
    Future<(bool, String?)> first(String query) async {
      final (resolved, ranked) = await pipeline.search(query);
      return (
        resolved.relaxed,
        ranked.isEmpty ? null : ranked.first.candidate.displayName,
      );
    }

    test('a describing word in front is dropped', () async {
      expect((await first('cheese dosa')).$2, contains('Dosa'));
      expect((await first('fried momos')).$2, contains('Momos'));
      expect((await first('egg fried rice')).$2, contains('Fried Rice'));
      expect((await first('cheese dosa')).$1, isTrue);
    });

    test('dropping the dish word shows nothing, not another food', () async {
      for (final query in ['protein bar', 'paneer wrap']) {
        final (relaxed, name) = await first(query);
        expect(relaxed, isFalse, reason: query);
        expect(name, isNot(contains('Whey Protein')), reason: query);
        expect(name, isNot(contains('Raw')), reason: query);
      }
    });

    test('the number rule runs after the amount is split off', () async {
      for (final (query, name) in [
        ('paneer 100g', 'Paneer'),
        ('roti 2', 'Roti'),
        ('2 boiled eggs', 'Boiled Eggs'),
        ('parle g', 'Glucose Biscuits'),
      ]) {
        final (_, top) = await first(query);
        expect(top, contains(name), reason: query);
      }
      expect((await pipeline.resolve('roti 2')).amount?.amount, 2);
      expect((await pipeline.resolve('paneer 100g')).query, 'paneer');
      // Product names the catalogue doesn't carry find nothing on the phone
      // (online search may), never Upma or a stir fry.
      for (final query in ['7 up', '5 star']) {
        final (relaxed, top) = await first(query);
        expect(top, isNull, reason: query);
        expect(relaxed, isFalse, reason: query);
        expect((await pipeline.resolve(query)).query, query);
      }
      expect(FoodQueryParser.parse('chicken 65').amount, isNull);
    });

    test('a number in the name has to match', () async {
      final (relaxed, name) = await first('chicken 65');
      expect(relaxed, isFalse);
      expect(name, isNot(contains('Chicken Tikka')));
      expect(await pipeline.dropOneWord('chicken 65'), isNull);
    });
  });
}
