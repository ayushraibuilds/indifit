import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/data/repositories/food_api_service.dart';

void main() {
  group('FoodApiService Backend Proxy & Auth', () {
    test(
      'searchOnline posts to /api/food/search with payload and parses backend response',
      () async {
        final adapter = _BackendSuccessAdapter();
        final dio = Dio(
          BaseOptions(headers: {'x-indifit-key': 'test-indifit-key'}),
        )..httpClientAdapter = adapter;

        final service = FoodApiService(
          dio,
          const PrivacyPolicy(
            isOfflineOnly: false,
            isTelemetryEnabled: false,
            allowOnlineNutrition: true,
          ),
          null,
          'https://api.indifit.app',
        );

        final results = await service.searchOnline('paneer');

        expect(results, hasLength(1));
        final item = results.single;
        expect(item.name, 'Paneer');
        expect(item.nameHindi, 'पनीर');
        expect(item.categoryId, 'dairy_liquid');
        expect(item.calories, 265.0);
        expect(item.protein, 18.3);
        expect(item.carbs, 1.2);
        expect(item.fat, 20.8);
        expect(item.fiber, 0.0);
        expect(item.sodium, 18.0);
        expect(item.servingSize, 100.0);
        expect(item.servingUnit, 'g');
        expect(item.provenance, 'curated');
        expect(item.confidence, 1.0);
        expect(item.servingOptions, isNotEmpty);
        expect(item.servingOptions!.first['unit'], '100g');

        expect(adapter.options!.uri.host, 'api.indifit.app');
        expect(adapter.options!.uri.path, '/api/food/search');
        expect(adapter.options!.method, 'POST');
        expect(adapter.options!.headers['x-indifit-key'], 'test-indifit-key');

        final body = adapter.options!.data as Map<String, dynamic>;
        expect(body['query'], 'paneer');
        expect(body['language'], 'hinglish');
        expect(body['page'], 1);
        expect(body['limit'], 20);
      },
    );

    test(
      'fail-closed when isNutritionOnlineAllowed is false (offline-only)',
      () async {
        final adapter = _BackendSuccessAdapter();
        final dio = Dio()..httpClientAdapter = adapter;

        final service = FoodApiService(
          dio,
          const PrivacyPolicy(
            isOfflineOnly: true,
            isTelemetryEnabled: false,
            allowOnlineNutrition: true,
          ),
          null,
          'https://api.indifit.app',
        );

        await expectLater(
          () => service.searchOnline('paneer'),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          () => service.fetchByBarcode('8901262010053'),
          throwsA(isA<StateError>()),
        );
        expect(adapter.called, isFalse);
      },
    );

    test('fail-closed when allowOnlineNutrition preference is false', () async {
      final adapter = _BackendSuccessAdapter();
      final dio = Dio()..httpClientAdapter = adapter;

      final service = FoodApiService(
        dio,
        const PrivacyPolicy(
          isOfflineOnly: false,
          isTelemetryEnabled: false,
          allowOnlineNutrition: false,
        ),
        null,
        'https://api.indifit.app',
      );

      await expectLater(
        () => service.searchOnline('paneer'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        () => service.fetchByBarcode('8901262010053'),
        throwsA(isA<StateError>()),
      );
      expect(adapter.called, isFalse);
    });

    test(
      'fetchByBarcode calls backend GET /api/food/barcode/{code} and parses candidate',
      () async {
        final adapter = _BarcodeSuccessAdapter();
        final dio = Dio()..httpClientAdapter = adapter;

        final service = FoodApiService(
          dio,
          const PrivacyPolicy(
            isOfflineOnly: false,
            isTelemetryEnabled: false,
            allowOnlineNutrition: true,
          ),
          null,
          'https://api.indifit.app',
        );

        final result = await service.fetchByBarcode('8901262010053');
        expect(result, isNotNull);
        expect(result!.name, 'Amul Gold Milk');
        expect(result.brand, 'Amul');
        expect(result.barcode, '8901262010053');
        expect(result.protein, 3.5);
        expect(adapter.options!.uri.path, '/api/food/barcode/8901262010053');
        expect(adapter.options!.method, 'GET');
      },
    );

    test('fetchByBarcode returns null on 404 not found', () async {
      final adapter = _Barcode404Adapter();
      final dio = Dio()..httpClientAdapter = adapter;

      final service = FoodApiService(
        dio,
        const PrivacyPolicy(
          isOfflineOnly: false,
          isTelemetryEnabled: false,
          allowOnlineNutrition: true,
        ),
        null,
        'https://api.indifit.app',
      );

      final result = await service.fetchByBarcode('0000000000000');
      expect(result, isNull);
    });

    test(
      'provider HTTP failure remains a typed bad-response failure',
      () async {
        final dio = Dio()..httpClientAdapter = _BadResponseAdapter();

        await expectLater(
          FoodApiService(
            dio,
            null,
            null,
            'https://api.indifit.app',
          ).searchOnline('protein shake'),
          throwsA(
            isA<DioException>()
                .having(
                  (error) => error.type,
                  'type',
                  DioExceptionType.badResponse,
                )
                .having((error) => error.response?.statusCode, 'status', 503),
          ),
        );
      },
    );

    test('provider timeout remains a typed timeout failure', () async {
      final dio = Dio()..httpClientAdapter = _TimeoutAdapter();

      await expectLater(
        FoodApiService(
          dio,
          null,
          null,
          'https://api.indifit.app',
        ).searchOnline('protein shake'),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.receiveTimeout,
          ),
        ),
      );
    });

    test(
      'provider request is cancelled through the real Dio cancel token',
      () async {
        final adapter = _CancellableAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final token = CancelToken();
        final request = FoodApiService(
          dio,
          null,
          null,
          'https://api.indifit.app',
        ).searchOnline('first query', cancelToken: token);
        await adapter.started.future;

        token.cancel('query changed');

        await expectLater(
          request,
          throwsA(
            isA<DioException>().having(
              CancelToken.isCancel,
              'cancelled',
              isTrue,
            ),
          ),
        );
      },
    );
  });

  group('FoodApiService without a backend (release default)', () {
    const allowed = PrivacyPolicy(
      isOfflineOnly: false,
      isTelemetryEnabled: false,
      allowOnlineNutrition: true,
    );

    test(
      'search goes straight to Open Food Facts and reads list brands',
      () async {
        final app = _RecordingAdapter(
          (_) => throw StateError('backend called'),
        );
        final off = _RecordingAdapter((_) => _json(_offSearchHits));
        final service = FoodApiService(
          Dio()..httpClientAdapter = app,
          allowed,
          null,
          '',
          Dio()..httpClientAdapter = off,
        );

        final results = await service.searchOnline('parle-g');

        expect(app.requests, isEmpty);
        expect(off.requests.single.uri.host, 'search.openfoodfacts.org');
        expect(off.requests.single.method, 'POST');
        expect((off.requests.single.data as Map)['q'], 'parle-g');
        expect(results.single.name, 'Parle G');
        expect(results.single.brand, 'Parle-G, Parle');
        expect(results.single.calories, 454);
      },
    );

    test('barcode lookup goes straight to Open Food Facts', () async {
      final app = _RecordingAdapter((_) => throw StateError('backend called'));
      final off = _RecordingAdapter(
        (_) => _json({
          'status': 1,
          'product': {
            'product_name': 'Parle G',
            'brands': 'Parle-G',
            'nutriments': {'energy-kcal_100g': 454},
          },
        }),
      );
      final service = FoodApiService(
        Dio()..httpClientAdapter = app,
        allowed,
        null,
        '',
        Dio()..httpClientAdapter = off,
      );

      final result = await service.fetchByBarcode('8901719100956');

      expect(app.requests, isEmpty);
      expect(
        off.requests.single.uri.path,
        '/api/v2/product/8901719100956.json',
      );
      expect(result?.name, 'Parle G');
    });

    test(
      'online nutrition off blocks both lookups before any request',
      () async {
        final off = _RecordingAdapter((_) => _json(_offSearchHits));
        final service = FoodApiService(
          Dio(),
          const PrivacyPolicy(
            isOfflineOnly: false,
            isTelemetryEnabled: false,
            allowOnlineNutrition: false,
          ),
          null,
          '',
          Dio()..httpClientAdapter = off,
        );

        await expectLater(service.searchOnline('parle-g'), throwsStateError);
        await expectLater(
          service.fetchByBarcode('8901719100956'),
          throwsStateError,
        );
        expect(off.requests, isEmpty);
      },
    );
  });

  group('FoodApiService backend fallback', () {
    test(
      'an unreachable backend falls back to Open Food Facts for search',
      () async {
        final app = _RecordingAdapter(
          (options) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );
        final off = _RecordingAdapter((_) => _json(_offSearchHits));
        final service = FoodApiService(
          Dio()..httpClientAdapter = app,
          null,
          null,
          'https://api.example.test',
          Dio()..httpClientAdapter = off,
        );

        final results = await service.searchOnline('parle-g');

        expect(app.requests.single.uri.path, '/api/food/search');
        expect(off.requests.single.uri.host, 'search.openfoodfacts.org');
        expect(results.single.name, 'Parle G');
      },
    );

    test('a backend client error is not retried elsewhere', () async {
      final app = _RecordingAdapter(
        (_) => _json({'detail': 'bad'}, status: 400),
      );
      final off = _RecordingAdapter((_) => _json(_offSearchHits));
      final service = FoodApiService(
        Dio()..httpClientAdapter = app,
        null,
        null,
        'https://api.example.test',
        Dio()..httpClientAdapter = off,
      );

      await expectLater(
        service.searchOnline('parle-g'),
        throwsA(isA<DioException>()),
      );
      expect(off.requests, isEmpty);
    });
  });
}

