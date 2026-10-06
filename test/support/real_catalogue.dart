import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_household_measure_repository.dart';
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/data/repositories/nutrition_thali_repository.dart';

/// A database seeded exactly like a fresh install (bundled foods, identity
/// manifest and the bundled catalogue pack), with every nutrition
/// repository wired to it (audit A-02).
///
/// Tests that log food against real catalogue rows belong here, not on
/// synthetic fixture foods: 2,653 synthetic tests once passed while every
/// real thali logged 0 kcal. Call `TestWidgetsFlutterBinding
/// .ensureInitialized()` first so the seeders can read assets.
class RealCatalogue {
  final AppDatabase db;
  final NutrientRegistry registry;
  final NutritionFoodCatalogRepository catalog;
  final NutritionRecipeRepository recipes;
  final NutritionConsumptionRepository consumption;
  final NutritionRecipeLogCoordinator recipeLogging;
  final NutritionThaliRepository thali;

  RealCatalogue._({
    required this.db,
    required this.registry,
    required this.catalog,
    required this.recipes,
    required this.consumption,
    required this.recipeLogging,
    required this.thali,
  });

  static Future<RealCatalogue> open() async {
    final db = AppDatabase.memory();
    // The first query opens the database: onCreate seeds the catalogue and
    // beforeOpen applies the bundled pack.
    await db.customSelect('SELECT 1').get();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final recipes = NutritionRecipeRepository(db: db);
    final consumption = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    final recipeLogging = NutritionRecipeLogCoordinator(
      db: db,
      recipes: recipes,
      calculator: const NutritionCalculationService(),
      consumption: consumption,
      registry: registry,
    );
    return RealCatalogue._(
      db: db,
      registry: registry,
      catalog: NutritionFoodCatalogRepository(db: db, registry: registry),
      recipes: recipes,
      consumption: consumption,
      recipeLogging: recipeLogging,
      thali: NutritionThaliRepository(
        db: db,
        registry: registry,
        recipes: recipes,
        recipeLogging: recipeLogging,
        measures: NutritionHouseholdMeasureRepository(db: db),
        constraints: NutritionConstraintRepository(database: db),
        consumption: consumption,
      ),
    );
  }

  /// The stable id of the bundled food named [name] (exact display name).
  Future<String> foodId(String name) async {
    final row = await (db.select(
      db.nutritionFoods,
    )..where((food) => food.displayName.equals(name))).getSingle();
    return row.id;
  }

  Future<void> close() => db.close();
}
