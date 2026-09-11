import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/health_service.dart';
import '../capabilities/capabilities_registry.dart';
import '../config/app_config.dart';
import '../privacy/privacy_policy.dart';
import '../services/civil_date_revision_notifier.dart';
import '../services/data_erasure_service.dart';
import '../services/local_schedule_date_service.dart';
import '../services/local_timezone_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final dataErasureServiceProvider = Provider<DataErasureService>((ref) {
  return DataErasureService(
    db: ref.watch(databaseProvider),
    cloudBackup: ref.watch(cloudBackupCapabilityProvider),
    account: ref.watch(accountCapabilityProvider),
    healthService: ref.watch(healthServiceProvider),
  );
});

final localScheduleDateServiceProvider = Provider<LocalScheduleDateService>((
  ref,
) {
  return LocalScheduleDateService();
});

final localTimezoneServiceProvider = Provider<LocalTimezoneService>((ref) {
  return LocalTimezoneService(
    dates: ref.watch(localScheduleDateServiceProvider),
  );
});

/// One shared date-boundary dependency for date-scoped consumer surfaces.
/// Database mutations still flow through their canonical repository watches;
/// this revision only handles a civil-date change while the app remains open.
final civilDateRevisionProvider =
    StateNotifierProvider<CivilDateRevisionNotifier, int>((ref) {
      return CivilDateRevisionNotifier(
        dates: ref.watch(localScheduleDateServiceProvider),
        timezoneId: () =>
            ref.read(localTimezoneServiceProvider).currentTimezoneId(),
      );
    });

final dioProvider = Provider<Dio>((ref) {
  // R09-A: this client exists only for legacy/post-V1 connected services. A
  // mobile release must remain fully usable without embedding a shared backend
  // credential. When a developer explicitly supplies one, add it only to this
  // dedicated client; Open Food Facts uses a separate credential-free client.
  final apiKey = AppConfig.rawApiKey.trim();
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {if (apiKey.isNotEmpty) 'x-indifit-key': apiKey},
    ),
  );
  dio.interceptors.add(PrivacyNetworkInterceptor(ref));
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(responseBody: false, requestBody: false),
    );
  }
  return dio;
});

class PrivacyNetworkInterceptor extends Interceptor {
  final Ref _ref;
  PrivacyNetworkInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final policy = _ref.read(privacyPolicyProvider);
    if (policy.isOfflineOnly) {
      handler.reject(
        DioException(
          requestOptions: options,
          error:
              'Outbound network call blocked by strict offline privacy policy.',
          type: DioExceptionType.cancel,
        ),
      );
      return;
    }
    handler.next(options);
  }
}
