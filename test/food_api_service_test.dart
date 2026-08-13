import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/repositories/food_api_service.dart';

void main() {
  test(
    'provider search is identified, field-limited, and parses results',
    () async {
      final adapter = _SuccessAdapter();
      final dio = Dio(
        BaseOptions(
          headers: const {'User-Agent': kOpenFoodFactsUserAgent},
          connectTimeout: kOpenFoodFactsConnectTimeout,
          receiveTimeout: kOpenFoodFactsReceiveTimeout,
        ),
      )..httpClientAdapter = adapter;

      final results = await FoodApiService(dio).searchOnline('protein shake');

      expect(results, hasLength(1));
      expect(results.single.name, 'Fixture shake');
      expect(results.single.protein, 20);
      expect(results.single.providerId, '123');
      expect(results.single.barcode, '123');
      expect(results.single.brand, 'Fixture Brand');
      expect(adapter.options!.uri.host, 'search.openfoodfacts.org');
      expect(adapter.options!.uri.path, '/search');
      expect(adapter.options!.method, 'POST');
      expect(adapter.options!.headers['User-Agent'], kOpenFoodFactsUserAgent);
      expect(adapter.options!.headers, isNot(contains('x-indifit-key')));
      final body = adapter.options!.data as Map<String, dynamic>;
      expect(body['q'], 'protein shake');
      expect(body['fields'], [
        'code',
        'brands',
        'product_name',
        'nutriments',
        'serving_quantity',
        'serving_quantity_unit',
      ]);
      expect(adapter.options!.queryParameters, isEmpty);
    },
  );

  test('provider HTTP failure remains a typed bad-response failure', () async {
    final dio = Dio()..httpClientAdapter = _BadResponseAdapter();

    await expectLater(
      FoodApiService(dio).searchOnline('protein shake'),
      throwsA(
        isA<DioException>()
            .having((error) => error.type, 'type', DioExceptionType.badResponse)
            .having((error) => error.response?.statusCode, 'status', 503),
      ),
    );
  });

  test('provider timeout remains a typed timeout failure', () async {
    final dio = Dio()..httpClientAdapter = _TimeoutAdapter();

    await expectLater(
      FoodApiService(dio).searchOnline('protein shake'),
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
      ).searchOnline('first query', cancelToken: token);
      await adapter.started.future;

      token.cancel('query changed');

      await expectLater(
        request,
        throwsA(
          isA<DioException>().having(CancelToken.isCancel, 'cancelled', isTrue),
        ),
      );
    },
  );
}

class _SuccessAdapter implements HttpClientAdapter {
  RequestOptions? options;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    return ResponseBody.fromString(
      '''{"hits":[{"code":"123","brands":"Fixture Brand","product_name":"Fixture shake","serving_quantity":330,"serving_quantity_unit":"g","nutriments":{"energy-kcal_100g":120,"proteins_100g":20,"carbohydrates_100g":6,"fat_100g":2}}]}''',
      200,
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
