import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/services/crash_reporting_service.dart';
import 'package:indifit/data/repositories/ai_routine_service.dart';
import 'package:indifit/data/repositories/food_api_service.dart';
import 'package:indifit/data/repositories/meal_plan_service.dart';
import 'package:indifit/data/repositories/weekly_report_service.dart';
import 'package:indifit/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDioAdapter implements HttpClientAdapter {
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    throw Exception(
      'MockDioAdapter should never be called when requests are blocked',
    );
  }

  @override
  void close({bool force = false}) {}
}

class FailingDioAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'No network',
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDioAdapter mockAdapter;
  late Dio dio;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAdapter = MockDioAdapter();
    dio = Dio();
    dio.httpClientAdapter = mockAdapter;
  });

  group('Task T5: Enforced Privacy & Offline Network Policy Tests', () {
    test(
      'Telemetry defaults to OFF for a new user without prior explicit consent',
      () async {
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(CrashReportingService.prefCrashReportingEnabled),
          isNull,
        );
        expect(CrashReportingService.isEnabled, isFalse);
      },
    );

    test(
      'Backend AI requests (Weekly Report) are blocked in offline mode and use local generator',
      () async {
        const offlinePolicy = PrivacyPolicy(
          isOfflineOnly: true,
          isTelemetryEnabled: true,
        );

        final service = WeeklyReportService(dio, offlinePolicy);

        final result = await service.generateReport(
          totalCaloriesLogged: 14000,
          calorieGoal: 2000,
          workoutSessionsCount: 4,
          totalVolumeKg: 5000,
          prsCount: 2,
          adherenceScore: 90.0,
        );

        expect(result.isFallback, isTrue);
        expect(result.fallbackReason, contains('Offline'));
        expect(
          mockAdapter.requestCount,
          equals(0),
        ); // Zero outbound HTTP requests
      },
    );

    test(
      'Backend AI requests (AiRoutineService) are blocked in offline mode',
      () async {
        const offlinePolicy = PrivacyPolicy(
          isOfflineOnly: true,
          isTelemetryEnabled: true,
        );

        final service = AiRoutineService(dio, offlinePolicy);

        final result = await service.generateRoutine(
          goal: 'hypertrophy',
          equipment: 'dumbbells',
          daysPerWeek: 3,
          experience: 'intermediate',
          injuries: 'none',
        );

        expect(result.name, contains('Smart DUMBBELLS'));
        expect(result.days.isNotEmpty, isTrue);
        expect(
          mockAdapter.requestCount,
          equals(0),
        ); // Zero outbound HTTP requests
      },
    );

    test(
      'Backend AI requests (MealPlanService) are blocked in offline mode',
      () async {
        const offlinePolicy = PrivacyPolicy(
          isOfflineOnly: true,
          isTelemetryEnabled: true,
        );

        final service = MealPlanService(dio, offlinePolicy);

        final result = await service.generateMealPlan(
          calorieGoal: 2200,
          dietPreference: 'vegetarian',
        );

        expect(result.isFallback, isTrue);
        expect(result.fallbackReason, contains('Local offline plan'));
        expect(
          mockAdapter.requestCount,
          equals(0),
        ); // Zero outbound HTTP requests
      },
    );

    test(
      'Open Food Facts barcode and search lookups surface strict offline policy failures',
      () async {
        const offlinePolicy = PrivacyPolicy(
          isOfflineOnly: true,
          isTelemetryEnabled: true,
        );

        final service = FoodApiService(dio, offlinePolicy);

        await expectLater(
          service.fetchByBarcode('8901058852319'),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          service.searchOnline('Paneer'),
          throwsA(isA<StateError>()),
        );

        expect(
          mockAdapter.requestCount,
          equals(0),
        ); // Zero outbound HTTP requests
      },
    );

    test(
      'Open Food Facts network errors are not mistaken for missing products',
      () async {
        dio.httpClientAdapter = FailingDioAdapter();
        final service = FoodApiService(dio);

        await expectLater(
          service.fetchByBarcode('8901058852319'),
          throwsA(isA<DioException>()),
        );
        await expectLater(
          service.searchOnline('Paneer'),
          throwsA(isA<DioException>()),
        );
      },
    );

    test(
      'Open Food Facts provider client never carries the IndiFit backend key',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final providerDio = container.read(openFoodFactsDioProvider);
        expect(providerDio.options.headers, isNot(contains('x-indifit-key')));
      },
    );

    test(
      'PrivacyNetworkInterceptor rejects raw Dio requests when offline_only mode is active',
      () async {
        final container = ProviderContainer(
          overrides: [
            privacyPolicyProvider.overrideWith(
              (ref) => PrivacyPolicyNotifier()
                ..state = const PrivacyPolicy(
                  isOfflineOnly: true,
                  isTelemetryEnabled: false,
                ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final testDio = container.read(dioProvider);
        testDio.httpClientAdapter = mockAdapter;

        expect(
          () => testDio.get('https://api.indifit.app/api/ai/test'),
          throwsA(
            isA<DioException>().having(
              (e) => e.error.toString(),
              'error message',
              contains('blocked by strict offline privacy policy'),
            ),
          ),
        );

        expect(mockAdapter.requestCount, equals(0));
      },
    );

    test(
      'Persisted offline mode blocks the first Dio request at application bootstrap',
      () async {
        SharedPreferences.setMockInitialValues({
          PrivacyPolicyNotifier.prefOfflineOnly: true,
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            privacyPolicyProvider.overrideWith(
              (ref) => PrivacyPolicyNotifier(prefs),
            ),
          ],
        );
        addTearDown(container.dispose);

        final testDio = container.read(dioProvider);
        testDio.httpClientAdapter = mockAdapter;

        await expectLater(
          testDio.get('https://api.indifit.app/api/ai/test'),
          throwsA(isA<DioException>()),
        );
        expect(mockAdapter.requestCount, equals(0));
      },
    );

    test(
      'Toggling offline mode in SettingsController immediately updates PrivacyPolicy at runtime',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(settingsControllerProvider.notifier);

        expect(container.read(privacyPolicyProvider).isOfflineOnly, isFalse);

        await controller.toggleOfflineOnly(true);
        expect(container.read(privacyPolicyProvider).isOfflineOnly, isTrue);
        expect(container.read(privacyPolicyProvider).isAiAllowed, isFalse);
        expect(
          container.read(privacyPolicyProvider).isOpenFoodFactsAllowed,
          isFalse,
        );

        await controller.toggleOfflineOnly(false);
        expect(container.read(privacyPolicyProvider).isOfflineOnly, isFalse);
        expect(container.read(privacyPolicyProvider).isAiAllowed, isTrue);
      },
    );

    test(
      'PrivacyPolicyNotifier loads persisted offline state synchronously on startup',
      () async {
        SharedPreferences.setMockInitialValues({
          PrivacyPolicyNotifier.prefOfflineOnly: true,
          PrivacyPolicyNotifier.prefCrashReportingEnabled: true,
        });

        final prefs = await SharedPreferences.getInstance();
        final notifier = PrivacyPolicyNotifier(prefs);

        expect(notifier.state.isOfflineOnly, isTrue);
        expect(
          notifier.state.isTelemetryEnabled,
          isFalse,
        ); // Telemetry forced off when offline
      },
    );

    test(
      'Enabling offline mode automatically turns off telemetry and blocks subsequent telemetry toggles',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final notifier = PrivacyPolicyNotifier(prefs);

        await notifier.setTelemetryEnabled(true);
        expect(notifier.state.isTelemetryEnabled, isTrue);

        await notifier.setOfflineOnly(true);
        expect(notifier.state.isOfflineOnly, isTrue);
        expect(notifier.state.isTelemetryEnabled, isFalse);

        // Attempting to enable telemetry while offline is rejected
        await notifier.setTelemetryEnabled(true);
        expect(notifier.state.isTelemetryEnabled, isFalse);
      },
    );

    test('Offline mode immediately disables active crash reporting', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await CrashReportingService.setEnabled(true);
      expect(CrashReportingService.isEnabled, isTrue);

      final controller = container.read(settingsControllerProvider.notifier);
      await controller.toggleOfflineOnly(true);
      await controller.toggleCrashReporting(true);

      final prefs = await SharedPreferences.getInstance();
      expect(CrashReportingService.isEnabled, isFalse);
      expect(
        prefs.getBool(CrashReportingService.prefCrashReportingEnabled),
        isFalse,
      );
      expect(
        container.read(settingsControllerProvider).crashReportingEnabled,
        isFalse,
      );
    });
  });
}
