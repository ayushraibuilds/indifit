import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/privacy/network_receipt.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/services/crash_reporting_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/catalog/catalog_update_service.dart';
import 'package:indifit/features/settings/food_database_screen.dart';
import 'package:indifit/features/settings/network_activity_screen.dart';
import 'package:indifit/features/support/tip_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/catalog_update_fakes.dart';
import 'support/real_catalogue.dart';

/// UF-21: the data receipt (Settings → Manage your data → Network activity).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 25, 9, 30);
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    NetworkReceipt.clock = () => now;
    NetworkReceipt.preferences = () async => prefs;
  });
  tearDown(() {
    NetworkReceipt.clock = DateTime.now;
    NetworkReceipt.preferences = SharedPreferences.getInstance;
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('kinds are told apart by the request', () {
    expect(
      networkCallKindFor(Uri.parse('https://api.test/api/food/search?q=dal')),
      NetworkCallKind.foodLookup,
    );
    expect(
      networkCallKindFor(Uri.parse('https://api.test/api/food/barcode/890')),
      NetworkCallKind.foodLookup,
    );
    expect(
      networkCallKindFor(
        Uri.parse('https://world.openfoodfacts.org/api/v2/product/890.json'),
      ),
      NetworkCallKind.foodLookup,
    );
    expect(
      networkCallKindFor(Uri.parse('https://api.test/api/ai/meal')),
      NetworkCallKind.ai,
    );
    expect(networkCallKindFor(Uri.parse(kTestManifestUrl)), isNull);
  });

  group('PrivacyNetworkInterceptor', () {
    Future<Dio> client({required bool offline}) async {
      SharedPreferences.setMockInitialValues({
        if (offline) PrivacyPolicyNotifier.prefOfflineOnly: true,
      });
      prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      if (offline) {
        await container
            .read(privacyPolicyProvider.notifier)
            .setOfflineOnly(true);
      }
      final dio = container.read(dioProvider);
      dio.httpClientAdapter = _Ok();
      return dio;
    }

    test('records food lookups and AI as they go out', () async {
      final dio = await client(offline: false);
      await dio.get('https://api.test/api/food/search?q=dal');
      await settle();
      expect(NetworkReceipt.lastRan(prefs, NetworkCallKind.foodLookup), now);
      expect(NetworkReceipt.lastRan(prefs, NetworkCallKind.ai), isNull);
      await dio.post('https://api.test/api/ai/meal');
      await settle();
      expect(NetworkReceipt.lastRan(prefs, NetworkCallKind.ai), now);
    });

    test('Offline mode blocks the call, and nothing is recorded', () async {
      final dio = await client(offline: true);
      await expectLater(
        dio.get('https://api.test/api/food/search?q=dal'),
        throwsA(isA<DioException>()),
      );
      await settle();
      expect(NetworkReceipt.lastRan(prefs, NetworkCallKind.foodLookup), isNull);
    });
  });

  group('food database updates', () {
    late RealCatalogue catalogue;
    setUp(() async => catalogue = await RealCatalogue.open());
    tearDown(() => catalogue.close());

    CatalogUpdateService service({required bool offline}) =>
        CatalogUpdateService(
          dio: Dio()..httpClientAdapter = FakeCatalogServer(),
          manifestUrl: kTestManifestUrl,
          db: catalogue.db,
          prefs: () async => prefs,
          registry: () async => catalogue.registry,
          isOfflineMode: () => offline,
          network: FakeCatalogNetwork(),
          nowUtc: () => now,
          appBuild: () async => 1,
        );

    test('a manifest check is recorded', () async {
      await service(offline: false).checkNow();
      expect(NetworkReceipt.lastRan(prefs, NetworkCallKind.foodDatabase), now);
    });

    test('Offline mode skips it, and nothing is recorded', () async {
      final result = await service(offline: true).checkNow();
      expect(result.outcome, CatalogUpdateOutcome.offlineMode);
      expect(
        NetworkReceipt.lastRan(prefs, NetworkCallKind.foodDatabase),
        isNull,
      );
    });
  });

  test('the tip jar records price lookups and purchases', () async {
    final store = InAppPurchaseTipStore(_FakeIap());
    await store.queryProducts({'tip_small'});
    await settle();
    expect(NetworkReceipt.lastRan(prefs, NetworkCallKind.tipJar), now);
  });

  group('crash reports', () {
    setUp(() {
      CrashReportingService.debugReset();
      CrashReportingService.sentryInitRunner = (configure, {appRunner}) async {
        await appRunner?.call();
      };
      CrashReportingService.sentryCloseRunner = () async {};
      CrashReportingService.debugDsnOverride =
          'https://key@o1.ingest.sentry.io/1';
    });
    tearDown(() => CrashReportingService.debugDsnOverride = null);

    test('only a report that is sent is recorded', () async {
      await CrashReportingService.initialize(() {});
      CrashReportingService.captureException(
        const FormatException('x'),
        StackTrace.current,
      );
      await settle();
      expect(
        NetworkReceipt.lastRan(prefs, NetworkCallKind.crashReports),
        isNull,
      );

      await CrashReportingService.setEnabled(true);
      CrashReportingService.captureException(
        const FormatException('x'),
        StackTrace.current,
      );
      await settle();
      expect(NetworkReceipt.lastRan(prefs, NetworkCallKind.crashReports), now);
      await CrashReportingService.setEnabled(false);
    });
  });

  test('status reads "Never", the last run, and Offline mode', () {
    final today = DateTime(2026, 10, 25);
    expect(networkActivityStatus(null, offline: false), 'Never');
    expect(
      networkActivityStatus(null, offline: true),
      'Never · Blocked by Offline mode',
    );
    final ran = DateTime(2026, 10, 25, 14, 5);
    expect(
      networkActivityStatus(ran, offline: false, today: today),
      'Last ran Today · 14:05',
    );
  });

  group('the screen', () {
    Future<void> open(WidgetTester tester, {bool offline = false}) async {
      if (offline) {
        await prefs.setBool(PrivacyPolicyNotifier.prefOfflineOnly, true);
      }
      await prefs.setInt(
        NetworkCallKind.foodLookup.prefKey,
        now.millisecondsSinceEpoch,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NetworkActivityScreen(),
                    ),
                  ),
                  child: const Text('Manage your data'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Manage your data'));
      await tester.pumpAndSettle();
    }

    String status(WidgetTester tester, NetworkCallKind kind) => tester
        .widget<Text>(find.byKey(ValueKey('network_status_${kind.id}')))
        .data!;

    testWidgets('one row per kind, with what it sends and when', (
      tester,
    ) async {
      await open(tester);
      for (final row in NetworkActivityRow.all) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('network_row_${row.kind.id}')),
          200,
        );
        expect(find.text(row.sends), findsOneWidget);
      }
      expect(status(tester, NetworkCallKind.tipJar), 'Never');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('network_row_food_lookup')),
        -200,
      );
      expect(
        status(tester, NetworkCallKind.foodLookup),
        startsWith('Last ran '),
      );
    });

    testWidgets('with Offline mode on, each row says it is blocked', (
      tester,
    ) async {
      await open(tester, offline: true);
      expect(
        status(tester, NetworkCallKind.foodDatabase),
        'Never · Blocked by Offline mode',
      );
    });

    testWidgets('links go to each switch', (tester) async {
      await open(tester);
      // Offline mode, AI consent and crash diagnostics are on Manage your
      // data: the link goes back there.
      await tester.tap(
        find.byKey(const ValueKey('network_switch_food_lookup')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NetworkActivityScreen), findsNothing);
      expect(find.text('Manage your data'), findsOneWidget);

      // Food updates on Wi-Fi only is on Food database.
      await tester.tap(find.text('Manage your data'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('network_switch_food_database')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FoodDatabaseScreen), findsOneWidget);
    });
  });
}

/// Answers every request with an empty 200.
class _Ok implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _FakeIap implements InAppPurchase {
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: const [],
        notFoundIDs: ids.toList(),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
