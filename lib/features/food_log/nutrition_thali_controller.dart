import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrition_constraints.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_thali.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/typed_quantities.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/nutrition_thali_repository.dart';
import 'meal_presentation_registry.dart';
import 'thali/thali_preset_usage.dart';
import 'thali/thali_presets.dart';

enum NutritionThaliStatus {
  idle,
  loading,
  ready,
  searching,
  saving,
  previewLoading,
  previewReady,
  finalizing,
  success,
  failure,
}

class NutritionThaliState {
  final NutritionThaliStatus status;
  final NutritionThaliDraft? draft;
  final NutritionThaliPreview? preview;
  final List<NutritionThaliFoodOption> foodResults;
  final List<NutritionThaliRecipeOption> recipeResults;
  final List<NutritionHouseholdMeasureDefinition> standardMeasures;
  final List<NutritionPersonalVessel> personalVessels;
  final String query;
  final bool dirty;
  final bool partialAcknowledged;

  /// The user chose "Log without calories" for this exact preview.
  final bool unknownEnergyAcknowledged;
  final Set<String> acknowledgedConstraintIds;
  final NutritionConsumptionSnapshot? savedSnapshot;
  final String? errorCode;
  final String? errorMessage;
  final String? userNotice;

  const NutritionThaliState({
    this.status = NutritionThaliStatus.idle,
    this.draft,
    this.preview,
    this.foodResults = const [],
    this.recipeResults = const [],
    this.standardMeasures = const [],
    this.personalVessels = const [],
    this.query = '',
    this.dirty = false,
    this.partialAcknowledged = false,
    this.unknownEnergyAcknowledged = false,
    this.acknowledgedConstraintIds = const {},
    this.savedSnapshot,
    this.errorCode,
    this.errorMessage,
    this.userNotice,
  });

  NutritionThaliState copyWith({
    NutritionThaliStatus? status,
    Object? draft = _nutritionThaliUnset,
    Object? preview = _nutritionThaliUnset,
    List<NutritionThaliFoodOption>? foodResults,
    List<NutritionThaliRecipeOption>? recipeResults,
    List<NutritionHouseholdMeasureDefinition>? standardMeasures,
    List<NutritionPersonalVessel>? personalVessels,
    String? query,
    bool? dirty,
    bool? partialAcknowledged,
    bool? unknownEnergyAcknowledged,
    Set<String>? acknowledgedConstraintIds,
    Object? savedSnapshot = _nutritionThaliUnset,
    Object? errorCode = _nutritionThaliUnset,
    Object? errorMessage = _nutritionThaliUnset,
    Object? userNotice = _nutritionThaliUnset,
  }) => NutritionThaliState(
    status: status ?? this.status,
    draft: draft == _nutritionThaliUnset
        ? this.draft
        : draft as NutritionThaliDraft?,
    preview: preview == _nutritionThaliUnset
        ? this.preview
        : preview as NutritionThaliPreview?,
    foodResults: foodResults ?? this.foodResults,
    recipeResults: recipeResults ?? this.recipeResults,
    standardMeasures: standardMeasures ?? this.standardMeasures,
    personalVessels: personalVessels ?? this.personalVessels,
    query: query ?? this.query,
    dirty: dirty ?? this.dirty,
    partialAcknowledged: partialAcknowledged ?? this.partialAcknowledged,
    unknownEnergyAcknowledged:
        unknownEnergyAcknowledged ?? this.unknownEnergyAcknowledged,
    acknowledgedConstraintIds: acknowledgedConstraintIds == null
        ? this.acknowledgedConstraintIds
        : Set.unmodifiable(acknowledgedConstraintIds),
    savedSnapshot: savedSnapshot == _nutritionThaliUnset
        ? this.savedSnapshot
        : savedSnapshot as NutritionConsumptionSnapshot?,
    errorCode: errorCode == _nutritionThaliUnset
        ? this.errorCode
        : errorCode as String?,
    errorMessage: errorMessage == _nutritionThaliUnset
        ? this.errorMessage
        : errorMessage as String?,
    userNotice: userNotice == _nutritionThaliUnset
        ? this.userNotice
        : userNotice as String?,
  );
}

