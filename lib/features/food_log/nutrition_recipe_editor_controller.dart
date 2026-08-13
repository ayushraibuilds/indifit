import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/raw_cooked_transformations.dart';
import '../../core/typed_quantities.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../../data/repositories/nutrition_recipe_repository.dart';
import '../../data/repositories/nutrition_transformation_repository.dart';

enum NutritionRecipeEditorStatus {
  idle,
  loading,
  ready,
  saving,
  publishing,
  success,
  failure,
}

class NutritionRecipeEditorState {
  final NutritionRecipeEditorStatus status;
  final NutritionRecipeDraftModel? draft;
  final NutritionRecipeModel? recipe;
  final String name;
  final String description;
  final String servingCountText;
  final String? servingDefinitionId;
  final String? servingDefinitionRevision;
  final String? servingDefinitionSource;
  final List<NutritionFoodOption> foods;
  final List<NutritionRecipeIngredientInput> ingredients;
  final String query;
  final String? errorCode;
  final String? errorMessage;
  final bool published;

  const NutritionRecipeEditorState({
    this.status = NutritionRecipeEditorStatus.idle,
    this.draft,
    this.recipe,
    this.name = '',
    this.description = '',
    this.servingCountText = '1',
    this.servingDefinitionId,
    this.servingDefinitionRevision,
    this.servingDefinitionSource,
    this.foods = const [],
    this.ingredients = const [],
    this.query = '',
    this.errorCode,
    this.errorMessage,
    this.published = false,
  });

  NutritionRecipeEditorState copyWith({
    NutritionRecipeEditorStatus? status,
    Object? draft = _unset,
    Object? recipe = _unset,
    String? name,
    String? description,
    String? servingCountText,
    Object? servingDefinitionId = _unset,
    Object? servingDefinitionRevision = _unset,
    Object? servingDefinitionSource = _unset,
    List<NutritionFoodOption>? foods,
    List<NutritionRecipeIngredientInput>? ingredients,
    String? query,
    Object? errorCode = _unset,
    Object? errorMessage = _unset,
    bool? published,
  }) => NutritionRecipeEditorState(
    status: status ?? this.status,
    draft: draft == _unset ? this.draft : draft as NutritionRecipeDraftModel?,
    recipe: recipe == _unset ? this.recipe : recipe as NutritionRecipeModel?,
    name: name ?? this.name,
    description: description ?? this.description,
    servingCountText: servingCountText ?? this.servingCountText,
    servingDefinitionId: servingDefinitionId == _unset
        ? this.servingDefinitionId
        : servingDefinitionId as String?,
    servingDefinitionRevision: servingDefinitionRevision == _unset
        ? this.servingDefinitionRevision
        : servingDefinitionRevision as String?,
    servingDefinitionSource: servingDefinitionSource == _unset
        ? this.servingDefinitionSource
        : servingDefinitionSource as String?,
    foods: foods ?? this.foods,
    ingredients: ingredients ?? this.ingredients,
    query: query ?? this.query,
    errorCode: errorCode == _unset ? this.errorCode : errorCode as String?,
    errorMessage: errorMessage == _unset
        ? this.errorMessage
        : errorMessage as String?,
    published: published ?? this.published,
  );
}

const _unset = Object();

