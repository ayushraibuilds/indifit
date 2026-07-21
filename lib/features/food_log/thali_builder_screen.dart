import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import 'food_search_screen.dart';

class ThaliBuilderScreen extends ConsumerStatefulWidget {
  final String mealType;

  const ThaliBuilderScreen({super.key, required this.mealType});

  @override
  ConsumerState<ThaliBuilderScreen> createState() => _ThaliBuilderScreenState();
}

class _ThaliBuilderScreenState extends ConsumerState<ThaliBuilderScreen> {
  final List<ThaliItem> _items = [];
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  bool _searching = false;

  int get totalCalories => _items.fold(0, (sum, item) => sum + (item.food.calories * item.multiplier).round());
  double get totalProtein => _items.fold(0.0, (sum, item) => sum + (item.food.proteinG * item.multiplier));
  double get totalCarbs => _items.fold(0.0, (sum, item) => sum + (item.food.carbsG * item.multiplier));
  double get totalFat => _items.fold(0.0, (sum, item) => sum + (item.food.fatG * item.multiplier));

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final repo = ref.read(foodRepositoryProvider);
    final results = await repo.searchFoodLocal(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  void _addItem(FoodItem food) {
    setState(() {
      final existingIndex = _items.indexWhere((item) => item.food.id == food.id && food.id != -1);
      if (existingIndex != -1) {
        _items[existingIndex].multiplier += 1.0;
      } else {
        _items.add(ThaliItem(food: food, multiplier: 1.0));
      }
      _searchController.clear();
      _searchResults = [];
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _updateMultiplier(int index, double val) {
    if (val <= 0) {
      _removeItem(index);
    } else {
      setState(() {
        _items[index].multiplier = val;
      });
    }
  }

  Future<void> _logThali() async {
    if (_items.isEmpty) return;

    final repo = ref.read(foodRepositoryProvider);
    final String groupId = const Uuid().v4();

    for (final item in _items) {
      await repo.logFoodEntry(
        name: item.food.name,
        calories: (item.food.calories * item.multiplier).round(),
        proteinG: item.food.proteinG * item.multiplier,
        carbsG: item.food.carbsG * item.multiplier,
        fatG: item.food.fatG * item.multiplier,
        servingLogged: item.food.servingSize * item.multiplier,
        servingUnit: item.food.servingUnit,
        mealType: widget.mealType,
        foodItemId: item.food.id == -1 ? null : item.food.id,
        mealGroupId: groupId,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged ${widget.mealType.toUpperCase()} Thali (${totalCalories} kcal)'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_items.isEmpty) return;

    final controller = TextEditingController(text: 'My Custom Thali');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Save Thali as Template'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Thali Name',
            hintText: 'e.g. South Indian Lunch Plate',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final repo = ref.read(foodRepositoryProvider);
    // Convert ThaliItems into FoodLog lookalikes for saveMealTemplate parameter structure
    final List<FoodLog> logs = _items.map((item) => FoodLog(
      id: 0,
      name: item.food.name,
      calories: (item.food.calories * item.multiplier).round(),
      proteinG: item.food.proteinG * item.multiplier,
      carbsG: item.food.carbsG * item.multiplier,
      fatG: item.food.fatG * item.multiplier,
      servingLogged: item.food.servingSize * item.multiplier,
      servingUnit: item.food.servingUnit,
      mealType: widget.mealType,
      loggedAt: DateTime.now(),
      isSynced: false,
    )).toList();

    await repo.saveMealTemplate(
      name: name,
      defaultMealType: widget.mealType,
      items: logs,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved template “$name”'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Thali Builder · ${widget.mealType.toUpperCase()}'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (_items.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined, color: AppColors.warning),
              tooltip: 'Save as Template',
              onPressed: _saveAsTemplate,
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          // running total card
          _buildSummaryCard(),

          // Plate contents section
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plate items list
                Expanded(
                  flex: 3,
                  child: _items.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _buildPlateItemRow(item, index);
                          },
                        ),
                ),
              ],
            ),
          ),

          // Search section at bottom
          _buildSearchBox(),

          // Log Action Button
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _logThali,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Log Complete Thali (${totalCalories} kcal)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Running Totals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textSecondary)),
              Text('$totalCalories kcal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroItem('Protein', '${totalProtein.toStringAsFixed(1)}g', AppColors.success),
              _buildMacroItem('Carbs', '${totalCarbs.toStringAsFixed(1)}g', AppColors.warning),
              _buildMacroItem('Fat', '${totalFat.toStringAsFixed(1)}g', AppColors.danger),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_rounded, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Your Thali is empty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text(
              'Search and add traditional items below to construct your plate.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlateItemRow(ThaliItem item, int index) {
    final computedCals = (item.food.calories * item.multiplier).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        title: Text(item.food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '$computedCals kcal • ${(item.food.servingSize * item.multiplier).toStringAsFixed(1)} ${item.food.servingUnit}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 20),
              onPressed: () => _updateMultiplier(index, item.multiplier - 0.5),
            ),
            Text(
              '${item.multiplier.toStringAsFixed(1)}x',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
              onPressed: () => _updateMultiplier(index, item.multiplier + 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Add to Thali: Roti, Dal, Paneer...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _search('');
                      },
                    )
                  : null,
            ),
            onChanged: _search,
          ),
          if (_searchResults.isNotEmpty || _searching)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: _searching
                  ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final food = _searchResults[index];
                        return ListTile(
                          title: Text(food.name),
                          subtitle: Text('${food.calories} kcal per ${food.servingSize} ${food.servingUnit}'),
                          trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                          onTap: () => _addItem(food),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}

class ThaliItem {
  final FoodItem food;
  double multiplier;

  ThaliItem({required this.food, required this.multiplier});
}