const _nutritionThaliUnset = Object();

/// Owns the complete thali draft lifecycle. Widgets submit typed intents and
/// render this state; they do not resolve quantities or write to Drift.
class NutritionThaliController extends StateNotifier<NutritionThaliState> {
  final Future<NutritionThaliRepository> _repositoryFuture;
  final String userId;
  final String mealCategory;
  final ThaliPresetUsage? _presetUsage;
  final Uuid _uuid;

  /// The preset this draft started from, counted towards "your usual" once
  /// the thali is logged.
  String? _presetId;
  String? _commandId;
  String? _consumptionId;
  NutritionConstraintAcknowledgement? _acknowledgement;
  _NutritionThaliFinalizeContext? _finalizeContext;
  String? _draftIdForRetry;
  _NutritionThaliRetryAction _retryAction = _NutritionThaliRetryAction.none;
  Timer? _previewDebounceTimer;

  NutritionThaliController({
    required Future<NutritionThaliRepository> repository,
    required this.userId,
    required this.mealCategory,
    ThaliPresetUsage? presetUsage,
    Uuid? uuid,
  }) : _repositoryFuture = repository,
       _presetUsage = presetUsage,
       _uuid = uuid ?? const Uuid(),
       super(const NutritionThaliState());

  @override
  void dispose() {
    _previewDebounceTimer?.cancel();
    super.dispose();
  }

