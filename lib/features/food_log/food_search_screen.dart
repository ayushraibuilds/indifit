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
import '../../core/services/indifit_haptics.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/typed_quantities.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_api_service.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../../data/repositories/nutrition_food_logging_coordinator.dart';
import '../../data/services/nutrition_food_search_ranking.dart';
import '../dashboard/today_consumer_presentation.dart';
import '../dashboard/today_surface_controller.dart';
import '../dashboard/widgets/dashboard_date_bar.dart';
import 'ai_meal_logger_screen.dart';
import 'barcode_scanner_screen.dart';
import 'canonical_food_delete.dart';
import 'custom_food_editor_screen.dart';
import 'food_log_surface.dart';
import 'meal_presentation_registry.dart';
import 'saved_meals_screen.dart';
import 'saved_recipe_log_screen.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  final String? mealType; // "breakfast", "lunch", "dinner", "snack"
  final DateTime? selectedDate;
  final bool returnToParentOnSave;
  final NutritionHistoricalReadRecord? initialRecord;

  const FoodSearchScreen({
    super.key,
    required this.mealType,
    this.selectedDate,
    this.returnToParentOnSave = true,
    this.initialRecord,
  });

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class CanonicalRecentFood {
  const CanonicalRecentFood({
    required this.option,
    required this.quantityLabel,
    required this.loggedAtUtc,
    this.frequencyCount = 1,
  });

  final NutritionFoodOption option;
  final String quantityLabel;
  final DateTime loggedAtUtc;
  final int frequencyCount;
}

class _FoodAddUndoToken {
  const _FoodAddUndoToken({
    required this.snapshotId,
    required this.localDate,
    required this.mealCategory,
  });

