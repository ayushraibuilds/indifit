import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
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

  test('cleanup can be retried without exposing the temporary path', () async {
    var attempts = 0;
    final service = NutritionEstimatePrivacyService(
      delete: (_) async {
        attempts += 1;
        if (attempts == 1) throw StateError('private path must not escape');
      },
    );

    final failed = await service.cleanupTemporaryImage(
      path: '/private/temporary/meal.jpg',
      lifecycle: NutritionEstimateImageLifecycle.failed,
    );
    final retried = await service.cleanupTemporaryImage(
      path: '/private/temporary/meal.jpg',
      lifecycle: NutritionEstimateImageLifecycle.failed,
    );

    expect(failed.succeeded, isFalse);
    expect(retried.succeeded, isTrue);
    expect(attempts, 2);
  });

  test(
    'evidence validates typed modality and persistence errors stay private',
    () {
      expect(
        () => NutritionEstimateEvidence.fromJson({
          'contract_version': 1,
          'input_modality': 'provider-secret-modality',
        }),
        throwsA(
          isA<NutritionEstimateValidationError>().having(
            (error) => error.code,
            'code',
            'unsupported_input_modality',
          ),
        ),
      );

      final error = NutritionEstimatePersistenceError(
        'estimate_write_failed',
        'The estimate could not be saved.',
        cause: StateError('/private/temporary/meal.jpg token=secret'),
      );
      expect(error.toString(), contains('estimate_write_failed'));
      expect(error.toString(), isNot(contains('/private/temporary')));
      expect(error.toString(), isNot(contains('secret')));
    },
  );

  test('malformed estimate JSON does not echo provider payload details', () {
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    Object? error;
    try {
      NutritionEstimateResponseParser.parseJson(
        '{"private_prompt":"do not echo",',
        registry: registry,
      );
    } catch (caught) {
      error = caught;
    }
    expect(error, isA<NutritionEstimateValidationError>());
    expect(error.toString(), isNot(contains('do not echo')));
  });

  test('provider metadata rejects secret-like durable values', () {
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    expect(
      () => NutritionEstimateResponseParser.parse({
        'subject': {'type': 'meal_estimate', 'label': 'Private test'},
        'provenance': {
          'source': 'ai_estimate',
          'provider': 'api_key=secret-value',
          'input_modality': 'text',
        },
        'nutrients': [
          {
            'id': 'energy',
            'unit': 'energy_kilocalorie',
            'status': 'estimated',
            'point': 100,
            'basis': 'absolute',
          },
        ],
      }, registry: registry),
      throwsA(isA<NutritionEstimatePrivacyError>()),
    );
  });
}
