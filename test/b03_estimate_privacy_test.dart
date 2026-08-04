import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_estimates.dart';
import 'package:indifit/core/privacy/nutrition_estimate_privacy.dart';

void main() {
  test(
    'temporary image cleanup deletes after success and reports failures safely',
    () async {
      final deleted = <String>[];
      final service = NutritionEstimatePrivacyService(
        delete: (path) async => deleted.add(path),
      );
      final success = await service.cleanupTemporaryImage(
        path: '/private/temporary/meal.jpg',
        lifecycle: NutritionEstimateImageLifecycle.completed,
      );
      expect(success.succeeded, isTrue);
      expect(success.state, NutritionEstimateImageCleanupState.deleted);
      expect(deleted, ['/private/temporary/meal.jpg']);

      final failure = NutritionEstimatePrivacyService(
        delete: (_) async => throw StateError('private path must not escape'),
      );
      final failed = await failure.cleanupTemporaryImage(
        path: '/private/temporary/meal.jpg',
        lifecycle: NutritionEstimateImageLifecycle.failed,
      );
      expect(failed.succeeded, isFalse);
      expect(failed.errorCode, 'temporary_image_cleanup_failed');
    },
  );

  test(
    'privacy-safe evidence rejects prompts, raw responses, secrets, and durable images',
    () {
      expect(
        () => NutritionEstimateEvidence(metadata: const {'prompt': 'private'}),
        throwsA(isA<NutritionEstimatePrivacyError>()),
      );
      expect(
        () => NutritionEstimateEvidence(metadata: const {'api_key': 'secret'}),
        throwsA(isA<NutritionEstimatePrivacyError>()),
      );
      expect(
        () => NutritionEstimateEvidence(temporaryImageRetained: true),
        throwsA(isA<NutritionEstimatePrivacyError>()),
      );
      expect(
        () => NutritionEstimateEvidence.fromJson({
          'contract_version': 1,
          'raw_response': {'calories': 100},
        }),
        throwsA(isA<NutritionEstimatePrivacyError>()),
      );
      final safe = NutritionEstimateEvidence(
        providerCategory: 'opaque-provider-category',
        providerResponseId: 'response-123',
        imageRetentionNotice: 'Deleted after processing.',
      );
      expect(safe.toJson()['temporary_image_retained'], isFalse);
      expect(safe.toJson().containsKey('providerResponse'), isFalse);
    },
  );

  test(
    'missing temporary image is a safe no-op and never exposes its path',
    () async {
      final result = await NutritionEstimatePrivacyService()
          .cleanupTemporaryImage(
            path: null,
            lifecycle: NutritionEstimateImageLifecycle.cancelled,
          );
      expect(result.state, NutritionEstimateImageCleanupState.alreadyAbsent);
      expect(result.errorCode, isNull);
    },
  );
}
