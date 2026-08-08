import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/health_provider.dart';
import 'package:indifit/data/repositories/health_service.dart';

class MockHealthService extends HealthService {
  int fetchCallCount = 0;
  int permissionRequestCount = 0;
  bool shouldGrantPermission = true;
  bool shouldThrowError = false;
  bool shouldThrowPermissionError = false;
  HealthDataSummary summaryToReturn = const HealthDataSummary(
    steps: 6500,
    activeCalories: 350.0,
    sleepHours: 7.5,
    isConnected: true,
  );

  @override
  Future<bool> requestPermissions() async {
    permissionRequestCount++;
    if (shouldThrowPermissionError) {
      throw Exception('Simulated permission platform error');
    }
    return shouldGrantPermission;
  }

  @override
  Future<HealthDataSummary> fetchTodayHealthData() async {
    fetchCallCount++;
    if (shouldThrowError) {
      throw Exception('Simulated Native Health SDK Error');
    }
    return summaryToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHealthService mockHealthService;

  setUp(() {
    mockHealthService = MockHealthService();
  });

  group('Task T6: Native Health State & Reliability Tests', () {
    test(
      'Initial creation loads health data and sets cached available state',
      () async {
        final container = ProviderContainer(
          overrides: [
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(healthStateProvider.notifier);
        await notifier.loadHealthData();

        final state = container.read(healthStateProvider);
        expect(state.status, equals(HealthStatus.available));
        expect(state.summary.steps, equals(6500));
        expect(state.summary.activeCalories, equals(350.0));
        expect(mockHealthService.fetchCallCount, equals(1));

        // Reading provider multiple times uses CACHED state and does NOT invoke fetchTodayHealthData again
        container.read(healthStateProvider);
        container.read(healthStateProvider);
        expect(mockHealthService.fetchCallCount, equals(1));
      },
    );

    test(
      'Explicit refresh triggers exactly one additional fetch call',
      () async {
        final container = ProviderContainer(
          overrides: [
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(healthStateProvider.notifier);
        await notifier.loadHealthData();
        expect(mockHealthService.fetchCallCount, equals(1));

        await notifier.refresh();
        expect(mockHealthService.fetchCallCount, equals(2));
        expect(
          container.read(healthStateProvider).status,
          equals(HealthStatus.available),
        );
      },
    );

    test('Permission denial sets distinct denied status', () async {
      mockHealthService.shouldGrantPermission = false;

      final container = ProviderContainer(
        overrides: [healthServiceProvider.overrideWithValue(mockHealthService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(healthStateProvider.notifier);
      await notifier.connectAndRefresh();

      final state = container.read(healthStateProvider);
      expect(state.status, equals(HealthStatus.denied));
      expect(state.errorMessage, contains('denied'));
      expect(mockHealthService.permissionRequestCount, equals(1));
    });

    test(
      'Permission not granted response sets notRequested status distinct from zero data',
      () async {
        mockHealthService.summaryToReturn = const HealthDataSummary(
          isConnected: false,
          statusMessage: 'Permissions not granted',
        );

        final container = ProviderContainer(
          overrides: [
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(healthStateProvider.notifier);
        await notifier.loadHealthData();

        final state = container.read(healthStateProvider);
        expect(state.status, equals(HealthStatus.notRequested));
        expect(state.summary.isConnected, isFalse);
      },
    );

    test('Connected user with 0 metrics sets distinct noData status', () async {
      mockHealthService.summaryToReturn = const HealthDataSummary(
        steps: 0,
        activeCalories: 0.0,
        sleepHours: 0.0,
        isConnected: true,
      );

      final container = ProviderContainer(
        overrides: [healthServiceProvider.overrideWithValue(mockHealthService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(healthStateProvider.notifier);
      await notifier.loadHealthData();

      final state = container.read(healthStateProvider);
      expect(state.status, equals(HealthStatus.noData));
      expect(state.summary.isConnected, isTrue);
    });

    test('HealthService exception produces error state', () async {
      mockHealthService.shouldThrowError = true;

      final container = ProviderContainer(
        overrides: [healthServiceProvider.overrideWithValue(mockHealthService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(healthStateProvider.notifier);
      await notifier.loadHealthData();

      final state = container.read(healthStateProvider);
      expect(state.status, equals(HealthStatus.error));
      expect(state.errorMessage, contains('load this right now'));
    });

    test(
      'Native health summary errors are not misclassified as not requested',
      () async {
        mockHealthService.summaryToReturn = const HealthDataSummary(
          isError: true,
          statusMessage: 'Health Connect is unavailable',
        );

        final container = ProviderContainer(
          overrides: [
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );
        addTearDown(container.dispose);

        await container.read(healthStateProvider.notifier).loadHealthData();

        final state = container.read(healthStateProvider);
        expect(state.status, equals(HealthStatus.error));
        expect(state.errorMessage, contains('unavailable'));
      },
    );

    test(
      'Permission platform errors produce error state instead of denial',
      () async {
        mockHealthService.shouldThrowPermissionError = true;

        final container = ProviderContainer(
          overrides: [
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );
        addTearDown(container.dispose);

        await container.read(healthStateProvider.notifier).connectAndRefresh();

        final state = container.read(healthStateProvider);
        expect(state.status, equals(HealthStatus.error));
        expect(state.errorMessage, contains('load this right now'));
      },
    );
  });
}
