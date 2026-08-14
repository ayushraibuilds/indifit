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

  const SavedMealDisplayItem({
    required this.draft,
    required this.itemCount,
    this.estimatedCalories,
    this.estimatedProteinG,
    required this.summary,
  });
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

  SavedMealsController({
    required Future<NutritionThaliRepository> thaliRepoFuture,
    required String userId,
  }) : _thaliRepoFuture = thaliRepoFuture,
       _userId = userId,
       super(const SavedMealsState());

  Future<void> loadSavedMeals({String query = ''}) async {
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
        try {
          final preview = await thaliRepo.preview(draft: draft);
          final energy =
              preview.aggregate.facts['energy']?.point?.value.asDouble;
          final prot =
              preview.aggregate.facts['protein']?.point?.value.asDouble;
          calories = energy;
          protein = prot;
        } catch (_) {
          // Preview is optional for card summary
        }

        displayItems.add(
          SavedMealDisplayItem(
            draft: draft,
            itemCount: draft.items.length,
            estimatedCalories: calories,
            estimatedProteinG: protein,
            summary: summary.isEmpty ? 'No items' : summary,
          ),
        );
      }

      state = state.copyWith(
        status: SavedMealsStatus.ready,
        meals: displayItems,
      );
    } catch (e) {
      state = state.copyWith(
        status: SavedMealsStatus.failure,
        errorMessage: 'Could not load saved meals.',
      );
    }
  }

  Future<NutritionConsumptionSnapshot?> logSavedMeal({
    required NutritionThaliDraft draft,
    required String mealCategory,
    DateTime? loggedAt,
  }) async {
    state = state.copyWith(
      status: SavedMealsStatus.finalizing,
      errorMessage: null,
    );

    try {
      final thaliRepo = await _thaliRepoFuture;
      final preview = await thaliRepo.preview(draft: draft);
      final when = (loggedAt ?? DateTime.now()).toUtc();
      final localDate =
          '${when.year.toString().padLeft(4, '0')}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';

      final snapshot = await thaliRepo.finalize(
        preview: preview,
        mealCategory: mealCategory,
        loggedAt: when,
        localDate: localDate,
        timezoneId: 'UTC',
        commandId: 'saved-meal-log::${const Uuid().v4()}',
        consumptionId: 'saved-meal-consumption::${const Uuid().v4()}',
        allowPartial: true,
      );

      state = state.copyWith(
        status: SavedMealsStatus.success,
        lastSnapshot: snapshot,
      );
      return snapshot;
    } catch (e) {
      state = state.copyWith(
        status: SavedMealsStatus.failure,
        errorMessage: 'Could not log saved meal.',
      );
      return null;
    }
  }

  Future<void> deleteSavedMeal(String thaliId) async {
    try {
      final thaliRepo = await _thaliRepoFuture;
      await thaliRepo.deleteThali(userId: _userId, thaliId: thaliId);
      await loadSavedMeals(query: state.query);
    } catch (e) {
      state = state.copyWith(
        status: SavedMealsStatus.failure,
        errorMessage: 'Could not delete saved meal.',
      );
    }
  }
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
