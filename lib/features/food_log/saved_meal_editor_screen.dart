import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_thali.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/theme/colors.dart';
import '../../core/typed_quantities.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../../data/repositories/nutrition_thali_repository.dart';

class SavedMealEditorScreen extends ConsumerStatefulWidget {
  final NutritionThaliDraft? thaliDraft;
  final String? defaultMealType;

  const SavedMealEditorScreen({
    super.key,
    this.thaliDraft,
    this.defaultMealType,
  });

  @override
  ConsumerState<SavedMealEditorScreen> createState() =>
      _SavedMealEditorScreenState();
}

class _SavedMealEditorScreenState extends ConsumerState<SavedMealEditorScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<NutritionThaliItem> _items = [];
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.thaliDraft != null) {
      _nameController.text = widget.thaliDraft!.name;
      _descriptionController.text = widget.thaliDraft!.description ?? '';
      _items.addAll(widget.thaliDraft!.items);
    } else {
      _nameController.text =
          'My ${widget.defaultMealType != null ? widget.defaultMealType!.substring(0, 1).toUpperCase() + widget.defaultMealType!.substring(1) : 'Meal'}';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addFoodOrRecipe() async {
    final catalogRepo = await ref.read(
      nutritionFoodCatalogRepositoryProvider.future,
    );
    final thaliRepo = await ref.read(nutritionThaliRepositoryProvider.future);
    if (!mounted) return;

    final selected = await showModalBottomSheet<_SavedMealComponentSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SavedMealComponentPicker(
        catalogRepo: catalogRepo,
        thaliRepo: thaliRepo,
      ),
    );

    if (selected != null) {
      final food = selected.food;
      final recipe = selected.recipe;
      setState(() {
        _items.add(
          NutritionThaliItem(
            id: 'item::${const Uuid().v4()}',
            position: _items.length,
            source: food != null
                ? NutritionThaliItemSource.food
                : NutritionThaliItemSource.recipe,
            foodId: food?.id,
            recipeVersionId: recipe?.recipeVersionId,
            quantity:
                food?.baseQuantity ??
                Quantity.serving(
                  amount: '1',
                  definition: ServingDefinitionReference(
                    id: 'recipe-complete:${recipe!.recipeVersionId}',
                    revision: 'recipe-version',
                    source: 'recipe_version',
                  ),
                  source: 'saved_meal',
                ),
            measureId: null,
            optional: false,
            notes: null,
            displayLabel: food?.displayName ?? recipe!.recipeName,
          ),
        );
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _adjustItemQuantity(int index, double delta) {
    setState(() {
      final item = _items[index];
      final current = item.quantity.amount.asDouble;
      final next = (current + delta).clamp(0.25, 1000.0);
      final newAmount = QuantityAmount.fromNum(
        (next * 100).roundToDouble() / 100,
      );
      _items[index] = NutritionThaliItem(
        id: item.id,
        position: item.position,
        source: item.source,
        foodId: item.foodId,
        recipeVersionId: item.recipeVersionId,
        quantity: Quantity(
          amount: newAmount,
          unit: item.quantity.unit,
          context: item.quantity.context,
        ),
        measureId: item.measureId,
        optional: item.optional,
        notes: item.notes,
        displayLabel: item.displayLabel,
      );
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please provide a name for this meal.');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _errorMessage = 'Please add at least one food or recipe.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final thaliRepo = await ref.read(nutritionThaliRepositoryProvider.future);

      final reindexedItems = <NutritionThaliItem>[];
      for (var i = 0; i < _items.length; i++) {
        reindexedItems.add(
          NutritionThaliItem(
            id: _items[i].id,
            position: i,
            source: _items[i].source,
            foodId: _items[i].foodId,
            recipeVersionId: _items[i].recipeVersionId,
            quantity: _items[i].quantity,
            measureId: _items[i].measureId,
            optional: _items[i].optional,
            notes: _items[i].notes,
            displayLabel: _items[i].displayLabel,
          ),
        );
      }

      final draft = NutritionThaliDraft(
        id: widget.thaliDraft?.id ?? 'thali::${const Uuid().v4()}',
        userId: kLocalNutritionUserScopeId,
        name: name,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        lifecycle: 'active',
        currentVersion: widget.thaliDraft?.currentVersion ?? 1,
        createdAtUtc: widget.thaliDraft?.createdAtUtc ?? DateTime.now().toUtc(),
        updatedAtUtc: DateTime.now().toUtc(),
        items: reindexedItems,
      );

      await thaliRepo.saveDraft(draft);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "$name" successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Could not save meal. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.thaliDraft == null ? 'Create Saved Meal' : 'Edit Saved Meal',
        ),
        backgroundColor: context.b05Colors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'SAVE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Name Field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Meal Name *',
                hintText: 'e.g. Usual Lunch, Morning Shake',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description Field
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. 40g protein post workout combination',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'COMPONENTS (${_items.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    fontSize: 13,
                    color: context.b05Colors.textSecondary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addFoodOrRecipe,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add item'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: context.b05Colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.b05Colors.border),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.lunch_dining_rounded,
                        size: 40,
                        color: context.b05Colors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No components added yet',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add the foods and recipes that make up this meal.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.b05Colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _addFoodOrRecipe,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Component'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final amount = item.quantity.amount.asDouble;
                  final displayQty =
                      '${amount == amount.roundToDouble() ? amount.toInt() : amount.toStringAsFixed(1)} ${item.quantity.unit.name}';

                  return Container(
                    decoration: BoxDecoration(
                      color: context.b05Colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.b05Colors.border),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stackControls =
                            constraints.maxWidth < 380 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.25;
                        final details = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayLabel ?? 'Item',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.source == NutritionThaliItemSource.recipe ? 'Recipe · ' : 'Food · '}$displayQty',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.b05Colors.textSecondary,
                              ),
                            ),
                          ],
                        );
                        final controls = Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Reduce quantity',
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 20,
                              ),
                              onPressed: () => _adjustItemQuantity(index, -0.5),
                            ),
                            IconButton(
                              tooltip: 'Increase quantity',
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 20,
                              ),
                              onPressed: () => _adjustItemQuantity(index, 0.5),
                            ),
                            IconButton(
                              tooltip: 'Remove item',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: AppColors.danger,
                              ),
                              onPressed: () => _removeItem(index),
                            ),
                          ],
                        );
                        if (stackControls) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              details,
                              Align(
                                alignment: Alignment.centerRight,
                                child: controls,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: details),
                            controls,
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SavedMealComponentSelection {
  final NutritionFoodOption? food;
  final NutritionThaliRecipeOption? recipe;

  const _SavedMealComponentSelection.food(this.food) : recipe = null;

  const _SavedMealComponentSelection.recipe(this.recipe) : food = null;
}

