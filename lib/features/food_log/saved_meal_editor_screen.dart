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
    if (!mounted) return;

    final selected = await showModalBottomSheet<NutritionFoodOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FoodSelectionModal(catalogRepo: catalogRepo),
    );

    if (selected != null) {
      setState(() {
        _items.add(
          NutritionThaliItem(
            id: 'item::${const Uuid().v4()}',
            position: _items.length,
            source: NutritionThaliItemSource.food,
            foodId: selected.id,
            recipeVersionId: null,
            quantity: selected.baseQuantity,
            measureId: null,
            optional: false,
            notes: null,
            displayLabel: selected.displayName,
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
                  label: const Text('Add Food'),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
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
                                displayQty,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.b05Colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 20,
                          ),
                          onPressed: () => _adjustItemQuantity(index, -0.5),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () => _adjustItemQuantity(index, 0.5),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.danger,
                          ),
                          onPressed: () => _removeItem(index),
                        ),
                      ],
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

class _FoodSelectionModal extends StatefulWidget {
  final NutritionFoodCatalogRepository catalogRepo;

  const _FoodSelectionModal({required this.catalogRepo});

  @override
  State<_FoodSelectionModal> createState() => _FoodSelectionModalState();
}

class _FoodSelectionModalState extends State<_FoodSelectionModal> {
  final _searchController = TextEditingController();
  List<NutritionFoodOption> _options = [];
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
    final results = await widget.catalogRepo.search(query: query.trim());
    if (mounted) {
      setState(() {
        _options = results;
        _isLoading = false;
      });
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
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
                const Expanded(
                  child: Text(
                    'Select Food',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search food name…',
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
                : _options.isEmpty
                ? const Center(
                    child: Text(
                      'No matching foods found.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: _options.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = _options[index];
                      final energy =
                          option.facts['energy']?.point?.value.asDouble;
                      final calText = energy != null
                          ? '${energy.round()} kcal'
                          : '';

                      return ListTile(
                        title: Text(
                          option.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${option.servingUnitLabel ?? ''}${calText.isNotEmpty ? ' · $calText' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.b05Colors.textSecondary,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.primary,
                        ),
                        onTap: () => Navigator.pop(context, option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
