import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/health_provider.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_health_activity_repository.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:indifit/features/settings/health_sync_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('R08G.4 Health authority state', () {
    test('platform-unavailable summary is not classified as denied', () async {
      final service = _FakeHealthService(
        summary: const HealthDataSummary(
          availability: HealthPlatformAvailability.unavailable,
          connectionStatus: HealthConnectionStatus.unavailable,
          statusMessage: 'Health data is unavailable on this device.',
        ),
      );
      final container = ProviderContainer(
        overrides: [healthServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(healthStateProvider.notifier).loadHealthData();

      expect(
        container.read(healthStateProvider).status,
        HealthStatus.unavailable,
      );
    });

    test('unsupported summary remains an honest unsupported state', () async {
      final service = _FakeHealthService(
        summary: const HealthDataSummary(
          availability: HealthPlatformAvailability.unsupported,
          connectionStatus: HealthConnectionStatus.unavailable,
          statusMessage:
              'Health integration is not supported on this platform.',
        ),
      );
      final container = ProviderContainer(
        overrides: [healthServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(healthStateProvider.notifier).loadHealthData();

      expect(
        container.read(healthStateProvider).status,
        HealthStatus.unsupported,
      );
    });

    test(
      'connect maps a denied request to denied and retains no access',
      () async {
        final service = _FakeHealthService(
          requestResult: false,
          requestStatus: HealthConnectionStatus.denied,
        );
        final container = ProviderContainer(
          overrides: [healthServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);

        await container.read(healthStateProvider.notifier).connectAndRefresh();

        final state = container.read(healthStateProvider);
        expect(state.status, HealthStatus.denied);
        expect(
          state.summary.resolvedConnectionStatus,
          HealthConnectionStatus.denied,
        );
        expect(state.summary.isConnected, isFalse);
        expect(service.permissionRequestCount, 1);
      },
    );

    test('successful partial permission remains partial and usable', () async {
      final service = _FakeHealthService(
        summary: const HealthDataSummary(
          steps: 1200,
          availability: HealthPlatformAvailability.supported,
          connectionStatus: HealthConnectionStatus.partial,
          permissionStates: {
            HealthCategory.steps: HealthPermissionStatus.granted,
            HealthCategory.activeEnergy: HealthPermissionStatus.denied,
          },
          integrationEnabled: true,
        ),
      );
      final container = ProviderContainer(
        overrides: [healthServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(healthStateProvider.notifier).connectAndRefresh();

      expect(container.read(healthStateProvider).status, HealthStatus.partial);
    });

    test(
      'a returned zero is data rather than an empty-state inference',
      () async {
        final service = _FakeHealthService(
          summary: const HealthDataSummary(
            steps: 0,
            availability: HealthPlatformAvailability.supported,
            connectionStatus: HealthConnectionStatus.connected,
            permissionStates: {
              HealthCategory.steps: HealthPermissionStatus.granted,
            },
            categoriesWithData: {HealthCategory.steps},
            integrationEnabled: true,
          ),
        );
        final container = ProviderContainer(
          overrides: [healthServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);

        await container.read(healthStateProvider.notifier).loadHealthData();

        expect(
          container.read(healthStateProvider).status,
          HealthStatus.available,
        );
        expect(container.read(healthStateProvider).summary.steps, 0);
      },
    );

    test(
      'failed read can be retried without changing the authority path',
      () async {
        final service = _FakeHealthService(failFirstFetch: true);
        final container = ProviderContainer(
          overrides: [healthServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(healthStateProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(container.read(healthStateProvider).status, HealthStatus.error);

        service.failFirstFetch = false;
        service.summary = const HealthDataSummary(
          steps: 100,
          availability: HealthPlatformAvailability.supported,
          connectionStatus: HealthConnectionStatus.connected,
        );
        await notifier.refresh();

        expect(
          container.read(healthStateProvider).status,
          HealthStatus.available,
        );
        expect(service.fetchCount, greaterThanOrEqualTo(2));
      },
    );

    test(
      'disconnect persists the local gate and does not require history deletion',
      () async {
        final service = HealthService();
        await service.setIntegrationEnabled(true);
        expect(await service.getIntegrationEnabled(), isTrue);

        await service.disconnect();

        expect(await service.getIntegrationEnabled(), isFalse);
      },
    );

    test(
      'reviewed B02 activity import remains the sole canonical ingestion path',
      () async {
        final db = AppDatabase.memory();
        addTearDown(db.close);
        final importer = HealthActivityImportRepository(db);
        final input = B02HealthActivityInput(
          provider: 'health_connect',
          providerType: 'EXERCISE_SESSION_TYPE_WALKING',
          externalId: 'provider-activity-1',
          sourceName: 'Health Connect',
          fingerprint: 'fingerprint-1',
          startedAtUtc: DateTime.utc(2026, 8, 26, 7, 30),
          endedAtUtc: DateTime.utc(2026, 8, 26, 8),
        );
        final first = await importer.importActivity(input);
        final second = await importer.importActivity(input);

        expect(first.status, B02HealthImportStatus.imported);
        expect(first.activityType, B02ActivityType.walking);
        expect(second.status, B02HealthImportStatus.duplicate);
        expect(await db.select(db.workoutSessions).get(), hasLength(1));
        expect(await db.select(db.healthProvenances).get(), hasLength(1));
      },
    );
  });

  group('R08G.4 Health consumer surface', () {
    testWidgets('disconnected state keeps categories off and offers connect', (
      tester,
    ) async {
      final service = _FakeHealthService(
        summary: const HealthDataSummary(
          availability: HealthPlatformAvailability.supported,
          connectionStatus: HealthConnectionStatus.notConnected,
          permissionStates: {
            HealthCategory.steps: HealthPermissionStatus.notRequested,
          },
        ),
      );
      await _pumpScreen(tester, service);

      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('Connect health data'), findsOneWidget);
      expect(find.text('Disconnect'), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
      expect(find.textContaining('(Read)'), findsNothing);
      expect(find.textContaining('(Write)'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('denied state does not relabel categories as unrequested', (
      tester,
    ) async {
      final service = _FakeHealthService(
        summary: const HealthDataSummary(
          availability: HealthPlatformAvailability.supported,
          connectionStatus: HealthConnectionStatus.denied,
          integrationEnabled: false,
        ),
      );
      await _pumpScreen(tester, service);

      expect(find.text('Permission not granted'), findsOneWidget);
      expect(find.textContaining('Status: Not allowed'), findsWidgets);
      expect(find.textContaining('Status: Not requested'), findsNothing);
    });

    testWidgets(
      'loading state shows a status and keeps category switches inactive',
      (tester) async {
        final service = _FakeHealthService(
          summary: const HealthDataSummary(
            availability: HealthPlatformAvailability.supported,
            connectionStatus: HealthConnectionStatus.notConnected,
          ),
        );
        final notifier = _LoadingHealthNotifier(service);
        await _pumpScreen(tester, service, notifier: notifier, settle: false);

        expect(find.text('Checking Health data'), findsOneWidget);
        expect(
          tester.widget<Switch>(find.byType(Switch).first).onChanged,
          isNull,
        );

        notifier.refreshCompleter.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'connected state shows only allowed categories and exact copy',
      (tester) async {
        final service = _FakeHealthService(
          summary: const HealthDataSummary(
            steps: 7200,
            activeCalories: 280,
            sleepHours: 7,
            isConnected: true,
            availability: HealthPlatformAvailability.supported,
            connectionStatus: HealthConnectionStatus.connected,
            integrationEnabled: true,
            permissionStates: {
              HealthCategory.steps: HealthPermissionStatus.granted,
              HealthCategory.activeEnergy: HealthPermissionStatus.granted,
              HealthCategory.sleep: HealthPermissionStatus.granted,
              HealthCategory.restingHeartRate: HealthPermissionStatus.granted,
              HealthCategory.workoutImport: HealthPermissionStatus.granted,
              HealthCategory.weightExport: HealthPermissionStatus.granted,
            },
            categoriesWithData: {
              HealthCategory.steps,
              HealthCategory.activeEnergy,
              HealthCategory.sleep,
            },
          ),
        );
        await _pumpScreen(
          tester,
          service,
          size: const Size(320, 568),
          textScale: 2,
          theme: AppTheme.darkTheme,
        );

        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Disconnect'), findsOneWidget);
        expect(find.text('Refresh health data'), findsWidgets);
        expect(find.textContaining('(Read)'), findsNothing);
        expect(find.textContaining('(Write)'), findsNothing);
        expect(find.text('Auto-sync on app open'), findsNothing);
        expect(find.textContaining('sync all'), findsNothing);
        expect(
          find.textContaining('Choose what IndiFit may use'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Existing IndiFit history stays'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'partial state exposes the distinction without claiming full access',
      (tester) async {
        final service = _FakeHealthService(
          summary: const HealthDataSummary(
            availability: HealthPlatformAvailability.supported,
            connectionStatus: HealthConnectionStatus.partial,
            permissionStates: {
              HealthCategory.steps: HealthPermissionStatus.granted,
              HealthCategory.activeEnergy: HealthPermissionStatus.denied,
              HealthCategory.sleep: HealthPermissionStatus.notRequested,
              HealthCategory.restingHeartRate: HealthPermissionStatus.denied,
              HealthCategory.workoutImport: HealthPermissionStatus.granted,
              HealthCategory.weightExport: HealthPermissionStatus.denied,
            },
            integrationEnabled: true,
          ),
        );
        await _pumpScreen(tester, service);

        expect(find.text('Partly connected'), findsOneWidget);
        expect(find.text('Connected'), findsNothing);
        expect(find.textContaining('Allowed'), findsWidgets);
        expect(find.textContaining('Not allowed'), findsWidgets);
      },
    );

    testWidgets(
      'opaque read permission is labelled and shown as locally enabled',
      (tester) async {
        final service = _FakeHealthService(
          summary: const HealthDataSummary(
            availability: HealthPlatformAvailability.supported,
            connectionStatus: HealthConnectionStatus.unknown,
            permissionStates: {
              HealthCategory.steps: HealthPermissionStatus.unknown,
            },
            integrationEnabled: true,
            platformName: 'Apple Health',
          ),
        );
        await _pumpScreen(tester, service);

        expect(find.text('Access status unavailable'), findsOneWidget);
        expect(
          find.textContaining('only uses data the system returns'),
          findsOneWidget,
        );
        expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
        expect(find.text('0'), findsNothing);
      },
    );

    testWidgets(
      'unsupported provider activities and provider calories stay out of UI',
      (tester) async {
        final service = _FakeHealthService(
          summary: const HealthDataSummary(
            availability: HealthPlatformAvailability.supported,
            connectionStatus: HealthConnectionStatus.connected,
            integrationEnabled: true,
          ),
          activities: const [
            {
              'imported': false,
              'title': 'Unsupported provider workout',
              'durationMinutes': 10,
              'calories': 999,
            },
            {
              'imported': true,
              'activityType': 'walking',
              'title': 'Imported activity',
              'durationMinutes': 20,
              'calories': 123,
            },
          ],
        );
        await _pumpScreen(tester, service);

        expect(find.text('Unsupported provider workout'), findsNothing);
        expect(find.text('Imported activities'), findsOneWidget);
        expect(find.textContaining('20 min'), findsOneWidget);
        expect(find.textContaining('123'), findsNothing);
        expect(find.textContaining('999'), findsNothing);
      },
    );

    testWidgets(
      'unsupported state has no dead connect action and is accessible',
      (tester) async {
        final service = _FakeHealthService(
          summary: const HealthDataSummary(
            availability: HealthPlatformAvailability.unsupported,
            connectionStatus: HealthConnectionStatus.unavailable,
            statusMessage:
                'Health integration is not supported on this platform.',
          ),
        );
        await _pumpScreen(tester, service);

        final semanticsHandle = tester.ensureSemantics();
        try {
          expect(find.text('Not supported on this platform'), findsOneWidget);
          expect(find.text('Connect health data'), findsNothing);
          expect(find.bySemanticsLabel('Refresh health data'), findsOneWidget);
          expect(
            find.textContaining('Status: Unavailable on this device'),
            findsWidgets,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semanticsHandle.dispose();
        }
      },
    );

    testWidgets(
      'disconnect action calls the service and leaves the screen truthful',
      (tester) async {
        final service = _FakeHealthService(
          summary: const HealthDataSummary(
            isConnected: true,
            availability: HealthPlatformAvailability.supported,
            connectionStatus: HealthConnectionStatus.connected,
            integrationEnabled: true,
          ),
        );
        await _pumpScreen(tester, service);

        await tester.tap(find.text('Disconnect'));
        await tester.pumpAndSettle();

        expect(service.disconnected, isTrue);
        expect(find.text('Disconnect'), findsNothing);
        expect(find.text('Connect health data'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeHealthService service, {
  Size size = const Size(390, 844),
  double textScale = 1,
  ThemeData? theme,
  HealthStateNotifier? notifier,
  bool settle = true,
}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final database = AppDatabase.memory();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    unawaited(database.close());
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        healthServiceProvider.overrideWithValue(service),
        healthStateProvider.overrideWith(
          (ref) => notifier ?? _FixedHealthNotifier(service),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          home: const HealthSyncHubScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
  }
}

class _FakeHealthService extends HealthService {
  _FakeHealthService({
    this.summary = const HealthDataSummary(),
    this.requestResult = true,
    this.requestStatus = HealthConnectionStatus.connected,
    this.failFirstFetch = false,
    this.activities = const [],
  });

  HealthDataSummary summary;
  bool requestResult;
  HealthConnectionStatus requestStatus;
  bool failFirstFetch;
  List<Map<String, dynamic>> activities;
  bool disconnected = false;
  int fetchCount = 0;
  int permissionRequestCount = 0;

  @override
  HealthConnectionStatus get lastPermissionRequestStatus => requestStatus;

  @override
  Future<HealthDataSummary> fetchTodayHealthData() async {
    fetchCount++;
    if (failFirstFetch && fetchCount == 1) {
      throw StateError('test-only failure');
    }
    return summary;
  }

  @override
  Future<bool> requestPermissions() async {
    permissionRequestCount++;
    return requestResult;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
    summary = summary.copyWith(
      isConnected: false,
      connectionStatus: HealthConnectionStatus.notConnected,
      integrationEnabled: false,
      permissionStates: const {},
    );
    await super.disconnect();
  }

  @override
  Future<String?> getLastSyncTime() async => null;

  @override
  Future<Map<HealthCategory, bool>> getAllCategoryStates() async => {
    for (final category in HealthCategory.values) category: true,
  };

  @override
  Future<List<Map<String, dynamic>>> importOutdoorActivities([
    AppDatabase? db,
  ]) async => activities;

  @override
  Future<bool> requestCategoryPermissions(HealthCategory category) async =>
      true;
}

class _FixedHealthNotifier extends HealthStateNotifier {
  // The fake subtype is retained so refresh can follow mutable test state.
  // ignore: use_super_parameters
  _FixedHealthNotifier(_FakeHealthService service)
    : _service = service,
      _summary = service.summary,
      super(service) {
    state = HealthState(
      status: _statusFor(summary: serviceSummary),
      summary: serviceSummary,
    );
  }

  final HealthDataSummary _summary;
  final _FakeHealthService _service;

  HealthDataSummary get serviceSummary => _summary;

  static HealthStatus _statusFor({required HealthDataSummary summary}) {
    if (summary.availability == HealthPlatformAvailability.unsupported) {
      return HealthStatus.unsupported;
    }
    if (summary.availability == HealthPlatformAvailability.unavailable) {
      return HealthStatus.unavailable;
    }
    return switch (summary.resolvedConnectionStatus) {
      HealthConnectionStatus.connected => HealthStatus.available,
      HealthConnectionStatus.partial => HealthStatus.partial,
      HealthConnectionStatus.denied => HealthStatus.denied,
      HealthConnectionStatus.unknown => HealthStatus.unknown,
      HealthConnectionStatus.unavailable => HealthStatus.unavailable,
      HealthConnectionStatus.notConnected => HealthStatus.notRequested,
    };
  }

  @override
  Future<void> loadHealthData() async {}

  @override
  Future<void> refresh() async {
    final summary = _service.summary;
    state = HealthState(
      status: _statusFor(summary: summary),
      summary: summary,
    );
  }

  @override
  Future<void> connectAndRefresh() async {}
}

class _LoadingHealthNotifier extends HealthStateNotifier {
  _LoadingHealthNotifier(super.service) {
    state = const HealthState(
      status: HealthStatus.loading,
      summary: HealthDataSummary(
        availability: HealthPlatformAvailability.supported,
        connectionStatus: HealthConnectionStatus.notConnected,
      ),
    );
  }

  final refreshCompleter = Completer<void>();

  @override
  Future<void> loadHealthData() async {}

  @override
  Future<void> refresh() => refreshCompleter.future;

  @override
  Future<void> connectAndRefresh() async {}
}
