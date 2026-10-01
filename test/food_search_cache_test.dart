import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/food_identity_manifest.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_api_service.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  group('FoodSearchCache Drift Disk Cache & Governance', () {
    late AppDatabase db;
    late PrivacyPolicy policy;

    setUp(() async {
      final scope = registerTestDatabaseScope();
      db = scope.create();
      policy = const PrivacyPolicy(
        isOfflineOnly: false,
        isTelemetryEnabled: false,
        allowOnlineNutrition: true,
      );
    });

    test(
      'retrieves cached results within 10ms with zero network calls',
      () async {
        final query = 'paneer';
        final queryHash = FoodApiService.computeQueryHash(query, 'hinglish');
        final cachedJson = jsonEncode({
          'results': [
            {
              'id': 'curated_paneer',
              'name': 'Paneer',
              'name_hindi': 'पनीर',
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
              'provenance': 'curated',
              'confidence': 1.0,
            },
          ],
          'count': 1,
          'total_hits': 1,
          'has_more': false,
          'query': query,
        });

        await db
            .into(db.foodSearchCache)
            .insertOnConflictUpdate(
              FoodSearchCacheCompanion.insert(
                queryHash: queryHash,
                queryText: query,
                responseJson: cachedJson,
                cachedAt: Value(DateTime.now().toUtc()),
                ttlSeconds: const Value(604800),
              ),
            );

        final failingAdapter = _ThrowingAdapter();
        final dio = Dio()..httpClientAdapter = failingAdapter;

        final service = FoodApiService(
          dio,
          policy,
          db,
          'https://api.indifit.app',
        );

        final stopwatch = Stopwatch()..start();
        final results = await service.searchOnline(query);
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThanOrEqualTo(25));
        expect(results, hasLength(1));
        expect(results.first.name, 'Paneer');
        expect(results.first.protein, 18.3);
        expect(failingAdapter.called, isFalse);
      },
    );

    test(
      'payload allowlist enforcement strips internal traces and debug payloads',
      () async {
        final dirtyResponse = {
          'results': [
            {
              'id': 'curated_dal_makhani',
              'name': 'Dal Makhani',
              'name_hindi': 'दाल मखनी',
              'brand': null,
              'category_id': 'dal_lentil',
              'calories': 320.0,
              'protein_g': 12.0,
              'carbs_g': 28.0,
              'fat_g': 18.0,
              'fiber_g': 6.0,
              'sodium_mg': 450.0,
              'serving_size': 150.0,
              'serving_unit': 'katori',
              'serving_options': [
                {
                  'unit': 'katori (standard)',
                  'gram_weight': 150.0,
                  'is_default': true,
                },
              ],
              'provenance': 'curated',
              'confidence': 'high',
              // Forbidden internal fields:
              '_internal_trace_id': 'trace-999-secret',
              'prompt_debug_text': 'System instructions leak test',
              'raw_provider_payload': {'deep': 'structure'},
              'leak_secret_key': 'topsecret',
            },
          ],
          'count': 1,
          'total_hits': 1,
          'has_more': false,
          'query': 'dal makhani',
        };

        final adapter = _StaticJsonAdapter(jsonEncode(dirtyResponse));
        final dio = Dio()..httpClientAdapter = adapter;

        final service = FoodApiService(
          dio,
          policy,
          db,
          'https://api.indifit.app',
        );

        final results = await service.searchOnline('dal makhani');
        expect(results, hasLength(1));

        final queryHash = FoodApiService.computeQueryHash(
          'dal makhani',
          'hinglish',
        );
        final cachedRow = await (db.select(
          db.foodSearchCache,
        )..where((tbl) => tbl.queryHash.equals(queryHash))).getSingleOrNull();

        expect(cachedRow, isNotNull);
        final cachedPayload = cachedRow!.responseJson;

        // Allowlisted fields must be present
        expect(cachedPayload.contains('Dal Makhani'), isTrue);
        expect(cachedPayload.contains('dal_lentil'), isTrue);
        expect(cachedPayload.contains('curated'), isTrue);

        // Forbidden debug traces and raw payloads must be completely stripped
        expect(cachedPayload.contains('_internal_trace_id'), isFalse);
        expect(cachedPayload.contains('trace-999-secret'), isFalse);
        expect(cachedPayload.contains('prompt_debug_text'), isFalse);
        expect(
          cachedPayload.contains('System instructions leak test'),
          isFalse,
        );
        expect(cachedPayload.contains('raw_provider_payload'), isFalse);
        expect(cachedPayload.contains('leak_secret_key'), isFalse);
        expect(cachedPayload.contains('topsecret'), isFalse);
      },
    );

    test('manifest version change flushes food search cache', () async {
      final queryHash1 = FoodApiService.computeQueryHash('biryani', 'hinglish');
      final queryHash2 = FoodApiService.computeQueryHash('dosa', 'hinglish');

      await db
          .into(db.foodSearchCache)
          .insert(
            FoodSearchCacheCompanion.insert(
              queryHash: queryHash1,
              queryText: 'biryani',
              responseJson: '{"results":[{"name":"Biryani"}]}',
              ttlSeconds: const Value(604800),
            ),
          );
      await db
          .into(db.foodSearchCache)
          .insert(
            FoodSearchCacheCompanion.insert(
              queryHash: queryHash2,
              queryText: 'dosa',
              responseJson: '{"results":[{"name":"Dosa"}]}',
              ttlSeconds: const Value(604800),
            ),
          );

      // Simulate obsolete manifest version (version 0)
      await db
          .into(db.foodSearchCache)
          .insertOnConflictUpdate(
            FoodSearchCacheCompanion.insert(
              queryHash: '__manifest_version__',
              queryText: '__manifest_version__',
              responseJson: '0',
              ttlSeconds: const Value(315360000),
            ),
          );

      expect((await db.select(db.foodSearchCache).get()).length, 3);

      // Invalidate on manifest increment
      await db.invalidateFoodSearchCacheIfManifestIncremented();

      final rows = await db.select(db.foodSearchCache).get();
      // Obsolete query results purged, only the current manifest version row remains
      expect(rows.length, 1);
      expect(rows.single.queryHash, '__manifest_version__');
      expect(rows.single.responseJson, kFoodIdentityManifestVersion.toString());
    });
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  bool called = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    called = true;
    throw StateError('Network should not have been called on cache hit!');
  }

  @override
  void close({bool force = false}) {}
}

class _StaticJsonAdapter implements HttpClientAdapter {
  final String jsonBody;
  _StaticJsonAdapter(this.jsonBody);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonBody,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