/// Controller boundary for the production direct-food recipe editor.
///
/// The controller owns only draft form state. Durable recipe versions are
/// still created, replaced, published, duplicated, and successor-versioned by
/// [NutritionRecipeRepository].
class NutritionRecipeEditorController
    extends StateNotifier<NutritionRecipeEditorState> {
  final NutritionRecipeRepository _recipes;
  final Future<NutritionFoodCatalogRepository> _foodsFuture;
  final NutritionTransformationRepository _transformations;
  final String userId;
  final Uuid _uuid;
  final String? recipeId;
  final String? draftVersionId;

  NutritionRecipeEditorController({
    required NutritionRecipeRepository recipes,
    required Future<NutritionFoodCatalogRepository> foods,
    required NutritionTransformationRepository transformations,
    required this.userId,
    this.recipeId,
    this.draftVersionId,
    Uuid? uuid,
  }) : _recipes = recipes,
       _foodsFuture = foods,
       _transformations = transformations,
       _uuid = uuid ?? const Uuid(),
       super(const NutritionRecipeEditorState());

  NutritionRecipeEditorState get currentState => state;

  Future<void> load() async {
    state = state.copyWith(
      status: NutritionRecipeEditorStatus.loading,
      errorCode: null,
      errorMessage: null,
    );
    try {
      NutritionRecipeDraftModel? draft;
      NutritionRecipeModel? recipe;
      var name = state.name;
      var description = state.description;
      var servingCountText = state.servingCountText;
      String? servingDefinitionId = state.servingDefinitionId;
      String? servingDefinitionRevision = state.servingDefinitionRevision;
      String? servingDefinitionSource = state.servingDefinitionSource;
      var ingredients = <NutritionRecipeIngredientInput>[];
      var published = false;
      if (draftVersionId != null) {
        draft = await _recipes.getDraft(draftVersionId!);
      }
      if (recipeId != null) {
        recipe = await _recipes.getRecipe(recipeId!);
        if (recipe == null) {
          throw const NutritionRecipeValidationError(
            'recipe_not_found',
            'The selected recipe is unavailable.',
          );
        }
        name = recipe.name;
        description = recipe.description ?? '';
        if (draft == null && recipe.currentVersionId != null) {
          final version = await _recipes.getVersion(recipe.currentVersionId!);
          if (version != null) {
            published =
                version.status == NutritionRecipeVersionStatus.published;
            ingredients = _toInputs(version.ingredients);
            servingCountText =
                version.servingDefinition?.count.toString() ?? '1';
            servingDefinitionId = version.servingDefinition?.id;
            servingDefinitionRevision = version.servingDefinition?.revision;
            servingDefinitionSource = version.servingDefinition?.source;
          }
        }
      }
      if (draft != null) {
        recipe = draft.recipe;
        name = recipe.name;
        description = recipe.description ?? '';
        ingredients = _toInputs(draft.version.ingredients);
        servingCountText =
            draft.version.servingDefinition?.count.toString() ?? '1';
        servingDefinitionId = draft.version.servingDefinition?.id;
        servingDefinitionRevision = draft.version.servingDefinition?.revision;
        servingDefinitionSource = draft.version.servingDefinition?.source;
      }
      servingDefinitionId ??= 'recipe-serving::${_uuid.v4()}';
      servingDefinitionRevision ??= 'b03-editor-v1';
      final foods = await (await _foodsFuture).search();
      state = state.copyWith(
        status: NutritionRecipeEditorStatus.ready,
        draft: draft,
        recipe: recipe,
        name: name,
        description: description,
        servingCountText: servingCountText,
        servingDefinitionId: servingDefinitionId,
        servingDefinitionRevision: servingDefinitionRevision,
        servingDefinitionSource: servingDefinitionSource,
        ingredients: ingredients,
        foods: foods,
        published: published,
        errorCode: null,
        errorMessage: null,
      );
    } catch (error) {
      _fail(error, fallbackCode: 'recipe_editor_load_failed');
    }
  }

  Future<void> searchFoods(String query) async {
    try {
      final foods = await (await _foodsFuture).search(query: query);
      state = state.copyWith(foods: foods, query: query);
    } catch (error) {
      _fail(error, fallbackCode: 'food_catalogue_unavailable');
    }
  }

  void setName(String value) => state = state.copyWith(name: value);

  void setDescription(String value) =>
      state = state.copyWith(description: value);

  void setServingCount(String value) =>
      state = state.copyWith(servingCountText: value);

  Future<List<NutritionTransformation>> transformationsFor(
    NutritionFoodOption option,
  ) => option.preparationId == null
      ? _transformations.findForFood(sourceFoodId: option.id)
      : _transformations.findForSource(
          sourceFoodId: option.id,
          sourcePreparationId: option.preparationId,
        );

  Future<NutritionFoodOption?> transformedFood(
    NutritionFoodOption option,
    Quantity quantity,
    NutritionTransformation? transformation,
  ) async {
    if (transformation == null) return option;
    final result = NutritionTransformationService.apply(
      transformation: transformation,
      sourceFoodId: option.id,
      sourcePreparationId:
          option.preparationId ?? transformation.sourcePreparationId,
      input: quantity,
      direction: transformation.direction,
    );
    if (result is! NutritionTransformationApplied || result.point == null) {
      return null;
    }
    return (await _foodsFuture).getOption(transformation.targetFoodId);
  }

  void addIngredient({
    required NutritionFoodOption food,
    required Quantity quantity,
    NutritionTransformation? transformation,
    NutritionFoodOption? transformedOption,
  }) {
    final selectedFood = transformedOption ?? food;
    NutritionTransformationApplied? applied;
    if (transformation != null) {
      final result = NutritionTransformationService.apply(
        transformation: transformation,
        sourceFoodId: food.id,
        sourcePreparationId:
            food.preparationId ?? transformation.sourcePreparationId,
        input: quantity,
        direction: transformation.direction,
      );
      if (result is! NutritionTransformationApplied || result.point == null) {
        throw const NutritionRecipeValidationError(
          'range_only_transformation',
          'A range-only conversion cannot be published as an exact recipe quantity. Log it directly to preserve the range.',
        );
      }
      applied = result;
    }
    final selectedQuantity = applied?.point ?? quantity;
    final note = transformation == null
        ? null
        : 'transformation:${transformation.id}:${transformation.ruleVersion}';
    final next = [
      ...state.ingredients,
      NutritionRecipeIngredientInput.directFood(
        id: 'ingredient::${_uuid.v4()}',
        foodId: selectedFood.id,
        quantity: selectedQuantity,
        position: state.ingredients.length,
        preparationId: transformation?.targetPreparationId,
        notes: note,
        provenanceSource:
            transformation?.source.stableId ?? selectedFood.sourceType,
      ),
    ];
    state = state.copyWith(ingredients: next);
  }

  void updateIngredientQuantity(int index, Quantity quantity) {
    if (index < 0 || index >= state.ingredients.length) return;
    final current = state.ingredients[index];
    final next = [...state.ingredients];
    next[index] = NutritionRecipeIngredientInput.directFood(
      id: current.id,
      foodId: current.foodId!,
      quantity: quantity,
      position: index,
      preparationId: current.preparationId,
      measureId: current.measureId,
      lower: current.lower,
      upper: current.upper,
      notes: current.notes,
      substitutedFromFoodId: current.substitutedFromFoodId,
      provenanceSource: current.provenanceSource,
    );
    state = state.copyWith(ingredients: next);
  }

  void removeIngredient(int index) {
    if (index < 0 || index >= state.ingredients.length) return;
    final next = [
      for (var i = 0; i < state.ingredients.length; i++)
        if (i != index)
          NutritionRecipeIngredientInput.directFood(
            id: state.ingredients[i].id,
            foodId: state.ingredients[i].foodId!,
            quantity: state.ingredients[i].quantity,
            position: i,
            preparationId: state.ingredients[i].preparationId,
            measureId: state.ingredients[i].measureId,
            lower: state.ingredients[i].lower,
            upper: state.ingredients[i].upper,
            notes: state.ingredients[i].notes,
            substitutedFromFoodId: state.ingredients[i].substitutedFromFoodId,
            provenanceSource: state.ingredients[i].provenanceSource,
          ),
    ];
    state = state.copyWith(ingredients: next);
  }

  Future<void> saveDraft() async {
    state = state.copyWith(
      status: NutritionRecipeEditorStatus.saving,
      errorCode: null,
      errorMessage: null,
    );
    try {
      if (state.name.trim().isEmpty) {
        throw const NutritionRecipeValidationError(
          'missing_recipe_name',
          'Give the recipe a name before saving.',
        );
      }
      final servingCount = QuantityAmount.fromString(
        state.servingCountText.trim(),
      );
      if (servingCount.isZero) {
        throw const NutritionRecipeValidationError(
          'invalid_serving_count',
          'Declared servings must be greater than zero.',
        );
      }
      final servingDefinition = NutritionRecipeServingDefinition(
        id: state.servingDefinitionId ?? 'recipe-serving::${_uuid.v4()}',
        revision: state.servingDefinitionRevision ?? 'b03-editor-v1',
        count: servingCount,
        source: state.servingDefinitionSource,
      );
      NutritionRecipeDraftModel draft;
      if (state.draft != null) {
        draft = await _recipes.updateDraft(
          recipeId: state.draft!.recipe.id,
          draftVersionId: state.draft!.version.id,
          name: state.name,
          description: state.description,
          servingDefinition: servingDefinition,
          ingredients: state.ingredients,
        );
      } else if (state.recipe != null && state.published) {
        draft = await _recipes.createSuccessorDraft(
          recipeId: state.recipe!.id,
          note: 'Edited from production recipe editor',
        );
        draft = await _recipes.updateDraft(
          recipeId: draft.recipe.id,
          draftVersionId: draft.version.id,
          name: state.name,
          description: state.description,
          servingDefinition: servingDefinition,
          // Published ingredient IDs belong to the immutable parent graph.
          // A successor must receive fresh portable line IDs even when the
          // user leaves an ingredient otherwise unchanged.
          ingredients: _rekeyIngredients(),
        );
      } else {
        draft = await _recipes.createDraft(
          userId: userId,
          name: state.name,
          description: state.description,
          servingDefinition: servingDefinition,
          ingredients: state.ingredients,
        );
      }
      state = state.copyWith(
        status: NutritionRecipeEditorStatus.success,
        draft: draft,
        recipe: draft.recipe,
        published: false,
        errorCode: null,
        errorMessage: null,
      );
    } catch (error) {
      _fail(error, fallbackCode: 'recipe_draft_save_failed');
    }
  }

  Future<void> publish() async {
    if (state.draft == null) await saveDraft();
    final draft = state.draft;
    if (draft == null || state.status == NutritionRecipeEditorStatus.failure) {
      return;
    }
    state = state.copyWith(
      status: NutritionRecipeEditorStatus.publishing,
      errorCode: null,
      errorMessage: null,
    );
    try {
      final version = await _recipes.publishDraft(
        recipeId: draft.recipe.id,
        draftVersionId: draft.version.id,
      );
      state = state.copyWith(
        status: NutritionRecipeEditorStatus.success,
        recipe: await _recipes.getRecipe(draft.recipe.id),
        draft: NutritionRecipeDraftModel(
          recipe: draft.recipe,
          version: version,
        ),
        published: version.status == NutritionRecipeVersionStatus.published,
      );
    } catch (error) {
      _fail(error, fallbackCode: 'recipe_publish_failed');
    }
  }

  Future<void> duplicateCurrent() async {
    final version = state.recipe?.currentVersionId;
    if (version == null) {
      _fail(
        const NutritionRecipeConflictError(
          'A published recipe version is required before duplication.',
        ),
        fallbackCode: 'recipe_duplicate_failed',
      );
      return;
    }
    state = state.copyWith(status: NutritionRecipeEditorStatus.saving);
    try {
      final duplicate = await _recipes.duplicatePublishedVersion(
        sourceVersionId: version,
        userId: userId,
        name: '${state.name} copy',
      );
      state = state.copyWith(
        status: NutritionRecipeEditorStatus.success,
        draft: duplicate,
        recipe: duplicate.recipe,
        name: duplicate.recipe.name,
        description: duplicate.recipe.description ?? '',
        servingCountText:
            duplicate.version.servingDefinition?.count.toString() ?? '1',
        servingDefinitionId: duplicate.version.servingDefinition?.id,
        servingDefinitionRevision:
            duplicate.version.servingDefinition?.revision,
        servingDefinitionSource: duplicate.version.servingDefinition?.source,
        ingredients: _toInputs(duplicate.version.ingredients),
        published: false,
      );
    } catch (error) {
      _fail(error, fallbackCode: 'recipe_duplicate_failed');
    }
  }

  List<NutritionRecipeIngredientInput> _toInputs(
    List<NutritionRecipeIngredientModel> ingredients,
  ) => [
    for (var index = 0; index < ingredients.length; index++)
      NutritionRecipeIngredientInput.directFood(
        id: ingredients[index].id,
        foodId: ingredients[index].foodId,
        quantity: ingredients[index].quantity,
        position: index,
        preparationId: ingredients[index].preparationId,
        measureId: ingredients[index].measureId,
        lower: ingredients[index].lower,
        upper: ingredients[index].upper,
        notes: ingredients[index].notes,
        substitutedFromFoodId: ingredients[index].substitutedFromFoodId,
      ),
  ];

  List<NutritionRecipeIngredientInput> _rekeyIngredients() => [
    for (var index = 0; index < state.ingredients.length; index++)
      NutritionRecipeIngredientInput.directFood(
        id: 'ingredient::${_uuid.v4()}',
        foodId: state.ingredients[index].foodId!,
        quantity: state.ingredients[index].quantity,
        position: index,
        preparationId: state.ingredients[index].preparationId,
        measureId: state.ingredients[index].measureId,
        lower: state.ingredients[index].lower,
        upper: state.ingredients[index].upper,
        notes: state.ingredients[index].notes,
        substitutedFromFoodId: state.ingredients[index].substitutedFromFoodId,
        provenanceSource: state.ingredients[index].provenanceSource,
      ),
  ];

  void _fail(Object error, {required String fallbackCode}) {
    final exception = error is NutritionRecipeException ? error : null;
    final code = exception?.code ?? fallbackCode;
    state = state.copyWith(
      status: NutritionRecipeEditorStatus.failure,
      errorCode: code,
      errorMessage: ProductFailurePresentation.fromCode(code).message,
    );
  }
}

final nutritionRecipeEditorControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      NutritionRecipeEditorController,
      NutritionRecipeEditorState,
      NutritionRecipeEditorArgs
    >((ref, args) {
      final controller = NutritionRecipeEditorController(
        recipes: ref.watch(nutritionRecipeRepositoryProvider),
        foods: ref.watch(nutritionFoodCatalogRepositoryProvider.future),
        transformations: ref.watch(nutritionTransformationRepositoryProvider),
        userId: kLocalNutritionUserScopeId,
        recipeId: args.recipeId,
        draftVersionId: args.draftVersionId,
      );
      controller.load();
      return controller;
    });

class NutritionRecipeEditorArgs {
  final String? recipeId;
  final String? draftVersionId;

  const NutritionRecipeEditorArgs({this.recipeId, this.draftVersionId});

  @override
  bool operator ==(Object other) =>
      other is NutritionRecipeEditorArgs &&
      other.recipeId == recipeId &&
      other.draftVersionId == draftVersionId;

  @override
  int get hashCode => Object.hash(recipeId, draftVersionId);
}