  final String snapshotId;
  final String localDate;
  final String mealCategory;
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
        final frequencyByFoodId = <String, int>{};
        for (final record in ordered) {
          for (final item in record.items) {
            final foodId = item.foodId;
            if (item.originSourceType == 'direct_food' && foodId != null) {
              frequencyByFoodId.update(
                foodId,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
            }
          }
        }
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
                frequencyCount: frequencyByFoodId[foodId] ?? 1,
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

  String? get _activeMealType {
    final value = widget.mealType?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    return value == 'snacks' ? 'snack' : value;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    if (_activeMealType != null) _loadRecentFoods();
    if (widget.initialRecord != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_openedInitialRecord && mounted && widget.initialRecord != null) {
          _openedInitialRecord = true;
          unawaited(() async {
            await _showCanonicalActionMenu(widget.initialRecord!);
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
    _debounceTimer = Timer(const Duration(milliseconds: 700), () {
      _performSearch(_searchController.text);
    });
  }

  NutritionFoodSearchHistory _searchHistory() {
    final frequency = <String, int>{};
    final recent = <String>{};
    for (final item in _canonicalRecentResults) {
      final key = 'canonical::${item.option.id}';
      frequency[key] = item.frequencyCount;
      recent.add(key);
      const legacyMarker = 'legacy-food-item:';
      final sourceReference = item.option.sourceReference;
      if (sourceReference?.startsWith(legacyMarker) == true) {
        final legacyKey =
            'canonical::legacy-food-item::${sourceReference!.substring(legacyMarker.length)}';
        frequency[legacyKey] = item.frequencyCount;
        recent.add(legacyKey);
      }
      final providerKey = _providerHistoryKey(sourceReference);
      if (providerKey != null) {
        frequency[providerKey] = item.frequencyCount;
        recent.add(providerKey);
      }
    }
    for (final item in _recentResults) {
      final key = 'canonical::legacy-food-item::${item.id}';
      frequency.putIfAbsent(key, () => 1);
      recent.add(key);
    }
    return NutritionFoodSearchHistory(
      frequencyByIdentity: frequency,
      recentIdentities: recent,
    );
  }

  String? _providerHistoryKey(String? sourceReference) {
    final reference = sourceReference?.trim();
    if (reference == null || reference.isEmpty) return null;
    for (final prefix in const [
      'open-food-facts:barcode:',
      'open-food-facts:product:',
    ]) {
      if (!reference.startsWith(prefix)) continue;
      final providerId = reference.substring(prefix.length).trim();
      return providerId.isEmpty ? null : 'provider::$providerId';
    }
    return null;
  }

  void _rebuildSearchRanking(String query) {
    final candidates = <NutritionFoodSearchCandidate>[
      for (final food in _localResults)
        NutritionFoodSearchCandidate.legacy(food),
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

  Future<void> _performSearch(String text) async {
    if (!mounted) return;
    final query = text.trim();
    final generation = ++_searchGeneration;
    _onlineSearchCancelToken?.cancel('New food search started');
    if (query.isEmpty) {
      _onlineSearchCancelToken = null;
      setState(() {
        _localResults = [];
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
      _rebuildSearchRanking(query);
      _searching = false;
      _searchingOnline = true;
    });

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

  String _providerReference(FoodApiResult result) {
    final barcode = result.barcode?.trim();
    if (barcode != null && barcode.isNotEmpty) {
      // Preserve the R07D-1 provider identity namespace for barcode-backed
      // products so retries reuse existing B03 identities.
      return 'open-food-facts:barcode:$barcode';
    }
    final stableId = result.providerId ?? result.barcode;
    if (stableId != null && stableId.trim().isNotEmpty) {
      return 'open-food-facts:product:${stableId.trim()}';
    }
    return 'open-food-facts:search:${NutritionFoodSearchVocabulary.normalize(result.name)}';
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
        brand: result.brand,
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

  Future<void> _openProviderFastAdd(FoodApiResult result) async {
    try {
      final reference = _providerReference(result);
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
        brand: result.brand,
      );
      await _addOptionFast(option);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This food is unavailable. Try again.')),
        );
      }
    }
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
      unawaited(IndiFitHaptics.confirmation());
      _invalidateNutritionReads();
      final undo = _FoodAddUndoToken(
        snapshotId: snapshot.id,
        localDate: dateContext.localDate,
        mealCategory: selectedMealType,
      );
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Text(
            'Added ${option.displayName} to ${_mealLabel(selectedMealType)}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => unawaited(_undoLastCanonicalAdd(undo)),
          ),
        ),
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

  Future<void> _undoLastCanonicalAdd(_FoodAddUndoToken undo) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Food removed. Your totals are up to date.'),
        ),
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
    String? supersedesSnapshotId,
    Future<void> Function(Quantity quantity)? onQuantityPicked,
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
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            Widget decreaseButton() => IconButton(
              tooltip: 'Decrease amount',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: selectedQuantity.compareTo(stepQuantity) > 0
                  ? () => setQuantity(
                      selectedQuantity - stepQuantity,
                      setModalState,
                    )
                  : null,
            );
            Widget amountInput() => TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, value) {
                  final text = value.text;
                  return RegExp(r'^\d*(?:\.\d{0,4})?$').hasMatch(text)
                      ? value
                      : oldValue;
                }),
              ],
              decoration: InputDecoration(
                labelText: 'Amount',
                errorText: amountError,
                suffixText: compatibleUnits.length == 1
                    ? _quantityUnitLabel(selectedQuantity, option: option)
                    : null,
              ),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onChanged: (value) => updateAmount(value, setModalState),
            );
            Widget unitPicker() => Semantics(
              label: 'Unit',
              value: _quantityUnitLabel(selectedQuantity, option: option),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<QuantityUnit>(
                    isDense: true,
                    value: selectedQuantity.unit,
                    items: compatibleUnits
                        .map(
                          (unit) => DropdownMenuItem(
                            value: unit,
                            child: Text(
                              QuantityUnitRegistry.definitionFor(unit).symbol,
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
              ),
            );
            Widget increaseButton() => IconButton(
              tooltip: 'Increase amount',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () =>
                  setQuantity(selectedQuantity + stepQuantity, setModalState),
            );
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

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stackUnit =
                            compatibleUnits.length > 1 &&
                            (constraints.maxWidth < 340 || textScale > 1.3);
                        final controls = Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            decreaseButton(),
                            Expanded(child: amountInput()),
                            increaseButton(),
                          ],
                        );
                        if (stackUnit) {
                          return Column(
                            children: [
                              controls,
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: unitPicker(),
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            decreaseButton(),
                            Expanded(child: amountInput()),
                            if (compatibleUnits.length > 1) ...[
                              const SizedBox(width: 8),
                              SizedBox(width: 104, child: unitPicker()),
                            ],
                            increaseButton(),
                          ],
                        );
                      },
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

                        final metrics = [
                          (
                            'Calories',
                            value('energy', ' kcal'),
                            context.b05Colors.action,
                          ),
                          (
                            'Protein',
                            value('protein', 'g'),
                            context.b05Colors
                                .meal(B05MealAccent.breakfast)
                                .indicator,
                          ),
                          (
                            'Carbs',
                            value('carbohydrate', 'g'),
                            context.b05Colors
                                .meal(B05MealAccent.lunch)
                                .indicator,
                          ),
                          (
                            'Fat',
                            value('fat', 'g'),
                            context.b05Colors
                                .meal(B05MealAccent.dinner)
                                .indicator,
                          ),
                        ];
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final columns =
                                constraints.maxWidth < 340 || textScale > 1.3
                                ? 2
                                : 4;
                            final width =
                                (constraints.maxWidth - (columns - 1) * 8) /
                                columns;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 12,
                              children: [
                                for (final metric in metrics)
                                  SizedBox(
                                    width: width,
                                    child: _buildMacroPreview(
                                      metric.$1,
                                      metric.$2,
                                      metric.$3,
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stackActions =
                            constraints.maxWidth < 340 || textScale > 1.3;
                        final actionWidth = stackActions
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: actionWidth,
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(false),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: context.b05Colors.border,
                                  ),
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
                            SizedBox(
                              width: actionWidth,
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
                                        late final Quantity finalQuantity;
                                        try {
                                          finalQuantity = Quantity.fromDecimal(
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
                                        if (onQuantityPicked != null) {
                                          setModalState(
                                            () => isFinalizing = true,
                                          );
                                          try {
                                            await onQuantityPicked(
                                              finalQuantity,
                                            );
                                            finalized = true;
                                            if (sheetContext.mounted) {
                                              Navigator.of(
                                                sheetContext,
                                              ).pop(true);
                                            }
                                          } catch (_) {
                                            if (sheetContext.mounted) {
                                              setModalState(
                                                () => isFinalizing = false,
                                              );
                                              ScaffoldMessenger.of(
                                                sheetContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Amount could not be updated. Try again.',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
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
                                              .read(
                                                localTimezoneServiceProvider,
                                              )
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
                                          final loggedAt =
                                              selectedLocalDate == null
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
                                          _invalidateNutritionReads();
                                          try {
                                            await HapticFeedback.selectionClick();
                                          } catch (_) {
                                            // Haptics are optional feedback; a
                                            // missing plugin cannot make a saved
                                            // meal look unsaved.
                                          }
                                          if (sheetContext.mounted) {
                                            Navigator.of(
                                              sheetContext,
                                            ).pop(true);
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
                                child: Text(
                                  isFinalizing
                                      ? 'Saving…'
                                      : 'Add to ${_mealTitle(selectedMealType)}',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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
      if (onQuantityPicked != null) return;
      // The result future resolves when the sheet begins closing. Wait for
      // its overlay to be removed before popping the meal-specific search
      // route, otherwise `maybePop` can run while the navigator is locked.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          indiFitSuccessSnackBar(
            supersedesSnapshotId == null
                ? '✓ Food added to ${_mealLabel(selectedMealType)}'
                : '✓ Food entry updated',
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

  void _toggleCanonicalSelection(NutritionFoodOption option) {
    unawaited(IndiFitHaptics.selection());
    final key = _selectionKeyForOption(option);
    setState(() {
      if (_selectedKeys.remove(key)) {
        _selectedOptions.remove(key);
        _selectedQuantities.remove(key);
      } else {
        _selectedKeys.add(key);
        _selectedOptions[key] = option;
        _selectedQuantities[key] = option.baseQuantity;
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

  Future<void> _toggleOnlineSelection(FoodApiResult food) async {
    final reference = _providerReference(food);
    final key = 'provider-food:$reference';
    if (_selectionLoading.contains(key)) return;
    final selectedOption = _selectedOptions.entries
        .where((entry) => entry.value.sourceReference == reference)
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
      final option = await catalog.ensureProviderFood(
        displayName: food.name,
        sourceReference: reference,
        servingSize: food.servingSize,
        servingUnit: food.servingUnit,
        energyKcal: food.calories,
        proteinG: food.protein,
        carbohydrateG: food.carbs,
        fatG: food.fat,
        brand: food.brand,
      );
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
      unawaited(IndiFitHaptics.confirmation());
      setState(() {
        _selectedKeys.clear();
        _selectedOptions.clear();
        _selectedQuantities.clear();
      });
      _invalidateNutritionReads();
      final undo = _FoodAddUndoToken(
        snapshotId: snapshot.id,
        localDate: dateContext.localDate,
        mealCategory: mealType,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Text(
            '${selected.length} foods added to ${_mealLabel(mealType)}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => unawaited(_undoLastCanonicalAdd(undo)),
          ),
        ),
      );
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
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
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
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            option.displayName,
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _committingSelection ? null : _commitSelection,
                child: Text(
                  _committingSelection
                      ? 'Adding…'
                      : 'ADD ${_selectedOptions.length} FOOD${_selectedOptions.length == 1 ? '' : 'S'} TO ${_mealLabel(mealType).toUpperCase()}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              'Log ${_mealLabel(mealType)}',
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
        if (_canonicalRecentResults.any((item) => item.frequencyCount > 1)) ...[
          const SizedBox(height: 16),
          _sectionHeader(
            title: 'Frequent',
            subtitle: 'Your repeat choices, ordered by real local history.',
          ),
          ...(_canonicalRecentResults
                  .where((item) => item.frequencyCount > 1)
                  .toList()
                ..sort((left, right) {
                  final count = right.frequencyCount.compareTo(
                    left.frequencyCount,
                  );
                  return count == 0
                      ? right.loggedAtUtc.compareTo(left.loggedAtUtc)
                      : count;
                }))
              .map(_buildCanonicalRecentItemRow),
        ],
        const SizedBox(height: 16),
        _sectionHeader(
          title: 'Saved & recipes',
          subtitle: 'Reusable meals and recipes you make often.',
        ),
        _buildNavigationCard(
          icon: Icons.bookmark_outline_rounded,
          title: 'Saved meals',
          detail: 'One-tap log your reusable meal combinations.',
          onTap: _openSavedMeals,
        ),
        _buildNavigationCard(
          icon: Icons.menu_book_rounded,
          title: 'Saved recipes',
          detail: 'Find, scale or create a published recipe.',
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
          label: _rankedSearchResults.isNotEmpty
              ? 'Showing matching foods'
              : 'Online search unavailable',
          detail: _rankedSearchResults.isNotEmpty
              ? 'Online results are temporarily unavailable.'
              : _onlineFailureMessage ?? 'Try again or choose from Recent.',
          error: _rankedSearchResults.isEmpty,
          onRetry: () => _performSearch(_searchController.text),
        ),
      if (_rankedSearchResults.isNotEmpty) ...[
        _sectionHeader(title: 'Search results'),
        ..._rankedSearchResults.map(_buildRankedSearchRow),
      ],
      if (_searchingOnline)
        const ConsumerStatusRow(
          label: 'Searching for more matches',
          detail: 'Matching foods are ready to use.',
          loading: true,
        ),
      if (!_searchingOnline &&
          !_isOnlineSearchOffline &&
          _rankedSearchResults.isEmpty)
        _buildNoResultsState(),
    ],
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
            for (final meal in const [
              ('breakfast', 'Breakfast'),
              ('lunch', 'Lunch'),
              ('dinner', 'Dinner'),
              ('snack', 'Snack'),
            ])
              OutlinedButton(
                onPressed: () => _openMealLogger(meal.$1),
                child: Text(meal.$2),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _buildRecentItemRow(FoodItem food) =>
      _buildLocalItemRow(food, recent: true);

  Widget _buildCanonicalSearchRow(NutritionFoodOption option) {
    final energy = _optionFactLabel(option, 'energy', 'kcal', 0);
    final protein = _optionFactLabel(option, 'protein', 'g protein', 1);
    final brand = option.brand?.trim();
    final isCustom =
        option.sourceType == 'user' || option.sourceType == 'user_entered';
    final identityLabel = brand == null || brand.isEmpty
        ? option.displayName
        : '$brand ${option.displayName}';
    final title = brand == null || brand.isEmpty
        ? Text(option.displayName, maxLines: 2, overflow: TextOverflow.ellipsis)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.displayName,
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
          );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label:
            '$identityLabel${isCustom ? ', custom food' : ''}, $energy, $protein',
        hint:
            'Tap Add to log the listed serving, or open to adjust the amount.',
        child: ListTile(
          minVerticalPadding: 8,
          leading: Semantics(
            label: 'Select ${option.displayName} for a multi-food add',
            child: Checkbox(
              value: _selectedOptions.containsKey(option.id),
              onChanged: (_) => _toggleCanonicalSelection(option),
            ),
          ),
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
            '${_quantityUnitLabel(option.baseQuantity, option: option)} · $energy · $protein',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _buildCanonicalFastAddAction(option),
          onTap: () => unawaited(_showLogDialog(option)),
        ),
      ),
    );
  }

  Widget _buildCanonicalRecentItemRow(CanonicalRecentFood recent) {
    final option = recent.option;
    final energy = _optionFactLabel(option, 'energy', 'kcal', 0);
    final protein = _optionFactLabel(option, 'protein', 'g protein', 1);
    final brand = option.brand?.trim();
    final identityLabel = brand == null || brand.isEmpty
        ? option.displayName
        : '$brand ${option.displayName}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label: '$identityLabel, $energy, $protein',
        hint:
            'Tap Add to log the listed serving, or open to adjust the amount.',
        child: ListTile(
          minVerticalPadding: 10,
          leading: Semantics(
            label: 'Select ${option.displayName} for a multi-food add',
            child: Checkbox(
              value: _selectedOptions.containsKey(option.id),
              onChanged: (_) => _toggleCanonicalSelection(option),
            ),
          ),
          title: brand == null || brand.isEmpty
              ? Text(
                  option.displayName,
                  style: B05Typography.label(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.displayName,
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
            '${recent.quantityLabel} · ${_lastLoggedLabel(recent.loggedAtUtc)} · ${recent.frequencyCount} logged · $energy · $protein',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _buildCanonicalFastAddAction(option),
          onTap: () => unawaited(_showLogDialog(option)),
        ),
      ),
    );
  }

  Widget _buildCanonicalFastAddAction(NutritionFoodOption option) {
    final isAdding = _fastAddInFlight.contains(option.id);
    return _buildFastAddAction(
      foodName: option.displayName,
      isAdding: isAdding,
      onPressed: isAdding ? null : () => unawaited(_addOptionFast(option)),
    );
  }

  Widget _buildFastAddAction({
    required String foodName,
    required VoidCallback? onPressed,
    bool isAdding = false,
  }) {
    final label = isAdding ? 'Adding $foodName' : 'Add $foodName';
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
            label: Text(isAdding ? 'Adding…' : 'Add'),
          ),
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
    final directItems = record.items
        .where(
          (candidate) =>
              candidate.originSourceType == 'direct_food' &&
              candidate.foodId != null,
        )
        .toList(growable: false);
    if (directItems.length > 1) {
      final deleteBatch = await showModalBottomSheet<bool>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(B05Layout.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${directItems.length} foods in this entry',
                  style: B05Typography.title(sheetContext),
                ),
                const SizedBox(height: B05Layout.space8),
                Text(
                  'Editing one food as a single correction could change the other foods. Add a corrected food from the meal instead, or delete this complete batch.',
                  style: B05Typography.body(sheetContext),
                ),
                const SizedBox(height: B05Layout.space16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete entire batch'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: const Text('Keep entry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (deleteBatch == true && mounted) {
        await showCanonicalFoodDelete(
          context: context,
          ref: ref,
          record: record,
        );
      }
      return;
    }
    final item = directItems.firstOrNull;
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

  String _mealTitle(String? value) => switch (_mealLabel(value)) {
    'breakfast' => 'Breakfast',
    'lunch' => 'Lunch',
    'dinner' => 'Dinner',
    'snack' => 'Snack',
    _ => 'Meal',
  };

  String _quantityUnitLabel(Quantity quantity, {NutritionFoodOption? option}) =>
      quantity.unit == QuantityUnit.householdReference
      ? quantity.context.householdMeasure!.measureType
      : quantity.unit == QuantityUnit.serving &&
            option?.servingUnitLabel?.trim().isNotEmpty == true
      ? option!.servingUnitLabel!.trim()
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
    final isSelected = _selectedOptions.values.any(
      (option) => option.sourceReference == 'legacy-food-item:${food.id}',
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label: '${food.name}, ${food.calories} kilocalories, $serving',
        hint:
            'Tap Add to use a supported serving or open to adjust the amount.',
        child: ListTile(
          minVerticalPadding: 10,
          leading: Semantics(
            label: 'Select ${food.name} for a multi-food add',
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => unawaited(_toggleLegacySelection(food)),
            ),
          ),
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
          trailing: _buildFastAddAction(
            foodName: food.name,
            onPressed: () => unawaited(_openLegacyFastAdd(food)),
          ),
          onTap: () => unawaited(_openLegacyLogDialog(food)),
        ),
      ),
    );
  }

  Widget _buildOnlineItemRow(FoodApiResult food) {
    final serving =
        '${_formatProviderNumber(food.servingSize)} ${food.servingUnit}';
    final brand = food.brand?.trim();
    final packageQuantity = food.packageQuantity?.trim();
    final packageDetail = packageQuantity == null || packageQuantity.isEmpty
        ? ''
        : ' · $packageQuantity pack';
    final identityLabel = brand == null || brand.isEmpty
        ? food.name
        : '$brand ${food.name}';
    final reference = _providerReference(food);
    final isSelected = _selectedOptions.values.any(
      (option) => option.sourceReference == reference,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label:
            '$identityLabel, ${_formatProviderValue(food.calories, 'kcal')}$packageDetail, $serving',
        hint:
            'Tap Add to use a supported serving or open to adjust the amount.',
        child: ListTile(
          minVerticalPadding: 10,
          leading: Semantics(
            label: 'Select ${food.name} for a multi-food add',
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => unawaited(_toggleOnlineSelection(food)),
            ),
          ),
          title: brand == null || brand.isEmpty
              ? Text(
                  food.name,
                  style: B05Typography.label(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
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
            '${_formatProviderValue(food.calories, 'kcal')} · ${_formatProviderValue(food.protein, 'g protein')} · $serving$packageDetail',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _buildFastAddAction(
            foodName: food.name,
            onPressed: () => unawaited(_openProviderFastAdd(food)),
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

class FoodDiaryScreen extends ConsumerStatefulWidget {
  const FoodDiaryScreen({super.key, required this.selectedDate, this.today});

  final DateTime selectedDate;
  final DateTime? today;

  @override
  ConsumerState<FoodDiaryScreen> createState() => _FoodDiaryScreenState();
}

class _FoodDiaryScreenState extends ConsumerState<FoodDiaryScreen> {
  late DateTime _selectedDay;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _selectedDay = _civilDay(widget.selectedDate);
    _today = _civilDay(widget.today ?? DateTime.now());
  }

  @override
  void didUpdateWidget(covariant FoodDiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _selectedDay = _civilDay(widget.selectedDate);
    }
    if (oldWidget.today != widget.today) {
      _today = _civilDay(widget.today ?? DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final diary = ref.watch(foodDiaryReadModelProvider(_selectedDay));
    final daily = diary.valueOrNull?.daily;
    final canonical = daily == null && diary.hasError
        ? ref.watch(canonicalFoodRecordsForDayProvider(_selectedDay))
        : const AsyncData<List<NutritionHistoricalReadRecord>>([]);
    final recent = daily == null
        ? const AsyncLoading<List<CanonicalRecentFood>>()
        : ref.watch(canonicalRecentFoodsProvider);
    final presentation = TodayNutritionPresentation.from(
      daily == null ? null : TodayDomainRead.available(daily),
      loading: diary.isLoading,
    );
    final records = daily?.records ?? canonical.valueOrNull ?? [];
    final meals = <({String type, String label})>[
      (type: 'breakfast', label: 'Breakfast'),
      (type: 'lunch', label: 'Lunch'),
      (type: 'dinner', label: 'Dinner'),
      (type: 'snack', label: 'Snacks'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Food diary', style: B05Typography.title(context)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            DashboardDateBar(
              selectedDate: _selectedDay,
              today: _today,
              onDateChanged: (date) {
                final nextDay = _civilDay(date);
                if (_isSameDay(nextDay, _selectedDay)) return;
                setState(() => _selectedDay = nextDay);
              },
            ),
            const SizedBox(height: 12),
            _FoodDiarySummary(presentation: presentation),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openMealPicker(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add food'),
            ),
            const SizedBox(height: 16),
            Text('Meals', style: B05Typography.title(context)),
            const SizedBox(height: 8),
            for (var index = 0; index < meals.length; index++) ...[
              _FoodDiaryMealRow(
                type: meals[index].type,
                label: meals[index].label,
                records: records
                    .where(
                      (record) =>
                          _foodDiaryMealType(record.mealCategory) ==
                          meals[index].type,
                    )
                    .toList(growable: false),
                onOpen: () => _openMealDetail(context, meals[index].type),
                onAdd: () => _openMealAdd(context, meals[index].type),
              ),
              if (index < meals.length - 1)
                Divider(height: 16, color: context.b05Colors.border),
            ],
            const SizedBox(height: 20),
            Text('Recent', style: B05Typography.title(context)),
            const SizedBox(height: 2),
            Text(
              'Your local history is ready when you need to repeat a meal.',
              style: B05Typography.caption(context),
            ),
            const SizedBox(height: 8),
            recent.when(
              loading: () => const B05StatusMessage(
                status: B05SemanticStatus.info,
                label: 'Loading recent foods',
              ),
              error: (_, _) => const B05StatusMessage(
                status: B05SemanticStatus.info,
                label: 'Recent foods are unavailable',
                value: 'Open Add Food to search your local foods.',
              ),
              data: (foods) => foods.isEmpty
                  ? const B05StatusMessage(
                      status: B05SemanticStatus.info,
                      label: 'No recent foods yet',
                      value: 'Foods you log will appear here.',
                    )
                  : Column(
                      children: [
                        for (final food in foods.take(3))
                          _FoodDiaryHistoryRow(
                            recent: food,
                            onTap: () => _openMealPicker(context),
                          ),
                      ],
                    ),
            ),
            if (recent.valueOrNull?.any((item) => item.frequencyCount > 1) ==
                true) ...[
              const SizedBox(height: 16),
              _FoodDiaryShortcut(
                icon: Icons.repeat_rounded,
                title: 'Frequent foods',
                detail: 'Repeat choices ordered by your real local history.',
                onTap: () => _openMealPicker(context),
              ),
            ],
            const SizedBox(height: 16),
            Text('Saved & recipes', style: B05Typography.title(context)),
            const SizedBox(height: 8),
            _FoodDiaryShortcut(
              icon: Icons.menu_book_rounded,
              title: 'Saved recipes',
              detail: 'Open a complete meal without rebuilding it.',
              onTap: () => _openSavedRecipes(context),
            ),
            if (diary.hasError && daily == null) ...[
              const SizedBox(height: 16),
              const B05StatusMessage(
                status: B05SemanticStatus.warning,
                label: 'Daily nutrition is unavailable',
                value: 'Your logged meals are still available below.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openMealAdd(BuildContext context, String mealType) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          mealType: mealType,
          selectedDate: _selectedDay,
          returnToParentOnSave: true,
        ),
      ),
    );
  }

  Future<void> _openMealDetail(BuildContext context, String mealType) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FoodMealDetailScreen(
          mealType: mealType,
          selectedDate: _selectedDay,
        ),
      ),
    );
  }

  Future<String?> _chooseMeal(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose a meal',
                    style: B05Typography.title(sheetContext),
                  ),
                ),
              ),
              for (final item in const [
                ('breakfast', 'Breakfast'),
                ('lunch', 'Lunch'),
                ('dinner', 'Dinner'),
                ('snack', 'Snacks'),
              ])
                ListTile(
                  title: Text(item.$2),
                  leading: const Icon(Icons.restaurant_outlined),
                  onTap: () => Navigator.of(sheetContext).pop(item.$1),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

  Future<void> _openMealPicker(BuildContext context) async {
    final meal = await _chooseMeal(context);
    if (meal == null || !context.mounted) return;
    await _openMealAdd(context, meal);
  }

  Future<void> _openSavedRecipes(BuildContext context) async {
    final meal = await _chooseMeal(context);
    if (meal == null || !context.mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SavedRecipeLogScreen(mealType: meal, selectedDate: _selectedDay),
      ),
    );
  }

  DateTime _civilDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class FoodMealDetailScreen extends ConsumerWidget {
  const FoodMealDetailScreen({
    super.key,
    required this.mealType,
    required this.selectedDate,
  });

  final String mealType;
  final DateTime selectedDate;

  DateTime get _day =>
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = ref.watch(foodDiaryReadModelProvider(_day));
    final records = diary.valueOrNull?.daily.records;
    final mealRecords = records
        ?.where((record) => _foodDiaryMealType(record.mealCategory) == mealType)
        .toList(growable: false);
    final title = _foodDiaryMealTitle(mealType);
    final total = mealRecords == null
        ? 'Loading meal total'
        : _foodDiaryEnergyLabel(mealRecords);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            B05Surface(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: B05Typography.title(context)),
                        const SizedBox(height: 4),
                        Text(total, style: B05Typography.body(context)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => FoodSearchScreen(
                          mealType: mealType,
                          selectedDate: selectedDate,
                          returnToParentOnSave: true,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add food'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FoodLogEntriesPanel(
              date: selectedDate,
              mealType: mealType,
              onCanonicalRecordTap: (record) =>
                  _openRecordActions(context, record),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRecordActions(
    BuildContext context,
    NutritionHistoricalReadRecord record,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          mealType: mealType,
          selectedDate: selectedDate,
          returnToParentOnSave: true,
          initialRecord: record,
        ),
      ),
    );
  }
}

class _FoodDiarySummary extends StatelessWidget {
  const _FoodDiarySummary({required this.presentation});

  final TodayNutritionPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final calories = presentation.calories;
    final macros = presentation.macros
        .where((metric) => metric.nutrientId != 'fibre')
        .toList(growable: false);
    return Semantics(
      container: true,
      label: 'Food diary nutrition summary',
      child: B05Surface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    calories?.isAvailable == true
                        ? '${calories!.value} ${calories.unit}'
                        : '— kcal',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (calories?.hasTarget == true)
                  Text(
                    '/ ${calories!.targetValue!.round()} kcal',
                    style: B05Typography.caption(context),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (calories?.progress != null)
              LinearProgressIndicator(
                value: calories!.progress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                color: context.b05Colors.action,
                backgroundColor: context.b05Colors.selected,
              )
            else
              Text(
                presentation.state == TodayPresentationState.loading
                    ? 'Preparing today’s nutrition.'
                    : 'A target is not available for this day.',
                style: B05Typography.caption(context),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var index = 0; index < macros.length; index++) ...[
                  Expanded(child: _FoodDiaryMetric(metric: macros[index])),
                  if (index < macros.length - 1)
                    VerticalDivider(width: 12, color: context.b05Colors.border),
                ],
              ],
            ),
            if (presentation.hasIncompleteNutrition) ...[
              const SizedBox(height: 8),
              Text(
                'Some nutrition is missing; available values stay visible.',
                style: B05Typography.caption(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoodDiaryMetric extends StatelessWidget {
  const _FoodDiaryMetric({required this.metric});

  final TodayNutritionMetricPresentation metric;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(metric.label, style: B05Typography.caption(context)),
      const SizedBox(height: 2),
      Text(
        '${metric.value} ${metric.unit}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: B05Typography.label(context),
      ),
    ],
  );
}

class _FoodDiaryMealRow extends StatelessWidget {
  const _FoodDiaryMealRow({
    required this.type,
    required this.label,
    required this.records,
    required this.onOpen,
    required this.onAdd,
  });

  final String type;
  final String label;
  final List<NutritionHistoricalReadRecord> records;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final accent = context.b05Colors.meal(
      foodMealPresentationFor(type).accent ?? B05MealAccent.snack,
    );
    final labels = records
        .expand((record) => record.items)
        .map((item) => item.displayLabel)
        .whereType<String>()
        .where((label) => label.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);
    final preview = records.isEmpty
        ? 'Nothing logged yet'
        : labels.isEmpty
        ? '${records.length} logged'
        : labels.join(' · ');
    return Semantics(
      container: true,
      button: true,
      label: '$label. ${_foodDiaryEnergyLabel(records)}. $preview',
      hint: 'Open $label details or use the add button.',
      child: InkWell(
        onTap: onOpen,
        borderRadius: B05Radii.smallRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.container,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    foodMealPresentationFor(type).icon,
                    size: 18,
                    color: accent.indicator,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: B05Typography.label(context)),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: B05Typography.caption(context),
                    ),
                  ],
                ),
              ),
              Text(
                _foodDiaryEnergyLabel(records),
                style: B05Typography.caption(context).copyWith(
                  color: accent.indicator,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              B05IconAction(
                icon: Icons.add_circle_outline_rounded,
                label: 'Add $label',
                hint: 'Log food to $label.',
                onPressed: onAdd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodDiaryHistoryRow extends StatelessWidget {
  const _FoodDiaryHistoryRow({required this.recent, required this.onTap});

  final CanonicalRecentFood recent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${recent.option.displayName}, ${recent.quantityLabel}',
    hint: 'Choose a meal to add this food.',
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      dense: true,
      title: Text(
        recent.option.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${recent.quantityLabel} · ${recent.frequencyCount} logged',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.add_rounded),
      onTap: onTap,
    ),
  );
}

class _FoodDiaryShortcut extends StatelessWidget {
  const _FoodDiaryShortcut({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: title,
    hint: detail,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: context.b05Colors.action),
      title: Text(title, style: B05Typography.label(context)),
      subtitle: Text(detail, style: B05Typography.caption(context)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

String _foodDiaryMealType(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'snacks' ? 'snack' : normalized;
}

String _foodDiaryMealTitle(String value) => switch (_foodDiaryMealType(value)) {
  'breakfast' => 'Breakfast',
  'lunch' => 'Lunch',
  'dinner' => 'Dinner',
  'snack' => 'Snacks',
  _ => 'Meal',
};

String _foodDiaryEnergyLabel(Iterable<NutritionHistoricalReadRecord> records) {
  final facts = [for (final record in records) record.totals.facts['energy']];
  if (facts.isEmpty || facts.any((fact) => fact == null || !fact.isAvailable)) {
    return '— kcal';
  }
  final available = facts.cast<NutrientFact>();
  if (available.any((fact) => fact.point == null)) return '— kcal';
  final total = available.fold<double>(
    0,
    (sum, fact) => sum + fact.point!.value.asDouble,
  );
  return '${total.round()} kcal';
}
