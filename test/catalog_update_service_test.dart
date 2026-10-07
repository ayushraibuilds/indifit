import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/core_providers.dart';
import 'package:indifit/data/catalog/catalog_pack.dart';
import 'package:indifit/data/catalog/catalog_update_service.dart';
import 'package:indifit/features/nutrition/nutrition_providers.dart';
import 'package:indifit/features/settings/food_database_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/catalog_update_fakes.dart';
import 'support/real_catalogue.dart';

const _roti = 'Whole Wheat Roti / Chapati';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RealCatalogue catalogue;
  late FakeCatalogServer server;
  late FakeCatalogNetwork network;
  late SharedPreferences prefs;
  late DateTime now;
  late Map<String, Object?> bundledPack;

  // A fresh install has the bundled pack; updates are the versions after it.
  const bundled = kBundledCatalogPackVersion;
  const next = bundled + 1;

  setUpAll(() {
    bundledPack =
        jsonDecode(
              utf8.decode(
                gzip.decode(
                  File(
                    'assets/catalog/pack-$bundled.json.gz',
                  ).readAsBytesSync(),
                ),
              ),
            )
            as Map<String, Object?>;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    catalogue = await RealCatalogue.open();
    server = FakeCatalogServer();
    network = FakeCatalogNetwork();
    now = DateTime.utc(2026, 10, 7, 9);
  });
  tearDown(() => catalogue.close());

  CatalogUpdateService service({
    String manifestUrl = kTestManifestUrl,
    Dio? dio,
    bool offline = false,
  }) => CatalogUpdateService(
    dio: dio ?? (Dio()..httpClientAdapter = server),
    manifestUrl: manifestUrl,
    db: catalogue.db,
    prefs: () async => prefs,
    registry: () async => catalogue.registry,
    isOfflineMode: () => offline,
    network: network,
    nowUtc: () => now,
  );

  /// Pack [version] as a full pack, with roti's energy set to [rotiEnergy].
  TestPackFile fullPack(int version, {double rotiEnergy = 300}) {
    final foods = [
      for (final food in bundledPack['foods']! as List)
        _withEnergy(food as Map<String, Object?>, rotiEnergy),
    ];
    return encodeTestPack({
      ...bundledPack,
      'version': version,
      'kind': 'full',
      'base': null,
      'foods': foods,
    }, '$version.json.gz');
  }

  /// A delta from [base] to [version] that changes only roti.
  TestPackFile deltaPack(int version, int base, {double rotiEnergy = 300}) {
    final roti = (bundledPack['foods']! as List)
        .cast<Map<String, Object?>>()
        .firstWhere((food) => food['display_name'] == _roti);
    return encodeTestPack({
      ...bundledPack,
      'version': version,
      'kind': 'delta',
      'base': base,
      'foods': [_withEnergy(roti, rotiEnergy)],
      'retire': const [],
    }, '$version-from-$base.json.gz');
  }

  void publish(TestPackFile pack) => server.file(pack.url, pack.bytes);

  Future<double?> rotiEnergyPer100g() async {
    final id = await catalogue.foodId(_roti);
    final row = await catalogue.db
        .customSelect(
          'SELECT amount FROM nutrition_food_nutrient_facts '
          "WHERE food_id = ? AND nutrient_id = 'energy' AND is_current = 1 "
          'AND preparation_id IS NULL',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return row.read<double?>('amount');
  }

  Future<int?> installed() async {
    final rows = await catalogue.db.select(catalogue.db.catalogState).get();
    return rows.map((row) => row.version).reduce((a, b) => a > b ? a : b);
  }

  test('an empty manifest URL means no request, even on demand', () async {
    final updates = service(manifestUrl: '');
    expect(updates.updatesAvailableInBuild, isFalse);
    expect((await updates.checkOnResume()).outcome, CatalogUpdateOutcome.off);
    expect((await updates.checkNow()).outcome, CatalogUpdateOutcome.off);
    expect(server.requests, isEmpty);
  });

  test('an ETag hit makes no download', () async {
    final newer = fullPack(next);
    publish(newer);
    server.manifest(testManifest(bundled, [fullPack(bundled)]), etag: '"m1"');
    final updates = service();

    expect((await updates.checkNow()).outcome, CatalogUpdateOutcome.upToDate);
    expect(server.urls, [kTestManifestUrl]);
    expect(server.requests.single.headers['If-None-Match'], isNull);

    // Unchanged on the server: 304, so nothing else is fetched.
    server.requests.clear();
    expect((await updates.checkNow()).outcome, CatalogUpdateOutcome.upToDate);
    expect(server.urls, [kTestManifestUrl]);
    expect(server.requests.single.headers['If-None-Match'], '"m1"');
    expect(await installed(), bundled);
  });

  test('Wi-Fi only on mobile data makes no download', () async {
    final newer = fullPack(next);
    publish(newer);
    server.manifest(testManifest(next, [newer]));
    network.value = CatalogNetwork.mobile;
    final updates = service();

    final result = await updates.checkNow();
    expect(result.outcome, CatalogUpdateOutcome.waitingForWifi);
    expect(server.urls, [kTestManifestUrl]);
    expect(await installed(), bundled);
    // The switch can show what the waiting download costs.
    expect((await updates.status()).pendingUpdateBytes, newer.bytes.length);

    // Allowed on mobile data, the same check downloads it.
    await updates.setAllowMobileData(true);
    expect((await updates.checkNow()).outcome, CatalogUpdateOutcome.updated);
    expect(server.urls.last, newer.url);
    expect(await installed(), next);
  });

  test('an update held for Wi-Fi downloads on the next resume on Wi-Fi, '
      'without asking for the manifest again', () async {
    final newer = fullPack(next);
    publish(newer);
    server.manifest(testManifest(next, [newer]));
    network.value = CatalogNetwork.mobile;
    final updates = service();
    expect(
      (await updates.checkOnResume()).outcome,
      CatalogUpdateOutcome.waitingForWifi,
    );

    now = now.add(const Duration(hours: 1));
    network.value = CatalogNetwork.wifi;
    server.requests.clear();
    expect(
      (await updates.checkOnResume()).outcome,
      CatalogUpdateOutcome.updated,
    );
    expect(server.urls, [newer.url]);
  });

  test('Offline Mode makes no request', () async {
    SharedPreferences.setMockInitialValues({
      AppPreferenceKeys.offlineOnly: true,
    });
    final offlinePrefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(offlinePrefs),
        databaseProvider.overrideWithValue(catalogue.db),
        catalogManifestUrlProvider.overrideWithValue(kTestManifestUrl),
        catalogNetworkProbeProvider.overrideWithValue(network),
        nutritionRegistryProvider.overrideWith((_) async => catalogue.registry),
      ],
    );
    addTearDown(container.dispose);
    // The app's shared client, with its Offline Mode interceptor.
    container.read(dioProvider).httpClientAdapter = server;
    server.manifest(testManifest(next, [fullPack(next)]));

    final updates = container.read(catalogUpdateServiceProvider);
    expect(
      (await updates.checkNow()).outcome,
      CatalogUpdateOutcome.offlineMode,
    );
    expect(
      (await updates.checkOnResume()).outcome,
      CatalogUpdateOutcome.offlineMode,
    );
    expect(server.requests, isEmpty);

    // Even if Offline Mode turned on after the service's own check, the
    // shared client's interceptor throws before anything is sent.
    final racing = service(dio: container.read(dioProvider), offline: false);
    expect((await racing.checkNow()).outcome, CatalogUpdateOutcome.failed);
    expect(server.requests, isEmpty);
    expect(await installed(), bundled);
  });

  test(
    'a sha256 mismatch is rejected and the installed version kept',
    () async {
      final before = await rotiEnergyPer100g();
      final newer = fullPack(next, rotiEnergy: before! + 50);
      publish(newer);
      server.manifest(
        testManifest(next, [
          TestPackFile(newer.bytes, {...newer.entry, 'sha256': 'ab' * 32}),
        ]),
      );
      final updates = service();

      expect((await updates.checkNow()).outcome, CatalogUpdateOutcome.failed);
      expect(server.urls, [kTestManifestUrl, newer.url]);
      expect(await installed(), bundled);
      expect(await rotiEnergyPer100g(), before);
      expect((await updates.status()).lastOutcome, CatalogUpdateOutcome.failed);
    },
  );

  test('a pack for a newer app build is not downloaded', () async {
    final newer = fullPack(next);
    publish(newer);
    server.manifest(testManifest(next, [newer], minAppBuild: 99));

    expect(
      (await service().checkNow()).outcome,
      CatalogUpdateOutcome.appTooOld,
    );
    expect(server.urls, [kTestManifestUrl]);
    expect(await installed(), bundled);
  });

  test('a delta is applied when its base is installed', () async {
    final delta = deltaPack(next, bundled, rotiEnergy: 301);
    final full = fullPack(next, rotiEnergy: 301);
    publish(delta);
    publish(full);
    server.manifest(testManifest(next, [delta, full]));

    expect((await service().checkNow()).outcome, CatalogUpdateOutcome.updated);
    expect(server.urls, [kTestManifestUrl, delta.url]);
    expect(await installed(), next);
    expect(await rotiEnergyPer100g(), 301);
  });

  test('the full pack is fetched when no delta starts at the installed '
      'version', () async {
    final delta = deltaPack(next + 1, next, rotiEnergy: 302);
    final full = fullPack(next + 1, rotiEnergy: 302);
    publish(delta);
    publish(full);
    server.manifest(testManifest(next + 1, [delta, full]));

    expect((await service().checkNow()).outcome, CatalogUpdateOutcome.updated);
    expect(server.urls, [kTestManifestUrl, full.url]);
    expect(await installed(), next + 1);
    expect(await rotiEnergyPer100g(), 302);
  });

  test('resume checks run at most once every 24 hours', () async {
    server.manifest(testManifest(bundled, [fullPack(bundled)]));
    final updates = service();

    expect(
      (await updates.checkOnResume()).outcome,
      CatalogUpdateOutcome.upToDate,
    );
    expect(server.requests, hasLength(1));

    now = now.add(const Duration(hours: 23, minutes: 59));
    expect(
      (await updates.checkOnResume()).outcome,
      CatalogUpdateOutcome.throttled,
    );
    expect(server.requests, hasLength(1));

    // "Check for updates" doesn't wait.
    expect((await updates.checkNow()).outcome, CatalogUpdateOutcome.upToDate);
    expect(server.requests, hasLength(2));

    now = now.add(const Duration(hours: 24));
    expect(
      (await updates.checkOnResume()).outcome,
      CatalogUpdateOutcome.upToDate,
    );
    expect(server.requests, hasLength(3));
  });

  test('no connection sends nothing and leaves the daily check due', () async {
    server.manifest(testManifest(bundled, [fullPack(bundled)]));
    network.value = CatalogNetwork.none;
    final updates = service();
    expect(
      (await updates.checkOnResume()).outcome,
      CatalogUpdateOutcome.noConnection,
    );
    expect(server.requests, isEmpty);

    network.value = CatalogNetwork.wifi;
    expect(
      (await updates.checkOnResume()).outcome,
      CatalogUpdateOutcome.upToDate,
    );
    expect(server.requests, hasLength(1));
  });

  test('status reports the installed catalogue', () async {
    final status = await service().status();
    expect(status.version, bundled);
    expect(status.source, 'bundled');
    expect(status.installedAt, isNotNull);
    // Pack v2 carries 573 foods; 75 are retired. Of the 498 active ones,
    // 255 name a `variant_of` in the pack, so 243 are dishes: the count the
    // README and store listing state (r09a_product_truth_test).
    final retired = {
      for (final retirement in bundledPack['retire']! as List)
        (retirement as Map)['id'],
    };
    final active = (bundledPack['foods']! as List).cast<Map>().where(
      (food) => !retired.contains(food['id']),
    );
    final variants = active.where((food) => food['variant_of'] != null);
    expect(status.foodCount, active.length);
    expect(status.variantCount, variants.length);
    expect((status.foodCount, status.variantCount), (498, 255));
    expect(status.lastCheckAt, isNull);
    expect(status.allowMobileData, isFalse);
  });
}

Map<String, Object?> _withEnergy(Map<String, Object?> food, double energy) {
  if (food['display_name'] != _roti) return food;
  final facts = food['facts']! as Map<String, Object?>;
  final values = facts['values']! as Map<String, Object?>;
  return {
    ...food,
    'facts': {
      ...facts,
      'values': {...values, 'energy': energy},
    },
  };
}
