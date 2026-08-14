import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_thali.dart';
import '../../data/repositories/nutrition_thali_repository.dart';

enum SavedMealsStatus { idle, loading, ready, finalizing, success, failure }

class SavedMealDisplayItem {
  final NutritionThaliDraft draft;
  final int itemCount;
  final double? estimatedCalories;
  final double? estimatedProteinG;
  final String summary;
  final bool hasPartialNutrition;
  final bool requiresPartialAcknowledgement;
  final String? unavailableCode;
  final String? unavailableMessage;

  const SavedMealDisplayItem({
    required this.draft,
    required this.itemCount,
    this.estimatedCalories,
    this.estimatedProteinG,
    required this.summary,
    this.hasPartialNutrition = false,
    this.requiresPartialAcknowledgement = false,
    this.unavailableCode,
    this.unavailableMessage,
  });

  bool get isLoggable => unavailableMessage == null;
}

class SavedMealsState {
  final SavedMealsStatus status;
  final List<SavedMealDisplayItem> meals;
  final String query;
  final NutritionConsumptionSnapshot? lastSnapshot;
  final String? errorMessage;
  final String? errorCode;

  const SavedMealsState({
    this.status = SavedMealsStatus.idle,
    this.meals = const [],
    this.query = '',
    this.lastSnapshot,
    this.errorMessage,
    this.errorCode,
  });

  SavedMealsState copyWith({
    SavedMealsStatus? status,
    List<SavedMealDisplayItem>? meals,
    String? query,
    Object? lastSnapshot = _savedMealsUnset,
    Object? errorMessage = _savedMealsUnset,
    Object? errorCode = _savedMealsUnset,
  }) => SavedMealsState(
    status: status ?? this.status,
    meals: meals ?? this.meals,
    query: query ?? this.query,
    lastSnapshot: lastSnapshot == _savedMealsUnset
        ? this.lastSnapshot
        : lastSnapshot as NutritionConsumptionSnapshot?,
    errorMessage: errorMessage == _savedMealsUnset
        ? this.errorMessage
        : errorMessage as String?,
    errorCode: errorCode == _savedMealsUnset
        ? this.errorCode
        : errorCode as String?,
  );
}

const Object _savedMealsUnset = Object();

class SavedMealsController extends StateNotifier<SavedMealsState> {
  final Future<NutritionThaliRepository> _thaliRepoFuture;
  final String _userId;
  final Uuid _uuid;
  var _loadGeneration = 0;
  Future<NutritionConsumptionSnapshot?>? _inFlightLog;
  _SavedMealFinalization? _pendingFinalization;

  SavedMealsController({
    required Future<NutritionThaliRepository> thaliRepoFuture,
    required String userId,
    Uuid? uuid,
  }) : _thaliRepoFuture = thaliRepoFuture,
       _userId = userId,
       _uuid = uuid ?? const Uuid(),
       super(const SavedMealsState());

