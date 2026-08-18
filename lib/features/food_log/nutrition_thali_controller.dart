import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrition_constraints.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_thali.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/typed_quantities.dart';
import '../../data/repositories/nutrition_thali_repository.dart';

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
  final Set<String> acknowledgedConstraintIds;
  final NutritionConsumptionSnapshot? savedSnapshot;
  final String? errorCode;
  final String? errorMessage;

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
    this.acknowledgedConstraintIds = const {},
    this.savedSnapshot,
    this.errorCode,
    this.errorMessage,
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
    Set<String>? acknowledgedConstraintIds,
    Object? savedSnapshot = _nutritionThaliUnset,
    Object? errorCode = _nutritionThaliUnset,
    Object? errorMessage = _nutritionThaliUnset,
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
  );
}

const _nutritionThaliUnset = Object();

/// Owns the complete thali draft lifecycle. Widgets submit typed intents and
/// render this state; they do not resolve quantities or write to Drift.
class NutritionThaliController extends StateNotifier<NutritionThaliState> {
  final Future<NutritionThaliRepository> _repositoryFuture;
  final String userId;
  final String mealCategory;
  final Uuid _uuid;
  String? _commandId;
  String? _consumptionId;
  NutritionConstraintAcknowledgement? _acknowledgement;
  _NutritionThaliFinalizeContext? _finalizeContext;
  String? _draftIdForRetry;
  _NutritionThaliRetryAction _retryAction = _NutritionThaliRetryAction.none;

  NutritionThaliController({
    required Future<NutritionThaliRepository> repository,
    required this.userId,
    required this.mealCategory,
    Uuid? uuid,
  }) : _repositoryFuture = repository,
       _uuid = uuid ?? const Uuid(),
       super(const NutritionThaliState());

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
    final item = NutritionThaliItem(
      id: 'thali-item-v1-${_uuid.v4()}',
      position: draft.items.length,
      source: NutritionThaliItemSource.food,
      foodId: option.id,
      recipeVersionId: null,
      quantity:
          quantity ?? Quantity.fromNum(amount: 100, unit: QuantityUnit.gram),
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
        _setDraft(persisted, dirty: false, preserveStatus: true);
      }
      final preview = await repository.preview(
        draft: persisted,
        acknowledgedConstraintIds: state.acknowledgedConstraintIds,
      );
      state = state.copyWith(
        status: NutritionThaliStatus.previewReady,
        draft: persisted,
        preview: preview,
        dirty: false,
        errorCode: null,
        errorMessage: null,
      );
    } catch (error) {
      _fail(error, action: _NutritionThaliRetryAction.preview);
    }
  }

  Future<void> finalize({
    required DateTime loggedAt,
    String? mealGroupId,
    required String localDate,
    required String timezoneId,
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
      return;
    }
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
      mealGroupId: mealGroupId,
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
        mealCategory: mealCategory,
        loggedAt: context.loggedAt,
        commandId: _commandId!,
        consumptionId: _consumptionId,
        mealGroupId: context.mealGroupId,
        localDate: context.localDate,
        timezoneId: context.timezoneId,
        allowPartial: state.partialAcknowledged,
        acknowledgement: _acknowledgement,
      );
      state = state.copyWith(
        status: NutritionThaliStatus.success,
        savedSnapshot: saved,
        errorCode: null,
        errorMessage: null,
      );
    } catch (error) {
      _fail(error, action: _NutritionThaliRetryAction.finalize);
    }
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
      preview: clearPreview ? null : state.preview,
      savedSnapshot: clearPreview ? null : state.savedSnapshot,
      errorCode: null,
      errorMessage: null,
    );
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
