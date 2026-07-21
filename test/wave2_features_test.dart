import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FoodRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = FoodRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Wave 2 FoodRepository Regional Pack Tests', () {
    test('isRegionalPackLoaded returns false for empty or non-existent pack', () async {
      final loaded = await repo.isRegionalPackLoaded('punjabi');
      expect(loaded, isFalse);
    });

    test('removeRegionalPack removes tagged items successfully', () async {
      // Setup: insert some dummy food items tagged with regional pack
      await db.into(db.foodItems).insert(
        FoodItemsCompanion.insert(
          name: 'Dummy Sarson Saag',
          calories: 120,
          proteinG: 3.0,
          carbsG: 10.0,
          fatG: 7.0,
          servingSize: 1.0,
          servingUnit: 'katori',
          category: 'veg',
          regionPack: const Value('punjabi'),
        ),
      );

      var loaded = await repo.isRegionalPackLoaded('punjabi');
      expect(loaded, isTrue);

      await repo.removeRegionalPack('punjabi');

      loaded = await repo.isRegionalPackLoaded('punjabi');
      expect(loaded, isFalse);
    });
  });
}
