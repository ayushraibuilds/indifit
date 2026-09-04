/// Central capability registry and dependency injection providers for IndiFit.
///
/// Every capability defaults to a safe, offline, no-op implementation, guaranteeing
/// that the app runs with 100% offline functionality out-of-the-box.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_capability.dart';
import 'ai_assistance_capability.dart';
import 'analytics_capability.dart';
import 'cloud_backup_capability.dart';
import 'connected_status.dart';
import 'content_download_capability.dart';
import 'diagnostics_capability.dart';
import 'entitlement_capability.dart';
import 'food_catalog_capability.dart';
import 'integration_capability.dart';
import 'network_capability.dart';
import 'sync_capability.dart';

export 'account_capability.dart';
export 'ai_assistance_capability.dart';
export 'analytics_capability.dart';
export 'cloud_backup_capability.dart';
export 'connected_status.dart';
export 'content_download_capability.dart';
export 'diagnostics_capability.dart';
export 'entitlement_capability.dart';
export 'food_catalog_capability.dart';
export 'integration_capability.dart';
export 'network_capability.dart';
export 'sync_capability.dart';

/// Account capability provider.
final accountCapabilityProvider = Provider<AccountCapability>((ref) {
  return const NoOpAccountCapability();
});

/// Network connectivity and policy capability provider.
final networkCapabilityProvider = Provider<NetworkCapability>((ref) {
  return const OfflineNetworkCapability();
});

/// Cloud backup capability provider.
final cloudBackupCapabilityProvider = Provider<CloudBackupCapability>((ref) {
  return const DisabledCloudBackupCapability();
});

/// Future provider exposing current Cloud Backup status.
final cloudBackupStatusProvider = FutureProvider<ConnectedStatusState>((ref) async {
  final capability = ref.watch(cloudBackupCapabilityProvider);
  return capability.getStatus();
});

/// Multi-device sync capability provider.
final syncCapabilityProvider = Provider<SyncCapability>((ref) {
  return const DisabledSyncCapability();
});

/// Remote food catalog capability provider.
final foodCatalogCapabilityProvider = Provider<FoodCatalogCapability>((ref) {
  return const DisabledFoodCatalogCapability();
});

/// Content and media download capability provider.
final contentDownloadCapabilityProvider =
    Provider<ContentDownloadCapability>((ref) {
  return const DisabledContentDownloadCapability();
});

/// AI assistance capability provider.
final aiAssistanceCapabilityProvider = Provider<AiAssistanceCapability>((ref) {
  return const DisabledAiAssistanceCapability();
});

/// Third-party platform integration (Health) provider.
final integrationCapabilityProvider = Provider<IntegrationCapability>((ref) {
  return const DisabledIntegrationCapability();
});

/// Diagnostics and telemetry capability provider.
final diagnosticsCapabilityProvider = Provider<DiagnosticsCapability>((ref) {
  return const NoOpDiagnosticsCapability();
});

/// Product analytics capability provider (separate from crash diagnostics).
final analyticsCapabilityProvider = Provider<AnalyticsCapability>((ref) {
  return const NoOpAnalyticsCapability();
});

/// Entitlement and feature access capability provider.
final entitlementCapabilityProvider = Provider<EntitlementCapability>((ref) {
  return const FullLocalEntitlementCapability();
});
