import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';

void main() {
  late AppDatabase db;
  late FoodRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = FoodRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('FoodRepository searchFoodLocal Tests', () {
    test('searches food by name when nameHindi is null', () async {
      await repo.insertCustomFood(
        FoodItemsCompanion.insert(
          name: 'Chicken Breast',
          nameHindi: const Value(null),
          calories: 165,
          proteinG: 31.0,
          carbsG: 0.0,
          fatG: 3.6,
          servingSize: 100.0,
          servingUnit: 'g',
          category: 'Protein',
        ),
      );

      final results = await repo.searchFoodLocal('chicken');
      expect(results.length, 1);
      expect(results.first.name, 'Chicken Breast');
      expect(results.first.nameHindi, isNull);
    });

    test('searches food by hindi name when nameHindi is provided', () async {
      await repo.insertCustomFood(
        FoodItemsCompanion.insert(
          name: 'Palak Paneer',
          nameHindi: const Value('पालक पनीर'),
          calories: 240,
          proteinG: 12.0,
          carbsG: 8.0,
          fatG: 18.0,
          servingSize: 150.0,
          servingUnit: 'g',
          category: 'Curry',
        ),
      );

      final results = await repo.searchFoodLocal('पालक');
      expect(results.length, 1);
      expect(results.first.name, 'Palak Paneer');
    });

    test('returns empty list when query does not match', () async {
      final results = await repo.searchFoodLocal('nonexistentfooditem123');
      expect(results, isEmpty);
    });
  });
}
