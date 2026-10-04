import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/di/core_providers.dart';
import '../../core/di/providers.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/utils/app_logger.dart';
import '../database/app_database.dart';

const Duration kFoodApiConnectTimeout = Duration(seconds: 15);
const Duration kFoodApiReceiveTimeout = Duration(seconds: 15);
const Duration kFoodApiSendTimeout = Duration(seconds: 15);

// Keep legacy constants for backwards-compatibility
const Duration kOpenFoodFactsConnectTimeout = Duration(seconds: 8);
const Duration kOpenFoodFactsReceiveTimeout = Duration(seconds: 12);
const Duration kOpenFoodFactsSendTimeout = Duration(seconds: 8);

/// Open Food Facts asks apps to identify as `AppName/Version (ContactEmail)`.
const String kOpenFoodFactsUserAgent = 'IndiFit/1.0.0 (privacy@indifit.app)';
const String kOpenFoodFactsSearchUrl =
    'https://search.openfoodfacts.org/search';

final foodApiServiceProvider = Provider<FoodApiService>((ref) {
  final dio = ref.watch(dioProvider);
  final policy = ref.watch(privacyPolicyProvider);
  final db = ref.watch(databaseProvider);
  final offDio = ref.watch(openFoodFactsDioProvider);
  return FoodApiService(dio, policy, db, AppConfig.backendUrl, offDio);
});

/// Open Food Facts is an emergency unauthenticated fallback provider and must never
/// receive the IndiFit backend credential carried by [dioProvider].
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
  final double? fiber;
  final double? sodium;
  final double? addedSugar;
  final double? saturatedFat;
  final double servingSize;
  final String servingUnit;
  final String? barcode;
  final String? providerId;
  final String? brand;
  final String? packageQuantity;
  final String? categoryId;
  final String? nameHindi;
  final List<Map<String, dynamic>>? servingOptions;
  final String? provenance;
  final double? confidence;

  FoodApiResult({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
    this.sodium,
    this.addedSugar,
    this.saturatedFat,
    required this.servingSize,
    required this.servingUnit,
    this.barcode,
    this.providerId,
    this.brand,
    this.packageQuantity,
    this.categoryId,
    this.nameHindi,
    this.servingOptions,
    this.provenance,
    this.confidence,
  });

  /// True only when energy + all macros are present. Incomplete provider data
  /// must go through explicit review/custom entry, never silent zero-fill.
  bool get hasCompleteMacros =>
      calories != null && protein != null && carbs != null && fat != null;

  factory FoodApiResult.fromBackendJson(Map<String, dynamic> json) {
    final rawServingOptions = json['serving_options'];
    List<Map<String, dynamic>>? servingOptions;
    if (rawServingOptions is List) {
      servingOptions = rawServingOptions
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final id = json['id']?.toString();
    final name = json['name']?.toString().trim() ?? '';
    final brand = _readReference(json['brand']);
    final catId = json['category_id']?.toString() ?? 'general';

    double? conf;
    if (json['confidence'] is num) {
      conf = (json['confidence'] as num).toDouble();
    } else if (json['confidence'] == 'high') {
      conf = 1.0;
    } else if (json['confidence'] == 'medium') {
      conf = 0.7;
    }

    return FoodApiResult(
      name: name,
      nameHindi: _readReference(json['name_hindi']),
      brand: brand,
      categoryId: catId,
      calories: _readNumber(json['calories']),
      protein: _readNumber(json['protein_g']),
      carbs: _readNumber(json['carbs_g']),
      fat: _readNumber(json['fat_g']),
      fiber: _readNumber(json['fiber_g']),
      sodium: _readNumber(json['sodium_mg']),
      servingSize: _readNumber(json['serving_size']) ?? 100.0,
      servingUnit: json['serving_unit']?.toString() ?? 'g',
      servingOptions: servingOptions,
      barcode: id,
      providerId: id,
      provenance: json['provenance']?.toString(),
      confidence: conf,
    );
  }

  factory FoodApiResult.fromOffProductJson(
    Map<String, dynamic> p, {
    String? barcode,
  }) {
    final nutriments = p['nutriments'] ?? {};
    final name = p['product_name']?.toString().trim() ?? 'Unknown Product';
    final providerId = barcode ?? _readReference(p['code'] ?? p['id']);

    final double? kcal = _readNumber(
      nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'],
    );
    final double? protein = _readNumber(nutriments['proteins_100g']);
    final double? carbs = _readNumber(nutriments['carbohydrates_100g']);
    final double? fat = _readNumber(nutriments['fat_100g']);
    final double? fiber = _readNumber(nutriments['fiber_100g']);
    final double? sodiumG = _readNumber(nutriments['sodium_100g']);
    final double? sodiumMg = sodiumG != null
        ? sodiumG * 1000.0
        : _readNumber(nutriments['sodium_mg_100g']);
    final double? addedSugar = _readNumber(
      nutriments['sugars_100g'] ?? nutriments['added-sugars_100g'],
    );
    final double? saturatedFat = _readNumber(nutriments['saturated-fat_100g']);

    final servingQtyText = p['serving_quantity']?.toString() ?? '100';
    final servingSize = double.tryParse(servingQtyText) ?? 100.0;
    final servingUnit = p['serving_quantity_unit'] ?? 'g';

    return FoodApiResult(
      name: name,
      calories: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sodium: sodiumMg,
      addedSugar: addedSugar,
      saturatedFat: saturatedFat,
      servingSize: servingSize,
      servingUnit: servingUnit,
      barcode: providerId,
      providerId: providerId,
      brand: _readBrands(p['brands']),
      packageQuantity: _readReference(p['quantity']),
    );
  }

  Map<String, dynamic> toSanitizedCacheJson() {
    return {
      'id': providerId ?? barcode,
      'name': name,
      if (nameHindi != null) 'name_hindi': nameHindi,
      if (brand != null) 'brand': brand,
      if (categoryId != null) 'category_id': categoryId,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein_g': protein,
      if (carbs != null) 'carbs_g': carbs,
      if (fat != null) 'fat_g': fat,
      if (fiber != null) 'fiber_g': fiber,
      if (sodium != null) 'sodium_mg': sodium,
      'serving_size': servingSize,
      'serving_unit': servingUnit,
      if (servingOptions != null) 'serving_options': servingOptions,
      if (provenance != null) 'provenance': provenance,
      if (confidence != null) 'confidence': confidence,
    };
  }
}

