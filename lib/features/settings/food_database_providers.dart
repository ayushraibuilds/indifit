import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/di/core_providers.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../data/catalog/catalog_update_service.dart';
import '../nutrition/nutrition_providers.dart';

/// The food database manifest URL; empty turns updates off (CAT-7).
final catalogManifestUrlProvider = Provider<String>(
  (_) => AppConfig.catalogManifestUrl,
);

final catalogNetworkProbeProvider = Provider<CatalogNetworkProbe>(
  (_) => ConnectivityCatalogNetworkProbe(),
);

final catalogUpdateServiceProvider = Provider<CatalogUpdateService>((ref) {
  return CatalogUpdateService(
    dio: ref.watch(dioProvider),
    manifestUrl: ref.watch(catalogManifestUrlProvider),
    db: ref.watch(databaseProvider),
    prefs: () async =>
        sharedPreferencesOrNull(() => ref.read(sharedPreferencesProvider)) ??
        await SharedPreferences.getInstance(),
    registry: () => ref.read(nutritionRegistryProvider.future),
    isOfflineMode: () => ref.read(privacyPolicyProvider).isOfflineOnly,
    network: ref.watch(catalogNetworkProbeProvider),
  );
});

/// What Settings → Food database shows; invalidate after a check.
final catalogStatusProvider = FutureProvider.autoDispose<CatalogStatus>(
  (ref) => ref.watch(catalogUpdateServiceProvider).status(),
);
