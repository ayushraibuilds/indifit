import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_api_service.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../../data/repositories/nutrition_food_logging_coordinator.dart';
import '../dashboard/today_surface_controller.dart';
import 'ai_meal_logger_screen.dart';
import 'barcode_scanner_screen.dart';
import 'custom_food_editor_screen.dart';
import 'food_log_surface.dart';
import 'meal_templates_screen.dart';
import 'saved_recipe_log_screen.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  final String mealType; // "breakfast", "lunch", "dinner", "snack"
  final DateTime? selectedDate;

  const FoodSearchScreen({
    super.key,
    required this.mealType,
    this.selectedDate,
  });

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _localResults = [];
  List<FoodApiResult> _onlineResults = [];
  List<FoodItem> _recentResults = [];
  bool _searching = false;
  Timer? _debounceTimer;
  bool _isOnlineSearchOffline = false;
  String? _onlineFailureMessage;

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
        });
      }
    } catch (e) {
      // Ignored
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
        _onlineFailureMessage = null;
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
      String? onlineFailureMessage;

      try {
        online = await apiService.searchOnline(text);
      } catch (e) {
        isOnlineSearchOffline = true;
        onlineFailureMessage = 'Online results are unavailable right now.';
      }

      if (mounted) {
        setState(() {
          _localResults = local;
          _onlineResults = online;
          _isOnlineSearchOffline = isOnlineSearchOffline;
          _onlineFailureMessage = onlineFailureMessage;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _isOnlineSearchOffline = true;
          _onlineFailureMessage = 'Food search is unavailable right now.';
        });
      }
    }
  }

  Future<void> _openLegacyLogDialog(FoodItem food) async {
    try {
      final catalog = await ref.read(
        nutritionFoodCatalogRepositoryProvider.future,
      );
      final option = await catalog.ensureLegacyFood(food);
      await _showLogDialog(option);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This food is unavailable. Try again.')),
        );
      }
    }
  }

  Future<void> _openProviderLogDialog(FoodApiResult result) async {
    try {
      final reference = result.barcode == null
          ? 'open-food-facts:search:${result.name.trim().toLowerCase()}'
          : 'open-food-facts:barcode:${result.barcode}';
      final catalog = await ref.read(
        nutritionFoodCatalogRepositoryProvider.future,
      );
      final option = await catalog.ensureProviderFood(
        displayName: result.name,
        sourceReference: reference,
        servingSize: result.servingSize,
        servingUnit: result.servingUnit,
        energyKcal: result.calories,
        proteinG: result.protein,
        carbohydrateG: result.carbs,
        fatG: result.fat,
      );
      await _showLogDialog(option);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This food is unavailable. Try again.')),
        );
      }
    }
  }

  Future<void> _showLogDialog(NutritionFoodOption option) async {
    final coordinator = await ref.read(
      nutritionFoodLoggingCoordinatorProvider.future,
    );
    final transformations = await coordinator.transformationsFor(option);
    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        double multiplier = 1.0;
        String? selectedTransformationId;
        String? commandId;
        String? consumptionId;
        var isFinalizing = false;
        late Future<NutritionFoodLogPreview> previewFuture;
        Future<NutritionFoodLogPreview> buildPreview() => coordinator.preview(
          option: option,
          quantity: option.baseQuantity * multiplier,
          transformation: transformations
              .where((item) => item.id == selectedTransformationId)
              .firstOrNull,
        );
        previewFuture = buildPreview();
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    option.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log to ${widget.mealType.toUpperCase()}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Serving adjustment row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Serving Amount',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: multiplier > 0.25
                                ? () => setModalState(() => multiplier -= 0.25)
                                : null,
                          ),
                          Text(
                            '${(option.baseQuantity.amount.asDouble * multiplier).toStringAsFixed(1)} ${option.baseQuantity.definition.displayLabel}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: AppColors.primary,
                            ),
                            onPressed: () =>
                                setModalState(() => multiplier += 0.25),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.border, height: 24),

                  if (transformations.isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: selectedTransformationId,
                      decoration: const InputDecoration(
                        labelText: 'Preparation conversion (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No conversion'),
                        ),
                        ...transformations.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.id,
                            child: Text(
                              '${item.sourceState.name} → ${item.targetState.name} (${item.method.name})',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          selectedTransformationId = value;
                          previewFuture = buildPreview();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  FutureBuilder<NutritionFoodLogPreview>(
                    future: previewFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Text(
                          'Nutrition preview unavailable. Try again.',
                          style: TextStyle(color: AppColors.warning),
                        );
                      }
                      final facts = snapshot.data!.facts;
                      String value(String id, String unit) {
                        final fact = facts[id];
                        if (fact == null) return 'Unknown';
                        final decimals = id == 'energy' ? 0 : 1;
                        if (fact.point != null) {
                          return '${fact.point!.value.format(decimalPlaces: decimals)}$unit';
                        }
                        if (fact.lower != null && fact.upper != null) {
                          return '${fact.lower!.value.format(decimalPlaces: decimals)}–${fact.upper!.value.format(decimalPlaces: decimals)}$unit';
                        }
                        return 'Unknown';
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMacroPreview(
                            'Calories',
                            value('energy', ' kcal'),
                            AppColors.primary,
                          ),
                          _buildMacroPreview(
                            'Protein',
                            value('protein', 'g'),
                            AppColors.success,
                          ),
                          _buildMacroPreview(
                            'Carbs',
                            value('carbohydrate', 'g'),
                            AppColors.warning,
                          ),
                          _buildMacroPreview(
                            'Fat',
                            value('fat', 'g'),
                            AppColors.danger,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isFinalizing
                              ? null
                              : () async {
                                  setModalState(() {
                                    isFinalizing = true;
                                    commandId ??=
                                        'direct-food-command::${const Uuid().v4()}';
                                    consumptionId ??=
                                        'direct-food-consumption::${const Uuid().v4()}';
                                  });
                                  try {
                                    final preview = await previewFuture;
                                    final timezoneId = await ref
                                        .read(localTimezoneServiceProvider)
                                        .currentTimezoneId();
                                    final dates = ref.read(
                                      localScheduleDateServiceProvider,
                                    );
                                    final selectedLocalDate =
                                        widget.selectedDate == null
                                        ? null
                                        : DateFormat(
                                            'yyyy-MM-dd',
                                          ).format(widget.selectedDate!);
                                    final loggedAt = selectedLocalDate == null
                                        ? DateTime.now().toUtc()
                                        : dates.instantForLocalDate(
                                            selectedLocalDate,
                                            timezoneId,
                                          );
                                    final localDate =
                                        selectedLocalDate ??
                                        dates.localDateFor(
                                          loggedAt,
                                          timezoneId,
                                        );
                                    await coordinator.finalize(
                                      userId: kLocalNutritionUserScopeId,
                                      preview: preview,
                                      mealCategory: widget.mealType,
                                      loggedAt: loggedAt,
                                      localDate: localDate,
                                      timezoneId: timezoneId,
                                      commandId: commandId,
                                      consumptionId: consumptionId,
                                    );
                                    ref
                                        .read(
                                          todayNutritionRevisionProvider
                                              .notifier,
                                        )
                                        .state++;
                                    ref.invalidate(
                                      b04ProductionRecommendationContextProvider,
                                    );
                                    ref.invalidate(
                                      b04CurrentFoodControllerProvider,
                                    );
                                    await HapticFeedback.selectionClick();
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop(true);
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Meal could not be logged. Try again.',
                                          ),
                                        ),
                                      );
                                    }
                                    if (context.mounted) {
                                      setModalState(() => isFinalizing = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(isFinalizing ? 'Saving…' : 'Add Meal'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    // Dismiss the parent only after the modal route has completed. Calling
    // pop twice in the same callback races the modal transition and can leave
    // the search page open after a successful canonical save.
    if (saved == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildMacroPreview(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final logDate = widget.selectedDate ?? DateTime.now();
    final dateStr = ConsumerDateLabel.dateTime(logDate);
    final explicitDate = DateFormat('EEE, MMM d').format(logDate.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log ${widget.mealType.toLowerCase()}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (dateStr != explicitDate)
              Text(
                'Logging for $explicitDate',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
            tooltip: 'Saved Recipes',
            onPressed: () async {
              final result = await Navigator.push<bool?>(
                context,
                MaterialPageRoute(
                  builder: (context) => SavedRecipeLogScreen(
                    mealType: widget.mealType,
                    selectedDate: widget.selectedDate,
                  ),
                ),
              );
              if (result == true && context.mounted) Navigator.pop(context);
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.bookmark_border_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'My Meal Templates',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MealTemplatesScreen(initialMealType: widget.mealType),
                ),
              );
              if (result == true && context.mounted) Navigator.pop(context);
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Scan Barcode',
            onPressed: () {
              _showBarcodePermissionRationale(context, () async {
                final result = await Navigator.push<FoodApiResult?>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BarcodeScannerScreen(),
                  ),
                );

                if (result != null && mounted) {
                  unawaited(_openProviderLogDialog(result));
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
                MaterialPageRoute(
                  builder: (context) => const CustomFoodEditorScreen(),
                ),
              );
              if (result == true) {
                await _performSearch(_searchController.text);
              }
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'More food logging options',
            onSelected: (value) {
              if (value == 'ai-text' || value == 'ai-photo') {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiMealLoggerScreen(
                      mealType: widget.mealType,
                      selectedDate: widget.selectedDate,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'ai-text', child: Text('Describe with AI')),
              PopupMenuItem(value: 'ai-photo', child: Text('Photo estimate')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            FoodLogEntriesPanel(date: logDate),
            const SizedBox(height: 12),
            // Search Input Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search whole wheat chapati, dal, idli...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppColors.textSecondary,
                        ),
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              ..._recentResults.map(
                                (food) => _buildLocalItemRow(food),
                              ),
                            ],
                          )
                        : _buildEmptyState())
                  : ListView(
                      children: [
                        if (_isOnlineSearchOffline)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  color: AppColors.warning,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _onlineFailureMessage ??
                                        'Offline mode. Showing local results only.',
                                    style: const TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _performSearch(_searchController.text),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        if (_localResults.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'LOCAL INDIAN DATABASE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          ..._localResults.map(
                            (food) => _buildLocalItemRow(food),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_onlineResults.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'GLOBAL SEARCH RESULTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          ..._onlineResults.map(
                            (food) => _buildOnlineItemRow(food),
                          ),
                        ],
                        if (_localResults.isEmpty && _onlineResults.isEmpty)
                          _buildNoResultsState(),
                      ],
                    ),
            ),
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
            Expanded(
              child: Text(
                food.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (food.isCustom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Custom',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${food.calories} kcal • P: ${food.proteinG}g | C: ${food.carbsG}g | F: ${food.fatG}g',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.add_rounded, color: AppColors.primary),
        onTap: () => unawaited(_openLegacyLogDialog(food)),
      ),
    );
  }

  Widget _buildOnlineItemRow(FoodApiResult food) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        title: Text(
          food.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${_formatProviderValue(food.calories, 'kcal')} • P: ${_formatProviderValue(food.protein, 'g')} | C: ${_formatProviderValue(food.carbs, 'g')} | F: ${_formatProviderValue(food.fat, 'g')}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.add_rounded, color: AppColors.textSecondary),
        onTap: () => unawaited(_openProviderLogDialog(food)),
      ),
    );
  }

  String _formatProviderValue(double? value, String unit) =>
      value == null ? 'Unknown' : '${value.toStringAsFixed(1)}$unit';

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            size: 48,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            'Type to search meals...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
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
            const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.textMuted,
            ),
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
                  MaterialPageRoute(
                    builder: (context) => const CustomFoodEditorScreen(),
                  ),
                );
                if (result == true) {
                  await _performSearch(_searchController.text);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Custom Food'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBarcodePermissionRationale(
    BuildContext context,
    VoidCallback onConfirm,
  ) {
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
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textMuted),
              ),
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
