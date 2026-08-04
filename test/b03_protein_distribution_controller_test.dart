import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_protein_distribution.dart';
import 'package:indifit/data/repositories/nutrition_protein_distribution_repository.dart';
import 'package:indifit/features/nutrition/protein_distribution_controller.dart';

void main() {
  const date = '2026-08-04';

  test(
    'controller exposes loading, empty, failure, and retry states',
    () async {
      var shouldFail = true;
      final repository = _FakeRepository(() {
        if (shouldFail) {
          throw const NutritionProteinDistributionError(
            'read_failed',
            'Read failed for test.',
          );
        }
        return _distribution(isEmpty: true);
      });
      final controller = NutritionProteinDistributionController(
        repository: Future.value(repository),
        userId: 'user-1',
        localDate: date,
      );

      expect(controller.state.status, NutritionProteinDistributionStatus.idle);
      final loading = controller.load();
      expect(
        controller.state.status,
        NutritionProteinDistributionStatus.loading,
      );
      await loading;
      expect(
        controller.state.status,
        NutritionProteinDistributionStatus.failure,
      );
      expect(controller.state.errorCode, 'read_failed');
      expect(controller.state.retryable, isTrue);

      shouldFail = false;
      await controller.retry();
      expect(controller.state.status, NutritionProteinDistributionStatus.empty);
      expect(controller.state.distribution!.isEmpty, isTrue);
    },
  );

  test(
    'controller exposes ready state without mutating the read model',
    () async {
      final repository = _FakeRepository(() => _distribution(isEmpty: false));
      final controller = NutritionProteinDistributionController(
        repository: Future.value(repository),
        userId: 'user-1',
        localDate: date,
      );

      await controller.load();

      expect(controller.state.status, NutritionProteinDistributionStatus.ready);
      expect(controller.state.distribution!.isEmpty, isFalse);
      expect(repository.calls, 1);
    },
  );
}

class _FakeRepository implements NutritionProteinDistributionRepository {
  final NutritionProteinDistribution Function() _read;
  int calls = 0;

  _FakeRepository(this._read);

  @override
  Future<NutritionProteinDistribution> forLocalDate({
    required String userId,
    required String localDate,
  }) async {
    calls++;
    return _read();
  }
}

NutritionProteinDistribution _distribution({required bool isEmpty}) =>
    NutritionProteinDistribution(
      userId: 'user-1',
      localDate: '2026-08-04',
      isEmpty: isEmpty,
      meals: const [],
      totalProtein: NutritionDistributionNutrientSummary.unavailable(
        nutrientId: nutritionProteinNutrientId,
      ),
      knownProtein: NutritionDistributionNutrientSummary.unavailable(
        nutrientId: nutritionProteinNutrientId,
      ),
      totalLeucine: NutritionDistributionNutrientSummary.unavailable(
        nutrientId: nutritionLeucineNutrientId,
      ),
      leucineAvailability: NutritionLeucineAvailability.unavailable,
      totalItemCount: 0,
      unknownProteinItemCount: 0,
      estimatedProteinItemCount: 0,
      percentagesAvailable: false,
      percentageUnavailableReason: 'empty_day',
      recordIds: const [],
    );