const _offSearchHits = {
  'hits': [
    {
      'code': '8901719100956',
      'product_name': 'Parle G',
      'brands': ['Parle-G', 'Parle'],
      'nutriments': {'energy-kcal_100g': 454},
    },
  ],
};

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _BackendSuccessAdapter implements HttpClientAdapter {
  RequestOptions? options;
  bool called = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    called = true;
    final json = jsonEncode({
      'results': [
        {
          'id': 'curated_paneer',
          'name': 'Paneer',
          'name_hindi': 'पनीर',
          'brand': null,
          'category_id': 'dairy_liquid',
          'calories': 265.0,
          'protein_g': 18.3,
          'carbs_g': 1.2,
          'fat_g': 20.8,
          'fiber_g': 0.0,
          'sodium_mg': 18.0,
          'serving_size': 100.0,
          'serving_unit': 'g',
          'serving_options': [
            {'unit': '100g', 'gram_weight': 100.0, 'is_default': true},
          ],
          'score': 100.0,
          'source': 'curated',
          'provenance': 'curated',
          'confidence': 'high',
        },
      ],
      'count': 1,
      'total_hits': 1,
      'has_more': false,
      'query': 'paneer',
    });

    return ResponseBody.fromString(
      json,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _BarcodeSuccessAdapter implements HttpClientAdapter {
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    final json = jsonEncode({
      'barcode': '8901262010053',
      'candidate': {
        'id': '8901262010053',
        'name': 'Amul Gold Milk',
        'brand': 'Amul',
        'category_id': 'dairy_liquid',
        'calories': 88.0,
        'protein_g': 3.5,
        'carbs_g': 5.0,
        'fat_g': 6.0,
        'fiber_g': null,
        'sodium_mg': 50.0,
        'serving_size': 100.0,
        'serving_unit': 'ml',
        'serving_options': [
          {'unit': 'glass (200ml)', 'gram_weight': 206.0, 'is_default': true},
        ],
        'score': 100.0,
        'source': 'curated',
        'provenance': 'verified_fmcg',
        'confidence': 'high',
      },
    });

    return ResponseBody.fromString(
      json,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Barcode404Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"detail":"Barcode not found."}',
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _TimeoutAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.receiveTimeout,
      message: 'fixture timeout',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _BadResponseAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"detail":"provider unavailable"}',
    503,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _CancellableAdapter implements HttpClientAdapter {
  final Completer<void> started = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!started.isCompleted) started.complete();
    await cancelFuture;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
      message: 'fixture cancelled',
    );
  }

  @override
  void close({bool force = false}) {}
}
