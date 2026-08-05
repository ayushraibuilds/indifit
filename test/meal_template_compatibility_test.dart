import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy meal templates remain separate from the recipe authority',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final templateId = await db
          .into(db.mealTemplates)
          .insert(
            MealTemplatesCompanion.insert(
              name: 'Legacy macro template',
              defaultMealType: const Value('lunch'),
            ),
          );
      await db
          .into(db.mealTemplateItems)
          .insert(
            MealTemplateItemsCompanion.insert(
              templateId: templateId,
              name: 'Copied display food',
              calories: 300,
              proteinG: 10,
              carbsG: 40,
              fatG: 8,
              servingLogged: 1,
              servingUnit: 'serving',
            ),
          );

      final repository = NutritionRecipeRepository(db: db);
      await repository.createRecipe(
        userId: 'template-user',
        recipeId: 'separate-recipe',
        versionId: 'separate-draft',
        name: 'Separate direct-food recipe',
      );

      expect(await db.select(db.mealTemplates).get(), hasLength(1));
      expect(await db.select(db.mealTemplateItems).get(), hasLength(1));
      expect((await db.select(db.mealTemplates).get()).single.id, templateId);
      expect(await db.select(db.nutritionRecipes).get(), hasLength(1));
      expect(
        (await db.select(db.nutritionRecipes).get()).single.id,
        'separate-recipe',
      );
    },
  );
}
