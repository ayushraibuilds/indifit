import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/raw_cooked_transformations.dart';
import '../../core/theme/colors.dart';
import '../../core/typed_quantities.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import 'nutrition_recipe_editor_controller.dart';

class NutritionRecipeEditorScreen extends ConsumerStatefulWidget {
  final String? recipeId;
  final String? draftVersionId;

  const NutritionRecipeEditorScreen({
    super.key,
    this.recipeId,
    this.draftVersionId,
  });

  @override
  ConsumerState<NutritionRecipeEditorScreen> createState() =>
      _NutritionRecipeEditorScreenState();
}

class _NutritionRecipeEditorScreenState
    extends ConsumerState<NutritionRecipeEditorScreen> {
  late final NutritionRecipeEditorArgs _args;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _servingCountController = TextEditingController();
  final _searchController = TextEditingController();
  NutritionRecipeEditorController? _controller;

  @override
  void initState() {
    super.initState();
    _args = NutritionRecipeEditorArgs(
      recipeId: widget.recipeId,
      draftVersionId: widget.draftVersionId,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _servingCountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = nutritionRecipeEditorControllerProvider(_args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    _controller = controller;
    if (_nameController.text != state.name &&
        !_nameController.selection.isValid) {
      _nameController.text = state.name;
    }
    if (_descriptionController.text != state.description &&
        !_descriptionController.selection.isValid) {
      _descriptionController.text = state.description;
    }
    if (_servingCountController.text != state.servingCountText &&
        !_servingCountController.selection.isValid) {
      _servingCountController.text = state.servingCountText;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeId == null ? 'Create Recipe' : 'Edit Recipe'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (_controller != null)
            IconButton(
              tooltip: 'Save draft',
              icon: const Icon(Icons.save_outlined),
              onPressed: () => unawaited(_saveDraft()),
            ),
        ],
      ),
      body:
          state.status == NutritionRecipeEditorStatus.loading ||
              state.status == NutritionRecipeEditorStatus.idle
          ? const Center(child: CircularProgressIndicator())
          : _buildEditor(context, controller, state),
    );
  }

  Widget _buildEditor(
    BuildContext context,
    NutritionRecipeEditorController controller,
    NutritionRecipeEditorState state,
  ) {
    final busy =
        state.status == NutritionRecipeEditorStatus.saving ||
        state.status == NutritionRecipeEditorStatus.publishing;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Recipe name',
              border: OutlineInputBorder(),
            ),
            onChanged: controller.setName,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            enabled: !busy,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: controller.setDescription,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _servingCountController,
            enabled: !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Declared servings',
              helperText: 'Used when scaling a saved recipe at log time.',
              border: OutlineInputBorder(),
            ),
            onChanged: controller.setServingCount,
          ),
          const SizedBox(height: 20),
          if (state.errorMessage != null)
            Card(
              color: AppColors.danger.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(
                  Icons.error_outline,
                  color: AppColors.danger,
                ),
                title: Text(state.errorMessage!),
              ),
            ),
          Row(
            children: [
              Text(
                'Ingredients',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text('${state.ingredients.length} added'),
            ],
          ),
          const SizedBox(height: 8),
          if (state.ingredients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'An empty draft is allowed. Add a direct food before publishing.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...state.ingredients.asMap().entries.map(
              (entry) => Card(
                key: ValueKey(entry.value.id),
                child: ListTile(
                  title: Text(entry.value.foodId ?? 'Unknown food'),
                  subtitle: Text(
                    '${entry.value.quantity.amount} ${entry.value.quantity.definition.displayLabel}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove ingredient',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    onPressed: busy
                        ? null
                        : () => controller.removeIngredient(entry.key),
                  ),
                  onTap: busy
                      ? null
                      : () => _editIngredientQuantity(
                          controller,
                          entry.key,
                          entry.value.quantity,
                        ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Find a direct food to add',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => unawaited(controller.searchFoods(value)),
          ),
          const SizedBox(height: 8),
          if (state.foods.isEmpty)
            const Text(
              'No foods are available offline for this search.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...state.foods
                .take(20)
                .map(
                  (food) => ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.primary,
                    ),
                    title: Text(food.displayName),
                    subtitle: Text(
                      food.hasNumericFacts
                          ? 'Typed nutrition available'
                          : 'Nutrition facts unavailable; preserved as unknown',
                    ),
                    onTap: busy ? null : () => _addIngredient(controller, food),
                  ),
                ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _saveDraft,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    state.status == NutritionRecipeEditorStatus.saving
                        ? 'Saving…'
                        : 'Save draft',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : _publish,
                  icon: const Icon(Icons.publish_outlined),
                  label: Text(
                    state.status == NutritionRecipeEditorStatus.publishing
                        ? 'Publishing…'
                        : 'Publish recipe',
                  ),
                ),
              ),
            ],
          ),
          if (state.published) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : _duplicate,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate current version'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addIngredient(
    NutritionRecipeEditorController controller,
    NutritionFoodOption food,
  ) async {
    final amount = await _quantityDialog(
      title: 'Add ${food.displayName}',
      initial: food.baseQuantity.amount.toString(),
      unit: food.baseQuantity.unit,
    );
    if (amount == null) return;
    final transformations = await controller.transformationsFor(food);
    NutritionTransformation? selected;
    if (transformations.isNotEmpty && mounted) {
      selected = await _transformationDialog(transformations);
    }
    if (!mounted) return;
    try {
      final quantity = Quantity.fromDecimal(
        amount: amount,
        unit: food.baseQuantity.unit,
        context: food.baseQuantity.context,
      );
      final target = await controller.transformedFood(food, quantity, selected);
      if (selected != null && target == null) {
        throw const FormatException('This conversion is unavailable.');
      }
      controller.addIngredient(
        food: food,
        quantity: quantity,
        transformation: selected,
        transformedOption: target,
      );
    } catch (error) {
      _showError('Ingredient was not added: $error');
    }
  }

  Future<void> _editIngredientQuantity(
    NutritionRecipeEditorController controller,
    int index,
    Quantity current,
  ) async {
    final amount = await _quantityDialog(
      title: 'Change quantity',
      initial: current.amount.toString(),
      unit: current.unit,
    );
    if (amount == null) return;
    try {
      controller.updateIngredientQuantity(
        index,
        Quantity.fromDecimal(
          amount: amount,
          unit: current.unit,
          context: current.context,
        ),
      );
    } catch (error) {
      _showError('Quantity was not updated: $error');
    }
  }

  Future<String?> _quantityDialog({
    required String title,
    required String initial,
    required QuantityUnit unit,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText:
                'Positive amount (${QuantityUnitRegistry.definitionFor(unit).displayLabel})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Use quantity'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<NutritionTransformation?> _transformationDialog(
    List<NutritionTransformation> transformations,
  ) => showDialog<NutritionTransformation?>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Optional preparation conversion'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('No conversion'),
        ),
        for (final transformation in transformations)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, transformation),
            child: Text(
              '${transformation.sourceState.name} → ${transformation.targetState.name} (${transformation.method.name})',
            ),
          ),
      ],
    ),
  );

  Future<void> _saveDraft() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.saveDraft();
    if (mounted &&
        controller.currentState.status == NutritionRecipeEditorStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe draft saved offline.')),
      );
    }
  }

  Future<void> _publish() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.publish();
    if (!mounted) return;
    if (controller.currentState.published) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe published as an immutable version.'),
        ),
      );
    }
  }

  Future<void> _duplicate() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.duplicateCurrent();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