  Future<void> loadSavedMeals({String query = ''}) async {
    final generation = ++_loadGeneration;
    state = state.copyWith(
      status: SavedMealsStatus.loading,
      query: query,
      errorMessage: null,
      errorCode: null,
    );

    try {
      final thaliRepo = await _thaliRepoFuture;
      final drafts = await thaliRepo.listDrafts(
        userId: _userId,
        includeArchived: false,
      );

      final displayItems = <SavedMealDisplayItem>[];
      for (final draft in drafts) {
        if (query.trim().isNotEmpty &&
            !draft.name.toLowerCase().contains(query.trim().toLowerCase())) {
          continue;
        }

        final itemLabels = draft.items
            .map((item) => item.displayLabel ?? 'Item')
            .toList(growable: false);
        final summary = itemLabels.join(' · ');

        double? calories;
        double? protein;
        var hasPartialNutrition = false;
        var requiresPartialAcknowledgement = false;
        String? unavailableCode;
        String? unavailableMessage;
        try {
          final preview = await thaliRepo.preview(draft: draft);
          if (generation != _loadGeneration) return;
          final energy =
              preview.aggregate.facts['energy']?.point?.value.asDouble;
          final prot =
              preview.aggregate.facts['protein']?.point?.value.asDouble;
          calories = energy;
          protein = prot;
          hasPartialNutrition =
              preview.isPartial ||
              preview.isUnknown ||
              preview.hasUnresolvedInputs;
          requiresPartialAcknowledgement = _requiresAcknowledgementFor(preview);
        } catch (error) {
          unavailableCode = _errorCode(error);
          unavailableMessage =
              'This saved meal needs attention before it can be logged.';
        }

        displayItems.add(
          SavedMealDisplayItem(
            draft: draft,
            itemCount: draft.items.length,
            estimatedCalories: calories,
            estimatedProteinG: protein,
            summary: summary.isEmpty ? 'No items' : summary,
            hasPartialNutrition: hasPartialNutrition,
            requiresPartialAcknowledgement: requiresPartialAcknowledgement,
            unavailableCode: unavailableCode,
            unavailableMessage: unavailableMessage,
          ),
        );
      }

      if (generation != _loadGeneration) return;

      state = state.copyWith(
        status: SavedMealsStatus.ready,
        meals: displayItems,
      );
    } catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        status: SavedMealsStatus.failure,
        errorMessage: 'Could not load saved meals.',
        errorCode: _errorCode(error),
      );
    }
  }

  Future<NutritionConsumptionSnapshot?> logSavedMeal({
    required NutritionThaliDraft draft,
    required String mealCategory,
    required DateTime loggedAt,
    required String localDate,
    required String timezoneId,
    bool allowPartial = true,
  }) {
    final active = _inFlightLog;
    if (active != null) return active;

    final requested = _SavedMealFinalization(
      draft: draft,
      mealCategory: mealCategory,
      loggedAt: loggedAt,
      localDate: localDate,
      timezoneId: timezoneId,
      commandId: 'saved-meal-log::${_uuid.v4()}',
      consumptionId: 'saved-meal-consumption::${_uuid.v4()}',
    );
    if (_pendingFinalization == null ||
        !_pendingFinalization!.matches(requested)) {
      _pendingFinalization = requested;
    }
    state = state.copyWith(
      status: SavedMealsStatus.finalizing,
      errorMessage: null,
      errorCode: null,
    );
    final log = _finalizeSavedMeal(
      _pendingFinalization!,
      allowPartial: allowPartial,
    );
    _inFlightLog = log;
    unawaited(
      log.whenComplete(() {
        if (identical(_inFlightLog, log)) _inFlightLog = null;
      }),
    );
    return log;
  }

  Future<NutritionConsumptionSnapshot?> _finalizeSavedMeal(
    _SavedMealFinalization finalization, {
    required bool allowPartial,
  }) async {
    try {
      final thaliRepo = await _thaliRepoFuture;
      final preview = await thaliRepo.preview(draft: finalization.draft);

      final snapshot = await thaliRepo.finalize(
        preview: preview,
        mealCategory: finalization.mealCategory,
        loggedAt: finalization.loggedAt,
        localDate: finalization.localDate,
        timezoneId: finalization.timezoneId,
        commandId: finalization.commandId,
        consumptionId: finalization.consumptionId,
        allowPartial: allowPartial,
      );

      state = state.copyWith(
        status: SavedMealsStatus.success,
        lastSnapshot: snapshot,
      );
      // A retry after a failure deliberately reuses the pending command, but a
      // completed user action must not prevent a later intentional re-log of
      // the same Saved Meal on the same selected day.
      if (identical(_pendingFinalization, finalization)) {
        _pendingFinalization = null;
      }
      return snapshot;
    } catch (error) {
      final code = _errorCode(error);
      state = state.copyWith(
        status: SavedMealsStatus.failure,
        errorCode: code,
        errorMessage: switch (code) {
          'partial_confirmation_required' =>
            'Review incomplete nutrition before logging this saved meal.',
          'stale_thali_version' || 'stale_dependency' || 'stale_calibration' =>
            'This saved meal changed. Refresh it before logging.',
          _ => 'Could not log saved meal.',
        },
      );
      return null;
    }
  }

  Future<void> deleteSavedMeal(String thaliId) async {
    try {
      final thaliRepo = await _thaliRepoFuture;
      await thaliRepo.deleteThali(userId: _userId, thaliId: thaliId);
      await loadSavedMeals(query: state.query);
    } catch (error) {
      state = state.copyWith(
        status: SavedMealsStatus.failure,
        errorMessage: 'Could not delete saved meal.',
        errorCode: _errorCode(error),
      );
    }
  }

  bool _requiresAcknowledgementFor(NutritionThaliPreview preview) {
    const coreNutrients = {'energy', 'protein', 'carbohydrate', 'fat'};
    return preview.hasUnresolvedInputs ||
        coreNutrients.any((nutrientId) {
          final fact = preview.aggregate.facts[nutrientId];
          return fact == null || !fact.isAvailable;
        });
  }

  String _errorCode(Object error) =>
      error is NutritionThaliError ? error.code : 'saved_meal_action_failed';
}

class _SavedMealFinalization {
  final NutritionThaliDraft draft;
  final String mealCategory;
  final DateTime loggedAt;
  final String localDate;
  final String timezoneId;
  final String commandId;
  final String consumptionId;

  const _SavedMealFinalization({
    required this.draft,
    required this.mealCategory,
    required this.loggedAt,
    required this.localDate,
    required this.timezoneId,
    required this.commandId,
    required this.consumptionId,
  });

  bool matches(_SavedMealFinalization other) =>
      draft.id == other.draft.id &&
      draft.currentVersion == other.draft.currentVersion &&
      draft.compositionFingerprint == other.draft.compositionFingerprint &&
      mealCategory == other.mealCategory &&
      loggedAt.toUtc() == other.loggedAt.toUtc() &&
      localDate == other.localDate &&
      timezoneId == other.timezoneId;
}

final savedMealsControllerProvider =
    StateNotifierProvider<SavedMealsController, SavedMealsState>((ref) {
      final controller = SavedMealsController(
        thaliRepoFuture: ref.watch(nutritionThaliRepositoryProvider.future),
        userId: kLocalNutritionUserScopeId,
      );
      unawaited(controller.loadSavedMeals());
      return controller;
    });
