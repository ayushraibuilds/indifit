import 'package:flutter/material.dart';

import '../../../core/nutrition_thali.dart';
import '../../../core/theme/colors.dart';
import '../../../core/typed_quantities.dart';
import '../nutrition_thali_controller.dart';

class ThaliComponentPickerSheet extends StatefulWidget {
  final NutritionThaliController controller;
  final NutritionThaliState state;

  const ThaliComponentPickerSheet({
    super.key,
    required this.controller,
    required this.state,
  });

  static Future<void> show(
    BuildContext context, {
    required NutritionThaliController controller,
    required NutritionThaliState state,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ThaliComponentPickerSheet(
        controller: controller,
        state: state,
      ),
    );
  }

  @override
  State<ThaliComponentPickerSheet> createState() =>
      _ThaliComponentPickerSheetState();
}

class _ThaliComponentPickerSheetState extends State<ThaliComponentPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '100');

  NutritionThaliFoodOption? _selectedFood;
  NutritionThaliRecipeOption? _selectedRecipe;

  QuantityUnit _selectedUnit = QuantityUnit.gram;
  String? _selectedMeasureId;

  @override
  void initState() {
    super.initState();
    // Pre-populate with initial search if already set
    if (widget.state.query.isNotEmpty) {
      _searchController.text = widget.state.query;
    }
  }

  @override
  void dispose() {
    _searchController.dispose;
    _amountController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    widget.controller.search(value);
  }

  void _selectFood(NutritionThaliFoodOption food) {
    setState(() {
      _selectedFood = food;
      _selectedRecipe = null;
      _selectedUnit = QuantityUnit.gram;
      _selectedMeasureId = null;
      _amountController.text = '100';
    });
  }

  void _selectRecipe(NutritionThaliRecipeOption recipe) {
    setState(() {
      _selectedRecipe = recipe;
      _selectedFood = null;
      _selectedUnit = QuantityUnit.serving;
      _selectedMeasureId = null;
      _amountController.text = '1';
    });
  }

  void _confirmAdd() {
    final rawAmount = double.tryParse(_amountController.text.trim()) ?? 1.0;
    final amount = rawAmount <= 0 ? 1.0 : rawAmount;

    if (_selectedFood != null) {
      Quantity quantity;
      if (_selectedUnit == QuantityUnit.householdReference &&
          _selectedMeasureId != null) {
        quantity = Quantity(
          amount: QuantityAmount.fromNum(amount),
          unit: QuantityUnit.householdReference,
          context: QuantityContext(
            householdMeasure: HouseholdMeasureReference(
              measureType: _selectedMeasureId!,
            ),
          ),
        );
      } else {
        quantity = Quantity.fromNum(amount: amount, unit: _selectedUnit);
      }
      widget.controller.addFood(
        _selectedFood!,
        quantity: quantity,
      );
    } else if (_selectedRecipe != null) {
      widget.controller.addRecipe(
        _selectedRecipe!,
        quantity: Quantity(
          amount: QuantityAmount.fromNum(amount),
          unit: QuantityUnit.serving,
          context: QuantityContext(
            servingDefinition: ServingDefinitionReference(
              id: 'recipe-complete:${_selectedRecipe!.recipeVersionId}',
              revision: 'recipe-version',
              source: 'recipe_version',
            ),
          ),
        ),
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final foodResults = widget.state.foodResults;
    final recipeResults = widget.state.recipeResults;
    final isSearching = widget.state.status == NutritionThaliStatus.searching;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Dish to Thali',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Search Input
            TextField(
              key: const Key('thali_search_input'),
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search roti, dal, sabzi, paneer, rice...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.cardBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Selected item portion config card
            if (_selectedFood != null || _selectedRecipe != null)
              _buildPortionConfigCard()
            else ...[
              // Search Results List
              if (isSearching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (foodResults.isEmpty &&
                  recipeResults.isEmpty &&
                  _searchController.text.isNotEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No matching dishes found.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (foodResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'FOODS',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...foodResults.map(
                          (food) => ListTile(
                            key: Key('thali_search_food_item_${food.id}'),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            leading: const Icon(
                              Icons.restaurant_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            title: Text(
                              food.displayName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: food.region != null
                                ? Text(
                                    food.region!,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  )
                                : null,
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            onTap: () => _selectFood(food),
                          ),
                        ),
                      ],
                      if (recipeResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'SAVED RECIPES',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...recipeResults.map(
                          (recipe) => ListTile(
                            key: Key('thali_search_recipe_item_${recipe.recipeId}'),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            leading: const Icon(
                              Icons.menu_book_rounded,
                              color: AppColors.streakOrange,
                              size: 20,
                            ),
                            title: Text(
                              recipe.recipeName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            onTap: () => _selectRecipe(recipe),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPortionConfigCard() {
    final title = _selectedFood?.displayName ?? _selectedRecipe?.recipeName ?? '';
    final standardMeasures = widget.state.standardMeasures;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                onPressed: () {
                  setState(() {
                    _selectedFood = null;
                    _selectedRecipe = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'PORTION & MEASURE',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  key: const Key('thali_portion_amount_input'),
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _selectedFood != null
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('g'),
                              selected: _selectedUnit == QuantityUnit.gram,
                              onSelected: (_) {
                                setState(() {
                                  _selectedUnit = QuantityUnit.gram;
                                  _selectedMeasureId = null;
                                  _amountController.text = '100';
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('piece'),
                              selected: _selectedUnit == QuantityUnit.piece,
                              onSelected: (_) {
                                setState(() {
                                  _selectedUnit = QuantityUnit.piece;
                                  _selectedMeasureId = null;
                                  _amountController.text = '1';
                                });
                              },
                            ),
                            ...standardMeasures.take(4).map(
                              (measure) => Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  label: Text(measure.displayName),
                                  selected: _selectedMeasureId == measure.id,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedUnit =
                                          QuantityUnit.householdReference;
                                      _selectedMeasureId = measure.id;
                                      _amountController.text = '1';
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Text(
                        '1 Serving',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('thali_add_selected_item_button'),
              onPressed: _confirmAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add to Plate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
