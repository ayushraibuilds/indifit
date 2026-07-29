import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/travel_repository.dart';

/// Reactive UI state for travel coordination and equipment profile overrides.
class TravelUiState {
  final TravelContext? activeTravelContext;
  final TravelPreviewResult? previewResult;
  final bool isLoading;
  final String? errorMessage;

  const TravelUiState({
    this.activeTravelContext,
    this.previewResult,
    this.isLoading = false,
    this.errorMessage,
  });

  TravelUiState copyWith({
    TravelContext? activeTravelContext,
    bool clearActiveTravel = false,
    TravelPreviewResult? previewResult,
    bool clearPreview = false,
    bool isLoading = false,
    String? errorMessage,
  }) {
    return TravelUiState(
      activeTravelContext: clearActiveTravel
          ? null
          : (activeTravelContext ?? this.activeTravelContext),
      previewResult: clearPreview
          ? null
          : (previewResult ?? this.previewResult),
      isLoading: isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Provider for TravelController.
final travelControllerProvider =
    StateNotifierProvider.autoDispose<TravelController, TravelUiState>((ref) {
      final travelRepo = ref.watch(travelRepositoryProvider);
      return TravelController(travelRepo: travelRepo);
    });

class TravelController extends StateNotifier<TravelUiState> {
  final TravelRepository _travelRepo;

  TravelController({required TravelRepository travelRepo})
    : _travelRepo = travelRepo,
      super(const TravelUiState(isLoading: true)) {
    loadActiveTravel();
  }

  /// Loads the currently active travel context.
  Future<void> loadActiveTravel() async {
    state = state.copyWith(isLoading: true);
    try {
      final active = await _travelRepo.getActiveTravelContext();
      if (active == null) {
        state = state.copyWith(clearActiveTravel: true, isLoading: false);
      } else {
        state = state.copyWith(activeTravelContext: active, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Previews travel context before applying.
  Future<void> previewTravel({
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
    required String equipmentProfileId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final preview = await _travelRepo.previewTravelContext(
        startLocalDate: startLocalDate,
        endLocalDate: endLocalDate,
        timezoneId: timezoneId,
        equipmentProfileId: equipmentProfileId,
      );
      state = state.copyWith(previewResult: preview, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Applies the active preview travel context.
  Future<void> applyTravel({String? note}) async {
    final preview = state.previewResult;
    if (preview == null) {
      throw StateError('No travel preview available to apply.');
    }

    state = state.copyWith(isLoading: true);
    try {
      await _travelRepo.createAndApplyTravelContext(
        startLocalDate: preview.startLocalDate,
        endLocalDate: preview.endLocalDate,
        timezoneId: preview.timezoneId,
        equipmentProfileId: preview.equipmentProfileId,
        note: note,
      );
      await loadActiveTravel();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Cancels the active travel context and restores normal equipment profile.
  Future<void> cancelActiveTravel() async {
    final active = state.activeTravelContext;
    if (active == null) return;

    state = state.copyWith(isLoading: true);
    try {
      await _travelRepo.cancelTravelContext(active.id);
      await loadActiveTravel();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
