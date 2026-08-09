import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/typed_quantities.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
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

class CanonicalRecentFood {
  const CanonicalRecentFood({
    required this.option,
    required this.quantityLabel,
    required this.loggedAtUtc,
  });

  final NutritionFoodOption option;
  final String quantityLabel;
  final DateTime loggedAtUtc;
}

final canonicalRecentFoodsProvider =
    FutureProvider.autoDispose<List<CanonicalRecentFood>>((ref) async {
      try {
        // Avoid initializing the asset-backed canonical read stack when this
        // user has no canonical consumption at all. This is only an existence
        // gate; every displayed record still comes through the B03 read model.
        final database = ref.read(databaseProvider);
        final canonicalSnapshot =
            await (database.select(database.nutritionConsumptionSnapshots)
                  ..where(
                    (row) => row.userId.equals(kLocalNutritionUserScopeId),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (canonicalSnapshot == null) return const [];
        final history = await ref.read(
          nutritionReadModelRepositoryProvider.future,
        );
        final catalog = await ref.read(
          nutritionFoodCatalogRepositoryProvider.future,
        );
        final records = await history.listHistory(
          userId: kLocalNutritionUserScopeId,
        );
        final ordered = records.where((record) => !record.isLegacy).toList()
          ..sort(
            (left, right) => right.loggedAtUtc.compareTo(left.loggedAtUtc),
          );
        final seenFoodIds = <String>{};
        final result = <CanonicalRecentFood>[];
        for (final record in ordered) {
          for (final item in record.items) {
            final foodId = item.foodId;
            if (item.originSourceType != 'direct_food' ||
                foodId == null ||
                !seenFoodIds.add(foodId)) {
              continue;
            }
            final option = await catalog.getOption(foodId);
            if (option == null) continue;
            result.add(
              CanonicalRecentFood(
                option: option,
                quantityLabel: item.quantity.quantity == null
                    ? 'Previous amount unavailable'
                    : QuantityFormatter.format(item.quantity.quantity!),
                loggedAtUtc: record.loggedAtUtc,
              ),
            );
            if (result.length == 20) return result;
          }
        }
        return result;
      } catch (_) {
        // A canonical-history read must never make local/legacy Recent unusable.
        return const [];
      }
    });

class _FoodQuantityReviewCapture extends StatelessWidget {
  const _FoodQuantityReviewCapture({
    required this.padding,
    required this.child,
  });

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: const ValueKey('food_quantity_review_surface'),
    child: Padding(
      padding: padding,
      child: SingleChildScrollView(child: child),
    ),
  );
}

class _FoodAmountTextField extends StatefulWidget {
  const _FoodAmountTextField({
    required this.quantity,
    required this.errorText,
    required this.suffixText,
    required this.onChanged,
  });

  final Quantity quantity;
  final String? errorText;
  final String? suffixText;
  final ValueChanged<String> onChanged;

  @override
  State<_FoodAmountTextField> createState() => _FoodAmountTextFieldState();
}

class _FoodAmountTextFieldState extends State<_FoodAmountTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.quantity.amount.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _FoodAmountTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.quantity.amount.toString();
    if (_controller.text == nextText) return;
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
    ],
    decoration: InputDecoration(
      labelText: 'Amount',
      errorText: widget.errorText,
      suffixText: widget.suffixText,
    ),
    onChanged: widget.onChanged,
  );
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _localResults = [];
  List<FoodApiResult> _onlineResults = [];
  List<FoodItem> _recentResults = [];
  List<CanonicalRecentFood> _canonicalRecentResults = [];
  bool _searching = false;
  bool _searchingOnline = false;
  int _searchGeneration = 0;
  bool _loadingRecent = true;
  String? _recentFailureMessage;
  Timer? _debounceTimer;
  final Set<Timer> _recentTimeouts = {};
  bool _isOnlineSearchOffline = false;
  String? _onlineFailureMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecentFoods();
  }

  Future<void> _loadRecentFoods() async {
    final legacyFuture = ref
        .read(foodRepositoryProvider)
        .getRecentFoods(20)
        .then<(List<FoodItem>, bool)>((foods) => (foods, false))
        .catchError((_) => (<FoodItem>[], true));
    final canonicalFuture = _canonicalRecentWithTimeout();
    final canonicalRecent = await canonicalFuture;
    final recentResult = canonicalRecent.isEmpty
        ? await legacyFuture
        : (const <FoodItem>[], false);
    // Canonical B03 history owns Recent. Legacy rows are a compatibility
    // fallback only, and must not displace foods logged through current paths.
    final recent = canonicalRecent.isEmpty
        ? recentResult.$1
        : const <FoodItem>[];
    if (mounted) {
      setState(() {
        _recentResults = recent;
        _canonicalRecentResults = canonicalRecent;
        _loadingRecent = false;
        _recentFailureMessage =
            recent.isEmpty && canonicalRecent.isEmpty && recentResult.$2
            ? 'Recent foods are unavailable right now.'
            : null;
      });
    }
  }

  Future<void> _retryRecentFoods() async {
    if (mounted) {
      setState(() {
        _loadingRecent = true;
        _recentFailureMessage = null;
      });
    }
    ref.invalidate(canonicalRecentFoodsProvider);
    await _loadRecentFoods();
  }

  Future<List<CanonicalRecentFood>> _canonicalRecentWithTimeout() {
    final completer = Completer<List<CanonicalRecentFood>>();
    late final Timer timer;
    void finish(List<CanonicalRecentFood> value) {
      timer.cancel();
      _recentTimeouts.remove(timer);
      if (!completer.isCompleted) completer.complete(value);
    }

    timer = Timer(const Duration(seconds: 2), () {
      _recentTimeouts.remove(timer);
      if (!completer.isCompleted) completer.complete(const []);
    });
    _recentTimeouts.add(timer);
    ref
        .read(canonicalRecentFoodsProvider.future)
        .then(finish, onError: (_) => finish(const []));
    return completer.future;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    for (final timer in _recentTimeouts) {
      timer.cancel();
    }
    _recentTimeouts.clear();
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
    if (!mounted) return;
    final query = text.trim();
    final generation = ++_searchGeneration;
    if (query.isEmpty) {
      setState(() {
        _localResults = [];
        _onlineResults = [];
        _searching = false;
        _searchingOnline = false;
        _isOnlineSearchOffline = false;
        _onlineFailureMessage = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchingOnline = false;
      _isOnlineSearchOffline = false;
      _onlineFailureMessage = null;
      _onlineResults = [];
    });

    List<FoodItem> local = const [];
    try {
      final repo = ref.read(foodRepositoryProvider);
      local = await repo.searchFoodLocal(query);
    } catch (_) {
      // Online search may still be useful when the local compatibility store
      // is temporarily unavailable.
    }
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _localResults = local;
      _searching = false;
      _searchingOnline = true;
    });

    try {
      final online = await ref.read(foodApiServiceProvider).searchOnline(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _onlineResults = online;
        _isOnlineSearchOffline = false;
        _onlineFailureMessage = null;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _onlineResults = [];
        _isOnlineSearchOffline = true;
        _onlineFailureMessage = 'Online results are unavailable right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          if (generation == _searchGeneration) _searchingOnline = false;
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
    var finalized = false;
    var selectedQuantity = option.baseQuantity;
    final compatibleUnits = switch (option.baseQuantity.dimension) {
      QuantityDimension.mass => const [
        QuantityUnit.milligram,
        QuantityUnit.gram,
        QuantityUnit.kilogram,
      ],
      QuantityDimension.volume => const [
        QuantityUnit.millilitre,
        QuantityUnit.litre,
      ],
      _ => [option.baseQuantity.unit],
    };
    final stepQuantity = option.baseQuantity / 4;
    TransitionRoute<dynamic>? sheetRoute;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.b05Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        sheetRoute ??= ModalRoute.of(sheetContext);
        String? selectedTransformationId;
        String? amountError;
        String? commandId;
        String? consumptionId;
        var isFinalizing = false;
        late Future<NutritionFoodLogPreview> previewFuture;
        Future<NutritionFoodLogPreview> buildPreview() => coordinator.preview(
          option: option,
          quantity: selectedQuantity,
          transformation: transformations
              .where((item) => item.id == selectedTransformationId)
              .firstOrNull,
        );
        previewFuture = buildPreview();
        void setQuantity(Quantity quantity, StateSetter setModalState) {
          setModalState(() {
            selectedQuantity = quantity;
            amountError = null;
            previewFuture = buildPreview();
          });
        }

        void updateAmount(String raw, StateSetter setModalState) {
          try {
            final quantity = Quantity.fromDecimal(
              amount: raw,
              unit: selectedQuantity.unit,
              context: selectedQuantity.context,
            );
            NutritionQuantityService.validatePositiveUserEnteredPortion(
              quantity,
            );
            setModalState(() {
              selectedQuantity = quantity;
              amountError = null;
              previewFuture = buildPreview();
            });
          } on QuantityError {
            setModalState(() {
              amountError = 'Enter an amount greater than zero.';
            });
          }
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return _FoodQuantityReviewCapture(
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
                  Text(option.displayName, style: B05Typography.title(context)),
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    label: 'Adding to ${_mealLabel(widget.mealType)}',
                    child: Text(
                      'Log to ${widget.mealType.toUpperCase()}',
                      style: TextStyle(
                        color: context.b05Colors.action,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: 'Decrease amount',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: selectedQuantity.compareTo(stepQuantity) > 0
                            ? () => setQuantity(
                                selectedQuantity - stepQuantity,
                                setModalState,
                              )
                            : null,
                      ),
                      Expanded(
                        child: _FoodAmountTextField(
                          quantity: selectedQuantity,
                          errorText: amountError,
                          suffixText: compatibleUnits.length == 1
                              ? _quantityUnitLabel(selectedQuantity)
                              : null,
                          onChanged: (value) =>
                              updateAmount(value, setModalState),
                        ),
                      ),
                      if (compatibleUnits.length > 1) ...[
                        const SizedBox(width: 8),
                        Semantics(
                          label: 'Unit',
                          value: _quantityUnitLabel(selectedQuantity),
                          child: DropdownButton<QuantityUnit>(
                            value: selectedQuantity.unit,
                            items: compatibleUnits
                                .map(
                                  (unit) => DropdownMenuItem(
                                    value: unit,
                                    child: Text(
                                      QuantityUnitRegistry.definitionFor(
                                        unit,
                                      ).symbol,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (unit) {
                              if (unit == null) return;
                              setQuantity(
                                selectedQuantity.convertTo(unit),
                                setModalState,
                              );
                            },
                          ),
                        ),
                      ],
                      IconButton(
                        tooltip: 'Increase amount',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setQuantity(
                          selectedQuantity + stepQuantity,
                          setModalState,
                        ),
                      ),
                    ],
                  ),
                  Divider(color: context.b05Colors.border, height: 24),

                  if (transformations.isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: selectedTransformationId,
                      decoration: const InputDecoration(
                        labelText: 'Logged as (optional)',
                        helperText:
                            'Choose raw or cooked only when it applies.',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No conversion'),
                        ),
                        ...transformations.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.id,
                            child: Text(_transformationLabel(item)),
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
                        return Text(
                          'Nutrition preview unavailable. Try again.',
                          style: TextStyle(
                            color: context.b05Colors.warning.foreground,
                          ),
                        );
                      }
                      final facts = snapshot.data!.facts;
                      String value(String id, String unit) {
                        final fact = facts[id];
                        if (fact == null || !fact.isAvailable) return '—';
                        final decimals = id == 'energy' ? 0 : 1;
                        if (fact.point != null) {
                          return '${fact.point!.value.format(decimalPlaces: decimals)}$unit';
                        }
                        if (fact.lower != null && fact.upper != null) {
                          return '${fact.lower!.value.format(decimalPlaces: decimals)}–${fact.upper!.value.format(decimalPlaces: decimals)}$unit';
                        }
                        return '—';
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMacroPreview(
                            'Calories',
                            value('energy', ' kcal'),
                            context.b05Colors.action,
                          ),
                          _buildMacroPreview(
                            'Protein',
                            value('protein', 'g'),
                            context.b05Colors
                                .meal(B05MealAccent.breakfast)
                                .indicator,
                          ),
                          _buildMacroPreview(
                            'Carbs',
                            value('carbohydrate', 'g'),
                            context.b05Colors
                                .meal(B05MealAccent.lunch)
                                .indicator,
                          ),
                          _buildMacroPreview(
                            'Fat',
                            value('fat', 'g'),
                            context.b05Colors
                                .meal(B05MealAccent.dinner)
                                .indicator,
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
                            side: BorderSide(color: context.b05Colors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: context.b05Colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isFinalizing || amountError != null
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
                                    // Keep the route result as a secondary
                                    // signal. A platform haptic/plugin call
                                    // must not prevent the completed canonical
                                    // save from closing the food flow.
                                    finalized = true;
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
                                    try {
                                      await HapticFeedback.selectionClick();
                                    } catch (_) {
                                      // Haptics are optional feedback; a
                                      // missing plugin cannot make a saved
                                      // meal look unsaved.
                                    }
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
                            backgroundColor: context.b05Colors.action,
                            foregroundColor: context.b05Colors.onAction,
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
    if ((saved == true || finalized) && mounted) {
      // The result future resolves when the sheet begins closing. Wait for
      // its overlay to be removed before popping the meal-specific search
      // route, otherwise `maybePop` can run while the navigator is locked.
      await sheetRoute?.completed;
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Widget _buildMacroPreview(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.b05Colors.textSecondary,
          ),
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log ${widget.mealType.toLowerCase()}',
              style: B05Typography.title(context),
            ),
            Text(dateStr, style: B05Typography.caption(context)),
          ],
        ),
        actions: [_buildMoreMenu(context)],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add ${_mealLabel(widget.mealType)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search foods',
                    hintText: 'Roti, paneer bhurji, dal, idli…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear food search',
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _searching
                      ? const SkeletonList(count: 6)
                      : _searchController.text.isEmpty
                      ? _buildLandingState(logDate)
                      : _buildSearchResults(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'More food options',
    onSelected: (value) async {
      if (value == 'custom') {
        final result = await Navigator.push<bool?>(
          context,
          MaterialPageRoute(builder: (_) => const CustomFoodEditorScreen()),
        );
        if (result == true) await _performSearch(_searchController.text);
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'custom', child: Text('Create a custom food')),
    ],
  );

  Widget _buildLandingState(DateTime logDate) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _sectionHeader(
          title: 'Recent',
          subtitle: 'Foods you log often stay close at hand.',
        ),
        if (_loadingRecent)
          const SkeletonList(count: 3)
        else if (_recentFailureMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ConsumerStatusRow(
              label: 'Recent foods unavailable',
              detail: _recentFailureMessage,
              error: true,
              onRetry: _retryRecentFoods,
            ),
          )
        else if (_canonicalRecentResults.isEmpty && _recentResults.isEmpty)
          _buildLandingEmpty(
            title: 'No recent foods yet',
            message: 'Foods you log will appear here.',
          )
        else
          ..._canonicalRecentResults.map(_buildCanonicalRecentItemRow),
        if (!_loadingRecent &&
            _recentResults.isNotEmpty &&
            _canonicalRecentResults.isNotEmpty)
          const SizedBox(height: 8),
        if (!_loadingRecent) ..._recentResults.take(6).map(_buildRecentItemRow),
        const SizedBox(height: 16),
        _sectionHeader(
          title: 'Saved',
          subtitle: 'Keep recipes for meals you make often.',
        ),
        _buildNavigationCard(
          icon: Icons.bookmark_outline_rounded,
          title: 'Saved recipes',
          detail: 'Open, scale and add a published recipe.',
          onTap: _openSavedRecipes,
        ),
        const SizedBox(height: 16),
        _sectionHeader(
          title: 'Recipes',
          subtitle: 'Choose a complete meal and add it in a few taps.',
        ),
        _buildNavigationCard(
          icon: Icons.menu_book_rounded,
          title: 'Browse recipes',
          detail: 'Find a recipe or create one from Food.',
          onTap: _openSavedRecipes,
        ),
        const SizedBox(height: 16),
        _sectionHeader(
          title: 'More ways',
          subtitle: 'Optional shortcuts when they help.',
        ),
        _buildNavigationCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scan barcode',
          detail: 'Find a packaged food by its barcode.',
          onTap: () => _openBarcode(context),
        ),
        _buildNavigationCard(
          icon: Icons.auto_awesome_rounded,
          title: 'Describe with AI',
          detail: 'Get an estimate, then review it before saving.',
          onTap: () => _openAi(context),
        ),
        _buildNavigationCard(
          icon: Icons.photo_camera_outlined,
          title: 'Photo estimate',
          detail: 'Use a photo as an optional starting point.',
          onTap: () => _openAi(context),
        ),
        const SizedBox(height: 16),
        FoodLogEntriesPanel(date: logDate),
      ],
    );
  }

  Widget _buildSearchResults() => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      if (_isOnlineSearchOffline)
        ConsumerStatusRow(
          label: 'Online search unavailable',
          detail: _localResults.isNotEmpty
              ? 'Foods on this device are still available.'
              : _onlineFailureMessage ?? 'Try again or choose from Recent.',
          error: true,
          onRetry: () => _performSearch(_searchController.text),
        ),
      if (_localResults.isNotEmpty) ...[
        _sectionHeader(title: 'Foods on this device'),
        ..._localResults.map(_buildLocalItemRow),
      ],
      if (_onlineResults.isNotEmpty) ...[
        const SizedBox(height: 12),
        _sectionHeader(title: 'More results'),
        ..._onlineResults.map(_buildOnlineItemRow),
      ],
      if (_searchingOnline)
        const ConsumerStatusRow(
          label: 'Searching more foods',
          detail: 'Foods on this device are ready to use.',
          loading: true,
        ),
      if (!_searchingOnline &&
          !_isOnlineSearchOffline &&
          _localResults.isEmpty &&
          _onlineResults.isEmpty)
        _buildNoResultsState(),
    ],
  );

  Widget _sectionHeader({required String title, String? subtitle}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: B05Typography.title(context)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle, style: B05Typography.caption(context)),
          ),
      ],
    ),
  );

  Widget _buildLandingEmpty({required String title, required String message}) =>
      B05Surface(
        subtle: true,
        showBorder: false,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.history_rounded, color: context.b05Colors.action),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: B05Typography.label(context)),
                  const SizedBox(height: 2),
                  Text(message, style: B05Typography.body(context)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildNavigationCard({
    required IconData icon,
    required String title,
    required String detail,
    required VoidCallback onTap,
  }) => B05Surface(
    padding: EdgeInsets.zero,
    child: Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      label: title,
      hint: detail,
      child: ListTile(
        minVerticalPadding: 12,
        leading: Icon(icon, color: context.b05Colors.action),
        title: Text(title, style: B05Typography.label(context)),
        subtitle: Text(detail, style: B05Typography.caption(context)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );

  Widget _buildRecentItemRow(FoodItem food) =>
      _buildLocalItemRow(food, recent: true);

  Widget _buildCanonicalRecentItemRow(CanonicalRecentFood recent) {
    final option = recent.option;
    final energy = _optionFactLabel(option, 'energy', 'kcal', 0);
    final protein = _optionFactLabel(option, 'protein', 'g protein', 1);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label: '${option.displayName}, $energy, $protein',
        hint: 'Opens the amount screen for ${_mealLabel(widget.mealType)}.',
        child: ListTile(
          minVerticalPadding: 10,
          title: Text(
            option.displayName,
            style: B05Typography.label(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${recent.quantityLabel} · ${_lastLoggedLabel(recent.loggedAtUtc)} · $energy · $protein',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton.icon(
            onPressed: () => unawaited(_showLogDialog(option)),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
          ),
          onTap: () => unawaited(_showLogDialog(option)),
        ),
      ),
    );
  }

  String _optionFactLabel(
    NutritionFoodOption option,
    String nutrientId,
    String unit,
    int precision,
  ) {
    final fact = option.facts[nutrientId];
    if (fact == null || !fact.isAvailable) return '—';
    String format(NutrientAmount? amount) => amount == null
        ? '—'
        : '${amount.value.format(decimalPlaces: precision)} $unit';
    if (fact.lower == null && fact.upper == null) return format(fact.point);
    return '${format(fact.lower)}–${format(fact.upper)}';
  }

  String _lastLoggedLabel(DateTime timestamp) {
    final days = DateTime.now().difference(timestamp.toLocal()).inDays;
    return days <= 0
        ? 'last logged today'
        : days == 1
        ? 'last logged yesterday'
        : 'last logged $days days ago';
  }

  Future<void> _openSavedRecipes() async {
    final result = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedRecipeLogScreen(
          mealType: widget.mealType,
          selectedDate: widget.selectedDate,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) Navigator.pop(context, true);
  }

  Future<void> _openAi(BuildContext context) async {
    final saved = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => AiMealLoggerScreen(
          mealType: widget.mealType,
          selectedDate: widget.selectedDate,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.pop(this.context, true);
  }

  void _openBarcode(BuildContext context) {
    _showBarcodePermissionRationale(context, () async {
      final result = await Navigator.push<Object?>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );
      if (!mounted) return;
      if (result is FoodApiResult) {
        unawaited(_openProviderLogDialog(result));
      } else if (result == true) {
        await _retryRecentFoods();
        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(
              content: Text('Custom food saved. Search by name to add it.'),
            ),
          );
        }
      }
    });
  }

  String _mealLabel(String value) {
    return switch (value.trim().toLowerCase()) {
      'breakfast' => 'breakfast',
      'lunch' => 'lunch',
      'dinner' => 'dinner',
      'snack' || 'snacks' => 'snack',
      _ => 'meal',
    };
  }

  String _quantityUnitLabel(Quantity quantity) =>
      quantity.unit == QuantityUnit.householdReference
      ? quantity.context.householdMeasure!.measureType
      : quantity.definition.displayLabel;

  String _transformationLabel(dynamic transformation) {
    final source = _preparationLabel(transformation.sourceState);
    final target = _preparationLabel(transformation.targetState);
    if (source == 'Preparation' && target == 'Preparation') {
      return 'Use this preparation';
    }
    return '$source → $target';
  }

  String _preparationLabel(dynamic value) {
    final name = value.toString().split('.').last;
    return switch (name) {
      'raw' => 'Raw',
      'cooked' => 'Cooked',
      _ => 'Preparation',
    };
  }

  Widget _buildLocalItemRow(FoodItem food, {bool recent = false}) {
    final serving =
        '${_numberLabel(food.servingSize)} ${food.servingUnit.trim()}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label: '${food.name}, ${food.calories} kilocalories, $serving',
        hint: 'Opens the amount screen for ${_mealLabel(widget.mealType)}.',
        child: ListTile(
          minVerticalPadding: 10,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  food.name,
                  style: B05Typography.label(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (food.isCustom)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Chip(
                    label: const Text('Custom'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelStyle: TextStyle(
                      color: context.b05Colors.success.foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: context.b05Colors.success.container,
                  ),
                ),
            ],
          ),
          subtitle: Text(
            '${_numberLabel(food.calories)} kcal · ${_numberLabel(food.proteinG)} g protein · $serving${recent ? ' · Recent' : ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton.icon(
            onPressed: () => unawaited(_openLegacyLogDialog(food)),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
          ),
          onTap: () => unawaited(_openLegacyLogDialog(food)),
        ),
      ),
    );
  }

  Widget _buildOnlineItemRow(FoodApiResult food) {
    final serving =
        '${_formatProviderNumber(food.servingSize)} ${food.servingUnit}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label:
            '${food.name}, ${_formatProviderValue(food.calories, 'kcal')}, $serving',
        hint: 'Opens the amount screen for ${_mealLabel(widget.mealType)}.',
        child: ListTile(
          minVerticalPadding: 10,
          title: Text(
            food.name,
            style: B05Typography.label(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${_formatProviderValue(food.calories, 'kcal')} · ${_formatProviderValue(food.protein, 'g protein')} · $serving',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton.icon(
            onPressed: () => unawaited(_openProviderLogDialog(food)),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
          ),
          onTap: () => unawaited(_openProviderLogDialog(food)),
        ),
      ),
    );
  }

  String _formatProviderValue(double? value, String unit) =>
      value == null ? '—' : '${value.toStringAsFixed(1)} $unit';

  String _formatProviderNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  String _numberLabel(num value) => value.toDouble() == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  Widget _buildNoResultsState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: context.b05Colors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text('No foods found', style: B05Typography.label(context)),
            const SizedBox(height: 4),
            Text(
              'Try another name or create a custom food.',
              style: B05Typography.body(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
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
              label: const Text('Create a custom food'),
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
          backgroundColor: context.b05Colors.surface,
          title: const Text(
            'Camera Permission Request',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Camera access lets IndiFit scan a package barcode. You can cancel and search for the food instead.',
            style: TextStyle(
              height: 1.4,
              color: context.b05Colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.b05Colors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.b05Colors.action,
                foregroundColor: context.b05Colors.onAction,
              ),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
  }
}
