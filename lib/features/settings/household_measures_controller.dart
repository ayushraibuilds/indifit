import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/typed_quantities.dart';
import '../../data/repositories/nutrition_household_measure_repository.dart';

enum HouseholdMeasuresStatus {
  initial,
  loading,
  ready,
  empty,
  saving,
  validationError,
  error,
}

class HouseholdMeasuresState {
  final HouseholdMeasuresStatus status;
  final List<NutritionPersonalVessel> vessels;
  final Map<String, NutritionVesselCalibration?> currentCalibrations;
  final String? message;

  const HouseholdMeasuresState({
    this.status = HouseholdMeasuresStatus.initial,
    this.vessels = const [],
    this.currentCalibrations = const {},
    this.message,
  });

  bool get isLoading =>
      status == HouseholdMeasuresStatus.initial ||
      status == HouseholdMeasuresStatus.loading;

  bool get isSaving => status == HouseholdMeasuresStatus.saving;

  HouseholdMeasuresState copyWith({
    HouseholdMeasuresStatus? status,
    List<NutritionPersonalVessel>? vessels,
    Map<String, NutritionVesselCalibration?>? currentCalibrations,
    String? message,
    bool clearMessage = false,
  }) => HouseholdMeasuresState(
    status: status ?? this.status,
    vessels: vessels ?? this.vessels,
    currentCalibrations: currentCalibrations ?? this.currentCalibrations,
    message: clearMessage ? null : message ?? this.message,
  );
}

class HouseholdMeasuresController
    extends StateNotifier<HouseholdMeasuresState> {
  final NutritionHouseholdMeasureRepository _repository;
  final String userId;

  HouseholdMeasuresController({
    required NutritionHouseholdMeasureRepository repository,
    required this.userId,
  }) : _repository = repository,
       super(const HouseholdMeasuresState());

  Future<void> load() async {
    state = state.copyWith(
      status: HouseholdMeasuresStatus.loading,
      clearMessage: true,
    );
    try {
      final vessels = await _repository.listVessels(
        userId: userId,
        includeArchived: true,
      );
      final currentCalibrations = <String, NutritionVesselCalibration?>{};
      for (final vessel in vessels) {
        currentCalibrations[vessel.id] = await _repository
            .getCurrentCalibration(userId: userId, vesselId: vessel.id);
      }
      state = state.copyWith(
        status: vessels.isEmpty
            ? HouseholdMeasuresStatus.empty
            : HouseholdMeasuresStatus.ready,
        vessels: vessels,
        currentCalibrations: currentCalibrations,
      );
    } catch (error) {
      state = state.copyWith(
        status: HouseholdMeasuresStatus.error,
        message: _messageFor(error),
      );
    }
  }

  Future<void> createVessel({
    required String displayName,
    String? vesselType,
  }) async {
    await _mutate(
      () => _repository.createVessel(
        userId: userId,
        displayName: displayName,
        vesselType: vesselType,
      ),
    );
  }

  Future<void> renameVessel({
    required String vesselId,
    required String displayName,
  }) async {
    await _mutate(
      () => _repository.renameVessel(
        userId: userId,
        vesselId: vesselId,
        displayName: displayName,
      ),
    );
  }

  Future<void> archiveVessel(String vesselId) async {
    await _mutate(
      () => _repository.archiveVessel(userId: userId, vesselId: vesselId),
    );
  }

  Future<void> calibrateVessel({
    required String vesselId,
    required String volumeMillilitres,
    String method = 'water_fill',
    double? confidence,
    String? notes,
  }) async {
    await _mutate(() {
      final volume = Quantity.fromDecimal(
        amount: volumeMillilitres.trim(),
        unit: QuantityUnit.millilitre,
      );
      return _repository.addCalibration(
        userId: userId,
        vesselId: vesselId,
        volume: volume,
        method: method,
        confidence: confidence,
        notes: notes,
      );
    });
  }

  Future<void> _mutate(Future<Object?> Function() operation) async {
    state = state.copyWith(
      status: HouseholdMeasuresStatus.saving,
      clearMessage: true,
    );
    try {
      await operation();
      await load();
    } catch (error) {
      state = state.copyWith(
        status: _isValidationFailure(error)
            ? HouseholdMeasuresStatus.validationError
            : HouseholdMeasuresStatus.error,
        message: _messageFor(error),
      );
    }
  }

  static bool _isValidationFailure(Object error) =>
      error is NutritionHouseholdMeasureException || error is QuantityError;

  static String _messageFor(Object error) {
    if (error is NutritionHouseholdMeasureException) return error.message;
    if (error is QuantityError) return error.message;
    return 'The household-measure operation could not be completed.';
  }
}

final householdMeasuresControllerProvider =
    StateNotifierProvider.family<
      HouseholdMeasuresController,
      HouseholdMeasuresState,
      String
    >((ref, userId) {
      final controller = HouseholdMeasuresController(
        repository: ref.watch(nutritionHouseholdMeasureRepositoryProvider),
        userId: userId,
      );
      controller.load();
      return controller;
    });
