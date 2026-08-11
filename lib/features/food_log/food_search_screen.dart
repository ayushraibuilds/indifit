import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
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
import 'canonical_food_delete.dart';
import 'custom_food_editor_screen.dart';
import 'food_log_surface.dart';
import 'saved_recipe_log_screen.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  final String? mealType; // "breakfast", "lunch", "dinner", "snack"
  final DateTime? selectedDate;
  final bool returnToParentOnSave;

  const FoodSearchScreen({
    super.key,
    required this.mealType,
    this.selectedDate,
    this.returnToParentOnSave = true,
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
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: child,
      ),
    ),
  );
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
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
  String? _selectedMealType;

  String? get _activeMealType {
    final value = (_selectedMealType ?? widget.mealType)?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    return value == 'snacks' ? 'snack' : value;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecentFoods();
  }

  Future<String?> _chooseMealContext() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose a meal', style: B05Typography.title(sheetContext)),
              const SizedBox(height: 4),
              Text(
                'Select where this food belongs before adding it.',
                style: B05Typography.body(sheetContext),
              ),
              const SizedBox(height: 8),
              for (final meal in const [
                ('breakfast', 'Breakfast', Icons.wb_sunny_outlined),
                ('lunch', 'Lunch', Icons.wb_sunny_rounded),
                ('dinner', 'Dinner', Icons.nightlight_round),
                ('snack', 'Snack', Icons.cookie_outlined),
              ])
                ListTile(
                  leading: Icon(meal.$3),
                  title: Text(meal.$2),
                  onTap: () => Navigator.of(sheetContext).pop(meal.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedMealType = selected);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
    return selected;
  }

  Future<String?> _ensureMealContext() async {
    final current = _activeMealType;
    if (current != null) return current;
    return _chooseMealContext();
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
    _searchFocusNode.dispose();
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
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      final offlinePolicy = error is StateError;
      setState(() {
        _onlineResults = [];
        _isOnlineSearchOffline = true;
        _onlineFailureMessage = offlinePolicy
            ? 'Online food search is disabled in Offline Mode.'
            : _onlineSearchFailureMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          if (generation == _searchGeneration) _searchingOnline = false;
        });
      }
    }
  }

  String _onlineSearchFailureMessage(Object error) {
    if (error is! DioException) {
      return 'Online results are unavailable right now.';
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout =>
        'Online food search timed out. Local results are still available.',
      DioExceptionType.connectionError || DioExceptionType.unknown =>
        'Online food search could not reach the provider. Check your connection.',
      DioExceptionType.badResponse =>
        'The online food provider is unavailable right now.',
      DioExceptionType.badCertificate =>
        'A secure connection to online food search could not be established.',
      DioExceptionType.cancel => 'Online food search was cancelled.',
    };
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

  Future<void> _showLogDialog(
    NutritionFoodOption option, {
    String? mealType,
    Quantity? initialQuantity,
    String? supersedesSnapshotId,
  }) async {
    final selectedMealType = mealType ?? await _ensureMealContext();
    if (selectedMealType == null || !mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final coordinator = await ref.read(
      nutritionFoodLoggingCoordinatorProvider.future,
    );
    final transformations = await coordinator.transformationsFor(option);
    if (!mounted) return;
    var finalized = false;
    var selectedQuantity = initialQuantity ?? option.baseQuantity;
    final compatibleUnits = <QuantityUnit>[
      ...switch (option.baseQuantity.dimension) {
        QuantityDimension.mass => const [
          QuantityUnit.gram,
          QuantityUnit.kilogram,
        ],
        QuantityDimension.volume => const [
          QuantityUnit.millilitre,
          QuantityUnit.litre,
        ],
        _ => [option.baseQuantity.unit],
      },
    ];
    if (!compatibleUnits.contains(option.baseQuantity.unit)) {
      compatibleUnits.insert(0, option.baseQuantity.unit);
    }
    final amountController = TextEditingController(
      text: selectedQuantity.amount.toString(),
    );
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
        Future<NutritionFoodLogPreview>? previewFuture;
        Future<NutritionFoodLogPreview> buildPreview() => coordinator.preview(
          option: option,
          quantity: selectedQuantity,
          transformation: transformations
              .where((item) => item.id == selectedTransformationId)
              .firstOrNull,
        );
        previewFuture = buildPreview();
        void setQuantity(Quantity quantity, StateSetter setModalState) {
          final nextText = quantity.amount.toString();
          amountController.value = TextEditingValue(
            text: nextText,
            selection: TextSelection.collapsed(offset: nextText.length),
          );
          setModalState(() {
            selectedQuantity = quantity;
            amountError = null;
            previewFuture = buildPreview();
          });
        }

        void updateAmount(String raw, StateSetter setModalState) {
          final trimmed = raw.trim();
          final amount = double.tryParse(trimmed);
          if (trimmed.isEmpty || trimmed == '.' || trimmed == '0.') {
            setModalState(() {
              amountError = null;
              previewFuture = null;
            });
            return;
          }
          if (amount == null || !amount.isFinite || amount <= 0) {
            setModalState(() {
              amountError = null;
              previewFuture = null;
            });
            return;
          }
          final quantity = Quantity.fromDecimal(
            amount: trimmed,
            unit: selectedQuantity.unit,
            context: selectedQuantity.context,
          );
          setModalState(() {
            selectedQuantity = quantity;
            amountError = null;
            previewFuture = buildPreview();
          });
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final stepQuantity =
                option.baseQuantity.convertTo(selectedQuantity.unit) / 4;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .86,
              ),
              child: _FoodQuantityReviewCapture(
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
                      style: B05Typography.title(context),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      label: 'Adding to ${_mealLabel(selectedMealType)}',
                      child: Text(
                        'Log to ${selectedMealType.toUpperCase()}',
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
                          onPressed:
                              selectedQuantity.compareTo(stepQuantity) > 0
                              ? () => setQuantity(
                                  selectedQuantity - stepQuantity,
                                  setModalState,
                                )
                              : null,
                        ),
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              TextInputFormatter.withFunction((
                                oldValue,
                                value,
                              ) {
                                final text = value.text;
                                return RegExp(
                                      r'^\d*(?:\.\d{0,4})?$',
                                    ).hasMatch(text)
                                    ? value
                                    : oldValue;
                              }),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              errorText: amountError,
                              suffixText: compatibleUnits.length == 1
                                  ? _quantityUnitLabel(selectedQuantity)
                                  : null,
                            ),
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
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
                        if (previewFuture == null) {
                          return Text(
                            'Enter an amount to preview nutrition.',
                            style: TextStyle(
                              color: context.b05Colors.textSecondary,
                            ),
                          );
                        }
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
                            onPressed: isFinalizing
                                ? null
                                : () async {
                                    final rawAmount = amountController.text
                                        .trim();
                                    final parsedAmount = double.tryParse(
                                      rawAmount,
                                    );
                                    if (parsedAmount == null ||
                                        !parsedAmount.isFinite ||
                                        parsedAmount <= 0) {
                                      setModalState(
                                        () => amountError =
                                            'Enter an amount greater than zero.',
                                      );
                                      return;
                                    }
                                    try {
                                      final finalQuantity =
                                          Quantity.fromDecimal(
                                            amount: rawAmount,
                                            unit: selectedQuantity.unit,
                                            context: selectedQuantity.context,
                                          );
                                      NutritionQuantityService.validatePositiveUserEnteredPortion(
                                        finalQuantity,
                                      );
                                      selectedQuantity = finalQuantity;
                                      previewFuture ??= buildPreview();
                                    } on QuantityError {
                                      setModalState(
                                        () => amountError =
                                            'Enter an amount greater than zero.',
                                      );
                                      return;
                                    }
                                    setModalState(() {
                                      isFinalizing = true;
                                      commandId ??=
                                          'direct-food-command::${const Uuid().v4()}';
                                      consumptionId ??=
                                          'direct-food-consumption::${const Uuid().v4()}';
                                    });
                                    try {
                                      final preview = await previewFuture!;
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
                                        mealCategory: selectedMealType,
                                        loggedAt: loggedAt,
                                        localDate: localDate,
                                        timezoneId: timezoneId,
                                        commandId: commandId,
                                        consumptionId: consumptionId,
                                        supersedesSnapshotId:
                                            supersedesSnapshotId,
                                        correctionId:
                                            supersedesSnapshotId == null
                                            ? null
                                            : 'food-correction::${const Uuid().v4()}',
                                        correctionReason:
                                            supersedesSnapshotId == null
                                            ? null
                                            : 'User edited logged quantity.',
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
                                        setModalState(
                                          () => isFinalizing = false,
                                        );
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
              ),
            );
          },
        );
      },
    );
    // The modal result can resolve before its reverse transition has removed
    // the EditableText. Keep the controller alive until the route is fully
    // completed so the transition cannot read a disposed controller.
    await sheetRoute?.completed;
    amountController.dispose();
    // Dismiss the parent only after the modal route has completed. Calling
    // pop twice in the same callback races the modal transition and can leave
    // the search page open after a successful canonical save.
    if ((saved == true || finalized) && mounted) {
      // The result future resolves when the sheet begins closing. Wait for
      // its overlay to be removed before popping the meal-specific search
      // route, otherwise `maybePop` can run while the navigator is locked.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              supersedesSnapshotId == null
                  ? '✓ Food added to ${_mealLabel(selectedMealType)}'
                  : '✓ Food entry updated',
            ),
          ),
        );
      }
      if (widget.returnToParentOnSave) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        await _retryRecentFoods();
      }
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
    final mealType = _activeMealType;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mealType == null ? 'Food' : 'Log ${_mealLabel(mealType)}',
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
                  mealType == null ? 'Food' : 'Add ${_mealLabel(mealType)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                if (mealType != null) ...[
                  TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: widget.mealType != null,
                    textInputAction: TextInputAction.search,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
                ],
                Expanded(
                  child: mealType != null && _searching
                      ? const SkeletonList(count: 6)
                      : mealType == null || _searchController.text.isEmpty
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_activeMealType == null) ...[
          _buildNeutralFoodEntry(),
          const SizedBox(height: 16),
        ],
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
        FoodLogEntriesPanel(
          date: logDate,
          onCanonicalRecordTap: _showCanonicalActionMenu,
        ),
      ],
    );
  }

  Widget _buildSearchResults() => ListView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      if (_isOnlineSearchOffline)
        ConsumerStatusRow(
          label: _localResults.isNotEmpty
              ? 'Showing available results'
              : 'Online search unavailable',
          detail: _localResults.isNotEmpty
              ? 'Online results are temporarily unavailable.'
              : _onlineFailureMessage ?? 'Try again or choose from Recent.',
          error: _localResults.isEmpty,
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

  Widget _buildNeutralFoodEntry() => B05Surface(
    subtle: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add food', style: B05Typography.title(context)),
        const SizedBox(height: 4),
        Text(
          'Choose a meal when you are ready to log something.',
          style: B05Typography.body(context),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _chooseMealContext,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add food'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final meal in const [
              ('breakfast', 'Breakfast'),
              ('lunch', 'Lunch'),
              ('dinner', 'Dinner'),
              ('snack', 'Snack'),
            ])
              OutlinedButton(
                onPressed: () async {
                  if (!mounted) return;
                  setState(() => _selectedMealType = meal.$1);
                  _searchFocusNode.requestFocus();
                },
                child: Text(meal.$2),
              ),
          ],
        ),
      ],
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
        hint: 'Choose a meal and amount before adding this food.',
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
    final mealType = await _ensureMealContext();
    if (mealType == null || !mounted) return;
    final result = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedRecipeLogScreen(
          mealType: mealType,
          selectedDate: widget.selectedDate,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true && widget.returnToParentOnSave) {
      Navigator.pop(context, true);
    } else if (result == true) {
      await _retryRecentFoods();
    }
  }

  Future<void> _openAi(BuildContext context) async {
    final mealType = await _ensureMealContext();
    if (mealType == null || !mounted) return;
    final navigator = Navigator.of(this.context);
    final saved = await navigator.push<bool?>(
      MaterialPageRoute(
        builder: (_) => AiMealLoggerScreen(
          mealType: mealType,
          selectedDate: widget.selectedDate,
        ),
      ),
    );
    if (saved == true && mounted) {
      if (widget.returnToParentOnSave) {
        navigator.pop(true);
      } else {
        await _retryRecentFoods();
      }
    }
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

  Future<void> _showCanonicalActionMenu(
    NutritionHistoricalReadRecord record,
  ) async {
    final item = record.items
        .where(
          (candidate) =>
              candidate.originSourceType == 'direct_food' &&
              candidate.foodId != null,
        )
        .firstOrNull;
    if (item == null || item.foodId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This logged item cannot be edited from this screen.',
            ),
          ),
        );
      }
      return;
    }
    final catalog = await ref.read(
      nutritionFoodCatalogRepositoryProvider.future,
    );
    final option = await catalog.getOption(item.foodId!);
    if (option == null || !mounted) return;
    final action = await showModalBottomSheet<_CanonicalFoodAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(B05Layout.space16),
          child: B05ActionGroup(
            children: [
              B05ActionButton(
                label: 'Edit amount',
                icon: Icons.edit_outlined,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(_CanonicalFoodAction.edit),
              ),
              B05ActionButton(
                label: 'Copy food',
                icon: Icons.copy_outlined,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(_CanonicalFoodAction.copy),
              ),
              B05ActionButton(
                label: 'Delete food',
                icon: Icons.delete_outline_rounded,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(_CanonicalFoodAction.delete),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _CanonicalFoodAction.edit:
        await _showLogDialog(
          option,
          mealType: record.mealCategory,
          initialQuantity: item.quantity.quantity ?? option.baseQuantity,
          supersedesSnapshotId: record.stableId,
        );
      case _CanonicalFoodAction.copy:
        await _showLogDialog(option, mealType: record.mealCategory);
      case _CanonicalFoodAction.delete:
        await showCanonicalFoodDelete(
          context: context,
          ref: ref,
          record: record,
        );
      case null:
        break;
    }
  }

  String _mealLabel(String? value) {
    return switch (value?.trim().toLowerCase()) {
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
        hint: 'Choose a meal and amount before adding this food.',
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
        hint: 'Choose a meal and amount before adding this food.',
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

enum _CanonicalFoodAction { edit, copy, delete }
