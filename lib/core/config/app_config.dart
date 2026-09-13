import 'package:flutter/foundation.dart';

/// Centralized app configuration for environment-specific variables.
class AppConfig {
  /// Post-V1 connected capability contract: IndiFit supports reviewable
  /// connected intelligence (nutrition-label OCR, meal parsing) while
  /// keeping the local database core fully functional offline.
  static const bool connectedAiEnabled = true;

  /// The base URL for the backend API (FastAPI AI router).
  /// Can be overridden during compilation using:
  /// `--dart-define=BACKEND_API_URL=https://your-production-url.com`
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: kReleaseMode
        ? 'https://api.indifit.app'
        : 'http://10.0.2.2:8000', // Adapt for Android Emulator local loopback
  );

  /// Optional legacy-backend credential for development and compatibility
  /// tests. V1 release startup never requires this value.
  static const String rawApiKey = String.fromEnvironment('INDIFIT_API_KEY');

  /// Returns true if a non-empty legacy-backend credential was supplied.
  static bool get hasValidApiKey => rawApiKey.trim().isNotEmpty;
}