class FoodApiService {
  final Dio _dio;
  final PrivacyPolicy? _policy;
  final AppDatabase? _db;
  final String _baseUrl;
  final Dio? _openFoodFactsDio;

  FoodApiService([
    Dio? dio,
    PrivacyPolicy? policy,
    AppDatabase? db,
    String? baseUrl,
    Dio? openFoodFactsDio,
  ]) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: kFoodApiConnectTimeout,
               receiveTimeout: kFoodApiReceiveTimeout,
               sendTimeout: kFoodApiSendTimeout,
             ),
           ),
       _policy = policy,
       _db = db,
       _baseUrl = baseUrl ?? AppConfig.backendUrl,
       _openFoodFactsDio = openFoodFactsDio;

  static String computeQueryHash(String query, [String language = 'hinglish']) {
    final normalized = '${query.trim().toLowerCase()}_$language';
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  /// 1. Fetch product by barcode (curated FMCG -> Open Food Facts v2 fallback)
  Future<FoodApiResult?> fetchByBarcode(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return null;

    if (_policy != null && !_policy.isNutritionOnlineAllowed) {
      throw StateError(
        'Online food lookup is blocked while Strict Offline Mode or online nutrition is disabled.',
      );
    }

    // No backend configured (release builds today): Open Food Facts directly.
    if (_baseUrl.isEmpty) return _fetchByBarcodeOff(cleanCode);

    try {
      final response = await _dio.get('$_baseUrl/api/food/barcode/$cleanCode');
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final candidate = data['candidate'];
        if (candidate is Map) {
          return FoodApiResult.fromBackendJson(
            Map<String, dynamic>.from(candidate),
          );
        }
      }
      return null;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      // If backend is unreachable or internal error and OFF client is available, try fallback
      if (_openFoodFactsDio != null && _isBackendUnavailable(error)) {
        return _fetchByBarcodeOff(cleanCode);
      }
      rethrow;
    }
  }

  /// The backend could not be reached or is down, so Open Food Facts can
  /// answer instead. Client errors (4xx) and cancellations are not retried.
  static bool _isBackendUnavailable(DioException error) =>
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.response?.statusCode == 502 ||
      error.response?.statusCode == 503;

  Future<FoodApiResult?> _fetchByBarcodeOff(String barcode) async {
    if (_openFoodFactsDio == null) return null;
    try {
      final url =
          'https://world.openfoodfacts.org/api/v2/product/$barcode.json';
      final response = await _openFoodFactsDio.get(url);
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        if (data['status'] == 1 && data['product'] is Map) {
          return FoodApiResult.fromOffProductJson(
            Map<String, dynamic>.from(data['product']),
            barcode: barcode,
          );
        }
      }
      return null;
    } on DioException {
      return null;
    }
  }

  /// 2. Search products online through IndiFit Backend Proxy (or OFF fallback).
  /// Full-text queries use POST so the search text is not placed in URLs or
  /// ordinary access logs. Drift SQLite disk cache is checked first for 0ms hits.
  Future<List<FoodApiResult>> searchOnline(
    String query, {
    CancelToken? cancelToken,
    String language = 'hinglish',
    int page = 1,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    if (_policy != null && !_policy.isNutritionOnlineAllowed) {
      throw StateError(
        'Online food lookup is blocked while Strict Offline Mode or online nutrition is disabled.',
      );
    }

    final queryHash = computeQueryHash(trimmed, language);

    // 1. Check Drift disk cache (0ms latency contract)
    if (_db != null) {
      try {
        final cached = await (_db.select(
          _db.foodSearchCache,
        )..where((tbl) => tbl.queryHash.equals(queryHash))).getSingleOrNull();

        if (cached != null) {
          final age = DateTime.now().toUtc().difference(
            cached.cachedAt.toUtc(),
          );
          if (age.inSeconds < cached.ttlSeconds) {
            final decoded = jsonDecode(cached.responseJson);
            if (decoded is Map && decoded['results'] is List) {
              return (decoded['results'] as List)
                  .whereType<Map>()
                  .map(
                    (e) => FoodApiResult.fromBackendJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .where((r) => r.name.isNotEmpty)
                  .toList();
            }
          }
        }
      } catch (e) {
        AppLogger.warning(
          'Food search cache read failed: $e',
          'FoodApiService',
        );
      }
    }

    // 2. Network: the IndiFit backend proxy when one is configured, otherwise
    // (and whenever the backend is unreachable) Open Food Facts directly.
    final offDio = _openFoodFactsDio;
    final Map<dynamic, dynamic>? data;
    if (_baseUrl.isEmpty) {
      data = await _postSearch(
        kOpenFoodFactsSearchUrl,
        offDio ?? _dio,
        query: trimmed,
        language: language,
        page: page,
        limit: limit,
        cancelToken: cancelToken,
      );
    } else {
      Map<dynamic, dynamic>? backendData;
      try {
        backendData = await _postSearch(
          '$_baseUrl/api/food/search',
          _dio,
          query: trimmed,
          language: language,
          page: page,
          limit: limit,
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        if (offDio == null || !_isBackendUnavailable(error)) rethrow;
        backendData = await _postSearch(
          kOpenFoodFactsSearchUrl,
          offDio,
          query: trimmed,
          language: language,
          page: page,
          limit: limit,
          cancelToken: cancelToken,
        );
      }
      data = backendData;
    }
    if (data == null) return [];

    List<FoodApiResult> results = [];
    if (data['results'] is List) {
      results = (data['results'] as List)
          .whereType<Map>()
          .map(
            (e) => FoodApiResult.fromBackendJson(Map<String, dynamic>.from(e)),
          )
          .where((r) => r.name.isNotEmpty)
          .toList();
    } else if (data['hits'] is List) {
      results = (data['hits'] as List)
          .whereType<Map>()
          .map(
            (raw) => FoodApiResult.fromOffProductJson(
              Map<String, dynamic>.from(raw),
            ),
          )
          .where((r) => r.name.isNotEmpty)
          .toList();
    }

    // Cache allowlisted results in Drift disk cache
    if (_db != null && results.isNotEmpty) {
      try {
        final sanitizedResults = results
            .map((r) => r.toSanitizedCacheJson())
            .toList();
        final cachePayload = jsonEncode({
          'results': sanitizedResults,
          'count': sanitizedResults.length,
          'total_hits': data['total_hits'] ?? sanitizedResults.length,
          'has_more': data['has_more'] ?? false,
          'query': trimmed,
        });

        await _db
            .into(_db.foodSearchCache)
            .insertOnConflictUpdate(
              FoodSearchCacheCompanion.insert(
                queryHash: queryHash,
                queryText: trimmed,
                responseJson: cachePayload,
                cachedAt: Value(DateTime.now().toUtc()),
                ttlSeconds: const Value(604800), // 7 days
              ),
            );
      } catch (e) {
        AppLogger.warning(
          'Food search cache write failed: $e',
          'FoodApiService',
        );
      }
    }

    return results;
  }

  /// POSTs one search to [url] and returns the response body, or null for a
  /// non-200 or non-JSON reply. Open Food Facts and the backend take different
  /// payloads. Failures are logged (host and path only) and rethrown.
  Future<Map<dynamic, dynamic>?> _postSearch(
    String url,
    Dio dio, {
    required String query,
    required String language,
    required int page,
    required int limit,
    CancelToken? cancelToken,
  }) async {
    final uri = Uri.parse(url);
    final isOffSearch = uri.host.endsWith('openfoodfacts.org');
    final stopwatch = Stopwatch()..start();
    if (kDebugMode && uri.host.isNotEmpty) unawaited(_logDns(uri.host));

    AppLogger.info(
      'event=food_search_start host=${uri.host} path=${uri.path} '
          'query_length=${query.length}',
      'FoodApiService',
    );

    try {
      final response = await dio.post(
        url,
        cancelToken: cancelToken,
        data: isOffSearch
            ? {
                'q': query,
                'page_size': limit,
                'page': page,
                'langs': const ['en'],
                'fields': const [
                  'code',
                  'brands',
                  'product_name',
                  'quantity',
                  'nutriments',
                  'serving_quantity',
                  'serving_quantity_unit',
                ],
              }
            : {
                'query': query,
                'language': language,
                'page': page,
                'limit': limit,
              },
      );
      stopwatch.stop();

      AppLogger.info(
        'event=food_search_complete host=${uri.host} path=${uri.path} '
            'status=${response.statusCode ?? 0} '
            'elapsed_ms=${stopwatch.elapsedMilliseconds}',
        'FoodApiService',
      );

      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map;
      }
      return null;
    } on DioException catch (error) {
      stopwatch.stop();
      AppLogger.warning(
        'event=food_search_failed host=${uri.host} path=${uri.path} '
            'type=${error.type.name} '
            'status=${error.response?.statusCode ?? 0} '
            'tls_failure=${error.type == DioExceptionType.badCertificate} '
            'cancelled=${CancelToken.isCancel(error)} '
            'elapsed_ms=${stopwatch.elapsedMilliseconds}',
        'FoodApiService',
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
        'FoodApiService',
      );
    } catch (error) {
      stopwatch.stop();
      AppLogger.warning(
        'event=dns_failed host=$host error_type=${error.runtimeType} '
            'elapsed_ms=${stopwatch.elapsedMilliseconds}',
        'FoodApiService',
      );
    }
  }
}

double? _readNumber(Object? raw) {
  if (raw is num && raw.isFinite) return raw.toDouble();
  if (raw is String) {
    final parsed = double.tryParse(raw.trim());
    return parsed != null && parsed.isFinite ? parsed : null;
  }
  return null;
}

/// Open Food Facts sends `brands` as a comma-separated string from the product
/// API and as a list from search.openfoodfacts.org.
String? _readBrands(Object? raw) {
  if (raw is List) {
    return _readReference(
      raw
          .map((brand) => brand?.toString().trim() ?? '')
          .where((b) => b.isNotEmpty)
          .join(', '),
    );
  }
  return _readReference(raw);
}

String? _readReference(Object? raw) {
  if (raw == null) return null;
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}
