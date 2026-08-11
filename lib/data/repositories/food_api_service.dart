import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/utils/app_logger.dart';

const Duration kOpenFoodFactsConnectTimeout = Duration(seconds: 8);
const Duration kOpenFoodFactsReceiveTimeout = Duration(seconds: 12);
const Duration kOpenFoodFactsSendTimeout = Duration(seconds: 8);
const String kOpenFoodFactsUserAgent = 'IndiFit/1.0.0 (https://indifit.app)';

final foodApiServiceProvider = Provider<FoodApiService>((ref) {
  final dio = ref.watch(openFoodFactsDioProvider);
  final policy = ref.watch(privacyPolicyProvider);
  return FoodApiService(dio, policy);
});

/// Open Food Facts is a public third-party provider and must never receive the
/// IndiFit backend bootstrap credential carried by [dioProvider].
final openFoodFactsDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: kOpenFoodFactsConnectTimeout,
      receiveTimeout: kOpenFoodFactsReceiveTimeout,
      sendTimeout: kOpenFoodFactsSendTimeout,
      headers: const {'User-Agent': kOpenFoodFactsUserAgent},
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

class FoodApiResult {
  final String name;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double servingSize;
  final String servingUnit;
  final String? barcode;

  FoodApiResult({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    required this.servingUnit,
    this.barcode,
  });
}

class FoodApiService {
  final Dio _dio;
  final PrivacyPolicy? _policy;

  FoodApiService([Dio? dio, PrivacyPolicy? policy])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: kOpenFoodFactsConnectTimeout,
              receiveTimeout: kOpenFoodFactsReceiveTimeout,
              sendTimeout: kOpenFoodFactsSendTimeout,
              headers: const {'User-Agent': kOpenFoodFactsUserAgent},
            ),
          ),
      _policy = policy;

  // 1. Fetch product by barcode (Open Food Facts v2 API)
  Future<FoodApiResult?> fetchByBarcode(String barcode) async {
    if (_policy != null && !_policy.isOpenFoodFactsAllowed) {
      throw StateError(
        'Online food lookup is blocked while Strict Offline Mode is enabled.',
      );
    }
    try {
      final url =
          'https://world.openfoodfacts.org/api/v2/product/$barcode.json';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['status'] == 1 && data['product'] != null) {
          final p = data['product'];
          final nutriments = p['nutriments'] ?? {};

          final name = p['product_name'] ?? 'Unknown Product';

          // Get values per 100g
          final double? kcal = _readNumber(
            nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'],
          );
          final double? protein = _readNumber(nutriments['proteins_100g']);
          final double? carbs = _readNumber(nutriments['carbohydrates_100g']);
          final double? fat = _readNumber(nutriments['fat_100g']);

          // Serving size info
          final servingQtyText = p['serving_quantity']?.toString() ?? '100';
          final servingSize = double.tryParse(servingQtyText) ?? 100.0;
          final servingUnit = p['serving_quantity_unit'] ?? 'g';

          return FoodApiResult(
            name: name,
            calories: kcal,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: servingSize,
            servingUnit: servingUnit,
            barcode: barcode,
          );
        }
      }
      return null;
    } on DioException {
      rethrow;
    }
  }

  // 2. Search products online (Open Food Facts Search API)
  Future<List<FoodApiResult>> searchOnline(
    String query, {
    CancelToken? cancelToken,
  }) async {
    if (query.trim().isEmpty) return [];
    if (_policy != null && !_policy.isOpenFoodFactsAllowed) {
      throw StateError(
        'Online food lookup is blocked while Strict Offline Mode is enabled.',
      );
    }

    const url = 'https://world.openfoodfacts.org/cgi/search.pl';
    final stopwatch = Stopwatch()..start();
    if (kDebugMode) unawaited(_logDns(Uri.parse(url).host));
    AppLogger.info(
      'event=request_start host=world.openfoodfacts.org path=/cgi/search.pl '
          'query_length=${query.trim().length} connect_timeout_ms='
          '${_dio.options.connectTimeout?.inMilliseconds} receive_timeout_ms='
          '${_dio.options.receiveTimeout?.inMilliseconds}',
      'OpenFoodFacts',
    );
    try {
      final response = await _dio.get(
        url,
        cancelToken: cancelToken,
        queryParameters: {
          'search_terms': query,
          'search_simple': 1,
          'action': 'process',
          'json': 1,
          'page_size': 10,
          'fields':
              'code,product_name,nutriments,serving_quantity,serving_quantity_unit',
        },
      );
      stopwatch.stop();
      AppLogger.info(
        'event=request_complete host=world.openfoodfacts.org '
            'path=/cgi/search.pl status=${response.statusCode ?? 0} '
            'elapsed_ms=${stopwatch.elapsedMilliseconds}',
        'OpenFoodFacts',
      );

      if (response.statusCode == 200 && response.data != null) {
        final products = response.data['products'] as List?;
        if (products == null) return [];

        return products.map((p) {
          final nutriments = p['nutriments'] ?? {};
          final name = p['product_name'] ?? 'Unknown Product';

          final double? kcal = _readNumber(nutriments['energy-kcal_100g']);
          final double? protein = _readNumber(nutriments['proteins_100g']);
          final double? carbs = _readNumber(nutriments['carbohydrates_100g']);
          final double? fat = _readNumber(nutriments['fat_100g']);

          final servingQtyText = p['serving_quantity']?.toString() ?? '100';
          final servingSize = double.tryParse(servingQtyText) ?? 100.0;
          final servingUnit = p['serving_quantity_unit'] ?? 'g';

          return FoodApiResult(
            name: name,
            calories: kcal,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: servingSize,
            servingUnit: servingUnit,
            barcode: _readReference(p['code'] ?? p['id']),
          );
        }).toList();
      }
      return [];
    } on DioException catch (error) {
      stopwatch.stop();
      AppLogger.warning(
        'event=request_failed host=world.openfoodfacts.org '
            'path=/cgi/search.pl type=${error.type.name} '
            'status=${error.response?.statusCode ?? 0} '
            'tls_failure=${error.type == DioExceptionType.badCertificate} '
            'cancelled=${CancelToken.isCancel(error)} '
            'elapsed_ms=${stopwatch.elapsedMilliseconds}',
        'OpenFoodFacts',
      );
      rethrow;
    }
  }

  static Future<void> _logDns(String host) async {
    final stopwatch = Stopwatch()..start();
    try {
      final addresses = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 4));
      stopwatch.stop();
      AppLogger.info(
        'event=dns_result host=$host addresses='
            '${addresses.map((address) => address.address).join(',')} '
            'elapsed_ms=${stopwatch.elapsedMilliseconds}',
        'OpenFoodFacts',
      );
    } catch (error) {
      stopwatch.stop();
      AppLogger.warning(
        'event=dns_failed host=$host error_type=${error.runtimeType} '
            'elapsed_ms=${stopwatch.elapsedMilliseconds}',
        'OpenFoodFacts',
      );
    }
  }

  static double? _readNumber(Object? raw) {
    if (raw is num && raw.isFinite) return raw.toDouble();
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      return parsed != null && parsed.isFinite ? parsed : null;
    }
    return null;
  }

  static String? _readReference(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }
}
