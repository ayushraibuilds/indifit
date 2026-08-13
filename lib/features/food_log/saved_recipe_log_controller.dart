import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrition_calculation_service.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/typed_quantities.dart';
import '../../data/repositories/nutrition_recipe_log_coordinator.dart';
import '../../data/repositories/nutrition_recipe_repository.dart';

enum SavedRecipeLogStatus {
  idle,
  loadingRecipes,
  ready,
  loadingSelection,
  loadingPreview,
  previewReady,
  finalizing,
  success,
  failure,
}

class SavedRecipeLogState {
  final SavedRecipeLogStatus status;
  final List<NutritionRecipeModel> recipes;
  final List<NutritionRecipeDraftModel> drafts;
  final List<NutritionRecipeVersionModel> versions;
  final String query;
  final NutritionRecipeModel? selectedRecipe;
  final NutritionRecipeVersionModel? selectedVersion;
  final NutritionRecipeLogAmountKind amountKind;
  final String amountText;
  final NutritionRecipeLogPreview? preview;
  final NutritionConsumptionSnapshot? savedSnapshot;
  final bool partialAcknowledged;
  final String? errorCode;
  final String? errorMessage;

  const SavedRecipeLogState({
    this.status = SavedRecipeLogStatus.idle,
    this.recipes = const [],
    this.drafts = const [],
    this.versions = const [],
    this.query = '',
    this.selectedRecipe,
    this.selectedVersion,
    this.amountKind = NutritionRecipeLogAmountKind.wholeRecipe,
    this.amountText = '1',
    this.preview,
    this.savedSnapshot,
    this.partialAcknowledged = false,
    this.errorCode,
    this.errorMessage,
  });

  SavedRecipeLogState copyWith({
    SavedRecipeLogStatus? status,
    List<NutritionRecipeModel>? recipes,
    List<NutritionRecipeDraftModel>? drafts,
    List<NutritionRecipeVersionModel>? versions,
    String? query,
    Object? selectedRecipe = _unset,
    Object? selectedVersion = _unset,
    NutritionRecipeLogAmountKind? amountKind,
    String? amountText,
    Object? preview = _unset,
    Object? savedSnapshot = _unset,
    bool? partialAcknowledged,
    Object? errorCode = _unset,
    Object? errorMessage = _unset,
  }) => SavedRecipeLogState(
    status: status ?? this.status,
    recipes: recipes ?? this.recipes,
    drafts: drafts ?? this.drafts,
    versions: versions ?? this.versions,
    query: query ?? this.query,
    selectedRecipe: selectedRecipe == _unset
        ? this.selectedRecipe
        : selectedRecipe as NutritionRecipeModel?,
    selectedVersion: selectedVersion == _unset
        ? this.selectedVersion
        : selectedVersion as NutritionRecipeVersionModel?,
    amountKind: amountKind ?? this.amountKind,
    amountText: amountText ?? this.amountText,
    preview: preview == _unset
        ? this.preview
        : preview as NutritionRecipeLogPreview?,
    savedSnapshot: savedSnapshot == _unset
        ? this.savedSnapshot
        : savedSnapshot as NutritionConsumptionSnapshot?,
    partialAcknowledged: partialAcknowledged ?? this.partialAcknowledged,
    errorCode: errorCode == _unset ? this.errorCode : errorCode as String?,
    errorMessage: errorMessage == _unset
        ? this.errorMessage
        : errorMessage as String?,
  );
}

const _unset = Object();

/// Owns saved-recipe logging state transitions; widgets only render state.
class SavedRecipeLogController extends StateNotifier<SavedRecipeLogState> {
  final Future<NutritionRecipeLogCoordinator> _coordinatorFuture;
  final String userId;
  final Uuid _uuid;
  String? _commandId;
  String? _consumptionId;
  _SavedRecipeFinalizeContext? _pendingFinalization;

  SavedRecipeLogController({
    required Future<NutritionRecipeLogCoordinator> coordinator,
    required this.userId,
    Uuid? uuid,
  }) : _coordinatorFuture = coordinator,
       _uuid = uuid ?? const Uuid(),
       super(const SavedRecipeLogState());

