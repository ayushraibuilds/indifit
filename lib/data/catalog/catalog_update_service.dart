import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/nutrients.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/utils/app_logger.dart';
import '../database/app_database.dart';
import 'catalog_pack.dart';
import 'catalog_pack_importer.dart';

/// The kind of connection a download would use.
enum CatalogNetwork { wifi, mobile, none }

/// Reports the current connection, so updates can wait for Wi-Fi.
abstract interface class CatalogNetworkProbe {
  Future<CatalogNetwork> current();
}

class ConnectivityCatalogNetworkProbe implements CatalogNetworkProbe {
  final Connectivity _connectivity;

  ConnectivityCatalogNetworkProbe([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  @override
  Future<CatalogNetwork> current() async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return CatalogNetwork.wifi;
    }
    if (results.every((result) => result == ConnectivityResult.none)) {
      return CatalogNetwork.none;
    }
    // Mobile, or a VPN or other link whose cost we can't tell: treat it as
    // metered.
    return CatalogNetwork.mobile;
  }
}

/// How the last update check ended. The stable ids are persisted.
enum CatalogUpdateOutcome {
  /// No manifest URL is configured in this build.
  off('off'),
  offlineMode('offline_mode'),
  noConnection('no_connection'),

  /// Checked less than 24 hours ago.
  throttled('throttled'),
  upToDate('up_to_date'),

  /// An update is published, and this connection is mobile data while
  /// updates are Wi-Fi only.
  waitingForWifi('waiting_for_wifi'),

  /// The published pack needs a newer app build.
  appTooOld('app_too_old'),
  updated('updated'),
  failed('failed');

  const CatalogUpdateOutcome(this.id);
  final String id;

  static CatalogUpdateOutcome? parse(String? id) {
    for (final outcome in values) {
      if (outcome.id == id) return outcome;
    }
    return null;
  }
}

class CatalogUpdateResult {
  final CatalogUpdateOutcome outcome;

  /// The installed catalogue version after the check.
  final int? installedVersion;

  const CatalogUpdateResult(this.outcome, {this.installedVersion});
}

/// What Settings → Food database shows.
class CatalogStatus {
  final bool updatesAvailableInBuild;
  final int? version;
  final DateTime? installedAt;

  /// `bundled` (came with the app) or `download`.
  final String? source;

  /// Active catalogue foods with current values, variants included.
  final int foodCount;

  /// How many of [foodCount] are size or preparation variants of a dish.
  final int variantCount;
  final DateTime? lastCheckAt;
  final CatalogUpdateOutcome? lastOutcome;
  final bool allowMobileData;

  /// The download the next update needs, from the last manifest seen.
  final int? pendingUpdateBytes;

  /// The full pack's size in the last manifest seen.
  final int? fullPackBytes;

  const CatalogStatus({
    required this.updatesAvailableInBuild,
    required this.version,
    required this.installedAt,
    required this.source,
    required this.foodCount,
    required this.variantCount,
    required this.lastCheckAt,
    required this.lastOutcome,
    required this.allowMobileData,
    required this.pendingUpdateBytes,
    required this.fullPackBytes,
  });
}

/// Downloads and applies food catalogue packs (CAT-7).
///
/// Runs on app resume at most once every 24 hours, or when the person taps
/// "Check for updates". Never runs in Offline Mode; waits for Wi-Fi unless
/// "Also update on mobile data" is on. The manifest is fetched with
/// `If-None-Match`; a published delta is used when its base is the installed
/// version, otherwise the full pack. Every pack is checked against its
/// sha256 and `min_app_build`, then applied by [CatalogPackImporter] in one
/// transaction, so a failure leaves the installed catalogue as it was.
///
/// Requests go through the app's shared Dio client, so the Offline Mode
/// interceptor applies to them too. They carry nothing about the person:
/// a plain GET of a static file.
class CatalogUpdateService {
  static const checkInterval = Duration(hours: 24);

  final Dio _dio;
  final String _manifestUrl;
  final AppDatabase _db;
  final Future<SharedPreferences> Function() _prefs;
  final Future<NutrientRegistry> Function() _registry;
  final bool Function() _isOfflineMode;
  final CatalogNetworkProbe _network;
  final DateTime Function() _nowUtc;
  final int _appBuild;

  Future<CatalogUpdateResult>? _running;

