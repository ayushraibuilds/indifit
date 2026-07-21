import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_api_service.dart';
import '../../data/repositories/food_repository.dart';
import 'barcode_scanner_screen.dart';
import 'custom_food_editor_screen.dart';
import 'meal_templates_screen.dart';


class FoodSearchScreen extends ConsumerStatefulWidget {
  final String mealType; // "breakfast", "lunch", "dinner", "snack"

  const FoodSearchScreen({super.key, required this.mealType});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _localResults = [];
  List<FoodApiResult> _onlineResults = [];
  List<FoodItem> _recentResults = [];
  bool _searching = false;
  bool _loadingRecent = true;
  Timer? _debounceTimer;
  bool _isOnlineSearchOffline = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecentFoods();
  }

  Future<void> _loadRecentFoods() async {
    try {
      final repo = ref.read(foodRepositoryProvider);
      final recent = await repo.getRecentFoods(20);
      if (mounted) {
        setState(() {
          _recentResults = recent;
          _loadingRecent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingRecent = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 375), () {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _performSearch(String text) async {
    if (text.trim().isEmpty) {
      setState(() {
        _localResults = [];
        _onlineResults = [];
        _searching = false;
        _isOnlineSearchOffline = false;
      });
      return;
    }

    setState(() => _searching = true);

    try {
      final repo = ref.read(foodRepositoryProvider);
      final apiService = ref.read(foodApiServiceProvider);

      // Perform local fuzzy database search
      final local = await repo.searchFoodLocal(text);

      List<FoodApiResult> online = [];
      bool isOnlineSearchOffline = false;

      try {
        online = await apiService.searchOnline(text);
      } catch (e) {
        isOnlineSearchOffline = true;
        debugPrint("Online search failed (device offline): $e");
      }

      if (mounted) {
        setState(() {
          _localResults = local;
          _onlineResults = online;
          _isOnlineSearchOffline = isOnlineSearchOffline;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _isOnlineSearchOffline = true;
        });
      }
    }
  }

  void _showLogDialog(String name, int calories, double protein, double carbs, double fat, double baseServing, String unit, int? foodItemId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        double multiplier = 1.0;
        return StatefulBuilder(
          builder: (context, setModalState) {
            double calcCalories = calories * multiplier;
            double calcProtein = protein * multiplier;
            double calcCarbs = carbs * multiplier;
            double calcFat = fat * multiplier;
            double currentServing = baseServing * multiplier;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log to ${widget.mealType.toUpperCase()}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  
                  // Serving adjustment row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Serving Amount', style: TextStyle(fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary),
                            onPressed: multiplier > 0.25 
                                ? () => setModalState(() => multiplier -= 0.25)
                                : null,
                          ),
                          Text(
                            '${currentServing.toStringAsFixed(1)} $unit',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                            onPressed: () => setModalState(() => multiplier += 0.25),
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(color: AppColors.border, height: 24),
                  
                  // Macros Preview Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroPreview('Calories', '${calcCalories.round()} kcal', AppColors.primary),
                      _buildMacroPreview('Protein', '${calcProtein.toStringAsFixed(1)}g', AppColors.success),
                      _buildMacroPreview('Carbs', '${calcCarbs.toStringAsFixed(1)}g', AppColors.warning),
                      _buildMacroPreview('Fat', '${calcFat.toStringAsFixed(1)}g', AppColors.danger),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final repo = ref.read(foodRepositoryProvider);
                            await repo.logFoodEntry(
                              name: name,
                              calories: calcCalories.round(),
                              proteinG: calcProtein,
                              carbsG: calcCarbs,
                              fatG: calcFat,
                              servingLogged: currentServing,
                              servingUnit: unit,
                              mealType: widget.mealType,
                              foodItemId: foodItemId,
                            );
                            if (context.mounted) {
                              Navigator.pop(context); // Close bottom sheet
                              Navigator.pop(context); // Close search screen
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Add Meal'),
                        ),
                      )
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMacroPreview(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add to ${widget.mealType.toUpperCase()}'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded, color: AppColors.primary),
            tooltip: 'My Meal Templates',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MealTemplatesScreen(initialMealType: widget.mealType),
                ),
              );
              if (result == true && mounted) Navigator.pop(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            tooltip: 'Scan Barcode',
            onPressed: () {

              _showBarcodePermissionRationale(context, () async {
                final result = await Navigator.push<FoodApiResult?>(
                  context,
                  MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                );

                if (result != null && mounted) {
                  _showLogDialog(
                    result.name,
                    result.calories,
                    result.protein,
                    result.carbs,
                    result.fat,
                    result.servingSize,
                    result.servingUnit,
                    null
                  );
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            tooltip: 'Create Custom Food',
            onPressed: () async {
              final result = await Navigator.push<bool?>(
                context,
                MaterialPageRoute(builder: (context) => const CustomFoodEditorScreen()),
              );
              if (result == true) {
                _performSearch(_searchController.text);
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Search Input Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search whole wheat chapati, dal, idli...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            
            // Search loading indicator or results list
            Expanded(
              child: _searching
                  ? const SkeletonList(count: 6)
                  : _searchController.text.isEmpty
                      ? (_recentResults.isNotEmpty
                          ? ListView(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    'RECENTLY LOGGED FOODS',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.0),
                                  ),
                                ),
                                ..._recentResults.map((food) => _buildLocalItemRow(food)),
                              ],
                            )
                          : _buildEmptyState())
                      : ListView(
                          children: [
                            if (_isOnlineSearchOffline)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Offline mode. Showing local results only.',
                                        style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_localResults.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'LOCAL INDIAN DATABASE',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.0),
                                ),
                              ),
                              ..._localResults.map((food) => _buildLocalItemRow(food)),
                              const SizedBox(height: 16),
                            ],
                            if (_onlineResults.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'GLOBAL SEARCH RESULTS',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0),
                                ),
                              ),
                              ..._onlineResults.map((food) => _buildOnlineItemRow(food)),
                            ],
                            if (_localResults.isEmpty && _onlineResults.isEmpty)
                              _buildNoResultsState(),
                          ],
                        ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLocalItemRow(FoodItem food) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (food.isCustom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Text(
                  'Custom',
                  style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${food.calories} kcal • P: ${food.proteinG}g | C: ${food.carbsG}g | F: ${food.fatG}g',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.add_rounded, color: AppColors.primary),
        onTap: () => _showLogDialog(
          food.name,
          food.calories,
          food.proteinG,
          food.carbsG,
          food.fatG,
          food.servingSize,
          food.servingUnit,
          food.id,
        ),
      ),
    );
  }

  Widget _buildOnlineItemRow(FoodApiResult food) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        subtitle: Text(
          '${food.calories} kcal • P: ${food.protein}g | C: ${food.carbs}g | F: ${food.fat}g',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.add_rounded, color: AppColors.textSecondary),
        onTap: () => _showLogDialog(
          food.name,
          food.calories,
          food.protein,
          food.carbs,
          food.fat,
          food.servingSize,
          food.servingUnit,
          null,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu_rounded, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Type to search meals...',
            style: TextStyle(color: AppColors.textSecondary),
          )
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'No items found. Try typing another term.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<bool?>(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomFoodEditorScreen()),
                );
                if (result == true) {
                  _performSearch(_searchController.text);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Custom Food'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                foregroundColor: AppColors.primary,
                elevation: 0,
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showBarcodePermissionRationale(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Camera Permission Request',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'IndiFit requires access to your camera to scan barcodes on food packaging. This allows instant matching with our offline database and the Open Food Facts API.',
            style: TextStyle(height: 1.4, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
  }
}