  void _scheduleDebouncedPreview() {
    _previewDebounceTimer?.cancel();
    if (state.draft == null || state.draft!.items.isEmpty) return;
    _previewDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && state.draft?.items.isNotEmpty == true) {
        unawaited(preview());
      }
    });
  }

  Future<void> initialize() async {
    state = state.copyWith(
      status: NutritionThaliStatus.loading,
      errorCode: null,
      errorMessage: null,
    );
    try {
      final repository = await _repositoryFuture;
      final measures = await Future.wait([
        repository.listStandardMeasures(),
        repository.listActiveVessels(userId: userId),
      ]);
      final draft = repository.newDraft(userId: userId);
      state = state.copyWith(
        standardMeasures:
            measures[0] as List<NutritionHouseholdMeasureDefinition>,
        personalVessels: measures[1] as List<NutritionPersonalVessel>,
      );
      _setDraft(draft, dirty: true);
    } catch (error) {
      _fail(error, action: _NutritionThaliRetryAction.initialize);
    }
  }

  Future<void> loadDraft(String thaliId) async {
    _draftIdForRetry = thaliId;
    _presetId = null;
    state = state.copyWith(
      status: NutritionThaliStatus.loading,
      errorCode: null,
      errorMessage: null,
    );
    try {
      final draft = await (await _repositoryFuture).getDraft(
        userId: userId,
        thaliId: thaliId,
      );
      if (draft == null) {
        throw const NutritionThaliNotFoundError(
          'thali_not_found',
          'The saved meal is no longer available.',
        );
      }
      final repository = await _repositoryFuture;
      final measures = await Future.wait([
        repository.listStandardMeasures(),
        repository.listActiveVessels(userId: userId),
      ]);
      state = state.copyWith(
        standardMeasures:
            measures[0] as List<NutritionHouseholdMeasureDefinition>,
        personalVessels: measures[1] as List<NutritionPersonalVessel>,
      );
      _setDraft(draft, dirty: false);
    } catch (error) {
      _fail(error, action: _NutritionThaliRetryAction.loadDraft);
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(
      status: NutritionThaliStatus.searching,
      query: query,
      errorCode: null,
      errorMessage: null,
    );
    if (query.trim().isEmpty) {
      state = state.copyWith(
        status: NutritionThaliStatus.ready,
        foodResults: const [],
        recipeResults: const [],
      );
      return;
    }
    try {
      final repository = await _repositoryFuture;
      final results = await Future.wait([
        repository.searchFoods(query: query),
        repository.searchRecipes(userId: userId, query: query),
      ]);
      state = state.copyWith(
        status: NutritionThaliStatus.ready,
        foodResults: results[0] as List<NutritionThaliFoodOption>,
        recipeResults: results[1] as List<NutritionThaliRecipeOption>,
      );
    } catch (error) {
      _fail(error, action: _NutritionThaliRetryAction.search);
    }
  }

  void setName(String name) {
    final draft = state.draft;
    if (draft == null) return;
    _setDraft(draft.copyWith(name: name), dirty: true, clearPreview: true);
  }

  void addFood(NutritionThaliFoodOption option, {Quantity? quantity}) {
    final draft = state.draft;
    if (draft == null) return;
    final amount =
        quantity ??
        option.defaultQuantity ??
        Quantity.fromNum(amount: 100, unit: QuantityUnit.gram);
    final item = NutritionThaliItem(
      id: 'thali-item-v1-${_uuid.v4()}',
      position: draft.items.length,
      source: NutritionThaliItemSource.food,
      foodId: option.id,
      recipeVersionId: null,
      quantity: amount,
      measureId: _measureIdOf(amount),
      displayLabel: option.displayName,
    );
    _setDraft(
      draft.copyWith(items: [...draft.items, item]),
      dirty: true,
      clearPreview: true,
    );
    _clearSearchResults();
  }

  void addRecipe(NutritionThaliRecipeOption option, {Quantity? quantity}) {
    final draft = state.draft;
    if (draft == null) return;
    final item = NutritionThaliItem(
      id: 'thali-item-v1-${_uuid.v4()}',
      position: draft.items.length,
      source: NutritionThaliItemSource.recipe,
      foodId: null,
      recipeVersionId: option.recipeVersionId,
      quantity:
          quantity ??
          Quantity(
            amount: QuantityAmount.one,
            unit: QuantityUnit.serving,
            context: QuantityContext(
              servingDefinition: ServingDefinitionReference(
                id: 'recipe-complete:${option.recipeVersionId}',
                revision: 'recipe-version',
                source: 'recipe_version',
              ),
            ),
          ),
      displayLabel: option.recipeName,
    );
    _setDraft(
      draft.copyWith(items: [...draft.items, item]),
      dirty: true,
      clearPreview: true,
    );
    _clearSearchResults();
  }

  void removeItem(String itemId) {
    final draft = state.draft;
    if (draft == null) return;
    final remaining = draft.items
        .where((item) => item.id != itemId)
        .toList(growable: false);
    _setDraft(
      draft.copyWith(items: _reposition(remaining)),
      dirty: true,
      clearPreview: true,
    );
  }

  void reorderItem(int oldIndex, int newIndex) {
    final draft = state.draft;
    if (draft == null || oldIndex < 0 || oldIndex >= draft.items.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= draft.items.length) return;
    final items = draft.items.toList();
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    _setDraft(
      draft.copyWith(items: _reposition(items)),
      dirty: true,
      clearPreview: true,
    );
  }

  void setQuantity(String itemId, Quantity quantity, {String? measureId}) {
    final draft = state.draft;
    if (draft == null) return;
    try {
      NutritionQuantityService.validatePositiveConsumedQuantity(quantity);
      final items = draft.items
          .map((item) {
            if (item.id != itemId) return item;
            return NutritionThaliItem(
              id: item.id,
              position: item.position,
              source: item.source,
              foodId: item.foodId,
              recipeVersionId: item.recipeVersionId,
              quantity: quantity,
              measureId: quantity.unit == QuantityUnit.householdReference
                  ? measureId ?? item.measureId
                  : null,
              optional: item.optional,
              notes: item.notes,
              displayLabel: item.displayLabel,
            );
          })
          .toList(growable: false);
      if (items.every((item) => item.id != itemId)) {
        throw const NutritionThaliValidationError(
          'item_not_found',
          'The meal item is no longer present.',
        );
      }
      _setDraft(draft.copyWith(items: items), dirty: true, clearPreview: true);
    } catch (error) {
      _fail(error, action: _NutritionThaliRetryAction.none);
    }
  }

  void incrementQuantity(String itemId, {double? step}) {
    final draft = state.draft;
    if (draft == null) return;
    NutritionThaliItem? item;
    for (final i in draft.items) {
      if (i.id == itemId) {
        item = i;
        break;
      }
    }
    if (item == null) return;
    final currentAmount = item.quantity.amount.asDouble;
    final newAmount = currentAmount + (step ?? _stepFor(item.quantity));
    setQuantity(
      itemId,
      Quantity(
        amount: QuantityAmount.fromNum(newAmount),
        unit: item.quantity.unit,
        context: item.quantity.context,
      ),
      measureId: item.measureId,
    );
  }

  void decrementQuantity(String itemId, {double? step, double? min}) {
    final draft = state.draft;
    if (draft == null) return;
    NutritionThaliItem? item;
    for (final i in draft.items) {
      if (i.id == itemId) {
        item = i;
        break;
      }
    }
    if (item == null) return;
    final currentAmount = item.quantity.amount.asDouble;
    final unitStep = step ?? _stepFor(item.quantity);
    final floor = min ?? unitStep;
    if (currentAmount <= floor) return;
    final newAmount = (currentAmount - unitStep).clamp(floor, double.infinity);
    setQuantity(
      itemId,
      Quantity(
        amount: QuantityAmount.fromNum(newAmount),
        unit: item.quantity.unit,
        context: item.quantity.context,
      ),
      measureId: item.measureId,
    );
  }

  void acknowledgeUnknownEnergy(bool acknowledged) {
    state = state.copyWith(unknownEnergyAcknowledged: acknowledged);
  }

  void acknowledgePartial(bool acknowledged) {
    state = state.copyWith(partialAcknowledged: acknowledged);
  }

  void acknowledgeConstraints(Iterable<String> constraintIds) {
    _resetCommand();
    state = state.copyWith(
      acknowledgedConstraintIds: constraintIds.toSet(),
      preview: null,
      status: NutritionThaliStatus.ready,
      errorCode: null,
      errorMessage: null,
    );
  }

  Future<void> saveDraft() async {
    final draft = state.draft;
    if (draft == null) return;
    _retryAction = _NutritionThaliRetryAction.save;
    state = state.copyWith(
      status: NutritionThaliStatus.saving,
      errorCode: null,
      errorMessage: null,
    );
    try {
      final saved = await (await _repositoryFuture).saveDraft(draft);
      _setDraft(saved, dirty: false, clearPreview: true);
    } catch (error) {
      _fail(error, action: _NutritionThaliRetryAction.save);
    }
  }

  Future<void> preview() async {
    final draft = state.draft;
    if (draft == null) return;
    _retryAction = _NutritionThaliRetryAction.preview;
    state = state.copyWith(
      status: NutritionThaliStatus.previewLoading,
      errorCode: null,
      errorMessage: null,
    );
    try {
      final repository = await _repositoryFuture;
      var persisted = draft;
      if (state.dirty) {
        persisted = await repository.saveDraft(draft);
        if (!mounted) return;
        _setDraft(persisted, dirty: false, preserveStatus: true);
      }
      final preview = await repository.preview(
        draft: persisted,
        acknowledgedConstraintIds: state.acknowledgedConstraintIds,
      );
      if (!mounted) return;
      state = state.copyWith(
        status: NutritionThaliStatus.previewReady,
        draft: persisted,
        preview: preview,
        dirty: false,
        errorCode: null,
        errorMessage: null,
      );
    } catch (error) {
      if (!mounted) return;
      _fail(error, action: _NutritionThaliRetryAction.preview);
    }
  }

  Future<NutritionConsumptionSnapshot?> finalize({
    required DateTime loggedAt,
    String? mealGroupId,
    required String localDate,
    required String timezoneId,
    bool allowPartial = true,
  }) async {
    final preview = state.preview;
    if (preview == null || state.dirty) {
      _fail(
        const NutritionThaliValidationError(
          'missing_preview',
          'Preview the complete meal before logging it.',
        ),
        action: _NutritionThaliRetryAction.preview,
      );
      return null;
    }

    final categoryPresentation = MealPresentationRegistry.forStableId(
      mealCategory,
    );
    if (!categoryPresentation.isKnown) {
      _fail(
        const NutritionThaliValidationError(
          'invalid_meal_category',
          'The specified meal category is invalid or unsupported.',
        ),
        action: _NutritionThaliRetryAction.finalize,
      );
      return null;
    }

    final effectiveMealGroupId =
        (mealGroupId != null && mealGroupId.trim().isNotEmpty)
        ? mealGroupId.trim()
        : 'meal-group:${_uuid.v4()}';

    _commandId ??= 'thali-log:${_uuid.v4()}';
    _consumptionId ??= 'thali-consumption:${_uuid.v4()}';
    if (_acknowledgement == null &&
        state.acknowledgedConstraintIds.isNotEmpty &&
        preview.constraintEvaluation != null) {
      final acknowledgedIds = preview.constraintEvaluation!.evaluations
          .where(
            (item) =>
                state.acknowledgedConstraintIds.contains(item.constraintId),
          )
          .map((item) => item.constraintId)
          .toList(growable: false);
      final acknowledgedId = acknowledgedIds.isEmpty
          ? null
          : acknowledgedIds.first;
      if (acknowledgedId != null) {
        _acknowledgement = NutritionConstraintAcknowledgement(
          commandId: _commandId!,
          userId: userId,
          evaluationFingerprint: preview.constraintEvaluation!.fingerprint,
          constraintId: acknowledgedId,
          reason: 'User acknowledged the meal dietary evaluation.',
          acknowledgedAtUtc: loggedAt,
        );
      }
    }
    _finalizeContext ??= _NutritionThaliFinalizeContext(
      loggedAt: loggedAt,
      mealGroupId: effectiveMealGroupId,
      localDate: localDate,
      timezoneId: timezoneId,
    );
    _retryAction = _NutritionThaliRetryAction.finalize;
    state = state.copyWith(
      status: NutritionThaliStatus.finalizing,
      errorCode: null,
      errorMessage: null,
    );
    try {
      final context = _finalizeContext!;
      final saved = await (await _repositoryFuture).finalize(
        preview: preview,
        mealCategory: categoryPresentation.stableId,
        loggedAt: context.loggedAt,
        commandId: _commandId!,
        consumptionId: _consumptionId,
        mealGroupId: context.mealGroupId,
        localDate: context.localDate,
        timezoneId: context.timezoneId,
        allowPartial: allowPartial || state.partialAcknowledged,
        allowUnknownEnergy: state.unknownEnergyAcknowledged,
        acknowledgement: _acknowledgement,
      );
      state = state.copyWith(
        status: NutritionThaliStatus.success,
        savedSnapshot: saved,
        errorCode: null,
        errorMessage: null,
      );
      final presetId = _presetId;
      if (presetId != null) {
        try {
          await _presetUsage?.recordLogged(presetId);
        } on Object catch (error, stackTrace) {
          // The meal is logged; only the "usual thali" hint is affected.
          AppLogger.error(
            'Recording thali preset use failed',
            error,
            stackTrace,
          );
        }
      }
      return saved;
    } catch (error) {
      _fail(error, action: _NutritionThaliRetryAction.finalize);
      return null;
    }
  }

  Future<NutritionConsumptionSnapshot?> logThali({
    required DateTime loggedAt,
    String? mealGroupId,
    required String localDate,
    required String timezoneId,
    bool saveAsTemplate = false,
    bool allowPartial = true,
  }) async {
    if (saveAsTemplate) {
      await saveDraft();
      if (state.status == NutritionThaliStatus.failure) {
        return null;
      }
    }
    if (state.preview == null || state.dirty) {
      await preview();
      if (state.status == NutritionThaliStatus.failure) {
        return null;
      }
    }
    return await finalize(
      loggedAt: loggedAt,
      mealGroupId: mealGroupId,
      localDate: localDate,
      timezoneId: timezoneId,
      allowPartial: allowPartial,
    );
  }

  /// Fills an empty new thali from the user's most-logged preset. Does
  /// nothing when nothing has been logged from a preset yet, or when the
  /// plate already has items (a saved draft or an AI handoff).
  Future<void> startFromUsual() async {
    final usual = _presetUsage?.mostUsed();
    final draft = state.draft;
    if (usual == null || draft == null || draft.items.isNotEmpty) return;
    await loadPreset(
      presetName: usual.name,
      items: usual.items,
      presetId: usual.id,
    );
    if (state.draft?.items.isNotEmpty == true) {
      final missing = state.userNotice;
      state = state.copyWith(
        userNotice: missing == null
            ? 'Started from your usual: ${usual.name}'
            : 'Started from your usual: ${usual.name}. $missing',
      );
    }
  }

  /// Empties the plate, e.g. after it was pre-filled from "your usual".
  void clearItems() {
    final draft = state.draft;
    if (draft == null || draft.items.isEmpty) return;
    _presetId = null;
    _setDraft(draft.copyWith(items: const []), dirty: true, clearPreview: true);
  }

  Future<void> loadPreset({
    required String presetName,
    required List<ThaliPresetItemDefinition> items,
    String? presetId,
  }) async {
    state = state.copyWith(
      status: NutritionThaliStatus.loading,
      errorCode: null,
      errorMessage: null,
      userNotice: null,
    );
    try {
      final repository = await _repositoryFuture;
      final addedItems = <NutritionThaliItem>[];
      final missingNames = <String>[];

      for (final def in items) {
        final food = await repository.findFoodBySourceRef(def.foodSourceRef);
        final quantity = food == null
            ? null
            : await repository.ownUnitQuantity(food.id, def.amount);
        if (food == null || quantity == null) {
          missingNames.add(def.displayName);
          continue;
        }
        addedItems.add(
          NutritionThaliItem(
            id: 'thali-item-v1-${_uuid.v4()}',
            position: addedItems.length,
            source: NutritionThaliItemSource.food,
            foodId: food.id,
            recipeVersionId: null,
            quantity: quantity,
            measureId: _measureIdOf(quantity),
            displayLabel: food.displayName,
          ),
        );
      }

      final currentDraft = state.draft ?? repository.newDraft(userId: userId);
      final draft = currentDraft.copyWith(name: presetName, items: addedItems);

      String? notice;
      if (missingNames.isNotEmpty) {
        if (addedItems.isEmpty) {
          notice =
              'Could not find preset items in the database. Please add items manually.';
        } else {
          notice =
              'Added ${addedItems.length} items. Missing from food library: ${missingNames.join(", ")}.';
        }
      }

      _setDraft(draft, dirty: true, clearPreview: true);
      _presetId = addedItems.isEmpty ? null : presetId;
      state = state.copyWith(userNotice: notice);

      if (addedItems.isNotEmpty) {
        await preview();
      }
    } catch (error) {
      _fail(error, action: _NutritionThaliRetryAction.none);
    }
  }

  /// Grams and millilitres move in 10s; rotis, katoris and servings in ½s.
  static double _stepFor(Quantity quantity) =>
      quantity.dimension == QuantityDimension.mass ||
          quantity.dimension == QuantityDimension.volume
      ? 10
      : 0.5;

  /// A household amount names its vessel; the item keeps that id so the
  /// thali can resolve it (a bare household quantity can't be calculated).
  static String? _measureIdOf(Quantity quantity) =>
      quantity.unit == QuantityUnit.householdReference
      ? quantity.context.householdMeasure?.measureType
      : null;

  void clearNotice() {
    state = state.copyWith(userNotice: null);
  }

  Future<void> retry({
    DateTime? loggedAt,
    String? mealGroupId,
    String? localDate,
    String? timezoneId,
  }) async {
    switch (_retryAction) {
      case _NutritionThaliRetryAction.initialize:
        await initialize();
      case _NutritionThaliRetryAction.loadDraft:
        final id = _draftIdForRetry ?? state.draft?.id;
        if (id != null) await loadDraft(id);
      case _NutritionThaliRetryAction.search:
        await search(state.query);
      case _NutritionThaliRetryAction.save:
        await saveDraft();
      case _NutritionThaliRetryAction.preview:
        await preview();
      case _NutritionThaliRetryAction.finalize:
        final storedDate = localDate ?? _finalizeContext?.localDate;
        final storedTimezone = timezoneId ?? _finalizeContext?.timezoneId;
        if (storedDate == null || storedTimezone == null) {
          _fail(
            const NutritionThaliValidationError(
              'missing_local_time_context',
              'Retry requires the original local date and timezone.',
            ),
            action: _NutritionThaliRetryAction.finalize,
          );
          return;
        }
        await finalize(
          loggedAt: loggedAt ?? _finalizeContext?.loggedAt ?? DateTime.now(),
          mealGroupId: mealGroupId ?? _finalizeContext?.mealGroupId,
          localDate: storedDate,
          timezoneId: storedTimezone,
        );
      case _NutritionThaliRetryAction.none:
        break;
    }
  }

  Future<void> clearDraft() async {
    state = state.copyWith(
      status: NutritionThaliStatus.loading,
      errorCode: null,
      errorMessage: null,
    );
    try {
      final repository = await _repositoryFuture;
      _resetCommand();
      _setDraft(repository.newDraft(userId: userId), dirty: true);
    } catch (error) {
      _fail(error, action: _NutritionThaliRetryAction.initialize);
    }
  }

  void _setDraft(
    NutritionThaliDraft draft, {
    required bool dirty,
    bool clearPreview = false,
    bool preserveStatus = false,
  }) {
    _resetCommand();
    state = state.copyWith(
      status: preserveStatus ? state.status : NutritionThaliStatus.ready,
      draft: draft,
      dirty: dirty,
      // A changed plate needs a fresh decision about unknown calories.
      unknownEnergyAcknowledged: clearPreview
          ? false
          : state.unknownEnergyAcknowledged,
      preview: clearPreview ? null : state.preview,
      savedSnapshot: clearPreview ? null : state.savedSnapshot,
      errorCode: null,
      errorMessage: null,
    );
    if (dirty && draft.items.isNotEmpty) {
      _scheduleDebouncedPreview();
    }
  }

  void _clearSearchResults() {
    state = state.copyWith(
      query: '',
      foodResults: const [],
      recipeResults: const [],
    );
  }

  List<NutritionThaliItem> _reposition(Iterable<NutritionThaliItem> items) => [
    for (var index = 0; index < items.length; index++)
      items.elementAt(index).copyWith(position: index),
  ];

  void _fail(Object error, {required _NutritionThaliRetryAction action}) {
    if (!mounted) return;
    _retryAction = action;
    final code = error is NutritionThaliError
        ? error.code
        : error is NutritionConstraintError
        ? error.code
        : error is QuantityError
        ? 'invalid_quantity'
        : 'thali_operation_failed';
    final message = ProductFailurePresentation.fromCode(code).message;
    state = state.copyWith(
      status: NutritionThaliStatus.failure,
      errorCode: code,
      errorMessage: message,
    );
  }

  void _resetCommand() {
    _commandId = null;
    _consumptionId = null;
    _acknowledgement = null;
    _finalizeContext = null;
  }
}

enum _NutritionThaliRetryAction {
  none,
  initialize,
  loadDraft,
  search,
  save,
  preview,
  finalize,
}

class _NutritionThaliFinalizeContext {
  final DateTime loggedAt;
  final String? mealGroupId;
  final String localDate;
  final String timezoneId;

  const _NutritionThaliFinalizeContext({
    required this.loggedAt,
    required this.mealGroupId,
    required this.localDate,
    required this.timezoneId,
  });
}
