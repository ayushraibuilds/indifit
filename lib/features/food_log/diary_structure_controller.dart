import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'meal_presentation_registry.dart';

const String prefDiaryMealSlotsKey = 'pref_diary_meal_slots';

enum DiaryStructurePreset {
  standard4,
  threeMeals,
  fiveMeals,
  athlete6;

  String get label => switch (this) {
    DiaryStructurePreset.standard4 => 'Standard (4 meals)',
    DiaryStructurePreset.threeMeals => '3 Main Meals',
    DiaryStructurePreset.fiveMeals => '5 Meals (Snacks)',
    DiaryStructurePreset.athlete6 => 'Athlete / Workout (6)',
  };

  String get description => switch (this) {
    DiaryStructurePreset.standard4 => 'Breakfast, Lunch, Dinner, and Snacks.',
    DiaryStructurePreset.threeMeals => 'Breakfast, Lunch, and Dinner without snack slots.',
    DiaryStructurePreset.fiveMeals => 'Breakfast, Morning snack, Lunch, Evening snack, and Dinner.',
    DiaryStructurePreset.athlete6 => 'Breakfast, Morning snack, Lunch, Pre-workout, Post-workout, and Dinner.',
  };

  List<String> get slotIds => switch (this) {
    DiaryStructurePreset.standard4 => const ['breakfast', 'lunch', 'dinner', 'snack'],
    DiaryStructurePreset.threeMeals => const ['breakfast', 'lunch', 'dinner'],
    DiaryStructurePreset.fiveMeals => const [
      'breakfast',
      'morning_snack',
      'lunch',
      'evening_snack',
      'dinner',
    ],
    DiaryStructurePreset.athlete6 => const [
      'breakfast',
      'morning_snack',
      'lunch',
      'pre_workout',
      'post_workout',
      'dinner',
    ],
  };
}

class DiaryStructureState {
  const DiaryStructureState({
    required this.activeSlotIds,
    this.isSaving = false,
  });

  final List<String> activeSlotIds;
  final bool isSaving;

  List<FoodMealPresentation> get activeSlots => activeSlotIds
      .map(MealPresentationRegistry.forStableId)
      .where((p) => p.isKnown)
      .toList(growable: false);

  bool isSlotActive(String id) => activeSlotIds.contains(id.trim().toLowerCase());

  bool get isDefault => listEquals(activeSlotIds, DiaryStructurePreset.standard4.slotIds);

  DiaryStructureState copyWith({
    List<String>? activeSlotIds,
    bool? isSaving,
  }) =>
      DiaryStructureState(
        activeSlotIds: activeSlotIds ?? this.activeSlotIds,
        isSaving: isSaving ?? this.isSaving,
      );
}

class DiaryStructureController extends StateNotifier<DiaryStructureState> {
  DiaryStructureController([SharedPreferences? prefs])
      : _prefs = prefs,
        super(
          DiaryStructureState(
            activeSlotIds: prefs != null
                ? sanitizeSlotIds(prefs.getStringList(prefDiaryMealSlotsKey))
                : DiaryStructurePreset.standard4.slotIds,
          ),
        ) {
    if (prefs == null) {
      _load();
    }
  }

  SharedPreferences? _prefs;
  bool _changedLocally = false;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      if (!mounted || _changedLocally) return;
      final stored = prefs.getStringList(prefDiaryMealSlotsKey);
      final sanitized = sanitizeSlotIds(stored);
      if (listEquals(state.activeSlotIds, sanitized)) return;
      state = state.copyWith(activeSlotIds: sanitized);
    } catch (_) {
      // Gracefully fall back to standard defaults if SharedPreferences
      // channel is not available (e.g. in certain widget test environments).
    }
  }

  /// Sanitizes raw slot IDs:
  /// - Resolves each ID via [MealPresentationRegistry.forStableId].
  /// - Drops unknown or corrupt identifiers.
  /// - Dedupes while preserving order.
  /// - If the result is empty, safely falls back to standard 4 slots.
  static List<String> sanitizeSlotIds(List<String>? rawIds) {
    if (rawIds == null || rawIds.isEmpty) {
      return List.unmodifiable(DiaryStructurePreset.standard4.slotIds);
    }
    final seen = <String>{};
    final sanitized = <String>[];
    for (final raw in rawIds) {
      final presentation = MealPresentationRegistry.forStableId(raw);
      if (presentation.isKnown && seen.add(presentation.stableId)) {
        sanitized.add(presentation.stableId);
      }
    }
    if (sanitized.isEmpty) {
      return List.unmodifiable(DiaryStructurePreset.standard4.slotIds);
    }
    return List.unmodifiable(sanitized);
  }

  /// Adds a slot to the active diary structure.
  ///
  /// Idempotent: adding an already-active slot is a no-op.
  Future<void> addSlot(String slotId) async {
    final normalized = slotId.trim().toLowerCase();
    final presentation = MealPresentationRegistry.forStableId(normalized);
    if (!presentation.isKnown || state.activeSlotIds.contains(presentation.stableId)) {
      return;
    }
    final updated = List<String>.from(state.activeSlotIds)..add(presentation.stableId);
    await _persist(updated);
  }

  /// Removes a slot from the active diary structure.
  ///
  /// Invariant: Enforces a minimum of 1 active slot.
  Future<void> removeSlot(String slotId) async {
    final normalized = slotId.trim().toLowerCase();
    if (!state.activeSlotIds.contains(normalized) || state.activeSlotIds.length <= 1) {
      return;
    }
    final updated = List<String>.from(state.activeSlotIds)..remove(normalized);
    await _persist(updated);
  }

  /// Toggles a slot's presence.
  Future<void> toggleSlot(String slotId) async {
    final normalized = slotId.trim().toLowerCase();
    if (state.activeSlotIds.contains(normalized)) {
      await removeSlot(normalized);
    } else {
      await addSlot(normalized);
    }
  }

  /// Reorders the active slots.
  Future<void> reorderSlots(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= state.activeSlotIds.length) return;
    if (newIndex < 0 || newIndex > state.activeSlotIds.length) return;

    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (oldIndex == targetIndex) return;

    final updated = List<String>.from(state.activeSlotIds);
    final movedItem = updated.removeAt(oldIndex);
    updated.insert(targetIndex, movedItem);
    await _persist(updated);
  }

  /// Applies a predefined diary structure preset.
  Future<void> applyPreset(DiaryStructurePreset preset) async {
    final sanitized = sanitizeSlotIds(preset.slotIds);
    await _persist(sanitized);
  }

  /// Resets the diary structure to the canonical 4 default meals.
  Future<void> resetToDefault() async {
    await applyPreset(DiaryStructurePreset.standard4);
  }

  Future<void> _persist(List<String> slotIds) async {
    _changedLocally = true;
    state = state.copyWith(activeSlotIds: List.unmodifiable(slotIds), isSaving: true);
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      if (listEquals(slotIds, DiaryStructurePreset.standard4.slotIds)) {
        await prefs.remove(prefDiaryMealSlotsKey);
      } else {
        await prefs.setStringList(prefDiaryMealSlotsKey, slotIds);
      }
    } catch (_) {
      // Gracefully handle unmocked preference storage in testing environments.
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final diaryStructureControllerProvider =
    StateNotifierProvider<DiaryStructureController, DiaryStructureState>((ref) {
  return DiaryStructureController();
});

final diaryMealSlotsProvider = Provider<List<FoodMealPresentation>>((ref) {
  final state = ref.watch(diaryStructureControllerProvider);
  return state.activeSlots;
});
