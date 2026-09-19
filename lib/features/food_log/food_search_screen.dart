import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/catalog/food_catalog_models.dart';
import '../../core/catalog/food_category_taxonomy.dart';
import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/typed_quantities.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_api_service.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../../data/services/nutrition_food_search_ranking.dart';
import '../dashboard/today_surface_controller.dart';
import 'barcode_scanner_screen.dart';
import 'canonical_food_delete.dart';
import 'custom_food_editor_screen.dart';
import 'diary_structure_controller.dart';
import 'food_diary_screen.dart';
import 'food_log_surface.dart';
import 'food_search_view_models.dart';
import 'meal_presentation_registry.dart';
import 'saved_meals_screen.dart';
import 'saved_recipe_log_screen.dart';
import 'widgets/food_portion_bottom_sheet.dart';
import 'widgets/food_search_widgets.dart';
import 'widgets/remote_food_review_sheet.dart';

export 'food_diary_screen.dart';
export 'food_search_view_models.dart';
export 'widgets/food_diary_widgets.dart';
export 'widgets/food_portion_bottom_sheet.dart';
export 'widgets/food_search_bar.dart';
export 'widgets/food_search_recent_list.dart';
export 'widgets/food_search_results_list.dart';
export 'widgets/food_search_widgets.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  final String? mealType; // "breakfast", "lunch", "dinner", "snack"
  final DateTime? selectedDate;
  final bool returnToParentOnSave;
  final NutritionHistoricalReadRecord? initialRecord;
  final NutritionHistoricalReadItem? initialRecordItem;
  final bool initialMultiSelect;

  const FoodSearchScreen({
    super.key,
    required this.mealType,
    this.selectedDate,
    this.returnToParentOnSave = true,
    this.initialRecord,
    this.initialRecordItem,
    this.initialMultiSelect = false,
  });

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  static const _searchDebounce = Duration(milliseconds: 300);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<FoodItem> _localResults = [];
  Map<int, FoodSearchPresentationAuthority> _localSearchAuthority = const {};
  List<NutritionFoodOption> _canonicalResults = [];
  List<FoodApiResult> _onlineResults = [];
  List<NutritionFoodSearchResult> _rankedSearchResults = [];
  List<FoodItem> _recentResults = [];
  List<CanonicalRecentFood> _canonicalRecentResults = [];
  bool _searching = false;
  bool _searchingOnline = false;
  int _searchGeneration = 0;
  bool _loadingRecent = true;
  String? _recentFailureMessage;
  Timer? _debounceTimer;
  CancelToken? _onlineSearchCancelToken;
  final Set<Timer> _recentTimeouts = {};
  bool _isOnlineSearchOffline = false;
  String? _onlineFailureMessage;
  final Set<String> _selectedKeys = {};
  final Map<String, NutritionFoodOption> _selectedOptions = {};
  final Map<String, Quantity> _selectedQuantities = {};
  final Set<String> _selectionLoading = {};
  final Set<String> _fastAddInFlight = {};
  bool _committingSelection = false;
  bool _openedInitialRecord = false;
  late bool _isMultiSelect;

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelect = !_isMultiSelect;
      if (!_isMultiSelect) {
        _selectedKeys.clear();
        _selectedOptions.clear();
        _selectedQuantities.clear();
      }
    });
  }

  String? get _activeMealType {
    final value = widget.mealType?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    return value == 'snacks' ? 'snack' : value;
  }

  @override
  void initState() {
    super.initState();
    _isMultiSelect = widget.initialMultiSelect;
    _searchController.addListener(_onSearchChanged);
    if (_activeMealType != null) _loadRecentFoods();
    if (widget.initialRecord != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_openedInitialRecord && mounted && widget.initialRecord != null) {
          _openedInitialRecord = true;
          unawaited(() async {
            await _showCanonicalActionMenu(
              widget.initialRecord!,
              widget.initialRecordItem,
            );
            if (mounted && widget.initialRecord != null) {
              Navigator.of(context).pop(true);
            }
          }());
        }
      });
    }
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
              for (final meal in ref.read(diaryMealSlotsProvider))
                ListTile(
                  leading: DecoratedBox(
                    decoration: BoxDecoration(
                      color: sheetContext.b05Colors
                          .meal(meal.accent!)
                          .container,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        meal.icon,
                        color: sheetContext.b05Colors
                            .meal(meal.accent!)
                            .indicator,
                      ),
                    ),
                  ),
                  title: Text(meal.label),
                  onTap: () => Navigator.of(sheetContext).pop(meal.stableId),
                ),
            ],
          ),
        ),
      ),
    );
    return selected;
  }

  Future<String?> _ensureMealContext() async {
    final current = _activeMealType;
    if (current != null) return current;
    return _chooseMealContext();
  }

  Future<({DateTime loggedAt, String localDate, String timezoneId})>
  _dateContext() async {
    final timezoneId = await ref
        .read(localTimezoneServiceProvider)
        .currentTimezoneId();
    final dates = ref.read(localScheduleDateServiceProvider);
    final selectedLocalDate = widget.selectedDate == null
        ? null
        : DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
    final loggedAt = selectedLocalDate == null
        ? DateTime.now().toUtc()
        : dates.instantForLocalDate(selectedLocalDate, timezoneId);
    return (
      loggedAt: loggedAt,
      localDate: selectedLocalDate ?? dates.localDateFor(loggedAt, timezoneId),
      timezoneId: timezoneId,
    );
  }

  String _selectionKeyForOption(NutritionFoodOption option) => option.id;

  bool _hasSafeDefaultServing(NutritionFoodOption option) {
    // A mass/volume base is the basis of the nutrition facts (commonly 100 g
    // or 100 mL), not a user-confirmed serving. Only an explicit serving can
    // truthfully take the one-tap path.
    return option.baseQuantity.unit == QuantityUnit.serving &&
        option.baseQuantity.context.servingDefinition != null &&
        !option.baseQuantity.isZero;
  }

  Future<void> _openMealLogger(String mealType) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          mealType: mealType,
          selectedDate: widget.selectedDate,
          returnToParentOnSave: true,
        ),
      ),
    );
    if (saved == true && mounted) await _retryRecentFoods();
  }

  Future<void> _chooseMealAndOpenLogger() async {
    final mealType = await _chooseMealContext();
    if (mealType != null && mounted) await _openMealLogger(mealType);
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
    _onlineSearchCancelToken?.cancel('Food search disposed');
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
    _onlineSearchCancelToken?.cancel('Food search query changed');
    _searchGeneration++;
    final query = _searchController.text;
    // Rows belong to the query that produced them. Remove them immediately so
    // an old result cannot be selected while the replacement query is waiting
    // for its debounce interval.
    setState(() {
      _localResults = [];
      _localSearchAuthority = const {};
      _canonicalResults = [];
      _onlineResults = [];
      _rankedSearchResults = [];
      _searching = query.trim().isNotEmpty;
      _searchingOnline = false;
      _isOnlineSearchOffline = false;
      _onlineFailureMessage = null;
    });
    if (query.trim().isEmpty) return;
    _debounceTimer = Timer(_searchDebounce, () {
      _performSearch(query);
    });
  }

  void _rebuildSearchRanking(String query) {
    final candidates = <NutritionFoodSearchCandidate>[
      for (final food in _localResults)
        NutritionFoodSearchCandidate.legacy(
          food,
          canonicalIdentityId: _localSearchAuthority[food.id]?.canonicalFoodId,
          presentationKind: _localSearchAuthority[food.id]?.kind,
          variantOfFoodId: _localSearchAuthority[food.id]?.variantOfFoodId,
        ),
      for (final option in _canonicalResults)
        NutritionFoodSearchCandidate.canonical(option),
      for (final food in _onlineResults)
        NutritionFoodSearchCandidate.remote(food),
    ];
    _rankedSearchResults = NutritionFoodSearchRanking.rank(
      query: query,
      candidates: candidates,
      history: _searchHistory(),
    );
  }

  NutritionFoodSearchHistory _searchHistory() {
    final frequencyByIdentity = <String, int>{};
    final recentIdentities = <String>{};
    for (final recent in _canonicalRecentResults) {
      final identity = 'canonical::${recent.option.id}';
      frequencyByIdentity[identity] = recent.frequencyCount;
      recentIdentities.add(identity);
    }
    for (final food in _recentResults) {
      final identity = 'canonical::legacy-food-item::${food.id}';
      frequencyByIdentity[identity] = 1;
      recentIdentities.add(identity);
    }
    return NutritionFoodSearchHistory(
      frequencyByIdentity: frequencyByIdentity,
      recentIdentities: recentIdentities,
    );
  }

  Future<List<FoodItem>> _loadLocalSearchResults(String query) async {
    final repository = ref.read(foodRepositoryProvider);
    final byId = <int, FoodItem>{};
    final normalized = NutritionFoodSearchVocabulary.normalize(query);
    final variants = NutritionFoodSearchVocabulary.expand(query);
    for (final variant in variants) {
      try {
        for (final item in await repository.searchFoodLocal(variant)) {
          byId[item.id] = item;
        }
      } catch (_) {
        // A single retrieval-vocabulary expansion must not block the others.
      }
    }
    if (normalized.length >= 4) {
      final firstToken = normalized.split(' ').first;
      if (firstToken.length >= 3) {
        final prefix = firstToken.substring(0, 3);
        try {
          for (final item in await repository.searchFoodLocal(prefix)) {
            byId[item.id] = item;
          }
        } catch (_) {
          // The provider path remains available if prefix retrieval fails.
        }
      }
    }
    return byId.values.toList(growable: false);
  }

  Future<void> _loadLocalSearchAuthority({
    required List<FoodItem> foods,
    required String query,
    required int generation,
  }) async {
    final repository = ref.read(foodRepositoryProvider);
    Map<int, FoodSearchPresentationAuthority> authority = const {};
    try {
      authority = await repository.readSearchPresentationAuthority(
        foods.map((food) => food.id),
      );
    } catch (_) {
      // Presentation metadata must fail open; identities remain independent.
    }
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _localSearchAuthority = authority;
      _rebuildSearchRanking(query);
    });
  }

  Future<void> _performSearch(String text) async {
    if (!mounted) return;
    final query = text.trim();
    final generation = ++_searchGeneration;
    _onlineSearchCancelToken?.cancel('New food search started');
    if (query.isEmpty) {
      _onlineSearchCancelToken = null;
      setState(() {
        _localResults = [];
        _localSearchAuthority = const {};
        _canonicalResults = [];
        _onlineResults = [];
        _searching = false;
        _searchingOnline = false;
        _isOnlineSearchOffline = false;
        _onlineFailureMessage = null;
      });
      return;
    }
    final cancelToken = CancelToken();
    _onlineSearchCancelToken = cancelToken;

    setState(() {
      _searching = true;
      _searchingOnline = false;
      _isOnlineSearchOffline = false;
      _onlineFailureMessage = null;
      _onlineResults = [];
      _rankedSearchResults = [];
    });
    unawaited(_loadCustomSearchResults(query, generation));

    final local = await _loadLocalSearchResults(query);
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _localResults = local;
      _localSearchAuthority = const {};
      _rebuildSearchRanking(query);
      _searching = false;
      _searchingOnline = true;
    });
    unawaited(
      _loadLocalSearchAuthority(
        foods: local,
        query: query,
        generation: generation,
      ),
    );

    try {
      final online = await ref
          .read(foodApiServiceProvider)
          .searchOnline(query, cancelToken: cancelToken);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _onlineResults = online;
        _rebuildSearchRanking(query);
        _isOnlineSearchOffline = false;
        _onlineFailureMessage = null;
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      if (error is DioException && CancelToken.isCancel(error)) return;
      final offlinePolicy = error is StateError;
      setState(() {
        _onlineResults = [];
        _rebuildSearchRanking(query);
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
      if (identical(_onlineSearchCancelToken, cancelToken)) {
        _onlineSearchCancelToken = null;
      }
    }
  }

  Future<void> _loadCustomSearchResults(String query, int generation) async {
    try {
      final catalog = await ref.read(
        nutritionFoodCatalogRepositoryProvider.future,
      );
      final canonical = await catalog.searchCustomFoods(
        queries: NutritionFoodSearchVocabulary.expand(query),
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _canonicalResults = canonical;
        _rebuildSearchRanking(query);
      });
    } catch (_) {
      // The legacy/local compatibility search remains usable on its own.
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
        'Online food search is unavailable. Check your connection.',
      DioExceptionType.badResponse =>
        'Online food search is unavailable right now.',
      DioExceptionType.badCertificate =>
        'A secure connection to online food search could not be established.',
      DioExceptionType.cancel => 'Online food search was cancelled.',
    };
  }

  String? _providerReference(FoodApiResult result) =>
      NutritionFoodProviderIdentity.sourceReference(result);

  void _showUnavailableProviderFoodMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This result is unavailable for logging. Try another match.',
        ),
      ),
    );
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

  Future<void> _openLegacyFastAdd(FoodItem food) async {
    try {
      final catalog = await ref.read(
        nutritionFoodCatalogRepositoryProvider.future,
      );
      await _addOptionFast(await catalog.ensureLegacyFood(food));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This food is unavailable. Try again.')),
        );
      }
    }
  }

  Future<void> _openProviderLogDialog(FoodApiResult result) async {
    try {
      final reference = _providerReference(result);
      if (reference == null) {
        _showUnavailableProviderFoodMessage();
        return;
      }
      // Never fabricate 0.0 for missing provider nutrients: incomplete results
      // go to custom entry instead of a review sheet with invented values.
      if (!result.hasCompleteMacros) {
        _showUnavailableProviderFoodMessage();
        return;
      }

      final resolvedCategory = FoodCategoryTaxonomy.resolveCategoryId(
        name: result.name,
      );
      final isStuffed = isStuffedParathaName(result.name);
      final servingOptions = FoodCategoryTaxonomy.servingOptionsForCategory(
        categoryId: resolvedCategory,
        servingSize: result.servingSize > 0 ? result.servingSize : 100.0,
        servingUnit: result.servingUnit.isNotEmpty ? result.servingUnit : 'g',
        isStuffedParatha: isStuffed,
      );

      final candidate = RemoteFoodCandidate(
        id: 'off_${result.barcode ?? result.providerId ?? result.name}',
        provider: FoodCatalogProvider.openFoodFacts,
        providerId: result.barcode ?? result.providerId,
        name: _consumerFoodName(result.name),
        brand: _consumerMetadata(result.brand),
        barcode: result.barcode,
        category: resolvedCategory,
        caloriesPer100g: result.calories!,
        proteinPer100g: result.protein!,
        carbsPer100g: result.carbs!,
        fatPer100g: result.fat!,
        fiberPer100g: result.fiber,
        sodiumMgPer100g: result.sodium,
        addedSugarPer100g: result.addedSugar,
        saturatedFatPer100g: result.saturatedFat,
        servingOptions: servingOptions,
        provenance: FoodProvenance(
          provider: FoodCatalogProvider.openFoodFacts,
          attributionText: 'Source: Open Food Facts (ODbL)',
          license: 'ODbL',
          sourceUrl: result.barcode != null ? 'https://world.openfoodfacts.org/product/${result.barcode}' : null,
          fetchedAtUtc: DateTime.now().toUtc(),
        ),
      );

      await RemoteFoodReviewSheet.show(
        context: context,
        candidate: candidate,
        mealType: widget.mealType ?? 'snack',
        selectedDate: widget.selectedDate ?? DateTime.now(),
        onConfirm: ({
          required RemoteFoodCandidate candidate,
          required double quantity,
          required ServingOption servingOption,
          required bool logImmediately,
        }) async {
          final catalog = await ref.read(
            nutritionFoodCatalogRepositoryProvider.future,
          );
          final option = await catalog.ensureProviderFood(
            displayName: candidate.name,
            sourceReference: reference,
            servingSize: servingOption.gramWeight,
            servingUnit: servingOption.unitName,
            energyKcal: candidate.caloriesPer100g,
            proteinG: candidate.proteinPer100g,
            carbohydrateG: candidate.carbsPer100g,
            fatG: candidate.fatPer100g,
            fiberG: candidate.fiberPer100g,
            sodiumMg: candidate.sodiumMgPer100g,
            addedSugarG: candidate.addedSugarPer100g,
            saturatedFatG: candidate.saturatedFatPer100g,
            brand: candidate.brand,
          );

          if (logImmediately) {
            // Preserve the reviewed portion: the option basis is per-100
            // units, so scale it by the reviewed servings. Without this the
            // dialog resets to a single serving and silently drops the
            // reviewed amount the user just confirmed.
            Quantity? reviewedQuantity;
            final factor = quantity * servingOption.gramWeight / 100;
            if (factor.isFinite && factor > 0) {
              reviewedQuantity = option.baseQuantity * factor;
            }
            await _showLogDialog(
              option,
              initialQuantity: reviewedQuantity,
            );
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${candidate.name} saved to My Foods')),
              );
            }
          }
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This food is unavailable. Try again.')),
        );
      }
    }
  }

  Future<void> _openProviderFastAdd(FoodApiResult result) async {
    // Provider results must pass through explicit review: route the one-tap
    // affordance to the review sheet instead of direct finalize so unverified
    // macros are never silently promoted.
    await _openProviderLogDialog(result);
  }

  Future<void> _addOptionFast(NutritionFoodOption option) async {
    // UI taps generate distinct command IDs. Guard before the first await so
    // a physical double tap cannot turn into two valid canonical commands.
    if (!_fastAddInFlight.add(option.id)) return;
    if (mounted) setState(() {});
    try {
      final selectedMealType = await _ensureMealContext();
      if (selectedMealType == null || !mounted) return;
      if (!_hasSafeDefaultServing(option)) {
        await _showLogDialog(option, mealType: selectedMealType);
        return;
      }
      final coordinator = await ref.read(
        nutritionFoodLoggingCoordinatorProvider.future,
      );
      final preview = await coordinator.preview(
        option: option,
        quantity: option.baseQuantity,
      );
      final dateContext = await _dateContext();
      final snapshot = await coordinator.finalize(
        userId: kLocalNutritionUserScopeId,
        preview: preview,
        mealCategory: selectedMealType,
        loggedAt: dateContext.loggedAt,
        localDate: dateContext.localDate,
        timezoneId: dateContext.timezoneId,
        commandId: 'direct-food-command::${const Uuid().v4()}',
        consumptionId: 'direct-food-consumption::${const Uuid().v4()}',
      );
      if (!mounted) return;
      _invalidateNutritionReads();
      final undo = FoodAddUndoToken(
        snapshotId: snapshot.id,
        localDate: dateContext.localDate,
        mealCategory: selectedMealType,
      );
      showIndiFitUndoFeedback(
        context,
        message:
            'Added ${option.displayName} to ${_mealLabel(selectedMealType)}',
        duration: const Duration(seconds: 4),
        onUndo: () => unawaited(_undoLastCanonicalAdd(undo)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Food could not be added. Try again.'),
          ),
        );
      }
    } finally {
      if (_fastAddInFlight.remove(option.id) && mounted) setState(() {});
    }
  }

  bool _isSafeRepeatQuantity(NutritionFoodOption option, Quantity? quantity) {
    if (quantity == null || quantity.isZero) {
      return false;
    }
    if (quantity.unit == option.baseQuantity.unit) {
      if (quantity.unit == QuantityUnit.serving) {
        return quantity.context.servingDefinition != null ||
            option.baseQuantity.context.servingDefinition != null;
      }
      return true;
    }
    if (quantity.dimension == option.baseQuantity.dimension &&
        quantity.dimension != QuantityDimension.unknown &&
        quantity.dimension != QuantityDimension.legacy) {
      return true;
    }
    return false;
  }

  Future<void> _addRecentFast(CanonicalRecentFood recent) async {
    final option = recent.option;
    if (!_fastAddInFlight.add(option.id)) return;
    if (mounted) setState(() {});
    try {
      final selectedMealType = await _ensureMealContext();
      if (selectedMealType == null || !mounted) return;
      final quantity = recent.historicalQuantity;
      if (quantity == null || !_isSafeRepeatQuantity(option, quantity)) {
        await _showLogDialog(
          option,
          mealType: selectedMealType,
          initialQuantity: quantity,
        );
        return;
      }
      final coordinator = await ref.read(
        nutritionFoodLoggingCoordinatorProvider.future,
      );
      final preview = await coordinator.preview(
        option: option,
        quantity: quantity,
      );
      final dateContext = await _dateContext();
      final snapshot = await coordinator.finalize(
        userId: kLocalNutritionUserScopeId,
        preview: preview,
        mealCategory: selectedMealType,
        loggedAt: dateContext.loggedAt,
        localDate: dateContext.localDate,
        timezoneId: dateContext.timezoneId,
        commandId: 'direct-food-command::${const Uuid().v4()}',
        consumptionId: 'direct-food-consumption::${const Uuid().v4()}',
      );
      if (!mounted) return;
      _invalidateNutritionReads();
      final undo = FoodAddUndoToken(
        snapshotId: snapshot.id,
        localDate: dateContext.localDate,
        mealCategory: selectedMealType,
      );
      showIndiFitUndoFeedback(
        context,
        message:
            'Added ${option.displayName} to ${_mealLabel(selectedMealType)}',
        duration: const Duration(seconds: 4),
        onUndo: () => unawaited(_undoLastCanonicalAdd(undo)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Food could not be added. Try again.'),
          ),
        );
      }
    } finally {
      if (_fastAddInFlight.remove(option.id) && mounted) setState(() {});
    }
  }

  Future<void> _undoLastCanonicalAdd(FoodAddUndoToken undo) async {
    try {
      final repository = await ref.read(
        nutritionConsumptionRepositoryProvider.future,
      );
      await repository.retractConsumption(
        userId: kLocalNutritionUserScopeId,
        snapshotId: undo.snapshotId,
        expectedLocalDate: undo.localDate,
        expectedMealCategory: undo.mealCategory,
        commandId: 'food-undo-command::${undo.snapshotId}',
      );
      if (!mounted) return;
      _invalidateNutritionReads();
      showIndiFitSuccessFeedback(
        context,
        'Food removed. Your totals are up to date.',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Undo is no longer available. Refresh to check the meal.',
            ),
          ),
        );
      }
    }
  }

  void _invalidateNutritionReads() {
    ref.read(todayNutritionRevisionProvider.notifier).state++;
    ref.invalidate(b04ProductionRecommendationContextProvider);
    ref.invalidate(b04CurrentFoodControllerProvider);
    ref.invalidate(canonicalRecentFoodsProvider);
  }

  Future<void> _showLogDialog(
    NutritionFoodOption option, {
    String? mealType,
    Quantity? initialQuantity,
    NutritionHistoricalReadRecord? correctionRecord,
    NutritionHistoricalReadItem? correctionItem,
    Future<void> Function(Quantity quantity)? onQuantityPicked,
  }) async {
    final categoryId = FoodCategoryTaxonomy.resolveCategoryId(
      name: option.displayName,
    );
    final categoryServingOptions = FoodCategoryTaxonomy.servingOptionsForCategory(
      categoryId: categoryId,
      servingSize: option.baseQuantity.amount.asDouble,
      servingUnit: option.servingUnitLabel ?? option.baseQuantity.unit.toString().split('.').last,
      isStuffedParatha: isStuffedParathaName(option.displayName),
    );

    await FoodPortionBottomSheet.show(
      context,
      ref: ref,
      option: option,
      mealType: mealType,
      initialQuantity: initialQuantity,
      targetDate: widget.selectedDate,
      correctionRecord: correctionRecord,
      correctionItem: correctionItem,
      onQuantityPicked: onQuantityPicked,
      ensureMealContext: _ensureMealContext,
      returnToParentOnSave: widget.returnToParentOnSave,
      onRetryRecentFoods: _retryRecentFoods,
      categoryId: categoryId,
      categoryServingOptions: categoryServingOptions,
    );
  }

  void _toggleCanonicalSelection(
    NutritionFoodOption option, {
    Quantity? initialQuantity,
  }) {
    final key = _selectionKeyForOption(option);
    setState(() {
      if (_selectedKeys.remove(key)) {
        _selectedOptions.remove(key);
        _selectedQuantities.remove(key);
      } else {
        _selectedKeys.add(key);
        _selectedOptions[key] = option;
        _selectedQuantities[key] = initialQuantity ?? option.baseQuantity;
      }
    });
  }

  Future<void> _toggleLegacySelection(FoodItem food) async {
    final key = 'legacy-food:${food.id}';
    if (_selectionLoading.contains(key)) return;
    final selectedOption = _selectedOptions.entries
        .where(
          (entry) =>
              entry.value.sourceReference == 'legacy-food-item:${food.id}',
        )
        .firstOrNull;
    if (selectedOption != null) {
      setState(() {
        _selectedKeys.remove(selectedOption.key);
        _selectedOptions.remove(selectedOption.key);
        _selectedQuantities.remove(selectedOption.key);
      });
      return;
    }
    setState(() => _selectionLoading.add(key));
    try {
      final catalog = await ref.read(
        nutritionFoodCatalogRepositoryProvider.future,
      );
      final option = await catalog.ensureLegacyFood(food);
      if (!mounted) return;
      setState(() {
        _selectionLoading.remove(key);
        _selectedKeys.add(option.id);
        _selectedOptions[option.id] = option;
        _selectedQuantities[option.id] = option.baseQuantity;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _selectionLoading.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This food cannot be selected right now.'),
          ),
        );
      }
    }
  }

  Future<void> _editSelectedQuantity(NutritionFoodOption option) async {
    final key = option.id;
    final current = _selectedQuantities[key] ?? option.baseQuantity;
    await _showLogDialog(
      option,
      mealType: _activeMealType,
      initialQuantity: current,
      onQuantityPicked: (quantity) async {
        if (!mounted) return;
        setState(() => _selectedQuantities[key] = quantity);
      },
    );
  }

  Future<void> _commitSelection() async {
    if (_committingSelection || _selectedOptions.isEmpty) return;
    setState(() => _committingSelection = true);
    try {
      // This must happen before choosing a meal: two taps while that sheet is
      // opening would otherwise create two separate atomic batches.
      final mealType = await _ensureMealContext();
      if (mealType == null || !mounted) return;
      final coordinator = await ref.read(
        nutritionFoodLoggingCoordinatorProvider.future,
      );
      final selected = _selectedOptions.values.toList(growable: false);
      final previews = await Future.wait(
        selected.map(
          (option) => coordinator.preview(
            option: option,
            quantity: _selectedQuantities[option.id] ?? option.baseQuantity,
          ),
        ),
      );
      final dateContext = await _dateContext();
      final snapshot = await coordinator.finalizeBatch(
        userId: kLocalNutritionUserScopeId,
        previews: previews,
        mealCategory: mealType,
        loggedAt: dateContext.loggedAt,
        localDate: dateContext.localDate,
        timezoneId: dateContext.timezoneId,
        commandId: 'direct-food-batch-command::${const Uuid().v4()}',
        consumptionId: 'direct-food-batch-consumption::${const Uuid().v4()}',
      );
      if (!mounted) return;
      setState(() {
        _selectedKeys.clear();
        _selectedOptions.clear();
        _selectedQuantities.clear();
        _isMultiSelect = false;
      });
      _invalidateNutritionReads();
      final undo = FoodAddUndoToken(
        snapshotId: snapshot.id,
        localDate: dateContext.localDate,
        mealCategory: mealType,
      );
      showIndiFitUndoFeedback(
        context,
        message: '${selected.length} foods added to ${_mealLabel(mealType)}',
        duration: const Duration(seconds: 4),
        onUndo: () => unawaited(_undoLastCanonicalAdd(undo)),
      );
      if (widget.returnToParentOnSave && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Foods could not be added together. Your selection is still here.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _committingSelection = false);
    }
  }

  String _selectionEnergyLabel() {
    if (_selectedOptions.isEmpty) return '—';
    var total = 0.0;
    for (final option in _selectedOptions.values) {
      final quantity = _selectedQuantities[option.id] ?? option.baseQuantity;
      final fact = option.facts['energy'];
      if (fact == null || !fact.isAvailable || fact.point == null) return '—';
      try {
        final scaled = fact.scaleBy(quantity);
        if (scaled.point == null) return '—';
        total += scaled.point!.value.asDouble;
      } on NutrientError {
        return '—';
      } on QuantityError {
        return '—';
      }
    }
    return '${total.round()} kcal';
  }

  Widget _buildSelectionBar() {
    final mealType = _activeMealType;
    return SafeArea(
      top: false,
      child: B05Surface(
        radius: B05SurfaceRadius.small,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                final selectionLabel =
                    '${_selectedOptions.length} food${_selectedOptions.length == 1 ? '' : 's'} selected · ${_selectionEnergyLabel()}';
                final clear = TextButton(
                  onPressed: () => setState(() {
                    _selectedKeys.clear();
                    _selectedOptions.clear();
                    _selectedQuantities.clear();
                  }),
                  child: const Text('Clear'),
                );
                if (constraints.maxWidth < 360 || textScale > 1.3) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selectionLabel, style: B05Typography.label(context)),
                      Align(alignment: Alignment.centerRight, child: clear),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectionLabel,
                        style: B05Typography.label(context),
                      ),
                    ),
                    clear,
                  ],
                );
              },
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final option in _selectedOptions.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            '${option.displayName} (${_quantityUnitLabel(_selectedQuantities[option.id] ?? option.baseQuantity, option: option)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onPressed: () =>
                            unawaited(_editSelectedQuantity(option)),
                        onDeleted: () => setState(() {
                          _selectedOptions.remove(option.id);
                          _selectedQuantities.remove(option.id);
                          _selectedKeys.remove(option.id);
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _committingSelection ? null : _commitSelection,
                child: Text(
                  _committingSelection
                      ? 'Adding…'
                      : ConsumerCopy.addFoodsToMeal(
                          count: _selectedOptions.length,
                          meal: _mealLabel(mealType),
                        ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final logDate = widget.selectedDate ?? DateTime.now();
    final dateStr = ConsumerDateLabel.dateTime(logDate);
    final mealType = _activeMealType;

    if (mealType == null) {
      return FoodDiaryScreen(selectedDate: logDate);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isMultiSelect
                  ? 'Select ${_mealLabel(mealType)} foods'
                  : 'Log ${_mealLabel(mealType)}',
              style: B05Typography.title(context),
            ),
            Text(
              _isMultiSelect
                  ? '${_selectedOptions.length} selected · $dateStr'
                  : dateStr,
              style: B05Typography.caption(context),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('toggle_multiselect_mode'),
            icon: Icon(
              _isMultiSelect
                  ? Icons.checklist_rtl_rounded
                  : Icons.checklist_rounded,
              color: _isMultiSelect ? context.b05Colors.action : null,
            ),
            tooltip: _isMultiSelect ? 'Exit multi-select' : 'Select multiple',
            onPressed: _toggleMultiSelectMode,
          ),
          _buildMoreMenu(context),
        ],
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
                  'Add to ${_mealTitle(mealType)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Add ${_mealLabel(mealType)}',
                  style: B05Typography.caption(context),
                ),
                const SizedBox(height: 14),
                FoodSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: widget.mealType != null,
                  onClear: () => _searchController.clear(),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _searching
                      ? const SkeletonList(count: 6)
                      : _searchController.text.isEmpty
                      ? _buildLandingState(logDate)
                      : _buildSearchResults(),
                ),
                if (_selectedOptions.isNotEmpty) _buildSelectionBar(),
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

  Widget _buildLandingState(DateTime logDate) => FoodSearchRecentList(
        neutralFoodEntry:
            _activeMealType == null ? _buildNeutralFoodEntry() : null,
        loadingRecent: _loadingRecent,
        recentFailureMessage: _recentFailureMessage,
        onRetryRecent: _retryRecentFoods,
        canonicalRecentResults: _canonicalRecentResults,
        recentResults: _recentResults,
        canonicalRecentItemBuilder: (context, recent) =>
            _buildCanonicalRecentItemRow(recent),
        recentItemBuilder: (context, food) => _buildRecentItemRow(food),
        onOpenSavedMeals: _openSavedMeals,
        onOpenSavedRecipes: _openSavedRecipes,
        onOpenBarcode: () => _openBarcode(context),
        onScanNutritionLabel: () {
          final mealParam =
              widget.mealType != null ? '?mealType=${widget.mealType}' : '';
          final dateParam = widget.selectedDate != null
              ? (mealParam.isEmpty
                  ? '?date=${widget.selectedDate!.toIso8601String().split('T').first}'
                  : '&date=${widget.selectedDate!.toIso8601String().split('T').first}')
              : '';
          context.push('/food/label-ocr$mealParam$dateParam');
        },
        onDescribeMeal: () {
          final mealParam =
              widget.mealType != null ? '?mealType=${widget.mealType}' : '';
          final dateParam = widget.selectedDate != null
              ? (mealParam.isEmpty
                  ? '?date=${widget.selectedDate!.toIso8601String().split('T').first}'
                  : '&date=${widget.selectedDate!.toIso8601String().split('T').first}')
              : '';
          context.push('/food/describe$mealParam$dateParam');
        },
        entriesPanel: FoodLogEntriesPanel(
          date: logDate,
          onCanonicalRecordTap: _showCanonicalActionMenu,
          onCanonicalItemTap: _showCanonicalActionMenu,
        ),
      );

  Widget _buildSearchResults() => FoodSearchResultsList(
        isOnlineSearchOffline: _isOnlineSearchOffline,
        searchingOnline: _searchingOnline,
        onlineFailureMessage: _onlineFailureMessage,
        onRetrySearch: () => _performSearch(_searchController.text),
        searchResults: _rankedSearchResults,
        searchResultItemBuilder: (context, result) =>
            _buildRankedSearchRow(result),
        onCreateCustomFood: () async {
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
      );

  Widget _buildRankedSearchRow(NutritionFoodSearchResult result) {
    final candidate = result.candidate;
    return switch (candidate.source) {
      NutritionFoodSearchSource.legacy => _buildLocalItemRow(candidate.food!),
      NutritionFoodSearchSource.canonical => _buildCanonicalSearchRow(
        candidate.option!,
      ),
      NutritionFoodSearchSource.remote => _buildOnlineItemRow(
        candidate.remote!,
      ),
    };
  }

  Widget _buildNeutralFoodEntry() => B05Surface(
    subtle: true,
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add food', style: B05Typography.title(context)),
        const SizedBox(height: 4),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _chooseMealAndOpenLogger,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add food'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final meal in ref.watch(diaryMealSlotsProvider))
              OutlinedButton(
                onPressed: () => _openMealLogger(meal.stableId),
                child: Text(meal.label),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _buildRecentItemRow(FoodItem food) =>
      _buildLocalItemRow(food, recent: true);

  Widget _buildCanonicalSearchRow(NutritionFoodOption option) {
    final displayName = _consumerFoodName(option.displayName);
    final brand = _consumerBrand(option.brand, displayName);
    final nutrition = _canonicalNutritionSummary(option);
    final isCustom =
        option.sourceType == 'user' || option.sourceType == 'user_entered';
    final identityLabel = brand == null || brand.isEmpty
        ? displayName
        : '$brand $displayName';
    final isSelected = _selectedOptions.containsKey(option.id);
    final title = brand == null || brand.isEmpty
        ? Text(displayName, maxLines: 2, overflow: TextOverflow.ellipsis)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                brand,
                style: B05Typography.caption(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label: '$identityLabel${isCustom ? ', custom food' : ''}, $nutrition',
        hint: _isMultiSelect
            ? (isSelected
                  ? 'Tap to deselect from multi-food add.'
                  : 'Tap to select for multi-food add.')
            : 'Tap Add to log the listed serving, or open to adjust the amount.',
        child: ListTile(
          minVerticalPadding: 8,
          leading: _isMultiSelect
              ? Semantics(
                  label: 'Select $displayName for a multi-food add',
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleCanonicalSelection(option),
                  ),
                )
              : null,
          title: Row(
            children: [
              Expanded(child: title),
              if (isCustom)
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
            nutrition,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _isMultiSelect
              ? (isSelected
                    ? IconButton(
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        tooltip: 'Adjust portion for $displayName',
                        onPressed: () =>
                            unawaited(_editSelectedQuantity(option)),
                      )
                    : null)
              : _buildCanonicalFastAddAction(option),
          onTap: () {
            if (_isMultiSelect) {
              _toggleCanonicalSelection(option);
            } else {
              unawaited(_showLogDialog(option));
            }
          },
        ),
      ),
    );
  }

  Widget _buildCanonicalRecentItemRow(CanonicalRecentFood recent) {
    final option = recent.option;
    final displayName = _consumerFoodName(option.displayName);
    final brand = _consumerBrand(option.brand, displayName);
    final nutrition = _canonicalNutritionSummary(option);
    final quantity = _consumerMetadata(recent.quantityLabel) ?? 'Serving';
    final identityLabel = brand == null || brand.isEmpty
        ? displayName
        : '$brand $displayName';
    final isSelected = _selectedOptions.containsKey(option.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label: '$identityLabel, $quantity, $nutrition',
        hint: _isMultiSelect
            ? (isSelected
                  ? 'Tap to deselect from multi-food add.'
                  : 'Tap to select for multi-food add.')
            : 'Tap Add to log $quantity, or open to adjust the amount.',
        child: ListTile(
          minVerticalPadding: 10,
          leading: _isMultiSelect
              ? Semantics(
                  label: 'Select $displayName for a multi-food add',
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleCanonicalSelection(
                      option,
                      initialQuantity: recent.historicalQuantity,
                    ),
                  ),
                )
              : null,
          title: brand == null || brand.isEmpty
              ? Text(
                  displayName,
                  style: B05Typography.label(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: B05Typography.label(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      brand,
                      style: B05Typography.caption(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
          subtitle: Text(
            '$quantity · ${_lastLoggedLabel(recent.loggedAtUtc)}${recent.frequencyCount > 1 ? ' · ${recent.frequencyCount} logged' : ''} · $nutrition',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _isMultiSelect
              ? (isSelected
                    ? IconButton(
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        tooltip: 'Adjust portion for $displayName',
                        onPressed: () =>
                            unawaited(_editSelectedQuantity(option)),
                      )
                    : null)
              : _buildCanonicalRecentFastAddAction(recent),
          onTap: () {
            if (_isMultiSelect) {
              _toggleCanonicalSelection(
                option,
                initialQuantity: recent.historicalQuantity,
              );
            } else {
              unawaited(
                _showLogDialog(
                  option,
                  initialQuantity: recent.historicalQuantity,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildCanonicalRecentFastAddAction(CanonicalRecentFood recent) {
    final option = recent.option;
    final isAdding = _fastAddInFlight.contains(option.id);
    return _buildFastAddAction(
      foodName: _consumerFoodName(option.displayName),
      isAdding: isAdding,
      onPressed: isAdding ? null : () => unawaited(_addRecentFast(recent)),
    );
  }

  Widget _buildCanonicalFastAddAction(NutritionFoodOption option) {
    final isAdding = _fastAddInFlight.contains(option.id);
    return _buildFastAddAction(
      foodName: _consumerFoodName(option.displayName),
      isAdding: isAdding,
      onPressed: isAdding ? null : () => unawaited(_addOptionFast(option)),
    );
  }

  Widget _buildFastAddAction({
    required String foodName,
    required VoidCallback? onPressed,
    bool isAdding = false,
    bool unavailable = false,
  }) {
    final label = unavailable
        ? '$foodName unavailable for logging'
        : isAdding
        ? 'Adding $foodName'
        : 'Add $foodName';
    // A disabled nested button must still consume its own hit area. Otherwise
    // a second physical tap falls through to the result-row tap target and
    // unexpectedly opens the quantity sheet.
    return AbsorbPointer(
      absorbing: onPressed == null,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: TextButton.icon(
            onPressed: onPressed,
            icon: Icon(
              isAdding ? Icons.hourglass_top_rounded : Icons.add_rounded,
              size: 18,
            ),
            label: Text(
              unavailable
                  ? 'Unavailable'
                  : isAdding
                  ? 'Adding…'
                  : 'Add',
            ),
          ),
        ),
      ),
    );
  }

  String _lastLoggedLabel(DateTime timestamp) {
    final days = DateTime.now().difference(timestamp.toLocal()).inDays;
    return days <= 0
        ? 'last logged today'
        : days == 1
        ? 'last logged yesterday'
        : 'last logged $days days ago';
  }

  Future<void> _openSavedMeals() async {
    final mealType = await _ensureMealContext();
    if (mealType == null || !mounted) return;
    final result = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedMealsScreen(
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

  void _openBarcode(BuildContext context) {
    _showBarcodePermissionRationale(context, () async {
      final result = await Navigator.push<Object?>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );
      if (!mounted) return;
      if (result is RemoteFoodCandidate) {
        unawaited(_openCandidateReview(result));
      } else if (result is FoodApiResult) {
        unawaited(_openProviderLogDialog(result));
      } else if (result is NutritionFoodOption) {
        // Rescan hit on a user-created food carrying this barcode.
        unawaited(_showLogDialog(result));
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

  Future<void> _openCandidateReview(RemoteFoodCandidate candidate) async {
    try {
      final resolvedCategory = candidate.category.isNotEmpty && candidate.category != 'general'
          ? candidate.category
          : FoodCategoryTaxonomy.resolveCategoryId(name: candidate.name);
      final effectiveCandidate = candidate.servingOptions.isNotEmpty
          ? (candidate.category != resolvedCategory ? candidate.copyWith(category: resolvedCategory) : candidate)
          : candidate.copyWith(
              category: resolvedCategory,
              servingOptions: FoodCategoryTaxonomy.servingOptionsForCategory(
                categoryId: resolvedCategory,
                isStuffedParatha: isStuffedParathaName(candidate.name),
              ),
            );

      final reference = effectiveCandidate.barcode != null && effectiveCandidate.barcode!.isNotEmpty
          ? 'open-food-facts:barcode:${effectiveCandidate.barcode}'
          : 'open-food-facts:product:${effectiveCandidate.providerId}';

      await RemoteFoodReviewSheet.show(
        context: context,
        candidate: effectiveCandidate,
        mealType: widget.mealType ?? 'snack',
        selectedDate: widget.selectedDate ?? DateTime.now(),
        onConfirm: ({
          required RemoteFoodCandidate candidate,
          required double quantity,
          required ServingOption servingOption,
          required bool logImmediately,
        }) async {
          final catalog = await ref.read(
            nutritionFoodCatalogRepositoryProvider.future,
          );
          final option = await catalog.ensureProviderFood(
            displayName: candidate.name,
            sourceReference: reference,
            servingSize: servingOption.gramWeight,
            servingUnit: servingOption.unitName,
            energyKcal: candidate.caloriesPer100g,
            proteinG: candidate.proteinPer100g,
            carbohydrateG: candidate.carbsPer100g,
            fatG: candidate.fatPer100g,
            fiberG: candidate.fiberPer100g,
            sodiumMg: candidate.sodiumMgPer100g,
            addedSugarG: candidate.addedSugarPer100g,
            saturatedFatG: candidate.saturatedFatPer100g,
            brand: candidate.brand,
          );

          if (logImmediately) {
            // Preserve the reviewed portion (see search-flow onConfirm):
            // without this the dialog resets to a single serving.
            Quantity? reviewedQuantity;
            final factor = quantity * servingOption.gramWeight / 100;
            if (factor.isFinite && factor > 0) {
              reviewedQuantity = option.baseQuantity * factor;
            }
            await _showLogDialog(
              option,
              initialQuantity: reviewedQuantity,
            );
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${candidate.name} saved to My Foods')),
              );
            }
          }
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This food is unavailable. Try again.')),
        );
      }
    }
  }

  Future<void> _showCanonicalActionMenu(
    NutritionHistoricalReadRecord record, [
    NutritionHistoricalReadItem? selectedItem,
  ]) async {
    final item =
        selectedItem ??
        record.items
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
    final action = await showModalBottomSheet<CanonicalFoodAction>(
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
                    Navigator.of(sheetContext).pop(CanonicalFoodAction.edit),
              ),
              B05ActionButton(
                label: 'Copy food',
                icon: Icons.copy_outlined,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(CanonicalFoodAction.copy),
              ),
              B05ActionButton(
                label: 'Delete food',
                icon: Icons.delete_outline_rounded,
                emphasis: B05ActionEmphasis.danger,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(CanonicalFoodAction.delete),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case CanonicalFoodAction.edit:
        await _showLogDialog(
          option,
          mealType: record.mealCategory,
          initialQuantity: item.quantity.quantity ?? option.baseQuantity,
          correctionRecord: record,
          correctionItem: item,
        );
      case CanonicalFoodAction.copy:
        await _showLogDialog(option, mealType: record.mealCategory);
      case CanonicalFoodAction.delete:
        await showCanonicalFoodItemDelete(
          context: context,
          ref: ref,
          record: record,
          item: item,
        );
      case null:
        break;
    }
  }

  String _mealLabel(String? value) {
    if (value == null || value.trim().isEmpty) return 'meal';
    final presentation = MealPresentationRegistry.forStableId(value);
    return presentation.isKnown ? presentation.label.toLowerCase() : 'meal';
  }

  String _mealTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Meal';
    final presentation = MealPresentationRegistry.forStableId(value);
    return presentation.isKnown ? presentation.label : 'Meal';
  }

  String _quantityUnitLabel(Quantity quantity, {NutritionFoodOption? option}) =>
      quantity.unit == QuantityUnit.householdReference
      ? quantity.context.householdMeasure!.measureType
      : quantity.unit == QuantityUnit.serving &&
            option?.servingUnitLabel?.trim().isNotEmpty == true
      ? option!.servingUnitLabel!.trim()
      : quantity.definition.displayLabel;

  String? _canonicalBasisLabel(
    Quantity quantity, {
    NutritionFoodOption? option,
  }) {
    if (quantity.unit == QuantityUnit.serving) {
      final servingLabel = option?.servingUnitLabel?.trim();
      if (servingLabel != null && servingLabel.isNotEmpty) {
        return servingLabel;
      }
      return quantity.amount.toString() == '1'
          ? 'serving'
          : '${quantity.amount} servings';
    }
    if (quantity.unit == QuantityUnit.householdReference) {
      final measure = quantity.context.householdMeasure?.measureType.trim();
      if (measure == null || measure.isEmpty) return null;
      return '${quantity.amount} $measure';
    }
    final symbol = quantity.definition.symbol.trim();
    if (symbol.isEmpty || symbol == '?') return null;
    return '${quantity.amount} $symbol';
  }


  Widget _buildLocalItemRow(FoodItem food, {bool recent = false}) {
    final displayName = _consumerFoodName(food.name);
    final serving = _localServingLabel(food);
    final metadata = [
      '${_numberLabel(food.calories)} kcal',
      '${_numberLabel(food.proteinG)} g protein',
      if (serving != null) 'Per $serving',
    ].join(' · ');
    final isSelected = _selectedOptions.values.any(
      (option) => option.sourceReference == 'legacy-food-item:${food.id}',
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label: '$displayName, $metadata',
        hint: _isMultiSelect
            ? (isSelected
                  ? 'Tap to deselect from multi-food add.'
                  : 'Tap to select for multi-food add.')
            : 'Tap Add to use a supported serving or open to adjust the amount.',
        child: ListTile(
          minVerticalPadding: 10,
          leading: _isMultiSelect
              ? Semantics(
                  label: 'Select $displayName for a multi-food add',
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => unawaited(_toggleLegacySelection(food)),
                  ),
                )
              : null,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
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
            '$metadata${recent ? ' · Recent' : ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _isMultiSelect
              ? (isSelected
                    ? IconButton(
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        tooltip: 'Adjust portion for $displayName',
                        onPressed: () async {
                          final selectedOption = _selectedOptions.values
                              .where(
                                (opt) =>
                                    opt.sourceReference ==
                                    'legacy-food-item:${food.id}',
                              )
                              .firstOrNull;
                          if (selectedOption != null) {
                            await _editSelectedQuantity(selectedOption);
                          }
                        },
                      )
                    : null)
              : _buildFastAddAction(
                  foodName: displayName,
                  onPressed: () => unawaited(_openLegacyFastAdd(food)),
                ),
          onTap: () {
            if (_isMultiSelect) {
              unawaited(_toggleLegacySelection(food));
            } else {
              unawaited(_openLegacyLogDialog(food));
            }
          },
        ),
      ),
    );
  }

  Widget _buildOnlineItemRow(FoodApiResult food) {
    final displayName = _consumerFoodName(food.name);
    final serving = _providerServingLabel(food);
    final brand = _consumerBrand(food.brand, displayName);
    final packageDetail = _providerPackageLabel(food.packageQuantity);
    final nutrition = _providerNutritionSummary(
      food,
      serving: serving,
      package: packageDetail,
    );
    final identityLabel = brand == null || brand.isEmpty
        ? displayName
        : '$brand $displayName';
    final reference = _providerReference(food);
    final canLog = reference != null;
    // Gate 1 (PV1-CATALOG-01B): provider results never join multi-select
    // batch logging. Every provider row requires individual review via
    // RemoteFoodReviewSheet — no provider response silently becomes trusted
    // nutrition through finalizeBatch.
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label:
            '$identityLabel, $nutrition${canLog ? '' : ', unavailable for logging'}',
        hint: canLog
            ? (_isMultiSelect
                  ? 'Tap to review $displayName before logging. Provider results need individual review.'
                  : 'Tap Add to use a supported serving or open to adjust the amount.')
            : 'This result is unavailable for logging. Try another match.',
        child: ListTile(
          minVerticalPadding: 10,
          leading: _isMultiSelect
              ? Semantics(
                  label:
                      '$displayName needs individual review before logging',
                  child: Tooltip(
                    message:
                        'Provider results need individual review — tap the row',
                    child: const Checkbox(
                      value: false,
                      onChanged: null,
                    ),
                  ),
                )
              : null,
          title: brand == null || brand.isEmpty
              ? Text(
                  displayName,
                  style: B05Typography.label(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: B05Typography.label(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      brand,
                      style: B05Typography.caption(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
          subtitle: Text(
            nutrition,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _isMultiSelect
              ? null
              : _buildFastAddAction(
                  foodName: displayName,
                  onPressed: canLog
                      ? () => unawaited(_openProviderFastAdd(food))
                      : null,
                  unavailable: !canLog,
                ),
          onTap: () {
            if (!canLog) {
              _showUnavailableProviderFoodMessage();
            } else {
              // Multi-select or not, provider rows always open individual
              // review (see Gate 1 note above).
              unawaited(_openProviderLogDialog(food));
            }
          },
        ),
      ),
    );
  }

  String? _localServingLabel(FoodItem food) {
    final unit = _consumerMetadata(food.servingUnit);
    if (unit == null || food.servingSize <= 0) return null;
    return '${_numberLabel(food.servingSize)} $unit';
  }

  String? _providerServingLabel(FoodApiResult food) {
    final unit = _consumerMetadata(food.servingUnit);
    if (unit == null || !food.servingSize.isFinite || food.servingSize <= 0) {
      return null;
    }
    return '${_formatProviderNumber(food.servingSize)} $unit';
  }

  String? _providerPackageLabel(String? value) {
    final clean = _consumerMetadata(value);
    if (clean == null) return null;
    final normalized = clean.replaceAll(RegExp(r'\s+'), ' ');
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(kg|g|mg|l|ml)\s*(?:pack(?:age)?)?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match != null) {
      return 'Package: ${_formatProviderNumber(double.parse(match.group(1)!))} ${match.group(2)!.toLowerCase()}';
    }
    return 'Package: $normalized';
  }

  String _providerNutritionSummary(
    FoodApiResult food, {
    required String? serving,
    required String? package,
  }) {
    final primaryFacts = <String>[
      if (food.calories != null && food.calories!.isFinite)
        '${_formatProviderNumber(food.calories!)} kcal',
      if (food.protein != null && food.protein!.isFinite)
        '${_formatProviderNumber(food.protein!)} g protein',
    ];
    final fallbackFacts = <String>[
      if (primaryFacts.isEmpty && food.carbs != null && food.carbs!.isFinite)
        '${_formatProviderNumber(food.carbs!)} g carbs',
      if (primaryFacts.isEmpty && food.fat != null && food.fat!.isFinite)
        '${_formatProviderNumber(food.fat!)} g fat',
    ];
    final facts = [...primaryFacts, ...fallbackFacts];
    if (facts.isEmpty) {
      return [
        'Nutrition details unavailable',
        if (serving != null) 'Per $serving',
        ?package,
      ].join(' · ');
    }
    return [
      ...facts,
      if (serving != null) 'Per $serving',
      ?package,
    ].join(' · ');
  }

  String _canonicalNutritionSummary(NutritionFoodOption option) {
    final facts = <String>[
      ..._optionFactLabels(option, 'energy', 'kcal', 0),
      ..._optionFactLabels(option, 'protein', 'g protein', 1),
      ..._optionFactLabels(option, 'carbohydrate', 'g carbs', 1),
      ..._optionFactLabels(option, 'fat', 'g fat', 1),
    ];
    final basis = _canonicalBasisLabel(option.baseQuantity, option: option);
    if (facts.isEmpty) {
      return [
        'Nutrition details unavailable',
        if (basis != null) 'Per $basis',
      ].join(' · ');
    }
    return [...facts, if (basis != null) 'Per $basis'].join(' · ');
  }

  List<String> _optionFactLabels(
    NutritionFoodOption option,
    String nutrientId,
    String unit,
    int precision,
  ) {
    final fact = option.facts[nutrientId];
    if (fact == null || !fact.isAvailable) return const [];
    String? format(NutrientAmount? amount) => amount == null
        ? null
        : '${amount.value.format(decimalPlaces: precision)} $unit';
    final lower = format(fact.lower);
    final upper = format(fact.upper);
    final point = format(fact.point);
    if (lower != null || upper != null) {
      return [
        [?lower, ?upper].join('–'),
      ];
    }
    return point == null ? const [] : [point];
  }

  String _consumerFoodName(String? value) {
    final clean = _consumerMetadata(value);
    if (clean == null) return 'Food';
    final bracketed = RegExp(r'^\[(.*)\]$').firstMatch(clean);
    final unwrapped = bracketed?.group(1)?.trim() ?? clean;
    final result = unwrapped.replaceFirst(RegExp(r'[.,;:]$'), '').trim();
    return result.isEmpty ? 'Food' : result;
  }

  String? _consumerMetadata(String? value) {
    final compact = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact == null ||
        compact.isEmpty ||
        compact == '—' ||
        compact == '-') {
      return null;
    }
    final bracketed = RegExp(r'^\[(.*)\]$').firstMatch(compact);
    final clean = bracketed?.group(1)?.trim() ?? compact;
    if (clean.isEmpty || clean == '—' || clean == '-') return null;
    return clean;
  }

  String? _consumerBrand(String? value, String foodName) {
    final brand = _consumerMetadata(value);
    if (brand == null) return null;
    final displayBrand = _consumerFoodName(brand);
    if (displayBrand.toLowerCase() == foodName.trim().toLowerCase()) {
      return null;
    }
    return displayBrand;
  }

  String _formatProviderNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  String _numberLabel(num value) => value.toDouble() == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

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