enum _SavedMealPickerMode { food, recipe }

class _SavedMealComponentPicker extends StatefulWidget {
  final NutritionFoodCatalogRepository catalogRepo;
  final NutritionThaliRepository thaliRepo;

  const _SavedMealComponentPicker({
    required this.catalogRepo,
    required this.thaliRepo,
  });

  @override
  State<_SavedMealComponentPicker> createState() =>
      _SavedMealComponentPickerState();
}

class _SavedMealComponentPickerState extends State<_SavedMealComponentPicker> {
  final _searchController = TextEditingController();
  List<NutritionFoodOption> _foodOptions = [];
  List<NutritionThaliRecipeOption> _recipeOptions = [];
  _SavedMealPickerMode _mode = _SavedMealPickerMode.food;
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String query) async {
    setState(() => _isLoading = true);
    try {
      if (_mode == _SavedMealPickerMode.food) {
        final results = await widget.catalogRepo.search(query: query.trim());
        if (mounted) {
          setState(() {
            _foodOptions = results;
            _isLoading = false;
          });
        }
      } else {
        final results = await widget.thaliRepo.searchRecipes(
          userId: kLocalNutritionUserScopeId,
          query: query.trim(),
        );
        if (mounted) {
          setState(() {
            _recipeOptions = results;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  void _setMode(_SavedMealPickerMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _search(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.b05Colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _mode == _SavedMealPickerMode.food
                        ? 'Select Food'
                        : 'Select Recipe',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Food'),
                  selected: _mode == _SavedMealPickerMode.food,
                  onSelected: (_) => _setMode(_SavedMealPickerMode.food),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Recipe'),
                  selected: _mode == _SavedMealPickerMode.recipe,
                  onSelected: (_) => _setMode(_SavedMealPickerMode.recipe),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: _mode == _SavedMealPickerMode.food
                    ? 'Search food name…'
                    : 'Search recipe name…',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _mode == _SavedMealPickerMode.food
                ? _FoodOptionsList(options: _foodOptions)
                : _RecipeOptionsList(options: _recipeOptions),
          ),
        ],
      ),
    );
  }
}

class _FoodOptionsList extends StatelessWidget {
  final List<NutritionFoodOption> options;

  const _FoodOptionsList({required this.options});

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const Center(
        child: Text(
          'No matching foods found.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: options.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final option = options[index];
        final energy = option.facts['energy']?.point?.value.asDouble;
        final calText = energy != null ? '${energy.round()} kcal' : '';
        return ListTile(
          title: Text(
            option.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Food${option.servingUnitLabel == null ? '' : ' · ${option.servingUnitLabel}'}${calText.isNotEmpty ? ' · $calText' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: context.b05Colors.textSecondary,
            ),
          ),
          trailing: const Icon(
            Icons.add_circle_outline,
            color: AppColors.primary,
          ),
          onTap: () =>
              Navigator.pop(context, _SavedMealComponentSelection.food(option)),
        );
      },
    );
  }
}

class _RecipeOptionsList extends StatelessWidget {
  final List<NutritionThaliRecipeOption> options;

  const _RecipeOptionsList({required this.options});

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const Center(
        child: Text(
          'No matching recipes found.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: options.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final option = options[index];
        return ListTile(
          title: Text(
            option.recipeName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Recipe',
            style: TextStyle(
              fontSize: 13,
              color: context.b05Colors.textSecondary,
            ),
          ),
          trailing: const Icon(
            Icons.add_circle_outline,
            color: AppColors.primary,
          ),
          onTap: () => Navigator.pop(
            context,
            _SavedMealComponentSelection.recipe(option),
          ),
        );
      },
    );
  }
}
