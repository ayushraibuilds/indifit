import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/core_providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/catalog/catalog_pack.dart';
import 'package:indifit/data/catalog/catalog_update_service.dart';
import 'package:indifit/features/settings/food_data_credits.dart';
import 'package:indifit/features/settings/food_database_providers.dart';
import 'package:indifit/features/settings/food_database_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/catalog_update_fakes.dart';
import 'support/real_catalogue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RealCatalogue catalogue;
  late FakeCatalogServer server;

  setUp(() => server = FakeCatalogServer());

  Future<void> pumpScreen(
    WidgetTester tester, {
    String manifestUrl = kTestManifestUrl,
    Map<String, Object> prefs = const {},
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues(prefs);
    final preferences = await SharedPreferences.getInstance();
    await tester.runAsync(() async {
      catalogue = await RealCatalogue.open();
    });
    addTearDown(() => tester.runAsync(catalogue.close));
    final service = CatalogUpdateService(
      dio: Dio()..httpClientAdapter = server,
      manifestUrl: manifestUrl,
      db: catalogue.db,
      prefs: () async => preferences,
      registry: () async => catalogue.registry,
      isOfflineMode: () =>
          preferences.getBool(AppPreferenceKeys.offlineOnly) ?? false,
      network: FakeCatalogNetwork(),
      nowUtc: () => DateTime.utc(2026, 10, 7, 9),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          catalogUpdateServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const FoodDatabaseScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('shows the installed catalogue, its size and its sources', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Food database'), findsOneWidget);
    expect(find.text('Version $kBundledCatalogPackVersion'), findsOneWidget);
    expect(
      find.textContaining('Came with the app · installed'),
      findsOneWidget,
    );
    expect(
      // 243 dishes, as README and the store listing say (r09a).
      find.text('498 foods, including 255 size and preparation variants'),
      findsOneWidget,
    );
    expect(find.text('Not checked for updates yet'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Also update on mobile data'), findsOneWidget);
    expect(find.text('Off: updates wait for Wi-Fi.'), findsOneWidget);
    expect(find.text('Sources and attributions'), findsOneWidget);
    expect(find.text(FoodDataCredits.catalogue), findsOneWidget);
    expect(find.text(FoodDataCredits.openFoodFacts), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Check for updates" checks and reports the result', (
    tester,
  ) async {
    final v1 = encodeTestPack({'version': 1, 'kind': 'full'}, '1.json.gz');
    server.manifest(testManifest(1, [v1]));
    await pumpScreen(tester);

    await tester.tap(find.text('Check for updates'));
    await settle(tester);

    expect(server.urls, [kTestManifestUrl]);
    expect(find.text('Your food database is up to date.'), findsOneWidget);
    expect(
      find.text(FoodDatabaseCopy.lastCheckLine(DateTime.utc(2026, 10, 7, 9))),
      findsOneWidget,
    );
    expect(find.textContaining('Last checked 7 Oct 2026'), findsOneWidget);
    // The last manifest says how big a full update is.
    expect(
      find.text(
        'Off: updates wait for Wi-Fi. A full update is '
        '${FoodDatabaseCopy.bytes(v1.bytes.length)}.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the mobile data switch is saved', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(Switch));
    await settle(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppPreferenceKeys.catalogUpdateAllowMobileData), true);
    expect(
      find.text('On: updates also download on mobile data.'),
      findsOneWidget,
    );
  });

  testWidgets('Offline Mode pauses the button and sends nothing', (
    tester,
  ) async {
    await pumpScreen(tester, prefs: {AppPreferenceKeys.offlineOnly: true});

    expect(
      find.text('Offline Mode is on, so food database updates are paused.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Check for updates'));
    await settle(tester);
    expect(server.requests, isEmpty);
  });

  testWidgets('a build without a manifest URL says updates are not '
      'available and offers no controls that do nothing', (tester) async {
    await pumpScreen(tester, manifestUrl: '');

    expect(
      find.text(
        'Food database updates aren\'t available in this version of IndiFit yet.',
      ),
      findsOneWidget,
    );
    expect(find.text('Also update on mobile data'), findsNothing);
    await tester.tap(find.text('Check for updates'));
    await settle(tester);
    expect(server.requests, isEmpty);
  });

  test('sizes are shown in plain units', () {
    expect(FoodDatabaseCopy.bytes(900), '900 bytes');
    expect(FoodDatabaseCopy.bytes(41234), '42 KB');
    expect(FoodDatabaseCopy.bytes(1250000), '1.3 MB');
  });
}

/// Real database work runs outside the fake clock, then the frame settles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}
