import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/ai/ai_gateway.dart';
import 'package:indifit/core/ai/backend_ai_gateway.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/features/nutrition_ai/natural_language_meal_service.dart';

Dio _dio(void Function(RequestOptions, RequestInterceptorHandler) onRequest) =>
    Dio()..interceptors.add(InterceptorsWrapper(onRequest: onRequest));

Dio _dioAnswering(int status, Object? body) => _dio(
  (options, handler) => status == 200
      ? handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: body),
        )
      : handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: status,
              data: body,
            ),
          ),
        ),
);

class _FakeGateway implements AiGateway {
  _FakeGateway(this.answer);

  final Future<Map<String, dynamic>> Function() answer;

  @override
  Future<Map<String, dynamic>> decomposeMealText(String text) => answer();

  @override
  Future<Map<String, dynamic>> decomposeMealPhoto(Uint8List jpeg) => answer();

  @override
  Future<Map<String, dynamic>> readNutritionLabel(Uint8List jpeg) => answer();
}

Matcher _gatewayFailure(AiGatewayFailure failure) =>
    isA<AiGatewayException>().having((e) => e.failure, 'failure', failure);

void main() {
  // The database seeds the food catalogue from assets via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackendAiGateway', () {
    test('rejects the backend\'s canned fallback data', () async {
      final gateway = BackendAiGateway(
        dio: _dioAnswering(200, {
          'items': [
            {'food_name': 'Roti / Chapati', 'quantity_amount': 2},
          ],
          'is_fallback': true,
          'fallback_reason': 'upstream_unavailable',
        }),
        baseUrl: 'http://ai.test',
      );

      await expectLater(
        gateway.decomposeMealPhoto(Uint8List(4)),
        throwsA(_gatewayFailure(AiGatewayFailure.unavailable)),
      );
    });

    test('maps 429 to quotaExceeded', () async {
      final gateway = BackendAiGateway(
        dio: _dioAnswering(429, {'detail': 'Rate limit exceeded'}),
        baseUrl: 'http://ai.test',
      );

      await expectLater(
        gateway.decomposeMealText('2 roti'),
        throwsA(_gatewayFailure(AiGatewayFailure.quotaExceeded)),
      );
    });

    test('maps connection errors to offline', () async {
      final gateway = BackendAiGateway(
        dio: _dio(
          (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          ),
        ),
        baseUrl: 'http://ai.test',
      );

      await expectLater(
        gateway.readNutritionLabel(Uint8List(4)),
        throwsA(_gatewayFailure(AiGatewayFailure.offline)),
      );
    });

    test('sends the device id only on photo requests', () async {
      final seen = <String, Object?>{};
      final gateway = BackendAiGateway(
        dio: _dio((options, handler) {
          seen[options.path] = options.headers['x-device-uuid'];
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'items': <Object>[]},
            ),
          );
        }),
        baseUrl: 'http://ai.test',
        deviceUuid: 'device-1',
      );

      await gateway.decomposeMealPhoto(Uint8List(4));
      await gateway.decomposeMealText('dal');

      expect(seen['http://ai.test/api/ai/meal-estimate-photo-v2'], 'device-1');
      expect(seen['http://ai.test/api/ai/meal-decompose'], isNull);
    });
  });

  group('NaturalLanguageMealService over a gateway', () {
    late AppDatabase db;
    late NutritionFoodCatalogRepository catalog;

    setUp(() {
      db = AppDatabase.memory();
      catalog = NutritionFoodCatalogRepository(
        db: db,
        registry: NutrientRegistry.fromAssetFileSync(
          'assets/data/nutrient_registry.json',
        ),
      );
    });

    tearDown(() => db.close());

    NaturalLanguageMealService service(AiGateway gateway) =>
        NaturalLanguageMealService(
          gateway: gateway,
          catalog: catalog,
          policy: () => const PrivacyPolicy(
            isOfflineOnly: false,
            isTelemetryEnabled: false,
            connectedAiEnabled: true,
          ),
        );

    test('resolves gateway items against the catalogue', () async {
      final result = await service(
        _FakeGateway(
          () async => {
            'items': [
              {
                'raw_segment': '2 bajra roti',
                'food_name': 'Bajra Roti (Millet)',
                'quantity_amount': 2,
                'quantity_unit': 'piece',
                'estimated_calories': 200,
              },
            ],
            'total_calories': 200,
          },
        ),
      ).decomposeMeal(text: '2 bajra roti');

      expect(result.items.single.isCatalogVerified, isTrue);
      expect(result.isFallback, isFalse);
    });

    test('offline failures surface as MealAiOfflineException', () async {
      final gateway = _FakeGateway(
        () => throw const AiGatewayException(AiGatewayFailure.offline, 'x'),
      );

      await expectLater(
        service(gateway).decomposeMeal(text: 'dal chawal'),
        throwsA(isA<MealAiOfflineException>()),
      );
    });

    test('other failures keep the gateway\'s message for the user', () async {
      final gateway = _FakeGateway(
        () => throw const AiGatewayException(
          AiGatewayFailure.quotaExceeded,
          'AI usage limit reached. Please try again later.',
        ),
      );

      await expectLater(
        service(gateway).decomposeMeal(text: 'dal chawal'),
        throwsA(
          isA<MealAiUnavailableException>().having(
            (e) => e.message,
            'message',
            contains('usage limit'),
          ),
        ),
      );
    });
  });
}