  Future<void> loadRecipes({String? query}) async {
    final nextQuery = query ?? state.query;
    state = state.copyWith(
      status: SavedRecipeLogStatus.loadingRecipes,
      query: nextQuery,
      errorCode: null,
      errorMessage: null,
    );
    try {
      final recipes = await (await _coordinatorFuture).listSavedRecipes(
        userId: userId,
        query: nextQuery,
      );
      final drafts = await (await _coordinatorFuture).listDrafts(
        userId: userId,
        query: nextQuery,
      );
      state = state.copyWith(
        status: SavedRecipeLogStatus.ready,
        recipes: recipes,
        drafts: drafts,
        query: nextQuery,
        errorCode: null,
        errorMessage: null,
      );
    } catch (error) {
      _fail(error, fallbackCode: 'recipe_load_failed');
    }
  }

  Future<void> selectRecipe(NutritionRecipeModel recipe) async {
    _resetCommand();
    state = state.copyWith(
      status: SavedRecipeLogStatus.loadingSelection,
      selectedRecipe: recipe,
      selectedVersion: null,
      versions: const [],
      preview: null,
      savedSnapshot: null,
      errorCode: null,
      errorMessage: null,
      partialAcknowledged: false,
    );
    try {
      final versions = await (await _coordinatorFuture).listLoggableVersions(
        recipeId: recipe.id,
        userId: userId,
      );
      if (versions.isEmpty) {
        throw const NutritionRecipeLogError(
          'unpublished_recipe',
          'This saved recipe has no published version available for logging.',
        );
      }
      final selected = versions.firstWhere(
        (version) => version.id == recipe.currentVersionId,
        orElse: () => versions.first,
      );
      state = state.copyWith(
        status: SavedRecipeLogStatus.ready,
        versions: versions,
        selectedVersion: selected,
        amountKind: NutritionRecipeLogAmountKind.wholeRecipe,
        amountText: '1',
        errorCode: null,
        errorMessage: null,
      );
    } catch (error) {
      _fail(error, fallbackCode: 'recipe_selection_failed');
    }
  }

  void clearSelection() {
    _resetCommand();
    state = state.copyWith(
      status: SavedRecipeLogStatus.ready,
      selectedRecipe: null,
      selectedVersion: null,
      versions: const [],
      preview: null,
      savedSnapshot: null,
      errorCode: null,
      errorMessage: null,
      partialAcknowledged: false,
    );
  }

  void selectVersion(NutritionRecipeVersionModel version) {
    if (version.status != NutritionRecipeVersionStatus.published) {
      _fail(
        const NutritionRecipeLogError(
          'unpublished_recipe_version',
          'Draft and archived versions cannot be logged.',
        ),
        fallbackCode: 'unpublished_recipe_version',
      );
      return;
    }
    _resetCommand();
    state = state.copyWith(
      selectedVersion: version,
      preview: null,
      savedSnapshot: null,
      status: SavedRecipeLogStatus.ready,
      errorCode: null,
      errorMessage: null,
      partialAcknowledged: false,
    );
  }

  void setAmountKind(NutritionRecipeLogAmountKind kind) {
    _resetCommand();
    final defaultText = switch (kind) {
      NutritionRecipeLogAmountKind.wholeRecipe => '1',
      NutritionRecipeLogAmountKind.declaredServing => '1',
      NutritionRecipeLogAmountKind.fraction =>
        state.amountText == '1' ? '0.5' : state.amountText,
      NutritionRecipeLogAmountKind.scalar => state.amountText,
    };
    state = state.copyWith(
      amountKind: kind,
      amountText: defaultText,
      preview: null,
      status: SavedRecipeLogStatus.ready,
      errorCode: null,
      errorMessage: null,
      partialAcknowledged: false,
    );
  }

  void setAmountText(String value) {
    _resetCommand();
    state = state.copyWith(
      amountText: value,
      preview: null,
      status: SavedRecipeLogStatus.ready,
      errorCode: null,
      errorMessage: null,
      partialAcknowledged: false,
    );
  }

  void acknowledgePartial(bool value) {
    state = state.copyWith(partialAcknowledged: value);
  }

  Future<void> preview() async {
    final recipe = state.selectedRecipe;
    final version = state.selectedVersion;
    if (recipe == null || version == null) {
      _fail(
        const NutritionRecipeLogError(
          'missing_recipe_selection',
          'Select a published saved recipe before previewing.',
        ),
        fallbackCode: 'missing_recipe_selection',
      );
      return;
    }
    state = state.copyWith(
      status: SavedRecipeLogStatus.loadingPreview,
      preview: null,
      errorCode: null,
      errorMessage: null,
    );
    try {
      final amount = _amountFromState();
      final preview = await (await _coordinatorFuture).preview(
        userId: userId,
        recipeId: recipe.id,
        recipeVersionId: version.id,
        amount: amount,
      );
      state = state.copyWith(
        status: SavedRecipeLogStatus.previewReady,
        preview: preview,
        errorCode: null,
        errorMessage: null,
        partialAcknowledged: false,
      );
    } catch (error) {
      _fail(error, fallbackCode: 'preview_failed');
    }
  }

