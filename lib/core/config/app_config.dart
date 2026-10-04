import 'package:flutter/foundation.dart';

/// Centralized app configuration for environment-specific variables.
class AppConfig {
  /// Connected AI ships only when a safe backend exists (see P0 plan WS6).
  /// Enable for development with --dart-define=INDIFIT_CONNECTED_AI=true.
  static const bool connectedAiEnabled = bool.fromEnvironment(
    'INDIFIT_CONNECTED_AI',
  );

  /// The base URL for the IndiFit backend (food search proxy, dev AI routes).
  ///
  /// Empty in release builds: no backend is deployed, so online food search
  /// and barcode lookup go straight to Open Food Facts. Set it once a backend
  /// is live with `--dart-define=BACKEND_API_URL=https://…`. Debug builds use
  /// the local FastAPI server (Android emulator loopback).
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: kReleaseMode ? '' : 'http://10.0.2.2:8000',
  );

  /// Optional legacy-backend credential for development and compatibility
  /// tests. V1 release startup never requires this value.
  static const String rawApiKey = String.fromEnvironment('INDIFIT_API_KEY');

  /// Which AI gateway connected features use: `firebase` (default, release)
  /// or `fastapi` for local development against `backend/`, e.g.
  /// `--dart-define=INDIFIT_AI_GATEWAY=fastapi`.
  static const String aiGateway = String.fromEnvironment(
    'INDIFIT_AI_GATEWAY',
    defaultValue: 'firebase',
  );

  /// A Firebase App Check debug token registered in the console, shared by
  /// every debug device, simulator and CI run so tokens don't have to be
  /// re-registered after reinstalls. Pass it at build time
  /// (`--dart-define=INDIFIT_APPCHECK_DEBUG_TOKEN=...`); it is a secret, so
  /// never commit it.
  static const String appCheckDebugToken = String.fromEnvironment(
    'INDIFIT_APPCHECK_DEBUG_TOKEN',
  );

  /// Use App Check's debug provider in a profile/release build, to test
  /// release-mode behaviour without store attestation. Store builds must
  /// never set this: anyone holding the debug token could then pass App
  /// Check.
  static const bool forceAppCheckDebugProvider = bool.fromEnvironment(
    'INDIFIT_APPCHECK_DEBUG',
  );

  /// Debug builds always use the debug provider; others only when forced.
  static bool get useAppCheckDebugProvider =>
      kDebugMode || forceAppCheckDebugProvider;

  /// Returns true if a non-empty legacy-backend credential was supplied.
  static bool get hasValidApiKey => rawApiKey.trim().isNotEmpty;
}