  CatalogUpdateService({
    required Dio dio,
    required String manifestUrl,
    required AppDatabase db,
    required Future<SharedPreferences> Function() prefs,
    required Future<NutrientRegistry> Function() registry,
    required bool Function() isOfflineMode,
    required CatalogNetworkProbe network,
    DateTime Function()? nowUtc,
    int appBuild = kCatalogAppBuild,
  }) : _dio = dio,
       _manifestUrl = manifestUrl.trim(),
       _db = db,
       _prefs = prefs,
       _registry = registry,
       _isOfflineMode = isOfflineMode,
       _network = network,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _appBuild = appBuild;

  /// False when this build has no manifest URL: nothing is ever requested.
  bool get updatesAvailableInBuild => _manifestUrl.isNotEmpty;

  /// The app came to the foreground. Checks at most once every 24 hours.
  Future<CatalogUpdateResult> checkOnResume() => _once(manual: false);

  /// "Check for updates": skips the 24-hour wait, nothing else.
  Future<CatalogUpdateResult> checkNow() => _once(manual: true);

  Future<CatalogUpdateResult> _once({required bool manual}) {
    final running = _running;
    if (running != null) return running;
    final next = _check(manual: manual).whenComplete(() => _running = null);
    return _running = next;
  }

  Future<CatalogUpdateResult> _check({required bool manual}) async {
    if (!updatesAvailableInBuild) {
      return const CatalogUpdateResult(CatalogUpdateOutcome.off);
    }
    if (_isOfflineMode()) {
      return const CatalogUpdateResult(CatalogUpdateOutcome.offlineMode);
    }
    final prefs = await _prefs();
    final installed = await _installedVersion();
    try {
      final network = await _network.current();
      if (network == CatalogNetwork.none) {
        return CatalogUpdateResult(
          CatalogUpdateOutcome.noConnection,
          installedVersion: installed,
        );
      }

      final now = _nowUtc();
      final lastMillis = prefs.getInt(
        AppPreferenceKeys.catalogUpdateLastCheckAt,
      );
      final last = lastMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastMillis, isUtc: true);
      final due =
          manual ||
          last == null ||
          now.isBefore(last) ||
          now.difference(last) >= checkInterval;

      final CatalogPackManifest manifest;
      if (due) {
        await prefs.setInt(
          AppPreferenceKeys.catalogUpdateLastCheckAt,
          now.millisecondsSinceEpoch,
        );
        manifest = await _fetchManifest(prefs);
      } else {
        // Between checks, only an update already found and held back for
        // Wi-Fi goes ahead, from the manifest seen then.
        final waiting =
            prefs.getString(AppPreferenceKeys.catalogUpdateLastOutcome) ==
            CatalogUpdateOutcome.waitingForWifi.id;
        final cached = waiting ? _cachedManifest(prefs) : null;
        if (cached == null) {
          return CatalogUpdateResult(
            CatalogUpdateOutcome.throttled,
            installedVersion: installed,
          );
        }
        manifest = cached;
      }

      if (installed != null && manifest.latest <= installed) {
        return _finish(prefs, CatalogUpdateOutcome.upToDate, installed);
      }
      final minAppBuild = manifest.minAppBuild;
      if (minAppBuild != null && minAppBuild > _appBuild) {
        return _finish(prefs, CatalogUpdateOutcome.appTooOld, installed);
      }
      final entry = manifest.entryFrom(installed);
      final allowMobile =
          prefs.getBool(AppPreferenceKeys.catalogUpdateAllowMobileData) ??
          false;
      if (network == CatalogNetwork.mobile && !allowMobile) {
        return _finish(prefs, CatalogUpdateOutcome.waitingForWifi, installed);
      }

      final bytes = await _download(entry);
      final registry = await _registry();
      final nutrientIds = registry.definitions.map((d) => d.id).toList();
      final pack = CatalogPack.decode(
        bytes,
        expectedSha256: entry.sha256,
        registryVersion: '${registry.version}',
        nutrientIds: nutrientIds.toSet(),
        appBuild: _appBuild,
      );
      final result = await CatalogPackImporter(
        db: _db,
        nutrientIds: nutrientIds,
      ).apply(pack, source: 'download');
      return _finish(
        prefs,
        result.applied
            ? CatalogUpdateOutcome.updated
            : CatalogUpdateOutcome.upToDate,
        result.version,
      );
    } catch (error, stackTrace) {
      // The importer's transaction rolled back (or never started), so the
      // installed catalogue is unchanged.
      AppLogger.warning('Food database update failed: $error');
      if (error is! DioException) {
        CrashReportingService.recordCrash(
          error,
          stackTrace,
          reason: 'food database update failed',
        );
      }
      return _finish(prefs, CatalogUpdateOutcome.failed, installed);
    }
  }

  Future<CatalogUpdateResult> _finish(
    SharedPreferences prefs,
    CatalogUpdateOutcome outcome,
    int? installed,
  ) async {
    await prefs.setString(
      AppPreferenceKeys.catalogUpdateLastOutcome,
      outcome.id,
    );
    return CatalogUpdateResult(outcome, installedVersion: installed);
  }

  Future<CatalogPackManifest> _fetchManifest(SharedPreferences prefs) async {
    final etag = prefs.getString(AppPreferenceKeys.catalogUpdateManifestEtag);
    final cachedJson = prefs.getString(
      AppPreferenceKeys.catalogUpdateManifestJson,
    );
    final response = await _dio.get<String>(
      _manifestUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          if (etag != null && cachedJson != null) 'If-None-Match': etag,
        },
        validateStatus: (status) => status == 200 || status == 304,
      ),
    );
    if (response.statusCode == 304) {
      final cached = _cachedManifest(prefs);
      if (cached != null) return cached;
      throw const CatalogPackError(
        'missing_manifest',
        'The server said the manifest is unchanged, but none is saved.',
      );
    }
    final body = response.data ?? '';
    final manifest = CatalogPackManifest.parse(jsonDecode(body));
    await prefs.setString(AppPreferenceKeys.catalogUpdateManifestJson, body);
    final newEtag = response.headers.value('etag');
    if (newEtag == null) {
      await prefs.remove(AppPreferenceKeys.catalogUpdateManifestEtag);
    } else {
      await prefs.setString(
        AppPreferenceKeys.catalogUpdateManifestEtag,
        newEtag,
      );
    }
    return manifest;
  }

  CatalogPackManifest? _cachedManifest(SharedPreferences prefs) {
    final json = prefs.getString(AppPreferenceKeys.catalogUpdateManifestJson);
    if (json == null) return null;
    try {
      return CatalogPackManifest.parse(jsonDecode(json));
    } on Object {
      // Safe: a damaged cache only means the next check downloads the
      // manifest again.
      return null;
    }
  }

  Future<List<int>> _download(CatalogPackManifestEntry entry) async {
    final url = Uri.parse(_manifestUrl).resolve(entry.url).toString();
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const CatalogPackError('empty_pack', 'The download was empty.');
    }
    return bytes;
  }

  Future<int?> _installedVersion() =>
      CatalogPackImporter(db: _db, nutrientIds: const []).installedVersion();

  /// "Also update on mobile data".
  Future<void> setAllowMobileData(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(AppPreferenceKeys.catalogUpdateAllowMobileData, value);
  }

  Future<CatalogStatus> status() async {
    final prefs = await _prefs();
    final installed = await _installedVersion();
    final state = installed == null
        ? null
        : await (_db.select(
            _db.catalogState,
          )..where((row) => row.version.equals(installed))).getSingle();
    final count = await _db
        .customSelect(
          'SELECT COUNT(*) AS foods, COALESCE(SUM(f.kind IN '
          "('preparationVariant', 'servingPresentationVariant')), 0) "
          'AS variants FROM nutrition_foods f '
          "WHERE f.lifecycle = 'active' "
          'AND EXISTS (SELECT 1 FROM nutrition_food_nutrient_facts n '
          'WHERE n.food_id = f.id AND n.is_current = 1 '
          "AND n.preparation_id IS NULL AND n.source_ref LIKE 'catalog-pack:%')",
          readsFrom: {_db.nutritionFoods, _db.nutritionFoodNutrientFacts},
        )
        .getSingle();
    final lastMillis = prefs.getInt(AppPreferenceKeys.catalogUpdateLastCheckAt);
    final manifest = _cachedManifest(prefs);
    int? pending;
    int? full;
    if (manifest != null) {
      for (final pack in manifest.packs) {
        if (pack.version == manifest.latest && !pack.isDelta) full = pack.bytes;
      }
      if (installed == null || manifest.latest > installed) {
        try {
          pending = manifest.entryFrom(installed).bytes;
        } on CatalogPackError {
          pending = null;
        }
      }
    }
    return CatalogStatus(
      updatesAvailableInBuild: updatesAvailableInBuild,
      version: installed,
      installedAt: state?.appliedAt,
      source: state?.source,
      foodCount: count.read<int>('foods'),
      variantCount: count.read<int>('variants'),
      lastCheckAt: lastMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastMillis, isUtc: true),
      lastOutcome: CatalogUpdateOutcome.parse(
        prefs.getString(AppPreferenceKeys.catalogUpdateLastOutcome),
      ),
      allowMobileData:
          prefs.getBool(AppPreferenceKeys.catalogUpdateAllowMobileData) ??
          false,
      pendingUpdateBytes: pending,
      fullPackBytes: full,
    );
  }
}