  Future<void> finalize({
    required String mealCategory,
    required DateTime loggedAt,
    String? mealGroupId,
    required String localDate,
    required String timezoneId,
  }) async {
    final preview = state.preview;
    if (preview == null) {
      _fail(
        const NutritionRecipeLogError(
          'missing_preview',
          'Preview the selected recipe before saving.',
        ),
        fallbackCode: 'missing_preview',
      );
      return;
    }
    _commandId ??= 'recipe-log:${_uuid.v4()}';
    _consumptionId ??= 'recipe-consumption:${_uuid.v4()}';
    final finalization = _pendingFinalization ??= _SavedRecipeFinalizeContext(
      mealCategory: mealCategory,
      loggedAt: loggedAt,
      mealGroupId: mealGroupId,
      localDate: localDate,
      timezoneId: timezoneId,
    );
    state = state.copyWith(
      status: SavedRecipeLogStatus.finalizing,
      errorCode: null,
      errorMessage: null,
    );
    try {
      final saved = await (await _coordinatorFuture).finalize(
        userId: userId,
        preview: preview,
        mealCategory: finalization.mealCategory,
        loggedAt: finalization.loggedAt,
        mealGroupId: finalization.mealGroupId,
        localDate: finalization.localDate,
        timezoneId: finalization.timezoneId,
        consumptionId: _consumptionId,
        commandId: _commandId!,
        allowPartial: state.partialAcknowledged,
      );
      state = state.copyWith(
        status: SavedRecipeLogStatus.success,
        savedSnapshot: saved,
        errorCode: null,
        errorMessage: null,
      );
    } catch (error) {
      _fail(error, fallbackCode: 'finalization_failed');
    }
  }

  Future<void> retryFinalize({
    required String mealCategory,
    required DateTime loggedAt,
    String? mealGroupId,
    required String localDate,
    required String timezoneId,
  }) => finalize(
    mealCategory: mealCategory,
    loggedAt: loggedAt,
    mealGroupId: mealGroupId,
    localDate: localDate,
    timezoneId: timezoneId,
  );

  NutritionRecipeLogAmount _amountFromState() {
    try {
      return switch (state.amountKind) {
        NutritionRecipeLogAmountKind.wholeRecipe =>
          NutritionRecipeLogAmount.wholeRecipe(),
        NutritionRecipeLogAmountKind.declaredServing =>
          NutritionRecipeLogAmount.declaredServing(),
        NutritionRecipeLogAmountKind.fraction =>
          NutritionRecipeLogAmount.fraction(state.amountText),
        NutritionRecipeLogAmountKind.scalar => NutritionRecipeLogAmount.scalar(
          state.amountText,
        ),
      };
    } on NutritionRecipeLogError {
      rethrow;
    } on QuantityError catch (error) {
      throw NutritionRecipeLogError(
        'invalid_amount',
        ProductFailurePresentation.fromCode('invalid_amount').message,
        cause: error,
      );
    }
  }

  void _fail(Object error, {required String fallbackCode}) {
    final code = error is NutritionRecipeLogError
        ? error.code
        : error is NutritionCalculationError
        ? error.code
        : fallbackCode;
    final message = ProductFailurePresentation.fromCode(code).message;
    state = state.copyWith(
      status: SavedRecipeLogStatus.failure,
      errorCode: code,
      errorMessage: message,
    );
  }

  void _resetCommand() {
    _commandId = null;
    _consumptionId = null;
    _pendingFinalization = null;
  }
}

/// The finalization payload is part of the idempotency identity. Keep the
/// first accepted values for the lifetime of the pending log intent so a
/// retry cannot drift across a clock tick, local-date boundary, or rebuild.
class _SavedRecipeFinalizeContext {
  final String mealCategory;
  final DateTime loggedAt;
  final String? mealGroupId;
  final String localDate;
  final String timezoneId;

  const _SavedRecipeFinalizeContext({
    required this.mealCategory,
    required this.loggedAt,
    required this.mealGroupId,
    required this.localDate,
    required this.timezoneId,
  });
}
